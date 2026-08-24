import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/models/plan_timeline.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/plan_timeline_service.dart';
import 'package:wellspring/theme.dart';

const Color _accentColor = Color(0xFF20B2AA);

class YourPlanScreen extends StatefulWidget {
  const YourPlanScreen({super.key});

  @override
  State<YourPlanScreen> createState() => _YourPlanScreenState();
}

class _YourPlanScreenState extends State<YourPlanScreen> {
  final _service = PlanTimelineService();
  bool _loading = true;
  List<PlanTimeline> _plans = [];
  PlanTimeline? _selectedPlan;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final userProvider = context.read<UserProvider>();
      final userId = userProvider.currentUser?.id;
      
      if (userId == null) {
        setState(() {
          _error = 'User not found';
          _loading = false;
        });
        return;
      }

      final plans = await _service.getTimelinesForUser(userId);
      debugPrint('[YourPlan] Loaded ${plans.length} plans');
      
      setState(() {
        _plans = plans;
        // Select current plan or first one
        _selectedPlan = plans.firstWhere(
          (p) => p.isCurrent,
          orElse: () => plans.isNotEmpty ? plans.first : null as PlanTimeline,
        );
        _loading = false;
      });
    } catch (e) {
      debugPrint('[YourPlan] Error loading plans: $e');
      setState(() {
        _error = 'Failed to load plans';
        _loading = false;
      });
    }
  }

  Future<void> _createNewPlan() async {
    // Navigate to journey creator to create a new plan
    if (mounted) {
      context.push('/arie-journey-creator');
    }
  }

  Future<void> _editPlan(PlanTimeline plan) async {
    if (mounted) {
      context.push('/plan/${plan.conditionId}', extra: {
        'conditionName': plan.name,
      });
    }
  }

  void _selectPlan(PlanTimeline plan) {
    setState(() {
      _selectedPlan = plan;
    });
  }

  int _getCompletedMilestones(List<Milestone> milestones) {
    return milestones.where((m) => m.completed).length;
  }

  int _getRemainingMilestones(List<Milestone> milestones) {
    return milestones.where((m) => !m.completed).length;
  }

  double _getProgressPercentage(List<Milestone> milestones) {
    if (milestones.isEmpty) return 0;
    return (_getCompletedMilestones(milestones) / milestones.length) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return GlassyScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        centerTitle: true,
        title: Text(
          'A.R.I.E',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _accentColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: _accentColor,
                ),
              )
            : _error != null
                ? Center(
                    child: Text(_error!),
                  )
                : _plans.isEmpty
                    ? _buildEmptyState(context)
                    : _buildContent(context),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Plans Yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first plan to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createNewPlan,
            icon: const Icon(Icons.add),
            label: const Text('Create a Plan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Plan',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your own milestones, goals, and progress',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (_selectedPlan != null) ...[
            _buildProgressOverview(context),
            const SizedBox(height: 24),
            _buildAriePlanSection(context),
          ],
          const SizedBox(height: 24),
          if (_plans.length > 1) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'All Plans',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildPlansList(context),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: _createNewPlan,
              icon: const Icon(Icons.add),
              label: const Text('Create New Plan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProgressOverview(BuildContext context) {
    if (_selectedPlan == null) return const SizedBox();
    
    final completed = _getCompletedMilestones(_selectedPlan!.milestones);
    final remaining = _getRemainingMilestones(_selectedPlan!.milestones);
    final percentage = _getProgressPercentage(_selectedPlan!.milestones);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Overview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(context, completed.toString(), 'Completed'),
                _buildStatCard(context, remaining.toString(), 'Remaining', bgColor: Colors.grey[800]),
                _buildStatCard(context, '0', 'Active Goals'),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(_accentColor),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${percentage.toStringAsFixed(0)}% Complete',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label, {Color? bgColor}) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: bgColor ?? const Color(0xFF1a3a3a),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAriePlanSection(BuildContext context) {
    if (_selectedPlan == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'A.R.I.E',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.auto_awesome),
                      color: _accentColor,
                      onPressed: () => _editPlan(_selectedPlan!),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      color: _accentColor,
                      onPressed: () => _editPlan(_selectedPlan!),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedPlan!.milestones.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No milestones yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
            else
              Column(
                children: _selectedPlan!.milestones.map((milestone) {
                  final isCompleted = milestone.completed;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isCompleted ? _accentColor : Colors.transparent,
                            border: Border.all(
                              color: isCompleted ? _accentColor : Colors.grey[400]!,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: isCompleted
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                milestone.title,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                                  color: isCompleted ? Colors.grey[600] : null,
                                ),
                              ),
                              if (milestone.description != null && milestone.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    milestone.description!,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('Edit'),
                              onTap: () => _editPlan(_selectedPlan!),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlansList(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        final plan = _plans[index];
        final isSelected = _selectedPlan?.id == plan.id;
        final completed = _getCompletedMilestones(plan.milestones);
        final total = plan.milestones.length;

        return GestureDetector(
          onTap: () => _selectPlan(plan),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? _accentColor.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _accentColor : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$completed/$total',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created ${DateFormat('MMM d, yyyy').format(plan.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (plan.isCurrent)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Current',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
