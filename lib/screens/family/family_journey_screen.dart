import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wellspring/screens/family/family_connection_debug_screen.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/screens/recovery/recovery_blueprint_dashboard.dart';
import 'package:wellspring/services/recovery_blueprint_service.dart';
import 'package:wellspring/models/recovery_blueprint.dart';
import 'package:wellspring/supabase/supabase_config.dart';

/// Journey tab - shows patient milestones and goals clearly
class FamilyJourneyScreen extends StatefulWidget {
  const FamilyJourneyScreen({super.key});

  @override
  State<FamilyJourneyScreen> createState() => _FamilyJourneyScreenState();
}

class _FamilyJourneyScreenState extends State<FamilyJourneyScreen> {
  final _familyService = FamilyService();
  final _userService = UserService();
  final _blueprintService = RecoveryBlueprintService();
  bool _isLoading = true;
  Map<String, dynamic>? _patientJourney;
  RecoveryBlueprint? _patientBlueprint;
  String? _patientId;
  String? _patientName;
  String? _familyUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      debugPrint('[JourneyScreen] Starting to load journey data...');
      final user = await _userService.getCurrentUser();
      if (user == null) {
        debugPrint('[JourneyScreen] No current user found');
        setState(() => _isLoading = false);
        return;
      }

      // Load patient's journey data only
      final connection = await _familyService.getPrimaryConnection(user.id);
      Map<String, dynamic>? patientJourneyData;
      RecoveryBlueprint? patientBlueprint;
      String? patientId;
      String? patientName;

      if (connection != null) {
        patientJourneyData =
            await _familyService.getJourneyData(connection.patientId);
        patientBlueprint =
            await _blueprintService.getByUserId(connection.patientId);
        patientId = connection.patientId;
        patientName = connection.patientName;
      }

