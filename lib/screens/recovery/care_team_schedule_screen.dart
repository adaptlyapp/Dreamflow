import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/recovery_blueprint.dart';
import 'package:wellspring/models/user.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/recovery_blueprint_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';
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
  final _familyService = FamilyService();
  final _supabase = SupabaseConfig.client;
  RecoveryBlueprint? _blueprint;
  User? _patient;
  List<CareTeamMember> _connectedFamilyMembers = [];
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
    final patientProfileId =
        widget.patientId ?? context.read<UserProvider>().currentUser?.id;
    if (patientProfileId == null) {
      setState(() => _loading = false);
      return;
    }

    // Get the auth user ID for blueprint queries (recovery_blueprints.user_id references auth.users)
    final authUserId = _supabase.auth.currentUser?.id;
    if (authUserId == null) {
      setState(() => _loading = false);
      return;
    }

    var bp = await _service.getByUserId(authUserId);
    final patient = await _userService.getUserById(patientProfileId);

    debugPrint(
        '[CareTeamSchedule] Loaded blueprint with ${bp?.dailyRoutines.length ?? 0} routines');
    if (bp != null) {
      for (var routine in bp.dailyRoutines) {
        debugPrint(
            '[CareTeamSchedule]   - ${routine.type}: ${routine.timesOfDay}');
      }

      // Load connected family members from family_patient_links and add them to blueprint
      bp = await _loadConnectedFamilyMembers(patientProfileId, bp);
    }

    debugPrint(
        '[CareTeamSchedule] Loaded patient with ${patient?.medications.length ?? 0} medications');
    if (patient != null) {
      for (var med in patient.medications) {
        debugPrint('[CareTeamSchedule]   - ${med.name}: ${med.times}');
      }
    }

    if (mounted) {
      setState(() {
        _blueprint = bp;
        _patient = patient;
        _connectedFamilyMembers =
            bp?.careTeam.where((m) => m.id.startsWith('family_')).toList() ??
                [];
        _loading = false;
      });
      debugPrint('[CareTeamSchedule] _load() completed, setState called');
      debugPrint(
          '[CareTeamSchedule] Connected family members: ${_connectedFamilyMembers.length}');
    }
  }

  /// Load family members connected via patient code and merge them into the blueprint
  /// Returns the updated blueprint with family members added
  Future<RecoveryBlueprint> _loadConnectedFamilyMembers(
      String patientId, RecoveryBlueprint blueprint) async {
    try {
      debugPrint('[CareTeamSchedule] ════════════════════════════════════════');
      debugPrint('[CareTeamSchedule] Loading connected family members');
      debugPrint('[CareTeamSchedule] Patient profile ID: $patientId');
      debugPrint('[CareTeamSchedule] Blueprint user_id: ${blueprint.userId}');
      debugPrint('[CareTeamSchedule] ════════════════════════════════════════');

      // NEW SCHEMA: patient_id in family_patient_links is auth.users(id).
      // The patientId param may be either the users profile id OR the auth id.
      // Look up the patient's auth_user_id from the users table if needed.
      String patientAuthId = patientId;
      try {
        final row = await _supabase
            .from('users')
            .select('auth_user_id')
            .eq('id', patientId)
            .maybeSingle();
        final resolved = row?['auth_user_id'] as String?;
        if (resolved != null && resolved.isNotEmpty) {
          patientAuthId = resolved;
        }
      } catch (_) {}

      debugPrint('[CareTeamSchedule] Resolved patient auth id: $patientAuthId');

      final links = await _supabase
          .from('family_patient_links')
          .select('family_member_id, patient_id')
          .eq('patient_id', patientAuthId);

      debugPrint(
          '[CareTeamSchedule] Query result: ${links.length} links found');
      for (final link in links) {
        debugPrint(
            '[CareTeamSchedule]   - patient_id: ${link['patient_id']}, family_member_id: ${link['family_member_id']}');
      }

      if (links.isEmpty) {
        debugPrint(
            '[CareTeamSchedule] ⚠️ No family links found for patient_id=$patientId');
        debugPrint(
            '[CareTeamSchedule] This means no family members have connected to this patient yet');
        return blueprint;
      }

      debugPrint('[CareTeamSchedule] Found ${links.length} family links');

      final newFamilyMembers = <CareTeamMember>[];

      // For each link, get the family member's info
      for (final link in links) {
        final familyMemberId = link['family_member_id'] as String;
        final memberIdInTeam = 'family_$familyMemberId';

        // Check if this family member is already in the care team
        final existingMember = blueprint.careTeam.firstWhere(
          (m) => m.id == memberIdInTeam,
          orElse: () => CareTeamMember(id: '', name: '', relationship: ''),
        );

        if (existingMember.id.isNotEmpty) {
          // Already in team, skip
          debugPrint(
              '[CareTeamSchedule]   ℹ️ Family member $memberIdInTeam already in care team');
          continue;
        }

        // Not in team yet, load their info and add them.
        // NEW SCHEMA: familyMemberId is an auth.users(id). Look up their profile from users table.
        try {
          Map<String, dynamic>? familyData = await _supabase
              .from('users')
              .select('id, name, email, auth_user_id, role')
              .eq('auth_user_id', familyMemberId)
              .eq('role', 'family')
              .maybeSingle();

          // Fallback: legacy family_members table
          familyData ??= await _supabase
              .from('family_members')
              .select('id, name, email, auth_user_id')
              .eq('auth_user_id', familyMemberId)
              .maybeSingle();

          if (familyData != null) {
            final name = familyData['name'] as String? ?? 'Family Member';
            final email = familyData['email'] as String?;

            // Create a CareTeamMember from this family member
            final member = CareTeamMember(
              id: memberIdInTeam,
              name: name,
              relationship: 'Family Member',
              email: email,
              roles: ['family'],
              availability: {},
              schedule: {},
            );

            newFamilyMembers.add(member);
            debugPrint(
                '[CareTeamSchedule]   ✓ Will add family member to care team: $name');
          }
        } catch (e) {
          debugPrint(
              '[CareTeamSchedule]   ✗ Error loading family member $familyMemberId: $e');
        }
      }

      // If there are new family members, add them to the blueprint
      if (newFamilyMembers.isNotEmpty) {
        debugPrint(
            '[CareTeamSchedule] Adding ${newFamilyMembers.length} new family members to blueprint...');

        final updatedBlueprint = RecoveryBlueprint(
          id: blueprint.id,
          userId: blueprint.userId,
          patientProfile: blueprint.patientProfile,
          careTeam: [...blueprint.careTeam, ...newFamilyMembers],
          independenceAssessment: blueprint.independenceAssessment,
          homeReadiness: blueprint.homeReadiness,
          dailyRoutines: blueprint.dailyRoutines,
          equipment: blueprint.equipment,
          supplies: blueprint.supplies,
          roadmap: blueprint.roadmap,
          createdAt: blueprint.createdAt,
          updatedAt: DateTime.now(),
        );

        await _service.update(updatedBlueprint);
        debugPrint(
            '[CareTeamSchedule] ✓ Blueprint updated with connected family members');
        return updatedBlueprint;
      }

      return blueprint;
    } catch (e) {
      debugPrint(
          '[CareTeamSchedule] Error loading connected family members: $e');
      return blueprint;
    }
  }

  Future<void> _createBlueprintAndAddMember() async {
    final currentUser = context.read<UserProvider>().currentUser;
    final authUserId = _supabase.auth.currentUser?.id;
    
    if (currentUser == null || authUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to create care schedule. Please sign in.')),
        );
      }
      return;
    }

    // Only allow patients to create their own blueprint (not family members viewing)
    if (widget.patientId != null && widget.patientId != currentUser.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only the patient can create their care team schedule.')),
        );
      }
      return;
    }

    // Create a minimal blueprint for the current auth user
    // IMPORTANT: recovery_blueprints.user_id references auth.users(id), not the patient profile id
    final now = DateTime.now();
    final newBlueprint = RecoveryBlueprint(
      id: const Uuid().v4(),
      userId: authUserId,
      patientProfile: const PatientProfile(
        primaryDiagnosis: 'General Care',
        recoveryPhase: RecoveryPhase.postDischarge,
      ),
      careTeam: [],
      independenceAssessment: const IndependenceAssessment(),
      homeReadiness: const HomeReadiness(),
      createdAt: now,
      updatedAt: now,
    );

    try {
      // Save the blueprint
      await _service.create(newBlueprint);
      
      // Reload to populate _blueprint - this must complete before showing the dialog
      await _load();

      // Show the add member dialog only after _blueprint is loaded
      if (mounted && _blueprint != null) {
        _showAddMemberDialog();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blueprint created but failed to load. Please try again.')),
        );
      }
    } catch (e) {
      debugPrint('Error creating blueprint: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating care schedule: $e')),
        );
      }
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
                decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationshipController,
                decoration: const InputDecoration(
                    labelText: 'Relationship (e.g., Spouse, Nurse)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => context.pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty ||
                  relationshipController.text.trim().isEmpty) {
                // Close dialog first so SnackBar is visible
                context.pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Name and relationship are required')),
                  );
                }
                return;
              }

              if (_blueprint == null) {
                // Close dialog first so SnackBar is visible
                context.pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Blueprint not loaded. Please close and try again.')),
                  );
                }
                return;
              }

              final newMember = CareTeamMember(
                id: const Uuid().v4(),
                name: nameController.text.trim(),
                relationship: relationshipController.text.trim(),
                phone: phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim(),
                email: emailController.text.trim().isEmpty
                    ? null
                    : emailController.text.trim(),
                availability: {},
              );

              try {
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
                await _load();
                if (mounted) context.pop();
              } catch (e) {
                debugPrint('Error adding team member: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding team member: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteMemberDialog(CareTeamMember member) {
    final isFamilyMember = member.id.startsWith('family_');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Team Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to remove ${member.name} from your care team?'),
            if (isFamilyMember) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, 
                      size: 20, 
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will disconnect the family member and revoke their access to your health data.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              context.pop();
              await _deleteMember(member.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMember(String memberId) async {
    try {
      // Check if this is a family member connected via patient code
      final isFamilyMember = memberId.startsWith('family_');
      
      if (isFamilyMember) {
        // Extract the family member's auth user ID from the memberId
        // memberId format: 'family_<auth_user_id>'
        final familyAuthId = memberId.substring('family_'.length);
        final patientId = widget.patientId ?? context.read<UserProvider>().currentUser?.id;
        
        if (patientId != null) {
          debugPrint('[CareTeamSchedule] Disconnecting family member: $familyAuthId from patient: $patientId');
          
          // Disconnect from family_patient_links and revoke blueprint access
          final success = await _familyService.disconnectFamilyMember(
            patientId: patientId,
            familyMemberId: familyAuthId,
          );
          
          if (!success) {
            throw Exception('Failed to disconnect family member from Supabase');
          }
        }
      }
      
      // Remove from care team in blueprint
      final updatedTeam =
          _blueprint!.careTeam.where((m) => m.id != memberId).toList();

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
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFamilyMember 
              ? '✓ Family member disconnected and removed from care team' 
              : '✓ Team member removed'),
          ),
        );
      }
    } catch (e) {
      debugPrint('[CareTeamSchedule] Error deleting team member: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove member: $e')),
        );
      }
    }
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
    final selectedActivities =
        List<String>.from(existingSlot?.activities ?? []);

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
          title: Text(
              '${member.name} - ${DateFormat('MMM d').format(date)}, $period'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('What will they help with?',
                      style: TextStyle(fontWeight: FontWeight.w600)),
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
                      if (value.trim().isNotEmpty &&
                          !selectedActivities.contains(value.trim())) {
                        setDialogState(() {
                          selectedActivities.add(value.trim());
                          activityController.clear();
                        });
                      }
                    },
                  ),
                  if (selectedActivities.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Selected activities:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...selectedActivities.map((activity) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(activity)),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  setDialogState(() =>
                                      selectedActivities.remove(activity));
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
                      _updateTimeSlot(
                          memberId, date, period, selectedActivities);
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateTimeSlot(String memberId, DateTime date, String period,
      List<String> activities) async {
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

    final updatedTeam = _blueprint!.careTeam
        .map((m) => m.id == memberId ? updatedMember : m)
        .toList();

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
      if (member.schedule.containsKey(dateKey) &&
          member.schedule[dateKey]!.isNotEmpty) {
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
              ? _buildNoBlueprintState(cs)
              : _blueprint!.careTeam.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64, color: cs.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text('No team members yet',
                                style: context.textStyles.headlineSmall),
                            const SizedBox(height: 8),
                            Text(
                              'Add family members or caregivers to start collaborative scheduling',
                              style: context.textStyles.bodyMedium
                                  ?.withColor(cs.onSurfaceVariant),
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
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom + 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTodayScheduleSummary(cs),
                          const SizedBox(height: 16),
                          _buildCalendarCard(cs),
                          const SizedBox(height: 16),
                          _buildWeekTimelineView(cs),
                          const SizedBox(height: 16),
                          _buildMedicationsSection(cs),
                          const SizedBox(height: 16),
                          _buildDailyCareTimelineSection(cs),
                          const SizedBox(height: 16),
                          _buildTeamLegend(cs),
                          if (_selectedDay != null) ...[
                            const SizedBox(height: 16),
                            _buildDaySchedule(cs),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildNoBlueprintState(ColorScheme cs) {
    // Check if viewing as family member (patientId is set and different from current user)
    final currentUserId = context.read<UserProvider>().currentUser?.id;
    final isViewingAsFamily = widget.patientId != null && widget.patientId != currentUserId;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              isViewingAsFamily ? 'No Care Team Set Up' : 'Set Up Your Care Team',
              style: context.textStyles.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              isViewingAsFamily
                  ? 'The patient needs to set up their care team schedule first'
                  : 'Create a care schedule to coordinate with family members and caregivers',
              style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (!isViewingAsFamily) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _createBlueprintAndAddMember,
                icon: const Icon(Icons.person_add),
                label: const Text('Add First Team Member'),
              ),
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
        return member.schedule[todayKey]
                ?.any((slot) => slot.period == periodKey) ??
            false;
      }).toList();
    }

    // Check if there's any schedule for today
    final hasScheduleToday =
        todaySchedule.values.any((members) => members.isNotEmpty);
    
    // Get today's medications
    final todayMedications = _patient?.medications ?? [];
    
    // Get today's routines
    final dayName = DateFormat('EEEE').format(today).toLowerCase();
    final todayRoutines = _blueprint!.dailyRoutines.where((routine) {
      return routine.daysPerformed.isEmpty ||
          routine.daysPerformed.any((day) => day.toLowerCase() == dayName);
    }).toList();
    
    final hasAnythingToday = hasScheduleToday || todayMedications.isNotEmpty || todayRoutines.isNotEmpty;

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
            if (!hasAnythingToday)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: cs.onSurfaceVariant, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No activities scheduled for today',
                        style: context.textStyles.bodyMedium
                            ?.withColor(cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              )
            else ...[              
              // Medications section
              if (todayMedications.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.medication, size: 16, color: Colors.pink),
                          const SizedBox(width: 8),
                          Text(
                            'Medications',
                            style: context.textStyles.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.pink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...todayMedications.map((med) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      med.name,
                                      style: context.textStyles.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                     // Caregiver assignment
                                     if ((med.assignedCaregiverId ?? '').isNotEmpty)
                                       Builder(builder: (context) {
                                         final member = _blueprint?.careTeam.firstWhere(
                                           (m) => m.id == med.assignedCaregiverId,
                                           orElse: () => CareTeamMember(id: '', name: '', relationship: ''),
                                         );
                                         final color = member != null && member.id.isNotEmpty
                                             ? _getMemberColors()[member.id]
                                             : null;
                                         if (member == null || member.id.isEmpty) return const SizedBox.shrink();
                                         return Padding(
                                           padding: const EdgeInsets.only(top: 2),
                                           child: Row(
                                             children: [
                                               if (color != null)
                                                 Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                               if (color != null) const SizedBox(width: 6),
                                               Flexible(
                                                 child: Text(
                                                   member.name,
                                                   style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
                                                   overflow: TextOverflow.ellipsis,
                                                 ),
                                               ),
                                             ],
                                           ),
                                         );
                                       }),
                                    if (med.dosage?.isNotEmpty ?? false)
                                      Text(
                                        med.dosage!,
                                        style: context.textStyles.bodySmall?.withColor(
                                          cs.onSurfaceVariant,
                                        ),
                                      ),
                                    if (med.times.isNotEmpty)
                                      Text(
                                        med.times.map((t) => _convert24To12Hour(t)).join(', '),
                                        style: context.textStyles.bodySmall?.withColor(
                                          cs.primary,
                                        ),
                                      ),
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
                const SizedBox(height: 12),
              ],
              
              // Routines section
              if (todayRoutines.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: cs.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Daily Care Routines',
                            style: context.textStyles.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...todayRoutines.map((routine) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      routine.type,
                                      style: context.textStyles.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                     // Caregiver assignment
                                     if ((routine.assignedCaregiverId ?? '').isNotEmpty)
                                       Builder(builder: (context) {
                                         final member = _blueprint?.careTeam.firstWhere(
                                           (m) => m.id == routine.assignedCaregiverId,
                                           orElse: () => CareTeamMember(id: '', name: '', relationship: ''),
                                         );
                                         final color = member != null && member.id.isNotEmpty
                                             ? _getMemberColors()[member.id]
                                             : null;
                                         if (member == null || member.id.isEmpty) return const SizedBox.shrink();
                                         return Padding(
                                           padding: const EdgeInsets.only(top: 2),
                                           child: Row(
                                             children: [
                                               if (color != null)
                                                 Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                               if (color != null) const SizedBox(width: 6),
                                               Flexible(
                                                 child: Text(
                                                   member.name,
                                                   style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
                                                   overflow: TextOverflow.ellipsis,
                                                 ),
                                               ),
                                             ],
                                           ),
                                         );
                                       }),
                                    if (routine.timesOfDay.isNotEmpty)
                                      Text(
                                        routine.timesOfDay.map((t) => _convert24To12Hour(t)).join(', '),
                                        style: context.textStyles.bodySmall?.withColor(
                                          cs.primary,
                                        ),
                                      ),
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
                const SizedBox(height: 12),
              ],
              
              // Care team schedule
              if (hasScheduleToday)
                ...todaySchedule.entries
                    .where((entry) => entry.value.isNotEmpty)
                    .map((entry) {
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
                        Row(
                          children: [
                            Icon(Icons.people, size: 16, color: cs.secondary),
                            const SizedBox(width: 8),
                            Text(
                              period,
                              style: context.textStyles.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...members.map((member) {
                          final timeSlot =
                              member.schedule[todayKey]?.firstWhere(
                            (slot) => slot.period == period.toLowerCase(),
                            orElse: () =>
                                TimeSlot(period: period.toLowerCase()),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.name,
                                        style: context.textStyles.bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                      if (timeSlot?.activities.isNotEmpty ??
                                          false)
                                        ...timeSlot!.activities
                                            .map((activity) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 2),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.check,
                                                          size: 12,
                                                          color: cs.primary),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          activity,
                                                          style: context
                                                              .textStyles
                                                              .bodySmall
                                                              ?.withColor(cs
                                                                  .onSurfaceVariant),
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
          ],
        ),
      ),
    );
  }

  Widget _buildTeamLegend(ColorScheme cs) {
    final memberColors = _getMemberColors();
    final connectedCount =
        _blueprint!.careTeam.where((m) => m.id.startsWith('family_')).length;

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
                Text('Care Team',
                    style: context.textStyles.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (connectedCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$connectedCount connected',
                      style: context.textStyles.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: _blueprint!.careTeam.map((member) {
                int totalSlots = 0;
                member.schedule
                    .forEach((date, slots) => totalSlots += slots.length);

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: memberColors[member.id]!.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: memberColors[member.id]!.withValues(alpha: 0.4)),
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
                        style: context.textStyles.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      // Show info icon for connected family members
                      if (member.id.startsWith('family_'))
                        Tooltip(
                          message: 'Connected via patient code',
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.link,
                              size: 16,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      // Show delete button for all members (including family)
                      InkWell(
                        onTap: () => _showDeleteMemberDialog(member),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: cs.error,
                          ),
                        ),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Weekly Schedule',
                  style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day - 7);
                    });
                  },
                  tooltip: 'Previous Week',
                ),
                IconButton(
                  icon: const Icon(Icons.today, size: 20),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime.now();
                      _selectedDay = _focusedDay;
                    });
                  },
                  tooltip: 'Today',
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day + 7);
                    });
                  },
                  tooltip: 'Next Week',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.week,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              availableCalendarFormats: const {CalendarFormat.week: 'Week'},
              headerVisible: false,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: (day) {
                final count = _getAvailabilityCount(day);
                return List.generate(count, (index) => 'event');
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: cs.secondary,
                  shape: BoxShape.circle,
                ),
                outsideDaysVisible: false,
                cellMargin: const EdgeInsets.all(4),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  return Positioned(
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.secondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${events.length}',
                        style: TextStyle(
                          color: cs.onSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekTimelineView(ColorScheme cs) {
    // Get the week's date range
    final weekStart = _focusedDay.subtract(Duration(days: _focusedDay.weekday % 7));
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    
    // Time slots (12 AM to 11 PM)
    final hours = List.generate(24, (i) => i);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.view_timeline, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Week of ${DateFormat('MMM d').format(weekDays.first)}',
                  style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 500,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time column
                      Column(
                        children: [
                          // Header spacer
                          SizedBox(
                            height: 60,
                            width: 60,
                          ),
                          // Hour labels
                          ...hours.map((hour) {
                            final hourLabel = hour == 0 ? '12AM' : 
                                            hour < 12 ? '${hour}AM' : 
                                            hour == 12 ? '12PM' : '${hour - 12}PM';
                            return Container(
                              height: 80,
                              width: 60,
                              alignment: Alignment.topRight,
                              padding: const EdgeInsets.only(right: 8, top: 4),
                              child: Text(
                                hourLabel,
                                style: context.textStyles.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      // Day columns
                      ...weekDays.map((day) {
                        final isToday = isSameDay(day, DateTime.now());
                        final isSelected = isSameDay(day, _selectedDay);
                        return Column(
                          children: [
                            // Day header
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDay = day;
                                  _focusedDay = day;
                                });
                              },
                              child: Container(
                                height: 60,
                                width: 100,
                                decoration: BoxDecoration(
                                  color: isSelected ? cs.primary : 
                                         isToday ? cs.primary.withValues(alpha: 0.3) : 
                                         cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      DateFormat('EEE').format(day),
                                      style: context.textStyles.labelSmall?.copyWith(
                                        color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('d').format(day),
                                      style: context.textStyles.titleLarge?.copyWith(
                                        color: isSelected ? cs.onPrimary : cs.onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Hour grid with events
                            ...hours.map((hour) {
                              return Container(
                                height: 80,
                                width: 100,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
                                    right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
                                  ),
                                ),
                                child: _buildTimeSlotEvents(day, hour, cs),
                              );
                            }),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotEvents(DateTime day, int hour, ColorScheme cs) {
    final dayKey = DateFormat('EEEE').format(day).toLowerCase();
    final events = <Widget>[];
    final memberColors = _getMemberColors();
    
    // Add medications
    if (_patient != null) {
      for (var med in _patient!.medications) {
        for (var timeStr in med.times) {
          final medHour = _parseHourFromTime(_convert24To12Hour(timeStr));
          if (medHour == hour) {
            Color? caregiverColor;
            String? caregiverName;
            if (med.assignedCaregiverId != null && med.assignedCaregiverId!.isNotEmpty) {
              caregiverColor = memberColors[med.assignedCaregiverId!];
              final member = _blueprint?.careTeam.firstWhere(
                (m) => m.id == med.assignedCaregiverId,
                orElse: () => CareTeamMember(id: '', name: '', relationship: ''),
              );
              if (member != null && member.id.isNotEmpty) {
                caregiverName = member.name;
              }
            }

            final pill = Container(
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.pink,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caregiverColor != null) ...[
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: caregiverColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      med.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );

            events.add(
              caregiverName != null && caregiverName.isNotEmpty
                  ? Tooltip(message: 'Assigned: $caregiverName', child: pill)
                  : pill,
            );
          }
        }
      }
    }
    
    // Add daily routines
    for (var routine in _blueprint!.dailyRoutines) {
      if (routine.daysPerformed.isEmpty || 
          routine.daysPerformed.any((d) => d.toLowerCase() == dayKey)) {
        for (var timeStr in routine.timesOfDay) {
          final routineHour = _parseHourFromTime(_convert24To12Hour(timeStr));
          if (routineHour == hour) {
            final baseColor = _getRoutineColor(routine.type);
            Color? caregiverColor;
            String? caregiverName;
            if (routine.assignedCaregiverId != null && routine.assignedCaregiverId!.isNotEmpty) {
              caregiverColor = memberColors[routine.assignedCaregiverId!];
              final member = _blueprint?.careTeam.firstWhere(
                (m) => m.id == routine.assignedCaregiverId,
                orElse: () => CareTeamMember(id: '', name: '', relationship: ''),
              );
              if (member != null && member.id.isNotEmpty) {
                caregiverName = member.name;
              }
            }

            final chip = Container(
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caregiverColor != null) ...[
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: caregiverColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      routine.type.replaceAll('_', ' '),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );

            events.add(
              caregiverName != null && caregiverName.isNotEmpty
                  ? Tooltip(message: 'Assigned: $caregiverName', child: chip)
                  : chip,
            );
          }
        }
      }
    }
    
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: events,
    );
  }

  int _parseHourFromTime(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.isEmpty) return -1;
      
      final timePart = parts[0];
      final hourMinute = timePart.split(':');
      if (hourMinute.isEmpty) return -1;
      
      var hour = int.tryParse(hourMinute[0]) ?? -1;
      if (hour == -1) return -1;
      
      final isPM = parts.length > 1 && parts[1].toUpperCase() == 'PM';
      
      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0;
      }
      
      return hour;
    } catch (e) {
      return -1;
    }
  }

  Color _getRoutineColor(String type) {
    switch (type.toLowerCase()) {
      case 'bowel':
        return Colors.purple;
      case 'bladder':
        return Colors.blue;
      case 'skin_check':
        return Colors.orange;
      case 'therapy':
        return Colors.green;
      case 'nutrition':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDaySchedule(ColorScheme cs) {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final memberColors = _getMemberColors();
    final dateFormatted = DateFormat('EEEE, MMMM d, y').format(_selectedDay!);

    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.calendar_today, color: cs.primary, size: 20),
        title: Text(
          dateFormatted,
          style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Tap team members to set their schedule and activities',
          style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                                      color: isScheduled ? memberColors[member.id]! : cs.outline.withValues(alpha: 0.3),
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

    for (var i = 0; i < _blueprint!.careTeam.length; i++) {
      memberColors[_blueprint!.careTeam[i].id] =
          colorPalette[i % colorPalette.length];
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
          style: context.textStyles.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
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
    // Filter out medication routines - they should only appear in Medications section
    final careRoutines = _blueprint!.dailyRoutines
        .where((r) => r.type.toLowerCase() != 'medication')
        .toList();

    final memberColors = _getMemberColors();

    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.access_time, color: cs.primary),
        title: Text(
          'Daily Care Timeline',
          style: context.textStyles.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${careRoutines.length} routine${careRoutines.length != 1 ? 's' : ''}',
          style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _addNewRoutine,
              icon: Icon(Icons.add_circle, color: cs.primary, size: 28),
              tooltip: 'Add routine',
              style: IconButton.styleFrom(
                backgroundColor: cs.primary.withValues(alpha: 0.1),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (careRoutines.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.schedule,
                      size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text(
                    'No care routines added yet.',
                    style: context.textStyles.bodyMedium
                        ?.withColor(cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addNewRoutine,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Care Routine'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                    ),
                  ),
                ],
              ),
            )
          else
            _buildCareRoutinesTimeline(cs, careRoutines),
        ],
      ),
    );
  }

  Widget _buildVisualTimeline(ColorScheme cs) {
    // Show ONLY medications in this timeline (for Medications section)
    final timelineItems = <TimelineItem>[];

    // Add medications
    if (_patient != null) {
      for (var med in _patient!.medications) {
        final assignedMember = med.assignedCaregiverId != null
            ? _blueprint?.careTeam.firstWhere(
                (m) => m.id == med.assignedCaregiverId,
                orElse: () => CareTeamMember(id: '', name: '', relationship: ''),
              )
            : null;
        
        for (var time in med.times) {
          timelineItems.add(TimelineItem(
            time: _convert24To12Hour(time),
            type: 'medication',
            title: med.name,
            subtitle: assignedMember?.name ?? med.dosage,
            notes: med.notes,
            icon: Icons.medication_liquid,
            color: const Color(0xFFE91E63), // Pink for medications
            medicationId: med.name,
            caregiverColor: assignedMember != null
                ? _getMemberColors()[assignedMember.id]
                : null,
          ));
        }
      }
    }

    // Sort by time
    timelineItems
        .sort((a, b) => _parseTime(a.time).compareTo(_parseTime(b.time)));

    if (timelineItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.schedule,
                  size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                'No scheduled items',
                style: context.textStyles.bodyMedium
                    ?.withColor(cs.onSurfaceVariant),
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
                                  timelineItems[index + 1]
                                      .color
                                      .withValues(alpha: 0.3),
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
                      border: Border.all(
                          color: item.color.withValues(alpha: 0.3), width: 1.5),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
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
                                  style:
                                      context.textStyles.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (item.daysPerformed != null &&
                            item.daysPerformed!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: item.daysPerformed!.map((day) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  day.substring(0, 3).toUpperCase(),
                                  style:
                                      context.textStyles.labelSmall?.copyWith(
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
                                Icon(Icons.info_outline,
                                    size: 14, color: cs.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.notes!,
                                    style: context.textStyles.bodySmall
                                        ?.withColor(cs.onSurfaceVariant),
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
                                label: const Text('Add Time',
                                    overflow: TextOverflow.ellipsis),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      item.color.withValues(alpha: 0.15),
                                  foregroundColor: item.color,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  minimumSize: const Size(0, 36),
                                  textStyle: context.textStyles.labelSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showEditTimesDialog(item),
                                icon: const Icon(Icons.edit_calendar, size: 16),
                                label: const Text('Manage',
                                    overflow: TextOverflow.ellipsis),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.surfaceContainerHighest,
                                  foregroundColor: cs.onSurface,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  minimumSize: const Size(0, 36),
                                  textStyle: context.textStyles.labelSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showAssignCaregiverDialog(item),
                            icon: const Icon(Icons.person_add, size: 16),
                            label: Text(
                              item.subtitle != null && item.caregiverColor != null
                                  ? 'Reassign Caregiver'
                                  : 'Assign Caregiver',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.secondaryContainer,
                              foregroundColor: cs.onSecondaryContainer,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              minimumSize: const Size(0, 36),
                              textStyle: context.textStyles.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
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

  Widget _buildCareRoutinesTimeline(ColorScheme cs, List<DailyRoutine> careRoutines) {
    // Show ONLY care routines (bowel, bladder, etc.) - NOT medications
    final timelineItems = <TimelineItem>[];

    // Add care routines
    for (var routine in careRoutines) {
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
          time: _convert24To12Hour(time),
          type: 'routine',
          title: routine.type
              .replaceAll('_', ' ')
              .split(' ')
              .map((w) => w[0].toUpperCase() + w.substring(1))
              .join(' '),
          subtitle: assignedMember?.name,
          notes: routine.suppliesNeeded.isNotEmpty
              ? '${routine.suppliesNeeded.length} supplies needed'
              : null,
          icon: routineIcon,
          color: routineColor,
          daysPerformed: routine.daysPerformed,
          caregiverColor: assignedMember != null
              ? _getMemberColors()[assignedMember.id]
              : null,
          routineType: routine.type,
        ));
      }
    }

    // Sort by time
    timelineItems
        .sort((a, b) => _parseTime(a.time).compareTo(_parseTime(b.time)));

    if (timelineItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.schedule,
                  size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                'No care routines scheduled',
                style: context.textStyles.bodyMedium
                    ?.withColor(cs.onSurfaceVariant),
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
                                  timelineItems[index + 1]
                                      .color
                                      .withValues(alpha: 0.3),
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
                      border: Border.all(
                          color: item.color.withValues(alpha: 0.3), width: 1.5),
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
                            IconButton(
                              onPressed: () => _deleteRoutine(item.routineType!),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: 'Delete routine',
                              color: Colors.red.shade300,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '🩺',
                                style: TextStyle(fontSize: 12),
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
                                  style:
                                      context.textStyles.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (item.daysPerformed != null &&
                            item.daysPerformed!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: item.daysPerformed!.map((day) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  day.substring(0, 3).toUpperCase(),
                                  style:
                                      context.textStyles.labelSmall?.copyWith(
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
                                Icon(Icons.info_outline,
                                    size: 14, color: cs.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.notes!,
                                    style: context.textStyles.bodySmall
                                        ?.withColor(cs.onSurfaceVariant),
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
                                label: const Text('Add Time',
                                    overflow: TextOverflow.ellipsis),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      item.color.withValues(alpha: 0.15),
                                  foregroundColor: item.color,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  minimumSize: const Size(0, 36),
                                  textStyle: context.textStyles.labelSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showEditTimesDialog(item),
                                icon: const Icon(Icons.edit_calendar, size: 16),
                                label: const Text('Manage',
                                    overflow: TextOverflow.ellipsis),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.surfaceContainerHighest,
                                  foregroundColor: cs.onSurface,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  minimumSize: const Size(0, 36),
                                  textStyle: context.textStyles.labelSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showAssignCaregiverDialog(item),
                            icon: const Icon(Icons.person_add, size: 16),
                            label: Text(
                              item.subtitle != null && item.caregiverColor != null
                                  ? 'Reassign Caregiver'
                                  : 'Assign Caregiver',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.secondaryContainer,
                              foregroundColor: cs.onSecondaryContainer,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              minimumSize: const Size(0, 36),
                              textStyle: context.textStyles.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
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
    String? currentAssignedId;

    if (item.type == 'medication' && _patient != null) {
      final med = _patient!.medications.firstWhere(
        (m) => m.name == item.medicationId,
        orElse: () => _patient!.medications.first,
      );
      currentTimes = List.from(med.times);
      currentAssignedId = med.assignedCaregiverId;
      debugPrint(
          '[CareTeamSchedule] Opening manage times for medication ${item.medicationId}, current times: $currentTimes');
    } else if (item.type == 'routine') {
      final routine = _blueprint!.dailyRoutines.firstWhere(
        (r) => r.type.toLowerCase() == item.routineType?.toLowerCase(),
        orElse: () => _blueprint!.dailyRoutines.first,
      );
      currentTimes = List.from(routine.timesOfDay);
      currentAssignedId = routine.assignedCaregiverId;
      debugPrint(
          '[CareTeamSchedule] Opening manage times for routine ${item.routineType}, current times: $currentTimes');
      debugPrint(
          '[CareTeamSchedule] Available routines: ${_blueprint!.dailyRoutines.map((r) => r.type).toList()}');
      debugPrint(
          '[CareTeamSchedule] Matched routine: ${routine.type} with ${routine.timesOfDay.length} times');
    }

    showDialog(
      context: context,
      builder: (dialogContext) => _EditTimesDialog(
        item: item,
        currentTimes: currentTimes,
        onUpdate: (updatedTimes) {
          debugPrint(
              '[CareTeamSchedule] Dialog closed with updated times: $updatedTimes');
          _updateAllTimes(item, updatedTimes);
        },
        careTeam: _blueprint?.careTeam ?? const [],
        memberColors: _getMemberColors(),
        selectedCaregiverId: currentAssignedId,
        onAssignCaregiver: (newId) => _assignCaregiver(item, newId),
      ),
    );
  }

  Future<void> _addAdditionalTime(TimelineItem item, TimeOfDay newTime) async {
    final timeString = _formatTimeOfDay(newTime);
    debugPrint(
        '[CareTeamSchedule] Adding time $timeString to ${item.title} (${item.type})');

    if (item.type == 'medication') {
      // Find the medication and add the new time
      if (_patient == null) return;

      final updatedMedications = _patient!.medications.map((med) {
        if (med.name == item.medicationId) {
          // Check if this time already exists
          if (med.times.contains(timeString)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Time $timeString already exists for this medication')),
              );
            }
            return med;
          }

          return med.copyWith(
            times: [...med.times, timeString]
              ..sort((a, b) => _parseTime(a).compareTo(_parseTime(b))),
          );
        }
        return med;
      }).toList();

      final updatedUser = _patient!.copyWith(medications: updatedMedications);

      await _userService.saveUser(updatedUser);
      debugPrint('[CareTeamSchedule] Saved medication to database');

      // Reload data to ensure UI is in sync with database
      await _load();
      debugPrint(
          '[CareTeamSchedule] Reloaded data after adding medication time');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Added $timeString to ${item.title}'),
            backgroundColor: item.color,
          ),
        );
      }
    } else if (item.type == 'routine') {
      debugPrint(
          '[CareTeamSchedule] Looking for routine with type: ${item.routineType}');
      debugPrint(
          '[CareTeamSchedule] Available routines: ${_blueprint!.dailyRoutines.map((r) => r.type).join(', ')}');

      // Find the routine by type (case-insensitive)
      final routineToAdd = _blueprint!.dailyRoutines.firstWhere(
        (r) => r.type.toLowerCase() == item.routineType?.toLowerCase(),
      );

      debugPrint(
          '[CareTeamSchedule] Found routine: ${routineToAdd.type}, current times: ${routineToAdd.timesOfDay}');

      // Check if this time already exists for this routine
      if (routineToAdd.timesOfDay.contains(timeString)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Time $timeString already exists for this routine')),
          );
        }
        return;
      }

      final updatedRoutines = _blueprint!.dailyRoutines.map((r) {
        // Case-insensitive comparison
        if (r.type.toLowerCase() == routineToAdd.type.toLowerCase()) {
          final newTimes = [...r.timesOfDay, timeString]
            ..sort((a, b) => _parseTime(a).compareTo(_parseTime(b)));
          debugPrint(
              '[CareTeamSchedule] Updating routine ${r.type} with new times: $newTimes');
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
    debugPrint(
        '[CareTeamSchedule] Updating times for ${item.title} (${item.type}): $newTimes');

    try {
      if (item.type == 'medication') {
        if (_patient == null) {
          debugPrint(
              '[CareTeamSchedule] ⚠️ ERROR: _patient is null, cannot update medication');
          return;
        }

        final updatedMedications = _patient!.medications.map((med) {
          if (med.name == item.medicationId) {
            return med.copyWith(
              times: newTimes
                ..sort((a, b) => _parseTime(a).compareTo(_parseTime(b))),
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
        debugPrint(
            '[CareTeamSchedule] ✓ Reloaded data after medication update');

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
          debugPrint(
              '[CareTeamSchedule] ⚠️ ERROR: _blueprint is null, cannot update routine');
          return;
        }

        debugPrint('[CareTeamSchedule] Routine type: ${item.routineType}');
        debugPrint(
            '[CareTeamSchedule] Current routines in blueprint: ${_blueprint!.dailyRoutines.map((r) => '${r.type} (${r.timesOfDay.length} times)').join(', ')}');

        final updatedRoutines = _blueprint!.dailyRoutines.map((r) {
          // Case-insensitive comparison
          if (r.type.toLowerCase() == item.routineType?.toLowerCase()) {
            debugPrint(
                '[CareTeamSchedule] ✓ MATCH: Updating routine ${r.type} from ${r.timesOfDay} to $newTimes');
            return DailyRoutine(
              type: r.type,
              timesOfDay: List.from(newTimes)
                ..sort((a, b) => _parseTime(a).compareTo(_parseTime(b))),
              assignedCaregiverId: r.assignedCaregiverId,
              suppliesNeeded: r.suppliesNeeded,
              daysPerformed: r.daysPerformed,
            );
          }
          debugPrint(
              '[CareTeamSchedule] ✗ No match: ${r.type} != ${item.routineType}');
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

        debugPrint(
            '[CareTeamSchedule] Calling _service.update with blueprint ${updatedBlueprint.id}...');
        final result = await _service.update(updatedBlueprint);
        debugPrint(
            '[CareTeamSchedule] ✓ Service.update returned, result blueprint has ${result.dailyRoutines.length} routines');

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

  void _showAssignCaregiverDialog(TimelineItem item) {
    if (_blueprint == null || _blueprint!.careTeam.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No care team members available. Add members first.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Caregiver to ${item.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select a care team member to assign to this ${item.type}:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ...?_blueprint?.careTeam.map((member) {
              final memberColor = _getMemberColors()[member.id];
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: memberColor?.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: memberColor ?? Colors.grey, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: memberColor,
                      ),
                    ),
                  ),
                ),
                title: Text(member.name),
                subtitle: Text(member.relationship),
                onTap: () {
                  Navigator.of(context).pop();
                  _assignCaregiver(item, member.id);
                },
              );
            }),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_off),
              title: const Text('Unassign'),
              subtitle: const Text('Remove caregiver assignment'),
              onTap: () {
                Navigator.of(context).pop();
                _assignCaregiver(item, null);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignCaregiver(TimelineItem item, String? caregiverId) async {
    try {
      if (item.type == 'medication') {
        // Update medication
        final updatedMedications = _patient!.medications.map((med) {
          if (med.name == item.medicationId) {
            return med.copyWith(assignedCaregiverId: caregiverId);
          }
          return med;
        }).toList();

        final updatedPatient = _patient!.copyWith(medications: updatedMedications);
        await _userService.saveUser(updatedPatient);

        setState(() {
          _patient = updatedPatient;
        });

        if (mounted) {
          final memberName = caregiverId != null
              ? _blueprint!.careTeam.firstWhere((m) => m.id == caregiverId).name
              : 'Unassigned';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Assigned ${item.title} to $memberName'),
              backgroundColor: item.color,
            ),
          );
        }
      } else if (item.type == 'routine') {
        // Update routine
        final updatedRoutines = _blueprint!.dailyRoutines.map((r) {
          if (r.type.toLowerCase() == item.routineType?.toLowerCase()) {
            return DailyRoutine(
              type: r.type,
              timesOfDay: r.timesOfDay,
              assignedCaregiverId: caregiverId,
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
          independenceAssessment: _blueprint!.independenceAssessment,
          homeReadiness: _blueprint!.homeReadiness,
          createdAt: _blueprint!.createdAt,
          updatedAt: DateTime.now(),
          careTeam: _blueprint!.careTeam,
          dailyRoutines: updatedRoutines,
          equipment: _blueprint!.equipment,
          supplies: _blueprint!.supplies,
          roadmap: _blueprint!.roadmap,
          updatedBy: _blueprint!.updatedBy,
        );

        await _service.update(updatedBlueprint);

        setState(() {
          _blueprint = updatedBlueprint;
        });

        if (mounted) {
          final memberName = caregiverId != null
              ? _blueprint!.careTeam.firstWhere((m) => m.id == caregiverId).name
              : 'Unassigned';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Assigned ${item.title} to $memberName'),
              backgroundColor: item.color,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[CareTeamSchedule] Error assigning caregiver: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign caregiver: $e'),
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

  /// Converts 24-hour time string (e.g., "08:00" or "20:00") to 12-hour format (e.g., "8:00 AM" or "8:00 PM")
  String _convert24To12Hour(String time24) {
    try {
      final parts = time24.split(':');
      if (parts.length != 2) return time24;
      
      final hour24 = int.parse(parts[0]);
      final minute = parts[1];
      
      if (hour24 < 0 || hour24 > 23) return time24;
      
      final period = hour24 < 12 ? 'AM' : 'PM';
      final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
      
      return '$hour12:$minute $period';
    } catch (e) {
      return time24; // Return original if parsing fails
    }
  }

  Future<void> _addNewRoutine() async {
    final newRoutine = await showDialog<DailyRoutine>(
      context: context,
      builder: (context) => _AddRoutineDialog(),
    );

    if (newRoutine == null || _blueprint == null) return;

    try {
      // Add routine to existing blueprint
      final updatedBlueprint = RecoveryBlueprint(
        id: _blueprint!.id,
        userId: _blueprint!.userId,
        patientProfile: _blueprint!.patientProfile,
        careTeam: _blueprint!.careTeam,
        independenceAssessment: _blueprint!.independenceAssessment,
        homeReadiness: _blueprint!.homeReadiness,
        dailyRoutines: [..._blueprint!.dailyRoutines, newRoutine],
        equipment: _blueprint!.equipment,
        supplies: _blueprint!.supplies,
        roadmap: _blueprint!.roadmap,
        createdAt: _blueprint!.createdAt,
        updatedAt: DateTime.now(),
      );
      
      await _service.update(updatedBlueprint);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Routine added successfully'), backgroundColor: Colors.green),
        );
        await _load();
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

  Future<void> _deleteRoutine(String routineType) async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine'),
        content: Text('Are you sure you want to delete the ${routineType.replaceAll('_', ' ')} routine?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || _blueprint == null) return;

    try {
      // Remove the routine
      final updatedRoutines = _blueprint!.dailyRoutines
          .where((r) => r.type.toLowerCase() != routineType.toLowerCase())
          .toList();

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Routine deleted successfully'), backgroundColor: Colors.green),
        );
        await _load();
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
  final List<CareTeamMember> careTeam;
  final Map<String, Color> memberColors;
  final String? selectedCaregiverId;
  final void Function(String?) onAssignCaregiver;

  const _EditTimesDialog({
    required this.item,
    required this.currentTimes,
    required this.onUpdate,
    required this.careTeam,
    required this.memberColors,
    required this.selectedCaregiverId,
    required this.onAssignCaregiver,
  });

  @override
  State<_EditTimesDialog> createState() => _EditTimesDialogState();
}

class _EditTimesDialogState extends State<_EditTimesDialog> {
  late List<String> _times;
  String? _caregiverId;

  @override
  void initState() {
    super.initState();
    _times = List.from(widget.currentTimes);
    _caregiverId = widget.selectedCaregiverId;
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.item.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.item.icon,
                        color: widget.item.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Times',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          widget.item.title,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
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
                              Icon(Icons.access_time,
                                  color: widget.item.color, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  time,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
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

                    const SizedBox(height: 24),
                    // Caregiver assignment section (always visible)
                    Row(
                      children: [
                        Icon(Icons.group, color: cs.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Assigned Caregiver',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        if (widget.careTeam.isEmpty)
                          Flexible(
                            child: Text(
                              'No team members yet',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Unassigned'),
                          selected: _caregiverId == null || _caregiverId!.isEmpty,
                          onSelected: (_) => setState(() => _caregiverId = null),
                        ),
                        ...widget.careTeam.map((m) {
                          final color = widget.memberColors[m.id] ?? cs.primary;
                          return ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text(m.name),
                              ],
                            ),
                            selected: _caregiverId == m.id,
                            onSelected: (_) => setState(() => _caregiverId = m.id),
                          );
                        }).toList(),
                      ],
                    ),
                    if (widget.careTeam.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Tip: Close this dialog and tap + in Care Team to add members.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
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
                    onPressed: _times.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            widget.onUpdate(_times);
                            widget.onAssignCaregiver(_caregiverId);
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

/// Dialog to add a new daily care routine
class _AddRoutineDialog extends StatefulWidget {
  @override
  State<_AddRoutineDialog> createState() => _AddRoutineDialogState();
}

class _AddRoutineDialogState extends State<_AddRoutineDialog> {
  String _selectedType = 'bowel';
  final _timeControllers = <TextEditingController>[];
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
  }
  
  void _removeTimeField(int index) {
    setState(() {
      _timeControllers[index].dispose();
      _timeControllers.removeAt(index);
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
                Icon(Icons.add_circle_outline, color: cs.primary, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add Care Routine',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
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
                    const Text('Routine Type', style: TextStyle(fontWeight: FontWeight.w600)),
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
                              Icon(type['icon'] as IconData, size: 16),
                              const SizedBox(width: 6),
                              Text(type['label'] as String),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedType = type['value'] as String);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    
                    // Times
                    Row(
                      children: [
                        const Text('Times', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _addTimeField());
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Time'),
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
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                ),
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
                    const Text('Days of Week', style: TextStyle(fontWeight: FontWeight.w600)),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saveRoutine,
                    style: FilledButton.styleFrom(
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
