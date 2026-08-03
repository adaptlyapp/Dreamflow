import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/models/goal.dart';
import 'package:wellspring/models/post.dart';
import 'package:wellspring/models/resource.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/services/guidance_service.dart';
import 'package:wellspring/services/goal_service.dart';
import 'package:wellspring/services/post_service.dart';
import 'package:wellspring/services/resource_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/post_card.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/services/milestone_service.dart';
import 'package:wellspring/screens/goals/milestone_education_page.dart';
import 'package:wellspring/models/condition_detail.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class ConditionDetailScreen extends StatefulWidget {
  final String conditionId;

  const ConditionDetailScreen({super.key, required this.conditionId});

  @override
  State<ConditionDetailScreen> createState() => _ConditionDetailScreenState();
}

class _ConditionDetailScreenState extends State<ConditionDetailScreen>
    with SingleTickerProviderStateMixin {
  final _conditionService = ConditionService();
  final _guidance = GuidanceService();
  final _goalService = GoalService();
  final _postService = PostService();
  final _resourceService = ResourceService();
  final _userService = UserService();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  Condition? _condition;
  bool _isLoading = true;
  String? _userId;
  String _stage = '';
  List<Goal> _activeGoals = [];
  bool _showAllGoals = false;
  List<Post> _posts = [];
  List<Resource> _resources = [];
  List<Milestone> _milestones = [];
  bool _showPlanNotice = false;
  String? _planNoticeText;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final condition =
        await _conditionService.getConditionById(widget.conditionId);
    final user = await _userService.getCurrentUser();
    if (condition == null) {
      setState(() {
        _isLoading = false;
        _condition = null;
      });
      return;
    }
    final userId = user?.id;
    final stage = _guidance.stageLabel(user?.diagnosisDate);

    final hydratedCondition = (() {
      try {
        final detail = (user == null)
            ? null
            : ConditionDetail.tryFromUserPreferences(
                preferences: user.preferences,
                conditionId: condition.id,
              );
        return condition.copyWith(userDetail: detail);
      } catch (e) {
        debugPrint('[ConditionDetail] Failed hydrating user detail: $e');
        return condition;
      }
    })();
    List<Goal> goals = [];
    List<Post> posts = [];
    List<Resource> res = [];
    if (userId != null) {
      goals = await _goalService.getActiveGoals(userId);
      posts = await _postService.getPersonalizedFeed(
          userConditions: [condition.id]);
      _milestones = await MilestoneService()
          .list(userId: userId, conditionId: condition.id);
    } else {
      posts = await _postService.getPersonalizedFeed(
          userConditions: [condition.id]);
    }
    res = await _resourceService.searchResources(conditions: [condition.id]);

    setState(() {
      _condition = hydratedCondition;
      _userId = userId;
      _stage = stage;
      _activeGoals = goals;
      _posts = posts;
      _resources = res;
      _isLoading = false;
    });
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CenteredLoadingSkeleton()),
      );
    }

    if (_condition == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Condition not found')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildHeroHeader(context),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  _buildStageCard(context),
                  SizedBox(height: AppSpacing.lg),
                  _buildGoalsSection(context),
                  SizedBox(height: AppSpacing.lg),
                  _buildTimelineSection(context),
                  SizedBox(height: AppSpacing.lg),
                  _buildCommunitySection(context),
                  SizedBox(height: AppSpacing.lg),
                  _buildResourcesSection(context),
                  SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      stretch: true,
      backgroundColor: isDark ? DarkModeColors.slate : scheme.primaryContainer,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.fadeTitle,
        ],
        title: Text(
          _condition!.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
        ),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      DarkModeColors.adaptlyDeep.withValues(alpha: 0.4),
                      DarkModeColors.slate,
                    ]
                  : [
                      scheme.primaryContainer,
                      scheme.surface,
                    ],
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        scheme.primary.withValues(alpha: 0.2),
                        scheme.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: -40,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        scheme.tertiary.withValues(alpha: 0.15),
                        scheme.tertiary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              // Icon decoration
              Positioned(
                top: 80,
                right: 24,
                child: Icon(
                  Icons.accessibility_new,
                  size: 64,
                  color: scheme.primary.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Parse month from stage label for progress calculation
    final monthMatch = RegExp(r'Month (\d+)').firstMatch(_stage);
    final monthNum = monthMatch != null ? int.tryParse(monthMatch.group(1)!) ?? 1 : 1;
    final progress = (monthNum / 12).clamp(0.0, 1.0);

    return Padding(
      padding: AppSpacing.paddingLg,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    DarkModeColors.graphite,
                    DarkModeColors.slate,
                  ]
                : [
                    scheme.surface,
                    scheme.surfaceContainerHighest,
                  ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _CircularProgressRing(
              progress: progress,
              size: 72,
              strokeWidth: 6,
              backgroundColor: scheme.outline.withValues(alpha: 0.2),
              progressColor: scheme.primary,
              child: Icon(
                Icons.trending_up,
                color: scheme.primary,
                size: 28,
              ),
            ),
            SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR JOURNEY',
                    style: context.textStyles.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    _stage,
                    style: context.textStyles.titleLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Keep going! Every step matters.',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badges = _guidance.topBadgesFor(_condition!);
    final hasOverflowGoals = _activeGoals.length >= 4;
    final visibleGoals = !_showAllGoals && hasOverflowGoals
        ? _activeGoals.take(3).toList()
        : _activeGoals;

    return Padding(
      padding: AppSpacing.horizontalLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.flag_rounded, color: scheme.primary, size: 20),
              ),
              SizedBox(width: AppSpacing.md),
              Text(
                'Your Goals',
                style: context.textStyles.titleLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              if (_activeGoals.isNotEmpty)
                Text(
                  '${_activeGoals.length} active',
                  style: context.textStyles.labelMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),

          // Goals list
          if (_activeGoals.isEmpty)
            _EmptyStateCard(
              icon: Icons.emoji_events_outlined,
              title: 'No active goals yet',
              subtitle: 'Add goals from suggestions below to start tracking',
            )
          else
            ...visibleGoals.map((g) => Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: _GoalCard(
                    goal: g,
                    onIncrement: () async {
                      await _goalService.incrementProgress(g.id);
                      await _load();
                    },
                    onEdit: () => _addOrEditGoal(existing: g),
                  ),
                )),

          if (hasOverflowGoals)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showAllGoals = !_showAllGoals),
                  icon: Icon(
                    _showAllGoals
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: scheme.primary,
                  ),
                  label: Text(
                    _showAllGoals
                        ? 'Show less'
                        : 'Show more (${_activeGoals.length - 3})',
                    style: context.textStyles.labelLarge
                        ?.copyWith(color: scheme.primary),
                  ),
                ),
              ),
            ),

          SizedBox(height: AppSpacing.lg),

          // Suggestions
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: scheme.tertiary, size: 18),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Suggested for ${_condition!.name}',
                        style: context.textStyles.titleSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: badges
                      .map((b) => _SuggestionChip(
                            badge: b,
                            onTap: () => _showAddGoalSheet(context, b),
                            iconBuilder: _iconFor,
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'self_improvement':
        return Icons.self_improvement;
      case 'battery_full':
        return Icons.battery_full;
      case 'psychology':
        return Icons.psychology;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'stylus_note':
        return Icons.edit_note;
      case 'bedtime':
        return Icons.bedtime;
      case 'spa':
        return Icons.spa;
      case 'monitor_heart':
        return Icons.monitor_heart;
      case 'restaurant':
        return Icons.restaurant;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'water_drop':
        return Icons.water_drop;
      case 'visibility':
        return Icons.visibility;
      case 'fitness_center':
        return Icons.fitness_center;
      default:
        return Icons.flag_circle;
    }
  }

  Future<void> _showAddGoalSheet(BuildContext context, GoalBadge badge) async {
    if (_userId == null) return;
    final controller = TextEditingController(text: badge.title);
    final now = DateTime.now();
    final scheme = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
              AppSpacing.lg, MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(_iconFor(badge.iconName),
                        color: scheme.primary, size: 24),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Text('Add Goal',
                      style: ctx.textStyles.titleMedium?.semiBold),
                ],
              ),
              SizedBox(height: AppSpacing.lg),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Goal title'),
              ),
              SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final goal = Goal(
                      id: const Uuid().v4(),
                      userId: _userId!,
                      title: controller.text.trim().isEmpty
                          ? badge.title
                          : controller.text.trim(),
                      description: 'Suggested for ${_condition!.name}',
                      targetPerPeriod: 4,
                      progressThisPeriod: 0,
                      period: 'weekly',
                      lastResetAt: now,
                      linkedTrackerKey: badge.linkedTrackerKey,
                      createdAt: now,
                      updatedAt: now,
                    );
                    await _goalService.addGoal(goal);
                    if (mounted) Navigator.pop(ctx);
                    await _load();
                  },
                  icon: Icon(Icons.add, color: scheme.onPrimary),
                  label: const Text('Add Goal'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addOrEditGoal({Goal? existing}) async {
    final userId = _userId;
    if (userId == null) return;

    final cs = Theme.of(context).colorScheme;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String period = existing?.period ?? 'weekly';
    int target = existing?.targetPerPeriod ?? 4;

    const allowedPeriods = <String>{'weekly', 'none'};
    if (!allowedPeriods.contains(period)) period = 'weekly';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
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
                        hintText: 'e.g., Stretching routine',
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Description (optional)'),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: period,
                            decoration: const InputDecoration(labelText: 'Period'),
                            items: const [
                              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                              DropdownMenuItem(value: 'none', child: Text('None')),
                            ],
                            onChanged: (v) => setLocal(() => period = v ?? 'weekly'),
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextFormField(
                            initialValue: target.toString(),
                            decoration: const InputDecoration(labelText: 'Target per period'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setLocal(() => target = int.tryParse(v) ?? target),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        if (existing != null) ...[
                          OutlinedButton.icon(
                            onPressed: () async {
                              final confirm = await showModalBottomSheet<bool>(
                                context: ctx,
                                showDragHandle: true,
                                backgroundColor: cs.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(AppRadius.lg)),
                                ),
                                builder: (sheetCtx) {
                                  return SafeArea(
                                    top: false,
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        AppSpacing.lg,
                                        AppSpacing.sm,
                                        AppSpacing.lg,
                                        AppSpacing.lg,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: cs.error.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(Icons.delete_outline,
                                                    color: cs.error),
                                              ),
                                              SizedBox(width: AppSpacing.md),
                                              Expanded(
                                                child: Text('Delete goal?',
                                                    style: sheetCtx
                                                        .textStyles.titleMedium
                                                        ?.semiBold),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: AppSpacing.sm),
                                          Text(
                                            'This will permanently remove this goal. This can’t be undone.',
                                            style: sheetCtx.textStyles.bodyMedium
                                                ?.copyWith(color: cs.onSurfaceVariant),
                                          ),
                                          SizedBox(height: AppSpacing.md),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () => sheetCtx.pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                              ),
                                              SizedBox(width: AppSpacing.sm),
                                              Expanded(
                                                child: FilledButton(
                                                  style: FilledButton.styleFrom(
                                                      backgroundColor: cs.error),
                                                  onPressed: () => sheetCtx.pop(true),
                                                  child: Text('Delete',
                                                      style: TextStyle(color: cs.onError)),
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
                                await _load();
                              } catch (e) {
                                debugPrint('Delete goal error: $e');
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not delete: $e')),
                                );
                              }
                            },
                            icon: Icon(Icons.delete_outline, color: cs.error),
                            label: Text('Delete',
                                style: TextStyle(color: cs.error)),
                          ),
                          const Spacer(),
                        ] else
                          const Spacer(),
                        FilledButton(
                          onPressed: () async {
                            final title = titleCtrl.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please add a title')),
                              );
                              return;
                            }
                            try {
                              final now = DateTime.now();
                              if (existing == null) {
                                final goal = Goal(
                                  id: const Uuid().v4(),
                                  userId: userId,
                                  title: title,
                                  description: descCtrl.text.trim().isEmpty
                                      ? null
                                      : descCtrl.text.trim(),
                                  targetPerPeriod: target,
                                  progressThisPeriod: 0,
                                  period: period,
                                  lastResetAt: now,
                                  linkedTrackerKey: null,
                                  createdAt: now,
                                  updatedAt: now,
                                );
                                await _goalService.addGoal(goal);
                              } else {
                                await _goalService.updateGoal(
                                  existing.copyWith(
                                    title: title,
                                    description: descCtrl.text.trim().isEmpty
                                        ? null
                                        : descCtrl.text.trim(),
                                    targetPerPeriod: target,
                                    period: period,
                                  ),
                                );
                              }
                              if (mounted) ctx.pop();
                              await _load();
                            } catch (e) {
                              debugPrint('Save goal error: $e');
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not save: $e')),
                              );
                            }
                          },
                          child: Text(existing == null ? 'Add' : 'Save',
                              style: TextStyle(color: cs.onPrimary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimelineSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: AppSpacing.horizontalLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showPlanNotice && (_planNoticeText?.isNotEmpty == true)) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _planNoticeText!,
                      style: context.textStyles.bodyMedium
                          ?.copyWith(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.md),
          ],

          // Section header with hero CTA
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: scheme.tertiary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.timeline_rounded, color: scheme.tertiary, size: 20),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Milestones & Timeline',
                      style: context.textStyles.titleLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (_userId != null && _milestones.isNotEmpty) ...[
                SizedBox(height: AppSpacing.md),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0xFF0F1B2D),
                              const Color(0xFF14283F),
                            ]
                          : [
                              const Color(0xFF0B2545),
                              const Color(0xFF13315C),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt_rounded,
                                    size: 14, color: scheme.onPrimary),
                                const SizedBox(width: 4),
                                Text(
                                  'ADAPTLY',
                                  style: context.textStyles.labelSmall?.copyWith(
                                    color: scheme.onPrimary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              'LIVE',
                              style:
                                  context.textStyles.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  scheme.primary,
                                  scheme.tertiary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: scheme.primary.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Adaptive Recovery',
                                  style: context.textStyles.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'Intelligence Engine',
                                  style: context.textStyles.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Adaptly\'s proprietary decision-support system transforms patient-reported data, clinical context, and caregiver input into personalized recovery milestones, daily guidance, and care-team insights — automatically, after every discharge.',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _EngineChip(
                              icon: Icons.timeline_rounded,
                              label: 'Milestones'),
                          _EngineChip(
                              icon: Icons.tips_and_updates_rounded,
                              label: 'Daily guidance'),
                          _EngineChip(
                              icon: Icons.groups_2_rounded,
                              label: 'Care-team insights'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                        onPressed: () async {
                          final res = await context.push('/plan/${_condition!.id}',
                              extra: _condition!.name);
                          await _load();
                          if (!mounted) return;
                          if (res is Map && (res['changed'] == true)) {
                            final bool saved = res['saved'] == true;
                            if (saved) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Plan updated')));
                              setState(() {
                                _showPlanNotice = false;
                                _planNoticeText = null;
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text(
                                      'Plan generated locally; will sync when permissions are fixed')));
                              setState(() {
                                _showPlanNotice = true;
                                _planNoticeText =
                                    'Plan was generated locally and could not be saved. It will appear here after access is fixed.';
                              });
                            }
                          }
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          elevation: 4,
                          shadowColor: scheme.primary.withValues(alpha: 0.5),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                        label: const Text('Open Plan'),
                      ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: AppSpacing.lg),

          if (_userId != null && _milestones.isEmpty) ...[
            _CreatePlanCard(
              onCreate: () async {
                final res = await context.push('/plan/${_condition!.id}',
                    extra: _condition!.name);
                await _load();
                if (!mounted) return;
                if (res is Map && (res['changed'] == true)) {
                  final bool saved = res['saved'] == true;
                  if (saved) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Plan created')));
                    setState(() {
                      _showPlanNotice = false;
                      _planNoticeText = null;
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Plan generated locally; will sync when permissions are fixed')));
                    setState(() {
                      _showPlanNotice = true;
                      _planNoticeText =
                          'Plan was generated locally and could not be saved. It will appear here after access is fixed.';
                    });
                  }
                }
              },
            ),
            SizedBox(height: AppSpacing.md),
          ],

          // Timeline items
          if (_milestones.isNotEmpty)
            ..._milestones.asMap().entries.map((e) {
              final m = e.value;
              final isLast = e.key == _milestones.length - 1;
              final due = m.dueDate;
              final desc = [
                if (m.description?.isNotEmpty == true) m.description!,
                if (due != null)
                  'Due ${MaterialLocalizations.of(context).formatMediumDate(due)}',
              ].join(' · ');
              return _TimelineCard(
                index: e.key,
                title: m.title,
                description: desc,
                isCompleted: m.completed,
                isLast: isLast,
                onTap: () => _showEducationForStep(context,
                    stepTitle: m.title, stepDescription: m.description),
              );
            })
          else ...[
            _TimelineCard(
              index: 0,
              title: 'Week 1',
              description: _condition!.timeline.week1,
              isCompleted: false,
              isLast: false,
              onTap: () => _showEducationForStep(context,
                  stepTitle: 'Week 1',
                  stepDescription: _condition!.timeline.week1),
            ),
            _TimelineCard(
              index: 1,
              title: 'Month 1',
              description: _condition!.timeline.month1,
              isCompleted: false,
              isLast: false,
              onTap: () => _showEducationForStep(context,
                  stepTitle: 'Month 1',
                  stepDescription: _condition!.timeline.month1),
            ),
            _TimelineCard(
              index: 2,
              title: 'Month 3',
              description: _condition!.timeline.month3,
              isCompleted: false,
              isLast: false,
              onTap: () => _showEducationForStep(context,
                  stepTitle: 'Month 3',
                  stepDescription: _condition!.timeline.month3),
            ),
            _TimelineCard(
              index: 3,
              title: 'Long Term',
              description: _condition!.timeline.longTerm,
              isCompleted: false,
              isLast: true,
              onTap: () => _showEducationForStep(context,
                  stepTitle: 'Long Term',
                  stepDescription: _condition!.timeline.longTerm),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEducationForStep(BuildContext context,
      {required String stepTitle, String? stepDescription}) async {
    final conditionName = _condition?.name;
    final detail = _condition?.userDetail;
    final conditionDetailsSummary =
        (detail != null && (conditionName?.trim().isNotEmpty ?? false) && detail.hasDetails)
            ? detail.toAiSummary(conditionName!)
            : null;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MilestoneEducationPage(
          stepTitle: stepTitle,
          stepDescription: stepDescription,
          conditionName: _condition?.name,
          conditionDetailsSummary: conditionDetailsSummary,
        ),
      ),
    );
  }

  Widget _buildCommunitySection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: AppSpacing.horizontalLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child:
                    Icon(Icons.people_alt_rounded, color: Colors.purple, size: 20),
              ),
              SizedBox(width: AppSpacing.md),
              Text(
                'Community Insights',
                style: context.textStyles.titleLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          if (_posts.isEmpty)
            _EmptyStateCard(
              icon: Icons.forum_outlined,
              title: 'No community posts yet',
              subtitle: 'Be the first to share your experience',
            )
          else
            ..._posts.take(4).map((p) => Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: PostCard(post: p),
                )),
        ],
      ),
    );
  }

  Widget _buildResourcesSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: AppSpacing.horizontalLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.medical_services_rounded,
                    color: Colors.orange, size: 20),
              ),
              SizedBox(width: AppSpacing.md),
              Text(
                'Resources',
                style: context.textStyles.titleLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          if (_resources.isEmpty)
            _EmptyStateCard(
              icon: Icons.location_on_outlined,
              title: 'No resources found',
              subtitle: 'Check back later for nearby resources',
            )
          else
            ..._resources.take(5).map((r) => _ResourceTile(resource: r)),
        ],
      ),
    );
  }
}

