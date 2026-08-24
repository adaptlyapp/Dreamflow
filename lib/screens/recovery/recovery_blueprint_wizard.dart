import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/models/recovery_blueprint.dart';
import 'package:wellspring/models/user.dart' as models;
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/recovery_blueprint_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';

class RecoveryBlueprintWizard extends StatefulWidget {
  final RecoveryBlueprint? existing;
  final String? patientId; // For family portal use

  const RecoveryBlueprintWizard({super.key, this.existing, this.patientId});

  @override
  State<RecoveryBlueprintWizard> createState() => _RecoveryBlueprintWizardState();
}

class _RecoveryBlueprintWizardState extends State<RecoveryBlueprintWizard> {
  final _service = RecoveryBlueprintService();
  final _userService = UserService();
  final _uuid = const Uuid();
  int _currentStep = 0;
  bool _saving = false;
  bool _loading = true;
  List<String> _availableConditions = [];
  models.User? _patientUser;

  // Step 1: Patient Profile
  String _primaryDiagnosis = '';
  List<String> _secondaryDiagnoses = [];
  DateTime? _dateOfInjury;
  RecoveryPhase _recoveryPhase = RecoveryPhase.postDischarge;
  String _functionalClassification = '';
  List<String> _therapyGoals = [];
  List<String> _physicianRestrictions = [];

  // Step 2: Care Team
  List<CareTeamMember> _careTeam = [];

  // Step 3: Independence Assessment
  Map<String, IndependenceLevel> _cognitive = {};
  Map<String, IndependenceLevel> _physical = {};

  // Step 4: Home Readiness
  Map<String, bool> _homeChecklist = {};
  List<ActionItem> _actionItems = [];

  // Step 5: Daily Routines
  List<DailyRoutine> _dailyRoutines = [];

  // Step 6: Equipment
  List<EquipmentItem> _equipment = [];

