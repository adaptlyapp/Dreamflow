import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/diet_plan.dart';
import 'package:wellspring/models/family_nutrition.dart';
import 'package:wellspring/models/nutrition.dart';
import 'package:wellspring/models/nutrition_hub.dart';
import 'package:wellspring/openai/openai_config.dart';
import 'package:wellspring/screens/tracker/nutrition/nutrition_hub_section.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/services/food_database_service.dart';
import 'package:wellspring/services/nutrition_service.dart';
import 'package:wellspring/services/tracker_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/theme.dart';

class NutritionTab extends StatefulWidget {
  const NutritionTab({super.key});

  @override
  State<NutritionTab> createState() => _NutritionTabState();
}

class _NutritionTabState extends State<NutritionTab> with AutomaticKeepAliveClientMixin {
  final _nutrition = NutritionService();
  final _tracker = TrackerService();
  final _ai = OpenAIClient();
  final _conditionService = ConditionService();

  UserProvider? _userProvider;

  bool _loading = true;
  bool _loadingWeek = true;
  bool _loadingRecent = true;
  bool _generating = false;
  DateTime _day = DateTime.now();

  NutritionDayLog? _log;
  DietPlanResult? _savedPlan;
  List<_WeekPoint> _week = const [];
  List<NutritionDayLog> _recentDays = const [];
  List<String> _resolvedConditionNames = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache Provider lookups so async methods don’t try to access inherited
    // widgets after this tab is disposed/deactivated.
    _userProvider ??= context.read<UserProvider>();
  }

  @override
  bool get wantKeepAlive => true;

  DateTime get _normalizedDay => DateTime(_day.year, _day.month, _day.day);

  Future<void> _reload() async {
    final userProvider = _userProvider;
    setState(() {
      _loading = true;
      _loadingWeek = true;
      _loadingRecent = true;
    });

    // Ensure profile is present (mirrors TrackerScreen behavior)
    try {
      await (userProvider ?? context.read<UserProvider>()).loadUser();
    } catch (e) {
      debugPrint('NutritionTab: loadUser failed (non-fatal): $e');
    }

    if (!mounted) return;
    final userId = (userProvider ?? context.read<UserProvider>()).currentUser?.id;
    if (userId == null) {
      setState(() {
        _loading = false;
        _loadingWeek = false;
      });
      return;
    }

    try {
      final log = await _nutrition.getDay(userId, _normalizedDay);
      final plan = await _nutrition.getSavedDietPlan();
      final recent = await _nutrition.getRecentNutritionDays(userId);
      if (!mounted) return;
      // Resolve user condition IDs -> human-readable names (best-effort).
      final user = (userProvider ?? context.read<UserProvider>()).currentUser;
      final resolved = <String>[];
      if (user != null) {
        for (final id in user.conditions) {
          try {
            final c = await _conditionService.getConditionById(id);
            resolved.add((c?.name.trim().isNotEmpty ?? false) ? c!.name.trim() : id);
          } catch (_) {
            resolved.add(id);
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _log = log;
        _savedPlan = plan;
        _recentDays = recent;
        _resolvedConditionNames = resolved;
        _loading = false;
        _loadingRecent = false;
      });
    } catch (e) {
      debugPrint('NutritionTab._reload error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingRecent = false;
      });
    }

    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final entries = await _tracker.getEntriesByDateRange(userId, start, end);

      final points = <_WeekPoint>[];
      for (int i = 0; i < 7; i++) {
        final d = start.add(Duration(days: i));
        final entry = entries.where((e) => _isSameDay(e.date, d)).toList();
        NutritionDayLog? log;
        for (final e in entry) {
          final raw = (e.customFields ?? const {})[NutritionDayLog.customFieldKey];
          if (raw is Map<String, dynamic>) {
            log = NutritionDayLog.fromJson(raw);
            break;
          }
          if (raw is Map) {
            log = NutritionDayLog.fromJson(raw.cast<String, dynamic>());
            break;
          }
        }
        final calories = log?.totalMacros.calories ?? 0;
        final protein = log?.totalMacros.proteinG ?? 0;
        points.add(_WeekPoint(day: d, calories: calories, proteinG: protein));
      }
      if (!mounted) return;
      setState(() {
        _week = points;
        _loadingWeek = false;
      });
    } catch (e) {
      debugPrint('NutritionTab._reload week error: $e');
      if (mounted) setState(() => _loadingWeek = false);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _jumpToDay(DateTime day) async {
    setState(() {
      _day = DateTime(day.year, day.month, day.day);
      _loading = true;
    });
    await _reload();
  }

  Future<void> _quickAddWater(int ml) async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;
    try {
      await _nutrition.addWater(userId, _normalizedDay, ml);
      await _reload();
    } catch (e) {
      debugPrint('NutritionTab._quickAddWater error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update hydration')));
    }
  }

  Future<void> _logHubFood(FoodEntry food, MealType type) async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;
    final day = _normalizedDay;
    try {
      final current = _log?.meals[type] ?? MealLog.empty(type);
      final now = DateTime.now();
      final newItem = FoodItemLog(
        name: food.name,
        macros: NutritionMacros(
          calories: food.caloriesPerServing,
          proteinG: food.proteinG,
          carbsG: food.carbsG,
          fatsG: food.fatG,
          fiberG: food.fiberG,
          sugarG: 0,
          sodiumMg: 0,
        ),
        notes: 'From Nutrition Hub • ${food.servingLabel}',
        createdAt: now,
        updatedAt: now,
      );
      final updated = current.copyWith(
        items: [...current.items, newItem],
        completed: true,
        updatedAt: now,
      );
      await _nutrition.upsertMeal(userId, day, updated);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Added ${food.name} to ${type.label}'),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      debugPrint('NutritionTab._logHubFood error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not log this food')));
    }
  }

  Future<void> _openMealSheet(MealType type) async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;
    final day = _normalizedDay;
    final current = _log?.meals[type] ?? MealLog.empty(type);

    final result = await showModalBottomSheet<MealLog>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MealEditorSheet(userId: userId, initial: current),
    );

    if (result == null) return;
    try {
      await _nutrition.upsertMeal(userId, day, result);
      await _reload();
    } catch (e) {
      debugPrint('NutritionTab._openMealSheet save error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save meal')));
    }
  }

  Future<void> _openDayViewer(NutritionDayLog day) async {
    try {
      debugPrint('NutritionTab: open day viewer for ${day.date.toIso8601String()}');
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _NutritionDayViewSheet(day: day),
      );
    } catch (e) {
      debugPrint('NutritionTab: failed to open day viewer: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open this entry')));
    }
  }

  Future<void> _generatePlan() async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;

    // Resolve condition IDs -> human-friendly names for the AI context.
    // (If a condition can't be resolved, keep the raw ID so we don't lose context.)
    final conditionIds = user.conditions;
    final resolvedConditions = <String>[];
    try {
      for (final id in conditionIds) {
        final c = await _conditionService.getConditionById(id);
        resolvedConditions.add((c?.name.trim().isNotEmpty ?? false) ? c!.name.trim() : id);
      }
    } catch (e) {
      debugPrint('NutritionTab: failed to resolve conditions for AI prompt: $e');
      resolvedConditions
        ..clear()
        ..addAll(conditionIds);
    }

    final input = await showModalBottomSheet<DietPlanInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DietPlanGeneratorSheet(currentConditions: resolvedConditions),
    );
    if (input == null) return;

    try {
      if (!mounted) return;
      setState(() => _generating = true);

      final json = await _ai.generateDietPlan(
        input: {
          ...input.toJson(),
          if (resolvedConditions.isNotEmpty) 'currentConditions': resolvedConditions,
        },
      );
      final plan = DietPlanResult.fromJson({...json, 'createdAt': DateTime.now().toIso8601String(), 'updatedAt': DateTime.now().toIso8601String()});
      await _nutrition.saveDietPlan(plan);
      if (!mounted) return;
      setState(() {
        _savedPlan = plan;
        _generating = false;
      });
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DietPlanPreviewSheet(
          plan: plan,
          onCopyDayToToday: (dayIndex) async {
            final today = DateTime.now();
            await _copyPlanDayToToday(dayIndex: dayIndex, today: today);
          },
        ),
      );
      await _reload();
    } catch (e) {
      debugPrint('NutritionTab._generatePlan error: $e');
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Diet plan generation failed: ${e.toString()}')));
    }
  }

  Future<void> _copyPlanDayToToday({required int dayIndex, required DateTime today}) async {
    final userId = context.read<UserProvider>().currentUser?.id;
    final plan = _savedPlan;
    if (userId == null || plan == null) return;
    if (dayIndex < 0 || dayIndex >= plan.days.length) return;

    try {
      final day = plan.days[dayIndex];
      final todayLog = await _nutrition.getDay(userId, today);

      MealLog build(MealType type, String keyFallback) {
        final key = switch (type) {
          MealType.breakfast => 'breakfast',
          MealType.lunch => 'lunch',
          MealType.dinner => 'dinner',
          MealType.snack => 'snack',
        };
        final m = day.meals[key] ?? day.meals[keyFallback];
        if (m == null) return MealLog.empty(type);
        final now = DateTime.now();
        return MealLog(
          type: type,
          items: [
            FoodItemLog(
              name: m.title,
              macros: const NutritionMacros.zero(),
              notes: m.description,
              createdAt: now,
              updatedAt: now,
            )
          ],
          notes: m.approxMacros,
          symptomTags: const [],
          completed: false,
          createdAt: now,
          updatedAt: now,
        );
      }

      final updatedMeals = {...todayLog.meals};
      updatedMeals[MealType.breakfast] = build(MealType.breakfast, 'Breakfast');
      updatedMeals[MealType.lunch] = build(MealType.lunch, 'Lunch');
      updatedMeals[MealType.dinner] = build(MealType.dinner, 'Dinner');
      if (todayLog.meals.containsKey(MealType.snack)) {
        updatedMeals[MealType.snack] = build(MealType.snack, 'Snack');
      }
      await _nutrition.saveDay(userId, todayLog.copyWith(meals: updatedMeals, updatedAt: DateTime.now()));
    } catch (e) {
      debugPrint('NutritionTab._copyPlanDayToToday error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not copy meals to today')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final log = _log;
    if (log == null) {
      return Padding(
        padding: AppSpacing.paddingLg,
        child: Text('Sign in to track nutrition.', style: text.bodyMedium?.withColor(cs.onSurfaceVariant)),
      );
    }

    final total = log.totalMacros;
    final waterProgress = log.waterGoalMl <= 0 ? 0.0 : (log.waterMl / log.waterGoalMl).clamp(0.0, 1.0);
    final mealsDone = log.completedMealsCount;

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
        children: [
          _DashboardHeaderRow(
            title: 'Nutrition',
            subtitle: 'Log meals, hydration, and progress',
            primaryButtonLabel: _generating ? 'Generating…' : 'Generate Diet Plan',
            primaryButtonIcon: Icons.auto_awesome,
            primaryButtonBusy: _generating,
            onPrimaryPressed: _generating ? null : _generatePlan,
          ),
          SizedBox(height: AppSpacing.lg),
          _NutritionStatsGrid(
            calories: total.calories,
            proteinG: total.proteinG,
            waterProgress: waterProgress,
            mealsCompleted: mealsDone,
            mealsTotal: log.totalMealsCount,
          ),
          SizedBox(height: AppSpacing.md),
          _HydrationCard(
            waterMl: log.waterMl,
            goalMl: log.waterGoalMl,
            onAdd250: () => _quickAddWater(250),
            onAdd500: () => _quickAddWater(500),
            onAdd1000: () => _quickAddWater(1000),
          ),
          SizedBox(height: AppSpacing.lg),
          _RecentNutritionSection(
            loading: _loadingRecent,
            selectedDay: _normalizedDay,
            days: _recentDays,
            onSelectDay: _jumpToDay,
            onViewDay: _openDayViewer,
            onViewAll: () async {
              final userId = (_userProvider ?? context.read<UserProvider>()).currentUser?.id;
              if (userId == null) return;
              try {
                final allDays = await _nutrition.getRecentNutritionDays(userId, maxDays: 60, entryLimit: 300);
                if (!mounted) return;
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  backgroundColor: Colors.transparent,
                  builder: (sheetContext) => Container(
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                    ),
                    child: _NutritionRecentDaysSheet(
                      selectedDay: _normalizedDay,
                      days: allDays,
                      onSelectDay: _jumpToDay,
                      onViewDay: _openDayViewer,
                    ),
                  ),
                );
              } catch (e) {
                debugPrint('NutritionTab.onViewAll error: $e');
              }
            },
          ),
          SizedBox(height: AppSpacing.lg),
          NutritionHubCard(
            conditions: _resolvedConditionNames,
            onLogFood: _logHubFood,
          ),
          SizedBox(height: AppSpacing.lg),
          Text('Meals', style: text.titleMedium?.semiBold),
          SizedBox(height: AppSpacing.sm),
          for (final t in MealType.values) ...[
            _MealCard(
              type: t,
              meal: log.meals[t] ?? MealLog.empty(t),
              onTap: () => _openMealSheet(t),
            ),
            SizedBox(height: AppSpacing.sm),
          ],
          SizedBox(height: AppSpacing.lg),
          _PlanCard(
            plan: _savedPlan,
            onView: _savedPlan == null
                ? null
                : () async {
                    final p = _savedPlan;
                    if (p == null) return;
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _DietPlanPreviewSheet(
                        plan: p,
                        onCopyDayToToday: (dayIndex) async {
                          await _copyPlanDayToToday(dayIndex: dayIndex, today: DateTime.now());
                        },
                      ),
                    );
                  },
            onClear: _savedPlan == null
                ? null
                : () async {
                    await _nutrition.clearDietPlan();
                    await _reload();
                  },
          ),
          SizedBox(height: AppSpacing.lg),
          Text('Weekly trends', style: text.titleMedium?.semiBold),
          SizedBox(height: AppSpacing.sm),
          _loadingWeek ? const _WeekSkeleton() : _WeeklyTrendsCard(points: _week),
        ],
      ),
    );
  }
}

