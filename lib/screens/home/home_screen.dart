import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wellspring/models/goal.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/tracker_service.dart';
import 'package:wellspring/services/goal_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:wellspring/services/milestone_service.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/models/medication.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/screens/goals/milestone_education_page.dart';
import 'package:wellspring/models/condition_detail.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:wellspring/services/tutorial_service.dart';
import 'package:wellspring/services/application_service.dart';
import 'package:wellspring/widgets/brand_logo.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

// Updated: Goals now use proper UUID format instead of timestamps
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _trackerService = TrackerService();
  final _goalService = GoalService();
  final _milestoneService = MilestoneService();
  final _conditionService = ConditionService();
  List<Goal> _goals = [];
  Milestone? _nextStep;
  bool _allStepsCompleted = false;
  bool _isLoading = true;
  Map<String, double> _stats7 = {};
  Map<String, double> _statsPrev7 = {};
  List<String> _recentMedications = [];
  bool _medicationTrackerExpanded = false;
  bool _loadingMedications = false;
  int _bladderStreak = 0;
  int _bowelStreak = 0;
  // Series for last 7 values (ascending by time)
  List<double> _painSeries7 = [];
  List<double> _sleepSeries7 = [];
  List<double> _energySeries7 = [];
  List<double> _stepsSeries7 = [];
  List<double> _hrSeries7 = [];
  List<double> _weightSeries7 = [];
  List<double> _tempSeries7 = [];
  List<double> _spasmSeries7 = [];
  // Deltas vs previous 7-day averages
  double _deltaPain = 0;
  double _deltaSleep = 0;
  double _deltaEnergy = 0;
  double _deltaSteps = 0;
  double _deltaHR = 0;
  double _deltaWeight = 0;
  double _deltaTemp = 0;
  double _deltaSpasm = 0;
  double _avgSys = 0;
  double _avgDia = 0;
  double _avgHR = 0;
  String _moodTrend = '';
  StreamSubscription? _trackerSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final userProvider = context.read<UserProvider>();
    if (userProvider.currentUser == null) {
      userProvider.loadUser().then((_) {
        final uid = context.read<UserProvider>().currentUser?.id;
        if (uid != null) _subscribeToTracker(uid);
        _loadAll();
      });
    } else {
      final uid = userProvider.currentUser?.id;
      if (uid != null) _subscribeToTracker(uid);
      _loadAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trackerSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload milestones when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      debugPrint('Home: App resumed, reloading milestones');
      _loadNextStep();
    }
  }

  void _subscribeToTracker(String userId) {
    // Cancel any existing subscription
    _trackerSub?.cancel();
    try {
      _trackerSub =
          _trackerService
              .recentEntriesStream(userId, limit: 5, includeNutrition: false)
              .listen((_) {
        // Whenever entries change, refresh the snapshot section
        _loadSnapshot();
      }, onError: (e) {
        debugPrint('Home._subscribeToTracker stream error: $e');
      });
    } catch (e) {
      debugPrint('Home._subscribeToTracker init error: $e');
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadSnapshot(),
      _loadGoals(),
      _loadNextStep(),
      _loadMedications(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }


  Future<void> _loadMedications() async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) {
      debugPrint('Home._loadMedications: no signed-in user; skipping');
      return;
    }

    if (mounted) setState(() => _loadingMedications = true);
    try {
      final suggestions = await _trackerService.getSuggestionsForKind(
        userId,
        TrackerSuggestionKind.medications,
        limit: 10,
      );
      if (mounted) {
        setState(() {
          _recentMedications = suggestions;
          _loadingMedications = false;
        });
      }
    } catch (e) {
      debugPrint('Home._loadMedications error: $e');
      if (mounted) {
        setState(() => _loadingMedications = false);
      }
    }
  }

  Future<void> _addMedication(Medication medication) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.currentUser;
    if (user == null) {
      debugPrint('Home._addMedication: no signed-in user');
      return;
    }

    // Add to existing medications list
    final updatedMedications = [...user.medications, medication];
    final updatedUser = user.copyWith(medications: updatedMedications);
    
    await userProvider.updateUser(updatedUser);
    debugPrint('Home._addMedication: Added ${medication.name}');
    // Schedule local notification reminders for this medication's times.
    try {
      await NotificationService.instance.scheduleMedication(medication);
    } catch (e) {
      debugPrint('Home._addMedication: schedule notification error: $e');
    }
  }

  Future<void> _quickLogMedication(Medication medication) async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) {
      debugPrint('Home._quickLogMedication: no signed-in user');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to log medications')),
        );
      }
      return;
    }

    try {
      final now = DateTime.now();
      // Check if there's already a medication-only entry for today
      // This keeps medication logs separate from full health tracker entries
      final existingMedEntry = await _trackerService.getMedicationOnlyEntryByDate(userId, now);

      if (existingMedEntry != null) {
        // Update existing medication-only entry - add medication if not already present
        final currentMeds = List<String>.from(existingMedEntry.medications ?? []);
        final medName = medication.name;
        
        if (!currentMeds.contains(medName)) {
          currentMeds.add(medName);
        }
        
        // Also add to medicationLogs with timestamp
        final currentLogs = List<MedicationLog>.from(existingMedEntry.medicationLogs ?? []);
        currentLogs.add(MedicationLog(
          name: medName,
          doseMg: medication.dosage != null ? int.tryParse(medication.dosage!.replaceAll(RegExp(r'[^0-9]'), '')) : null,
          takenAt: now.toIso8601String(),
        ));
        
        // Build updated customFields with medicationLogs
        final updatedCustomFields = Map<String, dynamic>.from(existingMedEntry.customFields ?? {});
        updatedCustomFields['medicationLogs'] = currentLogs.map((l) => l.toJson()).toList();
        
        final updatedEntry = TrackerEntry(
          id: existingMedEntry.id,
          userId: userId,
          date: existingMedEntry.date,
          medications: currentMeds,
          customFields: updatedCustomFields,
          createdAt: existingMedEntry.createdAt,
          updatedAt: now,
        );
        
        await _trackerService.updateEntry(updatedEntry);
        debugPrint('Home._quickLogMedication: Updated today\'s medication entry with ${medication.name}');
      } else {
        // Create new medication-only entry for today
        final newEntry = TrackerEntry(
          id: const Uuid().v4(),
          userId: userId,
          date: now,
          medications: [medication.name],
          customFields: {
            'medicationLogs': [
              MedicationLog(
                name: medication.name,
                doseMg: medication.dosage != null ? int.tryParse(medication.dosage!.replaceAll(RegExp(r'[^0-9]'), '')) : null,
                takenAt: now.toIso8601String(),
              ).toJson(),
            ],
          },
          createdAt: now,
          updatedAt: now,
        );
        
        await _trackerService.addEntry(newEntry);
        debugPrint('Home._quickLogMedication: Created new medication entry with ${medication.name}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Logged ${medication.name}')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        // Refresh snapshot to reflect new entry
        await _loadSnapshot();
      }
    } catch (e) {
      debugPrint('Home._quickLogMedication error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not log medication: $e')),
        );
      }
    }
  }

  Future<void> _loadSnapshot() async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) {
      debugPrint(
          'Home._loadSnapshot: no signed-in user; skipping snapshot load');
      return;
    }
    final now = DateTime.now();
    final start7 = now.subtract(Duration(days: 7));
    final prevStart = now.subtract(Duration(days: 14));
    final prevEnd = now.subtract(Duration(days: 7));

    debugPrint(
        'Home._loadSnapshot: uid=$userId, range7=${start7.toIso8601String()}..${now.toIso8601String()}');
    Map<String, double> stats7 =
        await _trackerService.getStatistics(userId, start7, now);
    final statsPrev =
        await _trackerService.getStatistics(userId, prevStart, prevEnd);

    List<TrackerEntry> entries = await _trackerService.getEntriesByDateRange(
        userId, now.subtract(Duration(days: 30)), now);
    // If there are no entries in the last 30 days, fallback to the most recent few entries
    if (entries.isEmpty) {
      try {
        final recent = await _trackerService.getRecentEntries(
          userId,
          limit: 7,
          includeNutrition: false,
        );
        if (recent.isNotEmpty) {
          entries = recent;
          debugPrint(
              'Home._loadSnapshot: last30 empty; using most recent ${entries.length} entries as fallback');
        }
      } catch (e) {
        debugPrint(
            'Home._loadSnapshot: failed to load recent entries fallback: $e');
      }
    }
    debugPrint(
        'Home._loadSnapshot: last30/mostRecent entries=${entries.length}, stats7_keys=${stats7.keys.toList()}');
    int bladder = 0;
    int bowel = 0;
    entries.sort((a, b) => b.date.compareTo(a.date));
    for (final e in entries) {
      if (e.bladderSuccess == true) {
        bladder += 1;
      } else {
        break;
      }
    }
    for (final e in entries) {
      if (e.bowelProgram == true) {
        bowel += 1;
      } else {
        break;
      }
    }

    // Build last-7 series (ascending by time) for metrics
    List<double> _lastN(List<double> items, int n) {
      if (items.length <= n) return List<double>.from(items);
      return items.sublist(items.length - n);
    }

    final byOldest = List.of(entries)..sort((a, b) => a.date.compareTo(b.date));
    final painVals = byOldest
        .where((e) => e.painLevel != null)
        .map((e) => (e.painLevel!).toDouble())
        .toList();
    final sleepVals = byOldest
        .where((e) => e.sleepQuality != null)
        .map((e) => (e.sleepQuality!).toDouble())
        .toList();
    final energyVals = byOldest
        .where((e) => e.energyLevel != null)
        .map((e) => (e.energyLevel!).toDouble())
        .toList();
    final stepsVals = byOldest
        .where((e) => e.steps != null)
        .map((e) => (e.steps!).toDouble())
        .toList();

    final seriesPain = _lastN(painVals, 7);
    final seriesSleep = _lastN(sleepVals, 7);
    final seriesEnergy = _lastN(energyVals, 7);
    final seriesSteps = _lastN(stepsVals, 7);
    final hrVals = byOldest
        .where((e) => e.heartRate != null)
        .map((e) => (e.heartRate!).toDouble())
        .toList();
    final seriesHR = _lastN(hrVals, 7);
    
    final weightVals = byOldest
        .where((e) => e.weight != null)
        .map((e) => e.weight!)
        .toList();
    final seriesWeight = _lastN(weightVals, 7);
    
    final tempVals = byOldest
        .where((e) => e.temperature != null)
        .map((e) => e.temperature!)
        .toList();
    final seriesTemp = _lastN(tempVals, 7);
    
    final spasmVals = byOldest
        .where((e) => e.spasmFrequency != null)
        .map((e) => (e.spasmFrequency!).toDouble())
        .toList();
    final seriesSpasm = _lastN(spasmVals, 7);
    
    // Calculate mood trend from recent entries
    final recentMoods = byOldest
        .where((e) => e.mood != null && e.mood!.isNotEmpty)
        .map((e) => e.mood!)
        .toList();
    final moodTrend = recentMoods.isEmpty ? '' : recentMoods.last;

    // Fallback A: if there are no entries in the last 7 days but we do have recent data,
    // compute averages from the most recent values (up to 7) so the dashboard isn't all zeros.
    final total7 = (stats7['totalEntries'] ?? 0).toDouble();
    bool usedFallback = false;
    if (total7 == 0 && entries.isNotEmpty) {
      double avg(List<double> xs) =>
          xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
      // Compute avg of last up-to-7 values for each metric
      final fb = <String, double>{
        'avgPain': avg(seriesPain),
        'avgSleep': avg(seriesSleep),
        'avgEnergy': avg(seriesEnergy),
        'avgSteps': avg(seriesSteps),
        'totalSteps':
            seriesSteps.isEmpty ? 0 : seriesSteps.fold(0.0, (s, v) => s + v),
        'avgHeartRate': avg(seriesHR),
        'avgWeight': avg(seriesWeight),
        'avgTemperature': avg(seriesTemp),
        'avgSpasm': avg(seriesSpasm),
        // For BP, compute from last up-to-7 among byOldest
        'avgSys': () {
          final xs = _lastN(
              byOldest
                  .where((e) => e.systolicBP != null)
                  .map((e) => e.systolicBP!.toDouble())
                  .toList(),
              7);
          return avg(xs);
        }(),
        'avgDia': () {
          final xs = _lastN(
              byOldest
                  .where((e) => e.diastolicBP != null)
                  .map((e) => e.diastolicBP!.toDouble())
                  .toList(),
              7);
          return avg(xs);
        }(),
        'totalEntries': entries.length.toDouble(),
      };
      stats7 = fb;
      usedFallback = true;
      debugPrint(
          'Home._loadSnapshot: no data in last 7 days — using fallback averages from recent entries: '
          'pain=${fb['avgPain']?.toStringAsFixed(2)}, sleep=${fb['avgSleep']?.toStringAsFixed(2)}, '
          'energy=${fb['avgEnergy']?.toStringAsFixed(2)}, steps=${fb['avgSteps']?.toStringAsFixed(0)}, '
          'hr=${fb['avgHeartRate']?.toStringAsFixed(0)}, bp=${fb['avgSys']?.toStringAsFixed(0)}/${fb['avgDia']?.toStringAsFixed(0)}');
    }

    // Fallback B: If last-7-day stats exist but all tracked metrics are zero (likely because
    // recent entries lack values for these fields), compute from the most recent non-null values
    // (up to 7). This avoids showing an all-zero dashboard when there is meaningful recent data.
    if (!usedFallback && entries.isNotEmpty) {
      double v(String k) => (stats7[k] ?? 0).toDouble();
      final allZero = v('avgPain') == 0 &&
          v('avgSleep') == 0 &&
          v('avgEnergy') == 0 &&
          v('avgSteps') == 0 &&
          v('avgHeartRate') == 0;
      if (allZero &&
          (seriesPain.isNotEmpty ||
              seriesSleep.isNotEmpty ||
              seriesEnergy.isNotEmpty ||
              seriesSteps.isNotEmpty ||
              seriesHR.isNotEmpty)) {
        double avg(List<double> xs) =>
            xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
        final fb = <String, double>{
          'avgPain': avg(seriesPain),
          'avgSleep': avg(seriesSleep),
          'avgEnergy': avg(seriesEnergy),
          'avgSteps': avg(seriesSteps),
          'totalSteps':
              seriesSteps.isEmpty ? 0 : seriesSteps.fold(0.0, (s, v) => s + v),
          'avgHeartRate': avg(seriesHR),
          'avgWeight': avg(seriesWeight),
          'avgTemperature': avg(seriesTemp),
          'avgSpasm': avg(seriesSpasm),
          'avgSys': () {
            final xs = _lastN(
                byOldest
                    .where((e) => e.systolicBP != null)
                    .map((e) => e.systolicBP!.toDouble())
                    .toList(),
                7);
            return avg(xs);
          }(),
          'avgDia': () {
            final xs = _lastN(
                byOldest
                    .where((e) => e.diastolicBP != null)
                    .map((e) => e.diastolicBP!.toDouble())
                    .toList(),
                7);
            return avg(xs);
          }(),
          'totalEntries': entries.length.toDouble(),
        };
        stats7 = fb;
        usedFallback = true;
        debugPrint(
            'Home._loadSnapshot: last-7 stats were all zero — using most recent non-null values instead: '
            'pain=${fb['avgPain']?.toStringAsFixed(2)}, sleep=${fb['avgSleep']?.toStringAsFixed(2)}, '
            'energy=${fb['avgEnergy']?.toStringAsFixed(2)}, steps=${fb['avgSteps']?.toStringAsFixed(0)}, '
            'hr=${fb['avgHeartRate']?.toStringAsFixed(0)}, bp=${fb['avgSys']?.toStringAsFixed(0)}/${fb['avgDia']?.toStringAsFixed(0)}');
      }
    }

    // Calculate deltas vs previous 7-day averages
    final double dPain = usedFallback
        ? 0.0
        : ((stats7['avgPain'] ?? 0) - (statsPrev['avgPain'] ?? 0)).toDouble();
    final double dSleep = usedFallback
        ? 0.0
        : ((stats7['avgSleep'] ?? 0) - (statsPrev['avgSleep'] ?? 0)).toDouble();
    final double dEnergy = usedFallback
        ? 0.0
        : ((stats7['avgEnergy'] ?? 0) - (statsPrev['avgEnergy'] ?? 0))
            .toDouble();
    final double dSteps = usedFallback
        ? 0.0
        : ((stats7['avgSteps'] ?? 0) - (statsPrev['avgSteps'] ?? 0)).toDouble();
    final double dHR = usedFallback
        ? 0.0
        : ((stats7['avgHeartRate'] ?? 0) - (statsPrev['avgHeartRate'] ?? 0))
            .toDouble();
    final double dWeight = usedFallback
        ? 0.0
        : ((stats7['avgWeight'] ?? 0) - (statsPrev['avgWeight'] ?? 0)).toDouble();
    final double dTemp = usedFallback
        ? 0.0
        : ((stats7['avgTemperature'] ?? 0) - (statsPrev['avgTemperature'] ?? 0)).toDouble();
    final double dSpasm = usedFallback
        ? 0.0
        : ((stats7['avgSpasm'] ?? 0) - (statsPrev['avgSpasm'] ?? 0)).toDouble();

    if (mounted) {
      setState(() {
        _stats7 = stats7;
        _statsPrev7 = statsPrev;
        _bladderStreak = bladder;
        _bowelStreak = bowel;
        _painSeries7 = seriesPain;
        _sleepSeries7 = seriesSleep;
        _energySeries7 = seriesEnergy;
        _stepsSeries7 = seriesSteps;
        _hrSeries7 = seriesHR;
        _weightSeries7 = seriesWeight;
        _tempSeries7 = seriesTemp;
        _spasmSeries7 = seriesSpasm;
        _deltaPain = dPain;
        _deltaSleep = dSleep;
        _deltaEnergy = dEnergy;
        _deltaSteps = dSteps;
        _deltaHR = dHR;
        _deltaWeight = dWeight;
        _deltaTemp = dTemp;
        _deltaSpasm = dSpasm;
        _avgSys = (stats7['avgSys'] ?? 0).toDouble();
        _avgDia = (stats7['avgDia'] ?? 0).toDouble();
        _avgHR = (stats7['avgHeartRate'] ?? 0).toDouble();
        _moodTrend = moodTrend;
      });
    }

    // Detailed debug log of computed values
    try {
      debugPrint('Home._loadSnapshot: computed -> '
          'avgPain=${(_stats7['avgPain'] ?? 0).toStringAsFixed(2)}, '
          'avgSleep=${(_stats7['avgSleep'] ?? 0).toStringAsFixed(2)}, '
          'avgEnergy=${(_stats7['avgEnergy'] ?? 0).toStringAsFixed(2)}, '
          'avgSteps=${(_stats7['avgSteps'] ?? 0).toStringAsFixed(0)}, '
          'avgHR=${(_stats7['avgHeartRate'] ?? 0).toStringAsFixed(0)}, '
          'avgBP=${_avgSys.round()}/${_avgDia.round()}, '
          'seriesLens={pain:${_painSeries7.length}, sleep:${_sleepSeries7.length}, energy:${_energySeries7.length}, steps:${_stepsSeries7.length}, hr:${_hrSeries7.length}}');
    } catch (_) {}
  }

  Future<void> _loadGoals() async {
    try {
      final userProvider = context.read<UserProvider>();
      var userId = userProvider.currentUser?.id;
      if (userId == null) {
        debugPrint('Home._loadGoals: no user loaded yet; attempting loadUser()');
        await userProvider.loadUser();
        userId = userProvider.currentUser?.id;
      }

      if (userId == null) {
        debugPrint('Home._loadGoals: no signed-in user; clearing goals');
        if (mounted) setState(() => _goals = []);
        return;
      }

      final goals = await _goalService.getActiveGoals(userId);
      if (mounted) setState(() => _goals = goals);
    } catch (e) {
      debugPrint('Home._loadGoals error: $e');
      if (mounted) setState(() => _goals = []);
    }
  }

  Future<void> _addOrEditGoal({Goal? existing}) async {
    final cs = Theme.of(context).colorScheme;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    // Initialize fields from existing goal (if any)
    String period = existing?.period ?? 'weekly';
    int target = existing?.targetPerPeriod ?? 4;
    String? linked = existing?.linkedTrackerKey;

    // Guard against invalid persisted values that are not part of the dropdown items.
    // If an old goal has an unsupported period (e.g., 'monthly'), fall back to 'weekly'.
    const allowedPeriods = <String>{'weekly', 'none'};
    if (!allowedPeriods.contains(period)) {
      debugPrint(
          'Home._addOrEditGoal: Unknown period "$period". Falling back to "weekly".');
      period = 'weekly';
    }
    // If a linked tracker key is no longer supported, reset to null (None).
    const allowedKeys = <String?>{
      null,
      'pain',
      'sleep',
      'energy',
      'bladder',
      'bowel',
      'mood',
      'spasm',
      'steps',
      'bp'
    };
    if (!allowedKeys.contains(linked)) {
      debugPrint(
          'Home._addOrEditGoal: Unknown linked key "$linked". Resetting to null.');
      linked = null;
    }

    String keyLabel(String? key) {
      return switch (key) {
        'pain' => 'Pain',
        'sleep' => 'Sleep',
        'energy' => 'Energy',
        'bladder' => 'Bladder program',
        'bowel' => 'Bowel program',
        'mood' => 'Mood',
        'spasm' => 'Spasms',
        'steps' => 'Steps',
        'bp' => 'Blood pressure',
        _ => 'None',
      };
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(existing == null ? 'Add Goal' : 'Edit Goal',
                      style: ctx.textStyles.titleMedium?.semiBold),
                  SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: titleCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g., Stretching routine'),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Description (optional)'),
                    maxLines: 3,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: period,
                          decoration:
                              const InputDecoration(labelText: 'Period'),
                          items: const [
                            DropdownMenuItem(
                                value: 'weekly', child: Text('Weekly')),
                            DropdownMenuItem(
                                value: 'none', child: Text('None')),
                          ],
                          onChanged: (v) =>
                              setLocal(() => period = v ?? 'weekly'),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextFormField(
                          initialValue: target.toString(),
                          decoration: const InputDecoration(
                              labelText: 'Target per period'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setLocal(
                              () => target = int.tryParse(v) ?? target),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String?>(
                    value: linked,
                    decoration: const InputDecoration(
                        labelText: 'Link to tracker metric (optional)'),
                    items: <String?>[
                      null,
                      'pain',
                      'sleep',
                      'energy',
                      'bladder',
                      'bowel',
                      'mood',
                      'spasm',
                      'steps',
                      'bp'
                    ]
                        .map((k) => DropdownMenuItem<String?>(
                            value: k, child: Text(keyLabel(k))))
                        .toList(),
                    onChanged: (v) => setLocal(() => linked = v),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      if (existing != null) ...[
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await _goalService.archiveGoal(existing.id);
                              if (mounted) ctx.pop();
                              await _loadGoals();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Goal archived')));
                              }
                            } catch (e) {
                              debugPrint('Archive goal error: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Could not archive: $e')));
                              }
                            }
                          },
                          icon: Icon(Icons.archive_outlined,
                              color: Theme.of(context).colorScheme.onSurface),
                          label: const Text('Archive'),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final userId =
                                context.read<UserProvider>().currentUser?.id;
                            if (userId == null) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('No user session')),
                                );
                              }
                              return;
                            }

                            final confirm = await showModalBottomSheet<bool>(
                              context: context,
                              backgroundColor:
                                  Theme.of(context).colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(AppRadius.lg)),
                              ),
                              builder: (sheetCtx) {
                                final cs = Theme.of(sheetCtx).colorScheme;
                                return SafeArea(
                                  child: Padding(
                                    padding: AppSpacing.paddingMd,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.delete_outline,
                                                color: cs.error),
                                            SizedBox(width: AppSpacing.sm),
                                            Expanded(
                                              child: Text(
                                                  'Delete goal forever?',
                                                  style: sheetCtx.textStyles
                                                      .titleMedium?.semiBold),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: AppSpacing.sm),
                                        Text(
                                          'This will permanently remove this goal and its milestones. This can’t be undone.',
                                          style: sheetCtx.textStyles.bodyMedium
                                              ?.copyWith(
                                                  color: cs.onSurfaceVariant),
                                        ),
                                        SizedBox(height: AppSpacing.md),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () =>
                                                    sheetCtx.pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                            ),
                                            SizedBox(width: AppSpacing.sm),
                                            Expanded(
                                              child: FilledButton(
                                                style: FilledButton.styleFrom(
                                                    backgroundColor: cs.error),
                                                onPressed: () =>
                                                    sheetCtx.pop(true),
                                                child: Text('Delete',
                                                    style: TextStyle(
                                                        color: cs.onError)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );

                            if (confirm != true) return;

                            try {
                              await _goalService.deleteGoalForever(
                                  goalId: existing.id, userId: userId);
                              if (mounted) ctx.pop();
                              await _loadGoals();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Goal deleted')),
                                );
                              }
                            } catch (e) {
                              debugPrint('Delete goal error: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Could not delete: $e')),
                                );
                              }
                            }
                          },
                          icon: Icon(Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error),
                          label: Text('Delete',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ),
                        const Spacer(),
                      ],
                      FilledButton(
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Please add a title')));
                            return;
                          }
                          try {
                            final userId =
                                context.read<UserProvider>().currentUser?.id;
                            if (userId == null) throw Exception('No user');
                            final now = DateTime.now();
                            if (existing == null) {
                              final goal = Goal(
                                id: const Uuid().v4(),
                                userId: userId,
                                title: title,
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                targetPerPeriod: target.clamp(0, 50),
                                progressThisPeriod: 0,
                                period: period,
                                lastResetAt: period == 'weekly' ? now : null,
                                linkedTrackerKey: linked,
                                active: true,
                                createdAt: now,
                                updatedAt: now,
                              );
                              await _goalService.addGoal(goal);
                            } else {
                              final updated = existing.copyWith(
                                title: title,
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                targetPerPeriod: target.clamp(0, 50),
                                period: period,
                                linkedTrackerKey: linked,
                                lastResetAt: (existing.lastResetAt == null &&
                                        period == 'weekly')
                                    ? now
                                    : existing.lastResetAt,
                              );
                              await _goalService.updateGoal(updated);
                            }
                            if (mounted) ctx.pop();
                            await _loadGoals();
                          } catch (e) {
                            debugPrint('Add/Edit goal error: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Could not save goal: $e')));
                            }
                          }
                        },
                        child: Text(existing == null ? 'Add' : 'Save'),
                      )
                    ],
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _quickAddGoal({
    required String title,
    String? description,
    int target = 5,
    String period = 'weekly',
    String? linked,
  }) async {
    try {
      final userId = context.read<UserProvider>().currentUser?.id;
      if (userId == null) throw Exception('No user');
      final now = DateTime.now();
      final goal = Goal(
        id: const Uuid().v4(),
        userId: userId,
        title: title,
        description:
            (description ?? '').trim().isEmpty ? null : description!.trim(),
        targetPerPeriod: target.clamp(0, 50),
        progressThisPeriod: 0,
        period: period,
        lastResetAt: period == 'weekly' ? now : null,
        linkedTrackerKey: linked,
        active: true,
        createdAt: now,
        updatedAt: now,
      );
      await _goalService.addGoal(goal);
      await _loadGoals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added goal: $title')),
        );
      }
    } catch (e) {
      debugPrint('Quick add goal error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add goal: $e')),
        );
      }
    }
  }

  Future<void> _loadNextStep() async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _nextStep = null;
          _allStepsCompleted = false;
        });
      }
      return;
    }
    try {
      debugPrint('Home._loadNextStep: Loading milestones for user $userId');
      final all = await _milestoneService.list(userId: userId);
      if (!mounted) return;
      debugPrint('Home._loadNextStep: Loaded ${all.length} total milestones');
      final incomplete = all.where((m) => !m.completed).toList();
      debugPrint(
          'Home._loadNextStep: Found ${incomplete.length} incomplete milestones');
      if (incomplete.isEmpty) {
        debugPrint(
            'Home._loadNextStep: No incomplete milestones, setting _allStepsCompleted=${all.isNotEmpty}');
        setState(() {
          _nextStep = null;
          // If there are milestones but none incomplete, show Congrats state.
          _allStepsCompleted = all.isNotEmpty;
        });
        return;
      }
      incomplete.sort((a, b) {
        final ad = a.dueDate;
        final bd = b.dueDate;
        if (ad == null && bd == null) return a.order.compareTo(b.order);
        if (ad == null) return 1; // nulls last
        if (bd == null) return -1;
        final cmp = ad.compareTo(bd);
        return cmp != 0 ? cmp : a.order.compareTo(b.order);
      });
      debugPrint(
          'Home._loadNextStep: Setting next step to ${incomplete.first.id} - ${incomplete.first.title}');
      setState(() {
        _nextStep = incomplete.first;
        _allStepsCompleted = false;
      });
    } catch (e) {
      debugPrint('Home._loadNextStep error: $e');
      if (mounted) {
        setState(() {
          _nextStep = null;
          _allStepsCompleted = false;
        });
      }
    }
  }

  Future<void> _openPlanForUser() async {
    try {
      final user = context.read<UserProvider>().currentUser;
      if (user == null) {
        if (mounted) context.push('/auth');
        return;
      }

      final condIds = user.conditions;
      if (condIds.isEmpty) {
        if (mounted) context.push('/conditions');
        return;
      }

      if (condIds.length == 1) {
        final id = condIds.first;
        final condition = await _conditionService.getConditionById(id);
        final name = condition?.name ?? 'Plan';
        if (mounted) context.push('/plan/$id', extra: name);
        return;
      }

      if (!mounted) return;
      final choices = <Map<String, String>>[];
      for (final id in condIds) {
        final condition = await _conditionService.getConditionById(id);
        if (condition != null) {
          choices.add({'id': condition.id, 'name': condition.name});
        }
      }
      if (choices.isEmpty) {
        context.push('/conditions');
        return;
      }

      await showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return SafeArea(
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Open plan for…',
                      style: ctx.textStyles.titleMedium?.semiBold),
                  SizedBox(height: AppSpacing.sm),
                  ...choices.map((c) => ListTile(
                        leading: Icon(Icons.assignment_turned_in_outlined,
                            color: cs.onSurfaceVariant),
                        title: Text(c['name'] ?? ''),
                        onTap: () {
                          ctx.pop();
                          context.push('/plan/${c['id']}', extra: c['name']);
                        },
                      )),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Home._openPlanForUser error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open plan: $e')),
        );
      }
    }
  }

  Future<void> _snoozeNextStep(int days) async {
    final step = _nextStep;
    if (step == null) return;
    try {
      final uid = context.read<UserProvider>().currentUser?.id;
      if (uid == null) throw Exception('No user');
      final base = step.dueDate ?? DateTime.now();
      // Move due date by the specified days, preserve date granularity
      final startOfDay = DateTime(base.year, base.month, base.day);
      final newDue = startOfDay.add(Duration(days: days));
      await _milestoneService.updateFields(uid, step.id, {
        'dueDate': newDue.toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Snoozed to ${DateFormat('EEE, MMM d').format(newDue)}')),
        );
      }
      await _loadNextStep();
    } catch (e) {
      debugPrint('Home._snoozeNextStep error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not snooze: $e')),
        );
      }
    }
  }

  Future<void> _openContactSupport() async {
    final email = Uri.parse('mailto:adaptlyapp@gmail.com?subject=Support Request');
    try {
      if (await canLaunchUrl(email)) {
        await launchUrl(email);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open email app. Please email us at adaptlyapp@gmail.com')),
          );
        }
      }
    } catch (e) {
      debugPrint('Home._openContactSupport error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app. Please email us at adaptlyapp@gmail.com')),
        );
      }
    }
  }

  Future<void> _openSubmitFeedback() async {
    final cs = Theme.of(context).colorScheme;
    final subjectCtl = TextEditingController();
    final messageCtl = TextEditingController();
    bool sending = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                          color: cs.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(children: [
                    Expanded(
                        child: Text('Submit feedback',
                            style: ctx.textStyles.titleLarge?.semiBold)),
                    IconButton(
                        icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                        onPressed: () => Navigator.of(ctx).pop()),
                  ]),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Tell us what’s working or what could be better. We read every message.',
                    style: ctx.textStyles.bodyMedium
                        ?.withColor(cs.onSurfaceVariant),
                  ),
                  SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: subjectCtl,
                    decoration: const InputDecoration(
                        labelText: 'Subject', hintText: 'Quick title'),
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: messageCtl,
                    maxLines: 6,
                    decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText:
                            'Share details, steps, or screenshots (paste a link).'),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Row(children: [
                    OutlinedButton.icon(
                      onPressed: sending ? null : () => Navigator.of(ctx).pop(),
                      icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                      label: const Text('Cancel'),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: sending
                          ? null
                          : () async {
                              final subject = subjectCtl.text.trim().isEmpty
                                  ? 'App feedback'
                                  : subjectCtl.text.trim();
                              final text = messageCtl.text.trim();
                              if (text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Please enter a message')));
                                return;
                              }
                              setLocal(() => sending = true);
                              try {
                                await ApplicationService().sendFeedbackEmail(
                                    subject: subject, text: text);
                                if (mounted) {
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Feedback sent — thank you!')));
                                }
                              } catch (e) {
                                debugPrint('Failed to send feedback: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Failed to send feedback')));
                                }
                              } finally {
                                if (mounted) setLocal(() => sending = false);
                              }
                            },
                      icon: Icon(Icons.send, color: cs.onPrimary),
                      label: Text(sending ? 'Sending…' : 'Send'),
                    ),
                  ]),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = context.watch<UserProvider>().currentUser;
    final showOnboardingReminder = user != null && !user.onboardingCompleted;
    return Scaffold(
      body: _isLoading
          ? const Center(child: CenteredLoadingSkeleton())
          : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeHeader(
                    onAddEntry: () async {
                      await context.push('/tracker/add');
                      await _loadSnapshot();
                    },
                    onOpenPlan: _openPlanForUser,
                    onOpenCommunities: () => context.push('/communities'),
                    onOpenResources: () => context.push('/resources'),
                    onSubmitFeedback: _openSubmitFeedback,
                    onOpenTherapist: () => context.push('/therapist'),
                    onOpenEducation: () => context.push('/education'),
                    onContactSupport: _openContactSupport,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                              if (showOnboardingReminder)
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                      AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                                  child: _OnboardingReminderBanner(
                                    onFinish: () => context.go('/onboarding'),
                                  ),
                                ),
                              SizedBox(height: AppSpacing.sm),
                              // Move Next Step to the top, above Health Snapshot
                              _AnimatedSection(
                        delayMs: 50,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg),
                              child: Text(
                                'Patient Journey',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            SizedBox(height: AppSpacing.xs),
                            Showcase(
                              key: TutorialKeys.homeNextStep,
                              title: 'Your Next Step',
                              description:
                                  'Complete, snooze, or learn more to keep momentum.',
                              child: _nextStep != null
                                  ? Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: AppSpacing.lg),
                                      child: _NextStepCard(
                                        milestone: _nextStep!,
                                        onMarkDone: () async {
                                        try {
                                          final uid = context
                                              .read<UserProvider>()
                                              .currentUser
                                              ?.id;
                                          if (uid == null)
                                            throw Exception('No user');
                                          debugPrint(
                                              'Home: Marking milestone ${_nextStep!.id} as completed');
                                          await _milestoneService
                                              .updateFields(
                                                  uid,
                                                  _nextStep!.id,
                                                  {'completed': true});
                                          debugPrint(
                                              'Home: Milestone updated successfully, reloading next step');
                                          await _loadNextStep();
                                          debugPrint(
                                              'Home: Next step reloaded');
                                        } catch (e) {
                                          debugPrint(
                                              'Home: Error marking done: $e');
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'Failed to update step: $e')),
                                          );
                                        }
                                      },
                                      onSnooze: (days) async {
                                        await _snoozeNextStep(days);
                                      },
                                      onOpenPlan: _openPlanForUser,
                                    ),
                                  )
                                : Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: AppSpacing.lg),
                                    child: _NoNextStepCard(
                                        onOpenPlan: _openPlanForUser,
                                        isAllCompleted: _allStepsCompleted),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      // Daily Goals
                      _AnimatedSection(
                        delayMs: 75,
                        child: _GoalsSection(
                          goals: _goals,
                          onIncrement: (goalId) async {
                            await _goalService.incrementProgress(goalId);
                            await _loadGoals();
                          },
                          onAdd: () => _addOrEditGoal(),
                          onEdit: (g) => _addOrEditGoal(existing: g),
                          onQuickAdd: ({
                            required String title,
                            String? description,
                            int target = 5,
                            String period = 'weekly',
                            String? linked,
                          }) =>
                              _quickAddGoal(
                            title: title,
                            description: description,
                            target: target,
                            period: period,
                            linked: linked,
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      // Medication Tracker Section (below Daily Goals, above Health Snapshot)
                      _AnimatedSection(
                        delayMs: 100,
                        child: _MedicationTrackerSection(
                          medications: user?.medications ?? [],
                          isExpanded: _medicationTrackerExpanded,
                          isLoading: _loadingMedications,
                          onToggleExpand: () => setState(() => _medicationTrackerExpanded = !_medicationTrackerExpanded),
                          onAddEntry: () async {
                            await context.push('/tracker/add');
                            await _loadMedications();
                          },
                          onEditMedications: () => context.push('/profile'),
                          onQuickLogMedication: _quickLogMedication,
                          onAddMedication: _addMedication,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      // Health Snapshot
                      _AnimatedSection(
                        delayMs: 130,
                        child: _HealthSnapshotSection(
                          stats7: _stats7,
                          statsPrev7: _statsPrev7,
                          bladderStreak: _bladderStreak,
                          bowelStreak: _bowelStreak,
                          painSeries: _painSeries7,
                          sleepSeries: _sleepSeries7,
                          energySeries: _energySeries7,
                          stepsSeries: _stepsSeries7,
                          hrSeries: _hrSeries7,
                          weightSeries: _weightSeries7,
                          tempSeries: _tempSeries7,
                          spasmSeries: _spasmSeries7,
                          deltaPain: _deltaPain,
                          deltaSleep: _deltaSleep,
                          deltaEnergy: _deltaEnergy,
                          deltaSteps: _deltaSteps,
                          deltaHR: _deltaHR,
                          deltaWeight: _deltaWeight,
                          deltaTemp: _deltaTemp,
                          deltaSpasm: _deltaSpasm,
                          avgSys: _avgSys,
                          avgDia: _avgDia,
                          moodTrend: _moodTrend,
                          onLogToday: () async {
                            await context.push('/tracker/add');
                            await _loadSnapshot();
                          },
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

class _AnimatedSection extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const _AnimatedSection({required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
    );
  }
}

class _OnboardingReminderBanner extends StatelessWidget {
  final VoidCallback onFinish;
  const _OnboardingReminderBanner({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.error.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.error_outline,
                    color: cs.onErrorContainer, size: 18),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Finish onboarding to unlock your plan',
                        style: context.textStyles.titleSmall
                            ?.withColor(cs.onErrorContainer)),
                    SizedBox(height: 4),
                    Text(
                      'You stopped partway through onboarding. Complete it now to personalize your care plan and resources.',
                      style: context.textStyles.bodyMedium
                          ?.withColor(cs.onErrorContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                ),
                onPressed: onFinish,
                child: const Text('Finish onboarding'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatefulWidget {
  final VoidCallback onAddEntry;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenCommunities;
  final VoidCallback onOpenResources;
  final VoidCallback onSubmitFeedback;
  final VoidCallback onOpenTherapist;
  final VoidCallback onOpenEducation;
  final VoidCallback onContactSupport;

  const _HomeHeader({
    required this.onAddEntry,
    required this.onOpenPlan,
    required this.onOpenCommunities,
    required this.onOpenResources,
    required this.onSubmitFeedback,
    required this.onOpenTherapist,
    required this.onOpenEducation,
    required this.onContactSupport,
  });

  @override
  State<_HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<_HomeHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = DateFormat('EEE, MMM d').format(DateTime.now());
    // Time-based greeting
    final hour = DateTime.now().hour;
    final String baseGreeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');
    // Personalize greeting with first name if available
    String? firstName;
    try {
      final user = context.read<UserProvider>().currentUser;
      if (user != null && user.name.trim().isNotEmpty) {
        final parts = user.name.trim().split(' ');
        firstName = parts.isNotEmpty ? parts.first : null;
      }
    } catch (e) {
      debugPrint('HomeHeader: failed to read user for greeting: $e');
    }
    final greeting =
        firstName != null ? '$baseGreeting, $firstName' : baseGreeting;

    List<Color> _canopyColors(ColorScheme cs) {
      if (hour < 12) {
        return [cs.primaryContainer, cs.primary];
      } else if (hour < 17) {
        return [cs.primary, cs.secondary];
      } else {
        return [cs.tertiary, cs.primary];
      }
    }

    return Stack(
      children: [
        // Canopy background with time-of-day gradient
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _canopyColors(cs),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(AppRadius.xl),
              bottomRight: Radius.circular(AppRadius.xl),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // Subtle radial glow motif in the top-right
                Positioned(
                  top: -30,
                  right: -20,
                  child: Container(
                    width: 220,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      gradient: RadialGradient(
                        center: const Alignment(0.8, -0.8),
                        radius: 1.0,
                        colors: [
                          cs.onPrimary.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    top: AppSpacing.md,
                  bottom: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Brand with greeting pill directly to its right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const BrandLogo(size: 84),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(child: _GreetingPill(text: greeting)),
                      ],
                    ),
                    SizedBox(height: AppSpacing.sm),
                    // Collapse quick actions behind a single toggle
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final maxDateWidth =
                                  (constraints.maxWidth * 0.44).clamp(120.0, 190.0);
                              return Row(
                                children: [
                                  Expanded(
                                    child: _QuickActionButton(
                                      icon: _expanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      label: _expanded
                                          ? 'Hide quick actions'
                                          : 'Quick actions',
                                      onTap: () =>
                                          setState(() => _expanded = !_expanded),
                                      bgColor:
                                          cs.onPrimary.withValues(alpha: 0.12),
                                      fgColor: cs.onPrimary,
                                      borderColor:
                                          cs.onPrimary.withValues(alpha: 0.20),
                                    ),
                                  ),
                                  SizedBox(width: AppSpacing.sm),
                                  ConstrainedBox(
                                    constraints:
                                        BoxConstraints(maxWidth: maxDateWidth),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: _TodayPill(text: today),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: _expanded
                                ? Padding(
                                    padding:
                                        EdgeInsets.only(top: AppSpacing.sm),
                                    child: Wrap(
                                      spacing: AppSpacing.md,
                                      runSpacing: AppSpacing.sm,
                                      children: [
                                        Showcase(
                                          key: TutorialKeys.homeAddEntry,
                                          title: 'Log today',
                                          description:
                                              'Tap here anytime to add a new health entry.',
                                          child: _QuickActionButton(
                                            icon: Icons.add_circle_outline,
                                            label: 'Add Entry',
                                            onTap: widget.onAddEntry,
                                            bgColor: cs.onPrimary
                                                .withValues(alpha: 0.12),
                                            fgColor: cs.onPrimary,
                                            borderColor: cs.onPrimary
                                                .withValues(alpha: 0.20),
                                          ),
                                        ),
                                        _QuickActionButton(
                                          icon: Icons.groups_2_outlined,
                                          label: 'Communities',
                                          onTap: widget.onOpenCommunities,
                                          bgColor: cs.onPrimary
                                              .withValues(alpha: 0.12),
                                          fgColor: cs.onPrimary,
                                          borderColor: cs.onPrimary
                                              .withValues(alpha: 0.20),
                                        ),
                                        _QuickActionButton(
                                          icon: Icons.library_books_outlined,
                                          label: 'Resources',
                                          onTap: widget.onOpenResources,
                                          bgColor: cs.onPrimary
                                              .withValues(alpha: 0.12),
                                          fgColor: cs.onPrimary,
                                          borderColor: cs.onPrimary
                                              .withValues(alpha: 0.20),
                                        ),
                                        _QuickActionButton(
                                          icon: Icons.medical_services_outlined,
                                          label: 'My Therapist',
                                          onTap: widget.onOpenTherapist,
                                          bgColor: cs.onPrimary
                                              .withValues(alpha: 0.12),
                                          fgColor: cs.onPrimary,
                                          borderColor: cs.onPrimary
                                              .withValues(alpha: 0.20),
                                        ),
                                        _QuickActionButton(
                                          icon: Icons.menu_book_outlined,
                                          label: 'Education',
                                          onTap: widget.onOpenEducation,
                                          bgColor: cs.onPrimary
                                              .withValues(alpha: 0.12),
                                          fgColor: cs.onPrimary,
                                          borderColor: cs.onPrimary
                                              .withValues(alpha: 0.20),
                                        ),
                                        _QuickActionButton(
                                          icon: Icons.calendar_today_outlined,
                                          label: 'Current Plan',
                                          onTap: widget.onOpenPlan,
                                          bgColor: cs.onPrimary
                                              .withValues(alpha: 0.12),
                                          fgColor: cs.onPrimary,
                                          borderColor: cs.onPrimary
                                              .withValues(alpha: 0.20),
                                        ),
                                        _QuickActionButton(
                                          icon: Icons.headset_mic_outlined,
                                          label: 'Contact Support',
                                          onTap: widget.onContactSupport,
                                          bgColor: cs.onPrimary
                                              .withValues(alpha: 0.12),
                                          fgColor: cs.onPrimary,
                                          borderColor: cs.onPrimary
                                              .withValues(alpha: 0.20),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ]),
                  ],
                ),
              ),
                // Removed bottom fade for a crisp edge
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color bgColor;
  final Color fgColor;
  final Color? borderColor;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.bgColor,
    required this.fgColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
        constraints: const BoxConstraints(minHeight: 40),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fgColor, size: 24),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.labelLarge?.withColor(fgColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayPill extends StatelessWidget {
  final String text;
  const _TodayPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(
          scale: 0.98 + (t * 0.02),
          child: child,
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
        constraints: const BoxConstraints(minHeight: 40),
        decoration: BoxDecoration(
          color: cs.onPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: cs.onPrimary.withValues(alpha: 0.24), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_month, size: 22, color: cs.onPrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.labelLarge?.withColor(cs.onPrimary),
            ),
          ),
        ]),
      ),
    );
  }
}

class _GreetingPill extends StatelessWidget {
  final String text;
  const _GreetingPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset((1 - t) * 6, 0), child: child),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6),
        constraints: const BoxConstraints(minHeight: 36),
        decoration: BoxDecoration(
          color: cs.onPrimary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: cs.onPrimary.withValues(alpha: 0.20), width: 1),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(Icons.waving_hand, size: 20, color: cs.onPrimary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: context.textStyles.labelLarge?.withColor(cs.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthSnapshotSection extends StatefulWidget {
  final Map<String, double> stats7;
  final Map<String, double> statsPrev7;
  final int bladderStreak;
  final int bowelStreak;
  final List<double> painSeries;
  final List<double> sleepSeries;
  final List<double> energySeries;
  final List<double> stepsSeries;
  final List<double> hrSeries;
  final List<double> weightSeries;
  final List<double> tempSeries;
  final List<double> spasmSeries;
  final double deltaPain;
  final double deltaSleep;
  final double deltaEnergy;
  final double deltaSteps;
  final double deltaHR;
  final double deltaWeight;
  final double deltaTemp;
  final double deltaSpasm;
  final double avgSys;
  final double avgDia;
  final String moodTrend;
  final VoidCallback onLogToday;

  const _HealthSnapshotSection({
    required this.stats7,
    required this.statsPrev7,
    required this.bladderStreak,
    required this.bowelStreak,
    required this.painSeries,
    required this.sleepSeries,
    required this.energySeries,
    required this.stepsSeries,
    required this.hrSeries,
    required this.weightSeries,
    required this.tempSeries,
    required this.spasmSeries,
    required this.deltaPain,
    required this.deltaSleep,
    required this.deltaEnergy,
    required this.deltaSteps,
    required this.deltaHR,
    required this.deltaWeight,
    required this.deltaTemp,
    required this.deltaSpasm,
    required this.avgSys,
    required this.avgDia,
    required this.moodTrend,
    required this.onLogToday,
  });

  @override
  State<_HealthSnapshotSection> createState() => _HealthSnapshotSectionState();
}

class _HealthSnapshotSectionState extends State<_HealthSnapshotSection> {
  final bool _showAll = false;

  Widget _buildAllMetricsSheet(BuildContext context, ScrollController controller) {
    final cs = Theme.of(context).colorScheme;
    final avgPain = (widget.stats7['avgPain'] ?? 0).toStringAsFixed(1);
    final avgSleep = (widget.stats7['avgSleep'] ?? 0).toStringAsFixed(1);
    final avgEnergy = (widget.stats7['avgEnergy'] ?? 0).toStringAsFixed(1);
    final avgSteps = (widget.stats7['avgSteps'] ?? 0).toStringAsFixed(0);
    final avgHR = (widget.stats7['avgHeartRate'] ?? 0).toStringAsFixed(0);
    final avgWeight = (widget.stats7['avgWeight'] ?? 0).toStringAsFixed(1);
    final avgTemp = (widget.stats7['avgTemperature'] ?? 0).toStringAsFixed(1);
    final avgSpasm = (widget.stats7['avgSpasm'] ?? 0).toStringAsFixed(1);
    final avgBpStr = (widget.avgSys > 0 && widget.avgDia > 0)
        ? '${widget.avgSys.round()}/${widget.avgDia.round()} mmHg'
        : 'No data';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: AppSpacing.sm),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'All Metrics',
                    style: context.textStyles.headlineSmall?.semiBold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline.withValues(alpha: 0.2)),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '7-Day Health Overview',
                    style: context.textStyles.titleMedium?.semiBold,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Track your progress over the past week',
                    style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                  ),
                  SizedBox(height: AppSpacing.lg),
                  // Pain Chart
                  _DetailedMetricCard(
                    title: 'Pain Level',
                    value: avgPain,
                    unit: '/10',
                    icon: Icons.healing_outlined,
                    color: cs.error,
                    series: widget.painSeries,
                    delta: widget.deltaPain,
                    betterWhenHigher: false,
                    minY: 0,
                    maxY: 10,
                  ),
                  SizedBox(height: AppSpacing.md),
                  // Sleep Chart
                  _DetailedMetricCard(
                    title: 'Sleep Quality',
                    value: avgSleep,
                    unit: 'hrs',
                    icon: Icons.bedtime_outlined,
                    color: cs.secondary,
                    series: widget.sleepSeries,
                    delta: widget.deltaSleep,
                    betterWhenHigher: true,
                    minY: 0,
                    maxY: 12,
                  ),
                  SizedBox(height: AppSpacing.md),
                  // Energy Chart
                  _DetailedMetricCard(
                    title: 'Energy Level',
                    value: avgEnergy,
                    unit: '/10',
                    icon: Icons.bolt_outlined,
                    color: cs.tertiary,
                    series: widget.energySeries,
                    delta: widget.deltaEnergy,
                    betterWhenHigher: true,
                    minY: 0,
                    maxY: 10,
                  ),
                  SizedBox(height: AppSpacing.md),
                  // Steps Chart
                  if (widget.stepsSeries.isNotEmpty)
                    _DetailedMetricCard(
                      title: 'Daily Steps',
                      value: avgSteps,
                      unit: 'steps',
                      icon: Icons.directions_walk,
                      color: cs.primary,
                      series: widget.stepsSeries,
                      delta: widget.deltaSteps,
                      betterWhenHigher: true,
                      minY: 0,
                      maxY: _stepsMaxY(widget.stepsSeries),
                    ),
                  if (widget.stepsSeries.isNotEmpty) SizedBox(height: AppSpacing.md),
                  // Heart Rate Chart
                  if (widget.hrSeries.isNotEmpty)
                    _DetailedMetricCard(
                      title: 'Heart Rate',
                      value: avgHR,
                      unit: 'bpm',
                      icon: Icons.favorite_border,
                      color: Colors.red,
                      series: widget.hrSeries,
                      delta: widget.deltaHR,
                      betterWhenHigher: false,
                      minY: _hrMinY(widget.hrSeries),
                      maxY: _hrMaxY(widget.hrSeries),
                    ),
                  if (widget.hrSeries.isNotEmpty) SizedBox(height: AppSpacing.md),
                  // Weight Chart
                  if (widget.weightSeries.isNotEmpty)
                    _DetailedMetricCard(
                      title: 'Weight',
                      value: avgWeight,
                      unit: 'kg',
                      icon: Icons.monitor_weight_outlined,
                      color: Colors.blue,
                      series: widget.weightSeries,
                      delta: widget.deltaWeight,
                      betterWhenHigher: false,
                      minY: _weightMinY(widget.weightSeries),
                      maxY: _weightMaxY(widget.weightSeries),
                    ),
                  if (widget.weightSeries.isNotEmpty) SizedBox(height: AppSpacing.md),
                  // Temperature Chart
                  if (widget.tempSeries.isNotEmpty)
                    _DetailedMetricCard(
                      title: 'Temperature',
                      value: avgTemp,
                      unit: '°C',
                      icon: Icons.thermostat_outlined,
                      color: Colors.orange,
                      series: widget.tempSeries,
                      delta: widget.deltaTemp,
                      betterWhenHigher: false,
                      minY: _tempMinY(widget.tempSeries),
                      maxY: _tempMaxY(widget.tempSeries),
                    ),
                  if (widget.tempSeries.isNotEmpty) SizedBox(height: AppSpacing.md),
                  // Spasm Chart
                  if (widget.spasmSeries.isNotEmpty)
                    _DetailedMetricCard(
                      title: 'Spasm Intensity',
                      value: avgSpasm,
                      unit: '/10',
                      icon: Icons.flash_on_outlined,
                      color: Colors.purple,
                      series: widget.spasmSeries,
                      delta: widget.deltaSpasm,
                      betterWhenHigher: false,
                      minY: 0,
                      maxY: 10,
                    ),
                  if (widget.spasmSeries.isNotEmpty) SizedBox(height: AppSpacing.md),
                  // Blood Pressure (if available)
                  if (avgBpStr != 'No data')
                    Container(
                      padding: AppSpacing.paddingMd,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.pink.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.monitor_heart_outlined, color: Colors.pink, size: 24),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Blood Pressure',
                                  style: context.textStyles.labelLarge?.withColor(cs.onSurfaceVariant),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  avgBpStr,
                                  style: context.textStyles.titleLarge?.semiBold,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (avgBpStr != 'No data') SizedBox(height: AppSpacing.md),
                  // Mood indicator
                  if (widget.moodTrend.isNotEmpty)
                    Container(
                      padding: AppSpacing.paddingMd,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(_moodEmoji(widget.moodTrend), style: const TextStyle(fontSize: 24)),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Overall Mood',
                                  style: context.textStyles.labelLarge?.withColor(cs.onSurfaceVariant),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  widget.moodTrend,
                                  style: context.textStyles.titleLarge?.semiBold,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: AppSpacing.xl),
                  // Footer note
                  Container(
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: cs.primary),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Track your daily health metrics in the Tracker tab for more detailed insights.',
                            style: context.textStyles.bodySmall?.withColor(cs.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAllMetrics() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return _buildAllMetricsSheet(context, scrollController);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avgPain = (widget.stats7['avgPain'] ?? 0).toStringAsFixed(1);
    final avgSleep = (widget.stats7['avgSleep'] ?? 0).toStringAsFixed(1);
    final avgEnergy = (widget.stats7['avgEnergy'] ?? 0).toStringAsFixed(1);
    final avgSteps = (widget.stats7['avgSteps'] ?? 0).toStringAsFixed(0);
    final avgHR = (widget.stats7['avgHeartRate'] ?? 0).toStringAsFixed(0);
    final avgWeight = (widget.stats7['avgWeight'] ?? 0).toStringAsFixed(1);
    final avgTemp = (widget.stats7['avgTemperature'] ?? 0).toStringAsFixed(1);
    final avgSpasm = (widget.stats7['avgSpasm'] ?? 0).toStringAsFixed(1);
    final avgBpStr = (widget.avgSys > 0 && widget.avgDia > 0)
        ? '${widget.avgSys.round()}/${widget.avgDia.round()} mmHg'
        : '';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title + View all toggle
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Health Snapshot',
                    style: context.textStyles.titleLarge?.semiBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _openAllMetrics,
                  icon: Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: cs.primary,
                  ),
                  label: Text(
                    'View all',
                    style: context.textStyles.labelLarge?.withColor(cs.primary),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          // Always-visible: 4 compact tiles in 2x2 grid
          LayoutBuilder(
            builder: (context, constraints) {
              final gap = AppSpacing.xs;
              final itemWidth = (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _CompactStatTile(
                      title: 'Pain',
                      value: avgPain,
                      icon: Icons.healing_outlined,
                      color: cs.error,
                      delta: widget.deltaPain,
                      series: widget.painSeries,
                      betterWhenHigher: false,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _CompactMoodTile(mood: widget.moodTrend),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _CompactStatTile(
                      title: 'Sleep',
                      value: avgSleep,
                      icon: Icons.bedtime_outlined,
                      color: cs.secondary,
                      delta: widget.deltaSleep,
                      series: widget.sleepSeries,
                      betterWhenHigher: true,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _CompactStatTile(
                      title: 'Energy',
                      value: avgEnergy,
                      icon: Icons.bolt_outlined,
                      color: cs.tertiary,
                      delta: widget.deltaEnergy,
                      series: widget.energySeries,
                      betterWhenHigher: true,
                    ),
                  ),
                ],
              );
            },
          ),
          // Expandable: more detail + additional metrics
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      int cols;
                      if (w >= 720) {
                        cols = 3;
                      } else if (w >= 480) {
                        cols = 2;
                      } else {
                        cols = 1;
                      }
                      final gap = AppSpacing.md;
                      final itemWidth = (w - (gap * (cols - 1))) / cols;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _MiniStatAdvanced(
                              title: 'Steps',
                              value: avgSteps,
                              icon: Icons.directions_walk,
                              color: cs.primary,
                              series: widget.stepsSeries,
                              minY: 0,
                              maxY: _stepsMaxY(widget.stepsSeries),
                              delta: widget.deltaSteps,
                              betterWhenHigher: true,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _MiniStatAdvanced(
                              title: 'Heart Rate',
                              value: avgHR + ' bpm',
                              icon: Icons.favorite_border,
                              color: cs.secondary,
                              series: widget.hrSeries,
                              minY: _hrMinY(widget.hrSeries),
                              maxY: _hrMaxY(widget.hrSeries),
                              delta: widget.deltaHR,
                              betterWhenHigher: false,
                            ),
                          ),
                          if (widget.weightSeries.isNotEmpty)
                            SizedBox(
                              width: itemWidth,
                              child: _MiniStatAdvanced(
                                title: 'Weight',
                                value: avgWeight + ' kg',
                                icon: Icons.monitor_weight_outlined,
                                color: cs.primary,
                                series: widget.weightSeries,
                                minY: _weightMinY(widget.weightSeries),
                                maxY: _weightMaxY(widget.weightSeries),
                                delta: widget.deltaWeight,
                                betterWhenHigher: false,
                              ),
                            ),
                          if (widget.tempSeries.isNotEmpty)
                            SizedBox(
                              width: itemWidth,
                              child: _MiniStatAdvanced(
                                title: 'Temperature',
                                value: avgTemp + ' °C',
                                icon: Icons.thermostat_outlined,
                                color: cs.error,
                                series: widget.tempSeries,
                                minY: 35.0,
                                maxY: 40.0,
                                delta: widget.deltaTemp,
                                betterWhenHigher: false,
                              ),
                            ),
                          if (widget.spasmSeries.isNotEmpty)
                            SizedBox(
                              width: itemWidth,
                              child: _MiniStatAdvanced(
                                title: 'Spasm Frequency',
                                value: avgSpasm,
                                icon: Icons.warning_amber_outlined,
                                color: Colors.orange,
                                series: widget.spasmSeries,
                                minY: 0,
                                maxY: 10,
                                delta: widget.deltaSpasm,
                                betterWhenHigher: false,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (avgBpStr.isNotEmpty ||
                      widget.bladderStreak > 0 ||
                      widget.bowelStreak > 0) ...[
                    SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (avgBpStr.isNotEmpty)
                          _Chip(
                            text: 'Avg BP: $avgBpStr',
                            icon: Icons.monitor_heart_outlined,
                          ),
                        if (widget.bladderStreak > 0)
                          _Chip(
                            text:
                                'Bladder streak: ${widget.bladderStreak} days',
                            icon: Icons.local_fire_department,
                          ),
                        if (widget.bowelStreak > 0)
                          _Chip(
                            text: 'Bowel streak: ${widget.bowelStreak} days',
                            icon: Icons.local_fire_department,
                          ),
                      ],
                    ),
                  ],
                  SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: widget.onLogToday,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Log Today'),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _showAll
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  double _stepsMaxY(List<double> series) {
    if (series.isEmpty) return 10000;
    double max = 0;
    for (final v in series) {
      if (v > max) max = v;
    }
    if (max <= 0) return 1000;
    // Pad headroom
    return (max * 1.15).clamp(1000, 20000);
  }

  double _hrMaxY(List<double> series) {
    if (series.isEmpty) return 140;
    double max = 0;
    for (final v in series) {
      if (v > max) max = v;
    }
    if (max <= 0) return 120;
    return (max + 10).clamp(80, 200);
  }

  double _hrMinY(List<double> series) {
    if (series.isEmpty) return 50;
    double min = 1000;
    for (final v in series) {
      if (v < min) min = v;
    }
    if (min == 1000) return 50;
    return (min - 10).clamp(40, 90);
  }

  double _weightMaxY(List<double> series) {
    if (series.isEmpty) return 100;
    double max = 0;
    for (final v in series) {
      if (v > max) max = v;
    }
    if (max <= 0) return 100;
    return (max + 5).clamp(40, 200);
  }

  double _weightMinY(List<double> series) {
    if (series.isEmpty) return 40;
    double min = 1000;
    for (final v in series) {
      if (v < min) min = v;
    }
    if (min == 1000) return 40;
    return (min - 5).clamp(30, 150);
  }

  double _tempMaxY(List<double> series) {
    if (series.isEmpty) return 40;
    double max = 0;
    for (final v in series) {
      if (v > max) max = v;
    }
    if (max <= 0) return 40;
    return (max + 1).clamp(35, 42);
  }

  double _tempMinY(List<double> series) {
    if (series.isEmpty) return 35;
    double min = 1000;
    for (final v in series) {
      if (v < min) min = v;
    }
    if (min == 1000) return 35;
    return (min - 1).clamp(34, 38);
  }

  String _moodEmoji(String m) {
    final t = m.toLowerCase();
    if (t.contains('great') || t.contains('happy') || t.contains('good')) {
      return '😊';
    }
    if (t.contains('ok') || t.contains('fine') || t.contains('neutral')) {
      return '😐';
    }
    if (t.contains('sad') || t.contains('down') || t.contains('low')) {
      return '😔';
    }
    if (t.contains('anx') || t.contains('stress') || t.contains('worry')) {
      return '😟';
    }
    if (t.contains('angry') || t.contains('mad') || t.contains('frust')) {
      return '😠';
    }
    if (t.contains('tired') || t.contains('exhaust')) return '😴';
    return '🙂';
  }
}

class _AIInsightsSheet extends StatefulWidget {
  final Map<String, double> stats7;
  final Map<String, double> statsPrev7;
  final List<double> painSeries;
  final List<double> sleepSeries;
  final List<double> energySeries;
  final List<double> stepsSeries;
  final List<double> hrSeries;

  const _AIInsightsSheet({
    required this.stats7,
    required this.statsPrev7,
    required this.painSeries,
    required this.sleepSeries,
    required this.energySeries,
    required this.stepsSeries,
    required this.hrSeries,
  });

  @override
  State<_AIInsightsSheet> createState() => _AIInsightsSheetState();
}

class _GoalTipsSheet extends StatefulWidget {
  final Goal goal;
  const _GoalTipsSheet({required this.goal});

  @override
  State<_GoalTipsSheet> createState() => _GoalTipsSheetState();
}

class _GoalTipsSheetState extends State<_GoalTipsSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _res;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
      _res = null;
    });
    try {
      // AI temporarily disabled: provide a simple, offline set of tips.
      final title = widget.goal.title.trim();
      final desc = (widget.goal.description ?? '').trim();
      final tips = <String>[
        if (desc.isNotEmpty) 'Restate your goal in one sentence: "$desc"',
        'Choose the smallest daily version you can do on a low-energy day.',
        'Put it on your calendar as a repeating reminder.',
        'Track one signal (easy/medium/hard) to spot patterns.',
      ];

      final res = <String, dynamic>{
        'oneLiner': title.isNotEmpty ? 'Small steps toward "$title" add up.' : 'Small steps add up.',
        'tips': tips,
        'exampleLogs': <String>[
          'Did the tiny version today (5 min).',
          'Felt easier than yesterday. Keeping it going.',
        ],
        'disclaimer': 'Tips are general and educational — not medical advice.',
      };
      if (!mounted) return;
      setState(() {
        _res = res;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Goal tips error: $e');
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
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10)),
                child:
                    Icon(Icons.lightbulb_outline, color: cs.primary, size: 18),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: Text('Tips for "${widget.goal.title}"',
                      style: context.textStyles.titleLarge?.semiBold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              IconButton(
                  icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).pop())
            ]),
            SizedBox(height: AppSpacing.md),
            if (_loading) ...[
              Row(children: [
                SizedBox(width: 20, height: 20, child: InlineLoadingDot()),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: Text('Generating personalized tips…',
                        style: context.textStyles.bodyMedium)),
              ]),
            ] else if (_error != null) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: cs.error.withValues(alpha: 0.2))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: cs.error),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                          child: Text(
                              'Could not generate tips. Please try again.',
                              style: context.textStyles.bodyMedium
                                  ?.withColor(cs.error))),
                    ]),
              ),
              SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _run,
                  icon: Icon(Icons.refresh, color: cs.onPrimary),
                  label: Text('Try again',
                      style: context.textStyles.labelLarge
                          ?.withColor(cs.onPrimary)),
                ),
              )
            ] else if (_res != null) ...[
              if ((_res!['oneLiner'] ?? '').toString().trim().isNotEmpty) ...[
                Text(_res!['oneLiner'], style: context.textStyles.titleSmall),
                SizedBox(height: AppSpacing.md),
              ],
              if ((_res!['tips'] as List).isNotEmpty) ...[
                _InsightBlock(
                    title: 'Suggested next steps',
                    icon: Icons.checklist_outlined,
                    child: _Bullets(items: List<String>.from(_res!['tips']))),
                SizedBox(height: AppSpacing.md),
              ],
              if ((_res!['exampleLogs'] as List).isNotEmpty) ...[
                _InsightBlock(
                    title: 'Example logs',
                    icon: Icons.event_available_outlined,
                    child: _Bullets(
                        items: List<String>.from(_res!['exampleLogs']))),
                SizedBox(height: AppSpacing.md),
              ],
              Text(_res!['disclaimer'] ?? '',
                  style: context.textStyles.labelSmall
                      ?.withColor(cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AIInsightsSheetState extends State<_AIInsightsSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final snap = <String, dynamic>{
        'avgPain': (widget.stats7['avgPain'] ?? 0).toDouble(),
        'avgSleep': (widget.stats7['avgSleep'] ?? 0).toDouble(),
        'avgEnergy': (widget.stats7['avgEnergy'] ?? 0).toDouble(),
        'avgSteps': (widget.stats7['avgSteps'] ?? 0).toDouble(),
        'avgHeartRate': (widget.stats7['avgHeartRate'] ?? 0).toDouble(),
        'avgSys': (widget.stats7['avgSys'] ?? 0).toDouble(),
        'avgDia': (widget.stats7['avgDia'] ?? 0).toDouble(),
      };
      final prev = <String, dynamic>{
        'avgPain': (widget.statsPrev7['avgPain'] ?? 0).toDouble(),
        'avgSleep': (widget.statsPrev7['avgSleep'] ?? 0).toDouble(),
        'avgEnergy': (widget.statsPrev7['avgEnergy'] ?? 0).toDouble(),
        'avgSteps': (widget.statsPrev7['avgSteps'] ?? 0).toDouble(),
        'avgHeartRate': (widget.statsPrev7['avgHeartRate'] ?? 0).toDouble(),
        'avgSys': (widget.statsPrev7['avgSys'] ?? 0).toDouble(),
        'avgDia': (widget.statsPrev7['avgDia'] ?? 0).toDouble(),
      };
      final series = <String, List<double>>{
        'pain': List<double>.from(widget.painSeries),
        'sleep': List<double>.from(widget.sleepSeries),
        'energy': List<double>.from(widget.energySeries),
        'steps': List<double>.from(widget.stepsSeries),
        'heartRate': List<double>.from(widget.hrSeries),
      };

      // AI temporarily disabled: return a lightweight, rule-based summary.
      String trend(double now, double before, {String higherIs = 'higher'}) {
        final diff = now - before;
        if (diff.abs() < 0.15) return 'about the same';
        if (diff > 0) return higherIs == 'higher' ? 'up' : 'down';
        return higherIs == 'higher' ? 'down' : 'up';
      }

      final avgPain = (snap['avgPain'] as double);
      final prevPain = (prev['avgPain'] as double);
      final avgSleep = (snap['avgSleep'] as double);
      final prevSleep = (prev['avgSleep'] as double);
      final avgEnergy = (snap['avgEnergy'] as double);
      final prevEnergy = (prev['avgEnergy'] as double);

      final painTrend = trend(avgPain, prevPain, higherIs: 'higher');
      final sleepTrend = trend(avgSleep, prevSleep, higherIs: 'higher');
      final energyTrend = trend(avgEnergy, prevEnergy, higherIs: 'higher');
      final res = <String, dynamic>{
        'summary':
            'Compared to your previous week, pain is $painTrend, sleep is $sleepTrend, and energy is $energyTrend.',
        'highlights': <String>[
          if (sleepTrend == 'up') 'Nice work — average sleep improved week over week.',
          if (energyTrend == 'up') 'Energy trended up compared to last week.',
        ],
        'risks': <String>[
          if (painTrend == 'up')
            'Pain trended up. Consider pacing and note what days felt harder.',
        ],
        'suggestedActions': <String>[
          'Pick one small routine change and try it for 3 days.',
          'Log a quick note on “easy/medium/hard” to learn what helps.',
        ],
        'trendByMetric': <String, String>{
          'Pain': painTrend,
          'Sleep': sleepTrend,
          'Energy': energyTrend,
        },
        'disclaimer': 'General insights only — not medical advice.',
      };
      setState(() {
        _result = res;
        _loading = false;
      });
    } catch (e) {
      debugPrint('AI insights error: $e');
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.auto_awesome, color: cs.primary, size: 18),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: Text('AI Health Insights',
                        style: context.textStyles.titleLarge?.semiBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                IconButton(
                  icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            SizedBox(height: AppSpacing.md),
            if (_loading) ...[
              Row(children: [
                SizedBox(width: 20, height: 20, child: InlineLoadingDot()),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: Text('Analyzing your recent tracking…',
                        style: context.textStyles.bodyMedium)),
              ]),
            ] else if (_error != null) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: cs.error.withValues(alpha: 0.2))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: cs.error),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                          child: Text(
                              'Could not generate insights. Please try again.',
                              style: context.textStyles.bodyMedium
                                  ?.withColor(cs.error))),
                    ]),
              ),
              SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _run,
                  icon: Icon(Icons.refresh, color: cs.onPrimary),
                  label: Text('Try again',
                      style: context.textStyles.labelLarge
                          ?.withColor(cs.onPrimary)),
                ),
              )
            ] else if (_result != null) ...[
              if ((_result!['suggestedActions'] as List).isNotEmpty) ...[
                Text('Quick tips',
                    style: context.textStyles.titleSmall?.semiBold),
                SizedBox(height: AppSpacing.xs),
                _TipsChips(
                    tips: List<String>.from(_result!['suggestedActions'])
                        .take(6)
                        .toList()),
                SizedBox(height: AppSpacing.md),
              ],
              _InsightBlock(
                  title: 'Summary',
                  icon: Icons.summarize_outlined,
                  child: Text(_result!['summary'] ?? '',
                      style: context.textStyles.bodyMedium)),
              SizedBox(height: AppSpacing.md),
              if ((_result!['highlights'] as List).isNotEmpty)
                _InsightBlock(
                  title: 'Highlights',
                  icon: Icons.trending_up,
                  child: _Bullets(
                      items: List<String>.from(
                          _result!['highlights'] ?? const [])),
                ),
              if ((_result!['highlights'] as List).isNotEmpty)
                SizedBox(height: AppSpacing.md),
              if ((_result!['risks'] as List).isNotEmpty)
                _InsightBlock(
                  title: 'Watch-outs',
                  icon: Icons.flag_outlined,
                  child: _Bullets(
                      items: List<String>.from(_result!['risks'] ?? const [])),
                ),
              if ((_result!['risks'] as List).isNotEmpty)
                SizedBox(height: AppSpacing.md),
              if ((_result!['suggestedActions'] as List).isNotEmpty)
                _InsightBlock(
                  title: 'Suggested actions',
                  icon: Icons.checklist_outlined,
                  child: _Bullets(
                      items: List<String>.from(
                          _result!['suggestedActions'] ?? const [])),
                ),
              SizedBox(height: AppSpacing.md),
              _TrendChips(
                  trend: Map<String, String>.from(
                      _result!['trendByMetric'] ?? const {})),
              SizedBox(height: AppSpacing.md),
              Text(_result!['disclaimer'] ?? '',
                  style: context.textStyles.labelSmall
                      ?.withColor(cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _InsightBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _InsightBlock(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: cs.onSurfaceVariant),
          SizedBox(width: AppSpacing.sm),
          Expanded(
              child:
                  Text(title, style: context.textStyles.titleSmall?.semiBold)),
        ]),
        SizedBox(height: AppSpacing.sm),
        child,
      ]),
    );
  }
}

