import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/models/pain_detail.dart';
import 'package:wellspring/models/recovery_blueprint.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/tracker_service.dart';
import 'package:wellspring/services/health_service.dart';
import 'package:wellspring/services/recovery_blueprint_service.dart';
import 'package:wellspring/theme.dart';
import 'package:intl/intl.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/widgets/pain_mapping_widget.dart';
import 'package:uuid/uuid.dart';

class AddEntryScreen extends StatefulWidget {
  /// When [existing] is provided, the screen works in "Edit" mode,
  /// pre-filling fields and updating the entry instead of creating one.
  const AddEntryScreen({super.key, this.existing});

  final TrackerEntry? existing;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _trackerService = TrackerService();
  final _healthService = HealthService();
  final _blueprintService = RecoveryBlueprintService();
  final _notesController = TextEditingController();
  final _sysController = TextEditingController();
  final _diaController = TextEditingController();
  final _hrController = TextEditingController();
  final _stepsController = TextEditingController();
  final _weightController = TextEditingController();
  final _tempController = TextEditingController();
  bool _saving = false;
  bool _importingHealth = false;
  RecoveryBlueprint? _blueprint;
  bool _loadingBlueprint = true;

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

  // Structured context (stored in entry.customFields)
  final Map<String, MedicationLog> _medicationLogsByName = {};
  final Map<String, SymptomLog> _symptomLogsByName = {};
  final Map<String, TriggerLog> _triggerLogsByName = {};
  final Map<String, ActivityLog> _activityLogsByName = {};

  // Suggestions (derived from previously saved entries)
  String? _suggestionsForUserId;
  bool _loadingSuggestions = false;
  List<String> _medicationSuggestions = const [];
  List<String> _symptomSuggestions = const [];
  List<String> _triggerSuggestions = const [];
  List<String> _activitySuggestions = const [];

  final List<String> _moodOptions = ['😊', '😐', '😔', '😰', '😡'];

  bool _hasAnyMedicationDetails(MedicationLog log) =>
      log.doseMg != null || log.takenAt != null || log.isPrn != null || log.effectScore != null;

  MedicationLog _applyLastTimeToEntryDate(MedicationLog last, DateTime entryDate) {
    if (last.takenAt == null) return last;
    final dt = DateTime.tryParse(last.takenAt!);
    if (dt == null) return last;
    final adjusted = DateTime(entryDate.year, entryDate.month, entryDate.day, dt.hour, dt.minute);
    return MedicationLog(
      name: last.name,
      doseMg: last.doseMg,
      takenAt: adjusted.toIso8601String(),
      isPrn: last.isPrn,
      effectScore: last.effectScore,
    );
  }

