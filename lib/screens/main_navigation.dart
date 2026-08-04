import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/services/tutorial_service.dart';
import 'package:showcaseview/showcaseview.dart';

enum PatientTab {
  home,
  conditions,
  community,
  tracker,
  profile,
}

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
      backgroundColor: Colors.black,
      body: widget.child,
      extendBody: true,
      bottomNavigationBar: Showcase(
        key: TutorialKeys.navBar,
        title: 'Navigation',
        description:
            'Use these tabs to move between Home, Condition, Community, Tracker, and your Profile.',
        child: AdaptlyBottomNav(
          selectedTab: PatientTab.values[widget.currentIndex],
          onTabSelected: (tab) {
            // Close any open modal bottom sheets before navigating
            final navigator = Navigator.of(context, rootNavigator: true);
            final modalRoute = ModalRoute.of(context);
            if (navigator.canPop() && modalRoute != null && !modalRoute.isFirst) {
              navigator.pop();
            }
            
            switch (tab) {
              case PatientTab.home:
                context.go('/');
                break;
              case PatientTab.conditions:
                context.go('/conditions');
                break;
              case PatientTab.community:
                context.go('/communities');
                break;
              case PatientTab.tracker:
                context.go('/tracker');
                break;
              case PatientTab.profile:
                context.go('/profile');
                break;
            }
          },
        ),
      ),
    );
  }
}

class AdaptlyBottomNav extends StatelessWidget {
  final PatientTab selectedTab;
  final ValueChanged<PatientTab> onTabSelected;

  const AdaptlyBottomNav({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 22),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xff111113).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xff242428)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _AdaptlyNavItem(
            tab: PatientTab.home,
            selectedTab: selectedTab,
            icon: Icons.home_rounded,
            label: 'Home',
            onTap: onTabSelected,
            tutorialKey: TutorialKeys.navHome,
            tutorialTitle: 'Home',
            tutorialDescription: 'This is your daily starting point. You\'ll see guidance, goals, updates, and reminders here.',
          ),
          _AdaptlyNavItem(
            tab: PatientTab.conditions,
            selectedTab: selectedTab,
            icon: Icons.medical_information_outlined,
            label: 'Condition',
            onTap: onTabSelected,
            tutorialKey: TutorialKeys.navConditions,
            tutorialTitle: 'Condition',
            tutorialDescription: 'Find guidance and advice tailored to specific conditions. These sections help you understand what to expect and how to manage daily life.',
          ),
          _AdaptlyNavItem(
            tab: PatientTab.community,
            selectedTab: selectedTab,
            icon: Icons.people_outline,
            label: 'Hub',
            onTap: onTabSelected,
            tutorialKey: TutorialKeys.navCommunity,
            tutorialTitle: 'Community',
            tutorialDescription: 'Connect with others who understand what you\'re going through. Ask questions, share experiences, or just read along.',
          ),
          _AdaptlyNavItem(
            tab: PatientTab.tracker,
            selectedTab: selectedTab,
            icon: Icons.insert_chart_outlined,
            label: 'Tracker',
            onTap: onTabSelected,
            tutorialKey: TutorialKeys.navTracker,
            tutorialTitle: 'Tracker',
            tutorialDescription: 'Use this to log things like pain, sleep, energy, and symptoms. Over time, this helps you notice patterns and stay informed.',
          ),
          _AdaptlyNavItem(
            tab: PatientTab.profile,
            selectedTab: selectedTab,
            icon: Icons.person_outline,
            label: 'Profile',
            onTap: onTabSelected,
            tutorialKey: TutorialKeys.navProfile,
            tutorialTitle: 'Profile & Settings',
            tutorialDescription: 'Update your information, manage preferences, and control notifications anytime.',
          ),
        ],
      ),
    );
  }
}

class _AdaptlyNavItem extends StatelessWidget {
  final PatientTab tab;
  final PatientTab selectedTab;
  final IconData icon;
  final String label;
  final ValueChanged<PatientTab> onTap;
  final GlobalKey? tutorialKey;
  final String? tutorialTitle;
  final String? tutorialDescription;

  const _AdaptlyNavItem({
    required this.tab,
    required this.selectedTab,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tutorialKey,
    this.tutorialTitle,
    this.tutorialDescription,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = tab == selectedTab;
    final color = isActive ? const Color(0xff2f91ff) : const Color(0xffaaaab0);

    Widget navItem = Expanded(
      child: GestureDetector(
        onTap: () => onTap(tab),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 31,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (tutorialKey != null && tutorialTitle != null && tutorialDescription != null) {
      return Showcase(
        key: tutorialKey!,
        title: tutorialTitle!,
        description: tutorialDescription!,
        child: navItem,
      );
    }

    return navItem;
  }
}
