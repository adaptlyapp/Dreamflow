import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/glass_card.dart';

class FamilyOnboardingScreen extends StatefulWidget {
  const FamilyOnboardingScreen({super.key});

  @override
  State<FamilyOnboardingScreen> createState() => _FamilyOnboardingScreenState();
}

class _FamilyOnboardingScreenState extends State<FamilyOnboardingScreen> {
  final _pageController = PageController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  int _currentPage = 0;
  String _selectedRelationship = 'Parent';
  bool _loading = false;
  String? _error;

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

  static const int _totalSteps = 4;

  static const List<String> _stepLabels = [
    'Welcome',
    'Connect',
    'Privacy',
    'Done',
  ];

  bool get _isLight => Theme.of(context).brightness == Brightness.light;

  InputDecoration _onboardingFieldDecoration({required String labelText, String? hintText, IconData? prefixIcon}) {
    final cs = Theme.of(context).colorScheme;
    final fillColor = _isLight ? Colors.white.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.06);
    final fg = _isLight ? Colors.black : Colors.white;
    final subtle = fg.withValues(alpha: 0.7);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: fillColor,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, color: subtle),
      labelStyle: context.textStyles.bodyMedium?.withColor(subtle),
      floatingLabelStyle: context.textStyles.bodyMedium?.withColor(fg.withValues(alpha: 0.92)),
      hintStyle: context.textStyles.bodyMedium?.withColor(subtle),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.55), width: 1),
      ),
      isDense: true,
    );
  }

  @override
  void initState() {
    super.initState();
    // Don't check for existing connections during onboarding
    // Always show all pages to ensure proper first-time setup
    // Users can manage connections later from the dashboard
  }

  @override
  void dispose() {
    _pageController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _connectToPatient() async {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    
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
      
      // Update family member's name
      await _userService.updateUserProfile(name: name);
      debugPrint('[FamilyOnboarding] ✓ Updated family member name to: $name');

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
    final titleColor = _isLight ? Colors.black : Colors.white;
    return GlassyScaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: titleColor),
          onPressed: () async {
            if (_currentPage > 0) {
              await _pageController.previousPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
              return;
            }
            try {
              await context.read<UserProvider>().logout();
            } catch (e) {
              debugPrint('FamilyOnboarding logout error: $e');
            }
            if (!context.mounted) return;
            context.go('/auth');
          },
        ),
        title: Text(
          'Family setup',
          style: context.textStyles.titleLarge?.semiBold?.withColor(titleColor),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _loading ? null : _completeOnboarding,
            style: TextButton.styleFrom(foregroundColor: cs.primary),
            child: Text('Skip', style: context.textStyles.labelLarge?.semiBold?.withColor(cs.primary)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: GlassCard(
                showGlow: true,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FamilyOnboardingTopBar(
                      currentStep: _currentPage,
                      totalSteps: _totalSteps,
                      stepLabel: _stepLabels[_currentPage.clamp(0, _stepLabels.length - 1)],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _FamilyProgressBar(value: (_currentPage + 1) / _totalSteps),
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _totalSteps,
                        onPageChanged: (page) => setState(() => _currentPage = page),
                        itemBuilder: (context, index) {
                          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              final page = _pageController.hasClients ? (_pageController.page ?? _currentPage.toDouble()) : _currentPage.toDouble();
                              final dist = (page - index).abs().clamp(0.0, 1.0);
                              final t = 1.0 - dist;
                              final opacity = 0.55 + (0.45 * t);
                              final scale = 0.98 + (0.02 * t);
                              return Opacity(
                                opacity: opacity,
                                child: Transform.scale(
                                  scale: scale,
                                  alignment: Alignment.topCenter,
                                  child: child,
                                ),
                              );
                            },
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(0, 0, 0, AppSpacing.lg + bottomInset),
                              child: _FamilyOnboardingStep(
                                index: index,
                                onNext: _nextPage,
                                onComplete: _completeOnboarding,
                                onConnect: _connectToPatient,
                                loading: _loading,
                                error: _error,
                                nameController: _nameController,
                                codeController: _codeController,
                                selectedRelationship: _selectedRelationship,
                                relationships: _relationships,
                                onRelationshipChanged: (value) => setState(() => _selectedRelationship = value),
                                fieldDecoration: _onboardingFieldDecoration,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FamilyOnboardingTopBar extends StatelessWidget {
  const _FamilyOnboardingTopBar({required this.currentStep, required this.totalSteps, required this.stepLabel});

  final int currentStep;
  final int totalSteps;
  final String stepLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final titleColor = isLight ? Colors.black : Colors.white;
    final subtitleColor = titleColor.withValues(alpha: 0.7);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: isLight ? 0.12 : 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Step ${currentStep + 1} of $totalSteps',
            style: context.textStyles.labelMedium?.semiBold?.withColor(cs.primary),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stepLabel, style: context.textStyles.titleMedium?.semiBold?.withColor(titleColor), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                'Set up your access to your loved one\'s journey.',
                style: context.textStyles.bodySmall?.withColor(subtitleColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FamilyProgressBar extends StatelessWidget {
  const _FamilyProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).brightness == Brightness.light
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.10);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(decoration: BoxDecoration(color: bg)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyOnboardingStep extends StatelessWidget {
  const _FamilyOnboardingStep({
    required this.index,
    required this.onNext,
    required this.onComplete,
    required this.onConnect,
    required this.loading,
    required this.nameController,
    required this.codeController,
    required this.selectedRelationship,
    required this.relationships,
    required this.onRelationshipChanged,
    required this.fieldDecoration,
    this.error,
  });

  final int index;
  final VoidCallback onNext;
  final VoidCallback onComplete;
  final VoidCallback onConnect;
  final bool loading;
  final String? error;
  final TextEditingController nameController;
  final TextEditingController codeController;
  final String selectedRelationship;
  final List<String> relationships;
  final ValueChanged<String> onRelationshipChanged;
  final InputDecoration Function({required String labelText, String? hintText, IconData? prefixIcon}) fieldDecoration;

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 0:
        return _WelcomePage(onNext: onNext);
      case 1:
        return _ConnectPage(
          nameController: nameController,
          codeController: codeController,
          selectedRelationship: selectedRelationship,
          relationships: relationships,
          onRelationshipChanged: onRelationshipChanged,
          onConnect: onConnect,
          loading: loading,
          error: error,
          fieldDecoration: fieldDecoration,
        );
      case 2:
        return _PermissionsPage(onNext: onNext);
      default:
        return _TutorialPage(onComplete: onComplete, loading: loading, error: error);
    }
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;
    final muted = fg.withValues(alpha: 0.72);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
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
              color: fg,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Stay connected to your loved one\'s recovery journey and provide support every step of the way.',
            style: context.textStyles.bodyLarge?.copyWith(
              color: muted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl * 1.5),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
    required this.nameController,
    required this.codeController,
    required this.selectedRelationship,
    required this.relationships,
    required this.onRelationshipChanged,
    required this.onConnect,
    required this.loading,
    required this.fieldDecoration,
    this.error,
  });

  final TextEditingController nameController;
  final TextEditingController codeController;
  final String selectedRelationship;
  final List<String> relationships;
  final ValueChanged<String> onRelationshipChanged;
  final VoidCallback onConnect;
  final bool loading;
  final String? error;
  final InputDecoration Function({required String labelText, String? hintText, IconData? prefixIcon}) fieldDecoration;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;
    final muted = fg.withValues(alpha: 0.72);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect to Patient',
            style: context.textStyles.displaySmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Enter the patient code provided by your loved one or their care team.',
            style: context.textStyles.bodyLarge?.copyWith(
              color: muted,
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

          // Family member name field
          TextField(
            controller: nameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            decoration: fieldDecoration(labelText: 'Your Name', hintText: 'Enter your full name', prefixIcon: Icons.person),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Patient code field
          TextField(
            controller: codeController,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            maxLength: 10,
            decoration: fieldDecoration(labelText: 'Patient Code', hintText: 'SDX-93F3B4', prefixIcon: Icons.pin),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Relationship dropdown
          Text(
            'Your Relationship',
            style: context.textStyles.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: DropdownButton<String>(
              value: selectedRelationship,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: isDark ? const Color(0xFF0B1220) : Colors.white,
              icon: Icon(Icons.arrow_drop_down, color: cs.primary),
              style: context.textStyles.bodyMedium?.withColor(fg),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
    final fg = isDark ? Colors.white : Colors.black;
    final muted = fg.withValues(alpha: 0.72);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
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
              color: fg,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'You\'ll only see information that the patient or care team has shared with family. Private patient-only information will remain hidden.',
            style: context.textStyles.bodyLarge?.copyWith(
              color: muted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl * 1.5),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
    final fg = isDark ? Colors.white : Colors.black;
    final muted = fg.withValues(alpha: 0.72);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
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
              color: fg,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Start exploring the family portal to support your loved one\'s recovery journey.',
            style: context.textStyles.bodyLarge?.copyWith(
              color: muted,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
