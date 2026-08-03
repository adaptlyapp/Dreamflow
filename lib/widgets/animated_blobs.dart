import 'dart:ui';

import 'package:flutter/material.dart';

/// Animated background with soft floating gradient blobs.
///
/// Lightweight and dependency-free. Uses three animated Positioned containers
/// with subtle movement to create a lively, modern backdrop.
class AnimatedBlobs extends StatefulWidget {
  const AnimatedBlobs({super.key});

  @override
  State<AnimatedBlobs> createState() => _AnimatedBlobsState();
}

class _AnimatedBlobsState extends State<AnimatedBlobs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _a1;
  late final Animation<double> _a2;
  late final Animation<double> _a3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );

    // Three phase-shifted animations for organic motion
    _a1 = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _a2 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
    );
    _a3 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1.0, curve: Curves.easeInOut),
    );
    // Defer start to after first frame so we can respect MediaQuery reduce motion
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateAnimationState());
  }

  void _updateAnimationState() {
    try {
      final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion) {
        if (_controller.isAnimating) _controller.stop();
      } else {
        if (!_controller.isAnimating) _controller.repeat(reverse: true);
      }
    } catch (_) {
      // If MediaQuery isn't available yet, ignore
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimationState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withValues(alpha: 0.20),
                  cs.tertiary.withValues(alpha: 0.12),
                ],
              ),
            ),
          ),

          // Floating blobs
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return Stack(children: [
                _blob(
                  alignment: Alignment(
                    lerp(-0.9, 0.6, _a1.value),
                    lerp(-1.0, -0.2, _a2.value),
                  ),
                  size: 260,
                  colors: [cs.primary, cs.primaryContainer],
                ),
                _blob(
                  alignment: Alignment(
                    lerp(0.8, -0.4, _a2.value),
                    lerp(0.9, 0.2, _a3.value),
                  ),
                  size: 220,
                  colors: [cs.tertiary, cs.primary],
                ),
                _blob(
                  alignment: Alignment(
                    lerp(-0.3, 0.2, _a3.value),
                    lerp(0.3, -0.3, _a1.value),
                  ),
                  size: 180,
                  colors: [cs.secondary, cs.tertiary],
                ),
              ]);
            },
          ),

          // Soft overlay to keep contrast readable
          Container(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _blob({required Alignment alignment, required double size, required List<Color> colors}) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Use RadialGradient for CanvasKit stability on web. SweepGradient can
            // hit null tileMode issues in some builds. This visually achieves a
            // similar soft blob effect.
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.85,
              tileMode: TileMode.clamp,
              colors: [
                colors.first.withValues(alpha: 0.75),
                colors.last.withValues(alpha: 0.15),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.15),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
      ),
    );
  }

  double lerp(double a, double b, double t) => a + (b - a) * t;
}