class _WeekPoint {
  final DateTime day;
  final int calories;
  final double proteinG;
  const _WeekPoint({required this.day, required this.calories, required this.proteinG});
}

class _WeekSkeleton extends StatelessWidget {
  const _WeekSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    );
  }
}

class _RecentNutritionSection extends StatelessWidget {
  final bool loading;
  final DateTime selectedDay;
  final List<NutritionDayLog> days;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<NutritionDayLog> onViewDay;
  final VoidCallback onViewAll;

  const _RecentNutritionSection({
    required this.loading,
    required this.selectedDay,
    required this.days,
    required this.onSelectDay,
    required this.onViewDay,
    required this.onViewAll,
  });

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _friendlyDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    return DateFormat('MMM d').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Recent entries', style: text.titleMedium?.semiBold)),
            Text(_friendlyDayLabel(selectedDay), style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
            SizedBox(width: AppSpacing.sm),
            TextButton.icon(
              onPressed: onViewAll,
              icon: Icon(Icons.view_list, size: 16, color: cs.onSurfaceVariant),
              label: Text('View all', style: text.labelSmall?.semiBold.withColor(cs.onSurfaceVariant)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        if (loading)
          Container(
            height: 124,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          )
        else if (days.isEmpty)
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: cs.outline.withValues(alpha: 0.12), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.restaurant_outlined, color: cs.onSurfaceVariant),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('No nutrition entries yet. Start by logging a meal.', style: text.bodyMedium?.withColor(cs.onSurfaceVariant))),
              ],
            ),
          )
        else
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: days.length,
              separatorBuilder: (_, __) => SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final d = days[index];
                final selected = _isSameDay(d.date, selectedDay);
                return _RecentNutritionDayCard(
                  label: _friendlyDayLabel(d.date),
                  calories: d.totalMacros.calories,
                  proteinG: d.totalMacros.proteinG,
                  mealsDone: d.completedMealsCount,
                  mealsTotal: d.totalMealsCount,
                  selected: selected,
                  // Tapping a recent day should be *viewable* (snapshot) as per user expectation.
                  // Selecting the day for editing is still available via long-press.
                  onTap: () {
                    debugPrint('NutritionTab: tapped recent day card ${d.date.toIso8601String()}');
                    onViewDay(d);
                  },
                  onLongPress: () {
                    debugPrint('NutritionTab: long-pressed recent day card ${d.date.toIso8601String()}');
                    onSelectDay(d.date);
                  },
                  onView: () {
                    debugPrint('NutritionTab: pressed view icon for ${d.date.toIso8601String()}');
                    onViewDay(d);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RecentNutritionDayCard extends StatelessWidget {
  final String label;
  final int calories;
  final double proteinG;
  final int mealsDone;
  final int mealsTotal;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onView;

  const _RecentNutritionDayCard({
    required this.label,
    required this.calories,
    required this.proteinG,
    required this.mealsDone,
    required this.mealsTotal,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;

    final bg = selected ? cs.primaryContainer.withValues(alpha: 0.55) : cs.surfaceContainerHighest.withValues(alpha: 0.55);
    final border = selected ? cs.primary.withValues(alpha: 0.35) : cs.outline.withValues(alpha: 0.12);
    final titleColor = selected ? cs.onPrimaryContainer : cs.onSurface;
    final metaColor = selected ? cs.onPrimaryContainer.withValues(alpha: 0.85) : cs.onSurfaceVariant;

    // We wrap the painted background in a Material so InkWell can reliably
    // participate in gesture arenas + show proper hover/focus feedback.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          width: 170,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label, style: text.titleSmall?.semiBold.withColor(titleColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(
                    onPressed: onView,
                    tooltip: 'View day',
                    icon: Icon(Icons.visibility_outlined, size: 18, color: metaColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${calories} kcal', style: text.bodyMedium?.semiBold.withColor(titleColor), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${proteinG.toStringAsFixed(0)}g protein', style: text.labelSmall?.withColor(metaColor)),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: metaColor),
                  SizedBox(width: 6),
                  Expanded(child: Text('$mealsDone/$mealsTotal meals', style: text.labelSmall?.withColor(metaColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutritionRecentDaysSheet extends StatelessWidget {
  final DateTime selectedDay;
  final List<NutritionDayLog> days;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<NutritionDayLog> onViewDay;

  const _NutritionRecentDaysSheet({
    required this.selectedDay,
    required this.days,
    required this.onSelectDay,
    required this.onViewDay,
  });

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _friendlyDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    return DateFormat('EEE, MMM d').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final canJumpToToday = !_isSameDay(selectedDay, normalizedToday);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppSpacing.paddingLg.copyWith(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(child: Text('All nutrition days', style: text.titleLarge?.semiBold)),
                  if (canJumpToToday) ...[
                    TextButton(
                      onPressed: () {
                        context.pop();
                        onSelectDay(normalizedToday);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: cs.primary,
                      ),
                      child: Text('Today', style: text.labelLarge?.semiBold),
                    ),
                    SizedBox(width: 6),
                  ],
                  IconButton(
                    onPressed: context.pop,
                    tooltip: 'Close',
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                padding: AppSpacing.paddingLg.copyWith(top: 0),
                itemCount: days.length,
                separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final d = days[index];
                  final selected = _isSameDay(d.date, selectedDay);
                  return InkWell(
                    onTap: () {
                      context.pop();
                      onSelectDay(d.date);
                    },
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Container(
                      padding: AppSpacing.paddingMd,
                      decoration: BoxDecoration(
                        color: selected ? cs.primaryContainer.withValues(alpha: 0.35) : cs.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: selected ? cs.primary.withValues(alpha: 0.25) : cs.outline.withValues(alpha: 0.12), width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_friendlyDayLabel(d.date), style: text.titleSmall?.semiBold),
                                SizedBox(height: 4),
                                Text(
                                  '${d.totalMacros.calories} kcal • ${d.totalMacros.proteinG.toStringAsFixed(0)}g protein • ${d.completedMealsCount}/${d.totalMealsCount} meals',
                                  style: text.bodySmall?.withColor(cs.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => onViewDay(d),
                            tooltip: 'View day',
                            icon: Icon(Icons.visibility_outlined, size: 18, color: cs.onSurfaceVariant),
                          ),
                          Icon(selected ? Icons.check_circle : Icons.chevron_right, size: 18, color: selected ? cs.primary : cs.onSurfaceVariant),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _NutritionDayViewSheet extends StatelessWidget {
  final NutritionDayLog day;
  const _NutritionDayViewSheet({required this.day});

  String _friendlyDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    return DateFormat('EEE, MMM d').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final total = day.totalMacros;

    Future<void> openFood(FoodItemLog item) async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _FoodItemViewSheet(item: item),
      );
    }

    Widget metric({required String label, required String value, required IconData icon}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35))),
            child: Icon(icon, size: 18, color: cs.primary),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
                SizedBox(height: 2),
                Text(value, style: text.bodyMedium?.semiBold),
              ],
            ),
          ),
        ],
      ),
    );

    Widget mealCard(MealType type, MealLog meal) {
      final hasItems = meal.items.isNotEmpty;
      return Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(type.label, style: text.titleSmall?.semiBold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: meal.completed ? cs.primary.withValues(alpha: 0.12) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(meal.completed ? Icons.check_circle : Icons.circle_outlined, size: 16, color: meal.completed ? cs.primary : cs.onSurfaceVariant),
                      SizedBox(width: 6),
                      Text(meal.completed ? 'Completed' : 'Not completed', style: text.labelSmall?.semiBold.withColor(meal.completed ? cs.primary : cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              hasItems ? '${meal.totalMacros.calories} kcal • ${meal.totalMacros.proteinG.toStringAsFixed(0)}g protein' : 'No foods logged',
              style: text.bodySmall?.withColor(cs.onSurfaceVariant),
            ),
            if ((meal.notes ?? '').trim().isNotEmpty) ...[
              SizedBox(height: AppSpacing.sm),
              Text(meal.notes!.trim(), style: text.bodySmall?.withColor(cs.onSurfaceVariant)),
            ],
            if (meal.symptomTags.isNotEmpty) ...[
              SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: meal.symptomTags.map((t) => _TagPill(label: t)).toList(growable: false),
              ),
            ],
            if (meal.items.isNotEmpty) ...[
              SizedBox(height: AppSpacing.md),
              for (final item in meal.items) ...[
                _FoodRowViewOnly(item: item, onView: () => openFood(item)),
                SizedBox(height: AppSpacing.xs),
              ],
            ]
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_friendlyDayLabel(day.date), style: text.titleLarge?.semiBold)),
                    IconButton(
                      onPressed: context.pop,
                      tooltip: 'Close',
                      icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                Text('Daily log snapshot', style: text.bodyMedium?.withColor(cs.onSurfaceVariant)),
                SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(child: metric(label: 'Calories', value: '${total.calories} kcal', icon: Icons.local_fire_department_outlined)),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: metric(label: 'Protein', value: '${total.proteinG.toStringAsFixed(0)} g', icon: Icons.fitness_center_outlined)),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: metric(label: 'Hydration', value: '${(day.waterMl / 1000).toStringAsFixed(1)}L', icon: Icons.water_drop_outlined)),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: metric(label: 'Meals', value: '${day.completedMealsCount}/${day.totalMealsCount}', icon: Icons.task_alt)),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),
                Text('Meals', style: text.titleSmall?.semiBold),
                SizedBox(height: AppSpacing.sm),
                for (final t in MealType.values) ...[
                  mealCard(t, day.meals[t] ?? MealLog.empty(t)),
                  SizedBox(height: AppSpacing.sm),
                ],
                SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: context.pop,
                  icon: Icon(Icons.done, color: cs.onPrimary),
                  label: Text('Done', style: text.labelLarge?.semiBold.withColor(cs.onPrimary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FoodRowViewOnly extends StatelessWidget {
  final FoodItemLog item;
  final VoidCallback onView;
  const _FoodRowViewOnly({required this.item, required this.onView});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final m = item.macros;

    return InkWell(
      onTap: onView,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: text.bodyMedium?.semiBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2),
                  Text(
                    '${m.calories} kcal • ${m.proteinG.toStringAsFixed(0)}P ${m.carbsG.toStringAsFixed(0)}C ${m.fatsG.toStringAsFixed(0)}F',
                    style: text.labelSmall?.withColor(cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeaderRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String primaryButtonLabel;
  final IconData primaryButtonIcon;
  final bool primaryButtonBusy;
  final VoidCallback? onPrimaryPressed;

  const _DashboardHeaderRow({
    required this.title,
    required this.subtitle,
    required this.primaryButtonLabel,
    required this.primaryButtonIcon,
    required this.primaryButtonBusy,
    required this.onPrimaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleLarge?.semiBold),
              SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: text.bodyMedium?.withColor(cs.onSurfaceVariant)),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onPrimaryPressed,
          icon: primaryButtonBusy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: cs.onPrimary),
                )
              : Icon(primaryButtonIcon, color: cs.onPrimary),
          label: Text(primaryButtonLabel, style: text.labelLarge?.semiBold.withColor(cs.onPrimary)),
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
          ),
        ),
      ],
    );
  }
}