class _Bullets extends StatelessWidget {
  final List<String> items;
  const _Bullets({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 6, color: cs.onSurfaceVariant),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text(t, style: context.textStyles.bodyMedium)),
                    ]),
              ))
          .toList(),
    );
  }
}

class _TrendChips extends StatelessWidget {
  final Map<String, String> trend;
  const _TrendChips({required this.trend});

  Color _colorFor(BuildContext context, String metric, String dir) {
    final cs = Theme.of(context).colorScheme;
    // For metrics where lower is better (pain, heartRate), an "up" may be bad
    final lowerIsBetter = metric == 'pain' || metric == 'heartRate';
    if (dir == 'flat' || dir.isEmpty) return cs.onSurfaceVariant;
    final up = dir == 'up';
    final improvement = lowerIsBetter ? !up : up;
    return improvement ? cs.primary : cs.error;
  }

  IconData _iconFor(String dir) {
    switch (dir) {
      case 'up':
        return Icons.trending_up;
      case 'down':
        return Icons.trending_down;
      default:
        return Icons.horizontal_rule;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox.shrink();
    final items = <Widget>[];
    trend.forEach((k, v) {
      final label = '${k[0].toUpperCase()}${k.substring(1)}';
      final color = _colorFor(context, k, v);
      items.add(Container(
        margin: EdgeInsets.only(right: AppSpacing.sm),
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_iconFor(v), size: 14, color: color),
          SizedBox(width: 6),
          Text(label, style: context.textStyles.labelMedium?.withColor(color)),
        ]),
      ));
    });
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal, child: Row(children: items));
  }
}

