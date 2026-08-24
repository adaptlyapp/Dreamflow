import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/services/recovery_blueprint_service.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/plan_timeline_service.dart';
import 'package:wellspring/models/recovery_blueprint.dart';
import 'package:wellspring/models/user.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/models/plan_timeline.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/screens/recovery/recovery_blueprint_dashboard.dart';
import 'package:wellspring/screens/goals/milestone_education_page.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/openai/openai_config.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wellspring/widgets/help_type_chip.dart';
import 'package:uuid/uuid.dart';

/// Family member's own journey page - completely separate from patient journey
class FamilyMemberJourneyScreen extends StatefulWidget {
  const FamilyMemberJourneyScreen({super.key});

  @override
  State<FamilyMemberJourneyScreen> createState() =>
      _FamilyMemberJourneyScreenState();
}

class _FamilyMemberJourneyScreenState extends State<FamilyMemberJourneyScreen> {
  final _userService = UserService();
  final _blueprintService = RecoveryBlueprintService();
  bool _isLoading = true;
  bool _generating = false;
  Map<String, dynamic>? _journeyData;
  RecoveryBlueprint? _blueprint;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = await _userService.getCurrentUser();
      final authUserId = SupabaseConfig.client.auth.currentUser?.id;

      if (user == null || authUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch the family member's OWN milestones and goals (not the patient's)
      // Use profile_id to distinguish between patient and family member profiles
      final milestonesData = await SupabaseConfig.client
          .from('milestones')
          .select()
          .eq('profile_id', user.id)
          .order('created_at', ascending: true);

      final goalsData = await SupabaseConfig.client
          .from('goals')
          .select()
          .eq('profile_id', user.id)
          .order('created_at', ascending: true);

      final blueprint = await _blueprintService.getByUserId(user.id);