class _NutritionStatsGrid extends StatelessWidget {
  final int calories;
  final double proteinG;
  final double waterProgress;
  final int mealsCompleted;
  final int mealsTotal;

  const _NutritionStatsGrid({
    required this.calories,
    required this.proteinG,
    required this.waterProgress,
    required this.mealsCompleted,
    required this.mealsTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniMetricCard(
            icon: Icons.local_fire_department_outlined,
            title: 'Calories',
            value: calories == 0 ? '—' : calories.toString(),
            subtitle: 'today',
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MiniMetricCard(
            icon: Icons.fitness_center_outlined,
            title: 'Protein',
            value: proteinG == 0 ? '—' : '${proteinG.toStringAsFixed(0)}g',
            subtitle: 'today',
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MiniMetricCard(
            icon: Icons.water_drop_outlined,
            title: 'Hydration',
            value: '${(waterProgress * 100).round()}%',
            subtitle: 'goal',
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MiniMetricCard(
            icon: Icons.task_alt,
            title: 'Meals',
            value: '$mealsCompleted/$mealsTotal',
            subtitle: 'done',
          ),
        ),
      ],
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _MiniMetricCard({required this.icon, required this.title, required this.value, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary),
          SizedBox(height: AppSpacing.sm),
          Text(value, style: text.titleMedium?.semiBold),
          SizedBox(height: 2),
          Text('$title • $subtitle', style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _HydrationCard extends StatelessWidget {
  final int waterMl;
  final int goalMl;
  final VoidCallback onAdd250;
  final VoidCallback onAdd500;
  final VoidCallback onAdd1000;

  const _HydrationCard({
    required this.waterMl,
    required this.goalMl,
    required this.onAdd250,
    required this.onAdd500,
    required this.onAdd1000,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final pct = goalMl <= 0 ? 0.0 : (waterMl / goalMl).clamp(0.0, 1.0);

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 7,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: cs.primary,
                ),
                Text('${(pct * 100).round()}%', style: text.labelMedium?.semiBold),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hydration', style: text.titleSmall?.semiBold),
                SizedBox(height: 2),
                Text('${(waterMl / 1000).toStringAsFixed(1)}L of ${(goalMl / 1000).toStringAsFixed(1)}L',
                    style: text.bodySmall?.withColor(cs.onSurfaceVariant)),
                SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _QuickAddChip(label: '+250ml', onTap: onAdd250),
                    _QuickAddChip(label: '+500ml', onTap: onAdd500),
                    _QuickAddChip(label: '+1L', onTap: onAdd1000),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickAddChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
        ),
        child: Text(label, style: text.labelMedium?.semiBold.withColor(cs.onPrimaryContainer)),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final MealType type;
  final MealLog meal;
  final VoidCallback onTap;

  const _MealCard({
    required this.type,
    required this.meal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final macros = meal.totalMacros;
    final hasItems = meal.items.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_iconFor(type), color: cs.primary),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.label, style: text.titleSmall?.semiBold),
                  SizedBox(height: 2),
                  Text(
                    hasItems
                        ? '${macros.calories} kcal • ${macros.proteinG.toStringAsFixed(0)}g protein'
                        : 'Tap to add food',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.withColor(cs.onSurfaceVariant),
                  ),
                  if (meal.symptomTags.isNotEmpty) ...[
                    SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: meal.symptomTags
                          .take(3)
                          .map((s) => _TagPill(label: s))
                          .toList(growable: false),
                    )
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(MealType t) => switch (t) {
        MealType.breakfast => Icons.wb_sunny_outlined,
        MealType.lunch => Icons.lunch_dining_outlined,
        MealType.dinner => Icons.dinner_dining_outlined,
        MealType.snack => Icons.cookie_outlined,
      };
}

class _TagPill extends StatelessWidget {
  final String label;
  const _TagPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: text.labelSmall?.withColor(cs.onSecondaryContainer)),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final DietPlanResult? plan;
  final VoidCallback? onView;
  final VoidCallback? onClear;
  const _PlanCard({required this.plan, required this.onView, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.calendar_month_outlined, color: cs.primary),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Diet Plan', style: text.titleSmall?.semiBold),
                SizedBox(height: 2),
                Text(
                  plan == null ? 'Generate a 7-day plan when you’re ready.' : (plan!.title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.withColor(cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (plan != null) ...[
            OutlinedButton(
              onPressed: onView,
              child: Text('View', style: text.labelLarge?.withColor(cs.primary)),
            ),
            SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: onClear,
              icon: Icon(Icons.delete_outline, color: cs.onSurfaceVariant),
              tooltip: 'Clear plan',
            )
          ] else
            OutlinedButton.icon(
              onPressed: onView,
              icon: Icon(Icons.auto_awesome, color: cs.primary),
              label: Text('Generate', style: text.labelLarge?.withColor(cs.primary)),
            )
        ],
      ),
    );
  }
}

class _WeeklyTrendsCard extends StatelessWidget {
  final List<_WeekPoint> points;
  const _WeeklyTrendsCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final maxCal = points.isEmpty ? 1 : math.max(1, points.map((p) => p.calories).fold<int>(0, math.max));

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Calories (7 days)', style: text.titleSmall?.semiBold)),
              Text('Protein shown as dots', style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= points.length) return const SizedBox.shrink();
                        const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        final label = labels.length == points.length ? labels[i] : '${i + 1}';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(label, style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(enabled: false),
                maxY: maxCal.toDouble() * 1.15,
                barGroups: [
                  for (int i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].calories.toDouble(),
                          width: 14,
                          borderRadius: BorderRadius.circular(6),
                          color: cs.primary.withValues(alpha: 0.85),
                          backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxCal.toDouble(), color: cs.surfaceContainerHighest),
                        )
                      ],
                      showingTooltipIndicators: const [],
                    )
                ],
              ),
              swapAnimationDuration: const Duration(milliseconds: 420),
              swapAnimationCurve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealEditorSheet extends StatefulWidget {
  final String userId;
  final MealLog initial;
  const _MealEditorSheet({required this.userId, required this.initial});

  @override
  State<_MealEditorSheet> createState() => _MealEditorSheetState();
}

class _MealEditorSheetState extends State<_MealEditorSheet> {
  final _nutrition = NutritionService();
  final _foodDb = FoodDatabaseService();
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _notes = TextEditingController();
  final _symptoms = TextEditingController();
  final _cal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fats = TextEditingController();
  final _fiber = TextEditingController();
  final _sugar = TextEditingController();
  final _sodium = TextEditingController();

