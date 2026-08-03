import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wellspring/services/resource_service.dart';
import 'package:wellspring/models/resource.dart';
import 'package:wellspring/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wellspring/services/commerce_service.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/openai/openai_config.dart';
import 'package:wellspring/widgets/nih_education_links.dart';

class MilestoneEducationPage extends StatefulWidget {
  final String stepTitle;
  final String? stepDescription;
  final String? conditionName;
  final String? conditionDetailsSummary;

  const MilestoneEducationPage({
    super.key,
    required this.stepTitle,
    this.stepDescription,
    this.conditionName,
    this.conditionDetailsSummary,
  });

  @override
  State<MilestoneEducationPage> createState() => _MilestoneEducationPageState();
}

/// Route payload for the go_router Learn more page.
///
/// We pass this via `GoRouterState.extra` to avoid stuffing long strings into
/// query parameters.
class MilestoneEducationArgs {
  final String stepTitle;
  final String? stepDescription;
  final String? conditionName;
  final String? conditionDetailsSummary;

  const MilestoneEducationArgs({
    required this.stepTitle,
    this.stepDescription,
    this.conditionName,
    this.conditionDetailsSummary,
  });
}

class _ResolvedLocation {
  final double lat;
  final double lng;
  final String? label;

  const _ResolvedLocation({required this.lat, required this.lng, this.label});
}

class _MilestoneEducationPageState extends State<MilestoneEducationPage> {
  Map<String, dynamic>? _edu;
  Map<String, List<Resource>> _nearbyByType = {};
  bool _loading = true;
  String? _error;
  String? _aiFallbackReason;
  bool _usedLocation = false;
  String? _locationLabel;
  bool _usedResourceFallback = false;
  double? _resourceRadiusMiles;
  Map<String, bool> _expandedResourceTypes = {};

  static const List<String> _resourceTypeOrder = ['therapist', 'hospital', 'center', 'service', 'pharmacy'];

  String _radiusLabel(double miles) => miles >= 10 ? miles.toStringAsFixed(0) : miles.toStringAsFixed(1);

  Map<String, dynamic> _offlineEducation() {
    final stepTitle = widget.stepTitle.trim();
    final desc = (widget.stepDescription ?? '').trim();
    final condition = (widget.conditionName ?? '').trim();

    final summaryParts = <String>[];
    if (condition.isNotEmpty) summaryParts.add('This step supports your $condition plan.');
    if (desc.isNotEmpty) summaryParts.add(desc);
    if (summaryParts.isEmpty) summaryParts.add('This step helps you make steady progress in a safe, sustainable way.');

    final keyConcepts = <String>[
      'Keep it small and repeatable (consistency beats intensity).',
      'Prepare your environment ahead of time (reduce friction).',
      'Track one simple signal so you can notice progress.',
    ];

    final stepByStep = <Map<String, dynamic>>[
      {'title': 'Start tiny', 'detail': 'Pick the smallest version you can do today (2–5 minutes).'},
      {'title': 'Set a cue', 'detail': 'Attach it to an existing routine (after breakfast / before bed).'},
      {'title': 'Do it safely', 'detail': 'Stop if pain spikes or you feel unwell; adjust and try again later.'},
      {'title': 'Log it', 'detail': 'Record a quick note so you can spot patterns over time.'},
    ];

    final queries = <String>[
      if (condition.isNotEmpty) '$condition ${stepTitle.isNotEmpty ? stepTitle : 'support'}',
      if (stepTitle.isNotEmpty) stepTitle,
      if (condition.isNotEmpty) '$condition local support services',
      'patient education resources',
    ].where((e) => e.trim().isNotEmpty).toSet().take(6).toList();

    final productQueries = <String>[
      if (stepTitle.isNotEmpty) stepTitle,
      if (condition.isNotEmpty) '$condition daily living aids',
      'adaptive equipment',
      'self care supplies',
    ].where((e) => e.trim().isNotEmpty).toSet().take(6).toList();

    return {
      'summary': summaryParts.join('\n\n'),
      'whyItMatters': 'Clear steps and supportive resources make it easier to stay consistent, learn what works for you, and reduce overwhelm.',
      'keyConcepts': keyConcepts,
      'stepByStep': stepByStep,
      'examples': <String>['“Today I’ll do the 2-minute version.”', '“I’ll set everything out the night before.”'],
      'pitfalls': <String>['Trying to do too much on a low-energy day.', 'Skipping tracking entirely (harder to learn patterns).'],
      'trackingIdeas': <String>[
        'How hard did it feel? (easy / medium / hard)',
        'Any pain change afterwards? (better / same / worse)',
        'Did you need help or equipment today?',
      ],
      'searchQueries': queries,
      'productQueries': productQueries,
      'disclaimer': 'Educational content only — not medical advice. If you have urgent concerns, contact a qualified professional.',
    };
  }