class _TipsChips extends StatelessWidget {
  final List<String> tips;
  const _TipsChips({required this.tips});

  @override
  Widget build(BuildContext context) {
    if (tips.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final items = tips
        .map((t) => Container(
              margin:
                  EdgeInsets.only(right: AppSpacing.sm, bottom: AppSpacing.xs),
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: cs.primary.withValues(alpha: 0.20), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lightbulb_outline, size: 14),
                SizedBox(width: 6),
                Text(t),
              ]),
            ))
        .toList();
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal, child: Row(children: items));
  }
}

// Inline AI tips card removed per user request

class _MiniStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          SizedBox(width: AppSpacing.sm),
          // Make text area flexible to avoid horizontal overflow
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.labelMedium?.withColor(
                    Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.titleLarge?.semiBold,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _MiniStatAdvanced extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final List<double> series;
  final double minY;
  final double maxY;
  // delta: raw delta (current - previous). Positive means the value increased.
  final double delta;
  // Whether a higher value is better for this metric.
  // For example: Pain (false), Heart Rate (false), Sleep/Energy/Steps (true)
  final bool betterWhenHigher;

  const _MiniStatAdvanced({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.series,
    required this.minY,
    required this.maxY,
    required this.delta,
    required this.betterWhenHigher,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const double epsilon = 0.05; // threshold to treat as "no meaningful change"
    // Determine immediate trend from the most recent change in the time series (last two points).
    // This aligns the arrow with what the user just logged (e.g., 2/10 -> 8/10 shows an up arrow
    // for metrics where higher is better), independent of rolling 7-day averages used for delta text.
    double? lastChange;
    if (series.length >= 2) {
      lastChange = series.last - series[series.length - 2];
    } else if (delta != 0) {
      // Fallback to weekly delta when only one data point exists
      lastChange = delta;
    }
    final bool isNeutral = lastChange == null || lastChange.abs() < epsilon;
    final bool trendUp = (lastChange ?? 0) > 0;
    // Improvement depends on metric semantics, and arrow should reflect improvement/decline
    final bool isImprovement = betterWhenHigher ? trendUp : !trendUp;
    final IconData arrow = isNeutral
        ? Icons.horizontal_rule
        : (isImprovement ? Icons.arrow_upward : Icons.arrow_downward);
    final Color deltaColor = isNeutral
        ? cs.onSurfaceVariant
        : (isImprovement ? cs.primary : cs.error);

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: cs.surface,
        border: Border.all(color: cs.outline.withValues(alpha: 0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.labelMedium?.withColor(
                        cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.titleLarge?.semiBold,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: deltaColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(arrow, size: 14, color: deltaColor),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 38,
            child: _Sparkline(
              values: series,
              minY: minY,
              maxY: maxY,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double delta;
  final List<double> series;
  final bool betterWhenHigher;

  const _CompactStatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.delta,
    required this.series,
    required this.betterWhenHigher,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const double epsilon = 0.05;
    double? lastChange;
    if (series.length >= 2) {
      lastChange = series.last - series[series.length - 2];
    } else if (delta != 0) {
      lastChange = delta;
    }
    final bool isNeutral = lastChange == null || lastChange.abs() < epsilon;
    final bool trendUp = (lastChange ?? 0) > 0;
    final bool isImprovement = betterWhenHigher ? trendUp : !trendUp;
    final IconData arrow = isNeutral
        ? Icons.horizontal_rule
        : (trendUp ? Icons.arrow_upward : Icons.arrow_downward);
    final Color trendColor = isNeutral
        ? cs.onSurfaceVariant
        : (isImprovement ? cs.primary : cs.error);

    return Container(
      padding: EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.labelSmall
                      ?.withColor(cs.onSurfaceVariant),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.titleSmall?.semiBold,
                ),
              ],
            ),
          ),
          Icon(arrow, size: 14, color: trendColor),
        ],
      ),
    );
  }
}