  List<FoodItemLog> _recentFoods = const [];
  List<FoodItemLog> _filteredFoods = const [];
  bool _loadingFoods = true;

  List<FoodDatabaseEntry> _dbFoods = const [];
  bool _loadingDb = true;

  List<_RemoteFoodSuggestion> _remoteFoods = const [];
  bool _loadingRemote = false;
  bool _loadingRemoteMore = false;
  bool _remoteHasMore = false;
  String _remoteQuery = '';
  int _remotePage = 1;
  Timer? _remoteDebounce;
  int _remoteQueryToken = 0;
  DateTime _lastQueryAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, _RemoteCacheEntry> _remoteCache = {};

  late bool _completed;
  late List<FoodItemLog> _items;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _completed = widget.initial.completed;
    _items = [...widget.initial.items];
    _tags = [...widget.initial.symptomTags];
    _notes.text = widget.initial.notes ?? '';

    _name.addListener(_onNameChanged);
    _nameFocus.addListener(_onNameFocusChanged);
    _initFoodDb();
    _loadRecentFoods();
  }

  Future<void> _initFoodDb() async {
    try {
      await _foodDb.initialize();
    } catch (e) {
      debugPrint('MealEditorSheet: FoodDatabaseService.initialize error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loadingDb = false);
      _refreshSuggestions(_name.text);
    }
  }

  void _onNameFocusChanged() {
    // When the user taps into the field (even if empty), show recent foods
    // so the experience feels “instant”.
    if (!mounted) return;
    if (_nameFocus.hasFocus) _refreshSuggestions(_name.text);
  }

  Future<void> _loadRecentFoods() async {
    try {
      final foods = await _nutrition.getRecentFoods(widget.userId);
      if (!mounted) return;
      setState(() {
        _recentFoods = foods;
        _loadingFoods = false;
      });
      _refreshSuggestions(_name.text);
    } catch (e) {
      debugPrint('MealEditorSheet: failed to load recent foods: $e');
      if (!mounted) return;
      setState(() {
        _recentFoods = const [];
        _filteredFoods = const [];
        _loadingFoods = false;
      });
    }
  }

  void _onNameChanged() {
    final now = DateTime.now();
    if (now.difference(_lastQueryAt) < const Duration(milliseconds: 70)) return;
    _lastQueryAt = now;
    _refreshSuggestions(_name.text);
  }

  void _refreshSuggestions(String query) {
    final q = query.trim().toLowerCase();

    // If the field is focused but empty, show the user's top recent foods.
    if (q.isEmpty) {
      _remoteDebounce?.cancel();
      if (_nameFocus.hasFocus && !_loadingFoods) {
        final top = _recentFoods.take(8).toList(growable: false);
        setState(() {
          _filteredFoods = top;
          _dbFoods = const [];
          _remoteFoods = const [];
          _loadingRemote = false;
        });
      } else if (_filteredFoods.isNotEmpty || _remoteFoods.isNotEmpty || _loadingRemote) {
        setState(() {
          _filteredFoods = const [];
          _dbFoods = const [];
          _remoteFoods = const [];
          _loadingRemote = false;
        });
      }
      return;
    }

    // Local suggestions: from the user's recent logs.
    final matches = _recentFoods.where((f) {
      final name = f.name.trim().toLowerCase();
      return name.contains(q);
    }).toList(growable: false);

    // Rank: prefix matches first, then shortest name.
    matches.sort((a, b) {
      final an = a.name.trim().toLowerCase();
      final bn = b.name.trim().toLowerCase();
      final ap = an.startsWith(q) ? 0 : 1;
      final bp = bn.startsWith(q) ? 0 : 1;
      if (ap != bp) return ap.compareTo(bp);
      return an.length.compareTo(bn.length);
    });

    final local = matches.take(8).toList(growable: false);
    setState(() => _filteredFoods = local);

    // Local library suggestions: built-in + custom foods.
    if (!_loadingDb) {
      try {
        final db = _foodDb.searchFoods(q, limit: 8);
        setState(() => _dbFoods = db);
      } catch (e) {
        debugPrint('MealEditorSheet: local DB search error: $e');
        setState(() => _dbFoods = const []);
      }
    }

    // Remote suggestions: search online APIs via Supabase Edge Function (CORS-safe).
    if (q.length < 2) {
      _remoteDebounce?.cancel();
      if (_remoteFoods.isNotEmpty || _loadingRemote) {
        setState(() {
          _remoteFoods = const [];
          _loadingRemote = false;
        });
      }
      return;
    }

    // If we already have cached results for this exact query (first page), use them instantly.
    final cached = _remoteCache[q];
    if (cached != null) {
      setState(() {
        _remoteQuery = q;
        _remotePage = cached.page;
        _remoteHasMore = cached.hasMore;
        _remoteFoods = cached.results;
        _loadingRemote = false;
        _loadingRemoteMore = false;
      });
      return;
    }

    _remoteDebounce?.cancel();
    _remoteDebounce = Timer(const Duration(milliseconds: 260), () {
      _searchRemoteFoods(q, reset: true);
    });
  }

  Future<void> _loadMoreRemote() async {
    final q = _remoteQuery;
    if (q.trim().isEmpty) return;
    if (_loadingRemote || _loadingRemoteMore || !_remoteHasMore) return;
    await _searchRemoteFoods(q, reset: false);
  }

  Future<void> _searchRemoteFoods(String q, {required bool reset}) async {
    if (!mounted) return;
    final token = ++_remoteQueryToken;
    final pageSize = 24;

    if (reset) {
      setState(() {
        _remoteQuery = q;
        _remotePage = 1;
        _remoteHasMore = false;
        _remoteFoods = const [];
        _loadingRemote = true;
        _loadingRemoteMore = false;
      });
    } else {
      setState(() {
        _loadingRemoteMore = true;
      });
    }

    try {
      final page = reset ? 1 : (_remotePage + 1);
      final res = await SupabaseConfig.client.functions.invoke(
        'food_search',
        body: {'query': q, 'limit': pageSize, 'page': page},
      );

      if (!mounted || token != _remoteQueryToken) return;

      if (res.status != 200) {
        debugPrint('MealEditorSheet: food_search edge function failed (${res.status})');
        setState(() {
          _remoteFoods = const [];
          _loadingRemote = false;
          _loadingRemoteMore = false;
          _remoteHasMore = false;
        });
        return;
      }

      final decoded = res.data;
      final list = decoded is Map ? decoded['results'] : null;
      if (list is! List) {
        setState(() {
          _remoteFoods = const [];
          _loadingRemote = false;
          _loadingRemoteMore = false;
          _remoteHasMore = false;
        });
        return;
      }

      final results = <_RemoteFoodSuggestion>[];
      double? d(dynamic v) => v == null ? null : double.tryParse(v.toString());

      for (final item in list) {
        if (item is! Map) continue;
        final name = (item['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final brand = (item['brand'] ?? '').toString().trim();
        final source = (item['source'] ?? '').toString().trim();

        final per = item['per100g'];
        final perMap = per is Map ? per : const {};
        final kcal = perMap['calories'] == null ? null : int.tryParse(perMap['calories'].toString());
        final protein = d(perMap['protein_g']);
        final carbs = d(perMap['carbs_g']);
        final fats = d(perMap['fats_g']);
        final fiber = d(perMap['fiber_g']);
        final sugar = d(perMap['sugar_g']);
        final sodiumMg = perMap['sodium_mg'] == null ? null : int.tryParse(perMap['sodium_mg'].toString());

        // Only include results that can autofill something.
        if (kcal == null && protein == null && carbs == null && fats == null) continue;

        results.add(
          _RemoteFoodSuggestion(
            name: name,
            brand: brand.isEmpty ? null : brand,
            source: source.isEmpty ? null : source,
            caloriesPer100g: kcal,
            proteinGPer100g: protein,
            carbsGPer100g: carbs,
            fatsGPer100g: fats,
            fiberGPer100g: fiber,
            sugarGPer100g: sugar,
            sodiumMgPer100g: sodiumMg,
          ),
        );
      }

      if (!mounted || token != _remoteQueryToken) return;

      final merged = <_RemoteFoodSuggestion>[];
      final seen = <String>{};
      void addUnique(Iterable<_RemoteFoodSuggestion> list) {
        for (final s in list) {
          final key = s.name.trim().toLowerCase();
          if (key.isEmpty || seen.contains(key)) continue;
          seen.add(key);
          merged.add(s);
        }
      }

      if (!reset) addUnique(_remoteFoods);
      addUnique(results);

      // Heuristic: if the API returned a full page, there might be more.
      final hasMore = list.length >= pageSize && results.isNotEmpty;
      setState(() {
        _remoteQuery = q;
        _remotePage = page;
        _remoteHasMore = hasMore;
        _remoteFoods = merged;
        _loadingRemote = false;
        _loadingRemoteMore = false;
      });

      // Cache only the first page so the initial experience feels instant.
      if (reset) _remoteCache[q] = _RemoteCacheEntry(page: page, hasMore: hasMore, results: merged);
    } catch (e) {
      debugPrint('MealEditorSheet: remote food search error: $e');
      if (!mounted || token != _remoteQueryToken) return;
      setState(() {
        if (reset) _remoteFoods = const [];
        _loadingRemote = false;
        _loadingRemoteMore = false;
        if (reset) _remoteHasMore = false;
      });

      // Cache empty on error for a short-lived UX improvement (prevents rapid repeats).
      if (reset) _remoteCache[q] = const _RemoteCacheEntry(page: 1, hasMore: false, results: []);
    }
  }

  void _applySuggestion(FoodItemLog item) {
    _name.text = item.name;
    _cal.text = item.macros.calories.toString();
    _protein.text = _fmt(item.macros.proteinG);
    _carbs.text = _fmt(item.macros.carbsG);
    _fats.text = _fmt(item.macros.fatsG);
    _fiber.text = _fmt(item.macros.fiberG);
    _sugar.text = _fmt(item.macros.sugarG);
    _sodium.text = item.macros.sodiumMg.toString();
    setState(() {
      _filteredFoods = const [];
      _remoteFoods = const [];
      _loadingRemote = false;
    });
    FocusScope.of(context).nextFocus();
  }

  void _applyRemoteSuggestion(_RemoteFoodSuggestion s) {
    _name.text = s.name;
    if (s.caloriesPer100g != null) _cal.text = s.caloriesPer100g.toString();
    if (s.proteinGPer100g != null) _protein.text = _fmt(s.proteinGPer100g!);
    if (s.carbsGPer100g != null) _carbs.text = _fmt(s.carbsGPer100g!);
    if (s.fatsGPer100g != null) _fats.text = _fmt(s.fatsGPer100g!);
    if (s.fiberGPer100g != null) _fiber.text = _fmt(s.fiberGPer100g!);
    if (s.sugarGPer100g != null) _sugar.text = _fmt(s.sugarGPer100g!);
    if (s.sodiumMgPer100g != null) _sodium.text = s.sodiumMgPer100g.toString();
    setState(() {
      _filteredFoods = const [];
      _remoteFoods = const [];
      _loadingRemote = false;
    });
    FocusScope.of(context).nextFocus();
  }

  void _applyDatabaseSuggestion(FoodDatabaseEntry f) {
    _name.text = f.name;
    _cal.text = f.macros.calories.toString();
    _protein.text = _fmt(f.macros.proteinG);
    _carbs.text = _fmt(f.macros.carbsG);
    _fats.text = _fmt(f.macros.fatsG);
    _fiber.text = _fmt(f.macros.fiberG);
    _sugar.text = _fmt(f.macros.sugarG);
    _sodium.text = f.macros.sodiumMg.toString();
    setState(() {
      _filteredFoods = const [];
      _dbFoods = const [];
      _remoteFoods = const [];
      _loadingRemote = false;
    });
    FocusScope.of(context).nextFocus();
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  String _macrosLine(NutritionMacros m) {
    final parts = <String>[];
    if (m.calories > 0) parts.add('${m.calories} kcal');
    if (m.proteinG > 0) parts.add('${m.proteinG.toStringAsFixed(0)}P');
    if (m.carbsG > 0) parts.add('${m.carbsG.toStringAsFixed(0)}C');
    if (m.fatsG > 0) parts.add('${m.fatsG.toStringAsFixed(0)}F');
    return parts.isEmpty ? 'Tap to autofill' : parts.join(' • ');
  }

  String _remoteMacrosLine(_RemoteFoodSuggestion s) {
    final parts = <String>[];
    if (s.caloriesPer100g != null) parts.add('${s.caloriesPer100g} kcal');
    if (s.proteinGPer100g != null) parts.add('${s.proteinGPer100g!.toStringAsFixed(0)}P');
    if (s.carbsGPer100g != null) parts.add('${s.carbsGPer100g!.toStringAsFixed(0)}C');
    if (s.fatsGPer100g != null) parts.add('${s.fatsGPer100g!.toStringAsFixed(0)}F');
    final brand = (s.brand ?? '').trim();
    final src = (s.source ?? '').trim();
    final metaParts = <String>[];
    if (brand.isNotEmpty) metaParts.add(brand);
    if (src.isNotEmpty) metaParts.add(src);
    final meta = metaParts.isEmpty ? '' : ' • ${metaParts.join(' • ')}';
    return parts.isEmpty ? 'Tap to autofill (per 100g)$meta' : '${parts.join(' • ')} (per 100g)$meta';
  }

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    _nameFocus.removeListener(_onNameFocusChanged);
    _nameFocus.dispose();
    _remoteDebounce?.cancel();
    _notes.dispose();
    _symptoms.dispose();
    _cal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fats.dispose();
    _fiber.dispose();
    _sugar.dispose();
    _sodium.dispose();
    super.dispose();
  }

  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
  double _dbl(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  void _addItem() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final now = DateTime.now();
    final item = FoodItemLog(
      name: name,
      macros: NutritionMacros(
        calories: _int(_cal),
        proteinG: _dbl(_protein),
        carbsG: _dbl(_carbs),
        fatsG: _dbl(_fats),
        fiberG: _dbl(_fiber),
        sugarG: _dbl(_sugar),
        sodiumMg: _int(_sodium),
      ),
      createdAt: now,
      updatedAt: now,
    );
    setState(() {
      _items.add(item);
      _name.clear();
      _cal.clear();
      _protein.clear();
      _carbs.clear();
      _fats.clear();
      _fiber.clear();
      _sugar.clear();
      _sodium.clear();
      _completed = true;
    });
  }

  void _addTag() {
    final raw = _symptoms.text.trim();
    if (raw.isEmpty) return;
    final parts = raw
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return;
    setState(() {
      for (final p in parts) {
        if (_tags.any((t) => t.toLowerCase() == p.toLowerCase())) continue;
        _tags.add(p);
      }
      _symptoms.clear();
    });
  }

  Future<void> _openFoodItemViewer(FoodItemLog item) async {
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _FoodItemViewSheet(item: item),
      );
    } catch (e) {
      debugPrint('MealEditorSheet: failed to open food viewer: $e');
    }
  }

  FoodItemLog _foodFromRemote(_RemoteFoodSuggestion s) {
    final now = DateTime.now();
    return FoodItemLog(
      name: s.name,
      macros: NutritionMacros(
        calories: s.caloriesPer100g ?? 0,
        proteinG: s.proteinGPer100g ?? 0,
        carbsG: s.carbsGPer100g ?? 0,
        fatsG: s.fatsGPer100g ?? 0,
        fiberG: s.fiberGPer100g ?? 0,
        sugarG: s.sugarGPer100g ?? 0,
        sodiumMg: s.sodiumMgPer100g ?? 0,
      ),
      notes: 'From food database (per 100g)',
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(widget.initial.type.label, style: text.titleLarge?.semiBold)),
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    )
                  ],
                ),
                Text('Add foods, quick macros, and how you felt after.', style: text.bodyMedium?.withColor(cs.onSurfaceVariant)),
                SizedBox(height: AppSpacing.lg),

                _SectionTitle(icon: Icons.add_circle_outline, title: 'Add food'),
                SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _name,
                  focusNode: _nameFocus,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Food name',
                    suffixIcon: _name.text.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () {
                              _name.clear();
                              _refreshSuggestions('');
                              _nameFocus.requestFocus();
                            },
                            icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                          ),
                  ),
                ),
                if (_loadingFoods ||
                    _loadingDb ||
                    _loadingRemote ||
                    _filteredFoods.isNotEmpty ||
                    _dbFoods.isNotEmpty ||
                    _remoteFoods.isNotEmpty ||
                    (_nameFocus.hasFocus && _name.text.trim().isNotEmpty)) ...[
                  SizedBox(height: AppSpacing.xs),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.40),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 16, color: cs.onSurfaceVariant),
                            SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                _loadingFoods
                                    ? 'Loading your recent foods…'
                                    : _loadingDb
                                        ? 'Loading food library…'
                                        : _loadingRemote
                                            ? 'Searching foods…'
                                            : 'Suggestions',
                                style: text.labelSmall?.withColor(cs.onSurfaceVariant),
                              ),
                            ),
                            if (_loadingRemote) ...[
                              SizedBox(width: AppSpacing.sm),
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: AppSpacing.sm),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              if (!_loadingFoods && _filteredFoods.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(Icons.history, size: 16, color: cs.onSurfaceVariant),
                                    SizedBox(width: AppSpacing.xs),
                                    Expanded(child: Text('From your recent logs', style: text.labelSmall?.withColor(cs.onSurfaceVariant))),
                                  ],
                                ),
                                SizedBox(height: AppSpacing.sm),
                                for (final f in _filteredFoods)
                                  _FoodSuggestionTile(
                                    title: f.name,
                                    subtitle: _macrosLine(f.macros),
                                    leadingIcon: Icons.history,
                                    onTap: () => _applySuggestion(f),
                                    onView: () => _openFoodItemViewer(f),
                                  ),
                              ],
                              if (!_loadingDb && _dbFoods.isNotEmpty) ...[
                                if (_filteredFoods.isNotEmpty) SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    Icon(Icons.auto_awesome, size: 16, color: cs.onSurfaceVariant),
                                    SizedBox(width: AppSpacing.xs),
                                    Expanded(child: Text('From your food library', style: text.labelSmall?.withColor(cs.onSurfaceVariant))),
                                  ],
                                ),
                                SizedBox(height: AppSpacing.sm),
                                for (final f in _dbFoods)
                                  _FoodSuggestionTile(
                                    title: f.name,
                                    subtitle: '${_macrosLine(f.macros)} • ${f.brand}',
                                    leadingIcon: Icons.auto_awesome,
                                    onTap: () => _applyDatabaseSuggestion(f),
                                    onView: () => _openFoodItemViewer(
                                      FoodItemLog(
                                        name: f.name,
                                        macros: f.macros,
                                        notes: 'From food library (${f.brand})',
                                        createdAt: DateTime.now(),
                                        updatedAt: DateTime.now(),
                                      ),
                                    ),
                                  ),
                              ],
                              if (!_loadingRemote && _remoteFoods.isNotEmpty) ...[
                                if (_filteredFoods.isNotEmpty || _dbFoods.isNotEmpty) SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    Icon(Icons.public, size: 16, color: cs.onSurfaceVariant),
                                    SizedBox(width: AppSpacing.xs),
                                    Expanded(child: Text('From food database (per 100g)', style: text.labelSmall?.withColor(cs.onSurfaceVariant))),
                                  ],
                                ),
                                SizedBox(height: AppSpacing.sm),
                                for (final s in _remoteFoods)
                                  _FoodSuggestionTile(
                                    title: s.name,
                                    subtitle: _remoteMacrosLine(s),
                                    leadingIcon: Icons.public,
                                    onTap: () => _applyRemoteSuggestion(s),
                                    onView: () => _openFoodItemViewer(_foodFromRemote(s)),
                                  ),
                                if (_remoteHasMore) ...[
                                  SizedBox(height: AppSpacing.sm),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: _loadingRemoteMore ? null : _loadMoreRemote,
                                      icon: _loadingRemoteMore
                                          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                                          : Icon(Icons.expand_more, color: cs.primary),
                                      label: Text(
                                        _loadingRemoteMore ? 'Loading more…' : 'Load more results',
                                        style: text.labelLarge?.withColor(cs.primary),
                                      ),
                                    ),
                                  ),
                                ]
                              ],
                            ],
                          ),
                        ),
                        if (!_loadingFoods && !_loadingDb && !_loadingRemote && _filteredFoods.isEmpty && _dbFoods.isEmpty && _remoteFoods.isEmpty && _name.text.trim().isNotEmpty) ...[
                          SizedBox(height: AppSpacing.sm),
                          Text('No matches yet — keep typing or add macros manually.', style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ),
                ],
                SizedBox(height: AppSpacing.sm),
                _MacroRow(
                  calories: _cal,
                  protein: _protein,
                  carbs: _carbs,
                  fats: _fats,
                ),
                SizedBox(height: AppSpacing.sm),
                _MicroRow(fiber: _fiber, sugar: _sugar, sodium: _sodium),
                SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _addItem,
                    icon: Icon(Icons.add, color: cs.onPrimary),
                    label: Text('Add', style: text.labelLarge?.semiBold.withColor(cs.onPrimary)),
                  ),
                ),

                if (_items.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.lg),
                  _SectionTitle(icon: Icons.list_alt_outlined, title: 'Items'),
                  SizedBox(height: AppSpacing.sm),
                  for (int i = 0; i < _items.length; i++) ...[
                    _FoodRow(
                      item: _items[i],
                      onView: () => _openFoodItemViewer(_items[i]),
                      onRemove: () => setState(() => _items.removeAt(i)),
                    ),
                    SizedBox(height: AppSpacing.xs),
                  ]
                ],

                SizedBox(height: AppSpacing.lg),
                _SectionTitle(icon: Icons.notes_outlined, title: 'Notes & symptoms'),
                SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes (e.g., bloated, good energy, nausea)') ,
                ),
                SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _symptoms,
                        decoration: const InputDecoration(labelText: 'Add symptom tags (comma separated)') ,
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: _addTag,
                      child: Text('Add', style: text.labelLarge?.withColor(cs.primary)),
                    )
                  ],
                ),
                if (_tags.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _tags
                        .map((t) => InputChip(
                              label: Text(t),
                              onDeleted: () => setState(() => _tags.remove(t)),
                            ))
                        .toList(growable: false),
                  )
                ],

                SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.task_alt, color: cs.primary),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(child: Text('Mark meal completed', style: text.bodyMedium)),
                            Switch.adaptive(value: _completed, onChanged: (v) => setState(() => _completed = v)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final now = DateTime.now();
                          context.pop(MealLog(
                            type: widget.initial.type,
                            items: _items,
                            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                            symptomTags: _tags,
                            completed: _completed,
                            createdAt: widget.initial.createdAt,
                            updatedAt: now,
                          ));
                        },
                        child: Text('Save meal', style: text.labelLarge?.semiBold.withColor(cs.onPrimary)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return Row(
      children: [
        Icon(icon, color: cs.primary),
        SizedBox(width: AppSpacing.sm),
        Text(title, style: text.titleSmall?.semiBold),
      ],
    );
  }
}

