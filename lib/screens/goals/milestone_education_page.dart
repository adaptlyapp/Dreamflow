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
import 'package:wellspring/services/vr_agency_service.dart';
import 'package:wellspring/models/vr_agency.dart';

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
  List<VRAgency> _vrAgencies = [];
  bool _showVRAgencies = false;

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
      'examples': <String>['"Today I\'ll do the 2-minute version."', '"I\'ll set everything out the night before."'],
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

  /// Builds a smart search query for resources based on milestone context
  String _buildResourceSearchQuery() {
    final parts = <String>[];
    final stepTitle = widget.stepTitle.toLowerCase();
    final stepDesc = (widget.stepDescription ?? '').toLowerCase();
    final condition = (widget.conditionName ?? '').toLowerCase();

    // Extract key action verbs and nouns from milestone title
    final titleWords = stepTitle.split(RegExp(r'\s+'));
    
    // Common therapy/service keywords that indicate what type of provider to look for
    if (stepTitle.contains('physical therapy') || stepTitle.contains('pt ')) {
      parts.add('physical therapy');
    } else if (stepTitle.contains('occupational therapy') || stepTitle.contains('ot ')) {
      parts.add('occupational therapy');
    } else if (stepTitle.contains('speech') || stepTitle.contains('language')) {
      parts.add('speech therapy');
    } else if (stepTitle.contains('driving') || stepTitle.contains('adaptive driving')) {
      parts.add('driving rehabilitation specialist');
    } else if (stepTitle.contains('nutrition') || stepTitle.contains('diet') || stepTitle.contains('meal')) {
      parts.add('nutritionist dietitian');
    } else if (stepTitle.contains('pain')) {
      parts.add('pain management clinic');
    } else if (stepTitle.contains('counseling') || stepTitle.contains('mental health') || stepTitle.contains('anxiety') || stepTitle.contains('depression')) {
      parts.add('mental health counselor');
    } else if (stepTitle.contains('support group') || stepTitle.contains('peer support')) {
      parts.add('support group');
    } else if (stepTitle.contains('equipment') || stepTitle.contains('supplies') || stepTitle.contains('wheelchair') || stepTitle.contains('adaptive')) {
      parts.add('durable medical equipment supplier');
    } else if (stepTitle.contains('medication') || stepTitle.contains('prescription')) {
      parts.add('pharmacy');
    } else {
      // Generic: use condition + therapy
      if (condition.isNotEmpty) {
        parts.add(condition);
      }
      parts.add('rehabilitation therapy');
    }

    return parts.join(' ');
  }

  /// Builds a fallback query when the primary search returns no results
  String _buildFallbackResourceQuery() {
    final condition = (widget.conditionName ?? '').toLowerCase();
    
    if (condition.contains('stroke')) return 'stroke rehabilitation center';
    if (condition.contains('spinal cord')) return 'spinal cord injury rehabilitation';
    if (condition.contains('brain injury') || condition.contains('tbi')) return 'traumatic brain injury rehabilitation';
    if (condition.contains('cardiac') || condition.contains('heart')) return 'cardiac rehabilitation';
    if (condition.contains('orthopedic') || condition.contains('joint') || condition.contains('fracture')) return 'orthopedic rehabilitation';
    if (condition.contains('parkinson')) return 'parkinsons therapy center';
    if (condition.contains('multiple sclerosis') || condition.contains('ms')) return 'multiple sclerosis clinic';
    
    // Generic fallback
    return condition.isNotEmpty ? '$condition specialist' : 'physical therapy rehabilitation';
  }

  /// Detects if this milestone is vocational/employment-related OR disability/driving-related
  /// (VR agencies help with employment, adaptive technology, driving modifications, etc.)
  bool _isVocationalMilestone() {
    final titleLower = widget.stepTitle.toLowerCase();
    final descLower = (widget.stepDescription ?? '').toLowerCase();
    final conditionLower = (widget.conditionName ?? '').toLowerCase();
    final combined = '$titleLower $descLower $conditionLower';

    final vocationalKeywords = [
      // Employment-related
      'work', 'job', 'employment', 'career', 'vocational', 'voc rehab',
      'return to work', 'workplace', 'training', 'education', 'college',
      'certification', 'resume', 'interview', 'self-employed',
      'business', 'telecommute', 'remote work', 'tuition', 'degree',
      
      // Disability-related (VR provides assistive tech, modifications, etc.)
      'disability', 'disabled', 'handicap', 'accommodation', 'accessible',
      'accessibility', 'adaptive equipment', 'adaptive technology',
      'assistive technology', 'assistive device', 'workstation',
      'modification', 'adapted', 'independent living',
      
      // Driving-related (VR helps with adaptive driving equipment & training)
      'driving', 'drive', 'driver', 'vehicle', 'car', 'transport',
      'adaptive driving', 'driving assessment', 'hand controls',
      'vehicle modification', 'drivers license', 'dmv',
    ];

    return vocationalKeywords.any((keyword) => combined.contains(keyword));
  }

  /// Determines if we should prioritize blind services (vs general VR)
  bool _shouldPrioritizeBlindServices() {
    final conditionLower = (widget.conditionName ?? '').toLowerCase();
    final titleLower = widget.stepTitle.toLowerCase();
    final descLower = (widget.stepDescription ?? '').toLowerCase();
    final combined = '$conditionLower $titleLower $descLower';

    final blindKeywords = [
      'blind', 'vision', 'visually impaired', 'low vision', 'sight',
      'retina', 'glaucoma', 'macular degeneration', 'eye',
    ];

    return blindKeywords.any((keyword) => combined.contains(keyword));
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
      String? userState;
      String? userStateAbbr;
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
          // Extract state information for VR agencies
          userState = (loc['state'] ?? '').toString().trim();
          userStateAbbr = (loc['stateAbbr'] ?? loc['abbr'] ?? '').toString().trim();
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
      // Build a smart search query from milestone context
      final searchQuery = _buildResourceSearchQuery();
      
      // Use the same searchResources method that Resources screen uses
      // (Google Places → OSM → Nominatim → curated Supabase)
      const baseDistance = 15.0;
      var usedFallbackResult = false;
      double? resolvedDistanceMiles = (userLat != null && userLng != null) ? baseDistance : null;
      List<Resource> resources = [];

      if (userLat != null && userLng != null) {
        debugPrint('MilestoneEducationPage: querying nearby resources for "$searchQuery" at ($userLat, $userLng) within ${baseDistance}mi');
        try {
          resources = await resourceService
              .searchResources(
                query: searchQuery,
                userLat: userLat,
                userLng: userLng,
                maxDistance: baseDistance,
              )
              .timeout(const Duration(seconds: 12));
          debugPrint('MilestoneEducationPage: initial query (${baseDistance}mi) returned ${resources.length} resources');
        } catch (e, st) {
          debugPrint('MilestoneEducationPage: searchResources failed: $e\n$st');
        }

        // If nothing within 15 miles, try a broader query (condition-based or generic therapy)
        if (resources.isEmpty) {
          final fallbackQuery = _buildFallbackResourceQuery();
          debugPrint('MilestoneEducationPage: trying fallback query "$fallbackQuery" within 100mi');
          try {
            resources = await resourceService
                .searchResources(
                  query: fallbackQuery,
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

      // Load VR agencies if this is a vocational milestone and we have state info
      List<VRAgency> vrAgencies = [];
      bool showVR = false;
      final isVocational = _isVocationalMilestone();
      debugPrint('MilestoneEducationPage: VR check - isVocational=$isVocational, userState="$userState", userStateAbbr="$userStateAbbr"');
      if (isVocational) {
        try {
          final vrService = VRAgencyService();
          if (userStateAbbr != null && userStateAbbr.isNotEmpty) {
            debugPrint('MilestoneEducationPage: Querying VR by state abbr: $userStateAbbr');
            vrAgencies = await vrService.getAgenciesByState(userStateAbbr);
          } else if (userState != null && userState.isNotEmpty) {
            debugPrint('MilestoneEducationPage: Querying VR by state name: $userState');
            vrAgencies = await vrService.getAgenciesByStateName(userState);
          } else {
            debugPrint('MilestoneEducationPage: No state info available for VR query');
          }

          // Prioritize blind services or general VR based on context
          if (vrAgencies.isNotEmpty) {
            final prioritizeBlind = _shouldPrioritizeBlindServices();
            vrAgencies.sort((a, b) {
              if (prioritizeBlind) {
                if (a.isBlindServices && !b.isBlindServices) return -1;
                if (!a.isBlindServices && b.isBlindServices) return 1;
              } else {
                if (a.isGeneralVR && !b.isGeneralVR) return -1;
                if (!a.isGeneralVR && b.isGeneralVR) return 1;
              }
              return 0;
            });
            showVR = true;
            debugPrint('MilestoneEducationPage: Loaded ${vrAgencies.length} VR agencies for state');
          }
        } catch (e) {
          debugPrint('MilestoneEducationPage: VR agency fetch failed (ignored): $e');
        }
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
        _vrAgencies = vrAgencies;
        _showVRAgencies = showVR;
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
      backgroundColor: cs.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Learn more', style: context.textStyles.titleLarge?.semiBold),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
       body: _loading
          ? const Center(child: CenteredLoadingSkeleton())
          : Stack(
              children: [
                // Subtle gradient background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cs.primary.withValues(alpha: 0.05),
                          cs.surface,
                        ],
                        stops: const [0.0, 0.3],
                      ),
                    ),
                  ),
                ),
                ListView(
                  padding: EdgeInsets.fromLTRB(AppSpacing.lg, kToolbarHeight + AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
                  children: [
                    _Header(stepTitle: widget.stepTitle),
                    SizedBox(height: AppSpacing.lg),
                    if (_aiFallbackReason != null) ...[
                   Container(
                     padding: AppSpacing.paddingMd,
                     margin: EdgeInsets.only(bottom: AppSpacing.lg),
                     decoration: BoxDecoration(
                       color: cs.tertiaryContainer.withValues(alpha: 0.3),
                       borderRadius: BorderRadius.circular(AppRadius.lg),
                       border: Border.all(color: cs.tertiary.withValues(alpha: 0.2), width: 1),
                     ),
                     child: Row(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Container(
                           padding: EdgeInsets.all(AppSpacing.xs),
                           decoration: BoxDecoration(
                             color: cs.tertiary.withValues(alpha: 0.2),
                             borderRadius: BorderRadius.circular(AppRadius.sm),
                           ),
                           child: Icon(Icons.cloud_off_outlined, color: cs.tertiary, size: 20),
                         ),
                         SizedBox(width: AppSpacing.md),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text('AI is unavailable right now', style: context.textStyles.titleSmall?.semiBold),
                               SizedBox(height: 4),
                               Text('Showing an offline version for now.', style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
                             ],
                           ),
                         ),
                       ],
                     ),
                   ),
                 ],
                if (_error != null) ...[
                  Container(
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: cs.error.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: cs.error),
                        SizedBox(width: AppSpacing.md),
                        Expanded(child: Text("Couldn't load educational content. Please try again.", style: context.textStyles.bodyMedium)),
                      ],
                    ),
                  ),
                ] else ...[
                  ..._buildSections(context),
                ]
              ],
            ),
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
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.auto_stories_rounded, color: cs.primary, size: 18),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Overview', style: context.textStyles.titleMedium?.semiBold),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Text(summary!, style: context.textStyles.bodyMedium?.copyWith(height: 1.5)),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg),
      ]);
    }

    if ((why ?? '').isNotEmpty) {
      result.addAll([
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: cs.tertiaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.tertiary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: cs.tertiary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.favorite_rounded, color: cs.tertiary, size: 18),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Why this matters', style: context.textStyles.titleMedium?.semiBold),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Text(why!, style: context.textStyles.bodyMedium?.copyWith(height: 1.5)),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg),
      ]);
    }

    if (keyConcepts.isNotEmpty) {
      result.add(
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.lightbulb_rounded, color: cs.secondary, size: 18),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Key concepts', style: context.textStyles.titleMedium?.semiBold),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              ...keyConcepts.map((e) => _Bullet(text: e)),
            ],
          ),
        ),
      );
      result.add(SizedBox(height: AppSpacing.lg));
    }

    if (stepByStep.isNotEmpty) {
      result.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.format_list_numbered_rounded, color: cs.primary, size: 18),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Step-by-step', style: context.textStyles.titleMedium?.semiBold),
                ],
              ),
            ),
            ...stepByStep.asMap().entries.map((entry) => _StepTile(
              number: entry.key + 1,
              title: (entry.value['title'] ?? '').toString(),
              detail: (entry.value['detail'] ?? '').toString(),
            )),
          ],
        ),
      );
      result.add(SizedBox(height: AppSpacing.lg));
    }

    if (examples.isNotEmpty) {
      result.add(
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.chat_bubble_outline_rounded, color: cs.secondary, size: 18),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Examples', style: context.textStyles.titleMedium?.semiBold),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              ...examples.map((e) => _ExampleBubble(text: e)),
            ],
          ),
        ),
      );
      result.add(SizedBox(height: AppSpacing.lg));
    }

    if (pitfalls.isNotEmpty) {
      result.add(
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.error.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: cs.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.warning_rounded, color: cs.error, size: 18),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Common pitfalls', style: context.textStyles.titleMedium?.semiBold),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              ...pitfalls.map((e) => _Bullet(text: e)),
            ],
          ),
        ),
      );
      result.add(SizedBox(height: AppSpacing.lg));
    }

    if (trackingIdeas.isNotEmpty) {
      result.add(
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.insights_rounded, color: cs.tertiary, size: 18),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('How to track', style: context.textStyles.titleMedium?.semiBold),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              ...trackingIdeas.map((e) => _Bullet(text: e)),
            ],
          ),
        ),
      );
      result.add(SizedBox(height: AppSpacing.lg));
    }

    if (queries.isNotEmpty) {
      result.addAll([
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.search_rounded, color: cs.primary, size: 18),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Research further', style: context.textStyles.titleMedium?.semiBold),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: queries.map((q) => ActionChip(
                  label: Text(q, style: context.textStyles.labelMedium),
                  avatar: Icon(Icons.open_in_new, size: 16, color: cs.primary),
                  backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
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
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg),
      ]);
    }

    // Vocational Rehabilitation section
    if (_showVRAgencies && _vrAgencies.isNotEmpty) {
      result.add(_buildVRAgencySection(context));
      result.add(SizedBox(height: AppSpacing.lg));
    }

    final hasNearby = _nearbyByType.values.any((items) => items.isNotEmpty);
    if (hasNearby) {
      result.add(
        Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.location_on_rounded, color: cs.secondary, size: 18),
              ),
              SizedBox(width: AppSpacing.sm),
              Text(_usedLocation ? 'Nearby support' : 'Helpful resources', style: context.textStyles.titleMedium?.semiBold),
            ],
          ),
        ),
      );
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
        Padding(
          padding: EdgeInsets.only(top: AppSpacing.md),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () {
                debugPrint('[MilestoneEducationPage] Explore locations tapped');
                context.go('/resources?tab=explore');
              },
              icon: Icon(Icons.travel_explore, color: cs.primary),
              label: Text('Explore all locations', style: context.textStyles.labelLarge?.withColor(cs.primary)),
            ),
          ),
        ),
      );
      result.add(SizedBox(height: AppSpacing.lg));
    } else if (_usedLocation) {
      result.add(
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.search_off_rounded, color: cs.secondary, size: 18),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Nearby support', style: context.textStyles.titleMedium?.semiBold),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Text('We couldn\'t find matching providers near ${_locationLabel ?? 'your saved location'} yet. Try broadening your goal or updating your location.',
                  style: context.textStyles.bodyMedium?.copyWith(height: 1.5)),
              SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    debugPrint('[MilestoneEducationPage] Explore locations tapped');
                    context.go('/resources?tab=explore');
                  },
                  icon: Icon(Icons.travel_explore, color: cs.primary),
                  label: Text('Explore all locations', style: context.textStyles.labelLarge?.withColor(cs.primary)),
                ),
              ),
            ],
          ),
        ),
      );
      result.add(SizedBox(height: AppSpacing.lg));
    } else {
      result.add(
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.location_searching_rounded, color: cs.secondary, size: 18),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Helpful resources', style: context.textStyles.titleMedium?.semiBold),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Text('Add your location in Account Settings > Profile to surface nearby therapists, resources, and hospitals.',
                  style: context.textStyles.bodyMedium?.copyWith(height: 1.5)),
              SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    debugPrint('[MilestoneEducationPage] Explore locations tapped');
                    context.go('/resources?tab=explore');
                  },
                  icon: Icon(Icons.travel_explore, color: cs.primary),
                  label: Text('Explore all locations', style: context.textStyles.labelLarge?.withColor(cs.primary)),
                ),
              ),
            ],
          ),
        ),
      );
      result.add(SizedBox(height: AppSpacing.lg));
    }

    if (productQueries.isNotEmpty) {
      result.add(
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.shopping_bag_rounded, color: cs.tertiary, size: 18),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('Helpful products', style: context.textStyles.titleMedium?.semiBold),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: productQueries.map((q) {
                  return ActionChip(
                    label: Text(q, style: context.textStyles.labelMedium),
                    avatar: Icon(Icons.open_in_new, size: 16, color: cs.tertiary),
                    backgroundColor: cs.tertiaryContainer.withValues(alpha: 0.5),
                    side: BorderSide(color: cs.tertiary.withValues(alpha: 0.3)),
                    onPressed: () async {
                      final url = CommerceService().amazonSearchUrl(q);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
      result.add(SizedBox(height: AppSpacing.lg));
    }

    // Trusted NIH / MedlinePlus education library — always available.
    result.add(
      Container(
        width: double.infinity,
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.local_library_rounded, color: cs.primary, size: 18),
                ),
                SizedBox(width: AppSpacing.sm),
                Text('Trusted health library', style: context.textStyles.titleMedium?.semiBold),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            NihEducationLinks(
              conditionName: widget.conditionName,
              milestoneTitle: widget.stepTitle,
              milestoneDescription: widget.stepDescription,
              showHeader: false,
            ),
          ],
        ),
      ),
    );
    result.add(SizedBox(height: AppSpacing.lg));

    if ((disclaimer ?? '').isNotEmpty) {
      result.add(
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(disclaimer!, style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant).copyWith(height: 1.4)),
              ),
            ],
          ),
        ),
      );
    }

    return result;
  }

  Widget _buildVRAgencySection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.secondaryContainer.withValues(alpha: 0.6),
            cs.tertiaryContainer.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: cs.secondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.work_rounded, color: cs.secondary, size: 24),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vocational Rehabilitation',
                      style: context.textStyles.titleMedium?.semiBold,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Government-funded program to help you prepare for, obtain, or advance in employment',
                      style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voc Rehab may pay for or help coordinate:',
                  style: context.textStyles.labelLarge?.semiBold,
                ),
                SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    'College tuition',
                    'Job training',
                    'Assistive technology',
                    'Vehicle modifications',
                    'Career counseling',
                    'Workplace accommodations',
                  ].map((item) => Chip(
                    label: Text(item, style: context.textStyles.labelSmall),
                    backgroundColor: cs.secondaryContainer.withValues(alpha: 0.6),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  )).toList(),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'Your ${_vrAgencies.length > 1 ? 'state VR offices' : 'state VR office'}:',
            style: context.textStyles.titleSmall?.semiBold,
          ),
          SizedBox(height: AppSpacing.sm),
          ..._vrAgencies.map((agency) => _buildVRAgencyTile(context, agency)),
          SizedBox(height: AppSpacing.sm),
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: cs.primary),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Eligibility usually requires: (1) documented disability, (2) the disability creates an employment barrier, and (3) VR services would help you reach a realistic employment goal.',
                    style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant).copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVRAgencyTile(BuildContext context, VRAgency agency) {
    final cs = Theme.of(context).colorScheme;
    
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agency.agencyName,
                      style: context.textStyles.titleSmall?.semiBold,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: agency.isBlindServices 
                            ? cs.tertiaryContainer.withValues(alpha: 0.6)
                            : cs.secondaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        agency.agencyTypeLabel,
                        style: context.textStyles.labelSmall?.semiBold.withColor(
                          agency.isBlindServices ? cs.tertiary : cs.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (agency.primaryPhone != null) ...[
            SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: () async {
                final phone = agency.primaryPhone!;
                final url = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^\d+]'), '')}');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: Row(
                children: [
                  Icon(Icons.phone_rounded, size: 16, color: cs.primary),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    agency.primaryPhone!,
                    style: context.textStyles.bodyMedium?.withColor(cs.primary),
                  ),
                  if (agency.tollFree != null && agency.tollFree!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          'Toll-free',
                          style: context.textStyles.labelSmall?.withColor(cs.primary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (agency.website != null && agency.website!.isNotEmpty) ...[
            SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: () async {
                final url = Uri.parse(agency.website!);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: Row(
                children: [
                  Icon(Icons.language_rounded, size: 16, color: cs.primary),
                  SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Visit website',
                      style: context.textStyles.bodyMedium?.withColor(cs.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.open_in_new, size: 14, color: cs.primary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(icon, color: cs.secondary, size: 20),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(label, style: context.textStyles.titleSmall?.semiBold)),
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text('${resources.length}', style: context.textStyles.labelSmall?.semiBold.withColor(cs.secondary)),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOutCubic,
            firstCurve: Curves.easeInOutCubic,
            secondCurve: Curves.easeInOutCubic,
            firstChild: Column(
              children: [
                Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                ..._buildResourceTiles(context),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildResourceTiles(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tiles = <Widget>[];
    for (var i = 0; i < resources.length; i++) {
      tiles.add(Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: itemBuilder(context, resources[i]),
      ));
      if (i != resources.length - 1) {
        tiles.add(Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
        ));
      }
    }
    tiles.add(SizedBox(height: AppSpacing.sm));
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
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withValues(alpha: 0.8),
            cs.tertiaryContainer.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.school_rounded, color: cs.primary, size: 28),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            stepTitle,
            style: context.textStyles.headlineSmall?.semiBold,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
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
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: context.textStyles.bodyMedium?.copyWith(height: 1.5))),
        ],
      ),
    );
  }
}

class _ExampleBubble extends StatelessWidget {
  final String text;
  const _ExampleBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, color: cs.secondary, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: context.textStyles.bodyMedium?.copyWith(
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int number;
  final String title;
  final String detail;
  const _StepTile({required this.number, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            margin: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: Text(
                '$number',
                style: context.textStyles.titleLarge?.semiBold.withColor(cs.primary),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, AppSpacing.md, AppSpacing.md, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.titleSmall?.semiBold),
                  SizedBox(height: 6),
                  Text(detail, style: context.textStyles.bodyMedium?.copyWith(height: 1.5)),
                ],
              ),
            ),
          ),
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