      setState(() {
        _patientJourney = patientJourneyData;
        _patientBlueprint = patientBlueprint;
        _patientId = patientId;
        _patientName = patientName;
        _familyUserId = user.id;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[JourneyScreen] Error loading journey data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                isDark
                    ? 'assets/images/ChatGPT_Image_Aug_3_2026_07_26_30_AM.png'
                    : 'assets/images/Misty_Mountain_Sunrise_Road.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0A3D4A),
                        Color(0xFF0D5563),
                        Color(0xFF0A3D4A),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Content
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF1ED3CF)),
            ),
          ],
        ),
      );
    }

    // Show patient's journey only
    final displayName = _patientName ?? "Patient";

    if (_patientJourney == null) {
      return Scaffold(
        body: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                isDark
                    ? 'assets/images/ChatGPT_Image_Aug_3_2026_07_26_30_AM.png'
                    : 'assets/images/Misty_Mountain_Sunrise_Road.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0A3D4A),
                        Color(0xFF0D5563),
                        Color(0xFF0A3D4A),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Journey',
                      style: context.textStyles.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Track recovery progress and milestones',
                      style: context.textStyles.bodyLarge?.withColor(
                        Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.flag_outlined,
                                size: 48,
                                color: Color(0xFF1ED3CF),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No Patient Connected',
                              style: context.textStyles.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Connect with a patient to view their\nrecovery journey and milestones.',
                              style: context.textStyles.bodyMedium?.withColor(
                                Colors.white.withValues(alpha: 0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
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
    }

    final milestones = (_patientJourney?['milestones'] as List?) ?? [];
    final completedCount =
        milestones.where((m) => m['completed'] == true).length;
    final totalCount = milestones.length;

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              isDark
                  ? 'assets/images/ChatGPT_Image_Aug_3_2026_07_26_30_AM.png'
                  : 'assets/images/Misty_Mountain_Sunrise_Road.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0A3D4A),
                      Color(0xFF0D5563),
                      Color(0xFF0A3D4A),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Journey',
                    style: context.textStyles.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track ${displayName}\'s recovery progress',
                    style: context.textStyles.bodyMedium?.withColor(
                      Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Recovery Milestones Section (Main Focus)
                  _RecoveryMilestonesCard(
                    milestones: milestones,
                    completedCount: completedCount,
                    totalCount: totalCount,
                    patientName: displayName,
                    onViewDetails: () {
                      context.push('/family/journey-detail');
                    },
                  ),
                  const SizedBox(height: 16),

                  // Recovery Blueprint Card
                  if (_patientBlueprint != null)
                    _RecoveryBlueprintCard(
                      blueprint: _patientBlueprint!,
                      onView: () {
                        // Navigate to family timeline view using go_router
                        context.push('/family/recovery-blueprint/timeline',
                            extra: _patientId);
                      },
                    )
                  else
                    _NoRecoveryBlueprintCard(
                      onCreate: () {
                        context.push('/family/recovery-blueprint/timeline',
                            extra: _patientId);
                      },
                    ),
                  const SizedBox(height: 24),

                  // Your Journey Section (with teal gradient button)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF1ED3CF).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1ED3CF)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.explore,
                                color: Color(0xFF1ED3CF),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Plan with A.R.I.E',
                              style: context.textStyles.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Uncertain on how to do something as a caregiver? Ask A.R.I.E',
                          style: context.textStyles.bodyMedium?.withColor(
                            Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFF1ED3CF),
                                  Color(0xFF22D3A0),
                                  Color(0xFF7BE38C),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1ED3CF)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: () {
                                  context.push('/family/my-journey');
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'My Plan',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsWidget extends StatelessWidget {
  const _StatsWidget({
    super.key,
    required this.completedCount,
    required this.totalCount,
    required this.activeGoalsCount,
  });

  final int completedCount;
  final int totalCount;
  final int activeGoalsCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remaining = totalCount - completedCount;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.surfaceContainerHighest.withValues(alpha: 0.6),
            cs.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.teal.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal, Colors.teal.shade600],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.show_chart,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text('Progress Overview',
                    style: context.textStyles.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _StatTile(
                        'Completed', completedCount.toString(), Colors.teal)),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatTile(
                        'Remaining', remaining.toString(), Colors.orange)),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatTile('Active Goals',
                        activeGoalsCount.toString(), Colors.blue)),
              ],
            ),
            const SizedBox(height: 20),
            Text('${(progress * 100).toInt()}% Complete',
                style: context.textStyles.labelMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: cs.surfaceContainerHighest,
              color: Colors.teal,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

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

class _NextMilestoneWidget extends StatelessWidget {
  const _NextMilestoneWidget({super.key, required this.milestone});
  final Map<String, dynamic> milestone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dueDate = milestone['dueDate'] != null
        ? DateTime.tryParse(milestone['dueDate'])
        : null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.teal.withValues(alpha: 0.2),
            Colors.teal.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.teal.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal, Colors.teal.shade600],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.flag, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text('Next Milestone',
                    style: context.textStyles.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(milestone['title'] ?? 'Milestone',
                style: context.textStyles.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            if (milestone['description'] != null) ...[
              const SizedBox(height: 8),
              Text(milestone['description'],
                  style: context.textStyles.bodyMedium
                      ?.withColor(cs.onSurfaceVariant)),
            ],
            if (dueDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: Colors.teal),
                  const SizedBox(width: 4),
                  Text('Due: ${dueDate.month}/${dueDate.day}/${dueDate.year}',
                      style: context.textStyles.labelMedium
                          ?.copyWith(color: Colors.teal.shade700)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecoveryMilestonesCard extends StatelessWidget {
  const _RecoveryMilestonesCard({
    super.key,
    required this.milestones,
    required this.completedCount,
    required this.totalCount,
    required this.patientName,
    this.onViewDetails,
  });

  final List milestones;
  final int completedCount;
  final int totalCount;
  final String patientName;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final remaining = totalCount - completedCount;

    // Get next upcoming milestone
    final nextMilestone = milestones.cast<Map<String, dynamic>?>().firstWhere(
          (m) => m?['completed'] != true,
          orElse: () => null,
        );

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1ED3CF).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1ED3CF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.flag,
                        color: Color(0xFF1ED3CF),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient Recovery Milestones',
                            style: context.textStyles.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$patientName\'s progress',
                            style: context.textStyles.bodyMedium?.withColor(
                              Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onViewDetails,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1ED3CF),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'view all',
                            style: context.textStyles.labelMedium?.copyWith(
                              color: const Color(0xFF1ED3CF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Progress Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ProgressStat(
                        icon: Icons.play_circle_outline,
                        label: 'In Progress',
                        value: completedCount.toString(),
                        color: const Color(0xFF4ADE80),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProgressStat(
                        icon: Icons.bar_chart,
                        label: 'Reached',
                        value: remaining.toString(),
                        color: const Color(0xFFFFB84D),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProgressStat(
                        icon: Icons.trending_up,
                        label: 'Upcoming',
                        value: totalCount.toString(),
                        color: const Color(0xFF60A5FA),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Progress Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Overall Progress',
                      style: context.textStyles.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: context.textStyles.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1ED3CF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF1ED3CF)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: context.textStyles.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: context.textStyles.labelSmall?.withColor(
              Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RecoveryBlueprintCard extends StatelessWidget {
  final RecoveryBlueprint blueprint;
  final VoidCallback onView;
  const _RecoveryBlueprintCard({required this.blueprint, required this.onView});

  @override
  Widget build(BuildContext context) {
    final careTeamCount = blueprint.careTeam.length;
    final equipmentCount = blueprint.equipment.length;
    final suppliesCount = blueprint.supplies.length;

    return InkWell(
      onTap: onView,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF1ED3CF).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1ED3CF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description,
                    color: Color(0xFF1ED3CF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Care Timeline',
                        style: context.textStyles.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Comprehensive recovery plan',
                        style: context.textStyles.bodySmall?.withColor(
                          Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF1ED3CF),
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _BlueprintInfoTile(
                    icon: Icons.people,
                    label: 'Care Team',
                    value: careTeamCount.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BlueprintInfoTile(
                    icon: Icons.inventory_2,
                    label: 'Tasks',
                    value: equipmentCount.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BlueprintInfoTile(
                    icon: Icons.schedule,
                    label: 'Sessions',
                    value: suppliesCount.toString(),
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

class _BlueprintInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _BlueprintInfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1ED3CF).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1ED3CF)),
          const SizedBox(height: 6),
          Text(
            value,
            style: context.textStyles.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.textStyles.labelSmall?.withColor(
              Colors.white.withValues(alpha: 0.7),
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

class _NoRecoveryBlueprintCard extends StatelessWidget {
  final VoidCallback onCreate;
  const _NoRecoveryBlueprintCard({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onCreate,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF1ED3CF).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1ED3CF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF1ED3CF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recovery Blueprint',
                        style: context.textStyles.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Not created yet',
                        style: context.textStyles.bodyMedium?.withColor(
                          Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'The patient hasn\'t created their Recovery Blueprint yet. A blueprint helps organize:',
              style: context.textStyles.bodyMedium?.withColor(
                Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 14),
            _BlueprintFeature(
                icon: Icons.people, text: 'Care team coordination'),
            _BlueprintFeature(
                icon: Icons.schedule, text: 'Daily routine scheduling'),
            _BlueprintFeature(
                icon: Icons.inventory_2, text: 'Equipment & supply tracking'),
          ],
        ),
      ),
    );
  }
}

class _BlueprintFeature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BlueprintFeature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1ED3CF)),
          const SizedBox(width: 10),
          Text(
            text,
            style: context.textStyles.bodyMedium?.withColor(
              Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