  Future<MedicationLog> _getMedicationInitialForEdit(String name) async {
    final existing = _medicationLogsByName[name] ?? MedicationLog(name: name);
    if (_hasAnyMedicationDetails(existing)) return existing;

    final userId = widget.existing?.userId ?? context.read<UserProvider>().currentUser?.id;
    if (userId == null) return existing;

    final last = await _trackerService.getLastMedicationLog(
      userId,
      name,
      before: _selectedDate,
      excludeEntryId: widget.existing?.id,
    );
    if (last == null) return existing;

    // Keep the label/name the user is editing, but prefill the other fields.
    final adjusted = _applyLastTimeToEntryDate(last, _selectedDate);
    return MedicationLog(
      name: name,
      doseMg: adjusted.doseMg,
      takenAt: adjusted.takenAt,
      isPrn: adjusted.isPrn,
      effectScore: adjusted.effectScore,
    );
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

  @override
  void initState() {
    super.initState();
    _loadBlueprint();
    // Prefill values when editing
    final e = widget.existing;
    if (e != null) {
      _selectedDate = e.date;
      _painLevel = e.painLevel;
      _painMap = e.painMap != null ? List.from(e.painMap!) : [];
      _mood = e.mood;
      _spasmFrequency = e.spasmFrequency;
      _bladderSuccess = e.bladderSuccess;
      _bowelProgram = e.bowelProgram;
      _sleepQuality = e.sleepQuality;
      _energyLevel = e.energyLevel;
      _systolicBP = e.systolicBP;
      _diastolicBP = e.diastolicBP;
      _heartRate = e.heartRate;
      _steps = e.steps;
      _weight = e.weight;
      _temperature = e.temperature;
      _medications = e.medications != null ? List.from(e.medications!) : [];
      _symptoms = e.symptoms != null ? List.from(e.symptoms!) : [];
      _triggers = e.triggers != null ? List.from(e.triggers!) : [];
      _activities = e.activities != null ? List.from(e.activities!) : [];

      // Structured logs (back-compat: if missing, we'll seed from string lists)
      final meds = e.medicationLogs ??
          _medications.map((n) => MedicationLog(name: n)).toList();
      for (final m in meds) {
        if (m.name.trim().isEmpty) continue;
        _medicationLogsByName[m.name] = m;
      }
      final syms =
          e.symptomLogs ?? _symptoms.map((n) => SymptomLog(name: n)).toList();
      for (final s in syms) {
        if (s.name.trim().isEmpty) continue;
        _symptomLogsByName[s.name] = s;
      }
      final trigs =
          e.triggerLogs ?? _triggers.map((n) => TriggerLog(name: n)).toList();
      for (final t in trigs) {
        if (t.name.trim().isEmpty) continue;
        _triggerLogsByName[t.name] = t;
      }
      final acts = e.activityLogs ??
          _activities.map((n) => ActivityLog(name: n)).toList();
      for (final a in acts) {
        if (a.name.trim().isEmpty) continue;
        _activityLogsByName[a.name] = a;
      }
      _notesController.text = e.notes ?? '';
      if (_systolicBP != null) _sysController.text = _systolicBP.toString();
      if (_diastolicBP != null) _diaController.text = _diastolicBP.toString();
      if (_heartRate != null) _hrController.text = _heartRate.toString();
      if (_steps != null) _stepsController.text = _steps.toString();
      if (_weight != null) _weightController.text = _weight.toString();
      if (_temperature != null) _tempController.text = _temperature.toString();
    }
  }

  void _syncLogsWithNames() {
    // Remove logs that no longer exist in the selected string lists.
    final medsSet = _medications.toSet();
    _medicationLogsByName.removeWhere((k, _) => !medsSet.contains(k));
    for (final n in _medications) {
      _medicationLogsByName.putIfAbsent(n, () => MedicationLog(name: n));
    }

    final symSet = _symptoms.toSet();
    _symptomLogsByName.removeWhere((k, _) => !symSet.contains(k));
    for (final n in _symptoms) {
      _symptomLogsByName.putIfAbsent(n, () => SymptomLog(name: n));
    }

    final trigSet = _triggers.toSet();
    _triggerLogsByName.removeWhere((k, _) => !trigSet.contains(k));
    for (final n in _triggers) {
      _triggerLogsByName.putIfAbsent(n, () => TriggerLog(name: n));
    }

    final actSet = _activities.toSet();
    _activityLogsByName.removeWhere((k, _) => !actSet.contains(k));
    for (final n in _activities) {
      _activityLogsByName.putIfAbsent(n, () => ActivityLog(name: n));
    }
  }

  Map<String, dynamic>? _buildCustomFieldsForSave() {
    final base = widget.existing?.customFields;
    final merged = <String, dynamic>{
      ...(base == null ? <String, dynamic>{} : Map<String, dynamic>.from(base))
    };
    merged['medicationLogs'] =
        _medicationLogsByName.values.map((e) => e.toJson()).toList();
    merged['symptomLogs'] =
        _symptomLogsByName.values.map((e) => e.toJson()).toList();
    merged['triggerLogs'] =
        _triggerLogsByName.values.map((e) => e.toJson()).toList();
    merged['activityLogs'] =
        _activityLogsByName.values.map((e) => e.toJson()).toList();
    return merged;
  }

  Future<void> _loadBlueprint() async {
    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) {
      setState(() => _loadingBlueprint = false);
      return;
    }
    try {
      final blueprint = await _blueprintService.getByUserId(userId);
      if (mounted) {
        setState(() {
          _blueprint = blueprint;
          _loadingBlueprint = false;
        });
      }
    } catch (e) {
      debugPrint('AddEntryScreen._loadBlueprint error: $e');
      if (mounted) setState(() => _loadingBlueprint = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoadSuggestions();
  }

  bool _shouldShowSection(String sectionType) {
    // Always show core sections
    if (['pain', 'mood', 'vitals', 'medications', 'notes'].contains(sectionType)) {
      return true;
    }

    final user = context.read<UserProvider>().currentUser;
    final conditions = user?.conditions ?? [];

    // Show bladder/bowel for spinal cord injury patients
    if (['bladder', 'bowel'].contains(sectionType)) {
      return conditions.any((c) => 
        c.toLowerCase().contains('spinal') || 
        c.toLowerCase().contains('sci') ||
        c.toLowerCase().contains('neurogenic'));
    }

    // Show spasm tracking for certain neurological conditions
    if (sectionType == 'spasm') {
      return conditions.any((c) => 
        c.toLowerCase().contains('spinal') || 
        c.toLowerCase().contains('sci') ||
        c.toLowerCase().contains('multiple sclerosis') ||
        c.toLowerCase().contains('cerebral palsy'));
    }

    // Show activities for all rehabilitation patients
    if (sectionType == 'activities') {
      return _blueprint?.patientProfile.recoveryPhase != null;
    }

    return true; // Show by default
  }

  String _getPersonalizedTitle() {
    final user = context.read<UserProvider>().currentUser;
    final isEditing = widget.existing != null;
    
    if (isEditing) return 'Edit Entry';
    
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Morning Check-In';
    } else if (hour < 17) {
      greeting = 'Afternoon Update';
    } else {
      greeting = 'Evening Log';
    }
    
    return greeting;
  }

  Future<void> _importAppleHealthData() async {
    if (_importingHealth) return;
    setState(() => _importingHealth = true);
    try {
      final data = await _healthService.getTodayHealthData();
      if (!mounted) return;
      
      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No health data available. Make sure Apple Health is connected.')),
        );
        return;
      }

      // Update the form fields with the imported data
      if (data['steps'] != null) {
        _steps = data['steps'] as int;
        _stepsController.text = _steps.toString();
      }
      if (data['heartRate'] != null) {
        _heartRate = data['heartRate'] as int;
        _hrController.text = _heartRate.toString();
      }
      if (data['systolicBP'] != null) {
        _systolicBP = data['systolicBP'] as int;
        _sysController.text = _systolicBP.toString();
      }
      if (data['diastolicBP'] != null) {
        _diastolicBP = data['diastolicBP'] as int;
        _diaController.text = _diastolicBP.toString();
      }
      if (data['weight'] != null) {
        _weight = data['weight'] as double;
        _weightController.text = _weight!.toStringAsFixed(1);
      }
      if (data['temperature'] != null) {
        _temperature = data['temperature'] as double;
        _tempController.text = _temperature!.toStringAsFixed(1);
      }
      if (data['sleepQuality'] != null) {
        _sleepQuality = data['sleepQuality'] as int;
      }

      setState(() {});

      final importedFields = <String>[];
      if (data['steps'] != null) importedFields.add('steps');
      if (data['heartRate'] != null) importedFields.add('heart rate');
      if (data['systolicBP'] != null) importedFields.add('blood pressure');
      if (data['weight'] != null) importedFields.add('weight');
      if (data['temperature'] != null) importedFields.add('temperature');
      if (data['sleepQuality'] != null) importedFields.add('sleep quality');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported: ${importedFields.join(', ')}')),
        );
      }
    } catch (e) {
      debugPrint('AddEntryScreen._importAppleHealthData error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to import health data')),
        );
      }
    } finally {
      if (mounted) setState(() => _importingHealth = false);
    }
  }

  Future<void> _maybeLoadSuggestions({bool force = false}) async {
    final userId =
        widget.existing?.userId ?? context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;
    if (_loadingSuggestions) return;
    if (!force &&
        _suggestionsForUserId == userId &&
        _medicationSuggestions.isNotEmpty) return;

    setState(() {
      _loadingSuggestions = true;
      _suggestionsForUserId = userId;
    });

    try {
      final meds = await _trackerService.getSuggestionsForKind(
          userId, TrackerSuggestionKind.medications);
      final symptoms = await _trackerService.getSuggestionsForKind(
          userId, TrackerSuggestionKind.symptoms);
      final triggers = await _trackerService.getSuggestionsForKind(
          userId, TrackerSuggestionKind.triggers);
      final activities = await _trackerService.getSuggestionsForKind(
          userId, TrackerSuggestionKind.activities);
      if (!mounted) return;
      setState(() {
        _medicationSuggestions = meds;
        _symptomSuggestions = symptoms;
        _triggerSuggestions = triggers;
        _activitySuggestions = activities;
      });
    } catch (e) {
      debugPrint('AddEntryScreen: failed to load suggestions: $e');
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _saveEntry() async {
    if (_saving) return;
    final userId =
        widget.existing?.userId ?? context.read<UserProvider>().currentUser?.id;

    if (userId == null) {
      // Not signed in — show a helpful message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save entries.')),
      );
      return;
    }

    setState(() => _saving = true);
    
    // Save notes as plain text (no encryption)
    final plaintext = _notesController.text.trim();
    
    try {
      // Keep structured logs consistent with the selected tag strings.
      _syncLogsWithNames();

      if (widget.existing != null) {
        // Update existing entry
        final updated = TrackerEntry(
          id: widget.existing!.id,
          userId: widget.existing!.userId,
          date: _selectedDate,
          // Apply sensible defaults if the user didn't adjust the sliders
          painLevel: _painLevel ?? widget.existing!.painLevel ?? 5,
          painMap: _painMap.isEmpty ? null : _painMap,
          mood: _mood,
          spasmFrequency: _spasmFrequency,
          bladderSuccess: _bladderSuccess,
          bowelProgram: _bowelProgram,
          sleepQuality: _sleepQuality ?? widget.existing!.sleepQuality ?? 5,
          energyLevel: _energyLevel ?? widget.existing!.energyLevel ?? 5,
          systolicBP: _systolicBP,
          diastolicBP: _diastolicBP,
          heartRate: _heartRate,
          steps: _steps,
          weight: _weight,
          temperature: _temperature,
          medications: _medications.isEmpty ? null : _medications,
          symptoms: _symptoms.isEmpty ? null : _symptoms,
          triggers: _triggers.isEmpty ? null : _triggers,
          activities: _activities.isEmpty ? null : _activities,
          medicationLogs: _medicationLogsByName.values.toList(),
          symptomLogs: _symptomLogsByName.values.toList(),
          triggerLogs: _triggerLogsByName.values.toList(),
          activityLogs: _activityLogsByName.values.toList(),
          customFields: _buildCustomFieldsForSave(),
          notes: plaintext.isEmpty ? null : plaintext,
          createdAt: widget.existing!.createdAt,
          updatedAt: DateTime.now(),
        );
        await _trackerService.updateEntry(updated);
        if (mounted) {
          context.pop<TrackerEntry>(updated);
        }
      } else {
        // Create new entry
        final defaultPain = _painLevel ?? 5;
        final defaultSleep = _sleepQuality ?? 5;
        final defaultEnergy = _energyLevel ?? 5;
        final newId = const Uuid().v4();
        final entry = TrackerEntry(
          id: newId,
          userId: userId,
          date: _selectedDate,
          painLevel: defaultPain,
          painMap: _painMap.isEmpty ? null : _painMap,
          mood: _mood,
          spasmFrequency: _spasmFrequency,
          bladderSuccess: _bladderSuccess,
          bowelProgram: _bowelProgram,
          sleepQuality: defaultSleep,
          energyLevel: defaultEnergy,
          systolicBP: _systolicBP,
          diastolicBP: _diastolicBP,
          heartRate: _heartRate,
          steps: _steps,
          weight: _weight,
          temperature: _temperature,
          medications: _medications.isEmpty ? null : _medications,
          symptoms: _symptoms.isEmpty ? null : _symptoms,
          triggers: _triggers.isEmpty ? null : _triggers,
          activities: _activities.isEmpty ? null : _activities,
          medicationLogs: _medicationLogsByName.values.toList(),
          symptomLogs: _symptomLogsByName.values.toList(),
          triggerLogs: _triggerLogsByName.values.toList(),
          activityLogs: _activityLogsByName.values.toList(),
          customFields: _buildCustomFieldsForSave(),
          notes: plaintext.isEmpty ? null : plaintext,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        // Notes are already included in entry object
        await _trackerService.addEntry(entry);
        if (mounted) {
          context.pop<TrackerEntry>(entry);
        }
      }
    } catch (e) {
      if (!mounted) return;
      // Surface error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save entry: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_getPersonalizedTitle()),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveEntry,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: InlineLoadingDot(),
                  )
                : Text('Save', style: context.textStyles.titleMedium?.semiBold),
          ),
        ],
      ),
      body: _loadingBlueprint
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user != null) ...[
              _buildWelcomeCard(user.name),
              SizedBox(height: AppSpacing.lg),
            ],
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
              child: Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Theme.of(context).colorScheme.primary),
                    SizedBox(width: AppSpacing.md),
                    Text(
                      DateFormat('MMMM dd, yyyy').format(_selectedDate),
                      style: context.textStyles.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
              OutlinedButton.icon(
                onPressed: _importingHealth ? null : _importAppleHealthData,
                icon: _importingHealth
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: InlineLoadingDot(),
                      )
                    : Icon(Icons.watch, color: Theme.of(context).colorScheme.primary),
                label: Text(_importingHealth ? 'Importing...' : 'Import from Apple Watch'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            SizedBox(height: AppSpacing.lg),
            if (_shouldShowSection('pain'))
              _buildSection(
                'Pain Level',
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 12,
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: (_painLevel ?? 5).toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: _painLevel?.toString() ?? '5',
                  onChanged: (value) =>
                      setState(() => _painLevel = value.toInt()),
                ),
              ),
            ),

            if (_shouldShowSection('pain')) ...{
              // Pain mapping widget
              PainMappingWidget(
                initialPainMap: _painMap,
                onChanged: (painMap) => setState(() => _painMap = painMap),
              ),
              SizedBox(height: AppSpacing.lg),
            },
            if (_shouldShowSection('mood'))
              _buildSection(
                'Mood',
              Wrap(
                spacing: AppSpacing.sm,
                children: _moodOptions.map((emoji) {
                  final selected = _mood == emoji;
                  return ChoiceChip(
                    label: Text(emoji, style: const TextStyle(fontSize: 22)),
                    selected: selected,
                    onSelected: (v) => setState(() => _mood = v ? emoji : null),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    selectedColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: context.textStyles.titleMedium?.withColor(
                      selected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              ),
            if (_shouldShowSection('bladder'))
              _buildSection(
                'Bladder Management',
              _BladderSection(
                bladderSuccess: _bladderSuccess,
                onChanged: (value) => setState(() => _bladderSuccess = value),
              ),
              ),
            if (_shouldShowSection('bowel'))
              _buildSection(
                'Bowel Program',
              _BowelSection(
                bowelProgram: _bowelProgram,
                onChanged: (value) => setState(() => _bowelProgram = value),
              ),
              ),
            if (_shouldShowSection('spasm'))
              _buildSection(
                'Spasm Tracking',
              _SpasmSection(
                spasmFrequency: _spasmFrequency,
                onChanged: (value) => setState(() => _spasmFrequency = value),
              ),
            ),
            if (_shouldShowSection('sleep'))
              _buildSection(
                'Sleep Hours (1-10)',
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 10,
                  activeTrackColor: Theme.of(context).colorScheme.tertiary,
                  inactiveTrackColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: (_sleepQuality ?? 5).toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${_sleepQuality ?? 5}h',
                  onChanged: (value) =>
                      setState(() => _sleepQuality = value.toInt()),
                ),
              ),
            ),
            if (_shouldShowSection('energy'))
              _buildSection(
                'Energy Level (1-10)',
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 10,
                  activeTrackColor: Theme.of(context).colorScheme.secondary,
                  inactiveTrackColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: (_energyLevel ?? 5).toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: _energyLevel?.toString() ?? '5',
                  onChanged: (value) =>
                      setState(() => _energyLevel = value.toInt()),
                ),
              ),
            ),
            if (_shouldShowSection('vitals'))
              _buildSection(
                'Blood Pressure',
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sysController,
                          decoration: InputDecoration(
                            labelText: 'Systolic (mmHg)',
                            prefixIcon:
                                const Icon(Icons.monitor_heart_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) =>
                              setState(() => _systolicBP = int.tryParse(v)),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _diaController,
                          decoration: InputDecoration(
                            labelText: 'Diastolic (mmHg)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) =>
                              setState(() => _diastolicBP = int.tryParse(v)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _hrController,
                    decoration: InputDecoration(
                      labelText: 'Heart Rate (bpm) — optional',
                      prefixIcon: const Icon(Icons.favorite_border),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        setState(() => _heartRate = int.tryParse(v)),
                  ),
                ],
              ),
            ),
            if (_shouldShowSection('vitals'))
              _buildSection(
                'Steps',
              TextField(
                controller: _stepsController,
                decoration: InputDecoration(
                  hintText: 'Number of steps today',
                  prefixIcon: const Icon(Icons.directions_walk),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) =>
                    setState(() => _steps = int.tryParse(value)),
              ),
            ),
            if (_shouldShowSection('vitals'))
              _buildSection(
                'Weight & Temperature',
              Column(
                children: [
                  TextField(
                    controller: _weightController,
                    decoration: InputDecoration(
                      labelText: 'Weight (Lb)',
                      prefixIcon: const Icon(Icons.scale_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) =>
                        setState(() => _weight = double.tryParse(v)),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _tempController,
                    decoration: InputDecoration(
                      labelText: 'Temperature (°C)',
                      prefixIcon: const Icon(Icons.thermostat_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) =>
                        setState(() => _temperature = double.tryParse(v)),
                  ),
                ],
              ),
            ),
            if (_shouldShowSection('medications'))
              _buildSection(
                'Medications',
              _TagWithDetailsSection(
                kindLabel: 'Medication',
                items: _medications,
                onChanged: (items) => setState(() {
                  _medications = items;
                  _syncLogsWithNames();
                }),
                hintText: 'Add medication',
                icon: Icons.medication_outlined,
                suggestions: _medicationSuggestions,
                onExcludeSuggestion: _suggestionsForUserId == null
                    ? null
                    : (s) async {
                        await _trackerService.excludeSuggestion(
                          _suggestionsForUserId!,
                          TrackerSuggestionKind.medications,
                          s,
                        );
                        if (!mounted) return;
                        setState(() => _medicationSuggestions =
                            _medicationSuggestions
                                .where((x) => x != s)
                                .toList());
                        await _maybeLoadSuggestions(force: true);
                      },
                buildDetailsSummary: (name) => _MedicationDetailsSummary(
                    log: _medicationLogsByName[name] ??
                        MedicationLog(name: name)),
                onEditDetails: (name) async {
                  final initial = await _getMedicationInitialForEdit(name);
                  if (!mounted) return;
                  final edited = await showModalBottomSheet<MedicationLog>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (context) => _MedicationDetailsSheet(
                      name: name,
                      initial: initial,
                      entryDate: _selectedDate,
                    ),
                  );
                  if (edited == null || !mounted) return;
                  setState(() {
                    _medicationLogsByName[name] = edited;
                  });
                },
              ),
            ),
            if (_shouldShowSection('symptoms'))
              _buildSection(
                'Symptoms',
              _TagWithDetailsSection(
                kindLabel: 'Symptom',
                items: _symptoms,
                onChanged: (items) => setState(() {
                  _symptoms = items;
                  _syncLogsWithNames();
                }),
                hintText: 'Add symptom',
                icon: Icons.sick_outlined,
                suggestions: _symptomSuggestions,
                onExcludeSuggestion: _suggestionsForUserId == null
                    ? null
                    : (s) async {
                        await _trackerService.excludeSuggestion(
                          _suggestionsForUserId!,
                          TrackerSuggestionKind.symptoms,
                          s,
                        );
                        if (!mounted) return;
                        setState(() => _symptomSuggestions =
                            _symptomSuggestions.where((x) => x != s).toList());
                        await _maybeLoadSuggestions(force: true);
                      },
                buildDetailsSummary: (name) => _SymptomDetailsSummary(
                    log: _symptomLogsByName[name] ?? SymptomLog(name: name)),
                onEditDetails: (name) async {
                  final existing =
                      _symptomLogsByName[name] ?? SymptomLog(name: name);
                  final edited = await showModalBottomSheet<SymptomLog>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (context) => _SymptomDetailsSheet(
                      name: name,
                      initial: existing,
                      entryDate: _selectedDate,
                    ),
                  );
                  if (edited == null || !mounted) return;
                  setState(() {
                    _symptomLogsByName[name] = edited;
                  });
                },
              ),
            ),
            if (_shouldShowSection('triggers'))
              _buildSection(
                'Triggers',
              _TagWithDetailsSection(
                kindLabel: 'Trigger',
                items: _triggers,
                onChanged: (items) => setState(() {
                  _triggers = items;
                  _syncLogsWithNames();
                }),
                hintText: 'Add trigger',
                icon: Icons.warning_amber_outlined,
                suggestions: _triggerSuggestions,
                onExcludeSuggestion: _suggestionsForUserId == null
                    ? null
                    : (s) async {
                        await _trackerService.excludeSuggestion(
                          _suggestionsForUserId!,
                          TrackerSuggestionKind.triggers,
                          s,
                        );
                        if (!mounted) return;
                        setState(() => _triggerSuggestions =
                            _triggerSuggestions.where((x) => x != s).toList());
                        await _maybeLoadSuggestions(force: true);
                      },
                buildDetailsSummary: (name) => _TriggerDetailsSummary(
                    log: _triggerLogsByName[name] ?? TriggerLog(name: name)),
                onEditDetails: (name) async {
                  final existing =
                      _triggerLogsByName[name] ?? TriggerLog(name: name);
                  final edited = await showModalBottomSheet<TriggerLog>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (context) =>
                        _TriggerDetailsSheet(name: name, initial: existing),
                  );
                  if (edited == null || !mounted) return;
                  setState(() {
                    _triggerLogsByName[name] = edited;
                  });
                },
              ),
            ),
            if (_shouldShowSection('activities'))
              _buildSection(
                'Activities',
              _TagWithDetailsSection(
                kindLabel: 'Activity',
                items: _activities,
                onChanged: (items) => setState(() {
                  _activities = items;
                  _syncLogsWithNames();
                }),
                hintText: 'Add activity',
                icon: Icons.local_activity_outlined,
                suggestions: _activitySuggestions,
                onExcludeSuggestion: _suggestionsForUserId == null
                    ? null
                    : (s) async {
                        await _trackerService.excludeSuggestion(
                          _suggestionsForUserId!,
                          TrackerSuggestionKind.activities,
                          s,
                        );
                        if (!mounted) return;
                        setState(() => _activitySuggestions =
                            _activitySuggestions.where((x) => x != s).toList());
                        await _maybeLoadSuggestions(force: true);
                      },
                buildDetailsSummary: (name) => _ActivityDetailsSummary(
                    log: _activityLogsByName[name] ?? ActivityLog(name: name)),
                onEditDetails: (name) async {
                  final existing =
                      _activityLogsByName[name] ?? ActivityLog(name: name);
                  final edited = await showModalBottomSheet<ActivityLog>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (context) =>
                        _ActivityDetailsSheet(name: name, initial: existing),
                  );
                  if (edited == null || !mounted) return;
                  setState(() {
                    _activityLogsByName[name] = edited;
                  });
                },
              ),
            ),
            if (_shouldShowSection('notes'))
              _buildSection(
                'Notes',
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Add any additional notes...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                maxLines: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textStyles.titleMedium?.semiBold),
          SizedBox(height: AppSpacing.sm),
          child,
          SizedBox(height: AppSpacing.lg),
        ],
      );

  Widget _buildWelcomeCard(String userName) {
    final cs = Theme.of(context).colorScheme;
    final firstName = userName.split(' ').first;
    final phase = _blueprint?.patientProfile.recoveryPhase;
    
    String subtitle = 'Track your progress for today';
    if (phase != null) {
      subtitle = 'Tracking your ${phase.label.toLowerCase()} recovery';
    }

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer,
            cs.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: cs.primary,
                  size: 28,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, $firstName!',
                      style: context.textStyles.titleLarge?.semiBold.withColor(
                        cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: context.textStyles.bodyMedium?.withColor(
                        cs.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_blueprint != null && _blueprint!.patientProfile.therapyGoals.isNotEmpty) ...{
            SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: cs.primary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Today\'s focus: ${_blueprint!.patientProfile.therapyGoals.first}',
                      style: context.textStyles.bodySmall?.semiBold.withColor(
                        cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          },
        ],
      ),
    );
  }
}

