import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/models/recovery_blueprint.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/recovery_blueprint_service.dart';
import 'package:wellspring/theme.dart';

/// Public, reusable Daily Care Timeline widget used by both
/// - Patient RecoveryBlueprintDashboard
/// - Family Daily Care Timeline screen
class DailyCareTimeline extends StatefulWidget {
  final List<DailyRoutine> dailyRoutines;
  final String? patientId;

  const DailyCareTimeline({super.key, required this.dailyRoutines, this.patientId});

  @override
  State<DailyCareTimeline> createState() => _DailyCareTimelineState();
}

class _DailyCareTimelineState extends State<DailyCareTimeline> {
  bool _expanded = true;

  Future<void> _addNewRoutine() async {
    final newRoutine = await showDialog<DailyRoutine>(
      context: context,
      builder: (context) => const DailyCareAddRoutineDialog(),
    );

    if (newRoutine == null) return;

    try {
      final userId = widget.patientId ?? Provider.of<UserProvider>(context, listen: false).currentUser?.id;
      if (userId == null) return;

      final blueprintService = RecoveryBlueprintService();
      var blueprint = await blueprintService.getByUserId(userId);

      if (blueprint == null) {
        blueprint = RecoveryBlueprint(
          id: const Uuid().v4(),
          userId: userId,
          patientProfile: const PatientProfile(primaryDiagnosis: 'Unknown', recoveryPhase: RecoveryPhase.postDischarge),
          careTeam: const [],
          independenceAssessment: const IndependenceAssessment(),
          homeReadiness: const HomeReadiness(),
          dailyRoutines: [newRoutine],
          equipment: const [],
          supplies: const [],
          roadmap: const RecoveryRoadmap(
            immediatePriorities: [], shortTermGoals: [], longTermGoals: [], warnings: [],
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await blueprintService.create(blueprint);
      } else {
        final updatedBlueprint = RecoveryBlueprint(
          id: blueprint.id,
          userId: blueprint.userId,
          patientProfile: blueprint.patientProfile,
          careTeam: blueprint.careTeam,
          independenceAssessment: blueprint.independenceAssessment,
          homeReadiness: blueprint.homeReadiness,
          dailyRoutines: [...blueprint.dailyRoutines, newRoutine],
          equipment: blueprint.equipment,
          supplies: blueprint.supplies,
          roadmap: blueprint.roadmap,
          createdAt: blueprint.createdAt,
          updatedAt: DateTime.now(),
        );
        await blueprintService.update(updatedBlueprint);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Routine added successfully')), // Colors OK
        );
        setState(() {});
      }
    } catch (e) {
      debugPrint('DailyCareTimeline: Error saving routine: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving routine: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteRoutine(DailyRoutine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine'),
        content: Text('Are you sure you want to delete the ${routine.type.replaceAll('_', ' ')} routine?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final userId = widget.patientId ?? Provider.of<UserProvider>(context, listen: false).currentUser?.id;
      if (userId == null) return;

      final blueprintService = RecoveryBlueprintService();
      final blueprint = await blueprintService.getByUserId(userId);
      if (blueprint == null) return;

      final updatedRoutines = blueprint.dailyRoutines.where((r) =>
        !(r.type == routine.type && r.timesOfDay.join(',') == routine.timesOfDay.join(',') && r.daysPerformed.join(',') == routine.daysPerformed.join(','))
      ).toList();

      final updatedBlueprint = RecoveryBlueprint(
        id: blueprint.id,
        userId: blueprint.userId,
        patientProfile: blueprint.patientProfile,
        careTeam: blueprint.careTeam,
        independenceAssessment: blueprint.independenceAssessment,
        homeReadiness: blueprint.homeReadiness,
        dailyRoutines: updatedRoutines,
        equipment: blueprint.equipment,
        supplies: blueprint.supplies,
        roadmap: blueprint.roadmap,
        createdAt: blueprint.createdAt,
        updatedAt: DateTime.now(),
      );

      await blueprintService.update(updatedBlueprint);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Routine deleted successfully'), backgroundColor: Colors.green),
        );
        setState(() {});
      }
    } catch (e) {
      debugPrint('DailyCareTimeline: Error deleting routine: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting routine: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final careRoutines = widget.dailyRoutines.where((r) => r.type.toLowerCase() != 'medication').toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F38).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Colors.cyan, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Care Timeline', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('${careRoutines.length} routine${careRoutines.length != 1 ? 's' : ''}', style: context.textStyles.bodySmall?.copyWith(color: Colors.white60)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _addNewRoutine,
                    icon: const Icon(Icons.add_circle, color: Colors.cyan, size: 28),
                    tooltip: 'Add routine',
                    style: IconButton.styleFrom(backgroundColor: Colors.cyan.withValues(alpha: 0.2)),
                  ),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: careRoutines.isEmpty
                  ? Column(
                      children: [
                        Text('No care routines added yet.', style: context.textStyles.bodyMedium?.copyWith(color: Colors.white60)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _addNewRoutine,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Care Routine'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.white),
                        ),
                      ],
                    )
                  : Column(
                      children: careRoutines.map((routine) {
                        Color routineColor = Colors.cyan;
                        IconData routineIcon = Icons.schedule;
                        switch (routine.type.toLowerCase()) {
                          case 'bowel':
                            routineColor = const Color(0xFF9C27B0);
                            routineIcon = Icons.spa;
                            break;
                          case 'bladder':
                            routineColor = const Color(0xFF2196F3);
                            routineIcon = Icons.water_drop;
                            break;
                          case 'skin_check':
                            routineColor = const Color(0xFF00BCD4);
                            routineIcon = Icons.health_and_safety;
                            break;
                          case 'therapy':
                            routineColor = const Color(0xFFFF9800);
                            routineIcon = Icons.fitness_center;
                            break;
                          case 'nutrition':
                            routineColor = const Color(0xFF4CAF50);
                            routineIcon = Icons.restaurant;
                            break;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D2530),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: routineColor.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(routineIcon, size: 20, color: routineColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      routine.type.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
                                      style: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteRoutine(routine),
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    tooltip: 'Delete routine',
                                    color: Colors.red.shade300,
                                    style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
                                  ),
                                ],
                              ),
                              if (routine.timesOfDay.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: routine.timesOfDay.map((time) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: routineColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: routineColor.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.access_time, size: 12, color: routineColor),
                                        const SizedBox(width: 4),
                                        Text(time, style: context.textStyles.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: routineColor)),
                                      ],
                                    ),
                                  )).toList(),
                                ),
                              ],
                              if (routine.daysPerformed.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 4,
                                  children: routine.daysPerformed.map((day) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: routineColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text(day.substring(0, 3).toUpperCase(), style: context.textStyles.labelSmall?.copyWith(color: Colors.white60, fontSize: 10)),
                                  )).toList(),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
        ],
      ),
    );
  }
}