class _CompactMoodTile extends StatelessWidget {
  final String mood;
  const _CompactMoodTile({required this.mood});

  String _moodEmoji(String m) {
    final t = m.toLowerCase();
    if (t.contains('great') || t.contains('happy') || t.contains('good')) {
      return '😊';
    }
    if (t.contains('ok') || t.contains('fine') || t.contains('neutral')) {
      return '😐';
    }
    if (t.contains('sad') || t.contains('down') || t.contains('low')) {
      return '😔';
    }
    if (t.contains('anx') || t.contains('stress') || t.contains('worry')) {
      return '😟';
    }
    if (t.contains('angry') || t.contains('mad') || t.contains('frust')) {
      return '😠';
    }
    if (t.contains('tired') || t.contains('exhaust')) return '😴';
    return '🙂';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasMood = mood.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cs.tertiary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.emoji_emotions_outlined,
                color: cs.tertiary, size: 18),
          ),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mood',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.labelSmall
                      ?.withColor(cs.onSurfaceVariant),
                ),
                Row(
                  children: [
                    if (hasMood)
                      Text(_moodEmoji(mood),
                          style: const TextStyle(fontSize: 16)),
                    if (hasMood) SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        hasMood ? mood : '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.titleSmall?.semiBold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> values;
  final double minY;
  final double maxY;
  final Color color;

  const _Sparkline({
    required this.values,
    required this.minY,
    required this.maxY,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (values.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          color: cs.surfaceContainerHighest,
          child: Center(
            child: Text(
              'No data',
              style:
                  context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
            ),
          ),
        ),
      );
    }
    final spots = values
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    // fl_chart can paint outside its layout bounds (especially with curved lines).
    // Clip here so the sparkline never bleeds into the stat header (like in the screenshot).
    return ClipRect(
      child: LineChart(
        LineChartData(
          clipData: const FlClipData.all(),
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              preventCurveOverShooting: true,
              barWidth: 2,
              color: color,
              isStrokeCapRound: true,
              spots: spots,
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.10),
              ),
              dotData: FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Chip({required this.text, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer),
          SizedBox(width: 6),
          Text(
            text,
            style: context.textStyles.labelMedium?.withColor(
              Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickChip(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: cs.primary.withValues(alpha: 0.20), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16),
          SizedBox(width: 6),
          Text(label),
        ]),
      ),
    );
  }
}

