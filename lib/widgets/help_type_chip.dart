import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wellspring/services/commerce_service.dart';
import 'package:wellspring/theme.dart';

/// Canonical values coming from the Goal Breakdown Engine:
/// expert | product | community | learning | action | tracking | environment
class HelpTypeStyle {
  final IconData icon;
  final Color color;
  final String label;
  final String actionLabel;
  final String helpText;
  const HelpTypeStyle({
    required this.icon,
    required this.color,
    required this.label,
    required this.actionLabel,
    required this.helpText,
  });
}

HelpTypeStyle helpTypeStyle(String t) {
  switch (t.trim().toLowerCase()) {
    case 'expert':
      return const HelpTypeStyle(
        icon: Icons.medical_services_outlined,
        color: Colors.indigo,
        label: 'Expert',
        actionLabel: 'Find providers',
        helpText: 'A professional can help with this step.',
      );
    case 'product':
      return const HelpTypeStyle(
        icon: Icons.shopping_bag_outlined,
        color: Colors.orange,
        label: 'Product',
        actionLabel: 'Shop ideas',
        helpText: 'A tool or supply makes this step easier.',
      );
    case 'community':
      return const HelpTypeStyle(
        icon: Icons.groups_outlined,
        color: Colors.pink,
        label: 'Community',
        actionLabel: 'Find community',
        helpText: 'People who\'ve done this before can help.',
      );
    case 'learning':
      return const HelpTypeStyle(
        icon: Icons.school_outlined,
        color: Colors.blue,
        label: 'Learn',
        actionLabel: 'Learn more',
        helpText: 'Understand the concept before acting.',
      );
    case 'tracking':
      return const HelpTypeStyle(
        icon: Icons.insights_outlined,
        color: Colors.teal,
        label: 'Track',
        actionLabel: 'Log in tracker',
        helpText: 'Measure this so you know if it\'s working.',
      );
    case 'environment':
      return const HelpTypeStyle(
        icon: Icons.home_outlined,
        color: Colors.brown,
        label: 'Environment',
        actionLabel: 'Setup ideas',
        helpText: 'Adjust your space or routine to make this easier.',
      );
    case 'action':
    default:
      return const HelpTypeStyle(
        icon: Icons.play_arrow_rounded,
        color: Colors.green,
        label: 'Action',
        actionLabel: 'Do it now',
        helpText: 'A concrete practice you complete.',
      );
  }
}

/// Small colored badge showing which "kind of help" a milestone represents.
class HelpTypeChip extends StatelessWidget {
  final String helpType;
  final bool compact;
  const HelpTypeChip({super.key, required this.helpType, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final s = helpTypeStyle(helpType);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: s.color.withValues(alpha: isDark ? 0.5 : 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: compact ? 11 : 12, color: s.color),
          const SizedBox(width: 4),
          Text(
            s.label,
            style: context.textStyles.labelSmall?.copyWith(
              color: s.color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Phase D: Smart CTA that routes the user to the right place based on
/// the milestone's helpType. Falls back gracefully if helpType is empty.
class HelpTypeActionButton extends StatelessWidget {
  final String? helpType;
  final String milestoneTitle;
  final String? milestoneDescription;
  final String? conditionName;
  /// Called when the helpType maps to "learning" and no external route fits —
  /// callers usually pass their existing "Learn more" opener here.
  final VoidCallback? onLearn;
  final bool outlined;

  const HelpTypeActionButton({
    super.key,
    required this.helpType,
    required this.milestoneTitle,
    this.milestoneDescription,
    this.conditionName,
    this.onLearn,
    this.outlined = true,
  });

  Future<void> _handleTap(BuildContext context) async {
    final t = (helpType ?? '').trim().toLowerCase();
    debugPrint('[HelpTypeAction] tap helpType="$t" title="$milestoneTitle"');
    try {
      switch (t) {
        case 'expert':
          context.push('/resources');
          return;
        case 'community':
          context.push('/communities');
          return;
        case 'tracking':
          context.push('/tracker/add');
          return;
        case 'product':
          final q = _productQuery();
          final url = CommerceService().amazonSearchUrl(q);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
          return;
        case 'environment':
        case 'learning':
        case 'action':
        default:
          if (onLearn != null) {
            onLearn!();
          } else {
            context.push('/resources');
          }
          return;
      }
    } catch (e) {
      debugPrint('[HelpTypeAction] error: $e');
    }
  }

  String _productQuery() {
    final base = milestoneTitle.trim();
    final cond = (conditionName ?? '').trim();
    if (cond.isNotEmpty) return '$cond $base';
    return base.isEmpty ? 'adaptive equipment' : base;
  }

  @override
  Widget build(BuildContext context) {
    final s = helpTypeStyle(helpType ?? '');
    final label = s.actionLabel;
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: () => _handleTap(context),
        icon: Icon(s.icon, size: 18, color: s.color),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: s.color,
          side: BorderSide(color: s.color.withValues(alpha: 0.5)),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: () => _handleTap(context),
      icon: Icon(s.icon, size: 18, color: Colors.white),
      label: Text(label),
      style: FilledButton.styleFrom(backgroundColor: s.color, foregroundColor: Colors.white),
    );
  }
}