class _FoodSuggestionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData leadingIcon;
  final VoidCallback onTap;
  final VoidCallback? onView;

  const _FoodSuggestionTile({
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    required this.onTap,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
              ),
              child: Icon(leadingIcon, size: 16, color: cs.primary),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium?.semiBold),
                  SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            if (onView != null)
              IconButton(
                onPressed: onView,
                tooltip: 'View details',
                icon: Icon(Icons.visibility_outlined, size: 18, color: cs.onSurfaceVariant),
              )
            else
              Icon(Icons.north_west, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final TextEditingController calories;
  final TextEditingController protein;
  final TextEditingController carbs;
  final TextEditingController fats;
  const _MacroRow({required this.calories, required this.protein, required this.carbs, required this.fats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _NumField(controller: calories, label: 'kcal')),
        SizedBox(width: AppSpacing.sm),
        Expanded(child: _NumField(controller: protein, label: 'protein g')),
        SizedBox(width: AppSpacing.sm),
        Expanded(child: _NumField(controller: carbs, label: 'carbs g')),
        SizedBox(width: AppSpacing.sm),
        Expanded(child: _NumField(controller: fats, label: 'fat g')),
      ],
    );
  }
}

class _MicroRow extends StatelessWidget {
  final TextEditingController fiber;
  final TextEditingController sugar;
  final TextEditingController sodium;
  const _MicroRow({required this.fiber, required this.sugar, required this.sodium});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _NumField(controller: fiber, label: 'fiber g')),
        SizedBox(width: AppSpacing.sm),
        Expanded(child: _NumField(controller: sugar, label: 'sugar g')),
        SizedBox(width: AppSpacing.sm),
        Expanded(child: _NumField(controller: sodium, label: 'sodium mg')),
      ],
    );
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _NumField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final FoodItemLog item;
  final VoidCallback onView;
  final VoidCallback onRemove;
  const _FoodRow({required this.item, required this.onView, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final m = item.macros;

    return InkWell(
      onTap: onView,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: text.bodyMedium?.semiBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2),
                  Text(
                    '${m.calories} kcal • ${m.proteinG.toStringAsFixed(0)}P ${m.carbsG.toStringAsFixed(0)}C ${m.fatsG.toStringAsFixed(0)}F',
                    style: text.labelSmall?.withColor(cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.close, color: cs.onSurfaceVariant),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodItemViewSheet extends StatelessWidget {
  final FoodItemLog item;
  const _FoodItemViewSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final m = item.macros;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    Widget metric({required String label, required String value, required IconData icon}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35))),
            child: Icon(icon, size: 18, color: cs.primary),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
                SizedBox(height: 2),
                Text(value, style: text.bodyMedium?.semiBold),
              ],
            ),
          ),
        ],
      ),
    );

    String grams(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.name, style: text.titleLarge?.semiBold, maxLines: 2, overflow: TextOverflow.ellipsis)),
                    IconButton(
                      onPressed: context.pop,
                      tooltip: 'Close',
                      icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                Text('Nutrition details', style: text.bodyMedium?.withColor(cs.onSurfaceVariant)),
                SizedBox(height: AppSpacing.lg),

                Row(
                  children: [
                    Expanded(child: metric(label: 'Calories', value: '${m.calories} kcal', icon: Icons.local_fire_department_outlined)),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: metric(label: 'Protein', value: '${grams(m.proteinG)} g', icon: Icons.fitness_center_outlined)),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: metric(label: 'Carbs', value: '${grams(m.carbsG)} g', icon: Icons.grain_outlined)),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: metric(label: 'Fats', value: '${grams(m.fatsG)} g', icon: Icons.opacity_outlined)),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: metric(label: 'Fiber', value: '${grams(m.fiberG)} g', icon: Icons.eco_outlined)),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: metric(label: 'Sugar', value: '${grams(m.sugarG)} g', icon: Icons.cookie_outlined)),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                metric(label: 'Sodium', value: '${m.sodiumMg} mg', icon: Icons.science_outlined),

                if ((item.notes ?? '').trim().isNotEmpty) ...[
                  SizedBox(height: AppSpacing.lg),
                  Text('Notes', style: text.titleSmall?.semiBold),
                  SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: Text(item.notes!.trim(), style: text.bodyMedium),
                  ),
                ],

                SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: context.pop,
                  icon: Icon(Icons.done, color: cs.onPrimary),
                  label: Text('Done', style: text.labelLarge?.semiBold.withColor(cs.onPrimary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoteFoodSuggestion {
  final String name;
  final String? brand;
  final String? source;
  final int? caloriesPer100g;
  final double? proteinGPer100g;
  final double? carbsGPer100g;
  final double? fatsGPer100g;
  final double? fiberGPer100g;
  final double? sugarGPer100g;
  final int? sodiumMgPer100g;

  const _RemoteFoodSuggestion({
    required this.name,
    required this.brand,
    required this.source,
    required this.caloriesPer100g,
    required this.proteinGPer100g,
    required this.carbsGPer100g,
    required this.fatsGPer100g,
    required this.fiberGPer100g,
    required this.sugarGPer100g,
    required this.sodiumMgPer100g,
  });
}

class _RemoteCacheEntry {
  final int page;
  final bool hasMore;
  final List<_RemoteFoodSuggestion> results;
  const _RemoteCacheEntry({required this.page, required this.hasMore, required this.results});
}

class _DietPlanGeneratorSheet extends StatefulWidget {
  final List<String> currentConditions;
  const _DietPlanGeneratorSheet({required this.currentConditions});

  @override
  State<_DietPlanGeneratorSheet> createState() => _DietPlanGeneratorSheetState();
}

class _DietPlanGeneratorSheetState extends State<_DietPlanGeneratorSheet> {
  String _goal = 'General wellness';
  final _diagnosis = TextEditingController();
  final _allergies = TextEditingController();
  final _restrictions = TextEditingController();
  final _budget = TextEditingController();
  final _cooking = TextEditingController();
  final _preferred = TextEditingController();
  final _avoid = TextEditingController();
  final _mealsPerDay = TextEditingController(text: '3');
  final _targetCalories = TextEditingController();
  final _targetProtein = TextEditingController();
  final _targetCarbs = TextEditingController();
  final _targetFats = TextEditingController();

  @override
  void dispose() {
    _diagnosis.dispose();
    _allergies.dispose();
    _restrictions.dispose();
    _budget.dispose();
    _cooking.dispose();
    _preferred.dispose();
    _avoid.dispose();
    _mealsPerDay.dispose();
    _targetCalories.dispose();
    _targetProtein.dispose();
    _targetCarbs.dispose();
    _targetFats.dispose();
    super.dispose();
  }

  List<String> _splitList(String raw) => raw
      .split(RegExp(r'[,\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  int? _intOrNull(String s) {
    final v = int.tryParse(s.trim());
    return (v == null || v <= 0) ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    const goals = <String>[
      'Weight loss',
      'Muscle gain',
      'Energy',
      'Recovery',
      'Blood sugar support',
      'Heart health',
      'Gut health',
      'General wellness',
    ];

    final conditions = widget.currentConditions.where((c) => c.trim().isNotEmpty).toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('AI Diet Plan', style: text.titleLarge?.semiBold)),
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    )
                  ],
                ),
                Text('Answer a few prompts — we’ll keep it simple and safe.', style: text.bodyMedium?.withColor(cs.onSurfaceVariant)),
                if (conditions.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Using your conditions', style: text.labelLarge?.semiBold),
                        SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: conditions
                              .take(8)
                              .map((c) => _TagPill(label: c))
                              .toList(growable: false),
                        ),
                        if (conditions.length > 8) ...[
                          SizedBox(height: AppSpacing.xs),
                          Text('+${conditions.length - 8} more', style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
                        ]
                      ],
                    ),
                  )
                ],
                SizedBox(height: AppSpacing.lg),

                Text('Primary goal', style: text.labelLarge?.withColor(cs.onSurfaceVariant)),
                SizedBox(height: AppSpacing.xs),
                _GoalChipPicker(
                  goals: goals,
                  value: _goal,
                  onChanged: (v) => setState(() => _goal = v),
                ),
                SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _diagnosis,
                  decoration: const InputDecoration(labelText: 'Diagnosis / condition-related needs (optional)'),
                ),
                SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _allergies,
                  decoration: const InputDecoration(labelText: 'Allergies (comma separated)'),
                ),
                SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _restrictions,
                  decoration: const InputDecoration(labelText: 'Restrictions (vegetarian, low FODMAP, etc.)'),
                ),
                SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _budget,
                  decoration: const InputDecoration(labelText: 'Budget (optional)'),
                ),
                SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _cooking,
                  decoration: const InputDecoration(labelText: 'Cooking ability (optional)'),
                ),
                SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _preferred,
                  decoration: const InputDecoration(labelText: 'Preferred foods (optional)'),
                ),
                SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _avoid,
                  decoration: const InputDecoration(labelText: 'Foods to avoid (optional)'),
                ),
                SizedBox(height: AppSpacing.sm),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mealsPerDay,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Meals per day'),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _targetCalories,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Calories target (optional)'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _targetProtein,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Protein g (optional)'),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _targetCarbs,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Carbs g (optional)'),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _targetFats,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Fats g (optional)'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),

                Container(
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: cs.onErrorContainer),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'AI-generated nutrition suggestions are for educational and planning purposes only and are not a replacement for medical advice. Users with medical conditions should consult a licensed healthcare professional or registered dietitian before making major diet changes.',
                          style: text.bodySmall?.withColor(cs.onErrorContainer),
                        ),
                      )
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.lg),

                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          final meals = int.tryParse(_mealsPerDay.text.trim()) ?? 3;
                          context.pop(DietPlanInput(
                            primaryGoal: _goal,
                            diagnosisOrNeed: _diagnosis.text.trim().isEmpty ? null : _diagnosis.text.trim(),
                            allergies: _splitList(_allergies.text),
                            restrictions: _splitList(_restrictions.text),
                            budget: _budget.text.trim().isEmpty ? null : _budget.text.trim(),
                            cookingAbility: _cooking.text.trim().isEmpty ? null : _cooking.text.trim(),
                            preferredFoods: _splitList(_preferred.text),
                            foodsToAvoid: _splitList(_avoid.text),
                            mealsPerDay: meals.clamp(2, 6),
                            targetCalories: _intOrNull(_targetCalories.text),
                            targetProteinG: _intOrNull(_targetProtein.text),
                            targetCarbsG: _intOrNull(_targetCarbs.text),
                            targetFatsG: _intOrNull(_targetFats.text),
                          ));
                        },
                        icon: Icon(Icons.auto_awesome, color: cs.onPrimary),
                        label: Text('Generate', style: text.labelLarge?.semiBold.withColor(cs.onPrimary)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DietPlanPreviewSheet extends StatelessWidget {
  final DietPlanResult plan;
  final ValueChanged<int> onCopyDayToToday;

  const _DietPlanPreviewSheet({required this.plan, required this.onCopyDayToToday});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(plan.title, style: text.titleLarge?.semiBold)),
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    )
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Container(
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_user_outlined, color: cs.onErrorContainer),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          plan.medicalSafetyDisclaimer,
                          style: text.bodySmall?.withColor(cs.onErrorContainer),
                        ),
                      )
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.lg),

                Text('Why this fits', style: text.titleSmall?.semiBold),
                SizedBox(height: AppSpacing.sm),
                for (final w in plan.whyThisFits.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline, size: 18, color: cs.primary),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(w, style: text.bodyMedium)),
                      ],
                    ),
                  ),

                SizedBox(height: AppSpacing.lg),
                Text('7‑day meals', style: text.titleSmall?.semiBold),
                SizedBox(height: AppSpacing.sm),
                for (int i = 0; i < plan.days.length; i++) ...[
                  _PlanDayCard(day: plan.days[i], onCopy: () => onCopyDayToToday(i)),
                  SizedBox(height: AppSpacing.sm),
                ],

                SizedBox(height: AppSpacing.lg),
                Text('Grocery list', style: text.titleSmall?.semiBold),
                SizedBox(height: AppSpacing.sm),
                _BulletCard(items: plan.groceryList),
                SizedBox(height: AppSpacing.lg),
                Text('Meal prep', style: text.titleSmall?.semiBold),
                SizedBox(height: AppSpacing.sm),
                _BulletCard(items: plan.mealPrepSuggestions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalChipPicker extends StatelessWidget {
  final List<String> goals;
  final String value;
  final ValueChanged<String> onChanged;

  const _GoalChipPicker({required this.goals, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingSm,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final g in goals)
            ChoiceChip(
              label: Text(g, style: text.labelMedium),
              selected: g == value,
              onSelected: (_) => onChanged(g),
              showCheckmark: false,
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
              selectedColor: cs.primary.withValues(alpha: 0.16),
              backgroundColor: cs.surface.withValues(alpha: 0.4),
              labelStyle: (g == value)
                  ? text.labelMedium?.semiBold.withColor(cs.onSurface)
                  : text.labelMedium?.withColor(cs.onSurface),
            ),
        ],
      ),
    );
  }
}

