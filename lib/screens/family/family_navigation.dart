import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/theme.dart';

enum FamilyTab {
  home,
  health,
  journey,
  resources,
  alerts,
}

class FamilyNavigation extends StatelessWidget {
  const FamilyNavigation({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  final Widget child;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: child,
      extendBody: true,
      bottomNavigationBar: AdaptlyBottomNav(
        selectedTab: FamilyTab.values[currentIndex],
        onTabSelected: (tab) {
          switch (tab) {
            case FamilyTab.home:
              context.go('/family/dashboard');
              break;
            case FamilyTab.health:
              context.go('/family/health');
              break;
            case FamilyTab.journey:
              context.go('/family/journey');
              break;
            case FamilyTab.resources:
              context.go('/family/resources');
              break;
            case FamilyTab.alerts:
              context.go('/family/alerts');
              break;
          }
        },
      ),
    );
  }
}

class AdaptlyBottomNav extends StatelessWidget {
  final FamilyTab selectedTab;
  final ValueChanged<FamilyTab> onTabSelected;

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
            tab: FamilyTab.home,
            selectedTab: selectedTab,
            icon: Icons.home_rounded,
            label: 'Home',
            onTap: onTabSelected,
          ),
          _AdaptlyNavItem(
            tab: FamilyTab.health,
            selectedTab: selectedTab,
            icon: Icons.favorite_outline,
            label: 'Health',
            onTap: onTabSelected,
          ),
          _AdaptlyNavItem(
            tab: FamilyTab.journey,
            selectedTab: selectedTab,
            icon: Icons.flag_outlined,
            label: 'Journey',
            onTap: onTabSelected,
          ),
          _AdaptlyNavItem(
            tab: FamilyTab.resources,
            selectedTab: selectedTab,
            icon: Icons.folder_outlined,
            label: 'Notes',
            onTap: onTabSelected,
          ),
          _AdaptlyNavItem(
            tab: FamilyTab.alerts,
            selectedTab: selectedTab,
            icon: Icons.notifications_outlined,
            label: 'Alerts',
            onTap: onTabSelected,
          ),
        ],
      ),
    );
  }
}

class _AdaptlyNavItem extends StatelessWidget {
  final FamilyTab tab;
  final FamilyTab selectedTab;
  final IconData icon;
  final String label;
  final ValueChanged<FamilyTab> onTap;

  const _AdaptlyNavItem({
    required this.tab,
    required this.selectedTab,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = tab == selectedTab;
    final color = isActive ? const Color(0xff2f91ff) : const Color(0xffaaaab0);

    return Expanded(
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
  }
}
