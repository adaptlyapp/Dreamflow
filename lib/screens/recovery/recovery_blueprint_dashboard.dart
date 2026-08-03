import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/recovery_blueprint.dart';
import 'package:wellspring/models/user.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/recovery_blueprint_service.dart';
import 'package:wellspring/services/tracker_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/theme.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

/// Recovery Command Center - Living visual representation of patient's recovery ecosystem
class RecoveryBlueprintDashboard extends StatefulWidget {
  final String? patientId;
  
  const RecoveryBlueprintDashboard({super.key, this.patientId});

  @override
  State<RecoveryBlueprintDashboard> createState() => _RecoveryBlueprintDashboardState();
}

class _RecoveryBlueprintDashboardState extends State<RecoveryBlueprintDashboard> {
  final _service = RecoveryBlueprintService();
  final _trackerService = TrackerService();
  RecoveryBlueprint? _blueprint;
  bool _loading = true;
  double _medicationAdherence = 0.0;
  final _calendarScrollController = ScrollController();
  List<BlueprintCollaborator> _collaborators = [];
  RealtimeChannel? _channel;
  String? _liveBannerText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _calendarScrollController.dispose();
    final ch = _channel;
    if (ch != null) {
      SupabaseConfig.client.removeChannel(ch);
    }
    super.dispose();
  }

  Future<void> _load() async {
    final userId = widget.patientId ?? context.read<UserProvider>().currentUser?.id;
    debugPrint('RecoveryCommandCenter: Loading for userId=$userId');
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    final bp = await _service.getByUserId(userId);

    // Calculate medication adherence from tracker
    double adherence = 0.0;
    try {
      final now = DateTime.now();
      final last7Days = now.subtract(const Duration(days: 7));
      final entries = await _trackerService.getEntriesByDateRange(userId, last7Days, now);
      final medEntries = entries.where((e) => e.medications?.isNotEmpty ?? false).toList();
      if (medEntries.isNotEmpty) {
        adherence = (medEntries.length / 14).clamp(0.0, 1.0); // Assume 2 entries/day ideal
      }
    } catch (e) {
      debugPrint('Error calculating medication adherence: $e');
    }

    List<BlueprintCollaborator> collabs = const [];
    if (bp != null) {
      collabs = await _service.listCollaborators(bp.id);
      _subscribeRealtime(bp.id);
    }

    if (mounted) {
      setState(() {
        _blueprint = bp;
        _medicationAdherence = adherence;
        _collaborators = collabs;
        _loading = false;
      });
    }
  }

  void _subscribeRealtime(String blueprintId) {
    final old = _channel;
    if (old != null) {
      SupabaseConfig.client.removeChannel(old);
      _channel = null;
    }
    _channel = _service.subscribeToBlueprint(
      blueprintId: blueprintId,
      onChange: (incoming) {
        if (!mounted) return;
        final me = SupabaseConfig.client.auth.currentUser?.id;
        // Ignore echoes of our own edit.
        if (incoming.updatedBy != null && incoming.updatedBy == me) return;
        final editorName = _collaborators
                .where((c) => c.userId == incoming.updatedBy)
                .map((c) => c.displayName)
                .firstWhere((n) => n != null && n.isNotEmpty, orElse: () => null) ??
            'A collaborator';
        setState(() {
          _blueprint = incoming;
          _liveBannerText = '$editorName just updated the blueprint';
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _liveBannerText = null);
        });
      },
    );
  }

  void _showAutoLinkInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How collaborators join'),
        content: const Text(
          'Family members automatically join this Recovery Blueprint as viewers '
          'when they enter your patient code during enrollment.\n\n'
          'No invites needed — just share your patient code with the people who '
          'should see your blueprint.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _updateRoutineTime(int index, List<String> times) async {
    if (_blueprint == null) return;
    
    final routines = List<DailyRoutine>.from(_blueprint!.dailyRoutines);
    final routine = routines[index];
    
    routines[index] = DailyRoutine(
      type: routine.type,
      daysPerformed: routine.daysPerformed,
      timesOfDay: times,
      suppliesNeeded: routine.suppliesNeeded,
      assignedCaregiverId: routine.assignedCaregiverId,
    );
    
    final updatedBlueprint = RecoveryBlueprint(
      id: _blueprint!.id,
      userId: _blueprint!.userId,
      patientProfile: _blueprint!.patientProfile,
      careTeam: _blueprint!.careTeam,
      independenceAssessment: _blueprint!.independenceAssessment,
      homeReadiness: _blueprint!.homeReadiness,
      dailyRoutines: routines,
      equipment: _blueprint!.equipment,
      supplies: _blueprint!.supplies,
      roadmap: _blueprint!.roadmap,
      createdAt: _blueprint!.createdAt,
      updatedAt: DateTime.now(),
    );
    
    await _service.update(updatedBlueprint);
    
    // Reload from database to ensure UI is in sync
    await _load();
  }

  void _updateRoutineDetails(int index, String? caregiverId, List<String> days, List<String> supplies) async {
    if (_blueprint == null) return;
    
    final routines = List<DailyRoutine>.from(_blueprint!.dailyRoutines);
    final routine = routines[index];
    
    routines[index] = DailyRoutine(
      type: routine.type,
      daysPerformed: days,
      timesOfDay: routine.timesOfDay,
      suppliesNeeded: supplies,
      assignedCaregiverId: caregiverId,
    );
    
    final updatedBlueprint = RecoveryBlueprint(
      id: _blueprint!.id,
      userId: _blueprint!.userId,
      patientProfile: _blueprint!.patientProfile,
      careTeam: _blueprint!.careTeam,
      independenceAssessment: _blueprint!.independenceAssessment,
      homeReadiness: _blueprint!.homeReadiness,
      dailyRoutines: routines,
      equipment: _blueprint!.equipment,
      supplies: _blueprint!.supplies,
      roadmap: _blueprint!.roadmap,
      createdAt: _blueprint!.createdAt,
      updatedAt: DateTime.now(),
    );
    
    await _service.update(updatedBlueprint);
    
    // Reload from database to ensure UI is in sync
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A20),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Recovery Blueprint', style: context.textStyles.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: _blueprint != null
            ? [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  tooltip: 'Edit Blueprint Settings',
                  onPressed: () async {
                    final route = widget.patientId != null
                        ? '/family/recovery-blueprint/wizard'
                        : '/recovery-blueprint/wizard';
                    final result = await context.push(route, extra: _blueprint);
                    if (result == true) _load();
                  },
                ),
              ]
            : null,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0A4D5C),
              Color(0xFF0A1A20),
              Color(0xFF0A1A20),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
            : _blueprint == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radar, size: 80, color: Colors.cyan.withValues(alpha: 0.5)),
                          const SizedBox(height: 24),
                          Text('No Recovery Blueprint', style: context.textStyles.headlineSmall?.copyWith(color: Colors.white)),
                          const SizedBox(height: 12),
                          Text(
                            'Create your blueprint to access the Recovery Command Center',
                            style: context.textStyles.bodyMedium?.copyWith(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () async {
                              final route = widget.patientId != null 
                                  ? '/family/recovery-blueprint/wizard'
                                  : '/recovery-blueprint/wizard';
                              final result = await context.push(route, extra: widget.patientId);
                              if (result == true) _load();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              foregroundColor: Colors.black,
                            ),
                            icon: const Icon(Icons.add_chart),
                            label: const Text('Create Blueprint'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CollaboratorsBar(
                          collaborators: _collaborators,
                          blueprint: _blueprint!,
                          liveBannerText: _liveBannerText,
                          onInfoTap: _showAutoLinkInfo,
                        ),
                        const SizedBox(height: 12),
                        // Today's Schedule Summary
                        _TodayScheduleSummary(blueprint: _blueprint!, patientId: widget.patientId),
                        const SizedBox(height: 16),
                        
                        // Care Coordinator - Key insights
                        _CareCoordinator(blueprint: _blueprint!, medicationAdherence: _medicationAdherence),
                        const SizedBox(height: 16),

                        // Care Team - Who's helping and when
                        _CareTeamSection(blueprint: _blueprint!, patientId: widget.patientId),
                        const SizedBox(height: 16),

                        // Daily Care Timeline
                        _DailyCareTimeline(
                          blueprint: _blueprint!,
                          onTimeUpdate: _updateRoutineTime,
                          onDetailsUpdate: _updateRoutineDetails,
                        ),
                        const SizedBox(height: 16),

                        // Equipment & Supplies
                        _EquipmentSuppliesSection(blueprint: _blueprint!),
                      ],
                    ),
                  ),
      ),
    );
  }
}

