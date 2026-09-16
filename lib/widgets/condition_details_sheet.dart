import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/models/condition_detail.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/condition_details_form.dart';

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
  late ConditionDetail _detail;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _detail = widget.existingDetail ?? ConditionDetail(conditionId: widget.condition.id);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final detail = _detail;
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
              Expanded(
                child: ListView(
                  controller: scrollCtl,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  children: [
                    ConditionDetailsForm(
                      condition: widget.condition,
                      initialDetail: widget.existingDetail,
                      onChanged: (d) => _detail = d,
                    ),
                  ],
                ),
              ),
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
