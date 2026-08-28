import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/tracker_service.dart';
import 'package:wellspring/services/health_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';
import 'package:intl/intl.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/screens/tracker/nutrition/nutrition_tab.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen>
    with AutomaticKeepAliveClientMixin {
  final _trackerService = TrackerService();
  final _healthService = HealthService();
  List<TrackerEntry> _entries = [];
  Map<String, double> _stats = {};
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  int? _todaySteps;
  int? _latestHeartRate;
  int? _systolicBP;
  int? _diastolicBP;
  double? _latestWeight;
  double? _latestTemperature;
  double? _lastNightSleep;
  DateTime? _lastHealthSync;
  bool _healthAuthorized = false;
  bool _checkingHealth = false;
  Timer? _liveTickTimer;
  int _tabIndex = 0;
  int _chartPageIndex = 0;
  final PageController _chartPageController = PageController();

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Set up listener for health data updates
    _healthService.addListener(_onHealthDataUpdated);
  }

  @override
  void dispose() {
    _healthService.removeListener(_onHealthDataUpdated);
    _liveTickTimer?.cancel();
    _chartPageController.dispose();
    super.dispose();
  }

  void _onHealthDataUpdated(Map<String, dynamic> data) {
    if (!mounted) return;
    debugPrint('TrackerScreen: Health data updated: $data');
    setState(() {
      _todaySteps = data['steps'] as int? ?? _todaySteps;
      _latestHeartRate = data['heartRate'] as int? ?? _latestHeartRate;
      _systolicBP = data['systolicBP'] as int? ?? _systolicBP;
      _diastolicBP = data['diastolicBP'] as int? ?? _diastolicBP;
      final w = data['weight'];
      if (w is num) _latestWeight = w.toDouble();
      final t = data['temperature'];
      if (t is num) _latestTemperature = t.toDouble();
      final sq = data['sleepQuality'];
      if (sq is num) _lastNightSleep = sq.toDouble() * 0.8; // reverse map
      _lastHealthSync = DateTime.now();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    // Ensure we have the authenticated user's profile loaded
    await context.read<UserProvider>().loadUser();
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: 30));

    debugPrint(
        'TrackerScreen._loadData: Loading for userId=$userId, range=$startDate to $now');
    List<TrackerEntry> entries =
        await _trackerService.getEntriesByDateRange(userId, startDate, now);
    // Nutrition logs are stored in the same table as tracker entries, but we
    // keep them out of the Health-side tracker analytics and recent lists.
    entries = entries.where((e) => !e.isNutritionOnlyEntry).toList();

    // Fallback: If no entries in last 30 days, load the most recent entries
    if (entries.isEmpty) {
      try {
        final recent = await _trackerService.getRecentEntries(
          userId,
          limit: 30,
          includeNutrition: false,
        );
        if (recent.isNotEmpty) {
          entries = recent;
          debugPrint(
              'TrackerScreen._loadData: No entries in last 30 days, loaded ${entries.length} recent entries as fallback');
        }
      } catch (e) {
        debugPrint(
            'TrackerScreen._loadData: Failed to load recent entries fallback: $e');
      }
    }

    // Calculate stats from the loaded entries instead of using date range
    // This ensures stats match the entries being displayed
    Map<String, double> stats;
    if (entries.isNotEmpty) {
      // Calculate stats from loaded entries
      final painLevels = entries
          .where((e) => e.painLevel != null)
          .map((e) => e.painLevel!)
          .toList();
      final sleepQuality = entries
          .where((e) => e.sleepQuality != null)
          .map((e) => e.sleepQuality!)
          .toList();
      final energyLevels = entries
          .where((e) => e.energyLevel != null)
          .map((e) => e.energyLevel!)
          .toList();

      stats = {
        'avgPain': painLevels.isEmpty
            ? 0
            : painLevels.reduce((a, b) => a + b) / painLevels.length,
        'avgSleep': sleepQuality.isEmpty
            ? 0
            : sleepQuality.reduce((a, b) => a + b) / sleepQuality.length,
        'avgEnergy': energyLevels.isEmpty
            ? 0
            : energyLevels.reduce((a, b) => a + b) / energyLevels.length,
      };

      try {
        final painCount = entries.where((e) => e.painLevel != null).length;
        debugPrint(
            'TrackerScreen._loadData: entries=${entries.length}, painWithValues=$painCount, statsKeys=${stats.keys.toList()}');
      } catch (e) {
        debugPrint('TrackerScreen._loadData debug print failed: $e');
      }
    } else {
      stats = {};
    }

    setState(() {
      _entries = entries;
      _stats = stats;
      _isLoading = false;
    });
    // Load Health steps in parallel (iOS only)
    _loadHealthIfSupported();
  }

  Future<void> _loadHealthIfSupported() async {
    if (!_isIOS) return;
    setState(() => _checkingHealth = true);
    try {
      var has = await _healthService.hasAuthorization();
      if (!mounted) return;

      // Auto-request Apple Health permission if we don't already have it.
      // This shows the iOS HealthKit sheet automatically on load so the user
      // never has to press a "Connect" button.
      if (!has) {
        debugPrint(
            'TrackerScreen: Auto-requesting Apple Health authorization on load');
        has = await _healthService.requestAuthorization();
        if (!mounted) return;
      }

      _healthAuthorized = has;
      if (has) {
        // Enable background delivery for continuous sync
        await _healthService.enableBackgroundDelivery();

        // Perform initial sync
        final data = await _healthService.syncNow();
        if (!mounted) return;
        _onHealthDataUpdated(data);
        _startLiveTick();

        debugPrint('TrackerScreen: Auto-sync enabled for Apple Health');
      } else {
        setState(() {}); // update UI to show connect prompt fallback
      }
    } catch (e) {
      debugPrint('TrackerScreen: loadHealth failed: $e');
    } finally {
      if (mounted) setState(() => _checkingHealth = false);
    }
  }

  /// Fast in-app tick to poll health data every 10s while the screen is
  /// visible, so the bar feels continuously updated without any user action.
  void _startLiveTick() {
    _liveTickTimer?.cancel();
    if (!_isIOS) return;
    _liveTickTimer =
        Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted || !_healthAuthorized) return;
      final data = await _healthService.getTodayHealthData();
      if (!mounted) return;
      _onHealthDataUpdated(data);
    });
  }

  Future<void> _connectAppleHealth() async {
    setState(() => _checkingHealth = true);
    try {
      final ok = await _healthService.requestAuthorization();
      if (!mounted) return;
      setState(() => _healthAuthorized = ok);
      if (ok) {
        // Enable background delivery for continuous updates
        await _healthService.enableBackgroundDelivery();

        // Perform initial sync
        final data = await _healthService.syncNow();
        if (!mounted) return;
        _onHealthDataUpdated(data);
        _startLiveTick();

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Apple Health connected - Auto-sync enabled')));
        debugPrint('TrackerScreen: Background delivery and auto-sync enabled');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Permission denied for Apple Health')));
      }
    } catch (e) {
      debugPrint('TrackerScreen: connectAppleHealth error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to connect Apple Health')));
      }
    } finally {
      if (mounted) setState(() => _checkingHealth = false);
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    return GlassyScaffold(
      body: SafeArea(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tabIndex == 0
                                    ? 'Health Tracker'
                                    : 'Nutrition Tracker',
                                style:
                                    context.textStyles.headlineMedium?.semiBold,
                              ),
                              SizedBox(height: AppSpacing.xs),
                              Text(
                                _tabIndex == 0
                                    ? (_entries.isEmpty
                                        ? 'No entries yet'
                                        : 'Your health overview: 30 days')
                                    : 'Meals, hydration, and progress',
                                style: context.textStyles.bodyMedium
                                    ?.withColor(cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _tabIndex == 0
                              ? FilledButton.icon(
                                  key: const ValueKey('add_health'),
                                  onPressed: () async {
                                    await context.push('/tracker/add');
                                    _loadData();
                                  },
                                  icon: Icon(Icons.add, color: cs.onPrimary),
                                  label: Text('Add Entry',
                                      style: context
                                          .textStyles.labelLarge?.semiBold
                                          .withColor(cs.onPrimary)),
                                  style: ButtonStyle(
                                    shape: WidgetStatePropertyAll(
                                      RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    padding: const WidgetStatePropertyAll(
                                        EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10)),
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('no_add'), width: 0, height: 0),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: TabBar(
                      onTap: (i) {
                        if (mounted) setState(() => _tabIndex = i);
                      },
                      dividerColor: Colors.transparent,
                      labelColor: cs.onSurface,
                      unselectedLabelColor: cs.onSurfaceVariant,
                      indicator: BoxDecoration(
                        color:
                            cs.surfaceContainerHighest.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.35)),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: const [
                        Tab(text: 'Health'),
                        Tab(text: 'Nutrition'),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _isLoading
                            ? const Center(child: CenteredLoadingSkeleton())
                            : SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                    AppSpacing.lg, 0, AppSpacing.lg, 100),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      child: _buildStatsCards(),
                                    ),
                                    SizedBox(height: AppSpacing.lg),
                                    if (_entries.isNotEmpty) ...[
                                      _buildChartsCarousel(),
                                      SizedBox(height: AppSpacing.md),
                                      Divider(
                                        height: 1,
                                        thickness: 0.6,
                                        color: cs.outlineVariant
                                            .withValues(alpha: 0.28),
                                      ),
                                      SizedBox(height: AppSpacing.lg),
                                      if (_isIOS) ...[
                                        _buildAppleHealthRow(),
                                        SizedBox(height: AppSpacing.md),
                                      ],
                                      _buildRecentEntries(),
                                    ] else
                                      Center(
                                        child: Column(
                                          children: [
                                            SizedBox(height: AppSpacing.xxl),
                                            Icon(Icons.insert_chart_outlined,
                                                size: 64,
                                                color: cs.onSurfaceVariant),
                                            SizedBox(height: AppSpacing.md),
                                            Text('No entries yet',
                                                style: context
                                                    .textStyles.titleLarge
                                                    ?.withColor(
                                                        cs.onSurfaceVariant)),
                                            SizedBox(height: AppSpacing.sm),
                                            Text(
                                                'Start tracking your health metrics',
                                                style: context
                                                    .textStyles.bodyMedium
                                                    ?.withColor(
                                                        cs.onSurfaceVariant)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                        const NutritionTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  String _formatFriendlyDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;
    final time = DateFormat('h:mm a').format(date);
    if (diff == 0) return 'Today • $time';
    if (diff == -1) return 'Yesterday • $time';
    return '${DateFormat('EEE, MMM d, yyyy').format(date)} • $time';
  }

  Future<String> _getCreatorName(String createdByUserId) async {
    try {
      final userService = UserService();
      final user = await userService.getUserById(createdByUserId);
      return user?.name ?? 'Family Member';
    } catch (e) {
      debugPrint('TrackerScreen._getCreatorName error: $e');
      return 'Family Member';
    }
  }

  Widget _buildStatsCards() => Row(
        children: [
          Expanded(
            child: _StatCard(
              title: 'Avg Pain',
              value: _stats['avgPain']?.toStringAsFixed(1) ?? '0.0',
              icon: Icons.healing_outlined,
              gradientKind: _GradientKind.danger,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: _StatCard(
              title: 'Avg Sleep Hours',
              value: (_stats['avgSleep']?.toStringAsFixed(1) ?? '0.0') + 'h',
              icon: Icons.bedtime_outlined,
              gradientKind: _GradientKind.primary,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: _StatCard(
              title: 'Avg Energy',
              value: _stats['avgEnergy']?.toStringAsFixed(1) ?? '0.0',
              icon: Icons.bolt_outlined,
              gradientKind: _GradientKind.tertiary,
            ),
          ),
        ],
      );

  Widget _buildAppleHealthRow() {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    if (_checkingHealth) {
      return Card(
          child: Padding(
              padding: AppSpacing.paddingMd,
              child: Row(children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: InlineLoadingDot(),
                ),
                SizedBox(width: AppSpacing.sm),
                Text('Checking Apple Health…', style: text.bodyMedium),
              ])));
    }
    if (!_healthAuthorized) {
      return Card(
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.health_and_safety_outlined, color: cs.primary),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connect Apple Health',
                        style: text.titleSmall?.semiBold),
                    SizedBox(height: 2),
                    Text('Import health data from your Apple Watch & iPhone.',
                        style: text.bodySmall?.withColor(cs.onSurfaceVariant)),
                  ]),
            ),
            FilledButton.icon(
              onPressed: _connectAppleHealth,
              icon: Icon(Icons.link, color: cs.onPrimary),
              label: Text('Connect',
                  style: text.labelLarge?.semiBold.withColor(cs.onPrimary)),
            ),
          ]),
        ),
      );
    }
    // Authorized: continuous live bar
    final syncedLabel = _lastHealthSync == null
        ? 'Syncing…'
        : 'Live • updated ${_relativeTime(_lastHealthSync!)}';
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.watch, color: cs.primary),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Apple Watch',
                              style: text.titleSmall?.semiBold),
                          SizedBox(width: AppSpacing.sm),
                          _LivePulseDot(color: cs.primary),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(syncedLabel,
                          style:
                              text.bodySmall?.withColor(cs.onSurfaceVariant)),
                    ]),
              ),
            ]),
            SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _HealthMetricChip(
                  icon: Icons.directions_walk,
                  label: 'Steps',
                  value: _todaySteps?.toString() ?? '—',
                ),
                _HealthMetricChip(
                  icon: Icons.favorite_border,
                  label: 'Heart Rate',
                  value: _latestHeartRate != null
                      ? '${_latestHeartRate!} bpm'
                      : '—',
                ),
                if (_systolicBP != null && _diastolicBP != null)
                  _HealthMetricChip(
                    icon: Icons.monitor_heart_outlined,
                    label: 'Blood Pressure',
                    value: '${_systolicBP!}/${_diastolicBP!}',
                  ),
                if (_lastNightSleep != null)
                  _HealthMetricChip(
                    icon: Icons.bedtime_outlined,
                    label: 'Sleep',
                    value: '${_lastNightSleep!.toStringAsFixed(1)}h',
                  ),
                if (_latestWeight != null)
                  _HealthMetricChip(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Weight',
                    value: '${_latestWeight!.toStringAsFixed(1)} kg',
                  ),
                if (_latestTemperature != null)
                  _HealthMetricChip(
                    icon: Icons.thermostat_outlined,
                    label: 'Temp',
                    value: '${_latestTemperature!.toStringAsFixed(1)}°C',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Widget _buildPainChart() {
    // Prepare last 7 entries with pain, sorted by date ascending
    final painData = _entries.where((e) => e.painLevel != null).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final trimmed =
        painData.length > 7 ? painData.sublist(painData.length - 7) : painData;

    // If there are entries but none have pain values, show an informative card
    if (trimmed.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      final text = context.textStyles;
      return Card(
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12)),
                child:
                    Icon(Icons.insights_outlined, color: cs.onSurfaceVariant),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No pain data yet',
                          style: text.titleSmall?.semiBold),
                      SizedBox(height: 2),
                      Text('Add entries with a pain level to see trends here.',
                          style:
                              text.bodySmall?.withColor(cs.onSurfaceVariant)),
                    ]),
              ),
            ],
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.textStyles;

    String rangeLabel() {
      final first = trimmed.first.date;
      final last = trimmed.last.date;
      final sameMonth = first.month == last.month && first.year == last.year;
      if (sameMonth) {
        return '${DateFormat('MMM d').format(first)} – ${DateFormat('d').format(last)}';
      }
      return '${DateFormat('MMM d').format(first)} – ${DateFormat('MMM d').format(last)}';
    }

    String painLabel(int value) {
      // Map 0-10 to qualitative labels
      if (value <= 1) return 'Minimal';
      if (value <= 3) return 'Mild';
      if (value <= 5) return 'Moderate';
      if (value <= 7) return 'Severe';
      return 'Extreme';
    }

    // Compute X axis bounds. Ensure there is width for a single data point.
    final minX = 0.0;
    final rawMaxX = (trimmed.length - 1).toDouble();
    final maxX = rawMaxX == minX ? minX + 1.0 : rawMaxX;

    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pain (Last 7 Entries)',
                    style: textStyles.titleMedium?.semiBold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    rangeLabel(),
                    style: textStyles.labelSmall
                        ?.withColor(colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: 0,
                  maxY: 10,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: Padding(
                        padding: EdgeInsets.only(right: AppSpacing.xs),
                        child: Text('Pain',
                            style: textStyles.labelSmall
                                ?.withColor(colorScheme.onSurfaceVariant)),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final v = value.round();
                          if (v % 2 == 0 && v >= 0 && v <= 10) {
                            return Text('$v',
                                style: textStyles.bodySmall
                                    ?.withColor(colorScheme.onSurfaceVariant));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < trimmed.length) {
                            final d = trimmed[i].date;
                            return Padding(
                              padding: EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(
                                DateFormat('M/d').format(d), // 1/8, 1/9...
                                style: textStyles.bodySmall
                                    ?.withColor(colorScheme.onSurfaceVariant),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.error,
                        ],
                      ),
                      spots: trimmed
                          .asMap()
                          .entries
                          .map((e) => FlSpot(
                              e.key.toDouble(), e.value.painLevel!.toDouble()))
                          .toList(),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary.withValues(alpha: 0.12),
                            colorScheme.error.withValues(alpha: 0.06),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: colorScheme.primary,
                            strokeWidth: 1,
                            strokeColor: colorScheme.surface,
                          );
                        },
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((t) {
                          final i = t.x.toInt();
                          final entry = trimmed[i];
                          final pain = entry.painLevel ?? 0;
                          final dateStr =
                              DateFormat('EEE, MMM d').format(entry.date);
                          return LineTooltipItem(
                            '$dateStr\n$pain/10 • ${painLabel(pain)}',
                            textStyles.bodySmall?.semiBold
                                    .withColor(colorScheme.onInverseSurface) ??
                                const TextStyle(),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsCarousel() {
    final availableCharts = <String>[];
    
    // Check which metrics have data
    if (_entries.any((e) => e.painLevel != null)) availableCharts.add('Pain');
    if (_entries.any((e) => e.energyLevel != null)) availableCharts.add('Energy');
    if (_entries.any((e) => e.sleepQuality != null)) availableCharts.add('Sleep');
    if (_entries.any((e) => e.heartRate != null)) availableCharts.add('Heart Rate');
    if (_entries.any((e) => e.systolicBP != null && e.diastolicBP != null)) availableCharts.add('Blood Pressure');
    if (_entries.any((e) => e.weight != null)) availableCharts.add('Weight');
    if (_entries.any((e) => e.temperature != null)) availableCharts.add('Temperature');
    if (_entries.any((e) => e.steps != null)) availableCharts.add('Steps');
    
    if (availableCharts.isEmpty) {
      return _buildEmptyChartState();
    }

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView(
            controller: _chartPageController,
            onPageChanged: (index) => setState(() => _chartPageIndex = index),
            children: availableCharts.map((chartType) {
              switch (chartType) {
                case 'Pain':
                  return _buildPainChart();
                case 'Energy':
                  return _buildEnergyChart();
                case 'Sleep':
                  return _buildSleepChart();
                case 'Heart Rate':
                  return _buildHeartRateChart();
                case 'Blood Pressure':
                  return _buildBloodPressureChart();
                case 'Weight':
                  return _buildWeightChart();
                case 'Temperature':
                  return _buildTemperatureChart();
                case 'Steps':
                  return _buildStepsChart();
                default:
                  return const SizedBox.shrink();
              }
            }).toList(),
          ),
        ),
        if (availableCharts.length > 1) ...[
          SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(availableCharts.length, (index) {
              final isActive = index == _chartPageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: AppSpacing.xs / 2),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildEnergyChart() {
    final data = _entries.where((e) => e.energyLevel != null).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final trimmed = data.length > 7 ? data.sublist(data.length - 7) : data;
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.textStyles;
    final minX = 0.0;
    final maxX = (trimmed.length - 1).toDouble() == 0.0 ? 1.0 : (trimmed.length - 1).toDouble();

    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Energy Level (Last 7 Entries)', style: textStyles.titleMedium?.semiBold),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: 0,
                  maxY: 10,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final v = value.round();
                          if (v % 2 == 0 && v >= 0 && v <= 10) {
                            return Text('$v', style: textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < trimmed.length) {
                            return Padding(
                              padding: EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(DateFormat('M/d').format(trimmed[i].date),
                                  style: textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      color: colorScheme.tertiary,
                      spots: trimmed.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.energyLevel!.toDouble())).toList(),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colorScheme.tertiary.withValues(alpha: 0.12),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 3,
                          color: colorScheme.tertiary,
                          strokeWidth: 1,
                          strokeColor: colorScheme.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepChart() {
    final data = _entries.where((e) => e.sleepQuality != null).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final trimmed = data.length > 7 ? data.sublist(data.length - 7) : data;
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.textStyles;
    final minX = 0.0;
    final maxX = (trimmed.length - 1).toDouble() == 0.0 ? 1.0 : (trimmed.length - 1).toDouble();

    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sleep Quality (Last 7 Entries)', style: textStyles.titleMedium?.semiBold),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: 0,
                  maxY: 10,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final v = value.round();
                          if (v % 2 == 0 && v >= 0 && v <= 10) {
                            return Text('$v', style: textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < trimmed.length) {
                            return Padding(
                              padding: EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(DateFormat('M/d').format(trimmed[i].date),
                                  style: textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.indigo,
                      spots: trimmed.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.sleepQuality!.toDouble())).toList(),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.indigo.withValues(alpha: 0.12),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 3,
                          color: Colors.indigo,
                          strokeWidth: 1,
                          strokeColor: colorScheme.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRateChart() {
    final data = _entries.where((e) => e.heartRate != null).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final trimmed = data.length > 7 ? data.sublist(data.length - 7) : data;
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.textStyles;
    final minX = 0.0;
    final maxX = (trimmed.length - 1).toDouble() == 0.0 ? 1.0 : (trimmed.length - 1).toDouble();
    final values = trimmed.map((e) => e.heartRate!.toDouble()).toList();
    final minY = (values.reduce((a, b) => a < b ? a : b) - 10).floorToDouble().clamp(40.0, 200.0);
    final maxY = (values.reduce((a, b) => a > b ? a : b) + 10).ceilToDouble().clamp(60.0, 220.0);

    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Heart Rate (Last 7 Entries)', style: textStyles.titleMedium?.semiBold),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()} bpm',
                              style: textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < trimmed.length) {
                            return Padding(
                              padding: EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(DateFormat('M/d').format(trimmed[i].date),
                                  style: textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.red,
                      spots: trimmed.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.heartRate!.toDouble())).toList(),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.red.withValues(alpha: 0.12),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 3,
                          color: Colors.red,
                          strokeWidth: 1,
                          strokeColor: colorScheme.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodPressureChart() {
    final data = _entries.where((e) => e.systolicBP != null && e.diastolicBP != null).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final trimmed = data.length > 7 ? data.sublist(data.length - 7) : data;
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.textStyles;
    final minX = 0.0;
    final maxX = (trimmed.length - 1).toDouble() == 0.0 ? 1.0 : (trimmed.length - 1).toDouble();

    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Blood Pressure (Last 7 Entries)', style: textStyles.titleMedium?.semiBold),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: 40,
                  maxY: 180,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 40,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}',
                              style: textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < trimmed.length) {
                            return Padding(
                              padding: EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(DateFormat('M/d').format(trimmed[i].date),
                                  style: textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.orange,
                      spots: trimmed.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.systolicBP!.toDouble())).toList(),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 3,
                          color: Colors.orange,
                          strokeWidth: 1,
                          strokeColor: colorScheme.surface,
                        ),
                      ),
                    ),
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.blue,
                      spots: trimmed.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.diastolicBP!.toDouble())).toList(),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 3,
                          color: Colors.blue,
                          strokeWidth: 1,
                          strokeColor: colorScheme.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightChart() {
    final data = _entries.where((e) => e.weight != null).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final trimmed = data.length > 7 ? data.sublist(data.length - 7) : data;
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.textStyles;
    final minX = 0.0;
    final maxX = (trimmed.length - 1).toDouble() == 0.0 ? 1.0 : (trimmed.length - 1).toDouble();
    final values = trimmed.map((e) => e.weight!).toList();
    final minY = (values.reduce((a, b) => a < b ? a : b) - 2).floorToDouble();
    final maxY = (values.reduce((a, b) => a > b ? a : b) + 2).ceilToDouble();

    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weight (Last 7 Entries)', style: textStyles.titleMedium?.semiBold),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toStringAsFixed(1)} kg',
                              style: textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < trimmed.length) {
                            return Padding(
                              padding: EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(DateFormat('M/d').format(trimmed[i].date),
                                  style: textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.green,
                      spots: trimmed.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.weight!)).toList(),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withValues(alpha: 0.12),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 3,
                          color: Colors.green,
                          strokeWidth: 1,
                          strokeColor: colorScheme.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureChart() {
    final data = _entries.where((e) => e.temperature != null).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final trimmed = data.length > 7 ? data.sublist(data.length - 7) : data;
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.textStyles;
    final minX = 0.0;
    final maxX = (trimmed.length - 1).toDouble() == 0.0 ? 1.0 : (trimmed.length - 1).toDouble();

    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Temperature (Last 7 Entries)', style: textStyles.titleMedium?.semiBold),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: 35,
                  maxY: 40,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toStringAsFixed(0)}°C',
                              style: textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < trimmed.length) {
                            return Padding(
                              padding: EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(DateFormat('M/d').format(trimmed[i].date),
                                  style: textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.deepOrange,
                      spots: trimmed.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.temperature!)).toList(),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.deepOrange.withValues(alpha: 0.12),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 3,
                          color: Colors.deepOrange,
                          strokeWidth: 1,
                          strokeColor: colorScheme.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsChart() {
    final data = _entries.where((e) => e.steps != null).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final trimmed = data.length > 7 ? data.sublist(data.length - 7) : data;
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.textStyles;
    final minX = 0.0;
    final maxX = (trimmed.length - 1).toDouble() == 0.0 ? 1.0 : (trimmed.length - 1).toDouble();
    final values = trimmed.map((e) => e.steps!.toDouble()).toList();
    final maxY = (values.reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();

    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Steps (Last 7 Entries)', style: textStyles.titleMedium?.semiBold),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          return Text('${(value / 1000).toStringAsFixed(0)}k',
                              style: textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < trimmed.length) {
                            return Padding(
                              padding: EdgeInsets.only(top: AppSpacing.xs),
                              child: Text(DateFormat('M/d').format(trimmed[i].date),
                                  style: textStyles.bodySmall?.withColor(colorScheme.onSurfaceVariant)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.purple,
                      spots: trimmed.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.steps!.toDouble())).toList(),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.purple.withValues(alpha: 0.12),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 3,
                          color: Colors.purple,
                          strokeWidth: 1,
                          strokeColor: colorScheme.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChartState() {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12)),
              child:
                  Icon(Icons.insights_outlined, color: cs.onSurfaceVariant),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No metric data yet',
                        style: text.titleSmall?.semiBold),
                    SizedBox(height: 2),
                    Text('Add entries with health metrics to see trends here.',
                        style:
                            text.bodySmall?.withColor(cs.onSurfaceVariant)),
                  ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEntries() {
    final userId = context.read<UserProvider>().currentUser?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Entries',
                style: context.textStyles.titleMedium?.semiBold),
            TextButton(
              onPressed: () => context.push('/tracker/recent'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View all',
                      style: context.textStyles.labelLarge?.semiBold),
                  SizedBox(width: AppSpacing.xs),
                  Icon(Icons.arrow_forward,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        if (userId == null)
          Center(
            child: Text(
              'Sign in to view your entries',
              style: context.textStyles.bodyMedium
                  ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          )
        else
          StreamBuilder<List<TrackerEntry>>(
            stream: _trackerService.recentEntriesStream(
              userId,
              limit: 5,
              includeNutrition: false,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CenteredLoadingSkeleton());
              }
              final recent = snapshot.data ?? [];
              if (recent.isEmpty) {
                return Text(
                  'No recent entries',
                  style: context.textStyles.bodyMedium?.withColor(
                      Theme.of(context).colorScheme.onSurfaceVariant),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: recent.map((entry) {
                  final isMedOnly = entry.isMedicationOnlyEntry;
                  final cs = Theme.of(context).colorScheme;
                  final isCreatedByOther = entry.createdByUserId != null && entry.createdByUserId != userId;
                  return InkWell(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () => context.push('/tracker/entry', extra: entry),
                    child: Card(
                      margin: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Padding(
                        padding: AppSpacing.paddingMd,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row with log type badge
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isMedOnly
                                        ? cs.primary.withValues(alpha: 0.15)
                                        : cs.secondary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isMedOnly
                                            ? Icons.medication_outlined
                                            : Icons.monitor_heart_outlined,
                                        size: 14,
                                        color: isMedOnly
                                            ? cs.primary
                                            : cs.secondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isMedOnly
                                            ? 'Medication Log'
                                            : 'Tracker Log',
                                        style: context
                                            .textStyles.labelSmall?.semiBold
                                            .withColor(
                                          isMedOnly ? cs.primary : cs.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      _formatFriendlyDate(entry.date),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: context.textStyles.labelMedium
                                          ?.withColor(cs.onSurfaceVariant),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: AppSpacing.sm),
                            // Content: medications or health metrics
                            if (isMedOnly) ...[
                              // Show medication details
                              _buildMedicationContent(entry),
                            ] else ...[
                              LayoutBuilder(
                                builder: (context, constraints) => Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: [
                                    if (entry.painLevel != null)
                                      _MetricChip(
                                        label: 'Pain: ${entry.painLevel}/10',
                                        icon: Icons.healing_outlined,
                                        maxWidth: constraints.maxWidth,
                                      ),
                                    if (entry.mood != null)
                                      _MetricChip(
                                        label: 'Mood: ${entry.mood}',
                                        icon: Icons.mood_outlined,
                                        maxWidth: constraints.maxWidth,
                                      ),
                                    if (entry.energyLevel != null)
                                      _MetricChip(
                                        label:
                                            'Energy: ${entry.energyLevel}/10',
                                        icon: Icons.bolt_outlined,
                                        maxWidth: constraints.maxWidth,
                                      ),
                                    if (entry.steps != null)
                                      _MetricChip(
                                        label: 'Steps: ${entry.steps}',
                                        icon: Icons.directions_walk,
                                        maxWidth: constraints.maxWidth,
                                      ),
                                    if (entry.systolicBP != null &&
                                        entry.diastolicBP != null)
                                      _MetricChip(
                                        label:
                                            'BP: ${entry.systolicBP}/${entry.diastolicBP}',
                                        icon: Icons.monitor_heart_outlined,
                                        maxWidth: constraints.maxWidth,
                                      ),
                                    if (entry.heartRate != null)
                                      _MetricChip(
                                        label: 'HR: ${entry.heartRate} bpm',
                                        icon: Icons.favorite_border,
                                        maxWidth: constraints.maxWidth,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            // Show creator info if created by someone else
                            if (isCreatedByOther) ...[
                              SizedBox(height: AppSpacing.xs),
                              FutureBuilder<String>(
                                future: _getCreatorName(entry.createdByUserId!),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) return const SizedBox.shrink();
                                  return Row(
                                    children: [
                                      Icon(Icons.person_outline, size: 12, color: cs.tertiary),
                                      SizedBox(width: 4),
                                      Text(
                                        'Logged by ${snapshot.data}',
                                        style: context.textStyles.labelSmall?.withColor(cs.tertiary),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMedicationContent(TrackerEntry entry) {
    final cs = Theme.of(context).colorScheme;
    final meds = <String>[];

    // Collect medication names from both sources
    if (entry.medications != null) {
      meds.addAll(entry.medications!);
    }
    if (entry.medicationLogs != null) {
      for (final log in entry.medicationLogs!) {
        final dosage = log.doseMg != null ? ' (${log.doseMg}mg)' : '';
        meds.add('${log.name}$dosage');
      }
    }

    if (meds.isEmpty) {
      return Text(
        'No medications logged',
        style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
      );
    }

    final maxChipWidth = MediaQuery.sizeOf(context).width -
        (AppSpacing.lg * 2) -
        (AppSpacing.md * 2);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: meds.map((med) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxChipWidth.clamp(140, 9999)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.medication, size: 14, color: cs.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    med,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        context.textStyles.labelSmall?.withColor(cs.onSurface),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

enum _GradientKind { primary, tertiary, danger }

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final _GradientKind gradientKind;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradientKind,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = switch (gradientKind) {
      _GradientKind.primary => [cs.primary, cs.tertiary],
      _GradientKind.tertiary => [cs.tertiary, cs.secondary],
      _GradientKind.danger => [cs.error, cs.primary],
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.first.withValues(alpha: 0.18),
            colors.last.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.20), width: 1),
      ),
      padding: AppSpacing.paddingMd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.primary, size: 22),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(value, style: context.textStyles.titleLarge?.semiBold),
          Text(
            title,
            style: context.textStyles.labelSmall?.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final double? maxWidth;

  const _MetricChip({required this.label, required this.icon, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (maxWidth ?? MediaQuery.sizeOf(context).width) * 1.0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePulseDot extends StatefulWidget {
  final Color color;
  const _LivePulseDot({required this.color});

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.5 * (1 - t)),
                    blurRadius: 8 * t,
                    spreadRadius: 2 * t,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text('LIVE',
                style: context.textStyles.labelSmall?.semiBold
                    .withColor(widget.color)),
          ],
        );
      },
    );
  }
}

class _HealthMetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HealthMetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.textStyles.labelSmall
                    ?.withColor(cs.onSurfaceVariant),
              ),
              Text(
                value,
                style: context.textStyles.titleSmall?.semiBold,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
