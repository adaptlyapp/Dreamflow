import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/models/user.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/providers/theme_provider.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/services/organization_service.dart';
import 'package:wellspring/services/location_intelligence_service.dart';
import 'package:wellspring/models/organization.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/models/onboarding_prefill.dart';
import 'package:wellspring/models/condition_detail.dart';
import 'package:wellspring/models/medication.dart';
import 'package:wellspring/widgets/condition_details_form.dart';
import 'package:wellspring/widgets/glass_card.dart';
import 'package:wellspring/widgets/skeletons.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key, this.prefill});

  final OnboardingPrefill? prefill;

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _conditionService = ConditionService();
  final _userService = UserService();
  final _organizationService = OrganizationService();
  OnboardingPrefill? _prefill;
  String? _prefillOrganizationId;
  
  List<Condition> _allConditions = [];
  List<String> _selectedConditions = [];
  // Search state for conditions step
  final TextEditingController _conditionSearchController = TextEditingController();
  String _conditionQuery = '';
  /// Per-condition detail answers collected in the "Details" step.
  final Map<String, ConditionDetail> _conditionDetails = {};
  final List<Medication> _medications = [];
  DateTime? _diagnosisDate;
  final List<String> _selectedInterests = [];
  int _currentStep = 0;
  bool _isSaving = false;
  final PageController _pageController = PageController();
  final LocationIntelligenceService _locationService = LocationIntelligenceService();
  // Organization selection state
  List<Organization> _organizations = [];
  String? _selectedOrganizationId;
  bool _loadingOrganizations = true;
  final TextEditingController _organizationSearchController = TextEditingController();
  String _organizationQuery = '';

  bool _locationPromptOpen = false;

  final List<String> _interestOptions = [
    'Fitness & Exercise',
    'Nutrition & Diet',
    'Mental Health',
    'Mindfulness',
    'Support Groups',
    'New Research',
    'Treatment Options',
    'Lifestyle Tips',
  ];

  @override
  void initState() {
    super.initState();
    _prefillBasicInfoFromAuth();
    _prefill = widget.prefill;
    _applyPrefillToFields();
    _loadConditions();
    _loadOrganizations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptLocationPermission();
    });
  }

  Future<void> _maybePromptLocationPermission() async {
    if (!mounted || _locationPromptOpen) return;

    // Only patient onboarding uses ARIE recommendations.
    final user = context.read<UserProvider>().currentUser;
    if (user == null || user.role != UserRole.patient) return;

    final raw = (user.preferences[LocationIntelligenceService.prefKey] as Map<String, dynamic>?) ?? const {};
    final hasPrompted = (raw['hasPrompted'] as bool?) ?? false;
    if (hasPrompted) return;

    _locationPromptOpen = true;
    try {
      // Prompt iOS/Android permission early so ARIE can use nearby search without
      // additional in-app enable switches.
      await _locationService.ensurePermission(requestIfNeeded: true);
    } catch (e) {
      debugPrint('QuestionnaireScreen: location permission request failed (non-fatal): $e');
    } finally {
      _locationPromptOpen = false;

      // Mark prompted so we don't ask again.
      try {
        final u = context.read<UserProvider>().currentUser;
        if (u != null) {
          final prefs = Map<String, dynamic>.from(u.preferences);
          final loc = Map<String, dynamic>.from((prefs[LocationIntelligenceService.prefKey] as Map<String, dynamic>?) ?? const {});
          loc['hasPrompted'] = true;
          loc['precisionDecimals'] = (loc['precisionDecimals'] as int?) ?? LocationIntelligenceService.defaultRoundingDecimals;
          loc['maxTravelMiles'] = (loc['maxTravelMiles'] as num?) ?? 20;
          prefs[LocationIntelligenceService.prefKey] = loc;
          await _userService.updatePreferences(prefs);
          if (mounted) await context.read<UserProvider>().loadUser();
        }
      } catch (e) {
        debugPrint('QuestionnaireScreen: failed to persist hasPrompted: $e');
      }
    }
  }

  List<Condition> get _visibleConditions {
    if (_conditionQuery.isEmpty) return _allConditions;
    final q = _conditionQuery.toLowerCase();
    return _allConditions.where((c) {
      final name = c.name.toLowerCase();
      final desc = (c.description).toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();
  }

  Future<void> _loadConditions() async {
    final conditions = await _conditionService.getAllConditions();
    setState(() => _allConditions = conditions);
  }

  List<Organization> get _visibleOrganizations {
    if (_organizationQuery.isEmpty) return _organizations;
    final q = _organizationQuery.toLowerCase();
    return _organizations.where((o) {
      final name = o.name.toLowerCase();
      final slug = o.slug.toLowerCase();
      final city = (o.settings?['city']?.toString() ?? '').toLowerCase();
      final metro = (o.settings?['metro']?.toString() ?? '').toLowerCase();
      return name.contains(q) || slug.contains(q) || city.contains(q) || metro.contains(q);
    }).toList();
  }

  Future<void> _loadOrganizations() async {
    try {
      debugPrint('QuestionnaireScreen: Loading organizations from Supabase...');
      final list = await _organizationService.getAllOrganizations();
      debugPrint('QuestionnaireScreen: Loaded ${list.length} organizations');
      if (!mounted) return;
      setState(() => _organizations = list);

      final prefillId = (_prefillOrganizationId ?? '').trim();
      if (prefillId.isNotEmpty) {
        try {
          final match = list.firstWhere((x) => x.id == prefillId);
          setState(() => _selectedOrganizationId = match.id);
          await context.read<ThemeProvider>().applyOrganization(match);
        } catch (e) {
          debugPrint('QuestionnaireScreen._loadOrganizations apply prefill error: $e');
        }
      }
    } catch (e) {
      debugPrint('QuestionnaireScreen._loadOrganizations error: $e');
    } finally {
      if (mounted) setState(() => _loadingOrganizations = false);
    }
  }

  void _prefillBasicInfoFromAuth() {
    final u = SupabaseConfig.auth.currentUser;
    if (u != null) {
      // Prefill email and make it non-empty so the user isn't asked again
      _emailController.text = u.email ?? _emailController.text;
      // Prefill nickname if available (user can edit)
      final displayName = u.userMetadata?['full_name'] ?? u.userMetadata?['name'];
      if (displayName != null && displayName.toString().trim().isNotEmpty) {
        _nameController.text = displayName.toString().trim();
      }
    }
  }

  void _applyPrefillToFields() {
    if (_prefill == null) return;
    if ((_prefill!.name ?? '').isNotEmpty) {
      _nameController.text = _prefill!.name!;
    }
    if ((_prefill!.email ?? '').isNotEmpty) {
      _emailController.text = _prefill!.email!;
    }
    if (_prefill!.interests.isNotEmpty) {
      _selectedInterests
        ..clear()
        ..addAll(_prefill!.interests);
    }
    // Backward-compat: OnboardingPrefill still calls it hospitalId, but we now
    // treat this as the selected organization id.
    if ((_prefill!.hospitalId ?? '').isNotEmpty) {
      _prefillOrganizationId = _prefill!.hospitalId;
      _selectedOrganizationId = _prefillOrganizationId;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _organizationSearchController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _conditionSearchController.dispose();
    super.dispose();
  }

  static const int _totalSteps = 7;

  bool get _isLight => Theme.of(context).brightness == Brightness.light;

  InputDecoration _onboardingFieldDecoration({String? labelText, String? hintText, IconData? prefixIcon, Widget? suffixIcon}) {
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
      suffixIcon: suffixIcon,
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

  Future<void> _goToStep(int step) async {
    if (step < 0 || step > _totalSteps - 1 || !mounted) return;
    await _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _nextStep() async {
    if (_isSaving) return; // Prevent double-submission
    
    if (_currentStep == 0) {
      // Require organization selection
      if (_selectedOrganizationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose your organization')),
        );
        return;
      }
      await _goToStep(_currentStep + 1);
    } else if (_currentStep == 1) {
      if (_formKey.currentState!.validate()) {
        await _goToStep(_currentStep + 1);
      }
    } else if (_currentStep == 2) {
      if (_selectedConditions.isNotEmpty) {
        await _goToStep(_currentStep + 1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select at least one condition')),
        );
      }
    } else if (_currentStep == 3) {
      // Condition details are optional
      await _goToStep(_currentStep + 1);
    } else if (_currentStep == 4) {
      // Medications are optional
      await _goToStep(_currentStep + 1);
    } else if (_currentStep == 5) {
      if (_diagnosisDate != null) {
        await _goToStep(_currentStep + 1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select your diagnosis date')),
        );
      }
    } else if (_currentStep == 6) {
      setState(() => _isSaving = true);
      try {
        await _completeOnboarding();
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  Future<void> _completeOnboarding() async {
    // Check if session is still valid
    var authUser = SupabaseConfig.auth.currentUser;
    
    // If no user, try to refresh the session
    if (authUser == null) {
      debugPrint('[Questionnaire] No active session, attempting to refresh...');
      try {
        await SupabaseConfig.auth.refreshSession();
        authUser = SupabaseConfig.auth.currentUser;
        debugPrint('[Questionnaire] Session refreshed successfully');
      } catch (e) {
        debugPrint('[Questionnaire] Session refresh failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Your session has expired. Please sign in again.'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Sign In',
                onPressed: () async {
                  try {
                    await SupabaseConfig.auth.signOut();
                  } catch (e) {
                    debugPrint('[Questionnaire] Sign out error: $e');
                  }
                  if (context.mounted) {
                    context.go('/auth');
                  }
                },
              ),
            ),
          );
        }
        return;
      }
    }
    
    // If still no user after refresh, session truly expired
    if (authUser == null) {
      debugPrint('[Questionnaire] Session expired, cannot complete onboarding');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Your session has expired. Please sign in again to continue.'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Sign In',
              onPressed: () async {
                try {
                  await SupabaseConfig.auth.signOut();
                } catch (e) {
                  debugPrint('[Questionnaire] Sign out error: $e');
                }
                if (context.mounted) {
                  context.go('/auth');
                }
              },
            ),
          ),
        );
      }
      return;
    }

    final uid = authUser.id;
    final email = authUser.email ?? _emailController.text;

    final user = User(
      id: uid,
      name: _nameController.text,
      email: email,
      onboardingCompleted: true,
      conditions: _selectedConditions,
      medications: List<Medication>.unmodifiable(_medications),
      diagnosisDate: _diagnosisDate,
      interests: _selectedInterests,
      preferences: {
        if (_selectedOrganizationId != null) 'organizationId': _selectedOrganizationId,
        if (_conditionDetails.isNotEmpty)
          'conditionDetails': {
            for (final e in _conditionDetails.entries)
              if (_selectedConditions.contains(e.key)) e.key: e.value.toJson(),
          },
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await _userService.completeOnboarding(user);
    } catch (e) {
      debugPrint('[Questionnaire] Error completing onboarding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving your profile: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }
    // If an organization was chosen, generate a patient code tied to it
    if (_selectedOrganizationId != null && _selectedOrganizationId!.isNotEmpty) {
      try {
        await _userService.ensurePatientCodeForCurrentUser(organizationId: _selectedOrganizationId!);
      } catch (e) {
        debugPrint('QuestionnaireScreen.ensurePatientCode error: $e');
      }
    }
    if (mounted) {
      // Reload from Firestore to ensure we reflect any server-side merges
      try {
        await context.read<UserProvider>().loadUser();
      } catch (e) {
        debugPrint('QuestionnaireScreen: failed to refresh user after onboarding: $e');
      }
      try {
        final org = _organizations.firstWhere((x) => x.id == _selectedOrganizationId);
        await context.read<ThemeProvider>().applyOrganization(org);
      } catch (_) {}
      context.go('/');
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
            if (_currentStep > 0) {
              _previousStep();
              return;
            }
            try {
              await context.read<UserProvider>().logout();
            } catch (e) {
              debugPrint('QuestionnaireScreen logout error: $e');
            }
            if (!context.mounted) return;
            context.go('/auth');
          },
        ),
        title: Text(
          'Tell us about you',
          style: context.textStyles.titleLarge?.semiBold?.withColor(titleColor),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: Icon(Icons.logout, color: titleColor),
            onPressed: () async {
              try {
                await context.read<UserProvider>().logout();
              } catch (e) {
                debugPrint('QuestionnaireScreen logout error: $e');
              }
              if (!context.mounted) return;
              context.go('/auth');
            },
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
                    _OnboardingTopBar(
                      currentStep: _currentStep,
                      totalSteps: _totalSteps,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ProgressBar(value: (_currentStep + 1) / _totalSteps),
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _totalSteps,
                        onPageChanged: (index) => setState(() => _currentStep = index),
                        itemBuilder: (context, index) {
                          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              final page = _pageController.hasClients ? (_pageController.page ?? _currentStep.toDouble()) : _currentStep.toDouble();
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
                              padding: EdgeInsets.fromLTRB(
                                0,
                                0,
                                0,
                                AppSpacing.lg + bottomInset,
                              ),
                              child: _buildStepContent(index),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          if (_currentStep > 0)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _previousStep,
                                icon: Icon(Icons.arrow_back, color: titleColor),
                                label: Text('Back', style: context.textStyles.labelLarge?.withColor(titleColor)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          if (_currentStep > 0) const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isSaving ? null : _nextStep,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Icon(
                                      _currentStep == _totalSteps - 1 ? Icons.check_circle_outline : Icons.arrow_forward,
                                      color: cs.onPrimary,
                                    ),
                              label: Text(
                                _currentStep == _totalSteps - 1 ? 'Complete' : 'Continue',
                                style: context.textStyles.labelLarge?.withColor(cs.onPrimary),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return _buildHospitalSelection();
      case 1:
        return _buildBasicInfo();
      case 2:
        return _buildConditionSelection();
      case 3:
        return _buildConditionDetails();
      case 4:
        return _buildMedications();
      case 5:
        return _buildDiagnosisDate();
      case 6:
        return _buildInterests();
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildMedications() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.medication_outlined, color: cs.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Any medications you take?',
                style: context.textStyles.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Optional — this helps reminders and care planning. You can edit this later in your profile.',
          style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_medications.isEmpty)
          _SelectableCard(
            title: 'Add your first medication',
            subtitle: 'Name, dosage, and times (optional)',
            selected: false,
            icon: Icons.add_circle_outline,
            onTap: () => _openMedicationEditor(),
          )
        else ...[
          ..._medications.map((m) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => _openMedicationEditor(existing: m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.medication_liquid_outlined, color: cs.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: context.textStyles.titleMedium?.semiBold),
                            if ((m.dosage ?? '').trim().isNotEmpty || m.times.isNotEmpty || (m.notes ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _medicationSubtitle(m),
                                style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      IconButton(
                        tooltip: 'Remove',
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        onPressed: () => setState(() => _medications.removeWhere((x) => x.id == m.id)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _openMedicationEditor,
            icon: Icon(Icons.add, color: cs.primary),
            label: const Text('Add another'),
            style: OutlinedButton.styleFrom(
              padding: AppSpacing.paddingMd,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
        ],
      ],
    );
  }

  String _medicationSubtitle(Medication m) {
    final parts = <String>[];
    final dosage = (m.dosage ?? '').trim();
    if (dosage.isNotEmpty) parts.add(dosage);
    if (m.times.isNotEmpty) parts.add(m.formattedTimes);
    final notes = (m.notes ?? '').trim();
    if (notes.isNotEmpty) parts.add(notes);
    return parts.join(' • ');
  }

  Future<void> _openMedicationEditor({Medication? existing}) async {
    final updated = await showModalBottomSheet<Medication>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MedicationEditorSheet(initial: existing),
    );

    if (!mounted || updated == null) return;
    setState(() {
      final idx = _medications.indexWhere((m) => m.id == updated.id);
      if (idx == -1) {
        _medications.add(updated);
      } else {
        _medications[idx] = updated;
      }
    });
  }

  Widget _buildHospitalSelection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Choose your organization (St. Louis area)',
                  style: context.textStyles.headlineSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'We’ll customize content based on your selected organization.',
            style: context.textStyles.bodyMedium?.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _organizationSearchController,
            onChanged: (v) => setState(() => _organizationQuery = v.trim()),
            textInputAction: TextInputAction.search,
            decoration: _onboardingFieldDecoration(
              hintText: 'Search St. Louis organizations',
              prefixIcon: Icons.search,
              suffixIcon: _organizationQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _organizationSearchController.clear();
                        setState(() => _organizationQuery = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loadingOrganizations)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Center(child: CenteredLoadingSkeleton()),
            )
          else ...[
            ..._visibleOrganizations.map((org) {
              final selected = _selectedOrganizationId == org.id;
              final subtitle = (org.settings?['city']?.toString().trim().isNotEmpty ?? false)
                  ? org.settings!['city'].toString().trim()
                  : (org.slug.isNotEmpty ? '@${org.slug}' : null);
              return _SelectableCard(
                key: ValueKey('org_${org.id}'),
                title: org.name,
                subtitle: subtitle,
                selected: selected,
                icon: Icons.business_outlined,
                onTap: () async {
                  setState(() => _selectedOrganizationId = org.id);
                  try {
                    await context.read<ThemeProvider>().applyOrganization(org);
                  } catch (e) {
                    debugPrint('Apply organization theme error: $e');
                  }
                },
              );
            }),
          ],
          if (!_loadingOrganizations && _visibleOrganizations.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.search_off, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'No organizations match your search.',
                      style: context.textStyles.bodyMedium?.withColor(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );

  Widget _buildBasicInfo() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            // Make header text wrap on small screens to avoid overflow
            Expanded(
              child: Text(
                'Let\'s start with the basics ✨',
                style: context.textStyles.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _nameController,
          decoration: _onboardingFieldDecoration(
            labelText: 'Nickname',
            hintText: 'What should we call you?',
            prefixIcon: Icons.person_outline,
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Please enter your nickname' : null,
        ),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _emailController,
          readOnly: true,
          enableInteractiveSelection: false,
          decoration: _onboardingFieldDecoration(
            labelText: 'Email (from your account)',
            hintText: 'We’ll use this for important updates',
            prefixIcon: Icons.email_outlined,
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Email is required';
            if (!value!.contains('@')) return 'Please enter a valid email';
            return null;
          },
        ),
      ],
    ),
  );

  Widget _buildConditionSelection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_outlined,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'What condition(s) are you managing?',
                  style: context.textStyles.headlineSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Select all that apply. This helps us personalize your experience.',
            style: context.textStyles.bodyMedium?.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Search bar
          TextField(
            controller: _conditionSearchController,
            onChanged: (value) => setState(() {
              _conditionQuery = value.trim();
            }),
            textInputAction: TextInputAction.search,
            decoration: _onboardingFieldDecoration(
              hintText: 'Search conditions',
              prefixIcon: Icons.search,
              suffixIcon: _conditionQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _conditionSearchController.clear();
                        setState(() => _conditionQuery = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._visibleConditions.map((c) {
            final selected = _selectedConditions.contains(c.id);
            return _SelectableCard(
              key: ValueKey('cond_${c.id}'),
              title: c.name,
              subtitle: c.description,
              selected: selected,
              icon: Icons.medication_liquid_outlined,
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedConditions.remove(c.id);
                  } else {
                    _selectedConditions.add(c.id);
                  }
                });
              },
            );
          }),
          if (_visibleConditions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.search_off, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'No conditions match your search.',
                      style: context.textStyles.bodyMedium?.withColor(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );

  Widget _buildConditionDetails() {
    final cs = Theme.of(context).colorScheme;
    final selected = _allConditions.where((c) => _selectedConditions.contains(c.id)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_outlined, color: cs.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Tell us more about your condition',
                style: context.textStyles.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Optional, but it helps ARIE personalize your milestones and goals. You can change this later in your profile.',
          style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (selected.isEmpty)
          Text(
            'Go back and pick a condition to add details.',
            style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
          )
        else
          ...selected.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey('cond_details_${c.id}'),
                  initiallyExpanded: selected.length == 1,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
                  leading: Icon(Icons.medical_information_outlined, color: cs.primary),
                  title: Text('My ${c.name} details',
                      style: context.textStyles.titleMedium?.semiBold),
                  subtitle: Text(
                    _conditionDetails.containsKey(c.id) ? 'Answers saved' : 'Tap to add details',
                    style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                  ),
                  children: [
                    ConditionDetailsForm(
                      condition: c,
                      initialDetail: _conditionDetails[c.id],
                      onChanged: (d) => _conditionDetails[c.id] = d,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDiagnosisDate() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'When were you diagnosed?',
                  style: context.textStyles.headlineSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'This helps us provide relevant timeline information.',
            style: context.textStyles.bodyMedium?.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SelectableCard(
            title: _diagnosisDate == null
                ? 'Select date'
                : '${_diagnosisDate!.month}/${_diagnosisDate!.day}/${_diagnosisDate!.year}',
            subtitle: _diagnosisDate == null
                ? 'Tap to choose your diagnosis date'
                : 'Tap to change the date',
            icon: Icons.event_outlined,
            selected: _diagnosisDate != null,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _diagnosisDate ?? DateTime.now(),
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _diagnosisDate = date);
              }
            },
          ),
        ],
      );

  Widget _buildInterests() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tag_outlined,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'What are your interests?',
                  style: context.textStyles.headlineSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Select topics you\'d like to see in your feed.',
            style: context.textStyles.bodyMedium?.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _interestOptions.map((interest) {
              final isSelected = _selectedInterests.contains(interest);
              return ChoiceChip(
                label: Text(interest),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedInterests.add(interest);
                    } else {
                      _selectedInterests.remove(interest);
                    }
                  });
                },
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              );
            }).toList(),
          ),
        ],
      );
}

