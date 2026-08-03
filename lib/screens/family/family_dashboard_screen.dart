import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/models/patient_connection.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/models/goal.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/models/recovery_blueprint.dart';
import 'package:wellspring/models/user.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/services/goal_service.dart';
import 'package:wellspring/services/milestone_service.dart';
import 'package:wellspring/services/recovery_blueprint_service.dart';
import 'package:wellspring/services/education_service.dart';
import 'package:wellspring/models/education_resource.dart';
import 'package:wellspring/services/organization_service.dart';
import 'package:wellspring/services/hospital_service.dart';
import 'package:wellspring/services/vr_agency_service.dart';
import 'package:wellspring/models/organization.dart';
import 'package:wellspring/models/hospital.dart';
import 'package:wellspring/models/vr_agency.dart';
import 'package:wellspring/theme.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';

class FamilyDashboardScreen extends StatefulWidget {
  const FamilyDashboardScreen({super.key});

  @override
  State<FamilyDashboardScreen> createState() => _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends State<FamilyDashboardScreen> {
  final _familyService = FamilyService();
  final _userService = UserService();
  final _goalService = GoalService();
  final _milestoneService = MilestoneService();
  final _blueprintService = RecoveryBlueprintService();

  PatientConnection? _connection;
  List<TrackerEntry>? _recentEntries;
  Map<String, double>? _stats;
  int _healthScore = 0;
  String _healthStatus = 'Good';
  List<Map<String, dynamic>>? _chartData;
  List<Map<String, dynamic>>? _alerts;
  List<Goal>? _activeGoals;
  List<Milestone>? _milestones;
  Milestone? _nextMilestone;
  bool _allMilestonesCompleted = false;
  RecoveryBlueprint? _blueprint;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      debugPrint('[FamilyDashboard] Starting data load...');
      final user = await _userService.getCurrentUser();
      if (user == null) {
        debugPrint('[FamilyDashboard] No current user found');
        return;
      }
      debugPrint('[FamilyDashboard] Current user: ${user.id}');

      final connection = await _familyService.getPrimaryConnection(user.id);
      if (connection == null) {
        debugPrint('[FamilyDashboard] No patient connection found');
        setState(() => _loading = false);
        return;
      }
      debugPrint(
          '[FamilyDashboard] Connected to patient: ${connection.patientName} (${connection.patientId})');

      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      debugPrint('[FamilyDashboard] Fetching patient statistics...');
      final stats = await _familyService.getPatientStatistics(
          connection.patientId, thirtyDaysAgo, now);
      debugPrint('[FamilyDashboard] Stats: $stats');

      debugPrint('[FamilyDashboard] Fetching recent entries...');
      final recentEntries = await _familyService
          .getPatientRecentEntries(connection.patientId, limit: 30);
      debugPrint('[FamilyDashboard] Retrieved ${recentEntries.length} entries');

      final healthScore =
          _familyService.calculateHealthScore(stats, recentEntries);
      final healthStatus = _familyService.getHealthStatusLabel(healthScore);
      final chartData = _familyService.getChartData(recentEntries);
      final alerts = _familyService.detectInfectionSignals(recentEntries);

      // Load goals and milestones for the patient
      debugPrint('[FamilyDashboard] Fetching goals and milestones...');
      final activeGoals =
          await _goalService.getActiveGoals(connection.patientId);
      final milestones =
          await _milestoneService.list(userId: connection.patientId);
      debugPrint(
          '[FamilyDashboard] Found ${activeGoals.length} goals, ${milestones.length} milestones');

      // Load recovery blueprint for daily routines
      debugPrint('[FamilyDashboard] Fetching recovery blueprint...');
      final blueprint =
          await _blueprintService.getByUserId(connection.patientId);
      debugPrint('[FamilyDashboard] Blueprint loaded: ${blueprint != null}');

      // Find next incomplete milestone
      final incomplete = milestones.where((m) => !m.completed).toList();
      Milestone? nextMilestone;
      bool allCompleted = false;

      if (incomplete.isEmpty) {
        allCompleted = milestones.isNotEmpty;
      } else {
        incomplete.sort((a, b) {
          final ad = a.dueDate;
          final bd = b.dueDate;
          if (ad == null && bd == null) return a.order.compareTo(b.order);
          if (ad == null) return 1;
          if (bd == null) return -1;
          final cmp = ad.compareTo(bd);
          return cmp != 0 ? cmp : a.order.compareTo(b.order);
        });
        nextMilestone = incomplete.first;
      }

      setState(() {
        _connection = connection;
        _recentEntries = recentEntries;
        _stats = stats;
        _healthScore = healthScore;
        _healthStatus = healthStatus;
        _chartData = chartData;
        _alerts = alerts;
        _activeGoals = activeGoals;
        _milestones = milestones;
        _nextMilestone = nextMilestone;
        _allMilestonesCompleted = allCompleted;
        _blueprint = blueprint;
        _loading = false;
      });
      debugPrint('[FamilyDashboard] Data load complete');
    } catch (e) {
      debugPrint('[FamilyDashboard] Load data error: $e');
      setState(() => _loading = false);
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 120) return const Color(0xFF2E7D32);
    if (score >= 100) return const Color(0xFF43A047);
    if (score >= 80) return const Color(0xFFFB8C00);
    if (score >= 60) return const Color(0xFFE53935);
    return const Color(0xFFB71C1C);
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Menu', style: context.textStyles.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Navigate your portal', style: context.textStyles.bodyMedium?.withColor(isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B))),
                ],
              ),
            ),
            Divider(color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB), height: 1),
            _DrawerItem(icon: Icons.dashboard_rounded, label: 'Dashboard', onTap: () { Navigator.pop(context); context.go('/family/dashboard'); }),
            _DrawerItem(icon: Icons.favorite_rounded, label: 'Health Tracker', onTap: () { Navigator.pop(context); context.go('/family/health'); }),
            _DrawerItem(icon: Icons.emoji_events_rounded, label: 'Recovery Journey', onTap: () { Navigator.pop(context); context.go('/family/journey'); }),
            _DrawerItem(icon: Icons.notifications_rounded, label: 'Alerts', onTap: () { Navigator.pop(context); context.go('/family/alerts'); }),
            _DrawerItem(icon: Icons.folder_rounded, label: 'Resources', onTap: () { Navigator.pop(context); context.go('/family/resources'); }),
            _DrawerItem(icon: Icons.school_rounded, label: 'Education Hub', onTap: () { Navigator.pop(context); context.push('/family/education'); }),
            const Spacer(),
            Divider(color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB), height: 1),
            _DrawerItem(icon: Icons.settings_rounded, label: 'Settings', onTap: () { Navigator.pop(context); context.push('/settings'); }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }

    if (_connection == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
        appBar: AppBar(title: const Text('Family Portal')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.primary.withValues(alpha: 0.15),
                        cs.primary.withValues(alpha: 0.05)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Icon(Icons.link_off, size: 64, color: cs.primary),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('No Patient Connection',
                    style: context.textStyles.headlineMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                Text(
                    'Please complete the family onboarding to connect to a patient.',
                    style: context.textStyles.bodyLarge
                        ?.withColor(cs.onSurfaceVariant),
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: () => context.go('/family/onboarding'),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Connect to Patient'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/ChatGPT_Image_Aug_3_2026_07_26_30_AM.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AdaptlyHeader(patientName: _connection!.patientName),
                  const SizedBox(height: AppSpacing.xl),
                  _WelcomeCard(
                    patientName: _connection!.patientName,
                    nextMilestone: _nextMilestone,
                    allMilestonesCompleted: _allMilestonesCompleted,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _QuickActionsGrid(),
                  const SizedBox(height: AppSpacing.xl),
                  _RecoveryHeroCard(
                    recentEntries: _recentEntries ?? [],
                    healthScore: _healthScore,
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// Adaptly Premium Header
class _AdaptlyHeader extends StatelessWidget {
  final String patientName;

  const _AdaptlyHeader({required this.patientName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Builder(
            builder: (context) => Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white : Colors.black),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'ADAPTLY',
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                Text(
                  'RECOVER. TRACK. THRIVE.',
                  style: context.textStyles.labelSmall?.withColor(
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                patientName.isNotEmpty ? patientName[0].toUpperCase() : '?',
                style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Quick Actions Grid (Premium Cards)
class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        scrollDirection: Axis.horizontal,
        children: [
          _QuickActionCard(
            icon: Icons.school_rounded,
            title: 'Education',
            subtitle: 'Learn about your recovery.',
            color: const Color(0xFF2F80FF),
            onTap: () => context.push('/family/education'),
          ),
          const SizedBox(width: AppSpacing.md),
          _QuickActionCard(
            icon: Icons.notifications_rounded,
            title: 'Alerts',
            subtitle: 'Important reminders and updates.',
            color: const Color(0xFFF59E0B),
            onTap: () => context.go('/family/alerts'),
          ),
          const SizedBox(width: AppSpacing.md),
          _QuickActionCard(
            icon: Icons.chat_bubble_rounded,
            title: 'Messages',
            subtitle: 'Talk with your care team.',
            color: const Color(0xFF10B981),
            onTap: () => context.push('/messages'),
          ),
          const SizedBox(width: AppSpacing.md),
          _QuickActionCard(
            icon: Icons.folder_rounded,
            title: 'Resources',
            subtitle: 'Helpful tools and support.',
            color: const Color(0xFF8B5CF6),
            onTap: () => context.go('/family/resources'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.textStyles.bodySmall?.withColor(
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Welcome Card
class _WelcomeCard extends StatelessWidget {
  final String patientName;
  final Milestone? nextMilestone;
  final bool allMilestonesCompleted;

  const _WelcomeCard({
    required this.patientName,
    this.nextMilestone,
    this.allMilestonesCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            child: Stack(
              children: [
                // Content
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, ${patientName.split(' ').first}',
                      style: context.textStyles.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Here\'s ${patientName.split(' ').first}\'s recovery overview.',
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: allMilestonesCompleted 
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : const Color(0xFF2F80FF).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              allMilestonesCompleted 
                                  ? Icons.emoji_events_rounded 
                                  : Icons.flag_rounded,
                              color: allMilestonesCompleted 
                                  ? const Color(0xFF10B981) 
                                  : const Color(0xFF2F80FF),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  allMilestonesCompleted 
                                      ? 'Recovery Milestone' 
                                      : 'Next Recovery Milestone',
                                  style: context.textStyles.labelSmall?.copyWith(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : Colors.black.withValues(alpha: 0.6),
                                  ),
                                ),
                                Text(
                                  allMilestonesCompleted 
                                      ? 'All Complete!' 
                                      : (nextMilestone?.title ?? 'No milestones yet'),
                                  style: context.textStyles.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                if (nextMilestone != null && nextMilestone!.dueDate != null)
                                  Text(
                                    'Due ${DateFormat('MMM d, y').format(nextMilestone!.dueDate!)}',
                                    style: context.textStyles.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : Colors.black.withValues(alpha: 0.6),
                                    ),
                                  )
                                else if (allMilestonesCompleted)
                                  Text(
                                    'Great job on your recovery!',
                                    style: context.textStyles.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : Colors.black.withValues(alpha: 0.6),
                                    ),
                                  )
                                else
                                  Text(
                                    'Set milestones in the Journey tab',
                                    style: context.textStyles.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : Colors.black.withValues(alpha: 0.6),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.black.withValues(alpha: 0.6),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showLearnMoreSheet(context, patientName, nextMilestone),
                        icon: Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        label: Text(
                          'Learn More',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.2),
                          ),
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Swipeable Activity Card with Vitals & Schedule
class _RecoveryHeroCard extends StatefulWidget {
  final List<TrackerEntry> recentEntries;
  final int healthScore;

  const _RecoveryHeroCard({
    required this.recentEntries,
    required this.healthScore,
  });

  @override
  State<_RecoveryHeroCard> createState() => _RecoveryHeroCardState();
}

class _RecoveryHeroCardState extends State<_RecoveryHeroCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getLatestVitals() {
    if (widget.recentEntries.isEmpty) {
      return {
        'heartRate': 72,
        'systolic': 120,
        'diastolic': 80,
        'sleepQuality': 7,
        'steps': 2450,
      };
    }
    
    int? heartRate;
    int? systolic;
    int? diastolic;
    int? sleepQuality;
    int? steps;
    
    for (final entry in widget.recentEntries) {
      heartRate ??= entry.heartRate;
      systolic ??= entry.systolicBP;
      diastolic ??= entry.diastolicBP;
      sleepQuality ??= entry.sleepQuality;
      steps ??= entry.steps;
    }
    
    return {
      'heartRate': heartRate ?? 72,
      'systolic': systolic ?? 120,
      'diastolic': diastolic ?? 80,
      'sleepQuality': sleepQuality ?? 7,
      'steps': steps ?? 2450,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          SizedBox(
            height: 520,
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _VitalsPage(vitals: _getLatestVitals(), recentEntries: widget.recentEntries),
                _SchedulePage(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PageIndicator(isActive: _currentPage == 0),
              const SizedBox(width: 8),
              _PageIndicator(isActive: _currentPage == 1),
            ],
          ),
        ],
      ),
    );
  }
}

// Page Indicator
class _PageIndicator extends StatelessWidget {
  final bool isActive;

  const _PageIndicator({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xff2f91ff) : const Color(0xff28313b),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// Vitals Page
class _VitalsPage extends StatelessWidget {
  final Map<String, dynamic> vitals;
  final List<TrackerEntry> recentEntries;

  const _VitalsPage({required this.vitals, required this.recentEntries});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff1d1d20), Color(0xff101012)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 24,
            offset: const Offset(8, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Vitals',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _VitalCard(
                  icon: Icons.favorite_rounded,
                  label: 'Heart Rate',
                  value: '${vitals['heartRate']}',
                  unit: 'bpm',
                  color: const Color(0xffef4444),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _VitalCard(
                  icon: Icons.nightlight_rounded,
                  label: 'Sleep',
                  value: '${vitals['sleepQuality']}',
                  unit: '/10',
                  color: const Color(0xff8b5cf6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _VitalCard(
                  icon: Icons.monitor_heart_rounded,
                  label: 'Blood Pressure',
                  value: '${vitals['systolic']}/${vitals['diastolic']}',
                  unit: 'mmHg',
                  color: const Color(0xff10b981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _VitalCard(
                  icon: Icons.directions_walk_rounded,
                  label: 'Steps',
                  value: '${vitals['steps']}',
                  unit: '',
                  color: const Color(0xff2f91ff),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Activity Frequency',
            style: TextStyle(
              color: Color(0xffd4d4d7),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _ActivityFrequencyBars(recentEntries: recentEntries),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mon', style: TextStyle(color: Color(0xffd2d2d5), fontSize: 14)),
              Text('Tue', style: TextStyle(color: Color(0xffd2d2d5), fontSize: 14)),
              Text('Wed', style: TextStyle(color: Color(0xffd2d2d5), fontSize: 14)),
              Text('Thu', style: TextStyle(color: Color(0xffd2d2d5), fontSize: 14)),
              Text('Fri', style: TextStyle(color: Color(0xffd2d2d5), fontSize: 14)),
              Text('Sat', style: TextStyle(color: Color(0xffd2d2d5), fontSize: 14)),
              Text('Sun', style: TextStyle(color: Color(0xffd2d2d5), fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

// Vital Card
class _VitalCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _VitalCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff1a1a1d),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xffa8a8ad),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      color: Color(0xffa8a8ad),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              ]
            ],
          ),
        ],
      ),
    );
  }
}

// Activity Frequency Bars (shows daily log activity)
class _ActivityFrequencyBars extends StatelessWidget {
  final List<TrackerEntry> recentEntries;

  const _ActivityFrequencyBars({required this.recentEntries});

  List<int> _getWeeklyActivity() {
    final now = DateTime.now();
    final weekCounts = List<int>.filled(7, 0);
    
    for (final entry in recentEntries) {
      final daysDiff = now.difference(entry.createdAt).inDays;
      if (daysDiff >= 0 && daysDiff < 7) {
        weekCounts[6 - daysDiff]++;
      }
    }
    
    return weekCounts;
  }

  @override
  Widget build(BuildContext context) {
    final weeklyActivity = _getWeeklyActivity();
    final maxCount = weeklyActivity.reduce(math.max).clamp(1, 100);

    return SizedBox(
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: weeklyActivity.map((count) {
          final heightPercent = (count / maxCount).clamp(0.1, 1.0);
          final height = 60 * heightPercent;
          final active = count > 0;

          return Container(
            width: 32,
            height: height,
            decoration: BoxDecoration(
              color: active ? const Color(0xff2f91ff) : const Color(0xff17334d),
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Schedule Page
class _SchedulePage extends StatefulWidget {
  const _SchedulePage();

  @override
  State<_SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<_SchedulePage> {
  final _familyService = FamilyService();
  final _userService = UserService();
  final _blueprintService = RecoveryBlueprintService();
  
  RecoveryBlueprint? _blueprint;
  User? _patient;
  PatientConnection? _connection;
  bool _loading = true;
  DateTime _selectedWeekStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedWeekStart = _getWeekStart(DateTime.now());
    _loadScheduleData();
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  Future<void> _loadScheduleData() async {
    try {
      final user = await _userService.getCurrentUser();
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      final connection = await _familyService.getPrimaryConnection(user.id);
      if (connection == null) {
        setState(() => _loading = false);
        return;
      }

      final blueprint = await _blueprintService.getByUserId(connection.patientId);
      final patient = await _userService.getUserById(connection.patientId);

      if (mounted) {
        setState(() {
          _connection = connection;
          _blueprint = blueprint;
          _patient = patient;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[SchedulePage] Error loading data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff1d1d20), Color(0xff101012)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 24,
            offset: const Offset(8, 12),
          ),
        ],
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xff2f91ff)))
          : _blueprint == null
              ? const Center(
                  child: Text(
                    'No schedule available',
                    style: TextStyle(color: Color(0xffa8a8ad), fontSize: 16),
                  ),
                )
              : Column(
                  children: [
                    _buildScheduleHeader(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildScheduleContent(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildScheduleHeader() {
    final monthYear = DateFormat('MMMM yyyy').format(_selectedWeekStart);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D7C8C), Color(0xFF0A5A68)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7));
              });
            },
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  monthYear,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Week of ${DateFormat('MMM d').format(_selectedWeekStart)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
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
            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleContent() {
    final weekDays = List.generate(3, (i) => _selectedWeekStart.add(Duration(days: i)));
    final today = DateTime.now();

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 50),
              ...weekDays.map((day) {
                final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xff2f91ff).withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('EEE').format(day),
                          style: TextStyle(
                            color: isToday ? const Color(0xff2f91ff) : const Color(0xffa8a8ad),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          DateFormat('d').format(day),
                          style: TextStyle(
                            color: isToday ? const Color(0xff2f91ff) : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          ..._buildScheduleRows(),
        ],
      ),
    );
  }

  List<Widget> _buildScheduleRows() {
    final rows = <Widget>[];
    final times = ['12AM', '1AM', '2AM', '3AM', '4AM', '5AM', '6AM', '7AM'];
    
    for (var i = 0; i < times.length; i++) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 50,
              child: Text(
                times[i],
                style: const TextStyle(
                  color: Color(0xffa8a8ad),
                  fontSize: 11,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 60,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff1a1a1d).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: i == 0 || i == 5
                    ? Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: i == 0 ? const Color(0xffef4444) : const Color(0xff8b5cf6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              i == 0 ? 'Advil' : 'Bowel',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (i == 5)
                              const Text(
                                'Joseph',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
            Expanded(
              child: Container(
                height: 60,
                margin: const EdgeInsets.only(left: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff1a1a1d).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: i == 0 || i == 5
                    ? Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: i == 0 ? const Color(0xffef4444) : const Color(0xff8b5cf6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              i == 0 ? 'Advil' : 'Bowel',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (i == 5)
                              const Text(
                                'Joseph',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
            Expanded(
              child: Container(
                height: 60,
                margin: const EdgeInsets.only(left: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff1a1a1d).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: i == 0 || i == 5
                    ? Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: i == 0 ? const Color(0xffef4444) : const Color(0xff8b5cf6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              i == 0 ? 'Advil' : 'Bowel',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (i == 5)
                              const Text(
                                'Joseph',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      );
    }
    
    return rows;
  }
}

// AI Insights Card
class _AIInsightsCard extends StatelessWidget {
  final int healthScore;

  const _AIInsightsCard({required this.healthScore});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB),
            width: 1,
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
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6), size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'AI Insights',
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              healthScore >= 100
                  ? 'Based on your progress this week, your recovery is improving. Continue focusing on hydration and mobility exercises.'
                  : 'Your recovery metrics suggest focusing on rest and pain management. Consider discussing medication adjustments with your care team.',
              style: context.textStyles.bodyMedium?.withColor(
                isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Upcoming Section
class _UpcomingSection extends StatelessWidget {
  final RecoveryBlueprint? blueprint;
  final Milestone? nextMilestone;

  const _UpcomingSection({
    required this.blueprint,
    required this.nextMilestone,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming',
            style: context.textStyles.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _UpcomingItem(
                  icon: Icons.medical_services_rounded,
                  title: 'Therapy Appointment',
                  subtitle: 'Tomorrow • 10:30 AM',
                  color: const Color(0xFF2F80FF),
                ),
                Divider(color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB), height: 1),
                _UpcomingItem(
                  icon: Icons.medication_rounded,
                  title: 'Medication Reminder',
                  subtitle: '8:00 PM Tonight',
                  color: const Color(0xFFF59E0B),
                ),
                if (nextMilestone != null) ...[
                  Divider(color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB), height: 1),
                  _UpcomingItem(
                    icon: Icons.emoji_events_rounded,
                    title: nextMilestone!.title,
                    subtitle: nextMilestone!.dueDate != null
                        ? 'Due ${DateFormat('MMM d').format(nextMilestone!.dueDate!)}'
                        : 'In Progress',
                    color: const Color(0xFF10B981),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _UpcomingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: context.textStyles.bodySmall?.withColor(
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }
}

// Drawer Item
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2F80FF)),
      title: Text(
        label,
        style: context.textStyles.titleSmall?.withColor(
          isDark ? Colors.white : Colors.black,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 4),
    );
  }
}

// Animated Section Widget
class _AnimatedSection extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _AnimatedSection({required this.child, this.delayMs = 0});

  @override
  State<_AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends State<_AnimatedSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: widget.child,
        ),
      );
}

// Learn More Sheet Function
void _showLearnMoreSheet(BuildContext context, String patientName, Milestone? nextMilestone) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _LearnMoreSheet(patientName: patientName, nextMilestone: nextMilestone),
  );
}

// Comprehensive Learn More Sheet
class _LearnMoreSheet extends StatefulWidget {
  final String patientName;
  final Milestone? nextMilestone;

  const _LearnMoreSheet({required this.patientName, this.nextMilestone});

  @override
  State<_LearnMoreSheet> createState() => _LearnMoreSheetState();
}

class _LearnMoreSheetState extends State<_LearnMoreSheet> {
  final _educationService = EducationService.instance;
  final _familyService = FamilyService();
  final _userService = UserService();
  final _organizationService = OrganizationService();
  final _hospitalService = HospitalService();
  final _vrAgencyService = VRAgencyService();
  
  List<EducationResource> _educationResources = [];
  List<Organization> _organizations = [];
  List<Hospital> _hospitals = [];
  List<VRAgency> _vrAgencies = [];
  bool _showVRAgencies = false;
  PatientConnection? _connection;
  User? _patient;
  Map<String, double>? _stats;
  List<TrackerEntry>? _recentEntries;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      // Load current user and patient connection
      final user = await _userService.getCurrentUser();
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      final connection = await _familyService.getPrimaryConnection(user.id);
      if (connection == null) {
        setState(() => _loading = false);
        return;
      }

      final patient = await _userService.getUserById(connection.patientId);
      
      // Load patient-specific data
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final stats = await _familyService.getPatientStatistics(
          connection.patientId, thirtyDaysAgo, now);
      final recentEntries = await _familyService
          .getPatientRecentEntries(connection.patientId, limit: 30);
      
      // Load ONLY NIH and MedlinePlus education resources
      final educationList = _educationService.all().where((resource) {
        // Only show resources from NIH or MedlinePlus
        final source = resource.sourceName.toLowerCase();
        return source.contains('nih') || 
               source.contains('medlineplus') || 
               source.contains('medline plus') ||
               source.contains('nlm');
      }).toList();

      // Load local resources (organizations and hospitals)
      final organizations = await _organizationService.getAllOrganizations();
      final hospitals = await _hospitalService.getHospitalsByMetro('stl');

      // Load VR agencies if applicable based on patient conditions
      List<VRAgency> vrAgencies = [];
      bool showVR = false;
      
      if (patient != null) {
        // Check if VR agencies are applicable
        showVR = _vrAgencyService.areVRAgenciesApplicable(
          conditionIds: patient.conditions,
          recoveryPhase: patient.preferences['recoveryPhase'] as String?,
        );
        
        if (showVR) {
          // Try to get agencies for patient's state
          final patientState = patient.preferences['state'] as String?;
          if (patientState != null && patientState.isNotEmpty) {
            vrAgencies = await _vrAgencyService.getRelevantAgencies(
              stateAbbr: patientState.length == 2 ? patientState : null,
              stateName: patientState.length > 2 ? patientState : null,
            );
          } else {
            // No state info, show all agencies
            vrAgencies = await _vrAgencyService.getAllAgencies();
          }
        }
      }

      setState(() {
        _connection = connection;
        _patient = patient;
        _stats = stats;
        _recentEntries = recentEntries;
        _educationResources = educationList;
        _organizations = organizations;
        _hospitals = hospitals;
        _vrAgencies = vrAgencies;
        _showVRAgencies = showVR;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[LearnMoreSheet] Error loading data: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recovery Resources',
                          style: context.textStyles.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Personalized resources for ${widget.patientName.split(' ').first}\'s care journey',
                          style: context.textStyles.bodyMedium?.withColor(
                            isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      children: [
                        // Patient Summary Stats
                        _PatientSummaryCard(
                          patient: _patient,
                          stats: _stats,
                          recentEntries: _recentEntries ?? [],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        // Current Milestone Section (if available)
                        if (widget.nextMilestone != null) ...[
                          _SectionHeader(
                            icon: Icons.flag_rounded,
                            title: 'Current Milestone',
                            color: const Color(0xFF2F80FF),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _MilestoneCard(milestone: widget.nextMilestone!),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                        // Local Resources Section
                        _SectionHeader(
                          icon: Icons.location_city_rounded,
                          title: 'Local Resources',
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_organizations.isEmpty && _hospitals.isEmpty && !_showVRAgencies)
                          _EmptyState(message: 'No local resources available')
                        else ...[
                          if (_organizations.isNotEmpty) ...[
                            ..._organizations.take(10).map((org) => _LocalResourceCard(
                              icon: Icons.business_rounded,
                              title: org.name,
                              subtitle: org.slug.isNotEmpty ? org.slug : 'Community Organization',
                              type: 'Organization',
                              color: const Color(0xFF10B981),
                            )),
                          ],
                          if (_hospitals.isNotEmpty) ...[
                            ..._hospitals.take(10).map((hospital) => _LocalResourceCard(
                              icon: Icons.local_hospital_rounded,
                              title: hospital.name,
                              subtitle: hospital.city ?? 'Healthcare Facility',
                              type: 'Hospital',
                              color: const Color(0xFF2F80FF),
                            )),
                          ],
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        // Vocational Rehabilitation Agencies Section (if applicable)
                        if (_showVRAgencies && _vrAgencies.isNotEmpty) ...[
                          _SectionHeader(
                            icon: Icons.work_rounded,
                            title: 'Vocational Rehabilitation',
                            color: const Color(0xFFEF4444),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ..._vrAgencies.map((agency) => _VRAgencyCard(agency: agency)),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                        // NIH & MedlinePlus Education Resources ONLY
                        _SectionHeader(
                          icon: Icons.school_rounded,
                          title: 'NIH & MedlinePlus Resources',
                          color: const Color(0xFF8B5CF6),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_educationResources.isEmpty)
                          _EmptyState(message: 'No NIH/MedlinePlus resources available')
                        else
                          ..._educationResources.map((resource) => _EducationResourceCard(resource: resource)),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Section Header Widget
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// Milestone Card
class _MilestoneCard extends StatelessWidget {
  final Milestone milestone;

  const _MilestoneCard({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            milestone.title,
            style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (milestone.description?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              milestone.description ?? '',
              style: context.textStyles.bodyMedium?.withColor(
                isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
              ),
            ),
          ],
          if (milestone.dueDate != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: const Color(0xFF2F80FF)),
                const SizedBox(width: 4),
                Text(
                  'Due ${DateFormat('MMM d, y').format(milestone.dueDate!)}',
                  style: context.textStyles.bodySmall?.withColor(const Color(0xFF2F80FF)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Local Resource Card (Organizations & Hospitals)
class _LocalResourceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String type;
  final Color color;

  const _LocalResourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: context.textStyles.bodySmall?.withColor(
                      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 2),
                Text(
                  type,
                  style: context.textStyles.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }
}

// Education Resource Card
class _EducationResourceCard extends StatelessWidget {
  final EducationResource resource;

  const _EducationResourceCard({required this.resource});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.menu_book_rounded, color: const Color(0xFF8B5CF6), size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.title,
                  style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (resource.category.isNotEmpty)
                  Text(
                    resource.category,
                    style: context.textStyles.bodySmall?.withColor(
                      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }
}

// Patient Summary Card
class _PatientSummaryCard extends StatelessWidget {
  final User? patient;
  final Map<String, double>? stats;
  final List<TrackerEntry> recentEntries;

  const _PatientSummaryCard({
    required this.patient,
    required this.stats,
    required this.recentEntries,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (patient == null || stats == null) {
      return const SizedBox.shrink();
    }

    final avgPain = stats!['avgPain'] ?? 0.0;
    final avgMood = stats!['avgMood'] ?? 0.0;
    final totalEntries = recentEntries.length;
    final entriesThisWeek = recentEntries.where((e) {
      final daysDiff = DateTime.now().difference(e.createdAt).inDays;
      return daysDiff <= 7;
    }).length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2F80FF).withValues(alpha: 0.15),
            const Color(0xFF8B5CF6).withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB),
          width: 1,
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
                  color: const Color(0xFF2F80FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics_rounded, color: Color(0xFF2F80FF), size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '30-Day Recovery Summary',
                  style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Total Log Entries',
                  value: '$totalEntries',
                  icon: Icons.edit_note_rounded,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _SummaryMetric(
                  label: 'This Week',
                  value: '$entriesThisWeek',
                  icon: Icons.calendar_today_rounded,
                  color: const Color(0xFF2F80FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Avg Pain Level',
                  value: avgPain.toStringAsFixed(1),
                  icon: Icons.healing_rounded,
                  color: avgPain <= 3 ? const Color(0xFF10B981) : avgPain <= 6 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _SummaryMetric(
                  label: 'Avg Mood',
                  value: avgMood.toStringAsFixed(1),
                  icon: Icons.sentiment_satisfied_rounded,
                  color: avgMood >= 7 ? const Color(0xFF10B981) : avgMood >= 4 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: context.textStyles.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: context.textStyles.bodySmall?.withColor(
              isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

// Empty State Widget
class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          message,
          style: context.textStyles.bodyMedium?.withColor(
            isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

// VR Agency Card Widget
class _VRAgencyCard extends StatelessWidget {
  final VRAgency agency;

  const _VRAgencyCard({required this.agency});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB),
          width: 1,
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
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.work_rounded, color: Color(0xFFEF4444), size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agency.agencyName,
                      style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${agency.jurisdiction} • ${agency.agencyTypeLabel}',
                      style: context.textStyles.bodySmall?.withColor(
                        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (agency.primaryPhone != null || agency.website != null) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (agency.primaryPhone != null)
                  _ContactButton(
                    icon: Icons.phone_rounded,
                    label: agency.primaryPhone!,
                    onTap: () => _launchUrl('tel:${agency.primaryPhone}'),
                  ),
                if (agency.website != null)
                  _ContactButton(
                    icon: Icons.language_rounded,
                    label: 'Website',
                    onTap: () => _launchUrl(agency.website!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }
}

// Contact Button Widget for VR Agency Card
class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A3441) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFEF4444)),
            const SizedBox(width: 6),
            Text(
              label,
              style: context.textStyles.labelSmall?.copyWith(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
