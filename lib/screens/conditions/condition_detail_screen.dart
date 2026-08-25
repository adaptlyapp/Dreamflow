import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/models/goal.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/services/milestone_service.dart';
import 'package:wellspring/services/goal_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/skeletons.dart';

class ConditionDetailScreen extends StatefulWidget {
  final String conditionId;

  const ConditionDetailScreen({super.key, required this.conditionId});

  @override
  State<ConditionDetailScreen> createState() => _ConditionDetailScreenState();
}

class _ConditionDetailScreenState extends State<ConditionDetailScreen> {
  final _conditionService = ConditionService();
  final _milestoneService = MilestoneService();
  final _goalService = GoalService();

  Condition? _condition;
  List<Milestone> _milestones = [];
  List<Goal> _goals = [];
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

      final condition = await _conditionService.getConditionById(widget.conditionId);
      
      if (condition == null) {
        setState(() => _isLoading = false);
        return;
      }

      final milestones = await _milestoneService.list(
        userId: userId,
        conditionId: widget.conditionId,
      );

      final goals = await _goalService.getActiveGoals(userId);

      if (mounted) {
        setState(() {
          _condition = condition;
          _milestones = milestones;
          _goals = goals;
          _userId = userId;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading condition detail: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleMilestoneComplete(Milestone milestone) async {
    if (_userId == null) return;
    
    try {
      await _milestoneService.updateFields(
        _userId!,
        milestone.id,
        {'completed': !milestone.completed},
      );
      await _loadData();
    } catch (e) {
      debugPrint('Error toggling milestone: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating milestone: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          forceMaterialTransparency: true,
        ),
        body: const Center(child: CenteredLoadingSkeleton()),
      );
    }

    if (_condition == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          forceMaterialTransparency: true,
        ),
        body: const Center(child: Text('Condition not found')),
      );
    }

    final hasPlan = _milestones.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/b0380405-152d-4717-8856-bf48d924b809.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0A1F2E),
                      Color(0xFF0D2A3D),
                      Color(0xFF0A1F2E),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Important: let SliverAppBar handle the top safe-area.
          // Wrapping the whole scroll view in SafeArea can cause inconsistent
          // results across iOS devices because SliverAppBar is also "primary"
          // by default (it applies status-bar padding).
          CustomScrollView(
            slivers: [
              _buildHeader(),
              if (hasPlan) ...[
                _buildTimelineCard(),
                _buildMilestonesSection(),
                _buildGoalsSection(),
              ] else
                _buildEmptyState(),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'Plan • ${_condition?.name ?? 'Plan'}',
        style: context.textStyles.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.ios_share, color: Color(0xFF1ED3CF), size: 22),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.auto_awesome, color: Color(0xFF1ED3CF), size: 22),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.check_circle_outline, color: Color(0xFF1ED3CF), size: 22),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildTimelineCard() {
    final totalCount = _milestones.length;
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: const Color(0xFF143542).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: const Color(0xFF1ED3CF).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1ED3CF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.layers,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From Adaptly',
                            style: context.textStyles.labelSmall?.copyWith(
                              color: const Color(0xFF1ED3CF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _condition!.name,
                            style: context.textStyles.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '$totalCount steps',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.swap_horiz,
                    color: Color(0xFF1ED3CF),
                    size: 18,
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    'Switch',
                    style: context.textStyles.labelMedium?.copyWith(
                      color: const Color(0xFF1ED3CF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1ED3CF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestonesSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your plan',
                  style: context.textStyles.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    // Show all
                  },
                  icon: const Icon(Icons.unfold_more, size: 18),
                  label: const Text('Show all'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1ED3CF),
                    side: BorderSide(color: const Color(0xFF1ED3CF).withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Future steps are collapsed',
              style: context.textStyles.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            for (int i = 0; i < _milestones.length; i++)
              _MilestoneItem(
                milestone: _milestones[i],
                index: i + 1,
                onToggle: () => _toggleMilestoneComplete(_milestones[i]),
                isLast: i == _milestones.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsSection() {
    if (_goals.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88FF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.star_outline,
                        color: Color(0xFF1E88FF),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Text(
                      'Active Goals',
                      style: context.textStyles.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    // View all goals
                  },
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('View All'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1E88FF),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Stay on track with your daily and weekly goals',
              style: context.textStyles.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            ...(_goals.map((goal) => Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: _GoalCard(goal: goal),
            ))),
          ],
        ),
      ),
    );
  }


  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1E88FF).withValues(alpha: 0.3),
                      const Color(0xFF1ED3CF).withValues(alpha: 0.3),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.route_outlined,
                  size: 70,
                  color: Color(0xFF1ED3CF),
                ),
              ),
              SizedBox(height: AppSpacing.xl),
              Text(
                'Start Your Recovery Journey',
                style: context.textStyles.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'Create personalized milestones and track your progress through each stage of recovery.',
                style: context.textStyles.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.xl),
              Container(
                padding: EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: const Color(0xFF143542).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: const Color(0xFF1ED3CF).withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    _EmptyStateFeature(
                      icon: Icons.track_changes,
                      title: 'Set Milestones',
                      description: 'Break down your recovery into achievable steps',
                    ),
                    SizedBox(height: AppSpacing.md),
                    _EmptyStateFeature(
                      icon: Icons.star_outline,
                      title: 'Track Progress',
                      description: 'Monitor your journey with daily goals',
                    ),
                    SizedBox(height: AppSpacing.md),
                    _EmptyStateFeature(
                      icon: Icons.celebration_outlined,
                      title: 'Celebrate Wins',
                      description: 'Mark milestones complete and see your progress',
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to create milestone/goal
                },
                icon: const Icon(Icons.add_road),
                label: const Text('Create My Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1ED3CF),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStateFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _EmptyStateFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: const Color(0xFF1ED3CF).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF1ED3CF),
            size: 24,
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: context.textStyles.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MilestoneItem extends StatelessWidget {
  final Milestone milestone;
  final int index;
  final VoidCallback onToggle;
  final bool isLast;

  const _MilestoneItem({
    required this.milestone,
    required this.index,
    required this.onToggle,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: milestone.completed
                    ? const Color(0xFF1ED3CF)
                    : const Color(0xFF143542),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: milestone.completed
                      ? const Color(0xFF1ED3CF)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Center(
                child: milestone.completed
                    ? const Icon(Icons.check, color: Colors.white, size: 28)
                    : Text(
                        '$index',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xFF143542).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          milestone.title,
                          style: context.textStyles.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.drag_indicator),
                        color: Colors.white.withValues(alpha: 0.3),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  if (milestone.description != null) ...[
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      milestone.description!,
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (milestone.dueDate != null) ...[
                    SizedBox(height: AppSpacing.md),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1ED3CF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Color(0xFF1ED3CF),
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            _formatDate(milestone.dueDate!),
                            style: context.textStyles.labelMedium?.copyWith(
                              color: const Color(0xFF1ED3CF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.school, size: 16),
                          label: const Text('Learn'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1ED3CF),
                            side: BorderSide(
                              color: const Color(0xFF1ED3CF).withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reroll'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1ED3CF),
                            side: BorderSide(
                              color: const Color(0xFF1ED3CF).withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1ED3CF),
                            side: BorderSide(
                              color: const Color(0xFF1ED3CF).withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.withValues(alpha: 0.8),
                            side: BorderSide(
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final progress = goal.targetPerPeriod > 0
        ? (goal.progressThisPeriod / goal.targetPerPeriod).clamp(0.0, 1.0)
        : 0.0;
    final isCompleted = progress >= 1.0;

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF143542).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF1E88FF).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.15),
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
                  color: isCompleted
                      ? const Color(0xFF1E88FF).withValues(alpha: 0.3)
                      : const Color(0xFF1E88FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle : Icons.track_changes,
                  color: const Color(0xFF1E88FF),
                  size: 22,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  goal.title,
                  style: context.textStyles.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${goal.progressThisPeriod}/${goal.targetPerPeriod}',
                  style: context.textStyles.titleSmall?.copyWith(
                    color: const Color(0xFF1E88FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (goal.description != null) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              goal.description!,
              style: context.textStyles.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFF0D2A3D),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted
                          ? const Color(0xFF1E88FF)
                          : const Color(0xFF1E88FF).withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                '${(progress * 100).toInt()}%',
                style: context.textStyles.labelLarge?.copyWith(
                  color: const Color(0xFF1E88FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