  Future<_ResolvedLocation?> _tryDeviceLocation() async {
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

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _ResolvedLocation(
        lat: position.latitude,
        lng: position.longitude,
        label: 'your current location',
      );
    } catch (e) {
      debugPrint('MilestoneEducationPage: device location failed (ignored): $e');
      return null;
    }
  }

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

  List<String> _orderedResourceTypes(Map<String, List<Resource>> grouped) {
    final ordered = <String>[];
    for (final type in _resourceTypeOrder) {
      if ((grouped[type]?.isNotEmpty ?? false) && !ordered.contains(type)) {
        ordered.add(type);
      }
    }
    final remaining = grouped.entries
        .where((entry) => entry.value.isNotEmpty && !ordered.contains(entry.key))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    ordered.addAll(remaining.map((entry) => entry.key));
    return ordered;
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
      // Ensure Supabase session is ready before making API calls
      final session = SupabaseConfig.client.auth.currentSession;
      if (session == null) {
        debugPrint('MilestoneEducationPage: Waiting for Supabase session...');
        // Give the session a moment to initialize
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final userProvider = context.read<UserProvider>();
      var user = userProvider.currentUser;
      if (user == null) {
        try {
          await userProvider.loadUser();
          user = userProvider.currentUser;
        } catch (e) {
          debugPrint('MilestoneEducationPage: loadUser failed (ignored): $e');
        }
      }
      if (user != null) {
        try {
          UserService().trackResourceView(user.id);
        } catch (e) {
          debugPrint('MilestoneEducationPage: trackResourceView failed (ignored): $e');
        }
      }

      double? userLat;
      double? userLng;
      String? locationLabel;
      try {
        final prefs = user?.preferences ?? const {};
        final loc = prefs['location'] as Map<String, dynamic>?;
        if (loc != null) {
          final latVal = loc['lat'];
          final lngVal = loc['lng'];
          if (latVal is num && lngVal is num) {
            userLat = latVal.toDouble();
            userLng = lngVal.toDouble();
          }
          final labelCandidate = (loc['label'] ?? loc['city'] ?? loc['postalCode'] ?? loc['zip'] ?? loc['state'] ?? '').toString().trim();
          if (labelCandidate.isNotEmpty) {
            locationLabel = labelCandidate;
          }
        }
      } catch (e) {
        debugPrint('MilestoneEducationPage: location parse failed (ignored): $e');
      }

      if (userLat == null || userLng == null) {
        final deviceLocation = await _tryDeviceLocation();
        if (deviceLocation != null) {
          userLat = deviceLocation.lat;
          userLng = deviceLocation.lng;
          locationLabel = deviceLocation.label;
        }
      }

      final resourceService = ResourceService();
      // Use the same searchResources method that Resources screen uses
      // (Google Places → OSM → Nominatim → curated Supabase)
      const baseDistance = 15.0;
      var usedFallbackResult = false;
      double? resolvedDistanceMiles = (userLat != null && userLng != null) ? baseDistance : null;
      List<Resource> resources = [];

      if (userLat != null && userLng != null) {
        debugPrint('MilestoneEducationPage: querying nearby resources at ($userLat, $userLng) within ${baseDistance}mi');
        try {
          resources = await resourceService
              .searchResources(
                userLat: userLat,
                userLng: userLng,
                maxDistance: baseDistance,
              )
              .timeout(const Duration(seconds: 12));
          debugPrint('MilestoneEducationPage: initial query (${baseDistance}mi) returned ${resources.length} resources');
        } catch (e, st) {
          debugPrint('MilestoneEducationPage: searchResources failed: $e\n$st');
        }

        // If nothing within 15 miles, gently expand once (mirrors "fallback" behavior)
        // so the section rarely appears empty.
        if (resources.isEmpty) {
          debugPrint('MilestoneEducationPage: trying fallback query within 100mi');
          try {
            resources = await resourceService
                .searchResources(
                  userLat: userLat,
                  userLng: userLng,
                  maxDistance: 100,
                )
                .timeout(const Duration(seconds: 12));
            debugPrint('MilestoneEducationPage: fallback query returned ${resources.length} resources');
            if (resources.isNotEmpty) {
              usedFallbackResult = true;
              resolvedDistanceMiles = 100;
            }
          } catch (e) {
            debugPrint('MilestoneEducationPage: expanded nearby fetch failed (ignored): $e');
          }
        } else {
          debugPrint('MilestoneEducationPage: found ${resources.length} resources within ${baseDistance}mi');
        }
      } else {
        debugPrint('MilestoneEducationPage: SKIPPING resource query because no location available');
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

      final orderedTypes = _orderedResourceTypes(grouped);
      final nextExpanded = <String, bool>{};
      for (var i = 0; i < orderedTypes.length; i++) {
        final type = orderedTypes[i];
        nextExpanded[type] = _expandedResourceTypes[type] ?? i == 0;
      }

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

      Map<String, dynamic> edu;
      try {
        edu = await OpenAIClient().generateMilestoneEducation(
          stepTitle: widget.stepTitle,
          stepDescription: widget.stepDescription,
          conditionName: widget.conditionName,
          conditionDetailsSummary: widget.conditionDetailsSummary,
          nearbyResources: nearbyForAi,
        );
        // Bridge: the UI expects productQueries for Amazon chips.
        edu['productQueries'] = (edu['productQueries'] as List?) ?? (edu['searchQueries'] as List?) ?? const <String>[];
      } catch (e) {
        debugPrint('MilestoneEducationPage: AI education failed; using offline template: $e');
        edu = _offlineEducation();
        _aiFallbackReason = e.toString();
      }

      if (!mounted) return;
      setState(() {
        _edu = edu;
        _loading = false;
        _nearbyByType = grouped;
        _usedLocation = userLat != null && userLng != null;
        _locationLabel = locationLabel;
        _usedResourceFallback = usedFallbackResult;
        _resourceRadiusMiles = resources.isEmpty ? null : resolvedDistanceMiles;
        _expandedResourceTypes = nextExpanded;
      });
    } catch (e) {
      debugPrint('Education load error (page): $e');
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Learn more'),
      ),
       body: _loading
          ? const Center(child: CenteredLoadingSkeleton())
          : ListView(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
              children: [
                _Header(stepTitle: widget.stepTitle),
                SizedBox(height: AppSpacing.md),
                 if (_aiFallbackReason != null) ...[
                   Container(
                     padding: AppSpacing.paddingMd,
                     margin: EdgeInsets.only(bottom: AppSpacing.md),
                     decoration: BoxDecoration(
                       color: cs.surfaceContainerHighest,
                       borderRadius: BorderRadius.circular(AppRadius.md),
                       border: Border.all(color: cs.outlineVariant),
                     ),
                     child: Row(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Icon(Icons.info_outline, color: cs.onSurfaceVariant),
                         SizedBox(width: AppSpacing.sm),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text('AI is unavailable right now', style: context.textStyles.titleSmall?.semiBold),
                               SizedBox(height: 2),
                               Text('Showing an offline version for now.', style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
                             ],
                           ),
                         ),
                       ],
                     ),
                   ),
                 ],
                if (_error != null) ...[
                  Row(children: [
                    Icon(Icons.error_outline, color: cs.error),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text("Couldn't load educational content. Please try again.", style: context.textStyles.bodyMedium)),
                  ]),
                ] else ...[
                  ..._buildSections(context),
                ]
              ],
            ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final result = <Widget>[];
    final summary = (_edu?['summary'] as String?)?.trim();
    final why = (_edu?['whyItMatters'] as String?)?.trim();
    final keyConcepts = List<String>.from(((_edu?['keyConcepts'] as List?) ?? []).map((e) => '$e'));
    final stepByStep = List<Map<String, dynamic>>.from(((_edu?['stepByStep'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
    final examples = List<String>.from(((_edu?['examples'] as List?) ?? []).map((e) => '$e'));
    final pitfalls = List<String>.from(((_edu?['pitfalls'] as List?) ?? []).map((e) => '$e'));
    final trackingIdeas = List<String>.from(((_edu?['trackingIdeas'] as List?) ?? []).map((e) => '$e'));
    final queries = List<String>.from(((_edu?['searchQueries'] as List?) ?? []).map((e) => '$e'));
    final productQueries = List<String>.from(((_edu?['productQueries'] as List?) ?? []).map((e) => '$e'));
    final disclaimer = (_edu?['disclaimer'] as String?)?.trim();

    if ((summary ?? '').isNotEmpty) {
      result.addAll([
        Text('Overview', style: context.textStyles.titleMedium?.semiBold),
        SizedBox(height: AppSpacing.xs),
        Text(summary!, style: context.textStyles.bodyMedium),
        SizedBox(height: AppSpacing.md),
      ]);
    }

    if ((why ?? '').isNotEmpty) {
      result.addAll([
        _SectionHeader(icon: Icons.favorite, label: 'Why this matters'),
        Text(why!, style: context.textStyles.bodyMedium),
        SizedBox(height: AppSpacing.md),
      ]);
    }

    if (keyConcepts.isNotEmpty) {
      result.add(_SectionHeader(icon: Icons.lightbulb, label: 'Key concepts'));
      result.addAll(keyConcepts.map((e) => _Bullet(text: e)));
      result.add(SizedBox(height: AppSpacing.md));
    }

    if (stepByStep.isNotEmpty) {
      result.add(_SectionHeader(icon: Icons.checklist, label: 'Step-by-step'));
      result.addAll(stepByStep.map((m) => _StepTile(title: (m['title'] ?? '').toString(), detail: (m['detail'] ?? '').toString())));
      result.add(SizedBox(height: AppSpacing.md));
    }

    if (examples.isNotEmpty) {
      result.add(_SectionHeader(icon: Icons.task_alt, label: 'Examples'));
      result.addAll(examples.map((e) => _Bullet(text: e)));
      result.add(SizedBox(height: AppSpacing.md));
    }

    if (pitfalls.isNotEmpty) {
      result.add(_SectionHeader(icon: Icons.report_problem, label: 'Common pitfalls'));
      result.addAll(pitfalls.map((e) => _Bullet(text: e)));
      result.add(SizedBox(height: AppSpacing.md));
    }

    if (trackingIdeas.isNotEmpty) {
      result.add(_SectionHeader(icon: Icons.show_chart, label: 'How to track'));
      result.addAll(trackingIdeas.map((e) => _Bullet(text: e)));
      result.add(SizedBox(height: AppSpacing.md));
    }

    if (queries.isNotEmpty) {
      result.addAll([
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
      result.add(_SectionHeader(icon: Icons.place, label: _usedLocation ? 'Nearby support' : 'Helpful resources'));
      if (_usedLocation && (_locationLabel?.trim().isNotEmpty ?? false)) {
        final radius = _resourceRadiusMiles ?? 15.0;
        result.add(Text('Within ~${_radiusLabel(radius)} miles of ${_locationLabel!}', style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)));
        result.add(SizedBox(height: AppSpacing.sm));
      } else if (!_usedLocation) {
        result.add(Text('Add your location in Account Settings > Profile to tailor these matches.', style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)));
        result.add(SizedBox(height: AppSpacing.sm));
      }
      if (_usedResourceFallback) {
        final fallbackText = _usedLocation
            ? 'Nothing matched this milestone exactly, so we surfaced trusted providers near you instead.'
            : 'Nothing matched this milestone exactly, so here are trusted providers we recommend for this milestone.';
        result.add(Text(fallbackText,
            style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)));
        result.add(SizedBox(height: AppSpacing.sm));
      }

      final orderedTypes = _orderedResourceTypes(_nearbyByType);
      for (var i = 0; i < orderedTypes.length; i++) {
        final type = orderedTypes[i];
        final resources = _nearbyByType[type] ?? <Resource>[];
        if (resources.isEmpty) continue;
        final isExpanded = _expandedResourceTypes[type] ?? i == 0;
        result.add(_ResourceGroupSection(
          label: _typeLabel(type),
          icon: _typeIcon(type),
          resources: resources,
          expanded: isExpanded,
          onToggle: () {
            setState(() {
              final current = _expandedResourceTypes[type] ?? false;
              _expandedResourceTypes[type] = !current;
            });
          },
          itemBuilder: (ctx, resource) => _resourceTile(ctx, resource),
        ));
      }

      result.add(
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () {
              debugPrint('[MilestoneEducationPage] Explore locations tapped');
              context.go('/resources?tab=explore');
            },
            icon: Icon(Icons.travel_explore, color: cs.primary),
            label: Text('Explore locations', style: context.textStyles.labelLarge?.withColor(cs.primary)),
          ),
        ),
      );
      result.add(SizedBox(height: AppSpacing.md));
    } else if (_usedLocation) {
      result.add(_SectionHeader(icon: Icons.place, label: 'Nearby support'));
      result.add(Text('We couldn\'t find matching providers near ${_locationLabel ?? 'your saved location'} yet. Try broadening your goal or updating your location.',
          style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)));
      result.add(SizedBox(height: AppSpacing.sm));
      result.add(
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () {
              debugPrint('[MilestoneEducationPage] Explore locations tapped');
              context.go('/resources?tab=explore');
            },
            icon: Icon(Icons.travel_explore, color: cs.primary),
            label: Text('Explore locations', style: context.textStyles.labelLarge?.withColor(cs.primary)),
          ),
        ),
      );
      result.add(SizedBox(height: AppSpacing.md));
    } else {
      result.add(_SectionHeader(icon: Icons.place, label: 'Helpful resources'));
      result.add(Text('Add your location in Account Settings > Profile to surface nearby therapists, resources, and hospitals.',
          style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)));
      result.add(SizedBox(height: AppSpacing.sm));
      result.add(
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () {
              debugPrint('[MilestoneEducationPage] Explore locations tapped');
              context.go('/resources?tab=explore');
            },
            icon: Icon(Icons.travel_explore, color: cs.primary),
            label: Text('Explore locations', style: context.textStyles.labelLarge?.withColor(cs.primary)),
          ),
        ),
      );
      result.add(SizedBox(height: AppSpacing.md));
    }

    if (productQueries.isNotEmpty) {
      result.add(_SectionHeader(icon: Icons.shopping_bag, label: 'Helpful products'));
      result.add(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: productQueries.map((q) {
          return ActionChip(
            label: Text(q),
            avatar: const Icon(Icons.open_in_new, size: 16),
            onPressed: () async {
              final url = CommerceService().amazonSearchUrl(q);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          );
        }).toList(),
      ));
      result.add(SizedBox(height: AppSpacing.md));
    }

    // Trusted NIH / MedlinePlus education library — always available.
    result.add(_SectionHeader(icon: Icons.school_rounded, label: 'Trusted health library'));
    result.add(NihEducationLinks(
      conditionName: widget.conditionName,
      milestoneTitle: widget.stepTitle,
      milestoneDescription: widget.stepDescription,
      showHeader: false,
    ));
    result.add(SizedBox(height: AppSpacing.md));

    if ((disclaimer ?? '').isNotEmpty) {
      result.add(
        Padding(
          padding: AppSpacing.paddingSm,
          child: Text(disclaimer!, style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant)),
        ),
      );
    }

    return result;
  }
}

