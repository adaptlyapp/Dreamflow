import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/achievement.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/achievement_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/skeletons.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _achievementService = AchievementService();
  bool _loading = true;
  List<UserAchievement> _userAchievements = [];
  Map<String, dynamic> _stats = {};
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final achievements = await _achievementService.getUserAchievements(user.id);
    final stats = await _achievementService.getAchievementStats(user.id);

    if (!mounted) return;
    setState(() {
      _userAchievements = achievements;
      _stats = stats;
      _loading = false;
    });
  }

  List<_AchievementDisplay> _getDisplayList() {
    final allAchievements = _achievementService.getAllAchievements();
    final displays = <_AchievementDisplay>[];

    for (final achievement in allAchievements) {
      if (_selectedCategory != 'all' && achievement.category != _selectedCategory) {
        continue;
      }

      final userAchievement = _userAchievements.firstWhere(
        (ua) => ua.achievementId == achievement.id,
        orElse: () => UserAchievement(
          id: achievement.id,
          userId: '',
          achievementId: achievement.id,
          progress: 0,
          unlocked: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      displays.add(_AchievementDisplay(
        achievement: achievement,
        userAchievement: userAchievement,
      ));
    }

    // Sort: unlocked first (by unlock date desc), then locked by tier
    displays.sort((a, b) {
      if (a.userAchievement.unlocked && !b.userAchievement.unlocked) return -1;
      if (!a.userAchievement.unlocked && b.userAchievement.unlocked) return 1;
      if (a.userAchievement.unlocked && b.userAchievement.unlocked) {
        return (b.userAchievement.unlockedAt ?? DateTime(2000))
            .compareTo(a.userAchievement.unlockedAt ?? DateTime(2000));
      }
      return a.achievement.tier.compareTo(b.achievement.tier);
    });

    return displays;
  }

  Color _getTierColor(int tier, ColorScheme cs) {
    switch (tier) {
      case 1:
        return const Color(0xFFCD7F32); // Bronze
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFFFD700); // Gold
      case 4:
        return const Color(0xFFE5E4E2); // Platinum
      default:
        return cs.primary;
    }
  }

  String _getTierName(int tier) {
    switch (tier) {
      case 1:
        return 'Bronze';
      case 2:
        return 'Silver';
      case 3:
        return 'Gold';
      case 4:
        return 'Platinum';
      default:
        return 'Common';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displays = _getDisplayList();

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CenteredLoadingSkeleton())
            : RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: Icon(Icons.arrow_back, color: cs.onSurface),
                            ),
                            Expanded(
                              child: Text(
                                'Achievements',
                                style: context.textStyles.headlineMedium?.semiBold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Stats card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: _StatsCard(stats: _stats),
                      ),
                    ),

                    SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

                    // Category filters
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 48,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          children: [
                            _CategoryChip(
                              label: 'All',
                              isSelected: _selectedCategory == 'all',
                              onTap: () => setState(() => _selectedCategory = 'all'),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            _CategoryChip(
                              label: 'Health',
                              isSelected: _selectedCategory == 'health',
                              onTap: () => setState(() => _selectedCategory = 'health'),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            _CategoryChip(
                              label: 'Social',
                              isSelected: _selectedCategory == 'social',
                              onTap: () => setState(() => _selectedCategory = 'social'),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            _CategoryChip(
                              label: 'Goals',
                              isSelected: _selectedCategory == 'goals',
                              onTap: () => setState(() => _selectedCategory = 'goals'),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            _CategoryChip(
                              label: 'Learning',
                              isSelected: _selectedCategory == 'learning',
                              onTap: () => setState(() => _selectedCategory = 'learning'),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            _CategoryChip(
                              label: 'Consistency',
                              isSelected: _selectedCategory == 'consistency',
                              onTap: () => setState(() => _selectedCategory = 'consistency'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

                    // Achievement list
                    if (displays.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Card(
                            child: Padding(
                              padding: AppSpacing.paddingLg,
                              child: Column(
                                children: [
                                  Icon(Icons.emoji_events_outlined, size: 48, color: cs.onSurfaceVariant),
                                  SizedBox(height: AppSpacing.md),
                                  Text(
                                    'No achievements in this category yet',
                                    style: context.textStyles.bodyLarge?.withColor(cs.onSurfaceVariant),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        sliver: SliverList.separated(
                          itemCount: displays.length,
                          separatorBuilder: (_, __) => SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, index) {
                            final display = displays[index];
                            return _AchievementCard(
                              display: display,
                              tierColor: _getTierColor(display.achievement.tier, cs),
                              tierName: _getTierName(display.achievement.tier),
                            );
                          },
                        ),
                      ),

                    SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unlocked = stats['unlocked'] ?? 0;
    final total = stats['total'] ?? 0;
    final points = stats['points'] ?? 0;
    final percentage = stats['percentage'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.secondary],
        ),
      ),
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: cs.onPrimary, size: 32),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Progress',
                        style: context.textStyles.titleLarge?.semiBold.withColor(cs.onPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$unlocked of $total achievements unlocked',
                        style: context.textStyles.bodyMedium?.withColor(cs.onPrimary.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.stars,
                    label: 'Points',
                    value: points.toString(),
                    color: cs.onPrimary,
                  ),
                ),
                Container(width: 1, height: 48, color: cs.onPrimary.withValues(alpha: 0.2)),
                Expanded(
                  child: _StatItem(
                    icon: Icons.check_circle,
                    label: 'Completion',
                    value: '$percentage%',
                    color: cs.onPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: color, size: 24),
      SizedBox(height: 4),
      Text(value, style: context.textStyles.titleLarge?.semiBold.withColor(color)),
      Text(label, style: context.textStyles.labelSmall?.withColor(color.withValues(alpha: 0.85))),
    ],
  );
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: context.textStyles.labelLarge?.withColor(
            isSelected ? cs.onPrimary : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final _AchievementDisplay display;
  final Color tierColor;
  final String tierName;

  const _AchievementCard({
    required this.display,
    required this.tierColor,
    required this.tierName,
  });

  IconData _getIconData(String iconName) {
    final iconMap = {
      'edit_note': Icons.edit_note,
      'calendar_today': Icons.calendar_today,
      'event': Icons.event,
      'local_fire_department': Icons.local_fire_department,
      'trending_up': Icons.trending_up,
      'chat_bubble': Icons.chat_bubble,
      'groups': Icons.groups,
      'favorite': Icons.favorite,
      'comment': Icons.comment,
      'flag': Icons.flag,
      'check_circle': Icons.check_circle,
      'emoji_events': Icons.emoji_events,
      'explore': Icons.explore,
      'school': Icons.school,
      'search': Icons.search,
      'cake': Icons.cake,
      'celebration': Icons.celebration,
      'stars': Icons.stars,
    };
    return iconMap[iconName] ?? Icons.emoji_events;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final achievement = display.achievement;
    final userAchievement = display.userAchievement;
    final isUnlocked = userAchievement.unlocked;
    final progress = userAchievement.progress;
    final requirement = achievement.requirement;
    final progressPercent = requirement > 0 ? (progress / requirement).clamp(0.0, 1.0) : 0.0;

    return Card(
      color: isUnlocked ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isUnlocked ? tierColor.withValues(alpha: 0.15) : cs.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isUnlocked ? tierColor.withValues(alpha: 0.3) : cs.outlineVariant,
                  width: 2,
                ),
              ),
              child: Icon(
                _getIconData(achievement.icon),
                color: isUnlocked ? tierColor : cs.onSurfaceVariant,
                size: 28,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.title,
                          style: context.textStyles.titleMedium?.semiBold.withColor(
                            isUnlocked ? cs.onSurface : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (isUnlocked)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: tierColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            tierName,
                            style: context.textStyles.labelSmall?.withColor(tierColor),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                  ),
                  if (!isUnlocked) ...[
                    SizedBox(height: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$progress / $requirement',
                              style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
                            ),
                            Text(
                              '${(progressPercent * 100).toInt()}%',
                              style: context.textStyles.labelSmall?.semiBold.withColor(cs.primary),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progressPercent,
                            minHeight: 6,
                            backgroundColor: cs.surfaceContainer,
                            valueColor: AlwaysStoppedAnimation(cs.primary),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: tierColor),
                        SizedBox(width: 4),
                        Text(
                          'Unlocked ${_formatDate(userAchievement.unlockedAt!)}',
                          style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }
}

class _AchievementDisplay {
  final Achievement achievement;
  final UserAchievement userAchievement;

  _AchievementDisplay({required this.achievement, required this.userAchievement});
}
