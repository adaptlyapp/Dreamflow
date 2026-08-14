import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/models/goal.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/services/milestone_service.dart';
import 'package:wellspring/services/goal_service.dart';

/// ARIE Milestone Builder - Create comprehensive recovery milestones
class ArieJourneyCreatorScreen extends StatefulWidget {
  const ArieJourneyCreatorScreen({super.key});

  @override
  State<ArieJourneyCreatorScreen> createState() => _ArieJourneyCreatorScreenState();
}

class _ArieJourneyCreatorScreenState extends State<ArieJourneyCreatorScreen> {
  final _conditionService = ConditionService();
  final _milestoneService = MilestoneService();
  final _goalService = GoalService();
  static const _uuid = Uuid();
  
  List<Condition> _savedConditions = [];
  Condition? _selectedCondition;
  final _goalController = TextEditingController();
  bool _isLoading = false;
  
  // Goals dashboard state
  List<Milestone> _milestones = [];
  List<Goal> _goals = [];
  bool _hasCreatedGoals = false;

  @override
  void initState() {
    super.initState();
    _loadSavedConditions();
    // Don't auto-load journeys - only show after user creates one
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConditions() async {
    try {
      final userProvider = context.read<UserProvider>();
      final currentUser = userProvider.currentUser;
      
      if (currentUser == null || currentUser.conditions.isEmpty) {
        if (mounted) {
          setState(() => _savedConditions = []);
        }
        return;
      }

      final allConditions = await _conditionService.getAllConditions();
      // Filter to only show user's saved conditions
      final userConditions = allConditions
          .where((c) => currentUser.conditions.contains(c.id))
          .toList();
      
      if (mounted) {
        setState(() => _savedConditions = userConditions);
      }
    } catch (e) {
      debugPrint('Error loading conditions: $e');
    }
  }
  
  Future<void> _loadGoalsData() async {
    setState(() => _isLoading = true);
    try {
      final userProvider = context.read<UserProvider>();
      final currentUser = userProvider.currentUser;
      
      if (currentUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final milestones = await _milestoneService.list(userId: currentUser.id);
      final goals = await _goalService.list(userId: currentUser.id);
      
      if (mounted) {
        setState(() {
          _milestones = milestones;
          _goals = goals;
          _hasCreatedGoals = milestones.isNotEmpty || goals.isNotEmpty;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading goals data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateMilestone() async {
    if (_selectedCondition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a condition')),
      );
      return;
    }
    if (_goalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter what you wish to achieve')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final userProvider = context.read<UserProvider>();
      final currentUser = userProvider.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not found');
      }

      final goalText = _goalController.text.trim();
      final now = DateTime.now();

      // Create a milestone for this goal
      final milestone = Milestone(
        id: _uuid.v4(),
        userId: currentUser.id,
        conditionId: _selectedCondition!.id,
        title: goalText,
        description: 'Created with ARIE for ${_selectedCondition!.name}',
        dueDate: now.add(const Duration(days: 30)), // 30 days from now
        completed: false,
        order: _milestones.length,
        createdAt: now,
        updatedAt: now,
      );

      await _milestoneService.upsert(milestone);

      // Create associated goals (example: weekly targets)
      final goal = Goal(
        id: _uuid.v4(),
        userId: currentUser.id,
        title: goalText,
        description: 'Track progress for: $goalText',
        targetPerPeriod: 4, // 4 times per week
        progressThisPeriod: 0,
        period: 'weekly',
        active: true,
        createdAt: now,
        updatedAt: now,
      );

      await _goalService.upsert(goal);

      // Reload goals data to show in dashboard
      await _loadGoalsData();
      
      // Clear form
      setState(() {
        _selectedCondition = null;
        _goalController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Your milestone and goal have been created!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating milestone: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create milestone: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F2E),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/b0380405-152d-4717-8856-bf48d924b809.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0A1F2E), Color(0xFF0D2A3D)],
                  ),
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasCreatedGoals
                    ? _buildGoalsDashboard()
                    : _buildMilestoneBuilder(),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneBuilder() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E88FF), Color(0xFF1ED3CF)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1ED3CF).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask ARIE',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Build personalized recovery milestones',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // Condition Selector
        Text(
          'Which condition?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF143542).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF1ED3CF).withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Condition>(
              value: _selectedCondition,
              hint: Text(
                _savedConditions.isEmpty 
                    ? 'No saved conditions' 
                    : 'Select from your saved conditions',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
              isExpanded: true,
              dropdownColor: const Color(0xFF143542),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1ED3CF)),
              items: _savedConditions.map((condition) {
                return DropdownMenuItem<Condition>(
                  value: condition,
                  child: Text(condition.name),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedCondition = value),
            ),
          ),
        ),
        
        const SizedBox(height: 28),
        
        // Goal Input
        Text(
          'What do you wish to achieve?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _goalController,
          maxLines: 5,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Describe your recovery goal in detail...\n\nExample: "I want to regain independence in daily activities, improve my mobility, and return to work within 6 months."',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              height: 1.5,
            ),
            filled: true,
            fillColor: const Color(0xFF143542).withValues(alpha: 0.9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: const Color(0xFF1ED3CF).withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: const Color(0xFF1ED3CF).withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF1ED3CF), width: 2),
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Info card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E88FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF1E88FF).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF1ED3CF), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ARIE will create a comprehensive milestone with goals, resources, educational content, and personalized recommendations.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Generate Button
        SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: _generateMilestone,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E88FF), Color(0xFF1ED3CF)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1ED3CF).withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Build My Milestone',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 100),
      ],
    ),
  );

  Widget _buildGoalsDashboard() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Text(
          'Goals',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Track what matters most',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Ask ARIE Button
        _buildAskArieButton(),
        
        const SizedBox(height: 32),
        
        // Your Current Goals Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Current Goals',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  onPressed: () {
                    // TODO: Show filter options
                  },
                ),
                Text(
                  'Sort: Recent',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Milestones List
        ..._milestones.map((milestone) => _buildMilestoneCard(milestone)),
        
        const SizedBox(height: 100),
      ],
    ),
  );

  Widget _buildAskArieButton() => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1E88FF), Color(0xFF1ED3CF)],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1ED3CF).withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _hasCreatedGoals = false);
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask ARIE',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Create a New Goal',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Build your personalized recovery path.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Which condition?',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tell ARIE your top priorities.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_circle, color: Colors.white, size: 32),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildMilestoneCard(Milestone milestone) {
    final progress = milestone.completed ? 100 : 0;
    final color = milestone.completed ? const Color(0xFF4CAF50) : const Color(0xFF1ED3CF);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF143542).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            debugPrint('Tapped milestone: ${milestone.title}');
            // Navigate to milestone detail if needed
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    milestone.completed ? Icons.check_circle : Icons.track_changes,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        milestone.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        milestone.description ?? 'Recovery milestone',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (milestone.dueDate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDueDate(milestone.dueDate!),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        milestone.completed ? 'Completed' : 'In Progress',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff < 7) return 'Due in $diff days';
    if (diff < 30) return 'Due in ${(diff / 7).ceil()} weeks';
    return 'Due in ${(diff / 30).ceil()} months';
  }

}