  // Step 7: Supplies
  List<SupplyItem> _supplies = [];

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    try {
      // Get patient user ID (from widget or current user)
      final patientId = widget.patientId ?? context.read<UserProvider>().currentUser?.id;
      
      if (patientId != null) {
        // Fetch patient user data to get their conditions
        _patientUser = await _userService.getUserById(patientId);
        _availableConditions = _patientUser?.conditions ?? [];
      }

      // Load existing blueprint or initialize defaults
      if (widget.existing != null) {
        _loadExisting();
      } else {
        _initializeDefaults();
      }
    } catch (e) {
      debugPrint('Error loading patient data: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadExisting() {
    final bp = widget.existing!;
    _primaryDiagnosis = bp.patientProfile.primaryDiagnosis;
    _secondaryDiagnoses = List.from(bp.patientProfile.secondaryDiagnoses);
    _dateOfInjury = bp.patientProfile.dateOfInjury;
    _recoveryPhase = bp.patientProfile.recoveryPhase;
    _functionalClassification = bp.patientProfile.functionalClassification ?? '';
    _therapyGoals = List.from(bp.patientProfile.therapyGoals);
    _physicianRestrictions = List.from(bp.patientProfile.physicianRestrictions);
    _careTeam = List.from(bp.careTeam);
    _cognitive = Map.from(bp.independenceAssessment.cognitive);
    _physical = Map.from(bp.independenceAssessment.physical);
    _homeChecklist = Map.from(bp.homeReadiness.checklist);
    _actionItems = List.from(bp.homeReadiness.actionItems);
    _dailyRoutines = List.from(bp.dailyRoutines);
    _equipment = List.from(bp.equipment);
    _supplies = List.from(bp.supplies);
  }

  void _initializeDefaults() {
    // Initialize independence assessment defaults
    for (final key in ['decisions', 'instructions', 'communication', 'phone', 'appointments']) {
      _cognitive[key] = IndependenceLevel.independent;
    }
    for (final key in ['transfer', 'dress', 'bathe', 'toilet', 'feed', 'mobility', 'drive']) {
      _physical[key] = IndependenceLevel.needsAssistance;
    }

    // Initialize home readiness checklist
    for (final key in ['ramp', 'grab_bars', 'shower_chair', 'hospital_bed', 'accessible_vehicle']) {
      _homeChecklist[key] = false;
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && _primaryDiagnosis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter primary diagnosis')),
      );
      return;
    }

    if (_currentStep < 7) {
      setState(() => _currentStep++);
    } else {
      _saveBlueprint();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _saveBlueprint() async {
    // Use patientId if provided (family portal), otherwise use current user's ID (patient portal)
    final userId = widget.patientId ?? context.read<UserProvider>().currentUser?.id;
    debugPrint('RecoveryBlueprintWizard.save: Saving blueprint for userId=$userId (patientId=${widget.patientId}, currentUser=${context.read<UserProvider>().currentUser?.id})');
    if (userId == null) return;

    setState(() => _saving = true);

    try {
      final blueprint = RecoveryBlueprint(
        id: widget.existing?.id ?? _uuid.v4(),
        userId: userId,
        patientProfile: PatientProfile(
          primaryDiagnosis: _primaryDiagnosis,
          secondaryDiagnoses: _secondaryDiagnoses,
          dateOfInjury: _dateOfInjury,
          recoveryPhase: _recoveryPhase,
          functionalClassification: _functionalClassification.isEmpty ? null : _functionalClassification,
          therapyGoals: _therapyGoals,
          physicianRestrictions: _physicianRestrictions,
        ),
        careTeam: _careTeam,
        independenceAssessment: IndependenceAssessment(
          cognitive: _cognitive,
          physical: _physical,
        ),
        homeReadiness: HomeReadiness(
          checklist: _homeChecklist,
          actionItems: _actionItems,
        ),
        dailyRoutines: _dailyRoutines,
        equipment: _equipment,
        supplies: _supplies,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Generate roadmap
      final roadmap = _service.generateRoadmap(blueprint);
      final finalBlueprint = RecoveryBlueprint(
        id: blueprint.id,
        userId: blueprint.userId,
        patientProfile: blueprint.patientProfile,
        careTeam: blueprint.careTeam,
        independenceAssessment: blueprint.independenceAssessment,
        homeReadiness: blueprint.homeReadiness,
        dailyRoutines: blueprint.dailyRoutines,
        equipment: blueprint.equipment,
        supplies: blueprint.supplies,
        roadmap: roadmap,
        createdAt: blueprint.createdAt,
        updatedAt: blueprint.updatedAt,
      );

      if (widget.existing != null) {
        await _service.update(finalBlueprint);
      } else {
        await _service.create(finalBlueprint);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recovery Blueprint saved!')),
        );
        context.pop(true);
      }
    } catch (e) {
      debugPrint('RecoveryBlueprintWizard.save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: cs.surface.withValues(alpha: 0.65),
          title: const Text('Recovery Blueprint Setup'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: cs.surface.withValues(alpha: 0.65),
        title: const Text('Recovery Blueprint Setup'),
      ),
      body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: AppSpacing.horizontalLg,
                  child: _ProgressBar(value: (_currentStep + 1) / 8),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: AppSpacing.paddingLg,
                      child: _CardSurface(
                        child: Column(
                          children: [
                            _StepHeader(current: _currentStep),
                            const SizedBox(height: AppSpacing.lg),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                child: SingleChildScrollView(
                                  key: ValueKey(_currentStep),
                                  padding: AppSpacing.paddingLg,
                                  child: _buildStepContent(),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            SafeArea(
                              top: false,
                              child: Row(
                                children: [
                                  if (_currentStep > 0)
                                    OutlinedButton.icon(
                                      onPressed: _saving ? null : _previousStep,
                                      icon: Icon(Icons.arrow_back, color: cs.primary),
                                      label: const Text('Back'),
                                    ),
                                  const Spacer(),
                                  FilledButton(
                                    onPressed: _saving ? null : _nextStep,
                                    child: _saving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Text(_currentStep == 7 ? 'Complete' : 'Continue'),
                                  ),
                                ],
                              ),
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

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPatientProfile();
      case 1:
        return _buildCareTeam();
      case 2:
        return _buildIndependenceAssessment();
      case 3:
        return _buildHomeReadiness();
      case 4:
        return _buildDailyRoutines();
      case 5:
        return _buildMedications();
      case 6:
        return _buildEquipment();
      case 7:
        return _buildSupplies();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPatientProfile() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Patient Profile', style: context.textStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Tell us about your condition and recovery stage',
            style: context.textStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_availableConditions.isEmpty)
            Text(
              'No diagnosed conditions found in patient profile. Please add conditions first.',
              style: context.textStyles.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
            )
          else
            DropdownButtonFormField<String>(
              value: _primaryDiagnosis.isEmpty ? null : _primaryDiagnosis,
              decoration: const InputDecoration(
                labelText: 'Primary Diagnosis',
                hintText: 'Select from diagnosed conditions',
              ),
              items: _availableConditions.map((condition) =>
                DropdownMenuItem(value: condition, child: Text(condition))
              ).toList(),
              onChanged: (value) => setState(() => _primaryDiagnosis = value ?? ''),
            ),
          const SizedBox(height: AppSpacing.md),
          Text('Recovery Phase', style: context.textStyles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: RecoveryPhase.values.map((phase) {
              final selected = _recoveryPhase == phase;
              return ChoiceChip(
                label: Text(phase.label),
                selected: selected,
                onSelected: (_) => setState(() => _recoveryPhase = phase),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Functional Classification (optional)',
              hintText: 'e.g., C4 ASIA A, NIHSS 8',
            ),
            onChanged: (v) => setState(() => _functionalClassification = v),
            controller: TextEditingController(text: _functionalClassification)..selection = TextSelection.collapsed(offset: _functionalClassification.length),
          ),
        ],
      );

  Widget _buildCareTeam() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Care Team', style: context.textStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Who helps with your care? Add team members and their availability.',
            style: context.textStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          ..._careTeam.map((member) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(member.name),
                  subtitle: Text(member.relationship),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _careTeam.remove(member)),
                  ),
                ),
              )),
          OutlinedButton.icon(
            onPressed: _showAddCareTeamMember,
            icon: const Icon(Icons.add),
            label: const Text('Add Team Member'),
          ),
        ],
      );

  Widget _buildIndependenceAssessment() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Independence Assessment', style: context.textStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text('Cognitive Abilities', style: context.textStyles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ..._cognitive.entries.map((e) => _buildIndependenceRow(e.key, e.value, true)),
          const SizedBox(height: AppSpacing.lg),
          Text('Physical Abilities', style: context.textStyles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ..._physical.entries.map((e) => _buildIndependenceRow(e.key, e.value, false)),
        ],
      );

  Widget _buildIndependenceRow(String key, IndependenceLevel level, bool isCognitive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(key.replaceAll('_', ' ').toUpperCase(), style: context.textStyles.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: IndependenceLevel.values.map((lvl) {
              final selected = level == lvl;
              return ChoiceChip(
                label: Text(lvl.label, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    if (isCognitive) {
                      _cognitive[key] = lvl;
                    } else {
                      _physical[key] = lvl;
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeReadiness() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Home Readiness', style: context.textStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text('Check what you have at home', style: context.textStyles.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          ..._homeChecklist.entries.map((e) => CheckboxListTile(
                title: Text(e.key.replaceAll('_', ' ').toUpperCase()),
                value: e.value,
                onChanged: (v) => setState(() => _homeChecklist[e.key] = v ?? false),
              )),
          const SizedBox(height: AppSpacing.lg),
          Text('Action Items', style: context.textStyles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ..._actionItems.map((item) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  title: Text(item.description),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _actionItems.remove(item)),
                  ),
                ),
              )),
          OutlinedButton.icon(
            onPressed: _showAddActionItem,
            icon: const Icon(Icons.add),
            label: const Text('Add Action Item'),
          ),
        ],
      );

  Widget _buildDailyRoutines() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Care Routines', style: context.textStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text('Set up your daily care schedule', style: context.textStyles.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          ..._dailyRoutines.map((routine) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  title: Text(routine.type.toUpperCase()),
                  subtitle: Text('${routine.daysPerformed.join(", ")} at ${routine.timesOfDay.isNotEmpty ? routine.timesOfDay.join(", ") : "TBD"}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _dailyRoutines.remove(routine)),
                  ),
                ),
              )),
          OutlinedButton.icon(
            onPressed: _showAddRoutine,
            icon: const Icon(Icons.add),
            label: const Text('Add Routine'),
          ),
        ],
      );

  Widget _buildMedications() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Medications', style: context.textStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Medication tracking is managed in your Profile. You can skip this step and add medications later.',
            style: context.textStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Manage Medications'),
              subtitle: const Text('Visit Profile > Account Settings to add/edit medications'),
              trailing: const Icon(Icons.arrow_forward),
            ),
          ),
        ],
      );

  Widget _buildEquipment() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Durable Medical Equipment', style: context.textStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text('Track your equipment and maintenance', style: context.textStyles.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          ..._equipment.map((eq) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: const Icon(Icons.medical_services_outlined),
                  title: Text(eq.name),
                  subtitle: eq.vendor != null ? Text(eq.vendor!) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _equipment.remove(eq)),
                  ),
                ),
              )),
          OutlinedButton.icon(
            onPressed: _showAddEquipment,
            icon: const Icon(Icons.add),
            label: const Text('Add Equipment'),
          ),
        ],
      );

  Widget _buildSupplies() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Supply Inventory', style: context.textStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text('Track supplies and get reorder alerts', style: context.textStyles.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          ..._supplies.map((supply) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: Icon(
                    Icons.inventory_2_outlined,
                    color: supply.needsReorder ? Colors.orange : null,
                  ),
                  title: Text(supply.name),
                  subtitle: Text('Qty: ${supply.currentQuantity} • ${supply.daysRemaining} days left'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _supplies.remove(supply)),
                  ),
                ),
              )),
          OutlinedButton.icon(
            onPressed: _showAddSupply,
            icon: const Icon(Icons.add),
            label: const Text('Add Supply'),
          ),
        ],
      );

  void _showAddCareTeamMember() {
    final nameController = TextEditingController();
    final relationshipController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Care Team Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: relationshipController,
              decoration: const InputDecoration(labelText: 'Relationship'),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final member = CareTeamMember(
                id: _uuid.v4(),
                name: nameController.text,
                relationship: relationshipController.text,
                phone: phoneController.text.isEmpty ? null : phoneController.text,
                email: emailController.text.isEmpty ? null : emailController.text,
              );
              setState(() => _careTeam.add(member));
              context.pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddActionItem() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Action Item'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final item = ActionItem(
                id: _uuid.v4(),
                description: controller.text,
              );
              setState(() => _actionItems.add(item));
              context.pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddRoutine() {
    final types = ['bowel', 'bladder', 'skin_check', 'therapy', 'nutrition'];
    String selectedType = 'bowel';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Daily Routine'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                items: types.map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                onChanged: (v) => setDialogState(() => selectedType = v!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final routine = DailyRoutine(type: selectedType);
                setState(() => _dailyRoutines.add(routine));
                context.pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEquipment() {
    final nameController = TextEditingController();
    final vendorController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Equipment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Equipment Name'),
            ),
            TextField(
              controller: vendorController,
              decoration: const InputDecoration(labelText: 'Vendor'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final eq = EquipmentItem(
                id: _uuid.v4(),
                name: nameController.text,
                vendor: vendorController.text.isEmpty ? null : vendorController.text,
              );
              setState(() => _equipment.add(eq));
              context.pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddSupply() {
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '30');
    final usageController = TextEditingController(text: '30');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Supply'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Supply Name'),
            ),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Current Quantity'),
            ),
            TextField(
              controller: usageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monthly Usage'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final supply = SupplyItem(
                id: _uuid.v4(),
                name: nameController.text,
                category: 'general',
                currentQuantity: int.tryParse(qtyController.text) ?? 30,
                monthlyUsage: int.tryParse(usageController.text) ?? 30,
                reorderThreshold: 10,
              );
              setState(() => _supplies.add(supply));
              context.pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _CardSurface extends StatelessWidget {
  const _CardSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: child,
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    final steps = const [
      (Icons.medical_information_outlined, 'Profile'),
      (Icons.people_outline, 'Care Team'),
      (Icons.accessibility_new, 'Independence'),
      (Icons.home_outlined, 'Home Setup'),
      (Icons.schedule, 'Routines'),
      (Icons.medication_outlined, 'Medications'),
      (Icons.medical_services_outlined, 'Equipment'),
      (Icons.inventory_2_outlined, 'Supplies'),
    ];
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(steps[current].$1, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Step ${current + 1} of ${steps.length} · ${steps[current].$2}',
            style: context.textStyles.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
