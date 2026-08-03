import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/models/condition_detail.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/theme.dart';

/// A bottom sheet for editing condition-specific details like injury level,
/// sub-type, mobility, and functional abilities.
class ConditionDetailsSheet extends StatefulWidget {
  final Condition condition;
  final ConditionDetail? existingDetail;

  const ConditionDetailsSheet({
    super.key,
    required this.condition,
    this.existingDetail,
  });

  @override
  State<ConditionDetailsSheet> createState() => _ConditionDetailsSheetState();
}

class _ConditionDetailsSheetState extends State<ConditionDetailsSheet> {
  late String? _injuryLevel;
  late String? _subType;
  late String? _mobilityStatus;
  late String? _upperExtremityFunction;
  late String? _lowerExtremityFunction;
  late bool _requiresAssistance;
  late Set<String> _assistiveDevices;
  late Set<String> _functionalAbilities;
  late Set<String> _challenges;
  late TextEditingController _notesCtl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingDetail;
    _injuryLevel = existing?.injuryLevel;
    _subType = existing?.subType;
    _mobilityStatus = existing?.mobilityStatus;
    _upperExtremityFunction = existing?.upperExtremityFunction;
    _lowerExtremityFunction = existing?.lowerExtremityFunction;
    _requiresAssistance = existing?.requiresAssistance ?? false;
    _assistiveDevices = Set.from(existing?.assistiveDevices ?? []);
    _functionalAbilities = Set.from(existing?.functionalAbilities ?? []);
    _challenges = Set.from(existing?.challenges ?? []);
    _notesCtl = TextEditingController(text: existing?.additionalNotes ?? '');
  }

  @override
  void dispose() {
    _notesCtl.dispose();
    super.dispose();
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
    return [];
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final detail = ConditionDetail(
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

      final userProv = context.read<UserProvider>();
      final user = userProv.currentUser;
      if (user == null) throw Exception('Not signed in');

      // Store in user preferences under conditionDetails map
      final prefs = Map<String, dynamic>.from(user.preferences);
      final detailsMap = Map<String, dynamic>.from(
        (prefs['conditionDetails'] as Map<String, dynamic>?) ?? {},
      );
      detailsMap[widget.condition.id] = detail.toJson();
      prefs['conditionDetails'] = detailsMap;

      await userProv.updateUser(user.copyWith(preferences: prefs));

      if (mounted) {
        Navigator.of(context).pop(detail);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Condition details saved')),
        );
      }
    } catch (e) {
      debugPrint('ConditionDetailsSheet save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtl) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: EdgeInsets.only(top: AppSpacing.md),
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: AppSpacing.paddingMd,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My ${widget.condition.name} Details',
                            style: context.textStyles.titleLarge?.semiBold,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Help AI personalize your milestones and goals',
                            style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollCtl,
                  padding: AppSpacing.paddingMd,
                  children: [
                    // Injury level for SCI
                    if (_isSpinalCordInjury) ...[
                      _SectionHeader(title: 'Injury Level', icon: Icons.accessibility_new),
                      SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...['C1-C4', 'C5-C6', 'C7-C8', 'T1-T6', 'T7-T12', 'L1-L5', 'S1-S5'].map(
                            (level) => ChoiceChip(
                              label: Text(level),
                              selected: _injuryLevel == level,
                              onSelected: (v) => setState(() => _injuryLevel = v ? level : null),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.sm),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Specific level (optional)',
                          hintText: 'e.g., C4-C5 incomplete',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                        onChanged: (v) => _injuryLevel = v.trim().isEmpty ? _injuryLevel : v.trim(),
                      ),
                      SizedBox(height: AppSpacing.lg),
                    ],

                    // Sub-type for diabetes, MS, etc.
                    if (_subTypeOptions.isNotEmpty) ...[
                      _SectionHeader(
                        title: _isDiabetes ? 'Diabetes Type' : _isMS ? 'MS Type' : _isArthritis ? 'Arthritis Type' : 'Type',
                        icon: Icons.category,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _subTypeOptions.map(
                          (type) => ChoiceChip(
                            label: Text(type),
                            selected: _subType == type,
                            onSelected: (v) => setState(() => _subType = v ? type : null),
                          ),
                        ).toList(),
                      ),
                      SizedBox(height: AppSpacing.lg),
                    ],

                    // Mobility
                    _SectionHeader(title: 'Mobility', icon: Icons.directions_walk),
                    SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: MobilityOptions.all.map(
                        (option) => ChoiceChip(
                          label: Text(option),
                          selected: _mobilityStatus == option,
                          onSelected: (v) => setState(() => _mobilityStatus = v ? option : null),
                        ),
                      ).toList(),
                    ),
                    SizedBox(height: AppSpacing.lg),

                    // Upper extremity function
                    _SectionHeader(title: 'Upper Body Function', icon: Icons.pan_tool),
                    SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Full function',
                        'Limited grip strength',
                        'Limited range of motion',
                        'Minimal hand function',
                        'No hand function',
                      ].map(
                        (option) => ChoiceChip(
                          label: Text(option),
                          selected: _upperExtremityFunction == option,
                          onSelected: (v) => setState(() => _upperExtremityFunction = v ? option : null),
                        ),
                      ).toList(),
                    ),
                    SizedBox(height: AppSpacing.lg),

                    // Lower extremity function
                    _SectionHeader(title: 'Lower Body Function', icon: Icons.airline_seat_legroom_normal),
                    SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Full function',
                        'Can stand briefly',
                        'Limited movement',
                        'Minimal movement',
                        'No movement',
                      ].map(
                        (option) => ChoiceChip(
                          label: Text(option),
                          selected: _lowerExtremityFunction == option,
                          onSelected: (v) => setState(() => _lowerExtremityFunction = v ? option : null),
                        ),
                      ).toList(),
                    ),
                    SizedBox(height: AppSpacing.lg),

                    // Assistive devices
                    _SectionHeader(title: 'Assistive Devices I Use', icon: Icons.accessibility),
                    SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AssistiveDeviceOptions.all.map(
                        (device) => FilterChip(
                          label: Text(device),
                          selected: _assistiveDevices.contains(device),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _assistiveDevices.add(device);
                              } else {
                                _assistiveDevices.remove(device);
                              }
                            });
                          },
                        ),
                      ).toList(),
                    ),
                    SizedBox(height: AppSpacing.lg),

                    // Functional abilities
                    _SectionHeader(title: 'What I Can Do', icon: Icons.check_circle_outline),
                    SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: FunctionalAbilityOptions.all.map(
                        (ability) => FilterChip(
                          label: Text(ability),
                          selected: _functionalAbilities.contains(ability),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _functionalAbilities.add(ability);
                              } else {
                                _functionalAbilities.remove(ability);
                              }
                            });
                          },
                        ),
                      ).toList(),
                    ),
                    SizedBox(height: AppSpacing.lg),

                    // Challenges
                    _SectionHeader(title: 'My Challenges', icon: Icons.warning_amber_outlined),
                    SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ChallengeOptions.all.map(
                        (challenge) => FilterChip(
                          label: Text(challenge),
                          selected: _challenges.contains(challenge),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _challenges.add(challenge);
                              } else {
                                _challenges.remove(challenge);
                              }
                            });
                          },
                        ),
                      ).toList(),
                    ),
                    SizedBox(height: AppSpacing.lg),

                    // Requires assistance
                    SwitchListTile(
                      value: _requiresAssistance,
                      onChanged: (v) => setState(() => _requiresAssistance = v),
                      title: const Text('I require daily assistance'),
                      subtitle: const Text('From a caregiver, family member, or aide'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SizedBox(height: AppSpacing.md),

                    // Additional notes
                    _SectionHeader(title: 'Additional Notes', icon: Icons.notes),
                    SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _notesCtl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Anything else the AI should know when creating your milestones...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                    ),
                    SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
              // Save button
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                              ),
                            )
                          : Icon(Icons.save, color: cs.onPrimary),
                      label: Text(_saving ? 'Saving...' : 'Save Details'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        SizedBox(width: 8),
        Text(title, style: context.textStyles.titleMedium?.semiBold),
      ],
    );
  }
}
