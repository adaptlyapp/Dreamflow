import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/models/pain_detail.dart';
import 'package:wellspring/models/patient_connection.dart';
import 'package:wellspring/models/user.dart';
import 'package:wellspring/services/tracker_service.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';
import 'package:intl/intl.dart';
import 'package:wellspring/widgets/pain_mapping_widget.dart';
import 'package:uuid/uuid.dart';

class FamilyAddHealthLogScreen extends StatefulWidget {
  const FamilyAddHealthLogScreen({super.key});

  @override
  State<FamilyAddHealthLogScreen> createState() => _FamilyAddHealthLogScreenState();
}

class _FamilyAddHealthLogScreenState extends State<FamilyAddHealthLogScreen> {
  final _trackerService = TrackerService();
  final _familyService = FamilyService();
  final _userService = UserService();
  final _notesController = TextEditingController();
  final _sysController = TextEditingController();
  final _diaController = TextEditingController();
  final _hrController = TextEditingController();
  final _stepsController = TextEditingController();
  final _weightController = TextEditingController();
  final _tempController = TextEditingController();
  
  bool _loading = true;
  bool _saving = false;
  PatientConnection? _connection;
  User? _patientUser;

  DateTime _selectedDate = DateTime.now();
  int? _painLevel;
  List<PainDetail> _painMap = [];
  String? _mood;
  int? _spasmFrequency;
  bool? _bladderSuccess;
  bool? _bowelProgram;
  int? _sleepQuality;
  int? _energyLevel;
  int? _systolicBP;
  int? _diastolicBP;
  int? _heartRate;
  int? _steps;
  double? _weight;
  double? _temperature;
  List<String> _medications = [];
  List<String> _symptoms = [];
  List<String> _triggers = [];
  List<String> _activities = [];

  final Map<String, MedicationLog> _medicationLogsByName = {};
  final Map<String, SymptomLog> _symptomLogsByName = {};
  final Map<String, TriggerLog> _triggerLogsByName = {};
  final Map<String, ActivityLog> _activityLogsByName = {};

  final List<String> _moodOptions = ['😊', '😐', '😔', '😰', '😡'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _sysController.dispose();
    _diaController.dispose();
    _hrController.dispose();
    _stepsController.dispose();
    _weightController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  User? _currentFamilyUser; // Track the family member creating the entry

  Future<void> _loadData() async {
    try {
      setState(() => _loading = true);
      
      final user = await _userService.getCurrentUser();
      if (user == null) {
        debugPrint('[FamilyAddHealthLog] No current user found');
        return;
      }

      _currentFamilyUser = user; // Store the family member's info

      final connection = await _familyService.getPrimaryConnection(user.id);
      if (connection == null) {
        debugPrint('[FamilyAddHealthLog] No patient connection found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No patient connection found. Please complete onboarding.')),
          );
          context.go('/family/dashboard');
        }
        return;
      }

      final patientUser = await _userService.getUserById(connection.patientId);