// ============================================================================
// REUSABLE COMPONENTS
// ============================================================================

class _CircularProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;
  final Widget? child;

  const _CircularProgressRing({
    required this.progress,
    required this.size,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _RingPainter(
              progress: progress,
              backgroundColor: backgroundColor,
              progressColor: progressColor,
              strokeWidth: strokeWidth,
            ),
          ),
          if (child != null) Center(child: child),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      backgroundColor != oldDelegate.backgroundColor ||
      progressColor != oldDelegate.progressColor;
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onIncrement;
  final VoidCallback onEdit;

  const _GoalCard({required this.goal, required this.onIncrement, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = goal.targetPerPeriod == 0
        ? 0.0
        : (goal.progressThisPeriod / goal.targetPerPeriod).clamp(0, 1).toDouble();
    final isComplete = pct >= 1.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      DarkModeColors.graphite,
                      DarkModeColors.slate,
                    ]
                  : [
                      scheme.surface,
                      scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isComplete
                  ? scheme.tertiary.withValues(alpha: 0.5)
                  : scheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
          _CircularProgressRing(
            progress: pct,
            size: 56,
            strokeWidth: 5,
            backgroundColor: scheme.outline.withValues(alpha: 0.2),
            progressColor: isComplete ? scheme.tertiary : scheme.primary,
            child: Text(
              '${(pct * 100).round()}%',
              style: context.textStyles.labelSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goal.title,
                        style: context.textStyles.titleSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isComplete)
                      Icon(Icons.check_circle, color: scheme.tertiary, size: 20),
                  ],
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  '${goal.progressThisPeriod}/${goal.targetPerPeriod} this week',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Material(
            color: scheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: InkWell(
              onTap: onIncrement,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Icon(Icons.add_rounded, color: scheme.primary, size: 24),
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final GoalBadge badge;
  final VoidCallback onTap;
  final IconData Function(String) iconBuilder;

  const _SuggestionChip({
    required this.badge,
    required this.onTap,
    required this.iconBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      scheme.primary.withValues(alpha: 0.15),
                      scheme.primary.withValues(alpha: 0.05),
                    ]
                  : [
                      scheme.primary.withValues(alpha: 0.1),
                      scheme.primary.withValues(alpha: 0.05),
                    ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconBuilder(badge.iconName), size: 18, color: scheme.primary),
              SizedBox(width: AppSpacing.sm),
              Text(
                badge.title,
                style: context.textStyles.labelLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final int index;
  final String title;
  final String description;
  final bool isCompleted;
  final bool isLast;
  final VoidCallback? onTap;

  const _TimelineCard({
    required this.index,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.isLast,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: isCompleted
                      ? LinearGradient(
                          colors: [scheme.tertiary, scheme.tertiary.withValues(alpha: 0.7)],
                        )
                      : LinearGradient(
                          colors: [
                            scheme.primary.withValues(alpha: 0.2),
                            scheme.primary.withValues(alpha: 0.1),
                          ],
                        ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted
                        ? scheme.tertiary
                        : scheme.primary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, color: Colors.white, size: 20)
                      : Text(
                          '${index + 1}',
                          style: context.textStyles.titleSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          scheme.primary.withValues(alpha: 0.4),
                          scheme.primary.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: AppSpacing.md),
          // Content card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.lg),
              child: Material(
                color: isDark
                    ? DarkModeColors.graphite.withValues(alpha: 0.5)
                    : scheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: scheme.outline.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: context.textStyles.titleSmall?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          description,
                          style: context.textStyles.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EngineChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EngineChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.textStyles.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePlanCard extends StatelessWidget {
  final VoidCallback onCreate;

  const _CreatePlanCard({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  scheme.primary.withValues(alpha: 0.15),
                  DarkModeColors.graphite,
                ]
              : [
                  scheme.primaryContainer,
                  scheme.surface,
                ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.auto_awesome, color: scheme.primary, size: 24),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No plan yet',
                      style: context.textStyles.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Create a personalized journey',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: Icon(Icons.add, color: scheme.onPrimary),
              label: const Text('Create My Plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: scheme.onSurface.withValues(alpha: 0.3)),
          SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: context.textStyles.titleSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: context.textStyles.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final Resource resource;

  const _ResourceTile({required this.resource});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: isDark
            ? DarkModeColors.graphite.withValues(alpha: 0.5)
            : scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.place, color: Colors.orange, size: 20),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.name,
                        style: context.textStyles.titleSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${resource.location} · ${resource.distance.toStringAsFixed(1)} mi',
                        style: context.textStyles.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
