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
import 'package:wellspring/services/hospital_service.dart';
import 'package:wellspring/models/hospital.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/animated_blobs.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/models/onboarding_prefill.dart';

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
  final _hospitalService = HospitalService();
  OnboardingPrefill? _prefill;
  String? _prefillHospitalId;
  
  List<Condition> _allConditions = [];
  List<String> _selectedConditions = [];
  // Search state for conditions step
  final TextEditingController _conditionSearchController = TextEditingController();
  String _conditionQuery = '';
  DateTime? _diagnosisDate;
  final List<String> _selectedInterests = [];
  int _currentStep = 0;
  // Hospital selection state
  List<Hospital> _hospitals = [];
  String? _selectedHospitalId;
  final TextEditingController _hospitalSearchController = TextEditingController();
  String _hospitalQuery = '';

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
    _loadHospitals();
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

  List<Hospital> get _visibleHospitals {
    if (_hospitalQuery.isEmpty) return _hospitals;
    final q = _hospitalQuery.toLowerCase();
    return _hospitals
        .where((h) =>
            h.name.toLowerCase().contains(q) || (h.city ?? '').toLowerCase().contains(q))
        .toList();
  }

  Future<void> _loadHospitals() async {
    try {
      final list = await _hospitalService.getHospitalsByMetro('stl');
      setState(() => _hospitals = list);
      if ((_prefillHospitalId ?? '').isNotEmpty) {
        try {
          final h = list.firstWhere((x) => x.id == _prefillHospitalId);
          setState(() => _selectedHospitalId = h.id);
          await context.read<ThemeProvider>().applyHospital(h);
        } catch (e) {
          debugPrint('QuestionnaireScreen._loadHospitals apply prefill error: $e');
        }
      }
    } catch (e) {
      debugPrint('QuestionnaireScreen._loadHospitals error: $e');
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
    if ((_prefill!.hospitalId ?? '').isNotEmpty) {
      _prefillHospitalId = _prefill!.hospitalId;
      _selectedHospitalId = _prefillHospitalId;
    }
  }

  @override
  void dispose() {
    _hospitalSearchController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _conditionSearchController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Require hospital selection
      if (_selectedHospitalId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please choose your hospital')),
        );
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      if (_formKey.currentState!.validate()) {
        setState(() => _currentStep++);
      }
    } else if (_currentStep == 2) {
      if (_selectedConditions.isNotEmpty) {
        setState(() => _currentStep++);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select at least one condition')),
        );
      }
    } else if (_currentStep == 3) {
      if (_diagnosisDate != null) {
        setState(() => _currentStep++);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select your diagnosis date')),
        );
      }
    } else if (_currentStep == 4) {
      _completeOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _completeOnboarding() async {
    final authUser = SupabaseConfig.auth.currentUser;
    final uid = authUser?.id;
    final email = authUser?.email ?? _emailController.text;

    final user = User(
      id: uid ?? 'unknown',
      name: _nameController.text,
      email: email,
      onboardingCompleted: true,
      conditions: _selectedConditions,
      diagnosisDate: _diagnosisDate,
      interests: _selectedInterests,
      preferences: {
        if (_selectedHospitalId != null) 'hospitalId': _selectedHospitalId,
      },
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _userService.completeOnboarding(user);
    // If a hospital was chosen, generate a patient code tied to it
    if (_selectedHospitalId != null && _selectedHospitalId!.isNotEmpty) {
      try {
        await _userService.ensurePatientCodeForCurrentUser(hospitalId: _selectedHospitalId!);
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
        final h = _hospitals.firstWhere((x) => x.id == _selectedHospitalId);
        await context.read<ThemeProvider>().applyHospital(h);
      } catch (_) {}
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: cs.surface.withValues(alpha: 0.65),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousStep,
              )
            : TextButton.icon(
                onPressed: () async {
                  try {
                    await context.read<UserProvider>().logout();
                  } catch (e) {
                    debugPrint('QuestionnaireScreen logout error: $e');
                  }
                  if (!context.mounted) return;
                  context.go('/auth');
                },
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Sign in'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
              ),
        title: const Text('Tell us about you'),
        actions: [
          IconButton(
            tooltip: 'Back to login',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Sign out first so /auth does not redirect to home
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AnimatedBlobs(),
          Column(
            children: [
              // Progress bar with stable CanvasKit-friendly implementation
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: AppSpacing.horizontalLg,
                  child: _ProgressBar(value: (_currentStep + 1) / 5),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: AppSpacing.paddingLg,
                      child: _CardSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _StepHeader(current: _currentStep),
                            const SizedBox(height: AppSpacing.lg),
                            // Constrain the animated step content so it can scroll
                            // without causing Column overflows on smaller screens.
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, anim) => SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.05, 0),
                                    end: Offset.zero,
                                  ).animate(anim),
                                  child: FadeTransition(opacity: anim, child: child),
                                ),
                                child: KeyedSubtree(
                                  key: ValueKey(_currentStep),
                                  child: Builder(
                                    builder: (context) {
                                      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
                                      return SingleChildScrollView(
                                        padding: EdgeInsets.fromLTRB(
                                          AppSpacing.lg,
                                          AppSpacing.lg,
                                          AppSpacing.lg,
                                          AppSpacing.lg + bottomInset,
                                        ),
                                        child: _buildStepContent(),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            SafeArea(
                              top: false,
                              child: Row(
                                children: [
                                  if (_currentStep > 0)
                                    OutlinedButton.icon(
                                      onPressed: _previousStep,
                                      icon: Icon(Icons.arrow_back, color: cs.primary),
                                      label: const Text('Back'),
                                      style: OutlinedButton.styleFrom(
                                        padding: AppSpacing.paddingMd,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  FilledButton(
                                    onPressed: _nextStep,
                                    style: FilledButton.styleFrom(
                                      padding: AppSpacing.paddingMd,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                      ),
                                    ),
                                    child: Text(
                                      _currentStep == 4 ? 'Complete' : 'Continue',
                                      style: context.textStyles.titleMedium?.semiBold,
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildHospitalSelection();
      case 1:
        return _buildBasicInfo();
      case 2:
        return _buildConditionSelection();
      case 3:
        return _buildDiagnosisDate();
      case 4:
        return _buildInterests();
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildHospitalSelection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_hospital_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Choose your hospital (St. Louis area)',
                  style: context.textStyles.headlineSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'We’ll customize colors and content for your selected hospital.',
            style: context.textStyles.bodyMedium?.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _hospitalSearchController,
            onChanged: (v) => setState(() => _hospitalQuery = v.trim()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search St. Louis hospitals',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _hospitalQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _hospitalSearchController.clear();
                        setState(() => _hospitalQuery = '');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._visibleHospitals.map((h) {
            final selected = _selectedHospitalId == h.id;
            return _SelectableCard(
              key: ValueKey('hospital_${h.id}'),
              title: h.name,
              subtitle: h.city,
              selected: selected,
              icon: Icons.local_hospital_outlined,
              onTap: () async {
                setState(() => _selectedHospitalId = h.id);
                try {
                  await context.read<ThemeProvider>().applyHospital(h);
                } catch (e) {
                  debugPrint('Apply hospital theme error: $e');
                }
              },
            );
          }),
          if (_visibleHospitals.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.search_off, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'No hospitals match your search.',
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
          decoration: InputDecoration(
            labelText: 'Nickname',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Please enter your nickname' : null,
        ),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _emailController,
          readOnly: true,
          enableInteractiveSelection: false,
          decoration: InputDecoration(
            labelText: 'Email (from your account)',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
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
            decoration: InputDecoration(
              hintText: 'Search conditions',
              prefixIcon: const Icon(Icons.search),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              isDense: true,
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

class _CardSurface extends StatelessWidget {
  const _CardSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: child,
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
      (Icons.local_hospital_outlined, 'Hospital'),
      (Icons.person_outline, 'Basics'),
      (Icons.health_and_safety_outlined, 'Conditions'),
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
