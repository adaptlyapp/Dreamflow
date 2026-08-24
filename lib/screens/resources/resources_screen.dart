import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wellspring/models/resource.dart';
import 'package:wellspring/services/resource_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/widgets/rating_stars.dart';
import 'package:wellspring/services/ratings_service.dart';
import 'package:wellspring/models/resource_rating.dart';
import 'package:wellspring/widgets/hours_badge.dart';
import 'package:wellspring/widgets/phone_link.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/widgets/recommend_resource_sheet.dart';
import 'package:wellspring/widgets/brand_logo.dart';
import 'package:geolocator/geolocator.dart';
// Saved-location: reintroduced explicit save to profile action

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final _resourceService = ResourceService();
  final _searchController = TextEditingController();
  final _locationController = TextEditingController();
  final _userService = UserService();
    final _ratingsService = RatingsService();
  List<Resource> _resources = [];
  // Keep the full list from the latest fetch; search filters this locally
  List<Resource> _allResources = [];
  bool _isLoading = true;
  String _typeFilter = 'all';
  String _locationFilter = 'all';
  // Local specialty filters (lowercase keys)
  final Set<String> _specialtyFilters = <String>{};
  double? _userLat;
  double? _userLng;
  String? _userLocationLabel;
  double? _maxDistanceMiles; // null = All
  // Advanced filters
  bool _openNow = false;
  double _minRating = 0;
  int _minReviews = 0;
  final Set<int> _priceLevels = <int>{}; // 0..4
  bool _sortByRating = false;
  bool _rankByDistance = false;
  final Set<String> _googleTypes = <String>{};
  String? _region; // country code from geocode
  String? _language = 'en';
  // Therapists: only include names that explicitly contain "therapy"/"therapist"
  bool _therapyNameOnly = false;
  bool _fallbackRunning = false;
  // Saved-location removed: only typed location is used for this session
  final Map<String, ResourceRatingSummary> _summaries = {};
  // Debounce for type-to-search
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _initializeLocationAndLoad();
  }

  Future<void> _initializeLocationAndLoad() async {
    // Try to get user's current location automatically
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.deniedForever && permission != LocationPermission.denied) {
          final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
          if (mounted) {
            setState(() {
              _userLat = position.latitude;
              _userLng = position.longitude;
              _userLocationLabel = 'Current location';
              _locationController.text = 'Current location';
            });
            debugPrint('ResourcesScreen: Got location: $_userLat, $_userLng');
          }
        } else {
          debugPrint('ResourcesScreen: Location permission denied');
        }
      } else {
        debugPrint('ResourcesScreen: Location services disabled');
      }
    } catch (e) {
      debugPrint('ResourcesScreen: Could not get current location: $e');
    }
    await _loadResources();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Removed: hydrate from user profile location

  Future<void> _loadResources() async {
    setState(() => _isLoading = true);
    final resources = await _resourceService.searchResources(
      // Always fetch by location and filters; apply text search locally
      query: null,
      type: _typeFilter == 'all' ? null : _typeFilter,
      location: _locationFilter == 'all' ? null : _locationFilter,
      userLat: _userLat,
      userLng: _userLng,
      maxDistance: _maxDistanceMiles,
      openNow: _openNow,
      minRating: _minRating > 0 ? _minRating : null,
      minUserRatings: _minReviews > 0 ? _minReviews : null,
      priceLevels: _priceLevels.isEmpty ? null : _priceLevels.toList(),
      sortByRating: _sortByRating,
      language: _language,
      region: _region,
      rankBy: _rankByDistance ? 'distance' : 'prominence',
      includeGoogleTypes: _googleTypes.isEmpty ? null : _googleTypes.toList(),
    );
    // Apply therapist name exacting filter and grouping preference
    List<Resource> adjusted = resources;
    if (_typeFilter == 'therapist') {
      final isTherapyName = (Resource r) {
        final n = r.name.toLowerCase();
        return n.contains('therapy') || n.contains('therapist');
      };
      if (_therapyNameOnly) {
        adjusted = adjusted.where(isTherapyName).toList();
      } else {
        // Bubble exact matches to the top
        adjusted.sort((a, b) {
          final aExact = (a.name.toLowerCase().contains('therapy') || a.name.toLowerCase().contains('therapist')) ? 1 : 0;
          final bExact = (b.name.toLowerCase().contains('therapy') || b.name.toLowerCase().contains('therapist')) ? 1 : 0;
          if (aExact != bExact) return bExact.compareTo(aExact);
          return a.distance.compareTo(b.distance);
        });
      }
    }
    setState(() {
      _allResources = adjusted;
      _isLoading = false;
    });
    // Apply any in-progress text filter to the freshly loaded list
    _applyLocalTextFilter();
    // After loading resources, fetch rating summaries for top 20 and refresh Google ones if stale
    unawaited(_loadRatingsForResources());
  }

  void _debouncedSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _applyLocalTextFilter();
    });
  }

  void _runSearch() {
    // Only filter locally; fetching happens when location/filters change
    _applyLocalTextFilter();
  }

  void _applyLocalTextFilter() {
    final q = _searchController.text.trim().toLowerCase();
    debugPrint('ResourcesScreen._applyLocalTextFilter q="$q" all=${_allResources.length} spec=${_specialtyFilters.join(',')}');
    List<Resource> filtered = List<Resource>.from(_allResources);
    if (q.isNotEmpty) {
      filtered = filtered.where((r) {
        final n = r.name.toLowerCase();
        final addr = r.address.toLowerCase();
        final loc = r.location.toLowerCase();
        final typ = r.type.toLowerCase();
        final specs = r.specialty.map((s) => s.toLowerCase());
        return n.contains(q) || addr.contains(q) || loc.contains(q) || typ.contains(q) || specs.any((s) => s.contains(q));
      }).toList();
    }
    if (_specialtyFilters.isNotEmpty) {
      filtered = filtered.where((r) {
        final specs = r.specialty.map((s) => s.toLowerCase());
        return specs.any((s) => _specialtyFilters.contains(s));
      }).toList();
    }
    setState(() => _resources = filtered);
    debugPrint('ResourcesScreen._applyLocalTextFilter -> ${filtered.length} items');
    // Smart fallback: if user typed a query and nothing matched locally, try a targeted fetch once
    if (q.isNotEmpty && filtered.isEmpty && !_fallbackRunning && _userLat != null && _userLng != null) {
      _fallbackRunning = true;
      unawaited(() async {
        try {
          final fetched = await _resourceService.searchResources(
            query: q,
            type: _typeFilter == 'all' ? null : _typeFilter,
            userLat: _userLat,
            userLng: _userLng,
            maxDistance: _maxDistanceMiles,
            language: _language,
            region: _region,
          );
          if (!mounted) return;
          setState(() {
            // Merge unique by id
            final existingIds = _allResources.map((e) => e.id).toSet();
            final newOnes = fetched.where((r) => !existingIds.contains(r.id)).toList();
            if (newOnes.isNotEmpty) {
              _allResources.addAll(newOnes);
            }
          });
          _applyLocalTextFilter();
        } catch (e) {
          debugPrint('ResourcesScreen._applyLocalTextFilter fallback fetch error: $e');
        } finally {
          _fallbackRunning = false;
        }
      }());
    }
  }

  Future<void> _loadRatingsForResources() async {
    try {
      final ids = _resources.take(20).map((r) => r.id).toList();
      if (ids.isEmpty) return;
      final batch = await _ratingsService.getSummariesBatch(ids);
      if (!mounted) return;
      setState(() => _summaries.addAll(batch));
      // Refresh Google for top 6
      final googleIds = ids.where((id) => id.startsWith('gpl_')).take(6);
      for (final id in googleIds) {
        unawaited(_ratingsService.ensureFreshGoogleSummary(id).then((s) {
          if (!mounted) return;
          setState(() => _summaries[id] = s);
        }));
      }
    } catch (e) {
      debugPrint('ResourcesScreen._loadRatingsForResources error: $e');
    }
  }

  Resource _applySummary(Resource r) {
    final s = _summaries[r.id];
    if (s == null) return r;
    if (s.countCombined > 0 && s.avgCombined > 0) {
      return r.copyWith(rating: s.avgCombined, reviewCount: s.countCombined);
    }
    return r;
  }

  Future<void> _applyTypedLocation({bool saveToProfile = false}) async {
    final q = _locationController.text.trim();
    if (q.isEmpty) return;
    final result = await _resourceService.geocodeAddress(q);
    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find that location')),
        );
      }
      return;
    }
    setState(() {
      _userLat = (result['lat'] as num).toDouble();
      _userLng = (result['lng'] as num).toDouble();
      _userLocationLabel = (result['label'] as String?) ?? q;
      _locationController.text = _userLocationLabel!;
      _region = (result['countryCode'] as String?)?.toUpperCase();
    });
    if (saveToProfile) {
      try {
        await _userService.savePreferredLocation(
          label: _userLocationLabel ?? q,
          lat: _userLat!,
          lng: _userLng!,
          countryCode: _region,
        );
        if (mounted) {
          // Refresh in-memory user so Profile reflects the new location immediately
          try {
            await context.read<UserProvider>().loadUser();
          } catch (e) {
            debugPrint('ResourcesScreen post-save refresh user error: $e');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location saved to profile')),
          );
        }
      } catch (e) {
        debugPrint('ResourcesScreen.savePreferredLocation error: $e');
        String msg = 'Could not save location to profile';
        final eStr = e.toString();
        if (eStr.contains('Not signed in')) {
          msg = 'Please sign in to save your location';
        } else if (eStr.contains('permission-denied')) {
          msg = 'Permission denied saving location (rules)';
        } else if (eStr.contains('unavailable')) {
          msg = 'Network unavailable. Try again.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      }
    }
    await _loadResources();
  }

  Future<void> _promptManualLocation() async {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    bool saving = false;
    Future<void> doGeocode() async {
      final q = controller.text.trim();
      if (q.isEmpty) return;
      final result = await _resourceService.geocodeAddress(q);
      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find that location')),
          );
        }
        return;
      }
      setState(() {
        _userLat = (result['lat'] as num).toDouble();
        _userLng = (result['lng'] as num).toDouble();
        _userLocationLabel = (result['label'] as String?) ?? 'Selected location';
        _region = (result['countryCode'] as String?)?.toUpperCase();
      });
      await _loadResources();
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Enter a location'),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'City, ZIP, or address',
                ),
                onSubmitted: (_) async {
                  if (saving) return;
                  setStateDialog(() => saving = true);
                  await doGeocode();
                  if (context.mounted) Navigator.of(ctx).pop();
                },
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setStateDialog(() => saving = true);
                          await doGeocode();
                          if (context.mounted) Navigator.of(ctx).pop();
                        },
                  child: const Text('Use once'),
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setStateDialog(() => saving = true);
                          final q = controller.text.trim();
                          if (q.isNotEmpty) {
                            final result = await _resourceService.geocodeAddress(q);
                            if (result != null) {
                              setState(() {
                                _userLat = (result['lat'] as num).toDouble();
                                _userLng = (result['lng'] as num).toDouble();
                                _userLocationLabel = (result['label'] as String?) ?? 'Selected location';
                                _region = (result['countryCode'] as String?)?.toUpperCase();
                              });
                              try {
                                await _userService.savePreferredLocation(
                                  label: _userLocationLabel ?? q,
                                  lat: _userLat!,
                                  lng: _userLng!,
                                  countryCode: _region,
                                );
                                if (mounted) {
                                  // Refresh in-memory user so Profile reflects the new location immediately
                                  try {
                                    await context.read<UserProvider>().loadUser();
                                  } catch (e) {
                                    debugPrint('ResourcesScreen.dialog post-save refresh user error: $e');
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Location saved to profile')),
                                  );
                                }
                              } catch (e) {
                                debugPrint('ResourcesScreen.dialog savePreferredLocation error: $e');
                                String msg = 'Could not save location to profile';
                                final eStr = e.toString();
                                if (eStr.contains('Not signed in')) {
                                  msg = 'Please sign in to save your location';
                                } else if (eStr.contains('permission-denied')) {
                                  msg = 'Permission denied saving location (rules)';
                                } else if (eStr.contains('unavailable')) {
                                  msg = 'Network unavailable. Try again.';
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(msg)),
                                  );
                                }
                              }
                              await _loadResources();
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not find that location')),
                                );
                              }
                            }
                          }
                          if (context.mounted) Navigator.of(ctx).pop();
                        },
                  child: const Text('Save to profile'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openFiltersSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        // Local temp state
        bool tOpenNow = _openNow;
        double tMinRating = _minRating;
        int tMinReviews = _minReviews;
        final Set<int> tPrices = {..._priceLevels};
        bool tSortByRating = _sortByRating;
        bool tRankByDistance = _rankByDistance;
        final Set<String> tTypes = {..._googleTypes};
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              final cs = Theme.of(ctx).colorScheme;
              Widget priceChip(int level) => FilterChip(
                    label: Text(['\$', '\$\$', '\$\$\$', '\$\$\$\$', '\$\$\$\$\$'][level]),
                    selected: tPrices.contains(level),
                    onSelected: (_) => setSheet(() {
                      if (tPrices.contains(level)) {
                        tPrices.remove(level);
                      } else {
                        tPrices.add(level);
                      }
                    }),
                  );
              FilterChip typeChip(String label, String type) => FilterChip(
                    label: Text(label),
                    selected: tTypes.contains(type),
                    onSelected: (_) => setSheet(() {
                      if (tTypes.contains(type)) {
                        tTypes.remove(type);
                      } else {
                        tTypes.add(type);
                      }
                    }),
                  );
              return SafeArea(
                child: Padding(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune, color: cs.primary),
                          SizedBox(width: AppSpacing.sm),
                          Text('Fine-tune results', style: context.textStyles.titleLarge?.semiBold),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setSheet(() {
                                tOpenNow = false;
                                tMinRating = 0;
                                tMinReviews = 0;
                                tPrices.clear();
                                tSortByRating = false;
                                tRankByDistance = false;
                                tTypes.clear();
                              });
                            },
                            child: const Text('Reset'),
                          )
                        ],
                      ),
                      SizedBox(height: AppSpacing.md),
                      SwitchListTile(
                        value: tOpenNow,
                        onChanged: (v) => setSheet(() => tOpenNow = v),
                        title: const Text('Open now'),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text('Minimum rating'),
                      Slider(
                        value: tMinRating,
                        onChanged: (v) => setSheet(() => tMinRating = double.parse(v.toStringAsFixed(1))),
                        divisions: 10,
                        min: 0,
                        max: 5,
                        label: tMinRating.toStringAsFixed(1),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text('Minimum reviews: $tMinReviews'),
                      Slider(
                        value: tMinReviews.toDouble(),
                        onChanged: (v) => setSheet(() => tMinReviews = v.round()),
                        divisions: 10,
                        min: 0,
                        max: 500,
                        label: '$tMinReviews',
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text('Price levels'),
                      Wrap(spacing: AppSpacing.sm, children: [
                        priceChip(0), priceChip(1), priceChip(2), priceChip(3), priceChip(4),
                      ]),
                      SizedBox(height: AppSpacing.md),
                      Text('Sort'),
                      Row(children: [
                        ChoiceChip(
                          label: const Text('Nearest'),
                          selected: !tSortByRating,
                          onSelected: (_) => setSheet(() { tSortByRating = false; }),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        ChoiceChip(
                          label: const Text('Top rated'),
                          selected: tSortByRating,
                          onSelected: (_) => setSheet(() { tSortByRating = true; }),
                        ),
                      ]),
                      SizedBox(height: AppSpacing.md),
                      Text('Nearby search ranking'),
                      Row(children: [
                        ChoiceChip(
                          label: const Text('Prominence'),
                          selected: !tRankByDistance,
                          onSelected: (_) => setSheet(() { tRankByDistance = false; }),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        ChoiceChip(
                          label: const Text('Distance'),
                          selected: tRankByDistance,
                          onSelected: (_) => setSheet(() { tRankByDistance = true; }),
                        ),
                      ]),
                      SizedBox(height: AppSpacing.md),
                      Text('Google place types'),
                      Wrap(spacing: AppSpacing.sm, children: [
                        typeChip('Hospital', 'hospital'),
                        typeChip('Clinic', 'clinic'),
                        typeChip('Doctor', 'doctor'),
                        typeChip('Physiotherapist', 'physiotherapist'),
                        typeChip('Psychologist', 'psychologist'),
                        typeChip('Pharmacy', 'pharmacy'),
                        typeChip('Dentist', 'dentist'),
                        typeChip('Health', 'health'),
                      ]),
                      SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _openNow = tOpenNow;
                              _minRating = tMinRating;
                              _minReviews = tMinReviews;
                              _priceLevels
                                ..clear()
                                ..addAll(tPrices);
                              _sortByRating = tSortByRating;
                              _rankByDistance = tRankByDistance;
                              _googleTypes
                                ..clear()
                                ..addAll(tTypes);
                            });
                            Navigator.of(ctx).pop();
                            _loadResources();
                          },
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text('Apply filters'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Saved-location removed: no profile sync
    return GlassyScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(children: [
                          const BrandLogo(size: 56),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Resource Finder', style: context.textStyles.headlineMedium?.semiBold, overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (_) => const RecommendResourceSheet(),
                          );
                        },
                        icon: Icon(Icons.add_location_alt_outlined, color: Theme.of(context).colorScheme.primary),
                        label: Text(
                          'Recommend',
                          style: context.textStyles.labelLarge?.withColor(Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md),
                  // Typed location input (city/ZIP/address)
                  TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      hintText: 'Enter city, ZIP, or address…',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      // Use suffix instead of suffixIcon to host multiple trailing buttons safely
                      suffix: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Apply location',
                            icon: Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
                            onPressed: () => _applyTypedLocation(),
                          ),
                          IconButton(
                            tooltip: 'Save to profile',
                            icon: Icon(Icons.bookmark_add_outlined, color: Theme.of(context).colorScheme.primary),
                            onPressed: () => _applyTypedLocation(saveToProfile: true),
                          ),
                        ],
                      ),
                      // Rely on themed borders to avoid web paint incompatibilities
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _applyTypedLocation(),
                  ),
                  if (_userLocationLabel != null && _userLocationLabel!.isNotEmpty) ...[
                    SizedBox(height: AppSpacing.xs),
                    _LocationBanner(
                      text: 'Using: ${_userLocationLabel!}',
                      actionLabel: 'Change',
                      onTap: _promptManualLocation,
                      secondaryLabel: _region != null ? _region : null,
                      onSecondaryTap: null,
                    ),
                  ],
                  SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search resources...',
                      prefixIcon: const Icon(Icons.search),
                      suffix: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() => _searchController.clear());
                                _applyLocalTextFilter();
                              },
                            ),
                          IconButton(
                            tooltip: 'Search',
                            icon: Icon(Icons.arrow_forward, color: Theme.of(context).colorScheme.primary),
                            onPressed: _runSearch,
                          ),
                        ],
                      ),
                      // Use themed borders
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    onChanged: (_) {
                      // Rebuild to toggle clear button visibility and debounce filter.
                      setState(() {});
                      _debouncedSearch();
                    },
                    onSubmitted: (_) => _runSearch(),
                  ),
                  SizedBox(height: AppSpacing.md),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All Types',
                          isSelected: _typeFilter == 'all',
                          onSelected: () => setState(() {
                            _typeFilter = 'all';
                            _loadResources();
                          }),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        _FilterChip(
                          label: 'Therapist',
                          isSelected: _typeFilter == 'therapist',
                          onSelected: () => setState(() {
                            _typeFilter = 'therapist';
                            // Default ON when switching to Therapist to meet request
                            _therapyNameOnly = true;
                            _loadResources();
                          }),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        _FilterChip(
                          label: 'Hospital',
                          isSelected: _typeFilter == 'hospital',
                          onSelected: () => setState(() {
                            _typeFilter = 'hospital';
                            _therapyNameOnly = false;
                            _loadResources();
                          }),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        _FilterChip(
                          label: 'Service',
                          isSelected: _typeFilter == 'service',
                          onSelected: () => setState(() {
                            _typeFilter = 'service';
                            _therapyNameOnly = false;
                            _loadResources();
                          }),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        _FilterChip(
                          label: 'Pharmacy',
                          isSelected: _typeFilter == 'pharmacy',
                          onSelected: () => setState(() {
                            _typeFilter = 'pharmacy';
                            _therapyNameOnly = false;
                            _loadResources();
                          }),
                        ),
                        SizedBox(width: AppSpacing.md),
                        // Specialty chips (local filters)
                        _FilterChip(
                          label: 'Independent living',
                          isSelected: _specialtyFilters.contains('independent living'),
                          onSelected: () => setState(() {
                            if (_specialtyFilters.contains('independent living')) {
                              _specialtyFilters.remove('independent living');
                            } else {
                              _specialtyFilters.add('independent living');
                            }
                            _applyLocalTextFilter();
                          }),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        _FilterChip(
                          label: 'Disability services',
                          isSelected: _specialtyFilters.contains('disability services'),
                          onSelected: () => setState(() {
                            if (_specialtyFilters.contains('disability services')) {
                              _specialtyFilters.remove('disability services');
                            } else {
                              _specialtyFilters.add('disability services');
                            }
                            _applyLocalTextFilter();
                          }),
                        ),
                        if (_typeFilter == 'therapist') ...[
                          SizedBox(width: AppSpacing.md),
                          _FilterChip(
                            label: 'Therapy name only',
                            isSelected: _therapyNameOnly,
                            onSelected: () => setState(() {
                              _therapyNameOnly = !_therapyNameOnly;
                              _loadResources();
                            }),
                          ),
                        ],
                        SizedBox(width: AppSpacing.md),
                        Icon(Icons.straighten, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        SizedBox(width: AppSpacing.xs),
                        _FilterChip(
                          label: 'All distances',
                          isSelected: _maxDistanceMiles == null,
                          onSelected: () => setState(() { _maxDistanceMiles = null; _loadResources(); }),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        _FilterChip(
                          label: '5 mi',
                          isSelected: _maxDistanceMiles == 5,
                          onSelected: () => setState(() { _maxDistanceMiles = 5; _loadResources(); }),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        _FilterChip(
                          label: '10 mi',
                          isSelected: _maxDistanceMiles == 10,
                          onSelected: () => setState(() { _maxDistanceMiles = 10; _loadResources(); }),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        _FilterChip(
                          label: '25 mi',
                          isSelected: _maxDistanceMiles == 25,
                          onSelected: () => setState(() { _maxDistanceMiles = 25; _loadResources(); }),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        _FilterChip(
                          label: '50 mi',
                          isSelected: _maxDistanceMiles == 50,
                          onSelected: () => setState(() { _maxDistanceMiles = 50; _loadResources(); }),
                        ),
                        SizedBox(width: AppSpacing.md),
                        // Advanced filters button
                        TextButton.icon(
                          onPressed: _openFiltersSheet,
                          icon: Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
                          label: Text('Filters', style: context.textStyles.labelLarge?.withColor(Theme.of(context).colorScheme.primary)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  // Removed secondary "Recommend a resource" button under filters to avoid duplication.
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CenteredLoadingSkeleton())
                  : _resources.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_off_outlined,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(height: AppSpacing.md),
                              Text(
                                'No resources found',
                                style: context.textStyles.titleLarge?.withColor(
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(height: AppSpacing.xs),
                              TextButton.icon(
                                onPressed: () async {
                                  await _loadResources();
                                },
                                icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
                                label: Text('Refresh', style: context.textStyles.labelLarge?.withColor(Theme.of(context).colorScheme.primary)),
                              )
                            ],
                          ),
                        )
                      : Builder(builder: (context) {
                          // Optional grouping for therapists
                          if (_typeFilter == 'therapist' && !_therapyNameOnly) {
                            final isTherapyName = (Resource r) {
                              final n = r.name.toLowerCase();
                              return n.contains('therapy') || n.contains('therapist');
                            };
                            final exact = _resources.where(isTherapyName).toList();
                            final others = _resources.where((r) => !isTherapyName(r)).toList();
                            final children = <Widget>[];
                            if (exact.isNotEmpty) {
                              children.add(Padding(
                                padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                                child: Text('Exact “therapy” matches', style: context.textStyles.titleSmall?.semiBold),
                              ));
                              children.addAll(exact.map((r) => _ResourceCard(resource: r)).toList());
                            }
                            if (others.isNotEmpty) {
                              children.add(Padding(
                                padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                                child: Text('Other therapists', style: context.textStyles.titleSmall?.semiBold),
                              ));
                              children.addAll(others.map((r) => _ResourceCard(resource: r)).toList());
                            }
                            return ListView(
                              padding: EdgeInsets.only(bottom: AppSpacing.lg + MediaQuery.of(context).padding.bottom),
                              children: children,
                            );
                          }
                          // Default flat list
                          return ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.lg,
                              AppSpacing.lg,
                              AppSpacing.lg + MediaQuery.of(context).padding.bottom,
                            ),
                            itemCount: _resources.length,
                            itemBuilder: (context, index) {
                              final withSummary = _applySummary(_resources[index]);
                              return _ResourceCard(resource: withSummary);
                            },
                          );
                        }),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
    );
  }
}

class _LocationBanner extends StatelessWidget {
  final String text;
  final String actionLabel;
  final VoidCallback onTap;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryTap;
  const _LocationBanner({
    required this.text,
    required this.actionLabel,
    required this.onTap,
    this.secondaryLabel,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.my_location, color: cs.onSurfaceVariant),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: context.textStyles.bodyMedium?.withColor(cs.onSurface))),
          TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.my_location),
            label: Text(actionLabel),
          ),
          if (secondaryLabel != null && onSecondaryTap != null) ...[
            SizedBox(width: AppSpacing.xs),
            TextButton(
              onPressed: onSecondaryTap,
              child: Text(secondaryLabel!),
            )
          ]
        ],
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final Resource resource;
  const _ResourceCard({required this.resource});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    resource.type == 'therapist'
                        ? Icons.person_outline
                        : (resource.type == 'center' || resource.type == 'hospital')
                            ? Icons.local_hospital_outlined
                            : (resource.type == 'pharmacy'
                                ? Icons.local_pharmacy_outlined
                                : Icons.medical_services_outlined),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(resource.name, style: context.textStyles.titleMedium?.semiBold),
                      if (resource.rating > 0 && resource.reviewCount > 0)
                        Row(children: [
                          RatingStars(rating: resource.rating, reviews: resource.reviewCount, size: 14),
                          SizedBox(width: 8),
                          Text(resource.rating.toStringAsFixed(1), style: context.textStyles.bodySmall),
                        ])
                      else
                        Row(children: [
                          Icon(Icons.star_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          SizedBox(width: 6),
                          Text('No ratings', style: context.textStyles.bodySmall?.withColor(Theme.of(context).colorScheme.onSurfaceVariant)),
                        ]),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            // Address row
            if (resource.address.isNotEmpty) ...[
              Row(children: [
                Icon(Icons.place_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    resource.address,
                    style: context.textStyles.bodySmall?.withColor(Theme.of(context).colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ]),
              SizedBox(height: AppSpacing.xs),
            ],
            Row(children: [
              Icon(Icons.location_on_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${resource.location} • ${resource.distance.toStringAsFixed(1)} mi',
                  style: context.textStyles.bodySmall?.withColor(Theme.of(context).colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ]),
            SizedBox(height: AppSpacing.xs),
            HoursBadge(availability: resource.availability, dense: true),
            if (resource.contactPhone != null) ...[
              SizedBox(height: AppSpacing.sm),
              PhoneLink(phone: resource.contactPhone!, dense: true),
            ],
            SizedBox(height: AppSpacing.sm),
            // Review submissions are disabled for now
          ],
        ),
      ),
    );
  }
}
