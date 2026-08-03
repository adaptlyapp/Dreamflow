import 'package:flutter/material.dart';

/// Lightweight pulsing block used as a skeleton placeholder.
class _PulseBlock extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  const _PulseBlock({required this.width, required this.height, required this.borderRadius});

  @override
  State<_PulseBlock> createState() => _PulseBlockState();
}

class _PulseBlockState extends State<_PulseBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surface;
    final onSurface = cs.onSurface;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Tween<double>(begin: 0.06, end: 0.12).transform(_c.value);
        final color = Color.alphaBlend(onSurface.withValues(alpha: t), base);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(color: color, borderRadius: widget.borderRadius),
        );
      },
    );
  }
}

/// Full-screen, generic loading skeleton used to avoid spinners between navigations.
class CenteredLoadingSkeleton extends StatelessWidget {
  final EdgeInsets padding;
  const CenteredLoadingSkeleton({super.key, this.padding = const EdgeInsets.symmetric(horizontal: 20)});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final maxW = width > 600 ? 560.0 : width - padding.horizontal;
    return Padding(
      padding: padding.copyWith(top: 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title line
            _PulseBlock(width: maxW * 0.5, height: 24, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 16),
            // Subtitle lines
            _PulseBlock(width: maxW * 0.9, height: 14, borderRadius: BorderRadius.circular(6)),
            const SizedBox(height: 10),
            _PulseBlock(width: maxW * 0.7, height: 14, borderRadius: BorderRadius.circular(6)),
            const SizedBox(height: 24),
            // Card placeholders
            for (int i = 0; i < 3; i++) ...[
              _PulseBlock(width: maxW, height: 88, borderRadius: BorderRadius.circular(14)),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small inline loader for compact areas (e.g., inside list tiles).
class InlineLoadingDot extends StatefulWidget {
  const InlineLoadingDot({super.key});
  @override
  State<InlineLoadingDot> createState() => _InlineLoadingDotState();
}

class _InlineLoadingDotState extends State<InlineLoadingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.onSurface;
    return FadeTransition(
      opacity: CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      child: Container(width: 12, height: 12, decoration: BoxDecoration(color: base.withValues(alpha: 0.6), shape: BoxShape.circle)),
    );
  }
}