/// Week Calendar View - Visual calendar with time-blocked events
class _TodayScheduleSummary extends StatefulWidget {
  final RecoveryBlueprint blueprint;
  final String? patientId;
  
  const _TodayScheduleSummary({required this.blueprint, this.patientId});

  @override
  State<_TodayScheduleSummary> createState() => _TodayScheduleSummaryState();
}

class _TodayScheduleSummaryState extends State<_TodayScheduleSummary> {
  final _userService = UserService();
  User? _patient;
  bool _loading = true;
  DateTime _selectedWeekStart = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _selectedWeekStart = _getWeekStart(DateTime.now());
    _loadPatient();
  }
  
  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }
  
  Future<void> _loadPatient() async {
    final userId = widget.patientId ?? context.read<UserProvider>().currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    
    final patient = await _userService.getUserById(userId);
    if (mounted) {
      setState(() {
        _patient = patient;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    if (_loading) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: const Color(0xFF0D2530),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F38).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(cs),
          _WeekCalendarView(
            blueprint: widget.blueprint,
            patient: _patient,
            weekStart: _selectedWeekStart,
            memberColors: _getMemberColors(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader(ColorScheme cs) {
    final monthYear = DateFormat('MMMM yyyy').format(_selectedWeekStart);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0D7C8C),
            Color(0xFF0A5A68),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7));
              });
            },
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  monthYear,
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Week of ${DateFormat('MMM d').format(_selectedWeekStart)}',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedWeekStart = _selectedWeekStart.add(const Duration(days: 7));
              });
            },
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ],
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
    
    for (var i = 0; i < widget.blueprint.careTeam.length; i++) {
      memberColors[widget.blueprint.careTeam[i].id] = colorPalette[i % colorPalette.length];
    }
    
    return memberColors;
  }
}


