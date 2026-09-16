import 'package:flutter/material.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/models/condition_detail.dart';
import 'package:wellspring/theme.dart';

/// Reusable form for capturing condition-specific details (injury level,
/// sub-type, mobility, functional abilities, challenges, notes).
///
/// Used both by [ConditionDetailsSheet] and the onboarding questionnaire.
/// The widget is layout-agnostic (a plain [Column]) so it can be embedded
/// inside any scrollable.
class ConditionDetailsForm extends StatefulWidget {
  const ConditionDetailsForm({
    super.key,
    required this.condition,
    this.initialDetail,
    required this.onChanged,
    this.showNotes = true,
  });

  /// The condition these details belong to.
  final Condition condition;

  /// Existing details to prefill the form with.
  final ConditionDetail? initialDetail;

  /// Called whenever any field changes with the up-to-date detail object.
  final ValueChanged<ConditionDetail> onChanged;

  /// Whether to show the free-form notes field.
  final bool showNotes;

  @override
  State<ConditionDetailsForm> createState() => _ConditionDetailsFormState();
}

class _ConditionDetailsFormState extends State<ConditionDetailsForm> {
  String? _injuryLevel;
  String? _subType;
  String? _mobilityStatus;
  String? _upperExtremityFunction;
  String? _lowerExtremityFunction;
  bool _requiresAssistance = false;
  late Set<String> _assistiveDevices;
  late Set<String> _functionalAbilities;
  late Set<String> _challenges;
  late TextEditingController _notesCtl;

  static const List<String> upperBodyOptions = [
    'Full function',
    'Limited grip strength',
    'Limited range of motion',
    'Minimal hand function',
    'No hand function',
  ];

  static const List<String> lowerBodyOptions = [
    'Full function',
    'Can stand briefly',
    'Limited movement',
    'Minimal movement',
    'No movement',
  ];

  static const List<String> injuryLevels = [
    'C1-C4',
    'C5-C6',
    'C7-C8',
    'T1-T6',
    'T7-T12',
    'L1-L5',
    'S1-S5',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.initialDetail;
    _injuryLevel = existing?.injuryLevel;
    _subType = existing?.subType;
    _mobilityStatus = existing?.mobilityStatus;
    _upperExtremityFunction = existing?.upperExtremityFunction;
    _lowerExtremityFunction = existing?.lowerExtremityFunction;
    _requiresAssistance = existing?.requiresAssistance ?? false;
    _assistiveDevices = Set.from(existing?.assistiveDevices ?? const []);
    _functionalAbilities = Set.from(existing?.functionalAbilities ?? const []);
    _challenges = Set.from(existing?.challenges ?? const []);
    _notesCtl = TextEditingController(text: existing?.additionalNotes ?? '');
    _notesCtl.addListener(_emit);
  }

  @override
  void dispose() {
    _notesCtl.dispose();
    super.dispose();
  }

  ConditionDetail get currentDetail => ConditionDetail(
        conditionId: widget.condition.id,
        injuryLevel: _injuryLevel,
        subType: _subType,
        mobilityStatus: _mobilityStatus,
        upperExtremityFunction: _upperExtremityFunction,
        lowerExtremityFunction: _lowerExtremityFunction,
        requiresAssistance: _requiresAssistance,
        assistiveDevices: _assistiveDevices.toList(),
        functionalAbilities: _functionalAbilities.toList(),
        challenges: _challenges.toList(),
        additionalNotes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      );

  void _emit() => widget.onChanged(currentDetail);

  void _update(VoidCallback fn) {
    setState(fn);
    _emit();
  }

  bool get _isSpinalCordInjury {
    final name = widget.condition.name.toLowerCase();
    return name.contains('spinal cord') || name.contains('sci') || name.contains('paralysis');
  }

  bool get _isDiabetes => widget.condition.name.toLowerCase().contains('diabetes');

  bool get _isMS {
    final name = widget.condition.name.toLowerCase();
    return name.contains('multiple sclerosis') || name == 'ms';
  }

  bool get _isArthritis => widget.condition.name.toLowerCase().contains('arthritis');

