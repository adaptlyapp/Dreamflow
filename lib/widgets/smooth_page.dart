import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A subtle, fast fade+scale transition for page navigations.
/// Keeps navigation feeling instant while avoiding hard cuts.
class SmoothTransitionPage<T> extends CustomTransitionPage<T> {
  SmoothTransitionPage({required Widget child})
      : super(
          child: child,
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
            return FadeTransition(
              opacity: curve,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1).animate(curve),
                child: child,
              ),
            );
          },
        );
}
