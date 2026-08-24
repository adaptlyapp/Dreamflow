import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/recovery_blueprint.dart';
import 'package:wellspring/models/user.dart';
import 'package:wellspring/models/medication.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/notification_service.dart';
import 'package:wellspring/services/tracker_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/recovery_blueprint_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/theme.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/widgets/daily_care_timeline.dart';

/// Recovery Command Center - Living visual representation of patient's recovery ecosystem
class RecoveryBlueprintDashboard extends StatefulWidget {
  final String? patientId;
  
  const RecoveryBlueprintDashboard({super.key, this.patientId});

  @override
  State<RecoveryBlueprintDashboard> createState() => _RecoveryBlueprintDashboardState();
}

class _RecoveryBlueprintDashboardState extends State<RecoveryBlueprintDashboard> {
  final _trackerService = TrackerService();
  List<CareTeamMember> _careTeam = [];
  List<DailyRoutine> _dailyRoutines = [];
  User? _patient;
  bool _loading = true;
  double _medicationAdherence = 0.0;
  final _calendarScrollController = ScrollController();
  bool _compactMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _calendarScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = widget.patientId ?? context.read<UserProvider>().currentUser?.id;
    debugPrint('RecoveryCommandCenter: Loading for userId=$userId');
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    // Load data directly from family connections and patient medications
    debugPrint('RecoveryCommandCenter: Loading care team and routines from existing data');
    
    final familyService = FamilyService();
    final blueprintService = RecoveryBlueprintService();
    final careTeamMembers = <CareTeamMember>[];
    
    // Get connected family members for care team
    if (widget.patientId != null) {
      // Family member viewing patient's blueprint - add the family member to care team
      final currentUser = await UserService().getCurrentUser();
      if (currentUser != null) {
        careTeamMembers.add(CareTeamMember(
          id: currentUser.id,
          name: currentUser.name,
          relationship: 'family',
          email: currentUser.email,
        ));
      }
    } else {
      // Patient viewing their own blueprint - add connected family members
      try {
        final familyMemberIds = await familyService.getFamilyMembersForPatient(userId);
        debugPrint('RecoveryCommandCenter: Found ${familyMemberIds.length} family members');
        
        for (final familyId in familyMemberIds) {
          try {
            final familyUser = await UserService().getUserById(familyId);
            if (familyUser != null) {
              careTeamMembers.add(CareTeamMember(
                id: familyUser.id,
                name: familyUser.name,
                relationship: 'family',
                email: familyUser.email,
              ));
            }
          } catch (e) {
            debugPrint('RecoveryCommandCenter: Error loading family member $familyId: $e');
          }
        }
      } catch (e) {
        debugPrint('RecoveryCommandCenter: Error loading family connections: $e');
      }
    }
    
    // Get patient's medications and existing blueprint routines
    final patientUser = await UserService().getUserById(userId);
    final dailyRoutines = <DailyRoutine>[];
    
    // Add medications as routines
    if (patientUser != null && patientUser.medications.isNotEmpty) {
      for (final med in patientUser.medications) {
        dailyRoutines.add(DailyRoutine(
          type: 'medication',
          daysPerformed: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
          timesOfDay: med.times,
          suppliesNeeded: [med.name, if (med.dosage != null) med.dosage!],
        ));
      }
    }
    
