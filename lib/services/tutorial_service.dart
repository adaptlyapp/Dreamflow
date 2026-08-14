import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/services/user_service.dart';

/// Centralized keys and helpers for the first-time app tutorial
class TutorialKeys {
  // Bottom navigation items
  static final GlobalKey navHome = GlobalKey(debugLabel: 'nav_home');
  static final GlobalKey navJourney = GlobalKey(debugLabel: 'nav_journey');
  static final GlobalKey navConditions = GlobalKey(debugLabel: 'nav_conditions');
  static final GlobalKey navCommunity = GlobalKey(debugLabel: 'nav_community');
  static final GlobalKey navTracker = GlobalKey(debugLabel: 'nav_tracker');
  static final GlobalKey navProfile = GlobalKey(debugLabel: 'nav_profile');
  // Entire bottom navigation bar as a reliable fallback anchor
  static final GlobalKey navBar = GlobalKey(debugLabel: 'nav_bar');

  // Home screen highlights
  static final GlobalKey homeNextStep = GlobalKey(debugLabel: 'home_next_step');
  static final GlobalKey homeAddEntry = GlobalKey(debugLabel: 'home_add_entry');
}

class TutorialService {
  static final TutorialService _instance = TutorialService._internal();
  factory TutorialService() => _instance;
  TutorialService._internal();

  bool _starting = false;
  static bool _forceOnce = false; // Forces the next start regardless of preferences
  BuildContext? _rootShowcaseContext; // Context from ShowCaseWidget builder

  /// Register the root context from ShowCaseWidget.builder so we always have
  /// a valid context to resolve ShowCaseWidget.of(context)
  void registerRootShowcaseContext(BuildContext ctx) {
    _rootShowcaseContext = ctx;
  }

  /// Force the tutorial to start the next time startIfNeeded() is called.
  static void forceOnce() {
    _forceOnce = true;
    debugPrint('TutorialService.forceOnce: next start will be forced');
  }

  /// Returns true if the signed-in user has already seen the tutorial.
  Future<bool> hasSeenTutorial() async {
    try {
      return await UserService().hasSeenTutorial();
    } catch (e) {
      debugPrint('TutorialService.hasSeenTutorial error: $e');
      return true; // fail closed (avoid blocking with repeated attempts)
    }
  }

  /// Marks the tutorial as seen in user.preferences.hasSeenTutorial = true
  Future<void> markSeen() async {
    try {
      await UserService().setHasSeenTutorial(true);
    } catch (e) {
      debugPrint('TutorialService.markSeen error: $e');
    }
  }

  /// Start the walkthrough flow (Welcome sheet + guided highlights) if needed.
  /// Safe to call multiple times; it will no-op if a flow is already starting.
  Future<void> startIfNeeded(BuildContext context) async {
    if (_starting) return;
    _starting = true;
    try {
      final seen = await hasSeenTutorial();
      final shouldStart = _forceOnce || !seen;
      debugPrint('TutorialService.startIfNeeded: seen=$seen, forceOnce=$_forceOnce, shouldStart=$shouldStart');
      // Reset the force flag now that we evaluated it
      _forceOnce = false;
      if (!shouldStart) return;

      // Give the UI a moment to build so keys resolve their contexts
      await Future.delayed(const Duration(milliseconds: 450));
      if (!context.mounted) return;

      // Step 1 — Welcome modal sheet with Next / Skip
      final proceed = await _showWelcomeSheet(context);
      if (!context.mounted) return;
      if (proceed != true) {
        // User skipped the walkthrough — mark seen and show subtle banner
        await markSeen();
        _showFinalToast(context);
        return;
      }
      debugPrint('TutorialService.startIfNeeded: Welcome sheet confirmed (Next)');

      // Step 2+ — Primary navigation tour in requested order
      // Wait briefly for keys to mount if needed (e.g., after closing the sheet)
      var keys = await _awaitTargets(
        order: [
          TutorialKeys.navHome,
          TutorialKeys.navConditions,
          TutorialKeys.navTracker,
          TutorialKeys.navCommunity,
          TutorialKeys.navProfile,
        ],
        attempts: 12,
        interval: const Duration(milliseconds: 120),
      );

      // Extra diagnostics to pinpoint which ones are missing
      debugPrint('TutorialService.startIfNeeded: targets status -> home=${TutorialKeys.navHome.currentContext != null}, cond=${TutorialKeys.navConditions.currentContext != null}, tracker=${TutorialKeys.navTracker.currentContext != null}, comm=${TutorialKeys.navCommunity.currentContext != null}, profile=${TutorialKeys.navProfile.currentContext != null}');
      debugPrint('TutorialService.startIfNeeded: showcase targets found = ${keys.length}');
      if (keys.isEmpty) {
        // If even the nav bar anchor isn't available, switch to a reliable
        // modal walkthrough that advances page-by-page with Next.
        if (TutorialKeys.navBar.currentContext == null) {
          debugPrint('TutorialService.startIfNeeded: No showcase targets. Starting modal fallback tour.');
          await markSeen();
          await _runModalTour(context);
          return;
        }
        // Otherwise, at least show the nav bar highlight.
        keys = [TutorialKeys.navBar];
        debugPrint('TutorialService.startIfNeeded: using fallback target navBar');
      }

      // Mark as seen right away so the flow doesn't re-open even if interrupted
      await markSeen();

      // Prefer the context from the first available target so ShowCaseWidget.of
      // always resolves using a descendant context of ShowCaseWidget
      final BuildContext? anchorCtx = keys.first.currentContext;
      final state = ShowCaseWidget.of(anchorCtx ?? _rootShowcaseContext ?? context);
      debugPrint('TutorialService.startIfNeeded: starting ShowCase with ${keys.length} targets');
      state.startShowCase(keys);
    } catch (e) {
      debugPrint('TutorialService.startIfNeeded error: $e');
    } finally {
      _starting = false;
    }
  }

