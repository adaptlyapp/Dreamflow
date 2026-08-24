import 'package:concentric_transition/concentric_transition.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/models/hospital.dart';
import 'package:wellspring/models/medication.dart';
import 'package:wellspring/models/organization.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/services/consent_service.dart';
import 'package:wellspring/services/hospital_service.dart';
import 'package:wellspring/services/organization_service.dart';
import 'package:wellspring/services/notification_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/brand_logo.dart';
import 'package:wellspring/providers/theme_provider.dart';
import 'package:wellspring/providers/user_provider.dart';

/// Entry to the onboarding flow with concentric transitions.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final ConditionService _conditionService = ConditionService();
  final OrganizationService _organizationService = OrganizationService();
  final UserService _userService = UserService();
  final ConsentService _consentService = ConsentService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _conditionSearchController =
      TextEditingController();
  final TextEditingController _organizationSearchController =
      TextEditingController();

  final List<String> _interestOptions = const [
    'Fitness & Exercise',
    'Nutrition & Diet',
    'Mental Health',
    'Mindfulness',
    'Support Groups',
    'New Research',
    'Treatment Options',
    'Lifestyle Tips',
  ];

  List<Condition> _conditions = [];
  List<Organization> _organizations = [];
  Set<String> _selectedConditions = {};
  Set<String> _selectedInterests = {};
  List<Medication> _medications = [];
  String? _selectedOrganizationId;
  DateTime? _diagnosisDate;
  bool _acceptedTerms = false;

  bool _loadingConditions = true;
  bool _loadingOrganizations = true;
  bool _isSaving = false;

  bool get _isComplete =>
      _nameController.text.trim().isNotEmpty &&
      _selectedOrganizationId != null &&
      _selectedConditions.isNotEmpty &&
      _diagnosisDate != null &&
      _acceptedTerms;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    await Future.wait([
      _prefillFromUser(),
      _loadConditions(),
      _loadOrganizations(),
    ]);
  }

  Future<void> _prefillFromUser() async {
    try {
      final user = await _userService.getCurrentUser();
      if (user != null) {
        final organizationId = (user.preferences['organizationId'] as String?)?.trim() ??
                               (user.preferences['hospitalId'] as String?)?.trim();
        setState(() {
          _nameController.text = user.name;
          _selectedConditions = {...user.conditions};
          _diagnosisDate = user.diagnosisDate;
          _selectedInterests = {...user.interests};
          _medications = [...user.medications];
          _acceptedTerms =
              (user.preferences['legal.termsAccepted'] as bool?) == true;
          if (organizationId != null && organizationId.isNotEmpty)
            _selectedOrganizationId = organizationId;
        });
        if (organizationId != null &&
            organizationId.isNotEmpty &&
            _organizations.isNotEmpty &&
            mounted) {
          try {
            final match = _organizations.firstWhere((o) => o.id == organizationId);
            await context.read<ThemeProvider>().applyOrganization(match);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('WelcomeScreen._prefillFromUser error: $e');
    }
  }

  Future<void> _loadConditions() async {
    try {
      final list = await _conditionService.getAllConditions();
      setState(() {
        _conditions = list;
        _loadingConditions = false;
      });
    } catch (e) {
      debugPrint('WelcomeScreen._loadConditions error: $e');
      setState(() => _loadingConditions = false);
    }
  }

  Future<void> _loadOrganizations() async {
    try {
      final list = await _organizationService.getAllOrganizations();
      setState(() {
        _organizations = list;
        _loadingOrganizations = false;
      });
      if (_selectedOrganizationId != null) {
        final match = list.where((o) => o.id == _selectedOrganizationId).toList();
        if (match.isNotEmpty && mounted) {
          await context.read<ThemeProvider>().applyOrganization(match.first);
        }
      }
    } catch (e) {
      debugPrint('WelcomeScreen._loadOrganizations error: $e');
      setState(() => _loadingOrganizations = false);
    }
  }

  List<Condition> get _visibleConditions {
    final query = _conditionSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _conditions;
    return _conditions.where((c) {
      final name = c.name.toLowerCase();
      final desc = c.description.toLowerCase();
      return name.contains(query) || desc.contains(query);
    }).toList();
  }

  List<Organization> get _visibleOrganizations {
    final query = _organizationSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _organizations;
    return _organizations
        .where((o) =>
            o.name.toLowerCase().contains(query) ||
            o.slug.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _pickDiagnosisDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _diagnosisDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 50),
      lastDate: now,
    );
    if (selected != null) {
      setState(() => _diagnosisDate = selected);
    }
  }

  Future<void> _saveAndFinish() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    
    // Validate all required fields with specific error messages
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name on the first slide.')),
      );
      return;
    }
    if (_selectedOrganizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose your organization on the second slide.')),
      );
      return;
    }
    if (_selectedConditions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one condition on the third slide.')),
      );
      return;
    }
    if (_diagnosisDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your diagnosis date on the fifth slide.')),
      );
      return;
    }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the Terms & Conditions on the first slide to continue.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = await _userService.getCurrentUser();
      if (user == null) {
        // Try one more time after a short delay (in case profile is being created)
        await Future.delayed(const Duration(milliseconds: 800));
        final retryUser = await _userService.getCurrentUser();
        if (retryUser == null) {
          if (mounted) {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Session expired. Please sign in again.'),
                  duration: Duration(seconds: 4)),
            );
            context.go('/auth');
          }
          return;
        }
        // Use the retry user if found
        debugPrint('WelcomeScreen: Found user on retry');
      }

      // Get the final user (either from first call or retry)
      final currentUser = user ?? await _userService.getCurrentUser();
      if (currentUser == null) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to load your profile. Please try again.')),
          );
        }
        return;
      }

      // Record consent with full audit trail
      if (_acceptedTerms) {
        final termsDoc =
            await _consentService.getActiveDocument('terms_and_conditions');
        if (termsDoc != null) {
          // CRITICAL: Use auth.uid() for RLS policy, not profile ID
          final authUserId = SupabaseConfig.client.auth.currentUser?.id;
          if (authUserId != null) {
            await _consentService.recordConsent(
              userId: authUserId,
              documentId: termsDoc.id,
              documentType: 'terms_and_conditions',
              documentVersion: termsDoc.version,
              consentMethod: 'onboarding',
              userAgent: 'Flutter App',
              deviceInfo: {
                'platform': defaultTargetPlatform.name,
                'app_version': 'onboarding',
              },
            );
            debugPrint(
                'WelcomeScreen: Recorded consent for T&C v${termsDoc.version}');
          }
        }
      }

      final prefs = Map<String, dynamic>.from(currentUser.preferences);
      prefs['organizationId'] = _selectedOrganizationId;
      if (_acceptedTerms) {
        prefs['legal.termsAccepted'] = true;
        prefs['legal.termsAcceptedAt'] =
            prefs['legal.termsAcceptedAt'] ?? DateTime.now().toIso8601String();
      }

      final updated = currentUser.copyWith(
        name: name,
        conditions: _selectedConditions.toList(),
        diagnosisDate: _diagnosisDate,
        interests: _selectedInterests.toList(),
        medications: _medications,
        preferences: prefs,
      );

      await _userService.completeOnboarding(updated);
      try {
        await context.read<UserProvider>().loadUser();
      } catch (e) {
        debugPrint(
            'WelcomeScreen: failed to refresh user after onboarding: $e');
      }
      // Schedule local notification reminders for the medications added
      // during onboarding so users see prompts at their chosen times.
      try {
        for (final m in _medications) {
          await NotificationService.instance.scheduleMedication(m);
        }
      } catch (e) {
        debugPrint('WelcomeScreen: failed to schedule med reminders: $e');
      }

      if (_selectedOrganizationId != null) {
        await _userService.ensurePatientCodeForCurrentUser(
            organizationId: _selectedOrganizationId!);
        final match =
            _organizations.where((o) => o.id == _selectedOrganizationId).toList();
        if (match.isNotEmpty && mounted) {
          await context.read<ThemeProvider>().applyOrganization(match.first);
        }
      }

      if (!mounted) return;
      context.go('/');
    } catch (e) {
      debugPrint('WelcomeScreen._saveAndFinish error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Something went wrong. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _conditionSearchController.dispose();
    _organizationSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    const primaryTeal = LightModeColors.adaptlyTeal;
    const deepTeal = DarkModeColors.adaptlyDeep;
    const slate = DarkModeColors.slate;
    final slides = [
      _WelcomeSlide(
        title: 'Your name',
        description: 'So we can personalize your experience.',
        icon: Icons.person_rounded,
        bgColor: const Color(0xFF14495A),
        textColor: Colors.white,
        accent: primaryTeal,
        isDark: true,
        child: _NameCard(
          controller: _nameController,
          onChanged: (_) => setState(() {}),
          isDark: true,
          acceptedTerms: _acceptedTerms,
          onToggleTerms: (value) => setState(() => _acceptedTerms = value),
          onViewTerms: () => context.push('/legal/terms'),
          onViewPrivacy: () => context.push('/legal/privacy'),
        ),
      ),
      _WelcomeSlide(
        title: 'Choose your organization',
        description:
            'We\'ll match branding and connect you to local resources.',
        icon: Icons.business_rounded,
        // Background behind the card (keep the card itself styled as-is).
        bgColor: const Color(0xFFA7F3D0),
        textColor: Colors.black,
        accent: primaryTeal,
        isDark: false,
        child: _OrganizationCard(
          loading: _loadingOrganizations,
          organizations: _visibleOrganizations,
          searchController: _organizationSearchController,
          selectedOrganizationId: _selectedOrganizationId,
          onSelect: (id) => setState(() => _selectedOrganizationId = id),
          onSearchChanged: () => setState(() {}),
          isDark: false,
          accent: primaryTeal,
        ),
      ),
      _WelcomeSlide(
        title: 'Conditions',
        description: 'Select everything you are managing today.',
        icon: Icons.favorite_rounded,
        bgColor: const Color(0xFF1A3B47),
        textColor: Colors.white,
        accent: primaryTeal,
        isDark: true,
        child: _ConditionsCard(
          loading: _loadingConditions,
          conditions: _visibleConditions,
          searchController: _conditionSearchController,
          selectedConditions: _selectedConditions,
          onToggle: (id) {
            setState(() {
              if (_selectedConditions.contains(id)) {
                _selectedConditions.remove(id);
              } else {
                _selectedConditions.add(id);
              }
            });
          },
          onSearchChanged: () => setState(() {}),
          isDark: true,
          accent: primaryTeal,
        ),
      ),
      _WelcomeSlide(
        title: 'Medications',
        description: 'Add your medications and when you take them.',
        icon: Icons.medication_rounded,
        bgColor: const Color(0xFF1E3A5F),
        textColor: Colors.white,
        accent: primaryTeal,
        isDark: true,
        child: _MedicationsCard(
          medications: _medications,
          onAdd: (medication) => setState(() => _medications.add(medication)),
          onRemove: (id) => setState(() => _medications.removeWhere((m) => m.id == id)),
          onUpdate: (medication) => setState(() {
            final index = _medications.indexWhere((m) => m.id == medication.id);
            if (index != -1) _medications[index] = medication;
          }),
          isDark: true,
          accent: primaryTeal,
        ),
      ),
      _WelcomeSlide(
        title: 'Diagnosis date',
        description: 'Helps tailor guidance to your stage.',
        icon: Icons.calendar_today_rounded,
        bgColor: primaryTeal,
        textColor: Colors.black,
        accent: deepTeal,
        isDark: false,
        child: _DiagnosisCard(
          diagnosisDate: _diagnosisDate,
          textColor: Colors.black,
          isDark: false,
          onPick: _pickDiagnosisDate,
        ),
      ),
      _WelcomeSlide(
        title: 'Interests',
        description: 'Get more of what matters to you.',
        icon: Icons.chat_bubble_rounded,
        bgColor: LightModeColors.onboardingTealWash,
        textColor: deepTeal,
        accent: primaryTeal,
        isDark: false,
        child: _InterestsCard(
          options: _interestOptions,
          selected: _selectedInterests,
          onToggle: (value) {
            setState(() {
              if (_selectedInterests.contains(value)) {
                _selectedInterests.remove(value);
              } else {
                _selectedInterests.add(value);
              }
            });
          },
          isDark: false,
          accent: primaryTeal,
        ),
      ),
    ];

    final circleRadius = width * 0.16;
    return Scaffold(
      body: Stack(
        children: [
          ConcentricPageView(
            colors: slides.map((p) => p.bgColor).toList(),
            itemCount: slides.length,
            radius: circleRadius,
            scaleFactor: 1.25,
            verticalPosition: 0.72,
            nextButtonBuilder: (context) => const SizedBox.shrink(),
            itemBuilder: (index) {
              final slide = slides[index % slides.length];
              return SafeArea(child: _ConcentricSlide(slide: slide));
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: AppSpacing.paddingMd,
                child: Transform.translate(
                  offset: const Offset(0, -8),
                  child: const BrandLogo(size: 128, withContainer: false),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextButton.icon(
                  onPressed: () async {
                    // Sign out first to avoid redirect loop
                    try {
                      await SupabaseConfig.auth.signOut();
                    } catch (e) {
                      debugPrint('[Welcome] Sign out error: $e');
                    }
                    if (context.mounted) {
                      context.go('/auth');
                    }
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text('Back to sign in', style: TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!_isComplete)
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Swipe right',
                              style: context.textStyles.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            const Icon(Icons.swipe_right_alt_rounded,
                                color: Colors.white, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_isComplete)
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.lg,
              child: Center(
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveAndFinish,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_isSaving ? 'Saving...' : 'Save & continue'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg)),
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    foregroundColor: Colors.black,
                    elevation: 4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WelcomeSlide {
  const _WelcomeSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.bgColor,
    required this.textColor,
    required this.accent,
    required this.isDark,
    required this.child,
  });
  final String title;
  final String description;
  final IconData icon;
  final Color bgColor;
  final Color textColor;
  final Color accent;
  final bool isDark;
  final Widget child;
}

class _ConcentricSlide extends StatelessWidget {
  const _ConcentricSlide({required this.slide});
  final _WelcomeSlide slide;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final num iconSize = (height * 0.12).clamp(64.0, 96.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minHeight: constraints.maxHeight - AppSpacing.lg * 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                      color: slide.textColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: Icon(slide.icon,
                      size: iconSize.toDouble(), color: slide.textColor),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  slide.title,
                  style: context.textStyles.headlineMedium?.copyWith(
                      color: slide.textColor, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  slide.description,
                  style: context.textStyles.titleMedium
                      ?.copyWith(color: slide.textColor.withValues(alpha: 0.9)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                    height: 4,
                    width: 80,
                    decoration: BoxDecoration(
                        color: slide.accent.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: AppSpacing.lg),
                slide.child,
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NameCard extends StatelessWidget {
  const _NameCard({
    required this.controller,
    required this.onChanged,
    required this.isDark,
    required this.acceptedTerms,
    required this.onToggleTerms,
    required this.onViewTerms,
    required this.onViewPrivacy,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isDark;
  final bool acceptedTerms;
  final ValueChanged<bool> onToggleTerms;
  final VoidCallback onViewTerms;
  final VoidCallback onViewPrivacy;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final fieldFill = isDark ? Colors.white.withOpacity(0.1) : Colors.white;
    final border = isDark
        ? Colors.white.withOpacity(0.2)
        : LightModeColors.lightOutline.withOpacity(0.6);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            textInputAction: TextInputAction.next,
            onChanged: onChanged,
            style: context.textStyles.titleMedium?.copyWith(color: textColor),
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle: context.textStyles.titleSmall
                  ?.copyWith(color: textColor.withOpacity(0.7)),
              hintText: 'How should we call you?',
              hintStyle: context.textStyles.titleSmall
                  ?.copyWith(color: textColor.withOpacity(0.5)),
              filled: true,
              fillColor: fieldFill,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox.adaptive(
                value: acceptedTerms,
                onChanged: (value) => onToggleTerms(value ?? false),
                activeColor: LightModeColors.adaptlyTeal,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'I agree to the',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: textColor),
                    ),
                    TextButton(
                      onPressed: onViewTerms,
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text('Terms & Conditions',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: textColor,
                                  decoration: TextDecoration.underline)),
                    ),
                    Text(
                      'and',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: textColor),
                    ),
                    TextButton(
                      onPressed: onViewPrivacy,
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text('Privacy Policy',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: textColor,
                                  decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrganizationCard extends StatelessWidget {
  const _OrganizationCard({
    required this.loading,
    required this.organizations,
    required this.searchController,
    required this.selectedOrganizationId,
    required this.onSelect,
    required this.onSearchChanged,
    required this.isDark,
    required this.accent,
  });

  final bool loading;
  final List<Organization> organizations;
  final TextEditingController searchController;
  final String? selectedOrganizationId;
  final ValueChanged<String> onSelect;
  final VoidCallback onSearchChanged;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final border =
        isDark ? Colors.white.withOpacity(0.18) : LightModeColors.lightOutline;
    // Avoid stark-white surfaces on light slides; use a slightly tinted surface.
    final shellColor = isDark
        ? Colors.white.withOpacity(0.08)
        : LightModeColors.lightSurfaceVariant.withValues(alpha: 0.92);
    final searchFill = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withValues(alpha: 0.72);
    final tileBaseColor = isDark
        ? Colors.white.withOpacity(0.04)
        : Colors.white.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: shellColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            onChanged: (_) => onSearchChanged(),
            decoration: InputDecoration(
              hintText: 'Search organizations',
              prefixIcon: Icon(Icons.search,
                  color: isDark
                      ? Colors.white.withOpacity(0.78)
                      : Colors.black.withValues(alpha: 0.65)),
              filled: true,
              fillColor: searchFill,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: CircularProgressIndicator()))
          else if (organizations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'No organizations found',
                style: context.textStyles.titleSmall?.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                itemCount: organizations.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final organization = organizations[index];
                  final isSelected = selectedOrganizationId == organization.id;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    tileColor:
                        isSelected ? accent.withOpacity(0.12) : tileBaseColor,
                    title: Text(organization.name,
                        style: context.textStyles.titleMedium?.copyWith(
                            color: isDark ? Colors.white : Colors.black)),
                    subtitle: organization.slug.isNotEmpty
                        ? Text(
                            '@${organization.slug}',
                            style: context.textStyles.bodyMedium?.copyWith(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.7)),
                          )
                        : null,
                    trailing: isSelected
                        ? Icon(Icons.check_circle,
                            color: isDark ? Colors.white : Colors.black)
                        : null,
                    onTap: () => onSelect(organization.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ConditionsCard extends StatelessWidget {
  const _ConditionsCard({
    required this.loading,
    required this.conditions,
    required this.searchController,
    required this.selectedConditions,
    required this.onToggle,
    required this.onSearchChanged,
    required this.isDark,
    required this.accent,
  });

  final bool loading;
  final List<Condition> conditions;
  final TextEditingController searchController;
  final Set<String> selectedConditions;
  final ValueChanged<String> onToggle;
  final VoidCallback onSearchChanged;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bool effectiveDark = isDark && brightness == Brightness.dark;
    final border = effectiveDark
        ? Colors.white.withOpacity(0.18)
        : LightModeColors.lightOutline.withOpacity(0.65);
    final shellColor =
        effectiveDark ? Colors.white.withOpacity(0.08) : Colors.white;
    final searchFill = effectiveDark
        ? Colors.white.withOpacity(0.12)
        : LightModeColors.lightSurfaceVariant;
    final textColor = effectiveDark ? Colors.white : Colors.black87;
    final hintColor = textColor.withOpacity(effectiveDark ? 0.7 : 0.55);
    final chipBackground = effectiveDark
        ? Colors.white.withOpacity(0.08)
        : LightModeColors.lightSurfaceVariant;
    final chipSelectedColor = accent.withOpacity(effectiveDark ? 0.45 : 0.2);
    final chipSelectedText = effectiveDark ? Colors.black : Colors.black87;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: shellColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            onChanged: (_) => onSearchChanged(),
            style: context.textStyles.bodyMedium?.copyWith(color: textColor),
            decoration: InputDecoration(
              hintText: 'Search conditions',
              hintStyle:
                  context.textStyles.bodyMedium?.copyWith(color: hintColor),
              prefixIcon: Icon(Icons.search, color: hintColor),
              filled: true,
              fillColor: searchFill,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: border.withOpacity(0.4))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: border.withOpacity(0.4))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: accent.withOpacity(0.6))),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: CircularProgressIndicator()))
          else if (conditions.isEmpty)
            Text('No conditions found', style: context.textStyles.titleSmall)
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: conditions.map((condition) {
                    final isSelected =
                        selectedConditions.contains(condition.id);
                    return FilterChip(
                      label: Text(
                        condition.name,
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: isSelected ? chipSelectedText : textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: chipSelectedColor,
                      checkmarkColor: chipSelectedText,
                      backgroundColor: chipBackground,
                      side: BorderSide(color: isSelected ? accent : border),
                      onSelected: (_) => onToggle(condition.id),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiagnosisCard extends StatelessWidget {
  const _DiagnosisCard(
      {required this.diagnosisDate,
      required this.textColor,
      required this.onPick,
      required this.isDark});
  final DateTime? diagnosisDate;
  final Color textColor;
  final VoidCallback onPick;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final formatted = diagnosisDate != null
        ? '${diagnosisDate!.month}/${diagnosisDate!.day}/${diagnosisDate!.year}'
        : 'Tap to select date';
    final shellColor = isDark ? Colors.white.withOpacity(0.08) : Colors.white;
    final border =
        isDark ? Colors.white.withOpacity(0.2) : LightModeColors.lightOutline;
    final buttonFill =
        isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.9);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: shellColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(
            'When were you diagnosed?',
            style: context.textStyles.titleMedium?.copyWith(color: textColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(
            onPressed: onPick,
            style: FilledButton.styleFrom(
              backgroundColor: buttonFill,
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: Text(formatted),
          ),
        ],
      ),
    );
  }
}

class _InterestsCard extends StatelessWidget {
  const _InterestsCard(
      {required this.options,
      required this.selected,
      required this.onToggle,
      required this.isDark,
      required this.accent});
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final border =
        isDark ? Colors.white.withOpacity(0.18) : LightModeColors.lightOutline;
    final shellColor = isDark ? Colors.white.withOpacity(0.08) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: shellColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: options.map((option) {
              final isSelected = selected.contains(option);
              return FilterChip(
                label: Text(option,
                    style: context.textStyles.bodyMedium?.copyWith(
                        color: isSelected
                            ? (isDark ? Colors.black : Colors.black)
                            : textColor)),
                selected: isSelected,
                selectedColor: accent.withOpacity(isDark ? 0.5 : 0.3),
                checkmarkColor: Colors.black,
                backgroundColor:
                    isDark ? Colors.white.withOpacity(0.08) : Colors.white,
                side: BorderSide(color: isSelected ? accent : border),
                onSelected: (_) => onToggle(option),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _MedicationsCard extends StatefulWidget {
  const _MedicationsCard({
    required this.medications,
    required this.onAdd,
    required this.onRemove,
    required this.onUpdate,
    required this.isDark,
    required this.accent,
  });

  final List<Medication> medications;
  final ValueChanged<Medication> onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<Medication> onUpdate;
  final bool isDark;
  final Color accent;

  @override
  State<_MedicationsCard> createState() => _MedicationsCardState();
}

class _MedicationsCardState extends State<_MedicationsCard> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  List<TimeOfDay> _selectedTimes = [];
  bool _isAdding = false;
  
  // Quick time presets
  static const _morningTime = TimeOfDay(hour: 8, minute: 0);
  static const _noonTime = TimeOfDay(hour: 12, minute: 0);
  static const _nightTime = TimeOfDay(hour: 20, minute: 0);
  
  bool get _hasMorning => _selectedTimes.any((t) => t.hour == _morningTime.hour && t.minute == _morningTime.minute);
  bool get _hasNoon => _selectedTimes.any((t) => t.hour == _noonTime.hour && t.minute == _noonTime.minute);
  bool get _hasNight => _selectedTimes.any((t) => t.hour == _nightTime.hour && t.minute == _nightTime.minute);
  
  void _togglePresetTime(TimeOfDay time) {
    setState(() {
      final exists = _selectedTimes.any((t) => t.hour == time.hour && t.minute == time.minute);
      if (exists) {
        _selectedTimes.removeWhere((t) => t.hour == time.hour && t.minute == time.minute);
      } else {
        _selectedTimes.add(time);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  void _toggleAddMode() {
    setState(() {
      _isAdding = !_isAdding;
      if (!_isAdding) {
        _nameController.clear();
        _dosageController.clear();
        _selectedTimes.clear();
      }
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null && !_selectedTimes.any((t) => t.hour == time.hour && t.minute == time.minute)) {
      setState(() => _selectedTimes.add(time));
    }
  }

  void _removeTime(TimeOfDay time) {
    setState(() => _selectedTimes.remove(time));
  }

  void _addMedication() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a medication name')),
      );
      return;
    }

    final times = _selectedTimes
        .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
        .toList()
      ..sort();

    final medication = Medication(
      id: const Uuid().v4(),
      name: name,
      dosage: _dosageController.text.trim().isEmpty ? null : _dosageController.text.trim(),
      times: times,
    );

    widget.onAdd(medication);
    _toggleAddMode();
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
  
  String _getTimeLabel(TimeOfDay time) {
    if (time.hour == _morningTime.hour && time.minute == _morningTime.minute) {
      return 'Morning';
    } else if (time.hour == _noonTime.hour && time.minute == _noonTime.minute) {
      return 'Noon';
    } else if (time.hour == _nightTime.hour && time.minute == _nightTime.minute) {
      return 'Night';
    }
    return _formatTime(time);
  }

  @override
  Widget build(BuildContext context) {
    final border = widget.isDark
        ? Colors.white.withOpacity(0.18)
        : LightModeColors.lightOutline;
    final shellColor =
        widget.isDark ? Colors.white.withOpacity(0.08) : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final hintColor = textColor.withOpacity(widget.isDark ? 0.7 : 0.55);
    final fieldFill = widget.isDark
        ? Colors.white.withOpacity(0.12)
        : LightModeColors.lightSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: shellColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Medication list
          if (widget.medications.isNotEmpty) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.medications.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final med = widget.medications[index];
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: border.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.medication_rounded,
                            color: widget.accent, size: 24),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med.name,
                                style: context.textStyles.titleMedium?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (med.dosage != null && med.dosage!.isNotEmpty)
                                Text(
                                  med.dosage!,
                                  style: context.textStyles.bodySmall?.copyWith(
                                    color: hintColor,
                                  ),
                                ),
                              if (med.times.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Wrap(
                                    spacing: AppSpacing.xs,
                                    runSpacing: AppSpacing.xs,
                                    children: med.times.map((t) {
                                      final parts = t.split(':');
                                      final hour = int.tryParse(parts[0]) ?? 0;
                                      final minute = int.tryParse(parts[1]) ?? 0;
                                      final time = TimeOfDay(hour: hour, minute: minute);
                                      final label = _getTimeLabel(time);
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: widget.accent.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          label,
                                          style: context.textStyles.labelSmall?.copyWith(
                                            color: widget.isDark ? Colors.white : Colors.black87,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: Colors.red.shade300, size: 20),
                          onPressed: () => widget.onRemove(med.id),
                          tooltip: 'Remove',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Add medication form
          if (_isAdding) ...[
            TextField(
              controller: _nameController,
              style: context.textStyles.bodyMedium?.copyWith(color: textColor),
              decoration: InputDecoration(
                hintText: 'Medication name',
                hintStyle: context.textStyles.bodyMedium?.copyWith(color: hintColor),
                prefixIcon: Icon(Icons.medication_outlined, color: hintColor),
                filled: true,
                fillColor: fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: border.withOpacity(0.4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: border.withOpacity(0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: widget.accent.withOpacity(0.6)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _dosageController,
              style: context.textStyles.bodyMedium?.copyWith(color: textColor),
              decoration: InputDecoration(
                hintText: 'Dosage (optional, e.g., 50mg)',
                hintStyle: context.textStyles.bodyMedium?.copyWith(color: hintColor),
                prefixIcon: Icon(Icons.science_outlined, color: hintColor),
                filled: true,
                fillColor: fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: border.withOpacity(0.4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: border.withOpacity(0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: widget.accent.withOpacity(0.6)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Quick preset times
            Text(
              'When do you take it?',
              style: context.textStyles.titleSmall?.copyWith(color: textColor),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _TimePresetChip(
                  label: 'Morning',
                  subtitle: '8:00 AM',
                  icon: Icons.wb_sunny_outlined,
                  isSelected: _hasMorning,
                  onTap: () => _togglePresetTime(_morningTime),
                  isDark: widget.isDark,
                  accent: widget.accent,
                ),
                _TimePresetChip(
                  label: 'Noon',
                  subtitle: '12:00 PM',
                  icon: Icons.wb_twilight_outlined,
                  isSelected: _hasNoon,
                  onTap: () => _togglePresetTime(_noonTime),
                  isDark: widget.isDark,
                  accent: widget.accent,
                ),
                _TimePresetChip(
                  label: 'Night',
                  subtitle: '8:00 PM',
                  icon: Icons.nights_stay_outlined,
                  isSelected: _hasNight,
                  onTap: () => _togglePresetTime(_nightTime),
                  isDark: widget.isDark,
                  accent: widget.accent,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Custom times and selected times display
            Row(
              children: [
                Text(
                  'Custom times:',
                  style: context.textStyles.bodySmall?.copyWith(color: hintColor),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      // Show only non-preset custom times as chips
                      ..._selectedTimes
                          .where((t) =>
                              !(t.hour == _morningTime.hour && t.minute == _morningTime.minute) &&
                              !(t.hour == _noonTime.hour && t.minute == _noonTime.minute) &&
                              !(t.hour == _nightTime.hour && t.minute == _nightTime.minute))
                          .map((time) => Chip(
                                label: Text(_formatTime(time)),
                                labelStyle: context.textStyles.labelMedium?.copyWith(
                                  color: widget.isDark ? Colors.black : Colors.black87,
                                ),
                                backgroundColor: widget.accent.withValues(alpha: 0.3),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () => _removeTime(time),
                                visualDensity: VisualDensity.compact,
                              )),
                      ActionChip(
                        label: const Icon(Icons.add, size: 18),
                        onPressed: _pickTime,
                        backgroundColor: fieldFill,
                        side: BorderSide(color: border),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _toggleAddMode,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: border),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: _addMedication,
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.accent,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Add medication button
            OutlinedButton.icon(
              onPressed: _toggleAddMode,
              icon: Icon(Icons.add_rounded, color: widget.accent),
              label: Text(
                widget.medications.isEmpty ? 'Add your first medication' : 'Add another medication',
                style: TextStyle(color: textColor),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                side: BorderSide(color: widget.accent.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
            if (widget.medications.isEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'You can skip this step if you don\'t take any medications.',
                style: context.textStyles.bodySmall?.copyWith(
                  color: hintColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TimePresetChip extends StatelessWidget {
  const _TimePresetChip({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    required this.accent,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final selectedBg = accent.withValues(alpha: 0.25);
    final unselectedBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.1);
    final border = isSelected
        ? accent
        : isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.3);
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: border, width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? accent : textColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.textStyles.labelMedium?.copyWith(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: context.textStyles.labelSmall?.copyWith(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.check_circle, size: 16, color: accent),
            ],
          ],
        ),
      ),
    );
  }
}