      setState(() {
        _journeyData = {
          'milestones': milestonesData,
          'goals': goalsData,
        };
        _blueprint = blueprint;
        _userId = user.id; // Store profile ID for inserts
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[FamilyMemberJourney] Error loading journey data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If no journey data, show empty state
    if (_journeyData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Journey'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_outlined, size: 64, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                const Text('Start Your Journey',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  'Create your own recovery milestones and goals to track your progress.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _showAddMilestoneDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Your First Milestone'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final milestones = (_journeyData?['milestones'] as List?) ?? [];
    final completedCount =
        milestones.where((m) => m['completed'] == true).length;
    final totalCount = milestones.length;
    final goals = ((_journeyData?['goals'] as List?) ?? [])
        .where((g) => g['active'] == true)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'A.R.I.E',
          style: Theme.of(context)
              .textTheme
              .headlineLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Your Plan',
              style: context.textStyles.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Track your own milestones, goals, and progress',
              style:
                  context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Recovery Blueprint (only show if family member has created their own)
            if (_blueprint != null) ...[
              _BlueprintCard(
                blueprint: _blueprint!,
                onView: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          RecoveryBlueprintDashboard(patientId: _userId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Stats Overview
            _StatsCard(
              completedCount: completedCount,
              totalCount: totalCount,
              activeGoalsCount: goals.length,
            ),
            const SizedBox(height: 16),

            // Milestones
            _MilestonesCard(
              milestones: milestones,
              userId: _userId,
              onAdd: () => _showAddMilestoneDialog(),
              onGenerateAI: () => _generateMilestonesWithAI(),
              onSavePlan: () => _showSavePlanDialog(milestones),
              onRefresh: _loadData,
            ),
            const SizedBox(height: 16),

            // Goals
            _GoalsCard(
              goals: goals,
              userId: _userId,
              onAdd: () => _showAddGoalDialog(),
              onRefresh: _loadData,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showSavePlanDialog(List<dynamic> milestones) async {
    if (milestones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add milestones before saving a plan')),
      );
      return;
    }

    final planNameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save as Plan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Give your recovery plan a name:'),
              const SizedBox(height: 16),
              TextField(
                controller: planNameController,
                decoration: const InputDecoration(
                  labelText: 'Plan Name',
                  border: OutlineInputBorder(),
                  hintText: 'E.g., Bed Wounds Recovery Plan',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This saves ${milestones.length} milestone${milestones.length != 1 ? 's' : ''} as a new plan without affecting existing milestones.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (planNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a plan name')),
                );
                return;
              }

              try {
                Navigator.pop(dialogContext);
                final planName = planNameController.text.trim();
                final authUserId = SupabaseConfig.client.auth.currentUser?.id;

                if (authUserId == null || _userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User not found')),
                  );
                  return;
                }

                // Generate a unique condition ID for this plan
                const uuid = Uuid();
                final conditionId = uuid.v4();

                // Convert raw milestones to Milestone objects
                final milestonesToSave = milestones.map((m) {
                  DateTime? parseDate(dynamic value) {
                    if (value is DateTime) return value;
                    if (value is String) {
                      final parsed = DateTime.tryParse(value);
                      if (parsed != null) return parsed;
                    }
                    return null;
                  }

                  return Milestone(
                    id: m['id'] ?? const Uuid().v4(),
                    userId: authUserId,
                    title: m['title'] ?? 'Milestone',
                    description: m['description'],
                    dueDate: parseDate(m['due_date']),
                    completed: m['completed'] == true,
                    order: milestones.indexOf(m),
                    helpType: m['help_type'] ?? m['helpType'],
                    createdAt: parseDate(m['created_at']) ?? DateTime.now(),
                    updatedAt: parseDate(m['updated_at']) ?? DateTime.now(),
                    conditionId: conditionId,
                  );
                }).toList();

                // Create plan timeline
                final plan = PlanTimeline(
                  id: const Uuid().v4(),
                  userId: authUserId,
                  conditionId: conditionId,
                  name: planName,
                  isCurrent: false,
                  milestones: milestonesToSave,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                // Save to Supabase using the service
                final planService = PlanTimelineService();
                await planService.createFromMilestones(
                  userId: authUserId,
                  conditionId: conditionId,
                  name: planName,
                  milestones: milestonesToSave,
                  conditionName: planName,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Plan "$planName" saved successfully!')),
                  );
                }
              } catch (e) {
                debugPrint('[FamilyMemberJourney] Error saving plan: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving plan: $e')),
                  );
                }
              }
            },
            child: const Text('Save Plan'),
          ),
        ],
      ),
    );
  }

  void _showAddMilestoneDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? targetDate;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Recovery Milestone'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Milestone Title',
                    border: OutlineInputBorder(),
                    hintText: 'E.g., Walk 10 minutes daily',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    targetDate == null
                        ? 'Set Target Date'
                        : 'Target: ${targetDate!.month}/${targetDate!.day}/${targetDate!.year}',
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => targetDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a milestone title')),
                  );
                  return;
                }
                if (_userId == null) return;

                try {
                  final authUserId = SupabaseConfig.client.auth.currentUser?.id;
                  await SupabaseConfig.client.from('milestones').insert({
                    'user_id': authUserId,
                    'profile_id': _userId,
                    'title': titleController.text.trim(),
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    'due_date': targetDate?.toIso8601String(),
                    'completed': false,
                    'created_at': DateTime.now().toIso8601String(),
                  });

                  Navigator.pop(dialogContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('✅ Milestone added successfully!')),
                    );
                    _loadData();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding milestone: $e')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog() {
    final titleController = TextEditingController();
    final targetController = TextEditingController(text: '10');
    String frequency = 'daily';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Recovery Goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Goal Title',
                    border: OutlineInputBorder(),
                    hintText: 'E.g., Physical Therapy Exercises',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: targetController,
                  decoration: const InputDecoration(
                    labelText: 'Target (per period)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => frequency = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a goal title')),
                  );
                  return;
                }
                if (_userId == null) return;

                try {
                  final authUserId = SupabaseConfig.client.auth.currentUser?.id;
                  final target = int.tryParse(targetController.text) ?? 10;
                  await SupabaseConfig.client.from('goals').insert({
                    'user_id': authUserId,
                    'profile_id': _userId,
                    'title': titleController.text.trim(),
                    'target_per_period': target,
                    'frequency': frequency,
                    'progress_this_period': 0,
                    'active': true,
                    'created_at': DateTime.now().toIso8601String(),
                  });

                  Navigator.pop(dialogContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('✅ Goal added successfully!')),
                    );
                    _loadData();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding goal: $e')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateMilestonesWithAI() async {
    // Load connected patient info to provide context to AI
    User? connectedPatient;
    String? patientConditions;
    try {
      final currentUser = await _userService.getCurrentUser();
      if (currentUser != null) {
        final familyService = FamilyService();
        final connection = await familyService.getPrimaryConnection(currentUser.id);
        if (connection != null) {
          connectedPatient = await _userService.getUserById(connection.patientId);
          if (connectedPatient != null && connectedPatient.conditions.isNotEmpty) {
            patientConditions = connectedPatient.conditions.join(', ');
          }
        }
      }
    } catch (e) {
      debugPrint('[FamilyMemberJourney] Error loading patient data: $e');
    }

    final descCtrl = TextEditingController();
    int count = 5;
    String durationUnit = 'weeks';
    final durationCtrl = TextEditingController(text: '8');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          int durationValue() {
            final v = int.tryParse(durationCtrl.text.trim());
            if (v == null) return durationUnit == 'days' ? 30 : 8;
            if (durationUnit == 'days') return v.clamp(1, 365);
            return v.clamp(1, 104);
          }

          int durationDays() {
            final value = durationValue();
            return durationUnit == 'days' ? value : (value * 7);
          }

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Generate Recovery Plan with AI',
                      style: ctx.textStyles.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (connectedPatient != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'A.R.I.E will consider ${connectedPatient.name}\'s condition${patientConditions != null ? ' ($patientConditions)' : ''} when creating your plan',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Describe your recovery goals',
                      hintText:
                          'e.g., Support patient care while maintaining my own wellbeing',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: durationUnit,
                        items: const [
                          DropdownMenuItem(
                              value: 'weeks', child: Text('Weeks')),
                          DropdownMenuItem(value: 'days', child: Text('Days')),
                        ],
                        onChanged: (v) {
                          final next = v ?? 'weeks';
                          setLocal(() {
                            durationUnit = next;
                            durationCtrl.text = next == 'days' ? '30' : '8';
                          });
                        },
                        decoration: const InputDecoration(
                            labelText: 'Duration unit',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: durationCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          labelText: durationUnit == 'days'
                              ? 'Duration (days)'
                              : 'Duration (weeks)',
                          helperText:
                              durationUnit == 'days' ? '1–365' : '1–104',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocal(() {}),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: count,
                    items: [3, 4, 5, 6, 7, 8]
                        .map((c) => DropdownMenuItem(
                            value: c, child: Text('$c milestones')))
                        .toList(),
                    onChanged: (v) => setLocal(() => count = v ?? 5),
                    decoration: const InputDecoration(
                        labelText: 'Number of milestones',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _generating
                          ? null
                          : () async {
                              if (descCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Please describe your recovery goals')),
                                );
                                return;
                              }
                              try {
                                setLocal(() => _generating = true);
                              } catch (_) {
                                if (mounted) setState(() => _generating = true);
                              }
                              try {
                                final description = descCtrl.text.trim();
                                final dDays = durationDays();
                                List<Map<String, dynamic>> plan;

                                try {
                                  final ai = OpenAIClient();
                                  
                                  // Build context about patient's condition
                                  String conditionContext = 'Family Member Recovery Support';
                                  String? detailsSummary;
                                  
                                  if (connectedPatient != null) {
                                    if (patientConditions != null) {
                                      conditionContext = 'Supporting family member with $patientConditions';
                                    }
                                    
                                    // Build detailed summary with patient info
                                    final summaryParts = <String>[];
                                    if (connectedPatient.conditions.isNotEmpty) {
                                      summaryParts.add('Patient conditions: ${connectedPatient.conditions.join(", ")}');
                                    }
                                    if (connectedPatient.medications.isNotEmpty) {
                                      final medNames = connectedPatient.medications
                                          .map((m) => m.name)
                                          .join(', ');
                                      summaryParts.add('Current medications: $medNames');
                                    }
                                    if (connectedPatient.diagnosisDate != null) {
                                      final daysSince = DateTime.now().difference(connectedPatient.diagnosisDate!).inDays;
                                      summaryParts.add('Days since diagnosis: $daysSince');
                                    }
                                    if (summaryParts.isNotEmpty) {
                                      detailsSummary = summaryParts.join('. ');
                                    }
                                  }
                                  
                                  plan = await ai.generateMilestones(
                                    description: description,
                                    milestones: count,
                                    durationDays: dDays,
                                    conditionName: conditionContext,
                                    conditionDetailsSummary: detailsSummary,
                                  );
                                } catch (e) {
                                  debugPrint(
                                      '[FamilyMemberJourney] AI generate failed: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'AI is unavailable right now')),
                                    );
                                  }
                                  return;
                                }

                                if (_userId == null) return;

                                // Save generated milestones
                                final authUserId =
                                    SupabaseConfig.client.auth.currentUser?.id;
                                for (int i = 0; i < plan.length; i++) {
                                  final item = plan[i];
                                  await SupabaseConfig.client
                                      .from('milestones')
                                      .insert({
                                    'user_id': authUserId,
                                    'profile_id': _userId,
                                    'title':
                                        item['title'] ?? 'Milestone ${i + 1}',
                                    'description': item['description'],
                                    'due_date': item['dueDate'],
                                    'help_type':
                                        (item['helpType'] ?? item['help_type']),
                                    'completed': false,
                                    'created_at':
                                        DateTime.now().toIso8601String(),
                                  });
                                }

                                Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            '✅ Generated $count milestones!')),
                                  );
                                  _loadData();
                                }
                              } catch (e) {
                                debugPrint(
                                    '[FamilyMemberJourney] Generate error: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Error generating plan: $e')),
                                  );
                                }
                              } finally {
                                try {
                                  setLocal(() => _generating = false);
                                } catch (_) {
                                  if (mounted)
                                    setState(() => _generating = false);
                                }
                              }
                            },
                      icon: _generating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: InlineLoadingDot(),
                            )
                          : const Icon(Icons.auto_awesome),
                      label:
                          Text(_generating ? 'Generating...' : 'Generate Plan'),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

