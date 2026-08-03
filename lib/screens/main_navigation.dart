import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/services/tutorial_service.dart';
import 'package:showcaseview/showcaseview.dart';

class MainNavigation extends StatefulWidget {
  final Widget child;
  final int currentIndex;

  const MainNavigation({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  bool _tutorialRequested = false;

  @override
  Widget build(BuildContext context) {
    // Schedule tutorial from here; ShowCaseWidget now lives at app root
    if (!_tutorialRequested) {
      _tutorialRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) TutorialService().startIfNeeded(context);
      });
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Showcase(
        key: TutorialKeys.navBar,
        title: 'Navigation',
        description:
            'Use these tabs to move between Home, Condition, Community, Tracker, and your Profile.',
        child: NavigationBar(
          selectedIndex: widget.currentIndex,
          onDestinationSelected: (index) {
            // Close any open modal bottom sheets before navigating
            // Use rootNavigator to access sheets opened with showModalBottomSheet
            final navigator = Navigator.of(context, rootNavigator: true);
            final modalRoute = ModalRoute.of(context);
            // If there's a modal route and it can be popped, close it
            if (navigator.canPop() && modalRoute != null && !modalRoute.isFirst) {
              navigator.pop();
            }
            
            switch (index) {
              case 0:
                context.go('/');
                break;
              case 1:
                context.go('/conditions');
                break;
              case 2:
                context.go('/communities');
                break;
              case 3:
                context.go('/tracker');
                break;
              case 4:
                context.go('/profile');
                break;
            }
          },
          destinations: [
            NavigationDestination(
              icon: Showcase(
                key: TutorialKeys.navHome,
                title: 'Home',
                description:
                    'This is your daily starting point. You’ll see guidance, goals, updates, and reminders here.',
                child: const Icon(Icons.home_outlined),
              ),
              selectedIcon: const Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Showcase(
                key: TutorialKeys.navConditions,
                title: 'Condition',
                description:
                    'Find guidance and advice tailored to specific conditions. These sections help you understand what to expect and how to manage daily life.',
                child: const Icon(Icons.medical_information_outlined),
              ),
              selectedIcon: const Icon(Icons.medical_information),
              label: 'Condition',
            ),
            NavigationDestination(
              icon: Showcase(
                key: TutorialKeys.navCommunity,
                title: 'Community',
                description:
                    'Connect with others who understand what you\'re going through. Ask questions, share experiences, or just read along.',
                child: const Icon(Icons.people_outline),
              ),
              selectedIcon: const Icon(Icons.people),
              label: 'Hub',
            ),
            NavigationDestination(
              icon: Showcase(
                key: TutorialKeys.navTracker,
                title: 'Tracker',
                description:
                    'Use this to log things like pain, sleep, energy, and symptoms. Over time, this helps you notice patterns and stay informed.',
                child: const Icon(Icons.insert_chart_outlined),
              ),
              selectedIcon: const Icon(Icons.insert_chart),
              label: 'Tracker',
            ),
            NavigationDestination(
              icon: Showcase(
                key: TutorialKeys.navProfile,
                title: 'Profile & Settings',
                description:
                    'Update your information, manage preferences, and control notifications anytime.',
                child: const Icon(Icons.person_outline),
              ),
              selectedIcon: const Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