// ========================= UI Components =========================

class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({required this.currentStep, required this.totalSteps});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final fg = isLight ? Colors.black : Colors.white;
    final subtle = fg.withValues(alpha: 0.7);
    final chipBg = isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.08);

    final steps = const [
      (Icons.business_outlined, 'Organization'),
      (Icons.person_outline, 'Basics'),
      (Icons.health_and_safety_outlined, 'Conditions'),
      (Icons.tune_outlined, 'Details'),
      (Icons.medication_outlined, 'Meds'),
      (Icons.calendar_month_outlined, 'Diagnosis'),
      (Icons.tag_outlined, 'Interests'),
    ];
    final (icon, label) = steps[currentStep];

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg.withValues(alpha: 0.85)),
              const SizedBox(width: 8),
              Text('Step ${currentStep + 1} of $totalSteps', style: context.textStyles.labelSmall?.withColor(fg.withValues(alpha: 0.85))),
            ],
          ),
        ),
        const Spacer(),
        Text(label, style: context.textStyles.labelSmall?.withColor(subtle)),
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: selected
                ? cs.primaryContainer.withValues(alpha: 0.55)
                : cs.surfaceContainerHighest.withValues(alpha: 0.6),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.6)
                  : cs.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.textStyles.titleMedium?.semiBold),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: selected
                    ? Icon(Icons.check_circle, color: cs.primary, key: const ValueKey('sel'))
                    : Icon(Icons.radio_button_unchecked, color: cs.outline, key: const ValueKey('unsel')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    final steps = const [
      (Icons.business_outlined, 'Organization'),
      (Icons.person_outline, 'Basics'),
      (Icons.health_and_safety_outlined, 'Conditions'),
      (Icons.tune_outlined, 'Details'),
      (Icons.medication_outlined, 'Meds'),
      (Icons.calendar_month_outlined, 'Diagnosis'),
      (Icons.tag_outlined, 'Interests'),
    ];
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // On very narrow layouts, show a compact header to avoid horizontal overflow.
        if (constraints.maxWidth < 420) {
          final icon = steps[current].$1;
          final label = steps[current].$2;
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, color: cs.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Step ${current + 1} of ${steps.length} · $label',
                  style: context.textStyles.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }

        // Default: full step pills with connectors.
        return Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              _StepPill(
                icon: steps[i].$1,
                label: steps[i].$2,
                active: i == current,
                done: i < current,
              ),
              if (i != steps.length - 1)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    height: 2,
                    decoration: BoxDecoration(
                      color: i < current
                          ? cs.primary
                          : cs.outline.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ]
          ],
        );
      },
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.done,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = active
        ? cs.primaryContainer.withValues(alpha: 0.8)
        : cs.surfaceContainerHighest.withValues(alpha: 0.7);
    final border = active || done
        ? cs.primary.withValues(alpha: 0.6)
        : cs.outline.withValues(alpha: 0.25);
    final fg = active ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_circle : icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(label, style: context.textStyles.labelLarge?.withColor(fg)),
        ],
      ),
    );
  }
}

