import 'package:flutter/material.dart';
import 'package:wellspring/services/resource_service.dart';
import 'package:wellspring/models/resource.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wellspring/openai/openai_config.dart';
import 'package:wellspring/widgets/nih_education_links.dart';

class MilestoneEducationSheet extends StatefulWidget {
  final String stepTitle;
  final String? stepDescription;
  final String? conditionName;

  const MilestoneEducationSheet({
    super.key,
    required this.stepTitle,
    this.stepDescription,
    this.conditionName,
  });

  @override
  State<MilestoneEducationSheet> createState() => _MilestoneEducationSheetState();
}

class _MilestoneEducationSheetState extends State<MilestoneEducationSheet> {
  Map<String, dynamic>? _edu;
  Map<String, List<Resource>> _nearbyByType = {};
  bool _loading = true;
  String? _error;
  bool _usedLocation = false;
  String? _locationLabel;

  static const List<String> _resourceTypeOrder = ['therapist', 'hospital', 'center', 'service', 'pharmacy'];

  Map<String, dynamic> _offlineEducation() {
    final stepTitle = widget.stepTitle.trim();
    final desc = (widget.stepDescription ?? '').trim();
    final condition = (widget.conditionName ?? '').trim();

    final summaryParts = <String>[];
    if (condition.isNotEmpty) summaryParts.add('This step supports your $condition plan.');
    if (desc.isNotEmpty) summaryParts.add(desc);
    if (summaryParts.isEmpty) summaryParts.add('This step helps you make steady progress in a safe, sustainable way.');

    return {
      'summary': summaryParts.join('\n\n'),
      'whyItMatters': 'Clear steps and supportive resources make it easier to stay consistent and reduce overwhelm.',
      'keyConcepts': <String>[
        'Keep it small and repeatable (consistency beats intensity).',
        'Prepare your environment ahead of time (reduce friction).',
      ],
      'stepByStep': <Map<String, dynamic>>[
        {'title': 'Start tiny', 'detail': 'Pick the smallest version you can do today (2–5 minutes).'},
        {'title': 'Set a cue', 'detail': 'Attach it to an existing routine (after breakfast / before bed).'},
        {'title': 'Log it', 'detail': 'Record a quick note so you can spot patterns over time.'},
      ],
      'disclaimer': 'Educational content only — not medical advice.',
    };
  }