class _ScheduleItem {
  final String time;
  final String type;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Color? caregiverColor;
  
  _ScheduleItem({
    required this.time,
    required this.type,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.caregiverColor,
  });
}

/// Week Calendar View with time-blocked events
class _WeekCalendarView extends StatefulWidget {
  final RecoveryBlueprint blueprint;
  final User? patient;
  final DateTime weekStart;
  final Map<String, Color> memberColors;
  
  const _WeekCalendarView({
    required this.blueprint,
    required this.patient,
    required this.weekStart,
    required this.memberColors,
  });

  @override
  State<_WeekCalendarView> createState() => _WeekCalendarViewState();
}

class _WeekCalendarViewState extends State<_WeekCalendarView> {
  final _timeScrollController = ScrollController();
  final _dayScrollControllers = <ScrollController>[];
  
  @override
  void initState() {
    super.initState();
    // Create 7 controllers for 7 days
    for (int i = 0; i < 7; i++) {
      final controller = ScrollController();
      // Sync all day columns with the time column
      controller.addListener(() {
        if (_timeScrollController.hasClients && !_timeScrollController.position.isScrollingNotifier.value) {
          _timeScrollController.jumpTo(controller.offset);
        }
      });
      _dayScrollControllers.add(controller);
    }
    
    // Sync time column with day columns
    _timeScrollController.addListener(() {
      if (_timeScrollController.position.isScrollingNotifier.value) {
        for (var dayController in _dayScrollControllers) {
          if (dayController.hasClients) {
            dayController.jumpTo(_timeScrollController.offset);
          }
        }
      }
    });
  }
  
