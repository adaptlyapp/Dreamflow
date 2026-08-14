import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/journey_hierarchy.dart';
import 'package:wellspring/models/recovery_domain.dart';
import 'package:wellspring/models/journey_template.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/journey_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/skeletons.dart';

/// Modern Journey Screen showcasing ARIE-generated personalized recovery pathways
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  final _journeyService = JourneyService();
  
  List<Journey>? _journeys;
  List<RecoveryDomain>? _domains;
  Map<String, List<Phase>> _phasesByJourney = {};
  Map<String, List<JourneyMilestone>> _milestonesByPhase = {};
  bool _isLoading = true;
  bool _hasGeneratedJourney = false;

  @override
  void initState() {
    super.initState();
    _loadJourneyData();
  }

  Future<void> _loadJourneyData() async {
    if (!mounted) return;
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.currentUser?.id;
    
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Don't auto-load journeys - only show after user creates one via builder
      if (mounted) {
        setState(() {
          _journeys = [];
          _domains = [];
          _phasesByJourney = {};
          _milestonesByPhase = {};
          _hasGeneratedJourney = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading journey data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateJourney() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.currentUser?.id;
    
    if (userId == null) return;

    // Show generating dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _GeneratingJourneyDialog(),
    );

    try {
      // Create a sample patient profile (in real app, this would come from questionnaire)
      final profile = PatientProfileInput(
        primaryDiagnosis: 'Spinal Cord Injury',
        recoveryPhase: 'postDischarge',
        functionalClassification: 'C5 ASIA B',
        cognitiveIndependence: {
          'decisions': 'independent',
          'communication': 'independent',
        },
        physicalIndependence: {
          'transfer': 'needsAssistance',
          'dress': 'needsAssistance',
          'mobility': 'needsAssistance',
        },
        therapyGoals: ['Increase upper body strength', 'Independent transfers'],
        patientPriorities: ['Get back home', 'Be independent', 'Return to work'],
      );

      await _journeyService.generatePersonalizedJourney(
        userId: userId,
        conditionId: 'sci-default',
        profile: profile,
      );

      if (mounted) {
        context.pop(); // Close dialog
        await _loadJourneyData(); // Reload data
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Your personalized recovery journey has been generated!'),
            backgroundColor: Color(0xFF1ED3CF),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        context.pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating journey: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F2E),
      body: Stack(
        children: [
          // Mountain background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/b0380405-152d-4717-8856-bf48d924b809.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0A1F2E),
                      Color(0xFF0D2A3D),
                      Color(0xFF0A1F2E),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: _isLoading
                ? const CenteredLoadingSkeleton()
                : !_hasGeneratedJourney
                    ? _buildEmptyState()
                    : _buildJourneyContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1ED3CF).withValues(alpha: 0.3),
                    const Color(0xFF1E88FF).withValues(alpha: 0.3),
                  ],
                ),
              ),
              child: const Icon(
                Icons.explore,
                size: 60,
                color: Color(0xFF1ED3CF),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Your Recovery Journey Awaits',
              style: context.textStyles.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'ARIE will create a personalized recovery pathway based on your condition, current abilities, and goals.',
              style: context.textStyles.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _FeaturePill(
              icon: Icons.psychology,
              label: 'AI-Powered Personalization',
            ),
            const SizedBox(height: 12),
            _FeaturePill(
              icon: Icons.medical_services,
              label: 'Evidence-Based Milestones',
            ),
            const SizedBox(height: 12),
            _FeaturePill(
              icon: Icons.school,
              label: 'Educational Resources',
            ),
            const SizedBox(height: 12),
            _FeaturePill(
              icon: Icons.track_changes,
              label: 'Progress Tracking',
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88FF), Color(0xFF1ED3CF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1ED3CF).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: _generateJourney,
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Generate My Journey',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _buildJourneyContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Recovery Journey',
                          style: context.textStyles.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Personalized by ARIE',
                          style: context.textStyles.bodySmall?.copyWith(
                            color: const Color(0xFF1ED3CF),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildProgressSummary(),
              ],
            ),
          ),
        ),
        
        // Ask ARIE Card
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildAskArieCard(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        
        // Recovery Domains Grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recovery Domains',
                  style: context.textStyles.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDomainsGrid(),
              ],
            ),
          ),
        ),

        // Journeys List
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final journey = _journeys![index];
                final phases = _phasesByJourney[journey.id] ?? [];
                return _JourneyCard(
                  journey: journey,
                  phases: phases,
                  milestonesByPhase: _milestonesByPhase,
                );
              },
              childCount: _journeys?.length ?? 0,
            ),
          ),
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildProgressSummary() {
    int totalMilestones = 0;
    int completedMilestones = 0;

    for (final milestones in _milestonesByPhase.values) {
      totalMilestones += milestones.length;
      completedMilestones += milestones.where((m) => m.status == JourneyStatus.completed).length;
    }

    final progress = totalMilestones > 0 ? completedMilestones / totalMilestones : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF143542).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1ED3CF).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Progress',
                style: context.textStyles.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: context.textStyles.titleLarge?.copyWith(
                  color: const Color(0xFF1ED3CF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF0D2A3D),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1ED3CF)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ProgressStat(
                icon: Icons.check_circle,
                value: completedMilestones.toString(),
                label: 'Completed',
                color: const Color(0xFF4CAF50),
              ),
              _ProgressStat(
                icon: Icons.trending_up,
                value: totalMilestones.toString(),
                label: 'Total',
                color: const Color(0xFF2196F3),
              ),
              _ProgressStat(
                icon: Icons.calendar_today,
                value: (_journeys?.length ?? 0).toString(),
                label: 'Domains',
                color: const Color(0xFFFF9800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAskArieCard() {
    return InkWell(
      onTap: () => context.push('/journey/builder'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E88FF), Color(0xFF1ED3CF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1ED3CF).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask ARIE',
                    style: context.textStyles.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Let me build a journey to complete a goal through milestones',
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDomainsGrid() {
    if (_domains == null || _domains!.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: _domains!.length,
      itemBuilder: (context, index) {
        final domain = _domains![index];
        return _DomainCard(domain: domain);
      },
    );
  }
}

// Supporting Widgets

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF143542).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1ED3CF).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF1ED3CF), size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _ProgressStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _DomainCard extends StatelessWidget {
  final RecoveryDomain domain;

  const _DomainCard({required this.domain});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF143542).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _getDomainIcon(domain.type),
                color: _getDomainColor(domain.type),
                size: 24,
              ),
              const Spacer(),
              Text(
                '${(domain.progressPercentage * 100).toInt()}%',
                style: TextStyle(
                  color: _getDomainColor(domain.type),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            domain.type.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: domain.progressPercentage,
              minHeight: 4,
              backgroundColor: const Color(0xFF0D2A3D),
              valueColor: AlwaysStoppedAnimation(_getDomainColor(domain.type)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDomainIcon(RecoveryDomainType type) {
    switch (type) {
      case RecoveryDomainType.mobility: return Icons.directions_walk;
      case RecoveryDomainType.selfCare: return Icons.self_improvement;
      case RecoveryDomainType.bowelBladder: return Icons.water_drop;
      case RecoveryDomainType.skinIntegrity: return Icons.healing;
      case RecoveryDomainType.respiratory: return Icons.air;
      case RecoveryDomainType.cardiovascular: return Icons.favorite;
      case RecoveryDomainType.painManagement: return Icons.medication;
      case RecoveryDomainType.mental: return Icons.psychology;
      case RecoveryDomainType.nutrition: return Icons.restaurant;
      case RecoveryDomainType.equipment: return Icons.wheelchair_pickup;
      case RecoveryDomainType.homeModification: return Icons.home;
      case RecoveryDomainType.advocacy: return Icons.gavel;
    }
  }

  Color _getDomainColor(RecoveryDomainType type) {
    switch (type) {
      case RecoveryDomainType.mobility: return const Color(0xFF2196F3);
      case RecoveryDomainType.selfCare: return const Color(0xFF9C27B0);
      case RecoveryDomainType.bowelBladder: return const Color(0xFF00BCD4);
      case RecoveryDomainType.skinIntegrity: return const Color(0xFFE91E63);
      case RecoveryDomainType.respiratory: return const Color(0xFF4CAF50);
      case RecoveryDomainType.cardiovascular: return const Color(0xFFF44336);
      case RecoveryDomainType.painManagement: return const Color(0xFFFF9800);
      case RecoveryDomainType.mental: return const Color(0xFF673AB7);
      case RecoveryDomainType.nutrition: return const Color(0xFF8BC34A);
      case RecoveryDomainType.equipment: return const Color(0xFF607D8B);
      case RecoveryDomainType.homeModification: return const Color(0xFF795548);
      case RecoveryDomainType.advocacy: return const Color(0xFF3F51B5);
    }
  }
}

class _JourneyCard extends StatelessWidget {
  final Journey journey;
  final List<Phase> phases;
  final Map<String, List<JourneyMilestone>> milestonesByPhase;

  const _JourneyCard({
    required this.journey,
    required this.phases,
    required this.milestonesByPhase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF143542).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
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
                  color: const Color(0xFF1ED3CF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.explore,
                  color: Color(0xFF1ED3CF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      journey.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (journey.description != null)
                      Text(
                        journey.description!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              _StatusBadge(status: journey.status),
            ],
          ),
          if (phases.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...phases.map((phase) {
              final phaseMilestones = milestonesByPhase[phase.id] ?? [];
              return _PhaseSection(
                phase: phase,
                milestones: phaseMilestones,
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _PhaseSection extends StatelessWidget {
  final Phase phase;
  final List<JourneyMilestone> milestones;

  const _PhaseSection({
    required this.phase,
    required this.milestones,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF1ED3CF),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              phase.title,
              style: const TextStyle(
                color: Color(0xFF1ED3CF),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${milestones.where((m) => m.status == JourneyStatus.completed).length}/${milestones.length}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...milestones.take(3).map((milestone) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _MilestoneTile(milestone: milestone),
        )),
        if (milestones.length > 3)
          TextButton(
            onPressed: () {},
            child: const Text('View all milestones'),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  final JourneyMilestone milestone;

  const _MilestoneTile({required this.milestone});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/journey/milestone/${milestone.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2A3D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              milestone.status == JourneyStatus.completed
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              color: milestone.status == JourneyStatus.completed
                  ? const Color(0xFF4CAF50)
                  : Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (milestone.dueDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(milestone.dueDate!),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (milestone.priority == PriorityLevel.critical)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF44336).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Critical',
                  style: TextStyle(
                    color: Color(0xFFF44336),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 7) return 'In $diff days';
    if (diff < 30) return 'In ${(diff / 7).ceil()} weeks';
    return 'In ${(diff / 30).ceil()} months';
  }
}

class _StatusBadge extends StatelessWidget {
  final JourneyStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    
    switch (status) {
      case JourneyStatus.notStarted:
        color = Colors.grey;
        icon = Icons.schedule;
      case JourneyStatus.inProgress:
        color = const Color(0xFF2196F3);
        icon = Icons.play_circle;
      case JourneyStatus.completed:
        color = const Color(0xFF4CAF50);
        icon = Icons.check_circle;
      case JourneyStatus.skipped:
        color = Colors.orange;
        icon = Icons.skip_next;
      case JourneyStatus.blocked:
        color = Colors.red;
        icon = Icons.block;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratingJourneyDialog extends StatelessWidget {
  const _GeneratingJourneyDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF143542),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1ED3CF).withValues(alpha: 0.3),
                    const Color(0xFF1E88FF).withValues(alpha: 0.3),
                  ],
                ),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 40,
                color: Color(0xFF1ED3CF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ARIE is generating your\npersonalized journey...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'This may take a few moments',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1ED3CF)),
            ),
          ],
        ),
      ),
    );
  }
}
