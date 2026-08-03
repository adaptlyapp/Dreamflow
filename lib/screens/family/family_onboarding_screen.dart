import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/user.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/animated_blobs.dart';

class FamilyOnboardingScreen extends StatefulWidget {
  const FamilyOnboardingScreen({super.key});

  @override
  State<FamilyOnboardingScreen> createState() => _FamilyOnboardingScreenState();
}

class _FamilyOnboardingScreenState extends State<FamilyOnboardingScreen> {
  final _pageController = PageController();
  final _codeController = TextEditingController();
  int _currentPage = 0;
  String _selectedRelationship = 'Parent';
  bool _loading = false;
  String? _error;
  bool _hasExistingConnection = false;

  final _familyService = FamilyService();
  final _userService = UserService();

  static const _relationships = [
    'Parent',
    'Spouse',
    'Sibling',
    'Child',
    'Friend',
    'Caregiver',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _checkExistingConnections();
  }

  Future<void> _checkExistingConnections() async {
    try {
      final user = await _userService.getCurrentUser();
      if (user != null) {
        final connections = await _familyService.getConnectionsForFamily(user.id);
        if (connections.isNotEmpty) {
          debugPrint('[FamilyOnboarding] Found ${connections.length} existing connections, skipping patient code entry');
          setState(() => _hasExistingConnection = true);
        }
      }
    } catch (e) {
      debugPrint('[FamilyOnboarding] Error checking existing connections: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    final maxPages = _hasExistingConnection ? 2 : 4;
    if (_currentPage < maxPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _connectToPatient() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a patient code');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Validate code
      final patient = await _familyService.validatePatientCode(code);
      if (patient == null) {
        setState(() => _error = 'That code doesn\'t look right. Please check with the patient or care team.');
        return;
      }

      debugPrint('[FamilyOnboarding] ✓ Patient validated: ${patient.name}');
      debugPrint('[FamilyOnboarding] ✓ Patient profile ID: ${patient.id}');

      // Get current family user
      final familyUser = await _userService.getCurrentUser();
      if (familyUser == null) {
        setState(() => _error = 'Unable to connect. Please try signing out and back in.');
        return;
      }

      debugPrint('[FamilyOnboarding] ✓ Family member ID: ${familyUser.id}');

      // Create connection
      await _familyService.connectToPatient(
        familyMemberId: familyUser.id,
        patientId: patient.id,
        patientName: patient.name,
        relationship: _selectedRelationship,
        patientProfileImageUrl: patient.profileImageUrl,
        patientCode: code, // Store the patient code for re-login
      );

      debugPrint('[FamilyOnboarding] Connected to patient ${patient.id}');
      _nextPage();
    } catch (e) {
      debugPrint('[FamilyOnboarding] Error connecting to patient: $e');
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeOnboarding() async {
    debugPrint('[FamilyOnboarding] ========================================');
    debugPrint('[FamilyOnboarding] SKIP BUTTON PRESSED');
    debugPrint('[FamilyOnboarding] ========================================');
    setState(() => _loading = true);
    
    try {
      final user = await _userService.getCurrentUser();
      debugPrint('[FamilyOnboarding] ✓ Got current user: ${user?.name}');
      
      if (user == null) {
        debugPrint('[FamilyOnboarding] ✗ No user found');
        setState(() {
          _loading = false;
          _error = 'Unable to find your account. Please try again.';
        });
        return;
      }

      debugPrint('[FamilyOnboarding] ✓ Marking onboarding complete...');
      await _userService.completeOnboarding(user);
      debugPrint('[FamilyOnboarding] ✓ Onboarding marked complete');
      
      if (!mounted) return;
      
      debugPrint('[FamilyOnboarding] ✓ Reloading user provider...');
      await context.read<UserProvider>().loadUser();
      debugPrint('[FamilyOnboarding] ✓ Navigating to /family/dashboard');
      context.go('/family/dashboard');
    } catch (e) {
      debugPrint('[FamilyOnboarding] ✗ Complete onboarding error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F14) : const Color(0xFFF8FAFC),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (isDark) const AnimatedBlobs(),
          SafeArea(
            child: Column(
              children: [
                // Top bar with skip button and progress indicator
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Empty space for alignment
                          const SizedBox(width: 80),
                          // Progress indicators
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_hasExistingConnection ? 2 : 4, (index) {
                                final isActive = index == _currentPage;
                                final isPast = index < _currentPage;
                                final maxPages = _hasExistingConnection ? 2 : 4;
                                return Container(
                                  width: 32,
                                  height: 4,
                                  margin: EdgeInsets.only(
                                    right: index < maxPages - 1 ? AppSpacing.xs : 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive || isPast
                                        ? cs.primary
                                        : isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            ),
                          ),
                          // Skip button
                          TextButton(
                            onPressed: _loading ? null : _completeOnboarding,
                            style: TextButton.styleFrom(
                              foregroundColor: cs.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                            ),
                            child: const Text('Skip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    children: _hasExistingConnection 
                        ? [
                            // Skip welcome and connect pages for returning users
                            _PermissionsPage(onNext: _nextPage),
                            _TutorialPage(
                              onComplete: _completeOnboarding,
                              loading: _loading,
                              error: _error,
                            ),
                          ]
                        : [
                            _WelcomePage(onNext: _nextPage),
                            _ConnectPage(
                              codeController: _codeController,
                              selectedRelationship: _selectedRelationship,
                              relationships: _relationships,
                              onRelationshipChanged: (value) =>
                                  setState(() => _selectedRelationship = value),
                              onConnect: _connectToPatient,
                              loading: _loading,
                              error: _error,
                            ),
                            _PermissionsPage(onNext: _nextPage),
                            _TutorialPage(
                              onComplete: _completeOnboarding,
                              loading: _loading,
                              error: _error,
                            ),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.family_restroom,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Welcome to Adaptly Family',
            style: context.textStyles.displaySmall?.copyWith(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Stay connected to your loved one\'s recovery journey and provide support every step of the way.',
            style: context.textStyles.bodyLarge?.copyWith(
              color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF475569),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl * 1.5),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }
}

class _ConnectPage extends StatelessWidget {
  const _ConnectPage({
    required this.codeController,
    required this.selectedRelationship,
    required this.relationships,
    required this.onRelationshipChanged,
    required this.onConnect,
    required this.loading,
    this.error,
  });

  final TextEditingController codeController;
  final String selectedRelationship;
  final List<String> relationships;
  final ValueChanged<String> onRelationshipChanged;
  final VoidCallback onConnect;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Connect to Patient',
            style: context.textStyles.displaySmall?.copyWith(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Enter the patient code provided by your loved one or their care team.',
            style: context.textStyles.bodyLarge?.copyWith(
              color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          
          // Error message
          if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: cs.onErrorContainer),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      error!,
                      style: context.textStyles.bodyMedium?.copyWith(color: cs.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Patient code field
          TextField(
            controller: codeController,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: 'Patient Code',
              hintText: 'SDX-93F3B4',
              prefixIcon: Icon(Icons.pin, color: cs.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Relationship dropdown
          Text(
            'Your Relationship',
            style: context.textStyles.labelLarge?.copyWith(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: isDark ? const Color(0xFF2A3441) : const Color(0xFFE5E7EB),
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: DropdownButton<String>(
              value: selectedRelationship,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: isDark ? const Color(0xFF1F2937) : Colors.white,
              icon: Icon(Icons.arrow_drop_down, color: cs.primary),
              items: relationships
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (value) {
                if (value != null) onRelationshipChanged(value);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Connect button
          FilledButton(
            onPressed: loading ? null : onConnect,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Connect to Patient'),
          ),
        ],
      ),
    );
  }
}

class _PermissionsPage extends StatelessWidget {
  const _PermissionsPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Privacy & Permissions',
            style: context.textStyles.displaySmall?.copyWith(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'You\'ll only see information that the patient or care team has shared with family. Private patient-only information will remain hidden.',
            style: context.textStyles.bodyLarge?.copyWith(
              color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF475569),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl * 1.5),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  const _TutorialPage({
    required this.onComplete,
    required this.loading,
    this.error,
  });

  final VoidCallback onComplete;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.tour_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'You\'re All Set!',
            style: context.textStyles.displaySmall?.copyWith(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Start exploring the family portal to support your loved one\'s recovery journey.',
            style: context.textStyles.bodyLarge?.copyWith(
              color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF475569),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl * 1.5),
          
          // Error message
          if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: cs.onErrorContainer),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      error!,
                      style: context.textStyles.bodyMedium?.copyWith(color: cs.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          FilledButton(
            onPressed: loading ? null : onComplete,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Enter Family Portal'),
          ),
        ],
      ),
    );
  }
}