  Future<({double lat, double lng, String? label})?> _tryDeviceLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      return (lat: position.latitude, lng: position.longitude, label: 'your current location');
    } catch (e) {
      debugPrint('MilestoneEducationSheet: device location failed (ignored): $e');
      return null;
    }
  }

  String _radiusLabel(double miles) => miles >= 10 ? miles.toStringAsFixed(0) : miles.toStringAsFixed(1);

  String _typeLabel(String type) {
    switch (type) {
      case 'therapist':
        return 'Therapists & specialists';
      case 'hospital':
        return 'Hospitals';
      case 'center':
        return 'Care centers';
      case 'service':
        return 'Support services';
      case 'pharmacy':
        return 'Pharmacies';
      default:
        if (type.isEmpty) return 'Resources';
        return '${type[0].toUpperCase()}${type.substring(1)}';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'therapist':
        return Icons.psychology_alt;
      case 'hospital':
        return Icons.local_hospital;
      case 'center':
        return Icons.apartment;
      case 'service':
        return Icons.support_agent;
      case 'pharmacy':
        return Icons.local_pharmacy;
      default:
        return Icons.place;
    }
  }

  Widget _resourceTile(BuildContext context, Resource resource) {
    final cs = Theme.of(context).colorScheme;
    final details = <String>[];
    if (_usedLocation && resource.distance > 0) {
      details.add('${resource.distance.toStringAsFixed(1)} mi away');
    }
    final locLabel = resource.location.trim().isNotEmpty ? resource.location.trim() : resource.address.trim();
    if (locLabel.isNotEmpty) {
      details.add(locLabel);
    }
    final primaryLine = details.join(' · ');
    final availability = resource.availability.trim();
    final rating = resource.rating;
    final subtitleChildren = <Widget>[];
    if (primaryLine.isNotEmpty) {
      subtitleChildren.add(Text(primaryLine, style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)));
    }
    if (availability.isNotEmpty) {
      subtitleChildren.add(Text(availability, style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant)));
    }
    final subtitleWidget = subtitleChildren.isEmpty
        ? null
        : (subtitleChildren.length == 1
            ? subtitleChildren.first
            : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: subtitleChildren));
    Widget? trailing;
    if (rating > 0) {
      trailing = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star_rate_rounded, size: 16, color: cs.tertiary),
            SizedBox(width: 2),
            Text(rating.toStringAsFixed(1), style: context.textStyles.labelMedium?.withColor(cs.onSurfaceVariant)),
          ]),
          if (resource.reviewCount > 0)
            Text('${resource.reviewCount} reviews', style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant)),
        ],
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      leading: Icon(_typeIcon(resource.type), color: cs.onSurfaceVariant),
      title: Text(resource.name, style: context.textStyles.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitleWidget,
      trailing: trailing,
      onTap: () => _openResourceLocation(resource),
    );
  }

  Future<void> _openResourceLocation(Resource resource) async {
    // Build Google Maps URL
    final query = Uri.encodeComponent('${resource.name} ${resource.address}'.trim());
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    
    debugPrint('Opening resource location: ${resource.name} at $url');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch maps URL: $url');
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userProvider = context.read<UserProvider>();
      var user = userProvider.currentUser;
      if (user == null) {
        try {
          await userProvider.loadUser();
          user = userProvider.currentUser;
        } catch (e) {
          debugPrint('MilestoneEducationSheet: loadUser failed (ignored): $e');
        }
      }
      if (user != null) {
        try {
          UserService().trackResourceView(user.id);
        } catch (e) {
          debugPrint('MilestoneEducationSheet: trackResourceView failed (ignored): $e');
        }
      }

      double? userLat;
      double? userLng;
      String? locationLabel;
      try {
        final prefs = user?.preferences ?? const {};
        debugPrint('MilestoneEducationSheet: user.preferences = $prefs');
        final loc = prefs['location'] as Map<String, dynamic>?;
        debugPrint('MilestoneEducationSheet: parsed location map = $loc');
        if (loc != null) {
          final latVal = loc['lat'];
          final lngVal = loc['lng'];
          if (latVal is num && lngVal is num) {
            userLat = latVal.toDouble();
            userLng = lngVal.toDouble();
          } else {
            final parsedLat = double.tryParse(latVal?.toString() ?? '');
            final parsedLng = double.tryParse(lngVal?.toString() ?? '');
            if (parsedLat != null && parsedLng != null) {
              userLat = parsedLat;
              userLng = parsedLng;
            }
          }
          final labelCandidate = (loc['label'] ?? loc['city'] ?? loc['postalCode'] ?? loc['zip'] ?? loc['state'] ?? '').toString().trim();
          if (labelCandidate.isNotEmpty) {
            locationLabel = labelCandidate;
          }
        }
      } catch (e) {
        debugPrint('MilestoneEducationSheet: location parse failed (ignored): $e');
      }

      debugPrint('MilestoneEducationSheet: after profile parse: lat=$userLat, lng=$userLng, label=$locationLabel');

      // If the user hasn't explicitly set a location, fall back to device location
      // so "Nearby support" can still show.
      if (userLat == null || userLng == null) {
        debugPrint('MilestoneEducationSheet: no profile location, trying device...');
        final device = await _tryDeviceLocation();
        if (device != null) {
          userLat = device.lat;
          userLng = device.lng;
          locationLabel ??= device.label;
          debugPrint('MilestoneEducationSheet: device location: lat=$userLat, lng=$userLng, label=$locationLabel');
        } else {
          debugPrint('MilestoneEducationSheet: device location unavailable');
        }
      }

      final resourceService = ResourceService();

      // Use the same searchResources method that Resources screen uses
      // (Google Places → OSM → Nominatim → curated Supabase)
      const initialRadius = 15.0;
      const fallbackRadius = 100.0;
      List<Resource> resources = [];
      if (userLat != null && userLng != null) {
        debugPrint('MilestoneEducationSheet: querying nearby resources at ($userLat, $userLng) within ${initialRadius}mi');
        try {
          resources = await resourceService
              .searchResources(
                userLat: userLat,
                userLng: userLng,
                maxDistance: initialRadius,
              )
              .timeout(const Duration(seconds: 12));
          debugPrint('MilestoneEducationSheet: initial query (${initialRadius}mi) returned ${resources.length} resources');
          // If no resources found nearby, try with larger radius
          if (resources.isEmpty) {
            debugPrint('MilestoneEducationSheet: trying fallback query within ${fallbackRadius}mi');
            resources = await resourceService
                .searchResources(
                  userLat: userLat,
                  userLng: userLng,
                  maxDistance: fallbackRadius,
                )
                .timeout(const Duration(seconds: 12));
            debugPrint('MilestoneEducationSheet: fallback query returned ${resources.length} resources');
          }
        } catch (e, st) {
          debugPrint('MilestoneEducationSheet: searchResources failed: $e\n$st');
        }
      } else {
        debugPrint('MilestoneEducationSheet: SKIPPING resource query because no location available');
      }

      final grouped = <String, List<Resource>>{};
      for (final r in resources) {
        if (r.name.trim().isEmpty) continue;
        grouped.putIfAbsent(r.type, () => []).add(r);
      }
      grouped.updateAll((key, value) {
        value.sort((a, b) => a.distance.compareTo(b.distance));
        return value.take(4).toList();
      });

      Map<String, dynamic> edu;
      try {
        final nearbyForAi = resources
            .take(8)
            .map((r) => {
                  'name': r.name,
                  'type': r.type,
                  'distanceMi': r.distance,
                  'availability': r.availability,
                  'address': r.address,
                })
            .toList();
        edu = await OpenAIClient().generateMilestoneEducation(
          stepTitle: widget.stepTitle,
          stepDescription: widget.stepDescription,
          conditionName: widget.conditionName,
          nearbyResources: nearbyForAi,
        );
      } catch (e) {
        debugPrint('MilestoneEducationSheet: AI failed; using offline template: $e');
        edu = _offlineEducation();
      }
      if (!mounted) return;
      setState(() {
        _edu = edu;
        _nearbyByType = grouped;
        _loading = false;
        _usedLocation = userLat != null && userLng != null;
        _locationLabel = locationLabel;
      });
    } catch (e) {
      debugPrint('Education load error: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    debugPrint('[MilestoneEducationSheet v3] build start: "${widget.stepTitle}"');
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

          List<Widget> sectionBlocks = [];
          // Header
          sectionBlocks.addAll([
            _Header(stepTitle: widget.stepTitle),
            SizedBox(height: AppSpacing.md),
          ]);

          if (_loading) {
            sectionBlocks.add(
              Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: const Center(child: CenteredLoadingSkeleton()),
              ),
            );
          } else if (_error != null) {
            sectionBlocks.add(
              Padding(
                padding: AppSpacing.paddingMd,
                child: Row(children: [
                  Icon(Icons.error_outline, color: cs.error),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Couldn\'t load educational content. Please try again.', style: context.textStyles.bodyMedium)),
                ]),
              ),
            );
          } else {
            final summary = (_edu![
              'summary'
            ] as String?)?.trim();
            final why = (_edu!['whyItMatters'] as String?)?.trim();
            final keyConcepts = List<String>.from((_edu!['keyConcepts'] as List? ?? []).map((e) => '$e'));
            final stepByStep = List<Map<String, dynamic>>.from((_edu!['stepByStep'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
            final examples = List<String>.from((_edu!['examples'] as List? ?? []).map((e) => '$e'));
            final pitfalls = List<String>.from((_edu!['pitfalls'] as List? ?? []).map((e) => '$e'));
            final trackingIdeas = List<String>.from((_edu!['trackingIdeas'] as List? ?? []).map((e) => '$e'));
            final queries = List<String>.from((_edu!['searchQueries'] as List? ?? []).map((e) => '$e'));
            final disclaimer = (_edu!['disclaimer'] as String?)?.trim();

            if ((summary ?? '').isNotEmpty) {
              sectionBlocks.addAll([
                Text('Overview', style: context.textStyles.titleMedium?.semiBold),
                SizedBox(height: AppSpacing.xs),
                Text(summary!, style: context.textStyles.bodyMedium),
                SizedBox(height: AppSpacing.md),
              ]);
            }

            if ((why ?? '').isNotEmpty) {
              sectionBlocks.addAll([
                _SectionHeader(icon: Icons.favorite, label: 'Why this matters'),
                Text(why!, style: context.textStyles.bodyMedium),
                SizedBox(height: AppSpacing.md),
              ]);
            }

            if (keyConcepts.isNotEmpty) {
              sectionBlocks.add(_SectionHeader(icon: Icons.lightbulb, label: 'Key concepts'));
              sectionBlocks.addAll(keyConcepts.map((e) => _Bullet(text: e)));
              sectionBlocks.add(SizedBox(height: AppSpacing.md));
            }

            if (stepByStep.isNotEmpty) {
              sectionBlocks.add(_SectionHeader(icon: Icons.checklist, label: 'Step-by-step'));
              sectionBlocks.addAll(stepByStep.map((m) => _StepTile(title: (m['title'] ?? '').toString(), detail: (m['detail'] ?? '').toString())));
              sectionBlocks.add(SizedBox(height: AppSpacing.md));
            }

            if (examples.isNotEmpty) {
              sectionBlocks.add(_SectionHeader(icon: Icons.task_alt, label: 'Examples'));
              sectionBlocks.addAll(examples.map((e) => _Bullet(text: e)));
              sectionBlocks.add(SizedBox(height: AppSpacing.md));
            }

            if (pitfalls.isNotEmpty) {
              sectionBlocks.add(_SectionHeader(icon: Icons.report_problem, label: 'Common pitfalls'));
              sectionBlocks.addAll(pitfalls.map((e) => _Bullet(text: e)));
              sectionBlocks.add(SizedBox(height: AppSpacing.md));
            }

            if (trackingIdeas.isNotEmpty) {
              sectionBlocks.add(_SectionHeader(icon: Icons.show_chart, label: 'How to track'));
              sectionBlocks.addAll(trackingIdeas.map((e) => _Bullet(text: e)));
              sectionBlocks.add(SizedBox(height: AppSpacing.md));
            }

            if (queries.isNotEmpty) {
              sectionBlocks.addAll([
                _SectionHeader(icon: Icons.search, label: 'Research further'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: queries.map((q) => ActionChip(
                    label: Text(q),
                    avatar: Icon(Icons.open_in_new, size: 16),
                    onPressed: () async {
                      // Track research click achievement
                      final user = context.read<UserProvider>().currentUser;
                      if (user != null) {
                        UserService().trackResearchClick(user.id);
                      }
                      final url = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(q)}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  )).toList(),
                ),
                SizedBox(height: AppSpacing.md),
              ]);
            }

            final hasNearby = _nearbyByType.values.any((items) => items.isNotEmpty);
            if (hasNearby) {
              sectionBlocks.add(_SectionHeader(icon: Icons.place, label: _usedLocation ? 'Nearby support' : 'Helpful resources'));
              if (_usedLocation && (_locationLabel?.trim().isNotEmpty ?? false)) {
                // Determine max distance shown for subtitle
                final maxDist = _nearbyByType.values.expand((l) => l).fold<double>(0, (m, r) => r.distance > m ? r.distance : m);
                final radiusLabel = maxDist > 20 ? 'Within ~${_radiusLabel(maxDist + 10)} miles' : 'Within ~${_radiusLabel(15)} miles';
                sectionBlocks.add(Text('$radiusLabel of ${_locationLabel!}', style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)));
                sectionBlocks.add(SizedBox(height: AppSpacing.sm));
              } else if (!_usedLocation) {
                sectionBlocks.add(Text('Add your location in Account Settings > Profile to tailor these suggestions.', style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)));
                sectionBlocks.add(SizedBox(height: AppSpacing.sm));
              }

              final emitted = <String>{};
              for (final type in _resourceTypeOrder) {
                final items = _nearbyByType[type];
                if (items == null || items.isEmpty) continue;
                emitted.add(type);
                sectionBlocks.add(Text(_typeLabel(type), style: context.textStyles.titleSmall?.semiBold));
                sectionBlocks.add(SizedBox(height: AppSpacing.xs));
                for (final resource in items) {
                  sectionBlocks.add(_resourceTile(context, resource));
                }
                sectionBlocks.add(SizedBox(height: AppSpacing.sm));
              }
              final remaining = _nearbyByType.entries
                  .where((entry) => entry.value.isNotEmpty && !emitted.contains(entry.key))
                  .toList()
                ..sort((a, b) => a.key.compareTo(b.key));
              for (final entry in remaining) {
                sectionBlocks.add(Text(_typeLabel(entry.key), style: context.textStyles.titleSmall?.semiBold));
                sectionBlocks.add(SizedBox(height: AppSpacing.xs));
                for (final resource in entry.value) {
                  sectionBlocks.add(_resourceTile(context, resource));
                }
                sectionBlocks.add(SizedBox(height: AppSpacing.sm));
              }

              sectionBlocks.add(
                Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xs),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        debugPrint('[MilestoneEducationSheet] Explore locations tapped, navigating to /resources?tab=explore');
                        // Close sheet first, then navigate
                        Navigator.of(context).pop();
                        context.go('/resources?tab=explore');
                      },
                      icon: Icon(Icons.travel_explore, color: cs.primary),
                      label: Text('Explore locations',
                        style: context.textStyles.labelLarge?.withColor(cs.primary)),
                    ),
                  ),
                ),
              );
              sectionBlocks.add(SizedBox(height: AppSpacing.md));
            } else if (_usedLocation) {
              sectionBlocks.add(_SectionHeader(icon: Icons.place, label: 'Nearby support'));
              sectionBlocks.add(Text('We couldn\'t find matching providers near ${_locationLabel ?? 'your saved location'} yet. Try broadening your search or updating your location.',
                  style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)));
              sectionBlocks.add(SizedBox(height: AppSpacing.sm));
              sectionBlocks.add(
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      debugPrint('[MilestoneEducationSheet] Explore locations tapped (no results), navigating to /resources?tab=explore');
                      Navigator.of(context).pop();
                      context.go('/resources?tab=explore');
                    },
                    icon: Icon(Icons.travel_explore, color: cs.primary),
                    label: Text('Explore locations',
                      style: context.textStyles.labelLarge?.withColor(cs.primary)),
                  ),
                ),
              );
              sectionBlocks.add(SizedBox(height: AppSpacing.md));
            } else {
              sectionBlocks.add(_SectionHeader(icon: Icons.place, label: 'Helpful resources'));
              sectionBlocks.add(Text('Add your location in Account Settings > Profile to surface nearby therapists, resources, and hospitals.',
                  style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)));
              sectionBlocks.add(SizedBox(height: AppSpacing.sm));
              sectionBlocks.add(
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      debugPrint('[MilestoneEducationSheet] Explore locations tapped (no location), navigating to /resources?tab=explore');
                      Navigator.of(context).pop();
                      context.go('/resources?tab=explore');
                    },
                    icon: Icon(Icons.travel_explore, color: cs.primary),
                    label: Text('Explore locations',
                      style: context.textStyles.labelLarge?.withColor(cs.primary)),
                  ),
                ),
              );
              sectionBlocks.add(SizedBox(height: AppSpacing.md));
            }

            // Trusted NIH / MedlinePlus education library — always available.
            sectionBlocks.add(_SectionHeader(icon: Icons.school_rounded, label: 'Trusted health library'));
            sectionBlocks.add(NihEducationLinks(
              conditionName: widget.conditionName,
              milestoneTitle: widget.stepTitle,
              milestoneDescription: widget.stepDescription,
              showHeader: false,
            ));
            sectionBlocks.add(SizedBox(height: AppSpacing.md));

            if ((disclaimer ?? '').isNotEmpty) {
              sectionBlocks.add(
                Padding(
                  padding: AppSpacing.paddingSm,
                  child: Text(disclaimer!, style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant)),
                ),
              );
            }
          }

          debugPrint('[MilestoneEducationSheet v3] sections=${sectionBlocks.length}');

          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(sectionBlocks),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String stepTitle;
  const _Header({required this.stepTitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cs.primary.withValues(alpha: 0.12), cs.tertiary.withValues(alpha: 0.12)]),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.school, color: cs.primary),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              stepTitle,
              style: context.textStyles.titleMedium?.semiBold,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, color: cs.primary, size: 20),
          SizedBox(width: AppSpacing.sm),
          Text(label, style: context.textStyles.titleSmall?.semiBold),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: cs.onSurfaceVariant),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: context.textStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String title;
  final String detail;
  const _StepTile({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textStyles.titleSmall?.semiBold),
          SizedBox(height: 4),
          Text(detail, style: context.textStyles.bodyMedium),
        ],
      ),
    );
  }
}