/// Public Add Routine dialog used by DailyCareTimeline
class DailyCareAddRoutineDialog extends StatefulWidget {
  const DailyCareAddRoutineDialog({super.key});

  @override
  State<DailyCareAddRoutineDialog> createState() => _DailyCareAddRoutineDialogState();
}

class _DailyCareAddRoutineDialogState extends State<DailyCareAddRoutineDialog> {
  String _selectedType = 'bowel';
  final _timeControllers = <TextEditingController>[];
  final _selectedDays = <String>{};

  final _routineTypes = const [
    {'value': 'bowel', 'label': 'Bowel Program', 'icon': Icons.spa},
    {'value': 'bladder', 'label': 'Bladder Management', 'icon': Icons.water_drop},
    {'value': 'skin_check', 'label': 'Skin Check', 'icon': Icons.health_and_safety},
    {'value': 'therapy', 'label': 'Therapy', 'icon': Icons.fitness_center},
    {'value': 'nutrition', 'label': 'Nutrition', 'icon': Icons.restaurant},
  ];

  final _days = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _selectedDays.addAll(_days.map((d) => d.toLowerCase()));
    _addTimeField('8:00 AM');
  }

  @override
  void dispose() {
    for (var c in _timeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addTimeField([String? initialTime]) {
    final controller = TextEditingController(text: initialTime ?? '');
    _timeControllers.add(controller);
  }

  void _removeTimeField(int index) {
    setState(() {
      _timeControllers[index].dispose();
      _timeControllers.removeAt(index);
    });
  }

  void _saveRoutine() {
    final times = _timeControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one time'), backgroundColor: Colors.orange));
      return;
    }
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one day'), backgroundColor: Colors.orange));
      return;
    }
    final routine = DailyRoutine(type: _selectedType, daysPerformed: _selectedDays.toList(), timesOfDay: times, suppliesNeeded: const []);
    Navigator.of(context).pop(routine);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: const Color(0xFF1A2F38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.add_circle_outline, color: Colors.cyan, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Add Care Routine', style: context.textStyles.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Routine Type', style: context.textStyles.titleSmall?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _routineTypes.map((type) {
                        final isSelected = _selectedType == type['value'];
                        return FilterChip(
                          label: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(type['icon'] as IconData, size: 16, color: isSelected ? Colors.white : Colors.white60),
                            const SizedBox(width: 6),
                            Text(type['label'] as String),
                          ]),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedType = type['value'] as String),
                          selectedColor: Colors.cyan,
                          backgroundColor: const Color(0xFF0D2530),
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white60),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text('Times', style: context.textStyles.titleSmall?.copyWith(color: Colors.white70)),
                        const Spacer(),
                        TextButton.icon(onPressed: () => setState(() => _addTimeField()), icon: const Icon(Icons.add, size: 16), label: const Text('Add Time'), style: TextButton.styleFrom(foregroundColor: Colors.cyan)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._timeControllers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final controller = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                hintText: '8:00 AM',
                                filled: true,
                                fillColor: const Color(0xFF0D2530),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.cyan.withValues(alpha: 0.3))),
                                hintStyle: const TextStyle(color: Colors.white30),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          if (_timeControllers.length > 1) ...[
                            const SizedBox(width: 8),
                            IconButton(onPressed: () => _removeTimeField(index), icon: const Icon(Icons.remove_circle_outline, color: Colors.red)),
                          ],
                        ]),
                      );
                    }),
                    const SizedBox(height: 24),
                    Text('Days of Week', style: context.textStyles.titleSmall?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _days.map((day) {
                        final dayLower = day.toLowerCase();
                        final isSelected = _selectedDays.contains(dayLower);
                        return FilterChip(
                          label: Text(day.substring(0, 3)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedDays.add(dayLower);
                              } else {
                                _selectedDays.remove(dayLower);
                              }
                            });
                          },
                          selectedColor: Colors.cyan,
                          backgroundColor: const Color(0xFF0D2530),
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white60),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.3)), padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(onPressed: _saveRoutine, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Save Routine'))),
            ]),
          ],
        ),
      ),
    );
  }
}