  /// Simple, reliable modal-based walkthrough that does not depend on anchors.
  /// Navigates between tabs and shows a short explainer on each.
  Future<void> _runModalTour(BuildContext context) async {
    final steps = <_ModalStep>[
      _ModalStep(
        route: '/',
        title: 'Home',
        body:
            'This is your daily starting point. You’ll see guidance, goals, updates, and reminders here.',
      ),
      _ModalStep(
        route: '/conditions',
        title: 'Conditions',
        body:
            'Find guidance and advice tailored to specific conditions. Learn what to expect and how to manage daily life.',
      ),
      _ModalStep(
        route: '/tracker',
        title: 'Tracker',
        body:
            'Log pain, sleep, energy, and symptoms. Over time, spot patterns that help you make informed decisions.',
      ),
      _ModalStep(
        route: '/communities',
        title: 'Community',
        body:
            'Connect with people who understand. Ask questions, share experiences, or simply read along.',
      ),
      _ModalStep(
        route: '/profile',
        title: 'Profile & Settings',
        body:
            'Update your info, manage preferences, and control notifications any time.',
      ),
    ];

    // Ensure we start from Home.
    if (context.mounted) context.go(steps.first.route);
    await Future.delayed(const Duration(milliseconds: 200));

    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (i > 0) {
        if (context.mounted) context.go(step.route);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final isLast = i == steps.length - 1;
      final bool? proceed = await _showStepSheet(
        context,
        title: step.title,
        body: step.body,
        isLast: isLast,
      );
      if (proceed != true) {
        // User skipped or dismissed
        _showFinalToast(context);
        return;
      }
    }

    // Completed all steps
    _showFinalToast(context);
  }

  Future<bool?> _showStepSheet(
    BuildContext context, {
    required String title,
    required String body,
    required bool isLast,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: false,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                body,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (ctx.mounted) ctx.pop(true);
                      },
                      child: Text(
                        isLast ? 'Finish' : 'Next',
                        style: Theme.of(ctx)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Theme.of(ctx).brightness == Brightness.light ? Colors.black : cs.onPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      if (ctx.mounted) ctx.pop(false);
                    },
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Simple struct for modal steps (declared top-level below)

  /// Displays the Welcome bottom sheet, returns true if user pressed Next.
  Future<bool?> _showWelcomeSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: false,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome to Adaptly', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Adaptly helps you navigate life after injury, illness, or diagnosis by giving you guidance, tracking, and support in one place.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        debugPrint('TutorialService: Welcome Next tapped');
                        // Use go_router context extension to pop this sheet
                        if (ctx.mounted) ctx.pop(true);
                      },
                      child: Text(
                        'Next',
                        style: Theme.of(ctx)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Theme.of(ctx).brightness == Brightness.light ? Colors.black : cs.onPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      debugPrint('TutorialService: Welcome Skip tapped');
                      if (ctx.mounted) ctx.pop(false);
                    },
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Repeatedly checks for mounted Showcase targets in the given order.
  /// Returns as soon as at least one target is available, or an empty list on timeout.
  Future<List<GlobalKey>> _awaitTargets({
    required List<GlobalKey> order,
    int attempts = 10,
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    List<GlobalKey> collect() => order.where((k) => k.currentContext != null).toList();

    var keys = collect();
    if (keys.isNotEmpty) return keys;
    for (var i = 0; i < attempts; i++) {
      await Future.delayed(interval);
      keys = collect();
      if (keys.isNotEmpty) return keys;
    }
    return keys; // possibly empty
  }

  void _showFinalToast(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You can explore at your own pace. Adaptly is here when you need it.'),
      ),
    );
  }
}

// Simple struct for modal steps
class _ModalStep {
  final String route;
  final String title;
  final String body;
  _ModalStep({required this.route, required this.title, required this.body});
}