      setState(() {
        _connection = connection;
        _patientUser = patientUser;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[FamilyAddHealthLog] Error loading data: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _saveEntry() async {
    if (_connection == null) return;

    // Check if at least one field is filled
    final hasData = _painLevel != null ||
        _painMap.isNotEmpty ||
        _mood != null ||
        _spasmFrequency != null ||
        _bladderSuccess != null ||
        _bowelProgram != null ||
        _sleepQuality != null ||
        _energyLevel != null ||
        _systolicBP != null ||
        _diastolicBP != null ||
        _heartRate != null ||
        _steps != null ||
        _weight != null ||
        _temperature != null ||
        _medications.isNotEmpty ||
        _symptoms.isNotEmpty ||
        _triggers.isNotEmpty ||
        _activities.isNotEmpty ||
        _notesController.text.isNotEmpty;

    if (!hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in at least one field')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Build custom fields with structured logs
      final customFields = <String, dynamic>{};
      if (_medicationLogsByName.isNotEmpty) {
        customFields['medicationLogs'] = _medicationLogsByName.values.map((e) => e.toJson()).toList();
      }
      if (_symptomLogsByName.isNotEmpty) {
        customFields['symptomLogs'] = _symptomLogsByName.values.map((e) => e.toJson()).toList();
      }
      if (_triggerLogsByName.isNotEmpty) {
        customFields['triggerLogs'] = _triggerLogsByName.values.map((e) => e.toJson()).toList();
      }
      if (_activityLogsByName.isNotEmpty) {
        customFields['activityLogs'] = _activityLogsByName.values.map((e) => e.toJson()).toList();
      }

      final entry = TrackerEntry(
        id: const Uuid().v4(),
        userId: _connection!.patientId,
        date: _selectedDate,
        painLevel: _painLevel,
        painMap: _painMap.isEmpty ? null : _painMap,
        mood: _mood,
        spasmFrequency: _spasmFrequency,
        bladderSuccess: _bladderSuccess,
        bowelProgram: _bowelProgram,
        sleepQuality: _sleepQuality,
        energyLevel: _energyLevel,
        systolicBP: _systolicBP,
        diastolicBP: _diastolicBP,
        heartRate: _heartRate,
        steps: _steps,
        weight: _weight,
        temperature: _temperature,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        medications: _medications.isEmpty ? null : _medications,
        symptoms: _symptoms.isEmpty ? null : _symptoms,
        triggers: _triggers.isEmpty ? null : _triggers,
        activities: _activities.isEmpty ? null : _activities,
        medicationLogs: _medicationLogsByName.values.toList(),
        symptomLogs: _symptomLogsByName.values.toList(),
        triggerLogs: _triggerLogsByName.values.toList(),
        activityLogs: _activityLogsByName.values.toList(),
        customFields: customFields.isEmpty ? null : customFields,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdByUserId: _currentFamilyUser?.id, // Track that family member created this entry
      );

      await _trackerService.addEntry(entry);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Health log saved for ${_connection!.patientName}'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('[FamilyAddHealthLog] Error saving entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addMedication(String name) {
    if (name.isEmpty || _medications.contains(name)) return;
    setState(() {
      _medications.add(name);
      if (!_medicationLogsByName.containsKey(name)) {
        _medicationLogsByName[name] = MedicationLog(name: name);
      }
    });
  }

  void _addSymptom(String name) {
    if (name.isEmpty || _symptoms.contains(name)) return;
    setState(() {
      _symptoms.add(name);
      if (!_symptomLogsByName.containsKey(name)) {
        _symptomLogsByName[name] = SymptomLog(name: name);
      }
    });
  }

  void _addTrigger(String name) {
    if (name.isEmpty || _triggers.contains(name)) return;
    setState(() {
      _triggers.add(name);
      if (!_triggerLogsByName.containsKey(name)) {
        _triggerLogsByName[name] = TriggerLog(name: name);
      }
    });
  }

  void _addActivity(String name) {
    if (name.isEmpty || _activities.contains(name)) return;
    setState(() {
      _activities.add(name);
      if (!_activityLogsByName.containsKey(name)) {
        _activityLogsByName[name] = ActivityLog(name: name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Log Health Data')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Log Health Data'),
            if (_connection != null)
              Text(
                'for ${_connection!.patientName}',
                style: context.textStyles.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
        backgroundColor: cs.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveEntry,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Picker
            _SectionCard(
              title: 'Date & Time',
              icon: Icons.calendar_today,
              child: ListTile(
                title: Text(DateFormat('EEEE, MMMM d, y').format(_selectedDate)),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Pain Level
            _SectionCard(
              title: 'Pain Level',
              icon: Icons.favorite_border,
              child: Column(
                children: [
                  Slider(
                    value: (_painLevel ?? 0).toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    label: _painLevel?.toString() ?? '0',
                    onChanged: (value) => setState(() => _painLevel = value.toInt()),
                  ),
                  Text(
                    _painLevel == null ? 'No pain' : 'Pain level: $_painLevel/10',
                    style: context.textStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_painLevel != null && _painLevel! > 0)
                    TextButton.icon(
                      onPressed: () => _showPainMappingDialog(),
                      icon: const Icon(Icons.touch_app),
                      label: Text(_painMap.isEmpty ? 'Map pain locations' : 'Edit pain map (${_painMap.length} areas)'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Vitals
            _SectionCard(
              title: 'Vital Signs',
              icon: Icons.monitor_heart,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sysController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Systolic BP',
                            suffixText: 'mmHg',
                          ),
                          onChanged: (v) => _systolicBP = int.tryParse(v),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _diaController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Diastolic BP',
                            suffixText: 'mmHg',
                          ),
                          onChanged: (v) => _diastolicBP = int.tryParse(v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _hrController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Heart Rate',
                      suffixText: 'bpm',
                      prefixIcon: Icon(Icons.favorite),
                    ),
                    onChanged: (v) => _heartRate = int.tryParse(v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _tempController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Temperature',
                      suffixText: '°C',
                      prefixIcon: Icon(Icons.thermostat),
                    ),
                    onChanged: (v) => _temperature = double.tryParse(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Mood
            _SectionCard(
              title: 'Mood',
              icon: Icons.mood,
              child: Wrap(
                spacing: AppSpacing.sm,
                children: _moodOptions.map((emoji) {
                  final isSelected = _mood == emoji;
                  return ChoiceChip(
                    label: Text(emoji, style: const TextStyle(fontSize: 24)),
                    selected: isSelected,
                    onSelected: (selected) => setState(() => _mood = selected ? emoji : null),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Quality Metrics
            _SectionCard(
              title: 'Daily Metrics',
              icon: Icons.assessment,
              child: Column(
                children: [
                  _SliderMetric(
                    label: 'Sleep Quality',
                    value: _sleepQuality,
                    onChanged: (v) => setState(() => _sleepQuality = v),
                  ),
                  _SliderMetric(
                    label: 'Energy Level',
                    value: _energyLevel,
                    onChanged: (v) => setState(() => _energyLevel = v),
                  ),
                  _SliderMetric(
                    label: 'Spasm Frequency',
                    value: _spasmFrequency,
                    onChanged: (v) => setState(() => _spasmFrequency = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CheckboxListTile(
                    title: const Text('Bladder Success'),
                    value: _bladderSuccess ?? false,
                    tristate: true,
                    onChanged: (v) => setState(() => _bladderSuccess = v),
                  ),
                  CheckboxListTile(
                    title: const Text('Bowel Program Completed'),
                    value: _bowelProgram ?? false,
                    tristate: true,
                    onChanged: (v) => setState(() => _bowelProgram = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Medications
            _SectionCard(
              title: 'Medications',
              icon: Icons.medication,
              child: Column(
                children: [
                  ..._medications.map((med) => ListTile(
                    title: Text(med),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _medications.remove(med);
                        _medicationLogsByName.remove(med);
                      }),
                    ),
                  )),
                  TextButton.icon(
                    onPressed: () => _showAddDialog('Add Medication', _addMedication),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Medication'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Symptoms
            _SectionCard(
              title: 'Symptoms',
              icon: Icons.report_problem,
              child: Column(
                children: [
                  ..._symptoms.map((symptom) => ListTile(
                    title: Text(symptom),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _symptoms.remove(symptom);
                        _symptomLogsByName.remove(symptom);
                      }),
                    ),
                  )),
                  TextButton.icon(
                    onPressed: () => _showAddDialog('Add Symptom', _addSymptom),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Symptom'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Activities
            _SectionCard(
              title: 'Activities',
              icon: Icons.directions_walk,
              child: Column(
                children: [
                  TextField(
                    controller: _stepsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Steps',
                      prefixIcon: Icon(Icons.directions_walk),
                    ),
                    onChanged: (v) => _steps = int.tryParse(v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ..._activities.map((activity) => ListTile(
                    title: Text(activity),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _activities.remove(activity);
                        _activityLogsByName.remove(activity);
                      }),
                    ),
                  )),
                  TextButton.icon(
                    onPressed: () => _showAddDialog('Add Activity', _addActivity),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Activity'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Notes
            _SectionCard(
              title: 'Notes',
              icon: Icons.notes,
              child: TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Add any additional notes...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _showPainMappingDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pain Mapping', style: context.textStyles.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: PainMappingWidget(
                  initialPainMap: _painMap,
                  onChanged: (painMap) => setState(() => _painMap = painMap),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog(String title, Function(String) onAdd) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter name'),
          onSubmitted: (value) {
            onAdd(value);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onAdd(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _SliderMetric extends StatelessWidget {
  const _SliderMetric({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.textStyles.bodyMedium),
        Slider(
          value: (value ?? 0).toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          label: value?.toString() ?? '0',
          onChanged: (v) => onChanged(v.toInt()),
        ),
      ],
    );
  }
}
