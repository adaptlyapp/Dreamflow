import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/models/goal.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/services/milestone_service.dart';
import 'package:wellspring/services/goal_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/glass_card.dart';

class ConditionsScreen extends StatefulWidget {
  const ConditionsScreen({super.key});

  @override
  State<ConditionsScreen> createState() => _ConditionsScreenState();
}

class _ConditionsScreenState extends State<ConditionsScreen>
    with AutomaticKeepAliveClientMixin {
  final _conditionService = ConditionService();
  final _milestoneService = MilestoneService();
  final _goalService = GoalService();

  List<Condition> _userConditions = [];
  Map<String, List<Milestone>> _milestonesByCondition = {};
  Map<String, List<Goal>> _goalsByCondition = {};
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.currentUser?.id;

      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final allConditions = await _conditionService.getAllConditions();
      final userConditionIds = userProvider.currentUser?.conditions ?? [];

      final myConditions =
          allConditions.where((c) => userConditionIds.contains(c.id)).toList();

      final milestonesByCondition = <String, List<Milestone>>{};
      final goalsByCondition = <String, List<Goal>>{};

      for (final condition in myConditions) {
        final milestones = await _milestoneService.list(
          userId: userId,
          conditionId: condition.id,
        );

        if (milestones.isNotEmpty) {
          milestonesByCondition[condition.id] = milestones;
        }

        final goals = await _goalService.getActiveGoals(userId);
        if (goals.isNotEmpty) {
          goalsByCondition[condition.id] = goals;
        }
      }

      if (!mounted) return;
      setState(() {
        _userId = userId;
        _userConditions = myConditions;
        _milestonesByCondition = milestonesByCondition;
        _goalsByCondition = goalsByCondition;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed loading conditions: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/ChatGPT_Image_Aug_3_2026_07_26_30_AM.png',
              fit: BoxFit.cover,
            ),
          ),
          RefreshIndicator.adaptive(
            onRefresh: _loadData,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'My hubs',
                                style: context.textStyles.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1ED3CF).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF1ED3CF).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  '${_userConditions.length}',
                                  style: context.textStyles.labelMedium?.copyWith(
                                    color: const Color(0xFF1ED3CF),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            'Tap a condition to open your plan and timeline.',
                            style: context.textStyles.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CenteredLoadingSkeleton()),
                  )
                else if (_userConditions.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    sliver: SliverList.separated(
                      itemCount: _userConditions.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) {
                        final condition = _userConditions[i];
                        final milestones =
                            _milestonesByCondition[condition.id] ?? [];
                        final goals = _goalsByCondition[condition.id] ?? [];

                        return _ConditionCard(
                          condition: condition,
                          milestones: milestones,
                          goals: goals,
                          onTap: () =>
                              context.push('/plan/${condition.id}', extra: condition.name),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1ED3CF).withValues(alpha: 0.3),
                    const Color(0xFF1E88FF).withValues(alpha: 0.3),
                  ],
                ),
              ),
              child: const Icon(
                Icons.explore,
                size: 50,
                color: Color(0xFF1ED3CF),
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            Text(
              'No Conditions',
              style: context.textStyles.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Visit Settings to add conditions and start tracking\nyour recovery with milestones and goals.',
              style: context.textStyles.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionCard extends StatelessWidget {
  final Condition condition;
  final List<Milestone> milestones;
  final List<Goal> goals;
  final VoidCallback onTap;

  const _ConditionCard({
    required this.condition,
    required this.milestones,
    required this.goals,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPlan = milestones.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0xFF143542).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E88FF), Color(0xFF1ED3CF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        condition.name,
                        style: context.textStyles.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasPlan) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Stage: Long-term Optimization',
                          style: context.textStyles.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ],
            ),
            if (hasPlan) ...[
              SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2A3D).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Color(0xFFFFA726), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Keep steady progress with small, consistent steps.',
                        style: context.textStyles.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TagChip(icon: Icons.bedtime, label: 'Sleep'),
                  _TagChip(icon: Icons.bolt, label: 'Energy'),
                  _TagChip(icon: Icons.directions_walk, label: 'Movement'),
                ],
              ),
            ] else ...[
              SizedBox(height: AppSpacing.md),
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2A3D).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  'No plan yet. Tap to view details and add milestones.',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TagChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2A3D).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