// Supporting widgets
class _BlueprintCard extends StatelessWidget {
  final RecoveryBlueprint blueprint;
  final VoidCallback onView;
  const _BlueprintCard({required this.blueprint, required this.onView});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onView,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.assignment, color: Colors.teal, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recovery Blueprint',
                      style: context.textStyles.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('View your comprehensive recovery plan',
                      style: context.textStyles.bodySmall
                          ?.withColor(cs.onSurfaceVariant)),
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

class _CreateBlueprintCard extends StatelessWidget {
  final VoidCallback onCreate;
  const _CreateBlueprintCard({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_outlined,
                    color: Colors.teal, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Recovery Blueprint',
                    style: context.textStyles.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Create a comprehensive recovery plan with care team coordination, schedules, and supply tracking.',
            style:
                context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Blueprint'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int completedCount;
  final int totalCount;
  final int activeGoalsCount;
  const _StatsCard(
      {required this.completedCount,
      required this.totalCount,
      required this.activeGoalsCount});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progress Overview',
              style: context.textStyles.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                    'Completed', completedCount.toString(), Colors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile('Remaining',
                    (totalCount - completedCount).toString(), Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                    'Active Goals', activeGoalsCount.toString(), Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: cs.surfaceContainer,
            color: Colors.teal,
          ),
          const SizedBox(height: 8),
          Text('${(progress * 100).toInt()}% Complete',
              style: context.textStyles.labelMedium),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style: context.textStyles.headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: context.textStyles.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 2),
        ],
      ),
    );
  }
}

