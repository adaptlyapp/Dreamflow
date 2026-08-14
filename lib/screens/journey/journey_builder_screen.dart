import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/journey_hierarchy.dart';
import 'package:wellspring/models/journey_template.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/journey_service.dart';
import 'package:wellspring/theme.dart';

/// Journey Builder Screen - Build personalized recovery journeys with ARIE
class JourneyBuilderScreen extends StatefulWidget {
  const JourneyBuilderScreen({super.key});

  @override
  State<JourneyBuilderScreen> createState() => _JourneyBuilderScreenState();
}

class _JourneyBuilderScreenState extends State<JourneyBuilderScreen> {
  final _journeyService = JourneyService();
  final _goalController = TextEditingController();
  
  List<JourneyMilestone>? _milestones;
  bool _isLoading = false;
  bool _isGenerating = false;
  String? _selectedDomain;
  int? _timelineDays;

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _buildJourney() async {
    if (_goalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your goal')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.currentUser?.id;

      if (userId == null) return;

      // Create a patient profile for journey generation
      final profile = PatientProfileInput(
        primaryDiagnosis: _selectedDomain ?? 'General Recovery',
        recoveryPhase: 'active',
        functionalClassification: 'Standard',
        cognitiveIndependence: {
          'decisions': 'independent',
          'communication': 'independent',
        },
        physicalIndependence: {
          'transfer': 'needsAssistance',
          'dress': 'needsAssistance',
          'mobility': 'needsAssistance',
        },
        therapyGoals: [_goalController.text.trim()],
        patientPriorities: [_goalController.text.trim()],
      );

      // Generate personalized journey (using condition ID '5' for Spinal Cord Injury)
      const conditionId = '5';
      await _journeyService.generatePersonalizedJourney(
        userId: userId,
        conditionId: conditionId,
        profile: profile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Journey created successfully!'),
            backgroundColor: Color(0xFF14B8A6),
            duration: Duration(seconds: 2),
          ),
        );
        // Navigate to the condition detail screen to show the journey
        context.go('/condition/$conditionId');
      }
    } catch (e) {
      debugPrint('Error building journey: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F2E),
      body: Stack(
        children: [
          // Background image
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
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Build Your Journey',
                            style: context.textStyles.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Powered by ARIE',
                            style: context.textStyles.bodySmall?.copyWith(
                              color: const Color(0xFF1ED3CF),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Intro card
                        _buildIntroCard(),
                        const SizedBox(height: 24),
                        // Goal input
                        _buildGoalInput(),
                        const SizedBox(height: 24),
                        // Timeline selector
                        _buildTimelineSelector(),
                        const SizedBox(height: 24),
                        // Domain selector
                        _buildDomainSelector(),
                        const SizedBox(height: 32),
                        // Build button
                        _buildActionButton(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ED3CF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF1ED3CF),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Let ARIE Guide You',
                      style: context.textStyles.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'AI-powered recovery planning',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'ARIE will create a personalized journey with milestones tailored to your goals. Each milestone includes education, product recommendations, and nearby resources.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What would you like to achieve?',
          style: context.textStyles.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF143542).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: TextField(
            controller: _goalController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Example: "I want to improve my upper body strength and learn to transfer independently"',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timeline',
          style: context.textStyles.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildTimelineChip('2 weeks', 14),
            _buildTimelineChip('1 month', 30),
            _buildTimelineChip('3 months', 90),
            _buildTimelineChip('6 months', 180),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineChip(String label, int days) {
    final isSelected = _timelineDays == days;
    return InkWell(
      onTap: () => setState(() => _timelineDays = days),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1ED3CF).withValues(alpha: 0.3)
              : const Color(0xFF143542).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1ED3CF)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildDomainSelector() {
    final domains = [
      ('Mobility', Icons.directions_walk),
      ('Self-Care', Icons.self_improvement),
      ('Pain Management', Icons.medication),
      ('Mental Health', Icons.psychology),
      ('Nutrition', Icons.restaurant),
      ('Equipment', Icons.wheelchair_pickup),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Focus Area (Optional)',
          style: context.textStyles.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: domains.map((domain) {
            final isSelected = _selectedDomain == domain.$1;
            return InkWell(
              onTap: () => setState(() {
                _selectedDomain = isSelected ? null : domain.$1;
              }),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1ED3CF).withValues(alpha: 0.3)
                      : const Color(0xFF143542).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1ED3CF)
                        : Colors.white.withValues(alpha: 0.1),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      domain.$2,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      domain.$1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
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
            onTap: _isGenerating ? null : _buildJourney,
            child: Center(
              child: _isGenerating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Build My Journey',
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
    );
  }
}