  List<String> get _subTypeOptions {
    if (_isDiabetes) return ConditionSubTypes.diabetes;
    if (_isMS) return ConditionSubTypes.ms;
    if (_isArthritis) return ConditionSubTypes.arthritis;
    if (_isSpinalCordInjury) return ConditionSubTypes.sci;
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isSpinalCordInjury) ...[
          const ConditionDetailsSectionHeader(title: 'Injury Level', icon: Icons.accessibility_new),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: injuryLevels
                .map((level) => ChoiceChip(
                      label: Text(level),
                      selected: _injuryLevel == level,
                      onSelected: (v) => _update(() => _injuryLevel = v ? level : null),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_subTypeOptions.isNotEmpty) ...[
          ConditionDetailsSectionHeader(
            title: _isDiabetes
                ? 'Diabetes Type'
                : _isMS
                    ? 'MS Type'
                    : _isArthritis
                        ? 'Arthritis Type'
                        : 'Type',
            icon: Icons.category,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _subTypeOptions
                .map((type) => ChoiceChip(
                      label: Text(type),
                      selected: _subType == type,
                      onSelected: (v) => _update(() => _subType = v ? type : null),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        const ConditionDetailsSectionHeader(title: 'Mobility', icon: Icons.directions_walk),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MobilityOptions.all
              .map((option) => ChoiceChip(
                    label: Text(option),
                    selected: _mobilityStatus == option,
                    onSelected: (v) => _update(() => _mobilityStatus = v ? option : null),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const ConditionDetailsSectionHeader(title: 'Upper Body Function', icon: Icons.pan_tool),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: upperBodyOptions
              .map((option) => ChoiceChip(
                    label: Text(option),
                    selected: _upperExtremityFunction == option,
                    onSelected: (v) => _update(() => _upperExtremityFunction = v ? option : null),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const ConditionDetailsSectionHeader(
            title: 'Lower Body Function', icon: Icons.airline_seat_legroom_normal),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: lowerBodyOptions
              .map((option) => ChoiceChip(
                    label: Text(option),
                    selected: _lowerExtremityFunction == option,
                    onSelected: (v) => _update(() => _lowerExtremityFunction = v ? option : null),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const ConditionDetailsSectionHeader(
            title: 'Assistive Devices I Use', icon: Icons.accessibility),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AssistiveDeviceOptions.all
              .map((device) => FilterChip(
                    label: Text(device),
                    selected: _assistiveDevices.contains(device),
                    onSelected: (v) => _update(() {
                      if (v) {
                        _assistiveDevices.add(device);
                      } else {
                        _assistiveDevices.remove(device);
                      }
                    }),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const ConditionDetailsSectionHeader(title: 'What I Can Do', icon: Icons.check_circle_outline),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FunctionalAbilityOptions.all
              .map((ability) => FilterChip(
                    label: Text(ability),
                    selected: _functionalAbilities.contains(ability),
                    onSelected: (v) => _update(() {
                      if (v) {
                        _functionalAbilities.add(ability);
                      } else {
                        _functionalAbilities.remove(ability);
                      }
                    }),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const ConditionDetailsSectionHeader(
            title: 'My Challenges', icon: Icons.warning_amber_outlined),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ChallengeOptions.all
              .map((challenge) => FilterChip(
                    label: Text(challenge),
                    selected: _challenges.contains(challenge),
                    onSelected: (v) => _update(() {
                      if (v) {
                        _challenges.add(challenge);
                      } else {
                        _challenges.remove(challenge);
                      }
                    }),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        SwitchListTile(
          value: _requiresAssistance,
          onChanged: (v) => _update(() => _requiresAssistance = v),
          title: const Text('I require daily assistance'),
          subtitle: const Text('From a caregiver, family member, or aide'),
          contentPadding: EdgeInsets.zero,
        ),
        if (widget.showNotes) ...[
          const SizedBox(height: AppSpacing.md),
          const ConditionDetailsSectionHeader(title: 'Additional Notes', icon: Icons.notes),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _notesCtl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Anything else the AI should know when creating your milestones...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
        ],
      ],
    );
  }
}

/// Small labelled section header used inside condition detail forms.
class ConditionDetailsSectionHeader extends StatelessWidget {
  const ConditionDetailsSectionHeader({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: context.textStyles.titleMedium?.semiBold)),
      ],
    );
  }
}