    // Load existing routines from Recovery Blueprint (if it exists)
    try {
      // Try to get the patient's auth_user_id as well by querying the users table
      String? authUserId;
      try {
        final response = await SupabaseConfig.client
            .from('users')
            .select('auth_user_id')
            .eq('id', userId)
            .maybeSingle();
        authUserId = response?['auth_user_id'] as String?;
        debugPrint('RecoveryCommandCenter: Patient authUserId=$authUserId');
      } catch (e) {
        debugPrint('RecoveryCommandCenter: Error getting authUserId: $e');
      }
      
      var blueprint = await blueprintService.getByUserId(userId);
      
      // If not found with profile ID, try auth user ID
      if (blueprint == null && authUserId != null && authUserId != userId) {
        debugPrint('RecoveryCommandCenter: Blueprint not found with profile ID, trying authUserId...');
        blueprint = await blueprintService.getByUserId(authUserId);
      }
      
      if (blueprint != null && blueprint.dailyRoutines.isNotEmpty) {
        debugPrint('RecoveryCommandCenter: Found existing blueprint with ${blueprint.dailyRoutines.length} routines');
        // Add non-medication routines from blueprint
        for (final routine in blueprint.dailyRoutines) {
          if (routine.type.toLowerCase() != 'medication') {
            dailyRoutines.add(routine);
            debugPrint('RecoveryCommandCenter: - Added ${routine.type} routine with ${routine.timesOfDay.length} times');
          }
        }
      } else {
        debugPrint('RecoveryCommandCenter: No existing blueprint found (tried profile ID and auth ID), will infer from tracker data');
        
        // Only analyze tracker entries if no blueprint exists
        final now = DateTime.now();
        final last30Days = now.subtract(const Duration(days: 30));
        final entries = await _trackerService.getEntriesByDateRange(userId, last30Days, now);
        
        // Check for bowel program tracking
        final bowelEntries = entries.where((e) => e.bowelProgram == true).length;
        if (bowelEntries > 0) {
          dailyRoutines.add(DailyRoutine(
            type: 'bowel',
            daysPerformed: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
            timesOfDay: ['8:00 AM'], // Default time
            suppliesNeeded: [],
          ));
        }
        
        // Check for bladder management tracking
        final bladderEntries = entries.where((e) => e.bladderSuccess != null).length;
        if (bladderEntries > 0) {
          dailyRoutines.add(DailyRoutine(
            type: 'bladder',
            daysPerformed: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
            timesOfDay: ['9:00 AM', '3:00 PM', '9:00 PM'], // Default times
            suppliesNeeded: [],
          ));
        }
        
        debugPrint('RecoveryCommandCenter: Found ${bowelEntries} bowel entries, ${bladderEntries} bladder entries');
      }
    } catch (e) {
      debugPrint('RecoveryCommandCenter: Error loading blueprint or tracker data: $e');
    }
    
    debugPrint('RecoveryCommandCenter: ✅ Data loaded!');
    debugPrint('RecoveryCommandCenter: - Care team members: ${careTeamMembers.length}');
    debugPrint('RecoveryCommandCenter: - Total routines: ${dailyRoutines.length}');
    debugPrint('RecoveryCommandCenter: - Medication routines: ${dailyRoutines.where((r) => r.type.toLowerCase() == 'medication').length}');
    debugPrint('RecoveryCommandCenter: - Care routines: ${dailyRoutines.where((r) => r.type.toLowerCase() != 'medication').length}');
    for (final routine in dailyRoutines.where((r) => r.type.toLowerCase() != 'medication')) {
      debugPrint('RecoveryCommandCenter:   * ${routine.type}: ${routine.timesOfDay}');
    }

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