class _MilestonesCard extends StatelessWidget {
  final List milestones;
  final String? userId;
  final VoidCallback onAdd;
  final VoidCallback onGenerateAI;
  final VoidCallback onSavePlan;
  final VoidCallback onRefresh;
  const _MilestonesCard(
      {required this.milestones,
      this.userId,
      required this.onAdd,
      required this.onGenerateAI,
      required this.onSavePlan,
      required this.onRefresh});

  Future<void> _toggleMilestone(
      BuildContext context, Map<String, dynamic> milestone) async {
    try {
      final milestoneId = milestone['id'];
      final currentlyCompleted = milestone['completed'] == true;

      await SupabaseConfig.client.from('milestones').update({
        'completed': !currentlyCompleted,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', milestoneId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(currentlyCompleted
                  ? '✓ Milestone unmarked'
                  : '✅ Milestone completed!')),
        );
        onRefresh();
      }
    } catch (e) {
      debugPrint('[_MilestonesCard] Error toggling milestone: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating milestone: $e')),
        );
      }
    }
  }

  void _showMilestoneOptions(
      BuildContext context, Map<String, dynamic> milestone) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('Learn More'),
              onTap: () {
                Navigator.pop(ctx);
                _showLearnMore(context, milestone);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Milestone'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditMilestoneDialog(context, milestone);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Milestone',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Milestone?'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style:
                            FilledButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await _deleteMilestone(context, milestone['id']);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLearnMore(BuildContext context, Map<String, dynamic> milestone) {
    // Family members are learning about supporting their loved one's recovery
    // Context: Family member recovery support
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MilestoneEducationPage(
          stepTitle: milestone['title'] ?? 'Recovery Milestone',
          stepDescription: milestone['description'],
          conditionName: 'Family Recovery Support',
          conditionDetailsSummary: null,
        ),
      ),
    );
  }

  Future<void> _deleteMilestone(
      BuildContext context, String milestoneId) async {
    try {
      await SupabaseConfig.client
          .from('milestones')
          .delete()
          .eq('id', milestoneId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Milestone deleted')),
        );
        onRefresh();
      }
    } catch (e) {
      debugPrint('[_MilestonesCard] Error deleting milestone: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting milestone: $e')),
        );
      }
    }
  }

  void _showEditMilestoneDialog(
      BuildContext context, Map<String, dynamic> milestone) {
    final titleController = TextEditingController(text: milestone['title']);
    final descriptionController =
        TextEditingController(text: milestone['description'] ?? '');
    DateTime? targetDate = milestone['due_date'] != null
        ? DateTime.tryParse(milestone['due_date'])
        : null;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Milestone'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Milestone Title',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    targetDate == null
                        ? 'Set Target Date'
                        : 'Target: ${targetDate!.month}/${targetDate!.day}/${targetDate!.year}',
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: targetDate ??
                          DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => targetDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a milestone title')),
                  );
                  return;
                }

                try {
                  await SupabaseConfig.client.from('milestones').update({
                    'title': titleController.text.trim(),
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    'due_date': targetDate?.toIso8601String(),
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', milestone['id']);

                  Navigator.pop(dialogContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Milestone updated!')),
                    );
                    onRefresh();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating milestone: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'A.R.I.E',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.albertSans().fontFamily,
                      fontSize: AppSpacing.lg),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                color: cs.primary,
                tooltip: 'Generate with AI',
                onPressed: onGenerateAI,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: Colors.orange,
                tooltip: 'Add manually',
                onPressed: onAdd,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (milestones.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.flag_outlined,
                        size: 48, color: cs.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text('No milestones yet',
                        style: context.textStyles.bodyMedium
                            ?.withColor(cs.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: onGenerateAI,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Generate with AI'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onAdd,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Manually'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            ...milestones.asMap().entries.map((entry) {
              final index = entry.key;
              final m = entry.value;
              final isCompleted = m['completed'] == true;
              return Padding(
                padding: EdgeInsets.only(
                    bottom: index < milestones.length - 1 ? 12 : 0),
                child: InkWell(
                  onTap: () => _toggleMilestone(context, m),
                  onLongPress: () => _showMilestoneOptions(context, m),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isCompleted ? Colors.teal : Colors.transparent,
                            border: Border.all(
                              color: isCompleted ? Colors.teal : cs.outline,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : Text('${index + 1}',
                                    style: context.textStyles.labelMedium),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['title'] ?? 'Milestone ${index + 1}',
                                style: context.textStyles.bodyMedium?.copyWith(
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (((m['help_type'] ?? m['helpType']) ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                HelpTypeChip(
                                  helpType:
                                      ((m['help_type'] ?? m['helpType']) ?? '')
                                          .toString(),
                                  compact: true,
                                ),
                              ],
                              if (m['description'] != null &&
                                  m['description'].toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  m['description'],
                                  style: context.textStyles.bodySmall
                                      ?.withColor(cs.onSurfaceVariant),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, size: 18),
                          color: cs.onSurfaceVariant,
                          onPressed: () => _showMilestoneOptions(context, m),
                          tooltip: 'Options',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _GoalsCard extends StatelessWidget {
  final List goals;
  final String? userId;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;
  const _GoalsCard(
      {required this.goals,
      this.userId,
      required this.onAdd,
      required this.onRefresh});

  Future<void> _incrementProgress(
      BuildContext context, Map<String, dynamic> goal) async {
    try {
      final currentProgress =
          goal['progress_this_period'] ?? goal['progressThisPeriod'] ?? 0;
      final target = goal['target_per_period'] ?? goal['targetPerPeriod'] ?? 1;
      final newProgress = (currentProgress + 1).clamp(0, target);

      await SupabaseConfig.client.from('goals').update({
        'progress_this_period': newProgress,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', goal['id']);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Progress: $newProgress/$target')),
        );
        onRefresh();
      }
    } catch (e) {
      debugPrint('[_GoalsCard] Error incrementing progress: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating goal: $e')),
        );
      }
    }
  }

  void _showGoalOptions(BuildContext context, Map<String, dynamic> goal) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Goal'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditGoalDialog(context, goal);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reset Progress'),
              onTap: () async {
                Navigator.pop(ctx);
                await _resetProgress(context, goal['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive, color: Colors.orange),
              title: const Text('Archive Goal',
                  style: TextStyle(color: Colors.orange)),
              onTap: () async {
                Navigator.pop(ctx);
                await _archiveGoal(context, goal['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetProgress(BuildContext context, String goalId) async {
    try {
      await SupabaseConfig.client.from('goals').update({
        'progress_this_period': 0,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', goalId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress reset')),
        );
        onRefresh();
      }
    } catch (e) {
      debugPrint('[_GoalsCard] Error resetting progress: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting progress: $e')),
        );
      }
    }
  }

  Future<void> _archiveGoal(BuildContext context, String goalId) async {
    try {
      await SupabaseConfig.client.from('goals').update({
        'active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', goalId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal archived')),
        );
        onRefresh();
      }
    } catch (e) {
      debugPrint('[_GoalsCard] Error archiving goal: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error archiving goal: $e')),
        );
      }
    }
  }

  void _showEditGoalDialog(BuildContext context, Map<String, dynamic> goal) {
    final titleController = TextEditingController(text: goal['title']);
    final targetController = TextEditingController(
      text: (goal['target_per_period'] ?? goal['targetPerPeriod'] ?? 10)
          .toString(),
    );
    String frequency = goal['period'] ?? goal['frequency'] ?? 'daily';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Goal Title',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: targetController,
                  decoration: const InputDecoration(
                    labelText: 'Target (per period)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => frequency = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a goal title')),
                  );
                  return;
                }

                try {
                  final target = int.tryParse(targetController.text) ?? 10;
                  await SupabaseConfig.client.from('goals').update({
                    'title': titleController.text.trim(),
                    'target_per_period': target,
                    'frequency': frequency,
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', goal['id']);

                  Navigator.pop(dialogContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Goal updated!')),
                    );
                    onRefresh();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating goal: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Active Goals',
                    style: context.textStyles.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: Colors.blue,
                onPressed: onAdd,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (goals.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.track_changes,
                        size: 48, color: cs.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text('No goals yet',
                        style: context.textStyles.bodyMedium
                            ?.withColor(cs.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Goal'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...goals.asMap().entries.map((entry) {
              final index = entry.key;
              final g = entry.value;
              final currentProgress =
                  g['progress_this_period'] ?? g['progressThisPeriod'] ?? 0;
              final target =
                  g['target_per_period'] ?? g['targetPerPeriod'] ?? 1;
              final progress = currentProgress / target;
              return Padding(
                padding:
                    EdgeInsets.only(bottom: index < goals.length - 1 ? 16 : 0),
                child: InkWell(
                  onTap: () => _incrementProgress(context, g),
                  onLongPress: () => _showGoalOptions(context, g),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                g['title'] ?? 'Goal',
                                style: context.textStyles.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '$currentProgress/$target',
                                  style: context.textStyles.labelMedium,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert, size: 18),
                                  color: cs.onSurfaceVariant,
                                  onPressed: () => _showGoalOptions(context, g),
                                  tooltip: 'Options',
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                          backgroundColor: cs.surfaceContainer,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to add progress • Long press for options',
                          style: context.textStyles.labelSmall
                              ?.withColor(cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