class _ChipInputField extends StatefulWidget {
  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  final String hintText;
  final IconData icon;
  final List<String> suggestions;
  final Future<void> Function(String suggestion)? onExcludeSuggestion;

  const _ChipInputField({
    required this.items,
    required this.onChanged,
    required this.hintText,
    required this.icon,
    this.suggestions = const [],
    this.onExcludeSuggestion,
  });

  @override
  State<_ChipInputField> createState() => _ChipInputFieldState();
}

class _ChipInputFieldState extends State<_ChipInputField> {
  final _controller = TextEditingController();
  String _query = '';
  bool _excluding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addItem() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.items.contains(text)) {
      widget.onChanged([...widget.items, text]);
      _controller.clear();
      setState(() => _query = '');
    }
  }

  void _addSuggestion(String suggestion) {
    final cleaned = suggestion.trim();
    if (cleaned.isEmpty || widget.items.contains(cleaned)) return;
    widget.onChanged([...widget.items, cleaned]);
    _controller.clear();
    setState(() => _query = '');
  }

  void _removeItem(String item) {
    widget.onChanged(widget.items.where((i) => i != item).toList());
  }

  Future<void> _excludeSuggestion(String suggestion) async {
    final cb = widget.onExcludeSuggestion;
    if (cb == null || _excluding) return;
    setState(() => _excluding = true);
    try {
      await cb(suggestion);
    } catch (e) {
      debugPrint('ChipInputField: failed to exclude suggestion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not remove suggestion. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _excluding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestionsToShow = widget.suggestions
        .where((s) => !widget.items.contains(s))
        .where((s) =>
            _query.isEmpty || s.toLowerCase().contains(_query.toLowerCase()))
        .take(10)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: Icon(widget.icon),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addItem,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          onSubmitted: (_) => _addItem(),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
        if (suggestionsToShow.isNotEmpty) ...[
          SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: suggestionsToShow
                .map((s) => InputChip(
                      label: Text(s, overflow: TextOverflow.ellipsis),
                      labelStyle: Theme.of(context).textTheme.labelLarge,
                      avatar: Icon(
                        Icons.add_circle_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      deleteIcon: _excluding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.close, size: 18),
                      onDeleted: widget.onExcludeSuggestion == null
                          ? null
                          : () => _excludeSuggestion(s),
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      onPressed: () => _addSuggestion(s),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.35),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
        if (widget.items.isNotEmpty) ...[
          SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: widget.items
                .map((item) => Chip(
                      label: Text(item),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => _removeItem(item),
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      labelStyle: context.textStyles.bodySmall?.withColor(
                        Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _TagWithDetailsSection extends StatelessWidget {
  final String kindLabel;
  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  final String hintText;
  final IconData icon;
  final List<String> suggestions;
  final Future<void> Function(String suggestion)? onExcludeSuggestion;
  final Widget Function(String name) buildDetailsSummary;
  final Future<void> Function(String name) onEditDetails;

  const _TagWithDetailsSection({
    required this.kindLabel,
    required this.items,
    required this.onChanged,
    required this.hintText,
    required this.icon,
    required this.suggestions,
    required this.onExcludeSuggestion,
    required this.buildDetailsSummary,
    required this.onEditDetails,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChipInputField(
          items: items,
          onChanged: onChanged,
          hintText: hintText,
          icon: icon,
          suggestions: suggestions,
          onExcludeSuggestion: onExcludeSuggestion,
        ),
        if (items.isNotEmpty) ...[
          SizedBox(height: AppSpacing.md),
          Text(
            'Add context (optional)',
            style:
                context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
          ),
          SizedBox(height: AppSpacing.sm),
          ...items.map((name) {
            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => onEditDetails(name),
                  child: Padding(
                    padding: AppSpacing.paddingMd,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.tune, color: cs.primary, size: 18),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyles.titleSmall?.semiBold,
                              ),
                              SizedBox(height: 6),
                              buildDetailsSummary(name),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        TextButton.icon(
                          onPressed: () => onEditDetails(name),
                          icon: Icon(Icons.edit_outlined,
                              size: 18, color: cs.primary),
                          label: Text('Details',
                              style: context.textStyles.labelLarge
                                  ?.withColor(cs.primary)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ]
      ],
    );
  }
}

class _MedicationDetailsSummary extends StatelessWidget {
  final MedicationLog log;
  const _MedicationDetailsSummary({required this.log});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = <String>[];
    if (log.doseMg != null) parts.add('${log.doseMg}mg');
    if (log.takenAt != null) {
      final dt = DateTime.tryParse(log.takenAt!);
      if (dt != null) {
        final t = TimeOfDay.fromDateTime(dt);
        parts.add(t.format(context));
      }
    }
    if (log.isPrn != null) parts.add(log.isPrn! ? 'PRN' : 'Scheduled');
    if (log.effectScore != null) parts.add('Helped ${log.effectScore}/5');

    if (parts.isEmpty) {
      return Text(
        'Tap to add dose, time, and effect',
        style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: parts
          .map(
            (p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
              ),
              child: Text(p,
                  style: context.textStyles.labelSmall
                      ?.withColor(cs.onSurfaceVariant)),
            ),
          )
          .toList(),
    );
  }
}

class _SymptomDetailsSummary extends StatelessWidget {
  final SymptomLog log;
  const _SymptomDetailsSummary({required this.log});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = <String>[];
    if (log.intensity != null) parts.add('${log.intensity}/10');
    if (log.durationMin != null) parts.add('${log.durationMin} min');
    if ((log.bodyArea ?? '').trim().isNotEmpty) parts.add(log.bodyArea!.trim());
    if (log.onsetAt != null) {
      final dt = DateTime.tryParse(log.onsetAt!);
      if (dt != null) {
        parts.add('Started ${TimeOfDay.fromDateTime(dt).format(context)}');
      }
    }
    if (parts.isEmpty) {
      return Text(
        'Tap to add severity, duration, and onset',
        style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: parts
          .map(
            (p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
              ),
              child: Text(p,
                  style: context.textStyles.labelSmall
                      ?.withColor(cs.onSurfaceVariant)),
            ),
          )
          .toList(),
    );
  }
}

class _TriggerDetailsSummary extends StatelessWidget {
  final TriggerLog log;
  const _TriggerDetailsSummary({required this.log});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = <String>[];
    if (log.temperatureF != null) parts.add('${log.temperatureF}\u00B0F');
    if (log.durationMin != null) parts.add('${log.durationMin} min');
    if (log.jacket == true) parts.add('Jacket');
    if (log.gloves == true) parts.add('Gloves');
    if (parts.isEmpty) {
      return Text(
        'Tap to add exposure strength',
        style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: parts
          .map(
            (p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
              ),
              child: Text(p,
                  style: context.textStyles.labelSmall
                      ?.withColor(cs.onSurfaceVariant)),
            ),
          )
          .toList(),
    );
  }
}

class _ActivityDetailsSummary extends StatelessWidget {
  final ActivityLog log;
  const _ActivityDetailsSummary({required this.log});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = <String>[];
    if ((log.purpose ?? '').trim().isNotEmpty) parts.add(log.purpose!.trim());
    if (log.distanceMi != null) parts.add('${log.distanceMi} mi');
    if ((log.assist ?? '').trim().isNotEmpty) parts.add(log.assist!.trim());
    if (log.fatigueAfter != null) parts.add('Fatigue ${log.fatigueAfter}/5');
    if (parts.isEmpty) {
      return Text(
        'Tap to add purpose, distance, and fatigue',
        style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: parts
          .map(
            (p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
              ),
              child: Text(p,
                  style: context.textStyles.labelSmall
                      ?.withColor(cs.onSurfaceVariant)),
            ),
          )
          .toList(),
    );
  }
}

class _MedicationDetailsSheet extends StatefulWidget {
  final String name;
  final MedicationLog initial;
  final DateTime entryDate;

  const _MedicationDetailsSheet(
      {required this.name, required this.initial, required this.entryDate});

  @override
  State<_MedicationDetailsSheet> createState() =>
      _MedicationDetailsSheetState();
}

class _MedicationDetailsSheetState extends State<_MedicationDetailsSheet> {
  late final TextEditingController _doseController;
  TimeOfDay? _time;
  bool _isPrn = true;
  int _effect = 0;

  @override
  void initState() {
    super.initState();
    _doseController =
        TextEditingController(text: widget.initial.doseMg?.toString() ?? '');
    _isPrn = widget.initial.isPrn ?? true;
    _effect = (widget.initial.effectScore ?? 0).clamp(0, 5);
    if (widget.initial.takenAt != null) {
      final dt = DateTime.tryParse(widget.initial.takenAt!);
      if (dt != null) _time = TimeOfDay.fromDateTime(dt);
    }
  }

  @override
  void dispose() {
    _doseController.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime date, TimeOfDay tod) =>
      DateTime(date.year, date.month, date.day, tod.hour, tod.minute);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.sm,
          bottom: bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medication_outlined, color: cs.primary),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(widget.name,
                    style: context.textStyles.titleLarge?.semiBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text('Dose + timing + effect (optional)',
              style:
                  context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
          SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _doseController,
            decoration: InputDecoration(
              labelText: 'Dose (mg)',
              prefixIcon: const Icon(Icons.science_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                        context: context,
                        initialTime: _time ?? TimeOfDay.now());
                    if (picked == null) return;
                    setState(() => _time = picked);
                  },
                  icon: Icon(Icons.schedule, color: cs.primary),
                  label: Text(
                      _time == null ? 'Time taken' : _time!.format(context)),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('PRN (as needed)'),
            subtitle: Text(_isPrn ? 'Taken as needed' : 'Taken on schedule',
                style: context.textStyles.bodySmall
                    ?.withColor(cs.onSurfaceVariant)),
            value: _isPrn,
            onChanged: (v) => setState(() => _isPrn = v),
          ),
          SizedBox(height: AppSpacing.sm),
          Text('Helped after 1–3 hours?',
              style: context.textStyles.titleSmall?.semiBold),
          SizedBox(height: AppSpacing.xs),
          SliderTheme(
            data: SliderTheme.of(context)
                .copyWith(overlayShape: SliderComponentShape.noOverlay),
            child: Slider(
              min: 0,
              max: 5,
              divisions: 5,
              value: _effect.toDouble(),
              label: '$_effect/5',
              onChanged: (v) => setState(() => _effect = v.round()),
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cancel'))),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final dose = int.tryParse(_doseController.text.trim());
                    final takenAt = _time == null
                        ? null
                        : _combine(widget.entryDate, _time!).toIso8601String();
                    context.pop(MedicationLog(
                        name: widget.name,
                        doseMg: dose,
                        takenAt: takenAt,
                        isPrn: _isPrn,
                        effectScore: _effect));
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SymptomDetailsSheet extends StatefulWidget {
  final String name;
  final SymptomLog initial;
  final DateTime entryDate;

  const _SymptomDetailsSheet(
      {required this.name, required this.initial, required this.entryDate});

  @override
  State<_SymptomDetailsSheet> createState() => _SymptomDetailsSheetState();
}

class _SymptomDetailsSheetState extends State<_SymptomDetailsSheet> {
  late final TextEditingController _durationController;
  late final TextEditingController _bodyAreaController;
  int _intensity = 5;
  TimeOfDay? _onset;

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(
        text: widget.initial.durationMin?.toString() ?? '');
    _bodyAreaController =
        TextEditingController(text: widget.initial.bodyArea ?? '');
    _intensity = (widget.initial.intensity ?? 5).clamp(1, 10);
    if (widget.initial.onsetAt != null) {
      final dt = DateTime.tryParse(widget.initial.onsetAt!);
      if (dt != null) _onset = TimeOfDay.fromDateTime(dt);
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _bodyAreaController.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime date, TimeOfDay tod) =>
      DateTime(date.year, date.month, date.day, tod.hour, tod.minute);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.sm,
          bottom: bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sick_outlined, color: cs.primary),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: Text(widget.name,
                      style: context.textStyles.titleLarge?.semiBold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text('Severity + duration + onset (optional)',
              style:
                  context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
          SizedBox(height: AppSpacing.lg),
          Text('Intensity', style: context.textStyles.titleSmall?.semiBold),
          SliderTheme(
            data: SliderTheme.of(context)
                .copyWith(overlayShape: SliderComponentShape.noOverlay),
            child: Slider(
              min: 1,
              max: 10,
              divisions: 9,
              value: _intensity.toDouble(),
              label: '$_intensity/10',
              onChanged: (v) => setState(() => _intensity = v.round()),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          TextField(
            controller: _durationController,
            decoration: InputDecoration(
              labelText: 'Duration (minutes)',
              prefixIcon: const Icon(Icons.timelapse_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showTimePicker(
                  context: context, initialTime: _onset ?? TimeOfDay.now());
              if (picked == null) return;
              setState(() => _onset = picked);
            },
            icon: Icon(Icons.schedule, color: cs.primary),
            label: Text(_onset == null
                ? 'Onset time'
                : 'Started ${_onset!.format(context)}'),
          ),
          SizedBox(height: AppSpacing.md),
          TextField(
            controller: _bodyAreaController,
            decoration: InputDecoration(
              labelText: 'Body area (optional)',
              prefixIcon: const Icon(Icons.my_location_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            textInputAction: TextInputAction.done,
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cancel'))),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final duration =
                        int.tryParse(_durationController.text.trim());
                    final onsetAt = _onset == null
                        ? null
                        : _combine(widget.entryDate, _onset!).toIso8601String();
                    final bodyArea = _bodyAreaController.text.trim();
                    context.pop(SymptomLog(
                      name: widget.name,
                      intensity: _intensity,
                      durationMin: duration,
                      onsetAt: onsetAt,
                      bodyArea: bodyArea.isEmpty ? null : bodyArea,
                    ));
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TriggerDetailsSheet extends StatefulWidget {
  final String name;
  final TriggerLog initial;

  const _TriggerDetailsSheet({required this.name, required this.initial});

  @override
  State<_TriggerDetailsSheet> createState() => _TriggerDetailsSheetState();
}

class _TriggerDetailsSheetState extends State<_TriggerDetailsSheet> {
  late final TextEditingController _tempController;
  late final TextEditingController _durationController;
  bool _jacket = false;
  bool _gloves = false;

  @override
  void initState() {
    super.initState();
    _tempController = TextEditingController(
        text: widget.initial.temperatureF?.toString() ?? '');
    _durationController = TextEditingController(
        text: widget.initial.durationMin?.toString() ?? '');
    _jacket = widget.initial.jacket ?? false;
    _gloves = widget.initial.gloves ?? false;
  }

  @override
  void dispose() {
    _tempController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.sm,
          bottom: bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: cs.primary),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.name,
                  style: context.textStyles.titleLarge?.semiBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Make the trigger measurable (optional)',
            style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tempController,
                  decoration: InputDecoration(
                    labelText: 'Temp (\u00B0F)',
                    prefixIcon: const Icon(Icons.ac_unit_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _durationController,
                  decoration: InputDecoration(
                    labelText: 'Duration (min)',
                    prefixIcon: const Icon(Icons.timelapse_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          SizedBox(height: AppSpacing.xs),
          Wrap(spacing: 10, runSpacing: 10, children: []),
          SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final temp = int.tryParse(_tempController.text.trim());
                    final duration =
                        int.tryParse(_durationController.text.trim());
                    context.pop(
                      TriggerLog(
                        name: widget.name,
                        temperatureF: temp,
                        durationMin: duration,
                        jacket: _jacket,
                        gloves: _gloves,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BladderSection extends StatelessWidget {
  final bool? bladderSuccess;
  final ValueChanged<bool?> onChanged;

  const _BladderSection({required this.bladderSuccess, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.water_drop_outlined, color: cs.onPrimaryContainer, size: 22),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bladder Management', style: context.textStyles.titleSmall?.semiBold),
                    const SizedBox(height: 2),
                    Text(
                      'Track your bladder management success',
                      style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _BladderOption(
                  icon: Icons.check_circle,
                  label: 'Successful',
                  subtitle: 'No accidents',
                  selected: bladderSuccess == true,
                  onTap: () => onChanged(bladderSuccess == true ? null : true),
                  color: Colors.green,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _BladderOption(
                  icon: Icons.cancel,
                  label: 'Accident',
                  subtitle: 'Had incident',
                  selected: bladderSuccess == false,
                  onTap: () => onChanged(bladderSuccess == false ? null : false),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BladderOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _BladderOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? color : cs.outline.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? color : cs.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: context.textStyles.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? color : cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: context.textStyles.labelSmall?.withColor(
                selected ? color.withValues(alpha: 0.8) : cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BowelSection extends StatelessWidget {
  final bool? bowelProgram;
  final ValueChanged<bool?> onChanged;

  const _BowelSection({required this.bowelProgram, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.healing_outlined, color: cs.onTertiaryContainer, size: 22),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bowel Program', style: context.textStyles.titleSmall?.semiBold),
                    const SizedBox(height: 2),
                    Text(
                      'Record your bowel program completion',
                      style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _BowelOption(
                  icon: Icons.check_circle,
                  label: 'Completed',
                  subtitle: 'Program done',
                  selected: bowelProgram == true,
                  onTap: () => onChanged(bowelProgram == true ? null : true),
                  color: Colors.green,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _BowelOption(
                  icon: Icons.schedule,
                  label: 'Incomplete',
                  subtitle: 'Not finished',
                  selected: bowelProgram == false,
                  onTap: () => onChanged(bowelProgram == false ? null : false),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BowelOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _BowelOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? color : cs.outline.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? color : cs.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: context.textStyles.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? color : cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: context.textStyles.labelSmall?.withColor(
                selected ? color.withValues(alpha: 0.8) : cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpasmSection extends StatelessWidget {
  final int? spasmFrequency;
  final ValueChanged<int?> onChanged;

  const _SpasmSection({required this.spasmFrequency, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final frequency = spasmFrequency ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.flash_on_outlined, color: cs.onSecondaryContainer, size: 22),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spasm Frequency', style: context.textStyles.titleSmall?.semiBold),
                    const SizedBox(height: 2),
                    Text(
                      'Number of spasms experienced today',
                      style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getSpasmColor(frequency).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: _getSpasmColor(frequency).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getSpasmIcon(frequency), color: _getSpasmColor(frequency), size: 32),
                SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$frequency spasms',
                      style: context.textStyles.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getSpasmColor(frequency),
                      ),
                    ),
                    Text(
                      _getSpasmLabel(frequency),
                      style: context.textStyles.bodySmall?.withColor(
                        _getSpasmColor(frequency).withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: _getSpasmColor(frequency),
              inactiveTrackColor: cs.surfaceContainerHighest,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              thumbColor: _getSpasmColor(frequency),
              overlayColor: _getSpasmColor(frequency).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: frequency.toDouble(),
              min: 0,
              max: 20,
              divisions: 20,
              label: '$frequency',
              onChanged: (value) => onChanged(value.toInt()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0', style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant)),
                Text('10', style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant)),
                Text('20', style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getSpasmColor(int frequency) {
    if (frequency == 0) return Colors.green;
    if (frequency <= 5) return Colors.blue;
    if (frequency <= 10) return Colors.orange;
    return Colors.red;
  }

  IconData _getSpasmIcon(int frequency) {
    if (frequency == 0) return Icons.check_circle;
    if (frequency <= 5) return Icons.info;
    if (frequency <= 10) return Icons.warning;
    return Icons.error;
  }

  String _getSpasmLabel(int frequency) {
    if (frequency == 0) return 'No spasms today';
    if (frequency <= 5) return 'Mild activity';
    if (frequency <= 10) return 'Moderate activity';
    return 'High activity';
  }
}

class _ActivityDetailsSheet extends StatefulWidget {
  final String name;
  final ActivityLog initial;

  const _ActivityDetailsSheet({required this.name, required this.initial});

  @override
  State<_ActivityDetailsSheet> createState() => _ActivityDetailsSheetState();
}

class _ActivityDetailsSheetState extends State<_ActivityDetailsSheet> {
  late final TextEditingController _purposeController;
  late final TextEditingController _distanceController;
  late final TextEditingController _assistController;
  int _fatigue = 0;

  @override
  void initState() {
    super.initState();
    _purposeController =
        TextEditingController(text: widget.initial.purpose ?? '');
    _distanceController = TextEditingController(
        text: widget.initial.distanceMi?.toString() ?? '');
    _assistController =
        TextEditingController(text: widget.initial.assist ?? '');
    _fatigue = (widget.initial.fatigueAfter ?? 0).clamp(0, 5);
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _distanceController.dispose();
    _assistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.sm,
          bottom: bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_activity_outlined, color: cs.primary),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: Text(widget.name,
                      style: context.textStyles.titleLarge?.semiBold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text('Functional context (optional)',
              style:
                  context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
          SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _purposeController,
            decoration: InputDecoration(
              labelText: 'Purpose (e.g., walk)',
              prefixIcon: const Icon(Icons.flag_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          TextField(
            controller: _distanceController,
            decoration: InputDecoration(
              labelText: 'Distance (miles)',
              prefixIcon: const Icon(Icons.straighten_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          SizedBox(height: AppSpacing.md),
          TextField(
            controller: _assistController,
            decoration: InputDecoration(
              labelText: 'Assist (e.g., walker)',
              prefixIcon: const Icon(Icons.accessibility_new_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Text('Fatigue after', style: context.textStyles.titleSmall?.semiBold),
          SliderTheme(
            data: SliderTheme.of(context)
                .copyWith(overlayShape: SliderComponentShape.noOverlay),
            child: Slider(
              min: 0,
              max: 5,
              divisions: 5,
              value: _fatigue.toDouble(),
              label: '$_fatigue/5',
              onChanged: (v) => setState(() => _fatigue = v.round()),
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cancel'))),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final purpose = _purposeController.text.trim();
                    final dist =
                        double.tryParse(_distanceController.text.trim());
                    final assist = _assistController.text.trim();
                    context.pop(ActivityLog(
                      name: widget.name,
                      purpose: purpose.isEmpty ? null : purpose,
                      distanceMi: dist,
                      assist: assist.isEmpty ? null : assist,
                      fatigueAfter: _fatigue,
                    ));
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