class _GoalsSection extends StatelessWidget {
  final List<Goal> goals;
  final void Function(String goalId) onIncrement;
  final VoidCallback onAdd;
  final void Function(Goal) onEdit;
  final void Function({
    required String title,
    String? description,
    int target,
    String period,
    String? linked,
  }) onQuickAdd;

  const _GoalsSection(
      {required this.goals,
      required this.onIncrement,
      required this.onAdd,
      required this.onEdit,
      required this.onQuickAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Daily Goals',
                  style: context.textStyles.titleLarge?.semiBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: Icon(Icons.add_circle_outline,
                    color: Theme.of(context).colorScheme.onPrimary),
                label: Text('Add goal',
                    style: context.textStyles.labelLarge
                        ?.withColor(Theme.of(context).colorScheme.primary)),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          // Quick Picks (includes mental health options)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PickChip(
                  icon: Icons.self_improvement,
                  label: '5‑min breathing',
                  onTap: () => onQuickAdd(
                    title: '5‑min breathing',
                    description: 'Guided breathing to reset and calm',
                    target: 7,
                    period: 'weekly',
                    linked: 'mood',
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                _PickChip(
                  icon: Icons.menu_book_outlined,
                  label: 'Gratitude journal',
                  onTap: () => onQuickAdd(
                    title: 'Gratitude journal',
                    description: 'List 3 things you’re grateful for',
                    target: 7,
                    period: 'weekly',
                    linked: 'mood',
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                _PickChip(
                  icon: Icons.mood_outlined,
                  label: 'Mood check‑in',
                  onTap: () => onQuickAdd(
                    title: 'Mood check‑in',
                    description: 'Quick mood score and note',
                    target: 7,
                    period: 'weekly',
                    linked: 'mood',
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                _PickChip(
                  icon: Icons.directions_walk,
                  label: '10‑min walk',
                  onTap: () => onQuickAdd(
                    title: '10‑minute walk',
                    description: 'Get outside for a short walk',
                    target: 5,
                    period: 'weekly',
                    linked: 'steps',
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                _PickChip(
                  icon: Icons.psychology_alt_outlined,
                  label: 'CBT thought record',
                  onTap: () => onQuickAdd(
                    title: 'CBT thought record',
                    description: 'Capture a thought and reframe it',
                    target: 3,
                    period: 'weekly',
                    linked: 'mood',
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                _PickChip(
                  icon: Icons.nature_people_outlined,
                  label: 'Go outside',
                  onTap: () => onQuickAdd(
                    title: 'Go outside for fresh air',
                    description: '2–5 minutes outdoors for a reset',
                    target: 5,
                    period: 'weekly',
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                _PickChip(
                  icon: Icons.nights_stay_outlined,
                  label: 'Sleep by 11',
                  onTap: () => onQuickAdd(
                    title: 'Sleep by 11:00 pm',
                    description: 'Lights out before 11 to support recovery',
                    target: 5,
                    period: 'weekly',
                    linked: 'sleep',
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                _PickChip(
                  icon: Icons.accessibility_new_outlined,
                  label: 'Stretch routine',
                  onTap: () => onQuickAdd(
                    title: 'Stretch routine',
                    description: 'Gentle full‑body or PT stretches',
                    target: 5,
                    period: 'weekly',
                    linked: 'spasm',
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                _PickChip(
                  icon: Icons.phone_in_talk_outlined,
                  label: 'Reach out',
                  onTap: () => onQuickAdd(
                    title: 'Reach out to a friend',
                    description: 'Call or text to connect with someone',
                    target: 3,
                    period: 'weekly',
                    linked: 'mood',
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                _PickChip(
                  icon: Icons.water_drop_outlined,
                  label: 'Hydration',
                  onTap: () => onQuickAdd(
                    title: 'Hydration habit',
                    description: 'Aim for ~8 cups of water',
                    target: 7,
                    period: 'weekly',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          if (goals.isEmpty)
            Card(
              child: Padding(
                padding: AppSpacing.paddingSm,
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No active goals yet',
                              style: context.textStyles.titleSmall?.semiBold),
                          SizedBox(height: 2),
                          Text('Create a weekly goal to stay on track.',
                              style: context.textStyles.bodySmall?.withColor(
                                  Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                          SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.sm,
                            children: [
                              FilledButton.icon(
                                onPressed: onAdd,
                                icon: Icon(Icons.add,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary),
                                label: const Text('Add goal'),
                              ),
                              OutlinedButton(
                                onPressed: () => context.push('/tracker'),
                                child: const Text('Open tracker'),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: goals
                    .map((g) => Padding(
                          padding: EdgeInsets.only(right: AppSpacing.md),
                          child: _GoalCard(
                              goal: g,
                              onIncrement: onIncrement,
                              onEdit: onEdit),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final void Function(String goalId) onIncrement;
  final void Function(Goal) onEdit;
  const _GoalCard(
      {required this.goal, required this.onIncrement, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final pct = goal.targetPerPeriod == 0
        ? 0.0
        : (goal.progressThisPeriod / goal.targetPerPeriod)
            .clamp(0, 1)
            .toDouble();
    return SizedBox(
      width: 260,
      child: Card(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                  Theme.of(context)
                      .colorScheme
                      .tertiary
                      .withValues(alpha: 0.06),
                ],
              ),
            ),
            child: InkWell(
              onTap: () => onEdit(goal),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Padding(
                padding: AppSpacing.paddingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.emoji_events_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            size: 18,
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                            child: Text(goal.title,
                                style: context.textStyles.titleMedium?.semiBold,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis)),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_horiz,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          onSelected: (value) {
                            if (value == 'edit') {
                              onEdit(goal);
                            } else if (value == 'tips') {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                backgroundColor:
                                    Theme.of(context).colorScheme.surface,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(AppRadius.lg))),
                                builder: (ctx) => _GoalTipsSheet(goal: goal),
                              );
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(
                                value: 'tips', child: Text('View tips')),
                          ],
                        ),
                      ],
                    ),
                    if (goal.description != null) ...[
                      SizedBox(height: AppSpacing.sm),
                      Text(goal.description!,
                          style: context.textStyles.bodySmall?.withColor(
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                    SizedBox(height: AppSpacing.md),
                    // Reduced signal: show a single progress representation (bar + count)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child:
                              LinearProgressIndicator(value: pct, minHeight: 8),
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${goal.progressThisPeriod}/${goal.targetPerPeriod} this week',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyles.labelMedium
                                    ?.withColor(Theme.of(context)
                                        .colorScheme
                                        .onSurface),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.md),
                    // Single clear CTA: Update progress
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => onIncrement(goal.id),
                        icon: Icon(Icons.check_circle,
                            color: Theme.of(context).colorScheme.onPrimary),
                        label: const Text('Update progress'),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Avatar button removed per request

class _NextStepCard extends StatefulWidget {
  final Milestone milestone;
  final VoidCallback onMarkDone;
  final void Function(int days) onSnooze;
  final VoidCallback onOpenPlan;
  const _NextStepCard(
      {required this.milestone,
      required this.onMarkDone,
      required this.onSnooze,
      required this.onOpenPlan});

  @override
  State<_NextStepCard> createState() => _NextStepCardState();
}

class _NextStepCardState extends State<_NextStepCard> {
  bool _justCompleted = false;

  Future<void> _openLearnMore() async {
    final m = widget.milestone;
    String? conditionName;
    String? conditionDetailsSummary;
    try {
      final id = m.conditionId;
      if (id != null && id.trim().isNotEmpty) {
        final user = context.read<UserProvider>().currentUser;
        final cond = await ConditionService().getConditionById(id);
        conditionName = cond?.name;
        if (cond != null && user != null) {
          final detail = ConditionDetail.tryFromUserPreferences(
            preferences: user.preferences,
            conditionId: cond.id,
          );
          if (detail != null && detail.hasDetails && conditionName?.trim().isNotEmpty == true) {
            conditionDetailsSummary = detail.toAiSummary(conditionName!);
          }
        }
      }
    } catch (e) {
      debugPrint('Home.NextStep learn more: failed to load condition name: $e');
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MilestoneEducationPage(
          stepTitle: m.title,
          stepDescription: m.description,
          conditionName: conditionName,
          conditionDetailsSummary: conditionDetailsSummary,
        ),
      ),
    );
  }

  Future<void> _handleMarkDone() async {
    if (_justCompleted) return;
    setState(() => _justCompleted = true);
    await Future.delayed(const Duration(milliseconds: 350));
    try {
      widget.onMarkDone();
    } catch (e) {
      debugPrint('NextStep markDone error: $e');
    } finally {
      if (mounted) setState(() => _justCompleted = false);
    }
  }

  Future<void> _openSnoozeSheet() async {
    final cs = Theme.of(context).colorScheme;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Snooze next step',
                    style: ctx.textStyles.titleMedium?.semiBold),
                SizedBox(height: AppSpacing.sm),
                _SnoozeTile(days: 1, subtitle: 'Until tomorrow'),
                _SnoozeTile(days: 3, subtitle: 'A few days'),
                _SnoozeTile(days: 7, subtitle: 'Next week'),
                SizedBox(height: AppSpacing.sm),
                Text('You can always adjust in your plan later.',
                    style: ctx.textStyles.labelSmall
                        ?.withColor(cs.onSurfaceVariant)),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) {
      try {
        widget.onSnooze(selected);
      } catch (e) {
        debugPrint('NextStep snooze error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final milestone = widget.milestone;
    final dueText = _dueLabel(context, milestone.dueDate);

    final isOverdue = () {
      if (milestone.dueDate == null) return false;
      final now = DateTime.now();
      final d0 = DateTime(now.year, now.month, now.day);
      final d1 = DateTime(milestone.dueDate!.year, milestone.dueDate!.month,
          milestone.dueDate!.day);
      return d1.isBefore(d0);
    }();

    final isToday = () {
      if (milestone.dueDate == null) return false;
      final now = DateTime.now();
      final d0 = DateTime(now.year, now.month, now.day);
      final d1 = DateTime(milestone.dueDate!.year, milestone.dueDate!.month,
          milestone.dueDate!.day);
      return d0 == d1;
    }();

    Color badgeBg;
    Color badgeFg;
    IconData badgeIcon;
    String badgeText;
    if (milestone.dueDate == null) {
      badgeBg = cs.surfaceContainerHigh;
      badgeFg = cs.onSurfaceVariant;
      badgeIcon = Icons.event_busy;
      badgeText = 'No due date';
    } else if (isOverdue) {
      badgeBg = cs.error.withValues(alpha: 0.12);
      badgeFg = cs.error;
      badgeIcon = Icons.warning_amber_rounded;
      // dueText includes the overdue phrasing already
      badgeText = dueText ?? 'Overdue';
    } else if (isToday) {
      badgeBg = cs.primary.withValues(alpha: 0.12);
      badgeFg = cs.primary;
      badgeIcon = Icons.today;
      badgeText = 'Due today';
    } else {
      badgeBg = cs.secondary.withValues(alpha: 0.12);
      badgeFg = cs.secondary;
      badgeIcon = Icons.upcoming;
      badgeText = dueText ?? '';
    }

    return Dismissible(
      key: ValueKey('next-step-' + milestone.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right to complete
          await _handleMarkDone();
          return false; // keep in place; parent reloads the next step
        } else {
          // Swipe left to snooze
          await _openSnoozeSheet();
          return false;
        }
      },
      background: _SwipeBackground(
        icon: Icons.check_circle,
        label: 'Complete',
        color: cs.primary,
        alignLeft: true,
      ),
      secondaryBackground: _SwipeBackground(
        icon: Icons.snooze,
        label: 'Snooze',
        color: cs.secondary,
        alignLeft: false,
      ),
      child: Card(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withValues(alpha: 0.06),
                  cs.tertiary.withValues(alpha: 0.06),
                ],
              ),
            ),
            child: Padding(
              padding: AppSpacing.paddingMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DateBadge(date: milestone.dueDate),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  switchInCurve: Curves.easeOutBack,
                                  switchOutCurve: Curves.easeIn,
                                  child: _justCompleted
                                      ? Icon(Icons.check_circle,
                                          key: const ValueKey('done'),
                                          color: cs.primary)
                                      : Container(
                                          key: const ValueKey('flag'),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: cs.surfaceContainerHigh,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Icon(Icons.flag_outlined,
                                              color: cs.primary, size: 18),
                                        ),
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Next Step',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(badgeIcon, size: 14, color: badgeFg),
                                      SizedBox(width: 6),
                                      Text(badgeText,
                                          style: context.textStyles.labelSmall
                                              ?.withColor(badgeFg)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if ((milestone.conditionId ?? '').isNotEmpty)
                              FutureBuilder(
                                future: ConditionService()
                                    .getConditionById(milestone.conditionId!),
                                builder: (context, snapshot) {
                                  final name = snapshot.data?.name;
                                  if (name == null) return SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Plan • ' + name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.textStyles.labelSmall
                                          ?.withColor(cs.onSurfaceVariant),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    milestone.title,
                    style: context.textStyles.titleMedium?.semiBold,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((milestone.description ?? '').isNotEmpty) ...[
                    SizedBox(height: 6),
                    Text(
                      milestone.description!,
                      style: context.textStyles.bodyMedium
                          ?.withColor(cs.onSurfaceVariant),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: AppSpacing.md),
                  // Make Mark done the dominant hero action; other actions are secondary
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _handleMarkDone,
                          icon: Icon(
                              _justCompleted ? Icons.check : Icons.check_circle,
                              color: cs.onPrimary),
                          label: Text(
                            _justCompleted ? 'Completed' : 'Mark done',
                            style: context.textStyles.labelLarge
                                ?.withColor(cs.onPrimary),
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          TextButton.icon(
                            onPressed: _openLearnMore,
                            icon: const Icon(Icons.school),
                            label: const Text('Learn more'),
                          ),
                          TextButton.icon(
                            onPressed: _openSnoozeSheet,
                            icon: const Icon(Icons.snooze),
                            label: const Text('Snooze'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _dueLabel(BuildContext context, DateTime? due) {
    if (due == null) return null;
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final d1 = DateTime(due.year, due.month, due.day);
    final diff = d1.difference(d0).inDays;
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff < 0)
      return 'Overdue by ${diff.abs()} day${diff.abs() == 1 ? '' : 's'}';
    return 'Due in $diff days';
  }
}

class _SwipeBackground extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool alignLeft;
  const _SwipeBackground(
      {required this.icon,
      required this.label,
      required this.color,
      required this.alignLeft});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Row(
      children: [
        if (alignLeft) ...[
          SizedBox(width: AppSpacing.md),
          Icon(icon, color: color),
          SizedBox(width: 6),
          Text(label, style: context.textStyles.labelLarge?.withColor(color)),
        ] else ...[
          Spacer(),
          Text(label, style: context.textStyles.labelLarge?.withColor(color)),
          SizedBox(width: 6),
          Icon(icon, color: color),
          SizedBox(width: AppSpacing.md),
        ]
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
      ),
      child: content,
    );
  }
}

class _DateBadge extends StatelessWidget {
  final DateTime? date;
  const _DateBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (date == null) {
      return Container(
        width: 42,
        height: 48,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(Icons.event_busy, color: cs.onSurfaceVariant, size: 20),
        ),
      );
    }
    final month = DateFormat('MMM').format(date!);
    final day = DateFormat('d').format(date!);
    return Container(
      width: 42,
      height: 48,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(month.toUpperCase(),
              style: context.textStyles.labelSmall
                  ?.withColor(cs.onSurfaceVariant)),
          Text(day, style: context.textStyles.titleSmall?.semiBold),
        ],
      ),
    );
  }
}

class _SnoozeTile extends StatelessWidget {
  final int days;
  final String subtitle;
  const _SnoozeTile({required this.days, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.snooze, color: cs.onSurfaceVariant),
      title: Text('Snooze $days day${days == 1 ? '' : 's'}'),
      subtitle: Text(subtitle),
      onTap: () => Navigator.of(context).pop(days),
    );
  }
}

class _NoNextStepCard extends StatelessWidget {
  final VoidCallback onOpenPlan;
  final bool isAllCompleted;
  const _NoNextStepCard(
      {required this.onOpenPlan, this.isAllCompleted = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isAllCompleted ? Icons.celebration : Icons.flag_outlined,
                color: cs.onSurfaceVariant),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAllCompleted ? 'Congrats! ' : 'Create goals',
                    style: context.textStyles.titleLarge?.semiBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Build a plan with steps and support',
                    style: context.textStyles.bodyMedium
                        ?.withColor(cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.md),
            TextButton.icon(
              onPressed: onOpenPlan,
              icon: const Icon(Icons.auto_awesome),
              label: Text(isAllCompleted ? 'Review plan' : 'Start here'),
            ),
          ],
        ),
      ),
    );
  }
}


class _MedicationTrackerSection extends StatelessWidget {
  final List<Medication> medications;
  final bool isExpanded;
  final bool isLoading;
  final VoidCallback onToggleExpand;
  final VoidCallback onAddEntry;
  final VoidCallback onEditMedications;
  final Future<void> Function(Medication medication) onQuickLogMedication;
  final Future<void> Function(Medication medication) onAddMedication;

  const _MedicationTrackerSection({
    required this.medications,
    required this.isExpanded,
    required this.isLoading,
    required this.onToggleExpand,
    required this.onAddEntry,
    required this.onEditMedications,
    required this.onQuickLogMedication,
    required this.onAddMedication,
  });

  String _getTimeOfDayLabel(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    
    // Check for preset times
    if (hour == 8 && minute == 0) return 'Morning';
    if (hour == 12 && minute == 0) return 'Noon';
    if (hour == 20 && minute == 0) return 'Night';
    
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  IconData _getTimeIcon(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return Icons.schedule;
    final hour = int.tryParse(parts[0]) ?? 0;
    
    if (hour >= 5 && hour < 12) return Icons.wb_sunny_outlined;
    if (hour >= 12 && hour < 17) return Icons.light_mode_outlined;
    return Icons.nightlight_outlined;
  }

  void _showAddMedicationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AddMedicationDialog(
        onSave: (medication) async {
          await onAddMedication(medication);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'My Medications',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddMedicationDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          if (isLoading)
            Card(
              child: Padding(
                padding: AppSpacing.paddingMd,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            )
          else if (medications.isEmpty)
            Card(
              child: Padding(
                padding: AppSpacing.paddingMd,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.medication_outlined, color: cs.primary),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No medications added',
                            style: context.textStyles.titleSmall?.semiBold,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Add your medications to track them here.',
                            style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () => _showAddMedicationDialog(context),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary.withValues(alpha: 0.04),
                        cs.tertiary.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: onToggleExpand,
                        child: Padding(
                          padding: AppSpacing.paddingSm,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.medication, color: cs.primary, size: 20),
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${medications.length} medication${medications.length == 1 ? '' : 's'}',
                                      style: context.textStyles.titleSmall?.semiBold,
                                    ),
                                    if (!isExpanded)
                                      Text(
                                        medications.map((m) => m.name).join(', '),
                                        style: context.textStyles.labelMedium?.withColor(cs.onSurfaceVariant),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              AnimatedRotation(
                                turns: isExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(Icons.keyboard_arrow_down, color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Column(
                          children: [
                            const Divider(height: 1),
                            ...medications.map((med) => _MedicationTile(
                              medication: med,
                              getTimeLabel: _getTimeOfDayLabel,
                              getTimeIcon: _getTimeIcon,
                              onTap: () => onQuickLogMedication(med),
                            )),
                          ],
                        ),
                        crossFadeState: isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MedicationTile extends StatefulWidget {
  final Medication medication;
  final String Function(String) getTimeLabel;
  final IconData Function(String) getTimeIcon;
  final VoidCallback onTap;

  const _MedicationTile({
    required this.medication,
    required this.getTimeLabel,
    required this.getTimeIcon,
    required this.onTap,
  });

  @override
  State<_MedicationTile> createState() => _MedicationTileState();
}

class _MedicationTileState extends State<_MedicationTile> {
  bool _isLogging = false;

  Future<void> _handleTap() async {
    if (_isLogging) return;
    setState(() => _isLogging = true);
    try {
      widget.onTap();
    } finally {
      if (mounted) {
        // Brief delay for visual feedback
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() => _isLogging = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _isLogging ? cs.primary : cs.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isLogging
                  ? Icon(Icons.check, color: cs.onPrimary, size: 18)
                  : Icon(Icons.medication_liquid, color: cs.secondary, size: 18),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.medication.name,
                          style: context.textStyles.titleSmall?.semiBold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_circle_outline, size: 14, color: cs.primary),
                            SizedBox(width: 4),
                            Text(
                              'Log',
                              style: context.textStyles.labelSmall?.withColor(cs.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.medication.dosage != null && widget.medication.dosage!.isNotEmpty)
                    Text(
                      widget.medication.dosage!,
                      style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                    ),
                  if (widget.medication.times.isNotEmpty) ...[
                    SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: widget.medication.times.map((time) {
                        final label = widget.getTimeLabel(time);
                        final icon = widget.getTimeIcon(time);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 14, color: cs.onSurfaceVariant),
                              SizedBox(width: 4),
                              Text(
                                label,
                                style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for adding a new medication
class AddMedicationDialog extends StatefulWidget {
  const AddMedicationDialog({super.key, required this.onSave});

  final Future<void> Function(Medication medication) onSave;

  @override
  State<AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<AddMedicationDialog> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  List<TimeOfDay> _selectedTimes = [];
  bool _isSaving = false;

  // Quick time presets
  static const _morningTime = TimeOfDay(hour: 8, minute: 0);
  static const _noonTime = TimeOfDay(hour: 12, minute: 0);
  static const _nightTime = TimeOfDay(hour: 20, minute: 0);

  bool get _hasMorning => _selectedTimes.any((t) => t.hour == _morningTime.hour && t.minute == _morningTime.minute);
  bool get _hasNoon => _selectedTimes.any((t) => t.hour == _noonTime.hour && t.minute == _noonTime.minute);
  bool get _hasNight => _selectedTimes.any((t) => t.hour == _nightTime.hour && t.minute == _nightTime.minute);

  void _togglePresetTime(TimeOfDay time) {
    setState(() {
      final exists = _selectedTimes.any((t) => t.hour == time.hour && t.minute == time.minute);
      if (exists) {
        _selectedTimes.removeWhere((t) => t.hour == time.hour && t.minute == time.minute);
      } else {
        _selectedTimes.add(time);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null && !_selectedTimes.any((t) => t.hour == time.hour && t.minute == time.minute)) {
      setState(() => _selectedTimes.add(time));
    }
  }

  void _removeTime(TimeOfDay time) {
    setState(() => _selectedTimes.remove(time));
  }

  Future<void> _saveMedication() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a medication name')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final times = _selectedTimes
        .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
        .toList()
      ..sort();

    final medication = Medication(
      id: const Uuid().v4(),
      name: name,
      dosage: _dosageController.text.trim().isEmpty ? null : _dosageController.text.trim(),
      times: times,
    );

    try {
      await widget.onSave(medication);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name added to your medications')),
        );
      }
    } catch (e) {
      debugPrint('AddMedicationDialog error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save medication')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.medication_outlined, color: cs.primary, size: 20),
          ),
          SizedBox(width: AppSpacing.sm),
          const Text('Add Medication'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Medication name',
                prefixIcon: Icon(Icons.medication_outlined, color: cs.onSurfaceVariant),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: AppSpacing.md),
            TextField(
              controller: _dosageController,
              decoration: InputDecoration(
                hintText: 'Dosage (optional, e.g., 50mg)',
                prefixIcon: Icon(Icons.science_outlined, color: cs.onSurfaceVariant),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'When do you take it?',
              style: context.textStyles.titleSmall,
            ),
            SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _TimePresetChipSimple(
                  label: 'Morning',
                  subtitle: '8:00 AM',
                  icon: Icons.wb_sunny_outlined,
                  isSelected: _hasMorning,
                  onTap: () => _togglePresetTime(_morningTime),
                ),
                _TimePresetChipSimple(
                  label: 'Noon',
                  subtitle: '12:00 PM',
                  icon: Icons.wb_twilight_outlined,
                  isSelected: _hasNoon,
                  onTap: () => _togglePresetTime(_noonTime),
                ),
                _TimePresetChipSimple(
                  label: 'Night',
                  subtitle: '8:00 PM',
                  icon: Icons.nights_stay_outlined,
                  isSelected: _hasNight,
                  onTap: () => _togglePresetTime(_nightTime),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            // Custom times
            Row(
              children: [
                Text('Custom times:', style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ..._selectedTimes
                          .where((t) =>
                              !(t.hour == _morningTime.hour && t.minute == _morningTime.minute) &&
                              !(t.hour == _noonTime.hour && t.minute == _noonTime.minute) &&
                              !(t.hour == _nightTime.hour && t.minute == _nightTime.minute))
                          .map((time) => Chip(
                                label: Text(_formatTime(time)),
                                labelStyle: context.textStyles.labelMedium,
                                backgroundColor: cs.primaryContainer,
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () => _removeTime(time),
                                visualDensity: VisualDensity.compact,
                              )),
                      ActionChip(
                        label: const Icon(Icons.add, size: 18),
                        onPressed: _pickTime,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveMedication,
          child: _isSaving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _TimePresetChipSimple extends StatelessWidget {
  const _TimePresetChipSimple({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
            SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.textStyles.labelMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
                ),
              ],
            ),
            if (isSelected) ...[
              SizedBox(width: AppSpacing.sm),
              Icon(Icons.check_circle, size: 16, color: cs.primary),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailedMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final List<double> series;
  final double delta;
  final bool betterWhenHigher;
  final double minY;
  final double maxY;

  const _DetailedMetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.series,
    required this.delta,
    required this.betterWhenHigher,
    required this.minY,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const double epsilon = 0.05;
    double? lastChange;
    if (series.length >= 2) {
      lastChange = series.last - series[series.length - 2];
    } else if (delta != 0) {
      lastChange = delta;
    }
    final bool isNeutral = lastChange == null || lastChange.abs() < epsilon;
    final bool trendUp = (lastChange ?? 0) > 0;
    final bool isImprovement = betterWhenHigher ? trendUp : !trendUp;
    final IconData arrow = isNeutral
        ? Icons.horizontal_rule
        : (isImprovement ? Icons.arrow_upward : Icons.arrow_downward);
    final Color deltaColor = isNeutral
        ? cs.onSurfaceVariant
        : (isImprovement ? cs.primary : cs.error);

    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textStyles.labelLarge?.withColor(cs.onSurfaceVariant),
                    ),
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          value,
                          style: context.textStyles.headlineMedium?.semiBold,
                        ),
                        SizedBox(width: 4),
                        Text(
                          unit,
                          style: context.textStyles.bodyLarge?.withColor(cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: deltaColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(arrow, size: 16, color: deltaColor),
                    if (delta.abs() >= epsilon) ...[
                      SizedBox(width: 4),
                      Text(
                        delta.abs().toStringAsFixed(1),
                        style: context.textStyles.labelMedium?.semiBold.withColor(deltaColor),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 120,
            child: series.isEmpty
                ? Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'No data available',
                        style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LineChart(
                      LineChartData(
                        clipData: const FlClipData.all(),
                        minY: minY,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: (maxY - minY) / 4,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: cs.outline.withValues(alpha: 0.1),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: (maxY - minY) / 4,
                              getTitlesWidget: (value, meta) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  value.toStringAsFixed(0),
                                  style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= series.length) return const SizedBox.shrink();
                                // Show day labels (e.g., Day 1, 2, 3...)
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${value.toInt() + 1}',
                                    style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            preventCurveOverShooting: true,
                            barWidth: 3,
                            color: color,
                            isStrokeCapRound: true,
                            spots: series
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value))
                                .toList(),
                            belowBarData: BarAreaData(
                              show: true,
                              color: color.withValues(alpha: 0.15),
                            ),
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                radius: 3,
                                color: color,
                                strokeWidth: 2,
                                strokeColor: cs.surface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