    if (mounted) {
      setState(() {
        _careTeam = careTeamMembers;
        _dailyRoutines = dailyRoutines;
        _patient = patientUser;
        _medicationAdherence = adherence;
        _loading = false;
      });
    }
  }

  Future<void> _deleteMedication(Medication medication) async {
    if (_patient == null) {
      debugPrint('RecoveryCommandCenter._deleteMedication: no patient loaded');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medication'),
        content: Text('Are you sure you want to delete ${medication.name}? All reminders will be cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Remove from medications list
    final updatedMedications = _patient!.medications.where((med) => med.id != medication.id).toList();
    final updatedUser = _patient!.copyWith(medications: updatedMedications);

    try {
      await UserService().saveUser(updatedUser);
      debugPrint('RecoveryCommandCenter._deleteMedication: Deleted ${medication.name}');
      
      // Cancel all notifications for this medication (both patient and family reminders)
      await NotificationService.instance.cancelMedication(medication.id);
      
      // Cancel family medication reminders for this specific medication
      final patientId = widget.patientId ?? _patient?.id;
      if (patientId != null) {
        await NotificationService.instance.cancelFamilyMedicationReminders(patientId);
        
        // Re-schedule remaining medications for family members
        final remainingMeds = updatedUser.medications;
        if (remainingMeds.isNotEmpty) {
          final patientName = _patient?.name ?? 'Patient';
          await NotificationService.instance.scheduleFamilyMedicationReminders(
            medications: remainingMeds,
            patientName: patientName,
            patientId: patientId,
          );
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${medication.name} deleted')),
        );
        // Reload to refresh UI
        _load();
      }
    } catch (e) {
      debugPrint('RecoveryCommandCenter._deleteMedication: error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting medication: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A20),
      // Keep content below the AppBar to avoid header overlap
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Recovery Blueprint', style: context.textStyles.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_compactMode ? Icons.view_agenda : Icons.view_compact, color: Colors.white),
            tooltip: _compactMode ? 'Expanded View' : 'Compact View',
            onPressed: () => setState(() => _compactMode = !_compactMode),
          ),
        ],
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
            : SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  // Add generous top padding (below AppBar) and bottom padding (above bottom nav)
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  child: _compactMode
                      ? _buildCompactView()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                              // Today's Schedule Summary
                              _TodayScheduleSummary(
                                careTeam: _careTeam,
                                dailyRoutines: _dailyRoutines,
                                patient: _patient,
                                patientId: widget.patientId,
                              ),
                              const SizedBox(height: 16),
                              
                              // Care Coordinator - Key insights
                              _CareCoordinator(
                                careTeam: _careTeam,
                                dailyRoutines: _dailyRoutines,
                                medicationAdherence: _medicationAdherence,
                              ),
                              const SizedBox(height: 16),

                              // Medications Section
                              _MedicationsSection(
                                patient: _patient,
                                onDeleteMedication: _deleteMedication,
                              ),
                              const SizedBox(height: 16),
                              
                              // Daily Care Timeline (shared widget)
                              DailyCareTimeline(
                                dailyRoutines: _dailyRoutines,
                                patientId: widget.patientId,
                              ),
                              const SizedBox(height: 16),

                              // Care Team - Who's helping and when
                              _CareTeamSection(
                                careTeam: _careTeam,
                                patientId: widget.patientId,
                              ),
                          ],
                        ),
                ),
              ),
      ),
    );
  }

  Widget _buildCompactView() {
    final careRoutines = _dailyRoutines.where((r) => r.type.toLowerCase() != 'medication').toList();
    final medications = _patient?.medications ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Compact Summary Cards Row
        Row(
          children: [
            Expanded(
              child: _buildCompactCard(
                icon: Icons.medication,
                title: 'Medications',
                count: '${medications.length}',
                color: const Color(0xFFE91E63),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactCard(
                icon: Icons.access_time,
                title: 'Care Routines',
                count: '${careRoutines.length}',
                color: Colors.cyan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactCard(
                icon: Icons.people,
                title: 'Care Team',
                count: '${_careTeam.length}',
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Compact Medications List
        if (medications.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2F38).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.medication, color: const Color(0xFFE91E63), size: 20),
                    const SizedBox(width: 8),
                    Text('Medications', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 12),
                ...medications.map((med) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          med.name,
                          style: context.textStyles.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ),
                      ...med.times.take(3).map((time) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            time,
                            style: context.textStyles.labelSmall?.copyWith(color: const Color(0xFFE91E63), fontSize: 10),
                          ),
                        ),
                      )),
                      if (med.times.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '+${med.times.length - 3}',
                            style: context.textStyles.labelSmall?.copyWith(color: Colors.white60, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Compact Care Routines List
        if (careRoutines.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2F38).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.cyan, size: 20),
                    const SizedBox(width: 8),
                    Text('Daily Care Timeline', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 12),
                ...careRoutines.map((routine) {
                  Color routineColor = Colors.cyan;
                  switch (routine.type.toLowerCase()) {
                    case 'bowel':
                      routineColor = const Color(0xFF9C27B0);
                      break;
                    case 'bladder':
                      routineColor = const Color(0xFF2196F3);
                      break;
                    case 'skin_check':
                      routineColor = const Color(0xFF00BCD4);
                      break;
                    case 'therapy':
                      routineColor = const Color(0xFFFF9800);
                      break;
                    case 'nutrition':
                      routineColor = const Color(0xFF4CAF50);
                      break;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: routineColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            routine.type.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
                            style: context.textStyles.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ),
                        ...routine.timesOfDay.take(3).map((time) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: routineColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              time,
                              style: context.textStyles.labelSmall?.copyWith(color: routineColor, fontSize: 10),
                            ),
                          ),
                        )),
                        if (routine.timesOfDay.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '+${routine.timesOfDay.length - 3}',
                              style: context.textStyles.labelSmall?.copyWith(color: Colors.white60, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Compact Care Team List
        if (_careTeam.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2F38).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text('Care Team', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 12),
                ..._careTeam.map((member) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.orange.withValues(alpha: 0.3),
                        child: Text(
                          member.name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          member.name,
                          style: context.textStyles.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        member.relationship.replaceAll('_', ' '),
                        style: context.textStyles.bodySmall?.copyWith(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCompactCard({
    required IconData icon,
    required String title,
    required String count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F38).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            count,
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: context.textStyles.labelSmall?.copyWith(
              color: Colors.white70,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Week Calendar View - Visual calendar with time-blocked events
class _TodayScheduleSummary extends StatefulWidget {
  final List<CareTeamMember> careTeam;
  final List<DailyRoutine> dailyRoutines;
  final User? patient;
  final String? patientId;
  
  const _TodayScheduleSummary({
    required this.careTeam,
    required this.dailyRoutines,
    required this.patient,
    this.patientId,
  });

  @override
  State<_TodayScheduleSummary> createState() => _TodayScheduleSummaryState();
}

class _TodayScheduleSummaryState extends State<_TodayScheduleSummary> {
  DateTime _selectedWeekStart = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _selectedWeekStart = _getWeekStart(DateTime.now());
  }
  
  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildHeader(cs),
          _WeekCalendarView(
            careTeam: widget.careTeam,
            dailyRoutines: widget.dailyRoutines,
            patient: widget.patient,
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
    
    for (var i = 0; i < widget.careTeam.length; i++) {
      memberColors[widget.careTeam[i].id] = colorPalette[i % colorPalette.length];
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
  final List<CareTeamMember> careTeam;
  final List<DailyRoutine> dailyRoutines;
  final User? patient;
  final DateTime weekStart;
  final Map<String, Color> memberColors;
  
  const _WeekCalendarView({
    required this.careTeam,
    required this.dailyRoutines,
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
    
    // Add daily routines (exclude medications as they're shown separately)
    for (var routine in widget.dailyRoutines) {
      // Skip medication routines - they're already shown from patient.medications
      if (routine.type.toLowerCase() == 'medication') continue;
      
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
          ? widget.careTeam.where((m) => m.id == routine.assignedCaregiverId).firstOrNull
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
    for (var member in widget.careTeam) {
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
  final List<CareTeamMember> careTeam;
  final List<DailyRoutine> dailyRoutines;
  final double medicationAdherence;

  const _CareCoordinator({
    required this.careTeam,
    required this.dailyRoutines,
    required this.medicationAdherence,
  });

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
    for (final member in careTeam) {
      member.availability.forEach((day, periods) => coveredSlots += periods.length);
    }
    final coverage = totalSlots > 0 ? coveredSlots / totalSlots : 0.0;
    
    if (careTeam.isEmpty) {
      insights.add(_Insight('No care team members added yet. Add family or professional caregivers.', true));
    } else if (coverage < 0.5) {
      insights.add(_Insight('${(coverage * 100).round()}% of weekly care slots covered. Add more caregivers or extend availability.', true));
    }

    // Daily routines
    if (dailyRoutines.isEmpty) {
      insights.add(_Insight('No daily care routines scheduled. Add tasks like medications, meals, and exercises.', true));
    } else {
      final unassigned = dailyRoutines.where((r) => r.assignedCaregiverId == null).length;
      if (unassigned > 0) {
        insights.add(_Insight('$unassigned care task${unassigned > 1 ? 's' : ''} not assigned to anyone. Assign team members for clarity.', true));
      }
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

/// Medications Section - Display patient medications
class _MedicationsSection extends StatefulWidget {
  final User? patient;
  final Future<void> Function(Medication)? onDeleteMedication;
  
  const _MedicationsSection({required this.patient, this.onDeleteMedication});

  @override
  State<_MedicationsSection> createState() => _MedicationsSectionState();
}

class _MedicationsSectionState extends State<_MedicationsSection> {
  bool _expanded = false;

  void _showMedicationOptions(BuildContext context, Medication medication) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2F38),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete, color: cs.error),
              title: Text('Delete Medication', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(ctx).pop();
                if (widget.onDeleteMedication != null) {
                  widget.onDeleteMedication!(medication);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final medications = widget.patient?.medications ?? [];

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
                  Icon(Icons.medication, color: const Color(0xFFE91E63), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medications',
                          style: context.textStyles.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${medications.length} medication${medications.length != 1 ? 's' : ''}',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && medications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: medications.map((med) {
                  return InkWell(
                    onLongPress: widget.onDeleteMedication != null
                        ? () => _showMedicationOptions(context, med)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2530),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Row(
                          children: [
                            Icon(Icons.medication, size: 20, color: const Color(0xFFE91E63)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                med.name,
                                style: context.textStyles.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (med.dosage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            med.dosage!,
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                        if (med.times.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: med.times.map((time) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time, size: 12, color: const Color(0xFFE91E63)),
                                  const SizedBox(width: 4),
                                  Text(
                                    time,
                                    style: context.textStyles.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFE91E63),
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ],
                        ],
                      ),
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

/// Care Team Section - Simple list of team members with scheduling
class _CareTeamSection extends StatelessWidget {
  final List<CareTeamMember> careTeam;
  final String? patientId;
  
  const _CareTeamSection({required this.careTeam, this.patientId});

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
          if (careTeam.isEmpty)
            Text('No team members added yet', style: context.textStyles.bodyMedium?.copyWith(color: Colors.white60))
          else
            ...careTeam.map((member) {
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
class _DailyCareTimeline extends StatefulWidget {
  final List<DailyRoutine> dailyRoutines;
  final String? patientId;
  
  const _DailyCareTimeline({
    required this.dailyRoutines,
    this.patientId,
  });

  @override
  State<_DailyCareTimeline> createState() => _DailyCareTimelineState();
}

class _DailyCareTimelineState extends State<_DailyCareTimeline> {
  bool _expanded = true;

  Future<void> _addNewRoutine() async {
    final newRoutine = await showDialog<DailyRoutine>(
      context: context,
      builder: (context) => _AddRoutineDialog(),
    );

    if (newRoutine == null) return;

    // Save to database
    try {
      // Use patientId if provided (for family portal), otherwise use current user
      final userId = widget.patientId ?? Provider.of<UserProvider>(context, listen: false).currentUser?.id;
      if (userId == null) return;
      
      debugPrint('[DailyCareTimeline] Adding routine for userId=$userId (patientId=${widget.patientId})');

      final blueprintService = RecoveryBlueprintService();
      
      // Get existing blueprint or create new one
      var blueprint = await blueprintService.getByUserId(userId);
      
      if (blueprint == null) {
        // Create a new blueprint with the routine
        blueprint = RecoveryBlueprint(
          id: const Uuid().v4(),
          userId: userId,
          patientProfile: PatientProfile(
            primaryDiagnosis: 'Unknown',
            recoveryPhase: RecoveryPhase.postDischarge,
          ),
          careTeam: const [],
          independenceAssessment: const IndependenceAssessment(),
          homeReadiness: const HomeReadiness(),
          dailyRoutines: [newRoutine],
          equipment: const [],
          supplies: const [],
          roadmap: const RecoveryRoadmap(
            immediatePriorities: [],
            shortTermGoals: [],
            longTermGoals: [],
            warnings: [],
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await blueprintService.create(blueprint);
      } else {
        // Add routine to existing blueprint
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
          SnackBar(content: Text('Routine added successfully'), backgroundColor: Colors.green),
        );
        // Reload the dashboard
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecoveryBlueprintDashboard(patientId: widget.patientId),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving routine: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving routine: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteRoutine(DailyRoutine routine) async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2F38),
        title: Text('Delete Routine', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete the ${routine.type.replaceAll('_', ' ')} routine?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Delete from database
    try {
      // Use patientId if provided (for family portal), otherwise use current user
      final userId = widget.patientId ?? Provider.of<UserProvider>(context, listen: false).currentUser?.id;
      if (userId == null) return;
      
      debugPrint('[DailyCareTimeline] Deleting routine for userId=$userId (patientId=${widget.patientId})');

      final blueprintService = RecoveryBlueprintService();
      final blueprint = await blueprintService.getByUserId(userId);
      
      if (blueprint == null) return;

      // Remove the routine
      final updatedRoutines = blueprint.dailyRoutines.where((r) => 
        !(r.type == routine.type && 
          r.timesOfDay.join(',') == routine.timesOfDay.join(',') &&
          r.daysPerformed.join(',') == routine.daysPerformed.join(','))
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
          SnackBar(content: Text('Routine deleted successfully'), backgroundColor: Colors.green),
        );
        // Reload the dashboard
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecoveryBlueprintDashboard(patientId: widget.patientId),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting routine: $e');
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
                        Text(
                          'Daily Care Timeline',
                          style: context.textStyles.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${careRoutines.length} routine${careRoutines.length != 1 ? 's' : ''}',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _addNewRoutine,
                    icon: const Icon(Icons.add_circle, color: Colors.cyan, size: 28),
                    tooltip: 'Add routine',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.cyan.withValues(alpha: 0.2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                  ),
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
                        Text(
                          'No care routines added yet.',
                          style: context.textStyles.bodyMedium?.copyWith(color: Colors.white60),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _addNewRoutine,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Care Routine'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: careRoutines.map((routine) {
                        // Determine color based on routine type
                        Color routineColor = Colors.cyan;
                        IconData routineIcon = Icons.schedule;
                        
                        switch (routine.type.toLowerCase()) {
                          case 'bowel':
                            routineColor = const Color(0xFF9C27B0); // Purple
                            routineIcon = Icons.spa;
                            break;
                          case 'bladder':
                            routineColor = const Color(0xFF2196F3); // Blue
                            routineIcon = Icons.water_drop;
                            break;
                          case 'skin_check':
                            routineColor = const Color(0xFF00BCD4); // Cyan
                            routineIcon = Icons.health_and_safety;
                            break;
                          case 'therapy':
                            routineColor = const Color(0xFFFF9800); // Orange
                            routineIcon = Icons.fitness_center;
                            break;
                          case 'nutrition':
                            routineColor = const Color(0xFF4CAF50); // Green
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
                                      style: context.textStyles.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteRoutine(routine),
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    tooltip: 'Delete routine',
                                    color: Colors.red.shade300,
                                    style: IconButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
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
                                        Text(
                                          time,
                                          style: context.textStyles.labelSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: routineColor,
                                          ),
                                        ),
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
                                    decoration: BoxDecoration(
                                      color: routineColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      day.substring(0, 3).toUpperCase(),
                                      style: context.textStyles.labelSmall?.copyWith(
                                        color: Colors.white60,
                                        fontSize: 10,
                                      ),
                                    ),
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

/// Dialog to add a new daily care routine
class _AddRoutineDialog extends StatefulWidget {
  @override
  State<_AddRoutineDialog> createState() => _AddRoutineDialogState();
}

class _AddRoutineDialogState extends State<_AddRoutineDialog> {
  String _selectedType = 'bowel';
  final _timeControllers = <TextEditingController>[];
  final _times = <String>[];
  final _selectedDays = <String>{};
  
  final _routineTypes = [
    {'value': 'bowel', 'label': 'Bowel Program', 'icon': Icons.spa},
    {'value': 'bladder', 'label': 'Bladder Management', 'icon': Icons.water_drop},
    {'value': 'skin_check', 'label': 'Skin Check', 'icon': Icons.health_and_safety},
    {'value': 'therapy', 'label': 'Therapy', 'icon': Icons.fitness_center},
    {'value': 'nutrition', 'label': 'Nutrition', 'icon': Icons.restaurant},
  ];
  
  final _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  
  @override
  void initState() {
    super.initState();
    // Add all days by default
    _selectedDays.addAll(_days.map((d) => d.toLowerCase()));
    // Add one default time
    _addTimeField('8:00 AM');
  }
  
  @override
  void dispose() {
    for (var controller in _timeControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  void _addTimeField([String? initialTime]) {
    final controller = TextEditingController(text: initialTime ?? '');
    _timeControllers.add(controller);
    if (initialTime != null) {
      _times.add(initialTime);
    }
  }
  
  void _removeTimeField(int index) {
    setState(() {
      _timeControllers[index].dispose();
      _timeControllers.removeAt(index);
      if (index < _times.length) {
        _times.removeAt(index);
      }
    });
  }
  
  void _saveRoutine() {
    // Collect times from controllers
    final times = _timeControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    
    if (times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one time'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    final routine = DailyRoutine(
      type: _selectedType,
      daysPerformed: _selectedDays.toList(),
      timesOfDay: times,
      suppliesNeeded: [],
    );
    
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
                Icon(Icons.add_circle_outline, color: Colors.cyan, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add Care Routine',
                    style: context.textStyles.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Routine Type
                    Text('Routine Type', style: context.textStyles.titleSmall?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _routineTypes.map((type) {
                        final isSelected = _selectedType == type['value'];
                        return FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(type['icon'] as IconData, size: 16, color: isSelected ? Colors.white : Colors.white60),
                              const SizedBox(width: 6),
                              Text(type['label'] as String),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedType = type['value'] as String);
                          },
                          selectedColor: Colors.cyan,
                          backgroundColor: const Color(0xFF0D2530),
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white60),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    
                    // Times
                    Row(
                      children: [
                        Text('Times', style: context.textStyles.titleSmall?.copyWith(color: Colors.white70)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _addTimeField());
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Time'),
                          style: TextButton.styleFrom(foregroundColor: Colors.cyan),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._timeControllers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final controller = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  hintText: '8:00 AM',
                                  filled: true,
                                  fillColor: const Color(0xFF0D2530),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.cyan.withValues(alpha: 0.3)),
                                  ),
                                  hintStyle: TextStyle(color: Colors.white30),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            if (_timeControllers.length > 1) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _removeTimeField(index),
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    
                    // Days
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveRoutine,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save Routine'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