class _PlanDayCard extends StatelessWidget {
  final DietPlanDay day;
  final VoidCallback onCopy;
  const _PlanDayCard({required this.day, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    DietPlanMeal? meal(String key) => day.meals[key];

    Widget mealRow(String label, DietPlanMeal? m) {
      if (m == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.labelLarge?.semiBold.withColor(cs.primary)),
            SizedBox(height: 2),
            Text(m.title, style: text.bodyMedium?.semiBold),
            SizedBox(height: 2),
            Text(m.description, style: text.bodySmall?.withColor(cs.onSurfaceVariant)),
            if (m.approxMacros != null && m.approxMacros!.trim().isNotEmpty) ...[
              SizedBox(height: 2),
              Text(m.approxMacros!, style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
            ]
          ],
        ),
      );
    }

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(day.dayLabel, style: text.titleSmall?.semiBold)),
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: Icon(Icons.copy, color: cs.primary),
                label: Text('Copy to today', style: text.labelLarge?.withColor(cs.primary)),
              )
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          mealRow('Breakfast', meal('breakfast')),
          mealRow('Lunch', meal('lunch')),
          mealRow('Dinner', meal('dinner')),
          mealRow('Snack', meal('snack')),
          if (day.notes != null && day.notes!.trim().isNotEmpty) ...[
            SizedBox(height: AppSpacing.sm),
            Text(day.notes!, style: text.bodySmall?.withColor(cs.onSurfaceVariant)),
          ]
        ],
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  final List<String> items;
  const _BulletCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final safe = items.where((e) => e.trim().isNotEmpty).toList();
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: safe.isEmpty
          ? Text('—', style: text.bodySmall?.withColor(cs.onSurfaceVariant))
          : Column(
              children: [
                for (final i in safe.take(40))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Icon(Icons.circle, size: 6, color: cs.primary),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(i, style: text.bodyMedium)),
                      ],
                    ),
                  )
              ],
            ),
    );
  }
}