  @override
  void dispose() {
    _timeScrollController.dispose();
    for (var controller in _dayScrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final weekDays = List.generate(7, (i) => widget.weekStart.add(Duration(days: i)));
    final today = DateTime.now();
    
    return SizedBox(
      height: 500,
      child: Row(
        children: [
          // Time labels column
          SizedBox(
            width: 50,
            child: Column(
              children: [
                // Empty space for day headers
                SizedBox(height: 60),
                // Time slots - all 24 hours
                Expanded(
                  child: SingleChildScrollView(
                    controller: _timeScrollController,
                    child: Column(
                      children: List.generate(24, (index) {
                        final hour = index;
                        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                        final period = hour < 12 ? 'AM' : 'PM';
                        return Container(
                          height: 60,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 8, top: 4),
                          child: Text(
                            '$displayHour$period',
                            style: context.textStyles.labelSmall?.copyWith(color: Colors.white60),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            width: 1,
            color: Colors.cyan.withValues(alpha: 0.2),
          ),
          
          // Days columns
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: weekDays.asMap().entries.map((entry) {
                  final dayIndex = entry.key;
                  final date = entry.value;
                  final isToday = date.year == today.year && 
                                  date.month == today.month && 
                                  date.day == today.day;
                  final dateKey = DateFormat('yyyy-MM-dd').format(date);
                  final events = _getEventsForDate(dateKey);
                  
                  return Container(
                    width: 120,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
                      ),
                      color: isToday ? cs.primaryContainer.withValues(alpha: 0.05) : null,
                    ),
                    child: Column(
                      children: [
                        // Day header
                        Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.cyan.withValues(alpha: 0.2))),
                            color: isToday ? cs.primary : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('E').format(date),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isToday ? cs.onPrimary : cs.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                  height: 1.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isToday ? cs.onPrimary : cs.onSurface,
                                  fontWeight: FontWeight.bold,
                                  height: 1.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                              ),
                            ],
                          ),
                        ),
                        
                        // Events in time slots
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _dayScrollControllers[dayIndex],
                            child: SizedBox(
                              height: 60 * 24.0, // 24 hours * 60px each
                              child: Stack(
                                children: [
                                  // Time grid lines
                                  Column(
                                    children: List.generate(24, (index) => Container(
                                      height: 60,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
                                        ),
                                      ),
                                    )),
                                  ),
                                  
                                  // Events
                                  ...events.map((event) => _buildEventBlock(context, event, cs)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventBlock(BuildContext context, _CalendarEvent event, ColorScheme cs) {
    final startMinutes = _parseTimeToMinutes(event.startTime);
    final duration = event.durationMinutes;
    
    // Calculate position (12 AM = 0, each hour = 60px)
    final topPosition = (startMinutes / 60) * 60.0;
    final height = math.max((duration / 60) * 60.0, 30.0); // Minimum height of 30px
    
    return Positioned(
      top: topPosition,
      left: 4,
      right: 4,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: event.color,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: event.color.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.title,
                style: context.textStyles.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (event.subtitle != null && height > 40) ...[
                const SizedBox(height: 2),
                Text(
                  event.subtitle!,
                  style: context.textStyles.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 10,
                  ),
                  softWrap: true,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  List<_CalendarEvent> _getEventsForDate(String dateKey) {
    final events = <_CalendarEvent>[];
    
    // Add medications
    if (widget.patient != null) {
      for (var med in widget.patient!.medications) {
        for (var time in med.times) {
          events.add(_CalendarEvent(
            startTime: time,
            durationMinutes: 30,
            title: med.name,
            subtitle: med.dosage,
            color: const Color(0xFFE91E63), // Pink
          ));
        }
      }
    }
    
    // Add daily routines
    for (var routine in widget.blueprint.dailyRoutines) {
      Color color = Colors.blue;
      
      switch (routine.type.toLowerCase()) {
        case 'bowel':
          color = const Color(0xFF9C27B0);
          break;
        case 'bladder':
          color = const Color(0xFF2196F3);
          break;
        case 'skin_check':
          color = const Color(0xFF00BCD4);
          break;
        case 'therapy':
          color = const Color(0xFFFF9800);
          break;
        case 'nutrition':
          color = const Color(0xFF4CAF50);
          break;
      }
      
      final assignedMember = routine.assignedCaregiverId != null
          ? widget.blueprint.careTeam.where((m) => m.id == routine.assignedCaregiverId).firstOrNull
          : null;
      
      // Add an event for each time
      for (var time in routine.timesOfDay) {
        if (time.isNotEmpty) {
          events.add(_CalendarEvent(
            startTime: time,
            durationMinutes: 60,
            title: routine.type.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
            subtitle: assignedMember?.name,
            color: color,
          ));
        }
      }
    }
    
    // Add team member activities
    for (var member in widget.blueprint.careTeam) {
      final daySchedule = member.schedule[dateKey];
      if (daySchedule != null) {
        for (var slot in daySchedule) {
          if (slot.activities.isNotEmpty) {
            String timeStr = _getPeriodTimeLabel(slot.period);
            events.add(_CalendarEvent(
              startTime: timeStr,
              durationMinutes: 180, // 3 hours for period blocks
              title: member.name,
              subtitle: slot.activities.join(', '),
              color: widget.memberColors[member.id] ?? Colors.blue,
            ));
          }
        }
      }
    }
    
    return events;
  }
  
  String _getPeriodTimeLabel(String period) {
    switch (period.toLowerCase()) {
      case 'morning': return '8:00 AM';
      case 'afternoon': return '1:00 PM';
      case 'evening': return '6:00 PM';
      case 'overnight': return '10:00 PM';
      default: return '12:00 PM';
    }
  }
  
  int _parseTimeToMinutes(String time) {
    try {
      final parts = time.split(' ');
      final timeParts = parts[0].split(':');
      var hours = int.parse(timeParts[0]);
      final minutes = int.parse(timeParts[1]);
      final isPM = parts.length > 1 && parts[1].toUpperCase() == 'PM';
      
      if (isPM && hours != 12) hours += 12;
      if (!isPM && hours == 12) hours = 0;
      
      return hours * 60 + minutes;
    } catch (e) {
      return 720; // Default to noon
    }
  }
}

class _CalendarEvent {
  final String startTime;
  final int durationMinutes;
  final String title;
  final String? subtitle;
  final Color color;
  
  _CalendarEvent({
    required this.startTime,
    required this.durationMinutes,
    required this.title,
    this.subtitle,
    required this.color,
  });
}

/// Care Coordinator - Smart insights about recovery plan
class _CareCoordinator extends StatelessWidget {
  final RecoveryBlueprint blueprint;
  final double medicationAdherence;

  const _CareCoordinator({required this.blueprint, required this.medicationAdherence});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final insights = _generateInsights();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F38).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, color: Colors.cyan, size: 20),
              const SizedBox(width: 8),
              Text('Care Insights', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  insight.isWarning ? Icons.error_outline : Icons.check_circle_outline,
                  color: insight.isWarning ? Colors.orange.shade700 : Colors.green.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insight.message,
                    style: context.textStyles.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  List<_Insight> _generateInsights() {
    final insights = <_Insight>[];

    // Care coverage analysis
    final totalSlots = 7 * 4;
    int coveredSlots = 0;
    for (final member in blueprint.careTeam) {
      member.availability.forEach((day, periods) => coveredSlots += periods.length);
    }
    final coverage = totalSlots > 0 ? coveredSlots / totalSlots : 0.0;
    
    if (blueprint.careTeam.isEmpty) {
      insights.add(_Insight('No care team members added yet. Add family or professional caregivers.', true));
    } else if (coverage < 0.5) {
      insights.add(_Insight('${(coverage * 100).round()}% of weekly care slots covered. Add more caregivers or extend availability.', true));
    }

    // Daily routines
    if (blueprint.dailyRoutines.isEmpty) {
      insights.add(_Insight('No daily care routines scheduled. Add tasks like medications, meals, and exercises.', true));
    } else {
      final unassigned = blueprint.dailyRoutines.where((r) => r.assignedCaregiverId == null).length;
      if (unassigned > 0) {
        insights.add(_Insight('$unassigned care task${unassigned > 1 ? 's' : ''} not assigned to anyone. Assign team members for clarity.', true));
      }
    }

    // Supplies
    final lowSupplies = blueprint.supplies.where((s) => s.needsReorder).length;
    if (lowSupplies > 0) {
      insights.add(_Insight('$lowSupplies supply item${lowSupplies > 1 ? 's' : ''} running low. Restock soon to avoid shortages.', true));
    }

    // Positive message if everything looks good
    if (insights.isEmpty) {
      insights.add(_Insight('Care plan is well organized. Team coverage is good and supplies are stocked.', false));
    }

    return insights;
  }
}

class _Insight {
  final String message;
  final bool isWarning;
  _Insight(this.message, this.isWarning);
}

/// Care Team Section - Simple list of team members with scheduling
class _CareTeamSection extends StatelessWidget {
  final RecoveryBlueprint blueprint;
  final String? patientId;
  
  const _CareTeamSection({required this.blueprint, this.patientId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F38).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.cyan, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Care Team', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              TextButton.icon(
                onPressed: () {
                  debugPrint('Schedule button clicked, patientId: $patientId');
                  // Use family route if patientId is provided (family portal), otherwise patient route
                  final route = patientId != null 
                      ? '/family/recovery-blueprint/schedule'
                      : '/recovery-blueprint/schedule';
                  context.push(route, extra: patientId);
                },
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text('Schedule'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (blueprint.careTeam.isEmpty)
            Text('No team members added yet', style: context.textStyles.bodyMedium?.copyWith(color: Colors.white60))
          else
            ...blueprint.careTeam.map((member) {
              // Count availability slots
              int totalSlots = 0;
              member.availability.forEach((day, periods) => totalSlots += periods.length);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2530),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.cyan.withValues(alpha: 0.3),
                      child: Text(
                        member.name[0].toUpperCase(),
                        style: context.textStyles.titleMedium?.copyWith(color: Colors.cyan, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.name, style: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(
                            member.relationship.replaceAll('_', ' '),
                            style: context.textStyles.bodySmall?.copyWith(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$totalSlots slots',
                        style: context.textStyles.labelSmall?.copyWith(color: Colors.cyan, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Daily Care Timeline (Centerpiece)
class _DailyCareTimeline extends StatelessWidget {
  final RecoveryBlueprint blueprint;
  final Function(int index, List<String> times) onTimeUpdate;
  final Function(int index, String? caregiverId, List<String> days, List<String> supplies) onDetailsUpdate;
  
  const _DailyCareTimeline({
    required this.blueprint,
    required this.onTimeUpdate,
    required this.onDetailsUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F38).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.cyan, size: 24),
              const SizedBox(width: 8),
              Text('Daily Care Timeline', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          if (blueprint.dailyRoutines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No routines scheduled yet', style: context.textStyles.bodyMedium?.copyWith(color: Colors.white60)),
            )
          else
            ...blueprint.dailyRoutines.asMap().entries.map((entry) {
              final index = entry.key;
              final routine = entry.value;
              
              // Find assigned caregiver name
              String? assignedName;
              if (routine.assignedCaregiverId != null) {
                final member = blueprint.careTeam.where((m) => m.id == routine.assignedCaregiverId).firstOrNull;
                assignedName = member?.name;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () => _showRoutineDetailsDialog(context, routine, index, blueprint.careTeam, onDetailsUpdate, onTimeUpdate),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D2530),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                routine.type.replaceAll('_', ' ').toUpperCase(),
                                style: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                            Icon(Icons.edit, size: 16, color: Colors.white60),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Times chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...routine.timesOfDay.map((time) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.cyan.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.cyan.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time, size: 12, color: Colors.cyan),
                                  const SizedBox(width: 4),
                                  Text(
                                    time,
                                    style: context.textStyles.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.cyan,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            if (routine.timesOfDay.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_alarm, size: 12, color: Colors.cyan.withValues(alpha: 0.6)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Add time',
                                      style: context.textStyles.labelSmall?.copyWith(color: Colors.cyan.withValues(alpha: 0.6)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (assignedName != null || routine.daysPerformed.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (assignedName != null) ...[
                                Icon(Icons.person, size: 14, color: Colors.white60),
                                const SizedBox(width: 4),
                                Text(assignedName, style: context.textStyles.labelSmall?.copyWith(color: Colors.white60)),
                              ],
                              if (assignedName != null && routine.daysPerformed.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('•', style: TextStyle(color: Colors.white60)),
                                ),
                              if (routine.daysPerformed.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    routine.daysPerformed.map((d) => d.substring(0, 3).toUpperCase()).join(', '),
                                    style: context.textStyles.labelSmall?.copyWith(color: Colors.white60),
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                  ),
                                ),
                            ],
                          ),
                        ],
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
  

  static void _showRoutineDetailsDialog(
    BuildContext context,
    DailyRoutine routine,
    int index,
    List<CareTeamMember> careTeam,
    Function(int, String?, List<String>, List<String>) onDetailsUpdate,
    Function(int, List<String>) onTimeUpdate,
  ) {
    final suppliesController = TextEditingController(text: routine.suppliesNeeded.join(', '));
    String? selectedCaregiver = routine.assignedCaregiverId;
    final selectedDays = List<String>.from(routine.daysPerformed);
    final selectedTimes = List<String>.from(routine.timesOfDay);
    
    final allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (statefulContext, setDialogState) => AlertDialog(
          title: Text('Edit ${routine.type.replaceAll('_', ' ')}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Times Section
                Row(
                  children: [
                    const Text('Times:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        final now = TimeOfDay.now();
                        final time = await showTimePicker(
                          context: dialogContext,
                          initialTime: now,
                        );
                        if (time != null) {
                          final formattedTime = time.format(dialogContext);
                          if (!selectedTimes.contains(formattedTime)) {
                            setDialogState(() {
                              selectedTimes.add(formattedTime);
                              selectedTimes.sort((a, b) => _compareTimeStrings(a, b));
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Time'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.cyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (selectedTimes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No times set. Tap "Add Time" to schedule.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedTimes.map((time) => Chip(
                      label: Text(time),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setDialogState(() {
                          selectedTimes.remove(time);
                        });
                      },
                    )).toList(),
                  ),
                const SizedBox(height: 8),
                // Quick time suggestions
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['6:00 AM', '8:00 AM', '12:00 PM', '2:00 PM', '6:00 PM', '8:00 PM'].map((time) {
                    final isAdded = selectedTimes.contains(time);
                    return ActionChip(
                      label: Text(time, style: TextStyle(fontSize: 11)),
                      onPressed: isAdded ? null : () {
                        setDialogState(() {
                          selectedTimes.add(time);
                          selectedTimes.sort((a, b) => _compareTimeStrings(a, b));
                        });
                      },
                      backgroundColor: isAdded ? Colors.cyan.withValues(alpha: 0.3) : null,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                const Text('Assigned Caregiver:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCaregiver,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select caregiver',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Unassigned')),
                    ...careTeam.map((member) => DropdownMenuItem(
                      value: member.id,
                      child: Text(member.name),
                    )),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedCaregiver = value);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Days:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allDays.map((day) {
                    final isSelected = selectedDays.contains(day.toLowerCase());
                    return FilterChip(
                      label: Text(day.substring(0, 3)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            selectedDays.add(day.toLowerCase());
                          } else {
                            selectedDays.remove(day.toLowerCase());
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: suppliesController,
                  decoration: const InputDecoration(
                    labelText: 'Supplies Needed',
                    border: OutlineInputBorder(),
                    hintText: 'Comma separated',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Update times first
                onTimeUpdate(index, selectedTimes);
                // Then update other details
                onDetailsUpdate(
                  index,
                  selectedCaregiver,
                  selectedDays,
                  suppliesController.text.trim().isEmpty
                      ? []
                      : suppliesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
  
  static int _compareTimeStrings(String a, String b) {
    // Simple time comparison for sorting (AM/PM format)
    final aHour = int.tryParse(a.split(':')[0]) ?? 0;
    final bHour = int.tryParse(b.split(':')[0]) ?? 0;
    final aIsAm = a.contains('AM');
    final bIsAm = b.contains('AM');
    
    if (aIsAm && !bIsAm) return -1;
    if (!aIsAm && bIsAm) return 1;
    
    final aHour24 = aIsAm ? (aHour == 12 ? 0 : aHour) : (aHour == 12 ? 12 : aHour + 12);
    final bHour24 = bIsAm ? (bHour == 12 ? 0 : bHour) : (bHour == 12 ? 12 : bHour + 12);
    
    return aHour24.compareTo(bHour24);
  }
}

/// Equipment & Supplies Section
class _EquipmentSuppliesSection extends StatelessWidget {
  final RecoveryBlueprint blueprint;
  const _EquipmentSuppliesSection({required this.blueprint});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Equipment
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2F38).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.medical_services, color: Colors.cyan, size: 20),
                  const SizedBox(width: 8),
                  Text('Equipment', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 12),
              if (blueprint.equipment.isEmpty)
                Text('No equipment listed', style: context.textStyles.bodyMedium?.copyWith(color: Colors.white60))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: blueprint.equipment.map((eq) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Text(eq.name, style: context.textStyles.labelMedium?.copyWith(color: Colors.white)),
                  )).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Supplies
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2F38).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2, color: Colors.cyan, size: 20),
                  const SizedBox(width: 8),
                  Text('Supplies', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 12),
              if (blueprint.supplies.isEmpty)
                Text('No supplies tracked', style: context.textStyles.bodyMedium?.copyWith(color: Colors.white60))
              else
                ...blueprint.supplies.map((supply) {
                  Color statusColor = Colors.green;
                  String statusText = 'IN STOCK';
                  if (supply.needsReorder) {
                    statusColor = Colors.red;
                    statusText = 'LOW';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(supply.name, style: context.textStyles.bodyMedium?.copyWith(color: Colors.white))),
                        Text(statusText, style: context.textStyles.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

/// Strip showing collaborators on this blueprint + "last edited by …" + invite.
class _CollaboratorsBar extends StatelessWidget {
  final List<BlueprintCollaborator> collaborators;
  final RecoveryBlueprint blueprint;
  final String? liveBannerText;
  final VoidCallback onInfoTap;

  const _CollaboratorsBar({
    required this.collaborators,
    required this.blueprint,
    required this.liveBannerText,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final editor = collaborators
        .where((c) => c.userId == blueprint.updatedBy)
        .map((c) => c.displayName)
        .firstWhere((n) => n != null && n.isNotEmpty, orElse: () => null);
    final editedLabel = blueprint.updatedBy == null
        ? 'Last updated ${DateFormat.yMMMd().add_jm().format(blueprint.updatedAt)}'
        : 'Last edited by ${editor ?? 'a collaborator'} • ${DateFormat.MMMd().add_jm().format(blueprint.updatedAt)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F38).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_3, size: 18, color: Colors.cyan),
              const SizedBox(width: 8),
              Text(
                collaborators.isEmpty ? 'Solo blueprint' : 'Collaborators',
                style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(width: 8),
              if (collaborators.isNotEmpty)
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: collaborators.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final c = collaborators[i];
                        final initial = (c.displayName?.trim().isNotEmpty == true
                                ? c.displayName!.trim()[0]
                                : '?')
                            .toUpperCase();
                        return Tooltip(
                          message:
                              '${c.displayName ?? "Unknown"} • ${c.role}',
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: c.isOwner
                                ? Colors.cyan
                                : (c.canEdit ? Colors.teal : Colors.blue),
                            backgroundImage: (c.avatarUrl != null && c.avatarUrl!.isNotEmpty)
                                ? NetworkImage(c.avatarUrl!)
                                : null,
                            child: (c.avatarUrl == null || c.avatarUrl!.isEmpty)
                                ? Text(
                                    initial,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                )
              else
                const Spacer(),
              IconButton(
                onPressed: onInfoTap,
                icon: const Icon(Icons.info_outline, size: 18),
                tooltip: 'How collaborators join',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            editedLabel,
            style: context.textStyles.bodySmall?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.link, size: 12, color: Colors.white60),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Family members auto-join as viewers when they enter your patient code.',
                  style: context.textStyles.bodySmall?.copyWith(color: Colors.white60),
                ),
              ),
            ],
          ),
          if (liveBannerText != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, size: 14, color: Colors.cyan),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      liveBannerText!,
                      style: context.textStyles.labelMedium
                          ?.copyWith(color: Colors.cyan),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


