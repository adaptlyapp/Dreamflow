import 'package:flutter/material.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/glass_card.dart';
import 'package:wellspring/widgets/help_type_chip.dart';

/// Summary card that shows the AI's "Goal Breakdown" reasoning above the
/// milestones list in the plan editor.
///
/// Data shape (as returned by [OpenAIClient.generatePlanBreakdown]):
/// ```
/// {
///   "goalSummary": "…",
///   "complexityLevel": "low|medium|high",
///   "needCategories": [ { "type": "expert", "reason": "…" }, … ]
/// }
/// ```
class GoalBreakdownCard extends StatelessWidget {
  final String goalSummary;
  final String complexityLevel; // "low" | "medium" | "high" | ""
  final List<Map<String, String>> needCategories;
  final VoidCallback? onDismiss;

  const GoalBreakdownCard({
    super.key,
    required this.goalSummary,
    required this.complexityLevel,
    required this.needCategories,
    this.onDismiss,
  });

  Color _complexityColor(BuildContext context) {
    switch (complexityLevel) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAny = goalSummary.trim().isNotEmpty || needCategories.isNotEmpty;
    if (!hasAny) return const SizedBox.shrink();

    return GlassCard(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Goal breakdown', style: context.textStyles.titleSmall?.semiBold),
              ),
              if (complexityLevel.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: _complexityColor(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${complexityLevel[0].toUpperCase()}${complexityLevel.substring(1)} complexity',
                    style: context.textStyles.labelSmall?.withColor(_complexityColor(context)),
                  ),
                ),
              if (onDismiss != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDismiss,
                  tooltip: 'Dismiss',
                ),
            ]),
            if (goalSummary.trim().isNotEmpty) ...[
              SizedBox(height: AppSpacing.xs),
              Text(goalSummary.trim(), style: context.textStyles.bodyMedium),
            ],
            if (needCategories.isNotEmpty) ...[
              SizedBox(height: AppSpacing.sm),
              Text('Kinds of help this goal needs',
                  style: context.textStyles.labelMedium?.withColor(theme.colorScheme.onSurfaceVariant)),
              SizedBox(height: AppSpacing.xs),
              ...needCategories.map((c) => _CategoryTile(
                    type: c['type'] ?? '',
                    reason: c['reason'] ?? '',
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String type;
  final String reason;
  const _CategoryTile({required this.type, required this.reason});

  @override
  Widget build(BuildContext context) {
    if (type.isEmpty) return const SizedBox.shrink();
    final style = helpTypeStyle(type);
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(style.icon, color: style.color, size: 16),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(style.label, style: context.textStyles.labelLarge?.semiBold),
                if (reason.trim().isNotEmpty)
                  Text(
                    reason.trim(),
                    style: context.textStyles.bodySmall
                        ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