// A lightweight, CanvasKit-safe progress bar to avoid web engine paint issues
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value; // 0..1

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 6,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MedicationEditorSheet extends StatefulWidget {
  const _MedicationEditorSheet({this.initial});

  final Medication? initial;

  @override
  State<_MedicationEditorSheet> createState() => _MedicationEditorSheetState();
}

class _MedicationEditorSheetState extends State<_MedicationEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _dosage;
  late final TextEditingController _notes;
  late List<TimeOfDay> _times;

  static const _presetMorning = TimeOfDay(hour: 8, minute: 0);
  static const _presetNoon = TimeOfDay(hour: 12, minute: 0);
  static const _presetNight = TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _dosage = TextEditingController(text: widget.initial?.dosage ?? '');
    _notes = TextEditingController(text: widget.initial?.notes ?? '');
    _times = _parseTimes(widget.initial?.times ?? const []);
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<TimeOfDay> _parseTimes(List<String> times) {
    final out = <TimeOfDay>[];
    for (final t in times) {
      final parts = t.split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) continue;
      out.add(TimeOfDay(hour: h, minute: m));
    }
    out.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    return out;
  }

  bool _hasTime(TimeOfDay time) => _times.any((t) => t.hour == time.hour && t.minute == time.minute);

  void _togglePreset(TimeOfDay time) {
    setState(() {
      if (_hasTime(time)) {
        _times.removeWhere((t) => t.hour == time.hour && t.minute == time.minute);
      } else {
        _times.add(time);
      }
      _times.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times.isNotEmpty ? _times.first : TimeOfDay.now(),
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (!_hasTime(picked)) {
        _times.add(picked);
        _times.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
      }
    });
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _timeLabel(TimeOfDay t) {
    if (t.hour == _presetMorning.hour && t.minute == _presetMorning.minute) return 'Morning';
    if (t.hour == _presetNoon.hour && t.minute == _presetNoon.minute) return 'Noon';
    if (t.hour == _presetNight.hour && t.minute == _presetNight.minute) return 'Night';
    return _formatTime(t);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a medication name')),
      );
      return;
    }

    final times = _times
        .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
        .toList()
      ..sort();

    final updated = Medication(
      id: widget.initial?.id ?? 'med_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      dosage: _dosage.text.trim().isEmpty ? null : _dosage.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      times: times,
    );

    context.pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
          ),
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.initial == null ? 'Add medication' : 'Edit medication',
                      style: context.textStyles.titleLarge?.semiBold,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Medication name',
                  prefixIcon: const Icon(Icons.medication_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _dosage,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Dosage (optional)',
                  prefixIcon: const Icon(Icons.straighten_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Times (optional)',
                style: context.textStyles.titleSmall?.withColor(cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _TimeChip(
                    label: 'Morning',
                    selected: _hasTime(_presetMorning),
                    onTap: () => _togglePreset(_presetMorning),
                  ),
                  _TimeChip(
                    label: 'Noon',
                    selected: _hasTime(_presetNoon),
                    onTap: () => _togglePreset(_presetNoon),
                  ),
                  _TimeChip(
                    label: 'Night',
                    selected: _hasTime(_presetNight),
                    onTap: () => _togglePreset(_presetNight),
                  ),
                  _TimeChip(
                    label: 'Pick time',
                    selected: false,
                    leading: Icons.add,
                    onTap: _pickTime,
                  ),
                ],
              ),
              if (_times.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _times
                      .map(
                        (t) => InputChip(
                          label: Text(_timeLabel(t)),
                          onDeleted: () => setState(() => _times.removeWhere((x) => x.hour == t.hour && x.minute == t.minute)),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Save'),
                style: FilledButton.styleFrom(
                  padding: AppSpacing.paddingMd,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected
        ? cs.primaryContainer.withValues(alpha: 0.75)
        : cs.surfaceContainerHighest.withValues(alpha: 0.6);
    final border = selected
        ? cs.primary.withValues(alpha: 0.55)
        : cs.outline.withValues(alpha: 0.25);
    final fg = selected ? cs.onPrimaryContainer : cs.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              Icon(leading, size: 18, color: cs.primary),
              const SizedBox(width: 8),
            ],
            Text(label, style: context.textStyles.labelLarge?.withColor(fg)),
          ],
        ),
      ),
    );
  }
}
