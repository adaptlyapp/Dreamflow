import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/recovery_blueprint.dart';
import 'package:wellspring/models/user.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/recovery_blueprint_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';
import 'package:uuid/uuid.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

/// Collaborative scheduling screen for care team
class CareTeamScheduleScreen extends StatefulWidget {
  final String? patientId;

  const CareTeamScheduleScreen({super.key, this.patientId});

  @override
  State<CareTeamScheduleScreen> createState() => _CareTeamScheduleScreenState();
}

class _CareTeamScheduleScreenState extends State<CareTeamScheduleScreen> {
  final _service = RecoveryBlueprintService();
  final _userService = UserService();
  RecoveryBlueprint? _blueprint;
  User? _patient;
  bool _loading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final _periods = ['Morning', 'Afternoon', 'Evening', 'Overnight'];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _load();
  }

  Future<void> _load() async {
    debugPrint('[CareTeamSchedule] _load() started');
    final userId = widget.patientId ?? context.read<UserProvider>().currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    final bp = await _service.getByUserId(userId);
    final patient = await _userService.getUserById(userId);
    
    debugPrint('[CareTeamSchedule] Loaded blueprint with ${bp?.dailyRoutines.length ?? 0} routines');
    if (bp != null) {
      for (var routine in bp.dailyRoutines) {
        debugPrint('[CareTeamSchedule]   - ${routine.type}: ${routine.timesOfDay}');
      }
    }
    
    debugPrint('[CareTeamSchedule] Loaded patient with ${patient?.medications.length ?? 0} medications');
    if (patient != null) {
      for (var med in patient.medications) {
        debugPrint('[CareTeamSchedule]   - ${med.name}: ${med.times}');
      }
    }
    
    if (mounted) {
      setState(() {
        _blueprint = bp;
        _patient = patient;
        _loading = false;
      });
      debugPrint('[CareTeamSchedule] _load() completed, setState called');
    }
  }

  void _showAddMemberDialog() {
    final nameController = TextEditingController();
    final relationshipController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Team Member'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationshipController,
                decoration: const InputDecoration(labelText: 'Relationship (e.g., Spouse, Nurse)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone (optional)', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email (optional)', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || relationshipController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and relationship are required')),
                );
                return;
              }

              final newMember = CareTeamMember(
                id: const Uuid().v4(),
                name: nameController.text.trim(),
                relationship: relationshipController.text.trim(),
                phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                availability: {},
              );

              final updatedBlueprint = RecoveryBlueprint(
                id: _blueprint!.id,
                userId: _blueprint!.userId,
                patientProfile: _blueprint!.patientProfile,
                careTeam: [..._blueprint!.careTeam, newMember],
                independenceAssessment: _blueprint!.independenceAssessment,
                homeReadiness: _blueprint!.homeReadiness,
                dailyRoutines: _blueprint!.dailyRoutines,
                equipment: _blueprint!.equipment,
                supplies: _blueprint!.supplies,
                roadmap: _blueprint!.roadmap,
                createdAt: _blueprint!.createdAt,
                updatedAt: DateTime.now(),
              );

              await _service.update(updatedBlueprint);
              _load();
              if (mounted) context.pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showActivityDialog(String memberId, DateTime date, String period) {
    final member = _blueprint!.careTeam.firstWhere((m) => m.id == memberId);
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final periodKey = period.toLowerCase();
    
    // Get current activities for this slot
    final existingSlot = member.schedule[dateKey]?.firstWhere(
      (slot) => slot.period == periodKey,
      orElse: () => TimeSlot(period: periodKey),
    );
    
    final activityController = TextEditingController();
    final selectedActivities = List<String>.from(existingSlot?.activities ?? []);
    
    // Common activity options
    final commonActivities = [
      'Medication assistance',
      'Meal preparation',
      'Personal care (bathing, dressing)',
      'Transportation to appointments',
      'Physical therapy exercises',
      'Wound care',
      'Vital signs monitoring',
      'Companionship',
      'Light housekeeping',
      'Grocery shopping',
      'Emergency contact',
    ];
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (statefulContext, setDialogState) => AlertDialog(
          title: Text('${member.name} - ${DateFormat('MMM d').format(date)}, $period'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('What will they help with?', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: commonActivities.map((activity) {
                      final isSelected = selectedActivities.contains(activity);
                      return FilterChip(
                        label: Text(activity),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedActivities.add(activity);
                            } else {
                              selectedActivities.remove(activity);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: activityController,
                    decoration: const InputDecoration(
                      labelText: 'Add custom activity',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.add),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty && !selectedActivities.contains(value.trim())) {
                        setDialogState(() {
                          selectedActivities.add(value.trim());
                          activityController.clear();
                        });
                      }
                    },
                  ),
                  if (selectedActivities.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Selected activities:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...selectedActivities.map((activity) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(activity)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              setDialogState(() => selectedActivities.remove(activity));
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (existingSlot?.activities.isNotEmpty == true)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _removeTimeSlot(memberId, date, period);
                },
                child: const Text('Remove'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedActivities.isEmpty
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                      _updateTimeSlot(memberId, date, period, selectedActivities);
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _updateTimeSlot(String memberId, DateTime date, String period, List<String> activities) async {
    final member = _blueprint!.careTeam.firstWhere((m) => m.id == memberId);
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final periodKey = period.toLowerCase();
    
    final schedule = Map<String, List<TimeSlot>>.from(member.schedule);
    final slots = List<TimeSlot>.from(schedule[dateKey] ?? []);
    
    // Remove existing slot for this period
    slots.removeWhere((slot) => slot.period == periodKey);
    
    // Add new slot with activities
    if (activities.isNotEmpty) {
      slots.add(TimeSlot(period: periodKey, activities: activities));
    }
    
    if (slots.isEmpty) {
      schedule.remove(dateKey);
    } else {
      schedule[dateKey] = slots;
    }

    final updatedMember = CareTeamMember(
      id: member.id,
      name: member.name,
      relationship: member.relationship,
      phone: member.phone,
      email: member.email,
      roles: member.roles,
      availability: member.availability,
      schedule: schedule,
    );

    final updatedTeam = _blueprint!.careTeam.map((m) => m.id == memberId ? updatedMember : m).toList();

    final updatedBlueprint = RecoveryBlueprint(
      id: _blueprint!.id,
      userId: _blueprint!.userId,
      patientProfile: _blueprint!.patientProfile,
      careTeam: updatedTeam,
      independenceAssessment: _blueprint!.independenceAssessment,
      homeReadiness: _blueprint!.homeReadiness,
      dailyRoutines: _blueprint!.dailyRoutines,
      equipment: _blueprint!.equipment,
      supplies: _blueprint!.supplies,
      roadmap: _blueprint!.roadmap,
      createdAt: _blueprint!.createdAt,
      updatedAt: DateTime.now(),
    );

    await _service.update(updatedBlueprint);
    setState(() {}); // Refresh UI immediately
  }
  
  void _removeTimeSlot(String memberId, DateTime date, String period) async {
    _updateTimeSlot(memberId, date, period, []);
  }
  
  int _getAvailabilityCount(DateTime date) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    int count = 0;
    
    // Count care team schedules
    for (var member in _blueprint!.careTeam) {
      if (member.schedule.containsKey(dateKey) && member.schedule[dateKey]!.isNotEmpty) {
        count++;
      }
    }
    
    // Count medications scheduled for this date
    if (_patient != null) {
      for (var med in _patient!.medications) {
        if (med.times.isNotEmpty) count++;
      }
    }
    
    // Count routines scheduled for this date
    final dayName = DateFormat('EEEE').format(date).toLowerCase();
    for (var routine in _blueprint!.dailyRoutines) {
      if (routine.daysPerformed.isEmpty || 
          routine.daysPerformed.any((day) => day.toLowerCase() == dayName)) {
        count += routine.timesOfDay.length;
      }
    }
    
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Care Team Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddMemberDialog,
            tooltip: 'Add Team Member',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blueprint == null
              ? const Center(child: Text('No blueprint found'))
              : _blueprint!.careTeam.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: cs.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text('No team members yet', style: context.textStyles.headlineSmall),
                            const SizedBox(height: 8),
                            Text(
                              'Add family members or caregivers to start collaborative scheduling',
                              style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _showAddMemberDialog,
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add Team Member'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTodayScheduleSummary(cs),
                          const SizedBox(height: 16),
                          _buildMedicationsSection(cs),
                          const SizedBox(height: 16),
                          _buildDailyCareTimelineSection(cs),
                          const SizedBox(height: 16),
                          _buildTeamLegend(cs),
                          const SizedBox(height: 16),
                          _buildCalendarCard(cs),
                          if (_selectedDay != null) ...[
                            const SizedBox(height: 16),
                            _buildDaySchedule(cs),
                          ],
                        ],
                      ),
                    ),
    );
  }
  
  Widget _buildTodayScheduleSummary(ColorScheme cs) {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final memberColors = _getMemberColors();
    
    // Get today's schedule
    final todaySchedule = <String, List<CareTeamMember>>{};
    for (var period in _periods) {
      final periodKey = period.toLowerCase();
      todaySchedule[period] = _blueprint!.careTeam.where((member) {
        return member.schedule[todayKey]?.any((slot) => slot.period == periodKey) ?? false;
      }).toList();
    }
    
    // Check if there's any schedule for today
    final hasScheduleToday = todaySchedule.values.any((members) => members.isNotEmpty);
    
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today, color: cs.onPrimaryContainer, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Schedule",
                        style: context.textStyles.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, MMMM d').format(today),
                        style: context.textStyles.bodyMedium?.withColor(
                          cs.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasScheduleToday)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: cs.onSurfaceVariant, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No care team members scheduled for today',
                        style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...todaySchedule.entries.where((entry) => entry.value.isNotEmpty).map((entry) {
                final period = entry.key;
                final members = entry.value;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          period,
                          style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        ...members.map((member) {
                          final timeSlot = member.schedule[todayKey]?.firstWhere(
                            (slot) => slot.period == period.toLowerCase(),
                            orElse: () => TimeSlot(period: period.toLowerCase()),
                          );
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    color: memberColors[member.id],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.name,
                                        style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      if (timeSlot?.activities.isNotEmpty ?? false)
                                        ...timeSlot!.activities.map((activity) => Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Row(
                                            children: [
                                              Icon(Icons.check, size: 12, color: cs.primary),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  activity,
                                                  style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTeamLegend(ColorScheme cs) {
    final memberColors = _getMemberColors();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Care Team', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: _blueprint!.careTeam.map((member) {
                int totalSlots = 0;
                member.schedule.forEach((date, slots) => totalSlots += slots.length);
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: memberColors[member.id]!.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: memberColors[member.id]!.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: memberColors[member.id],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${member.name} ($totalSlots slots)',
                        style: context.textStyles.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
  
  Widget _buildCalendarCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TableCalendar(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.sunday,
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          calendarStyle: CalendarStyle(
            markersMaxCount: 1,
            markerDecoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            outsideDaysVisible: false,
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: context.textStyles.titleMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              final count = _getAvailabilityCount(date);
              if (count == 0) return null;
              
              return Positioned(
                bottom: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildDaySchedule(ColorScheme cs) {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final memberColors = _getMemberColors();
    final dateFormatted = DateFormat('EEEE, MMMM d, y').format(_selectedDay!);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateFormatted,
                    style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tap team members to set their schedule and activities',
              style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ..._periods.map((period) {
              final periodKey = period.toLowerCase();
              final scheduledMembers = _blueprint!.careTeam.where((member) {
                return member.schedule[dateKey]?.any((slot) => slot.period == periodKey) ?? false;
              }).toList();
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          period,
                          style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (scheduledMembers.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${scheduledMembers.length} scheduled',
                              style: context.textStyles.labelSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _blueprint!.careTeam.map((member) {
                        final timeSlot = member.schedule[dateKey]?.firstWhere(
                          (slot) => slot.period == periodKey,
                          orElse: () => TimeSlot(period: periodKey),
                        );
                        final isScheduled = timeSlot?.activities.isNotEmpty ?? false;
                        
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showActivityDialog(member.id, _selectedDay!, period),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 100),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isScheduled
                                    ? memberColors[member.id]!.withValues(alpha: 0.15)
                                    : cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isScheduled
                                      ? memberColors[member.id]!
                                      : cs.outline.withValues(alpha: 0.3),
                                  width: isScheduled ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: isScheduled ? memberColors[member.id] : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isScheduled ? memberColors[member.id]! : cs.outline,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          member.name,
                                          style: context.textStyles.bodySmall?.copyWith(
                                            fontWeight: isScheduled ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isScheduled && timeSlot!.activities.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    ...timeSlot.activities.take(2).map((activity) => Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check, size: 10, color: cs.primary),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              activity,
                                              style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                    if (timeSlot.activities.length > 2)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '+${timeSlot.activities.length - 2} more',
                                          style: context.textStyles.labelSmall?.copyWith(
                                            color: cs.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ] else if (!isScheduled)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Tap to schedule',
                                        style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
  
  Map<String, Color> _getMemberColors() {
    final memberColors = <String, Color>{};
    final colorPalette = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
    ];
    
    for (var i = 0; i < _blueprint!.careTeam.length; i++) {
      memberColors[_blueprint!.careTeam[i].id] = colorPalette[i % colorPalette.length];
    }
    
    return memberColors;
  }
  
  Widget _buildMedicationsSection(ColorScheme cs) {
    if (_patient == null || _patient!.medications.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.medication, color: cs.primary),
        title: Text(
          'Medications',
          style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_patient!.medications.length} medication${_patient!.medications.length != 1 ? 's' : ''}',
          style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
        ),
        children: [
          _buildVisualTimeline(cs),
        ],
      ),
    );
  }
  
  Widget _buildDailyCareTimelineSection(ColorScheme cs) {
    if (_blueprint!.dailyRoutines.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final memberColors = _getMemberColors();
    
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.access_time, color: cs.primary),
        title: Text(
          'Daily Care Timeline',
          style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_blueprint!.dailyRoutines.length} routine${_blueprint!.dailyRoutines.length != 1 ? 's' : ''}',
          style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
        ),
        children: [
          _buildVisualTimeline(cs),
        ],
      ),
    );
  }
  
  Widget _buildVisualTimeline(ColorScheme cs) {
    // Combine medications and routines into timeline items
    final timelineItems = <TimelineItem>[];
    
    // Add medications
    if (_patient != null) {
      for (var med in _patient!.medications) {
        for (var time in med.times) {
          timelineItems.add(TimelineItem(
            time: time,
            type: 'medication',
            title: med.name,
            subtitle: med.dosage,
            notes: med.notes,
            icon: Icons.medication_liquid,
            color: const Color(0xFFE91E63), // Pink for medications
            medicationId: med.name,
          ));
        }
      }
    }
    
    // Add routines
    for (var routine in _blueprint!.dailyRoutines) {
      IconData routineIcon = Icons.healing;
      Color routineColor = Colors.blue;
      
      switch (routine.type.toLowerCase()) {
        case 'bowel':
          routineIcon = Icons.wc;
          routineColor = const Color(0xFF9C27B0); // Purple
          break;
        case 'bladder':
          routineIcon = Icons.water_drop;
          routineColor = const Color(0xFF2196F3); // Blue
          break;
        case 'skin_check':
          routineIcon = Icons.visibility;
          routineColor = const Color(0xFF00BCD4); // Cyan
          break;
        case 'therapy':
          routineIcon = Icons.fitness_center;
          routineColor = const Color(0xFFFF9800); // Orange
          break;
        case 'nutrition':
          routineIcon = Icons.restaurant;
          routineColor = const Color(0xFF4CAF50); // Green
          break;
      }
      
      final assignedMember = routine.assignedCaregiverId != null
          ? _blueprint!.careTeam.firstWhere(
              (m) => m.id == routine.assignedCaregiverId,
              orElse: () => CareTeamMember(id: '', name: '', relationship: ''),
            )
          : null;
      
      // Add a timeline item for each time
      for (var time in routine.timesOfDay) {
        timelineItems.add(TimelineItem(
          time: time,
          type: 'routine',
          title: routine.type.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
          subtitle: assignedMember?.name,
          notes: routine.suppliesNeeded.isNotEmpty ? '${routine.suppliesNeeded.length} supplies needed' : null,
          icon: routineIcon,
          color: routineColor,
          daysPerformed: routine.daysPerformed,
          caregiverColor: assignedMember != null ? _getMemberColors()[assignedMember.id] : null,
          routineType: routine.type,
        ));
      }
    }
    
    // Sort by time
    timelineItems.sort((a, b) => _parseTime(a.time).compareTo(_parseTime(b.time)));
    
    if (timelineItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.schedule, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                'No scheduled items',
                style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      height: 400,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ListView.builder(
        itemCount: timelineItems.length,
        itemBuilder: (context, index) {
          final item = timelineItems[index];
          final isLast = index == timelineItems.length - 1;
          
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Timeline indicator
                SizedBox(
                  width: 80,
                  child: Column(
                    children: [
                      Text(
                        item.time,
                        style: context.textStyles.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: item.color, width: 2),
                        ),
                        child: Icon(item.icon, size: 16, color: item.color),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  item.color.withValues(alpha: 0.5),
                                  timelineItems[index + 1].color.withValues(alpha: 0.3),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 16),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: item.color.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: context.textStyles.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item.type == 'medication' ? '💊' : '🩺',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        if (item.subtitle != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (item.caregiverColor != null) ...[
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: item.caregiverColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  item.subtitle!,
                                  style: context.textStyles.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (item.daysPerformed != null && item.daysPerformed!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: item.daysPerformed!.map((day) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  day.substring(0, 3).toUpperCase(),
                                  style: context.textStyles.labelSmall?.copyWith(
                                    color: item.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        if (item.notes != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 14, color: cs.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.notes!,
                                    style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showAddTimeDialog(item),
                                icon: const Icon(Icons.add_alarm, size: 16),
                                label: const Text('Add Time', overflow: TextOverflow.ellipsis),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: item.color.withValues(alpha: 0.15),
                                  foregroundColor: item.color,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  minimumSize: const Size(0, 36),
                                  textStyle: context.textStyles.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showEditTimesDialog(item),
                                icon: const Icon(Icons.edit_calendar, size: 16),
                                label: const Text('Manage', overflow: TextOverflow.ellipsis),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.surfaceContainerHighest,
                                  foregroundColor: cs.onSurface,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  minimumSize: const Size(0, 36),
                                  textStyle: context.textStyles.labelSmall?.copyWith(fontWeight: FontWeight.w600),
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
        },
      ),
    );
  }
  
  int _parseTime(String time) {
    // Parse time like "8:00 AM" to minutes since midnight for sorting
    final parts = time.split(' ');
    final timeParts = parts[0].split(':');
    var hours = int.parse(timeParts[0]);
    final minutes = int.parse(timeParts[1]);
    final isPM = parts.length > 1 && parts[1].toUpperCase() == 'PM';
    
    if (isPM && hours != 12) hours += 12;
    if (!isPM && hours == 12) hours = 0;
    
    return hours * 60 + minutes;
  }
  
  void _showAddTimeDialog(TimelineItem item) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Select time for ${item.title}',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              dialBackgroundColor: item.color.withValues(alpha: 0.1),
              hourMinuteColor: item.color.withValues(alpha: 0.15),
              hourMinuteTextColor: item.color,
              dayPeriodColor: item.color.withValues(alpha: 0.2),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (time != null && mounted) {
      await _addAdditionalTime(item, time);
    }
  }
  
  void _showEditTimesDialog(TimelineItem item) {
    // Get all current times for this medication or routine
    List<String> currentTimes = [];
    
    if (item.type == 'medication' && _patient != null) {
      final med = _patient!.medications.firstWhere(
        (m) => m.name == item.medicationId,
        orElse: () => _patient!.medications.first,
      );
      currentTimes = List.from(med.times);
      debugPrint('[CareTeamSchedule] Opening manage times for medication ${item.medicationId}, current times: $currentTimes');
    } else if (item.type == 'routine') {
      final routine = _blueprint!.dailyRoutines.firstWhere(
        (r) => r.type.toLowerCase() == item.routineType?.toLowerCase(),
        orElse: () => _blueprint!.dailyRoutines.first,
      );
      currentTimes = List.from(routine.timesOfDay);
      debugPrint('[CareTeamSchedule] Opening manage times for routine ${item.routineType}, current times: $currentTimes');
      debugPrint('[CareTeamSchedule] Available routines: ${_blueprint!.dailyRoutines.map((r) => r.type).toList()}');
      debugPrint('[CareTeamSchedule] Matched routine: ${routine.type} with ${routine.timesOfDay.length} times');
    }
    
    showDialog(
      context: context,
      builder: (dialogContext) => _EditTimesDialog(
        item: item,
        currentTimes: currentTimes,
        onUpdate: (updatedTimes) {
          debugPrint('[CareTeamSchedule] Dialog closed with updated times: $updatedTimes');
          _updateAllTimes(item, updatedTimes);
        },
      ),
    );
  }
  
  Future<void> _addAdditionalTime(TimelineItem item, TimeOfDay newTime) async {
    final timeString = _formatTimeOfDay(newTime);
    debugPrint('[CareTeamSchedule] Adding time $timeString to ${item.title} (${item.type})');
    
    if (item.type == 'medication') {
      // Find the medication and add the new time
      if (_patient == null) return;
      
      final updatedMedications = _patient!.medications.map((med) {
        if (med.name == item.medicationId) {
          // Check if this time already exists
          if (med.times.contains(timeString)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Time $timeString already exists for this medication')),
              );
            }
            return med;
          }
          
          return med.copyWith(
            times: [...med.times, timeString]..sort((a, b) => _parseTime(a).compareTo(_parseTime(b))),
          );
        }
        return med;
      }).toList();
      
      final updatedUser = _patient!.copyWith(medications: updatedMedications);
      
      await _userService.saveUser(updatedUser);
      debugPrint('[CareTeamSchedule] Saved medication to database');
      
      // Reload data to ensure UI is in sync with database
      await _load();
      debugPrint('[CareTeamSchedule] Reloaded data after adding medication time');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Added $timeString to ${item.title}'),
            backgroundColor: item.color,
          ),
        );
      }
    } else if (item.type == 'routine') {
      debugPrint('[CareTeamSchedule] Looking for routine with type: ${item.routineType}');
      debugPrint('[CareTeamSchedule] Available routines: ${_blueprint!.dailyRoutines.map((r) => r.type).join(', ')}');
      
      // Find the routine by type (case-insensitive)
      final routineToAdd = _blueprint!.dailyRoutines.firstWhere(
        (r) => r.type.toLowerCase() == item.routineType?.toLowerCase(),
      );
      
      debugPrint('[CareTeamSchedule] Found routine: ${routineToAdd.type}, current times: ${routineToAdd.timesOfDay}');
      
      // Check if this time already exists for this routine
      if (routineToAdd.timesOfDay.contains(timeString)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Time $timeString already exists for this routine')),
          );
        }
        return;
      }
      
      final updatedRoutines = _blueprint!.dailyRoutines.map((r) {
        // Case-insensitive comparison
        if (r.type.toLowerCase() == routineToAdd.type.toLowerCase()) {
          final newTimes = [...r.timesOfDay, timeString]..sort((a, b) => _parseTime(a).compareTo(_parseTime(b)));
          debugPrint('[CareTeamSchedule] Updating routine ${r.type} with new times: $newTimes');
          return DailyRoutine(
            type: r.type,
            timesOfDay: newTimes,
            assignedCaregiverId: r.assignedCaregiverId,
            suppliesNeeded: r.suppliesNeeded,
            daysPerformed: r.daysPerformed,
          );
        }
        return r;
      }).toList();
      
      final updatedBlueprint = RecoveryBlueprint(
        id: _blueprint!.id,
        userId: _blueprint!.userId,
        patientProfile: _blueprint!.patientProfile,
        careTeam: _blueprint!.careTeam,
        independenceAssessment: _blueprint!.independenceAssessment,
        homeReadiness: _blueprint!.homeReadiness,
        dailyRoutines: updatedRoutines,
        equipment: _blueprint!.equipment,
        supplies: _blueprint!.supplies,
        roadmap: _blueprint!.roadmap,
        createdAt: _blueprint!.createdAt,
        updatedAt: DateTime.now(),
      );
      
      await _service.update(updatedBlueprint);
      debugPrint('[CareTeamSchedule] Saved routine to database');
      
      // Reload data to ensure UI is in sync with database
      await _load();
      debugPrint('[CareTeamSchedule] Reloaded data after adding routine time');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Added $timeString to ${item.title}'),
            backgroundColor: item.color,
          ),
        );
      }
    }
  }
  
  Future<void> _updateAllTimes(TimelineItem item, List<String> newTimes) async {
    debugPrint('[CareTeamSchedule] ═══ _updateAllTimes STARTED ═══');
    debugPrint('[CareTeamSchedule] Updating times for ${item.title} (${item.type}): $newTimes');
    
    try {
      if (item.type == 'medication') {
        if (_patient == null) {
          debugPrint('[CareTeamSchedule] ⚠️ ERROR: _patient is null, cannot update medication');
          return;
        }
        
        final updatedMedications = _patient!.medications.map((med) {
          if (med.name == item.medicationId) {
            return med.copyWith(
              times: newTimes..sort((a, b) => _parseTime(a).compareTo(_parseTime(b))),
            );
          }
          return med;
        }).toList();
        
        final updatedUser = _patient!.copyWith(medications: updatedMedications);
        debugPrint('[CareTeamSchedule] Calling _userService.saveUser...');
        await _userService.saveUser(updatedUser);
        debugPrint('[CareTeamSchedule] ✓ Saved medication times to database');
        
        // Reload data to ensure UI is in sync with database
        debugPrint('[CareTeamSchedule] Reloading data...');
        await _load();
        debugPrint('[CareTeamSchedule] ✓ Reloaded data after medication update');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Updated times for ${item.title}'),
              backgroundColor: item.color,
            ),
          );
        }
      } else if (item.type == 'routine') {
        if (_blueprint == null) {
          debugPrint('[CareTeamSchedule] ⚠️ ERROR: _blueprint is null, cannot update routine');
          return;
        }
        
        debugPrint('[CareTeamSchedule] Routine type: ${item.routineType}');
        debugPrint('[CareTeamSchedule] Current routines in blueprint: ${_blueprint!.dailyRoutines.map((r) => '${r.type} (${r.timesOfDay.length} times)').join(', ')}');
        
        final updatedRoutines = _blueprint!.dailyRoutines.map((r) {
          // Case-insensitive comparison
          if (r.type.toLowerCase() == item.routineType?.toLowerCase()) {
            debugPrint('[CareTeamSchedule] ✓ MATCH: Updating routine ${r.type} from ${r.timesOfDay} to $newTimes');
            return DailyRoutine(
              type: r.type,
              timesOfDay: List.from(newTimes)..sort((a, b) => _parseTime(a).compareTo(_parseTime(b))),
              assignedCaregiverId: r.assignedCaregiverId,
              suppliesNeeded: r.suppliesNeeded,
              daysPerformed: r.daysPerformed,
            );
          }
          debugPrint('[CareTeamSchedule] ✗ No match: ${r.type} != ${item.routineType}');
          return r;
        }).toList();
        
        final updatedBlueprint = RecoveryBlueprint(
          id: _blueprint!.id,
          userId: _blueprint!.userId,
          patientProfile: _blueprint!.patientProfile,
          careTeam: _blueprint!.careTeam,
          independenceAssessment: _blueprint!.independenceAssessment,
          homeReadiness: _blueprint!.homeReadiness,
          dailyRoutines: updatedRoutines,
          equipment: _blueprint!.equipment,
          supplies: _blueprint!.supplies,
          roadmap: _blueprint!.roadmap,
          createdAt: _blueprint!.createdAt,
          updatedAt: DateTime.now(),
        );
        
        debugPrint('[CareTeamSchedule] Calling _service.update with blueprint ${updatedBlueprint.id}...');
        final result = await _service.update(updatedBlueprint);
        debugPrint('[CareTeamSchedule] ✓ Service.update returned, result blueprint has ${result.dailyRoutines.length} routines');
        
        // Reload data to ensure UI is in sync with database
        debugPrint('[CareTeamSchedule] Reloading data...');
        await _load();
        debugPrint('[CareTeamSchedule] ✓ Reloaded data after routine update');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Updated times for ${item.title}'),
              backgroundColor: item.color,
            ),
          );
        }
      }
      debugPrint('[CareTeamSchedule] ═══ _updateAllTimes COMPLETED ═══');
    } catch (e, stackTrace) {
      debugPrint('[CareTeamSchedule] ❌ ERROR in _updateAllTimes: $e');
      debugPrint('[CareTeamSchedule] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update times: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

class TimelineItem {
  final String time;
  final String type;
  final String title;
  final String? subtitle;
  final String? notes;
  final IconData icon;
  final Color color;
  final List<String>? daysPerformed;
  final Color? caregiverColor;
  final String? medicationId;
  final String? routineType;

  TimelineItem({
    required this.time,
    required this.type,
    required this.title,
    this.subtitle,
    this.notes,
    required this.icon,
    required this.color,
    this.daysPerformed,
    this.caregiverColor,
    this.medicationId,
    this.routineType,
  });
}

// Dialog for managing all times for a medication or routine
class _EditTimesDialog extends StatefulWidget {
  final TimelineItem item;
  final List<String> currentTimes;
  final Function(List<String>) onUpdate;

  const _EditTimesDialog({
    required this.item,
    required this.currentTimes,
    required this.onUpdate,
  });

  @override
  State<_EditTimesDialog> createState() => _EditTimesDialogState();
}

class _EditTimesDialogState extends State<_EditTimesDialog> {
  late List<String> _times;

  @override
  void initState() {
    super.initState();
    _times = List.from(widget.currentTimes);
  }

  void _addTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Add time for ${widget.item.title}',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              dialBackgroundColor: widget.item.color.withValues(alpha: 0.1),
              hourMinuteColor: widget.item.color.withValues(alpha: 0.15),
              hourMinuteTextColor: widget.item.color,
              dayPeriodColor: widget.item.color.withValues(alpha: 0.2),
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      final timeString = _formatTimeOfDay(time);
      if (!_times.contains(timeString)) {
        setState(() {
          _times.add(timeString);
          _times.sort((a, b) => _parseTime(a).compareTo(_parseTime(b)));
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This time already exists')),
          );
        }
      }
    }
  }

  void _removeTime(String time) {
    if (_times.length > 1) {
      setState(() => _times.remove(time));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one time is required')),
      );
    }
  }

  int _parseTime(String time) {
    final parts = time.split(' ');
    final timeParts = parts[0].split(':');
    var hours = int.parse(timeParts[0]);
    final minutes = int.parse(timeParts[1]);
    final isPM = parts.length > 1 && parts[1].toUpperCase() == 'PM';

    if (isPM && hours != 12) hours += 12;
    if (!isPM && hours == 12) hours = 0;

    return hours * 60 + minutes;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.item.color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.item.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.item.icon, color: widget.item.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Times',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.item.title,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Scheduled Times',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_times.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'No times scheduled',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._times.map((time) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.item.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: widget.item.color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, color: widget.item.color, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  time,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _removeTime(time),
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.red,
                                iconSize: 20,
                                tooltip: 'Remove time',
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _addTime,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Another Time'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.item.color,
                        side: BorderSide(color: widget.item.color),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _times.isEmpty ? null : () {
                      Navigator.of(context).pop();
                      widget.onUpdate(_times);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.item.color,
                    ),
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