class _ResourceGroupSection extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Resource> resources;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget Function(BuildContext context, Resource resource) itemBuilder;

  const _ResourceGroupSection({
    required this.label,
    required this.icon,
    required this.resources,
    required this.expanded,
    required this.onToggle,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: AppSpacing.paddingSm,
              child: Row(
                children: [
                  Icon(icon, color: cs.primary),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(label, style: context.textStyles.titleSmall?.semiBold)),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedCrossFade(
              crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 220),
              sizeCurve: Curves.easeInOut,
              firstChild: Column(
                children: [
                  const Divider(height: 1),
                  ..._buildResourceTiles(context),
                  SizedBox(height: AppSpacing.sm),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildResourceTiles(BuildContext context) {
    final tiles = <Widget>[];
    for (var i = 0; i < resources.length; i++) {
      tiles.add(Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: itemBuilder(context, resources[i]),
      ));
      if (i != resources.length - 1) {
        tiles.add(const Divider(height: 1));
      }
    }
    return tiles;
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

class _ProductTile extends StatelessWidget {
  final String name;
  final String detail;
  final VoidCallback onShop;
  const _ProductTile({required this.name, required this.detail, required this.onShop});

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: context.textStyles.titleSmall?.semiBold, maxLines: 2, overflow: TextOverflow.ellipsis),
                SizedBox(height: 4),
                Text(detail, style: context.textStyles.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onShop,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Shop'),
          )
        ],
      ),
    );
  }
}
