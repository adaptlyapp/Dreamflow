import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/models/condition_detail.dart';
import 'package:wellspring/models/post.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/services/post_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/services/achievement_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/comments_sheet.dart';
import 'package:wellspring/widgets/condition_details_sheet.dart';
import 'package:wellspring/widgets/post_card.dart';
import 'package:wellspring/screens/profile/pin_user_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  final _postService = PostService();
  final _userService = UserService();
  final _achievementService = AchievementService();
  final _conditionService = ConditionService();
  bool _loading = true;
  List<Post> _posts = [];
  Map<String, dynamic> _achievementStats = {};
  List<Condition> _conditions = [];

  @override
  void initState() {
    super.initState();
    final userProvider = context.read<UserProvider>();
    if (userProvider.currentUser == null) {
      userProvider.loadUser().then((_) => _load());
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final items = await _postService.getUserPosts(user.id);
    final stats = await _achievementService.getAchievementStats(user.id);
    final allConditions = await _conditionService.getAllConditions();
    // Filter to only user's conditions
    final detailsMap =
        (user.preferences['conditionDetails'] as Map<String, dynamic>?) ??
            const {};
    final userConditions =
        allConditions.where((c) => user.conditions.contains(c.id)).map((c) {
      final raw = detailsMap[c.id];
      if (raw == null) return c;
      try {
        final detail = ConditionDetail.fromJson(Map<String, dynamic>.from(raw));
        return c.copyWith(userDetail: detail);
      } catch (_) {
        return c;
      }
    }).toList();
    if (!mounted) return;
    setState(() {
      _posts = items;
      _achievementStats = stats;
      _conditions = userConditions;
      _loading = false;
    });
  }

  Future<void> _handleLike(String postId) async {
    await _postService.likePost(postId);
    await _load();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final user = context.watch<UserProvider>().currentUser;
    final name =
        (user?.name?.trim().isNotEmpty == true) ? user!.name.trim() : 'Profile';
    // Show admin actions if either the Supabase user doc email OR the
    // Supabase auth account email matches the allowlist. Some legacy user
    // docs may have a missing/old email field.
    final authEmail = SupabaseConfig.auth.currentUser?.email?.toLowerCase();
    final userEmail = (user?.email ?? '').toLowerCase();
    final isAdmin = authEmail == 'adaptlyapp@gmail.com' ||
        userEmail == 'adaptlyapp@gmail.com' ||
        authEmail == 'dpaine170014@gmail.com' ||
        userEmail == 'dpaine170014@gmail.com';
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/ChatGPT_Image_Aug_3_2026_07_26_30_AM.png',
              fit: BoxFit.cover,
            ),
          ),
          // Content
          SafeArea(
            child: _loading
                ? const Center(child: CenteredLoadingSkeleton())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: AppSpacing.lg,
                              right: AppSpacing.lg,
                              top: AppSpacing.md,
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => context.pop(),
                                  icon: Icon(Icons.arrow_back,
                                      color: cs.onSurface),
                                ),
                                if (isAdmin) ...[
                                  TextButton.icon(
                                    onPressed: () =>
                                        context.go('/admin/suggestions'),
                                    icon: const Icon(Icons.verified_user),
                                    label: const Text('Approvals'),
                                  ),
                                ],
                                TextButton.icon(
                                  onPressed: () =>
                                      context.push('/settings?section=profile'),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit'),
                                ),
                                IconButton(
                                  tooltip: 'Log out',
                                  onPressed: () async {
                                    try {
                                      await context
                                          .read<UserProvider>()
                                          .logout();
                                      if (!mounted) return;
                                      context.go('/auth');
                                    } catch (e) {
                                      debugPrint('Profile logout failed: $e');
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(const SnackBar(
                                            content:
                                                Text('Failed to log out')));
                                      }
                                    }
                                  },
                                  icon: Icon(Icons.logout, color: cs.error),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                            child: SizedBox(height: AppSpacing.md)),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            child: _HeaderCard(name: name),
                          ),
                        ),
                        SliverToBoxAdapter(
                            child: SizedBox(height: AppSpacing.lg)),
                        // Achievements card
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            child: _AchievementsCard(stats: _achievementStats),
                          ),
                        ),
                        SliverToBoxAdapter(
                            child: SizedBox(height: AppSpacing.lg)),
                        // Condition details card
                        if (_conditions.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg),
                              child: _ConditionDetailsCard(
                                conditions: _conditions,
                                onRefresh: _load,
                              ),
                            ),
                          ),
                        if (_conditions.isNotEmpty)
                          SliverToBoxAdapter(
                              child: SizedBox(height: AppSpacing.lg)),
                        // Preferred location (reflect saved coords from Resources)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            child: _LocationCard(),
                          ),
                        ),
                        SliverToBoxAdapter(
                            child: SizedBox(height: AppSpacing.lg)),
                        // Pinned profiles section
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('Pinned profiles',
                                      style: context
                                          .textStyles.titleLarge?.semiBold),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    await showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      showDragHandle: true,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(AppRadius.lg)),
                                      ),
                                      builder: (_) => const PinUserSheet(),
                                    );
                                    if (!mounted) return;
                                    setState(() {});
                                  },
                                  icon: Icon(Icons.add, color: cs.primary),
                                  label: Text('Add',
                                      style: context.textStyles.labelLarge
                                          ?.withColor(cs.primary)),
                                )
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                            child: SizedBox(height: AppSpacing.sm)),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 96,
                            child: StreamBuilder<List<Map<String, dynamic>>>(
                              stream: _userService.watchPinnedUsers(),
                              builder: (context, snapshot) {
                                // If Firestore denies the query (e.g., a legacy doc violates rules),
                                // the stream throws and previously pinned items appear to "disappear".
                                // Surface a clear message instead of rendering an empty list.
                                if (snapshot.hasError) {
                                  final err = snapshot.error;
                                  debugPrint(
                                      'ProfileScreen pinned stream error: $err');
                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: AppSpacing.lg),
                                    child: Card(
                                      child: Padding(
                                        padding: AppSpacing.paddingMd,
                                        child: Row(
                                          children: [
                                            Icon(Icons.error_outline,
                                                color: cs.error),
                                            SizedBox(width: AppSpacing.md),
                                            Expanded(
                                              child: Text(
                                                'Pinned profiles are unavailable right now. Please check Firestore rules for users/{uid}/pinned_users.',
                                                style: context
                                                    .textStyles.bodyMedium
                                                    ?.withColor(
                                                        cs.onSurfaceVariant),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final items = snapshot.data ?? [];
                                if (items.isEmpty) {
                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: AppSpacing.lg),
                                    child: Card(
                                      child: Padding(
                                        padding: AppSpacing.paddingMd,
                                        child: Row(
                                          children: [
                                            Icon(Icons.push_pin_outlined,
                                                color: cs.onSurfaceVariant),
                                            SizedBox(width: AppSpacing.md),
                                            Expanded(
                                              child: Text(
                                                'Pin profiles you care about to visit quickly.',
                                                style: context
                                                    .textStyles.bodyMedium
                                                    ?.withColor(
                                                        cs.onSurfaceVariant),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg),
                                  itemBuilder: (context, index) {
                                    final p = items[index];
                                    final name =
                                        (p['name'] ?? 'User') as String;
                                    final imageUrl =
                                        (p['imageUrl'] as String?)?.trim();
                                    final userId = p['id'] as String;
                                    ImageProvider? provider;
                                    if (imageUrl != null &&
                                        imageUrl.isNotEmpty) {
                                      if (imageUrl.startsWith('data:image')) {
                                        try {
                                          final comma = imageUrl.indexOf(',');
                                          final b64 = comma != -1
                                              ? imageUrl.substring(comma + 1)
                                              : imageUrl;
                                          provider =
                                              MemoryImage(base64Decode(b64));
                                        } catch (_) {
                                          provider = null;
                                        }
                                      } else {
                                        provider = NetworkImage(imageUrl);
                                      }
                                    }
                                    return InkWell(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md),
                                      onTap: () => context.push('/u/$userId'),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: cs.primaryContainer,
                                              image: provider != null
                                                  ? DecorationImage(
                                                      image: provider,
                                                      fit: BoxFit.cover)
                                                  : null,
                                            ),
                                            alignment: Alignment.center,
                                            child: provider == null
                                                ? Text(name[0].toUpperCase(),
                                                    style: context
                                                        .textStyles.titleMedium
                                                        ?.withColor(cs
                                                            .onPrimaryContainer))
                                                : null,
                                          ),
                                          SizedBox(height: 8),
                                          SizedBox(
                                            width: 72,
                                            child: Text(
                                              name,
                                              style:
                                                  context.textStyles.labelSmall,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                  separatorBuilder: (_, __) =>
                                      SizedBox(width: AppSpacing.md),
                                  itemCount: items.length,
                                );
                              },
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                            child: SizedBox(height: AppSpacing.lg)),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            child: Text('Your posts',
                                style: context.textStyles.titleLarge?.semiBold),
                          ),
                        ),
                        SliverToBoxAdapter(
                            child: SizedBox(height: AppSpacing.md)),
                        if (_posts.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg),
                              child: Card(
                                child: Padding(
                                  padding: AppSpacing.paddingMd,
                                  child: Row(
                                    children: [
                                      Icon(Icons.article_outlined,
                                          color: cs.onSurfaceVariant),
                                      SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Text(
                                          'You haven’t posted yet. Share an update from Communities!',
                                          style: context.textStyles.bodyMedium
                                              ?.withColor(cs.onSurfaceVariant),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding:
                                EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            sliver: SliverList.builder(
                              itemCount: _posts.length,
                              itemBuilder: (context, index) {
                                final p = _posts[index];
                                return PostCard(
                                  post: p,
                                  onLike: () => _handleLike(p.id),
                                  onComment: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      showDragHandle: true,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(AppRadius.lg)),
                                      ),
                                      builder: (_) => CommentsSheet(
                                          post: p, service: _postService),
                                    ).then((_) => _load());
                                  },
                                  onDeleted: _load,
                                );
                              },
                            ),
                          ),
                        SliverToBoxAdapter(
                            child: SizedBox(height: AppSpacing.xl)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  const _HeaderCard({required this.name});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = context.watch<UserProvider>().currentUser;
    final initial =
        (user?.name.isNotEmpty == true ? user!.name[0] : '?').toUpperCase();
    final url = user?.profileImageUrl?.trim();

    ImageProvider? provider;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('data:image')) {
        try {
          final comma = url.indexOf(',');
          final b64 = comma != -1 ? url.substring(comma + 1) : url;
          provider = MemoryImage(base64Decode(b64));
        } catch (_) {
          provider = null;
        }
      } else {
        provider = NetworkImage(url);
      }
    }

    // Animated, gradient header with avatar and glassy badges
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary,
              cs.secondary,
            ],
          ),
          border: Border.all(color: cs.onPrimary.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with precise clip + border for perfect circle
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: cs.onPrimary.withValues(alpha: 0.24), width: 1),
                ),
                child: ClipOval(
                  child: provider != null
                      ? Image(
                          image: provider,
                          fit: BoxFit.cover,
                          width: 84,
                          height: 84,
                        )
                      : Container(
                          color: cs.primaryContainer,
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: context.textStyles.headlineSmall
                                ?.withColor(cs.onPrimaryContainer),
                          ),
                        ),
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name,
                        style: context.textStyles.titleLarge?.semiBold
                            ?.withColor(cs.onPrimary)),
                    if (user?.email.isNotEmpty == true) ...[
                      SizedBox(height: AppSpacing.xs),
                      Text(user!.email,
                          style: context.textStyles.bodySmall?.withColor(
                              cs.onPrimary.withValues(alpha: 0.85))),
                    ],
                    SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _Badge(icon: Icons.waving_hand, label: 'Member'),
                        if ((user?.conditions.length ?? 0) > 0)
                          _Badge(
                              icon: Icons.health_and_safety_outlined,
                              label: '${user!.conditions.length} conditions'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.onPrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.onPrimary.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onPrimary),
          SizedBox(width: 6),
          Text(label,
              style: context.textStyles.labelMedium?.withColor(cs.onPrimary)),
        ],
      ),
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _AchievementsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unlocked = stats['unlocked'] ?? 0;
    final total = stats['total'] ?? 0;
    final points = stats['points'] ?? 0;

    return InkWell(
      onTap: () => context.push('/achievements'),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFD700).withValues(alpha: 0.15),
              const Color(0xFFFFA500).withValues(alpha: 0.15),
            ],
          ),
          border:
              Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.emoji_events,
                    color: const Color(0xFFFFD700), size: 28),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Achievements',
                        style: context.textStyles.titleMedium?.semiBold),
                    SizedBox(height: 4),
                    Text(
                      '$unlocked of $total unlocked • $points points',
                      style: context.textStyles.bodySmall
                          ?.withColor(cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConditionDetailsCard extends StatelessWidget {
  final List<Condition> conditions;
  final VoidCallback onRefresh;
  const _ConditionDetailsCard(
      {required this.conditions, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // `conditions` are hydrated with Condition.userDetail in the parent load.

    // Count how many conditions have details
    int detailsCount = 0;
    for (final c in conditions) {
      if (c.userDetail?.hasDetails == true) detailsCount++;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.tertiary.withValues(alpha: 0.12),
            cs.primary.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: cs.tertiary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border:
                        Border.all(color: cs.tertiary.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.tune, color: cs.tertiary, size: 24),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Condition Details',
                          style: context.textStyles.titleMedium?.semiBold),
                      SizedBox(height: 2),
                      Text(
                        detailsCount == 0
                            ? 'Add details to personalize your milestones'
                            : '$detailsCount of ${conditions.length} conditions detailed',
                        style: context.textStyles.bodySmall
                            ?.withColor(cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            // Show condition chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: conditions.map((c) {
                final detail = c.userDetail;
                final hasDetail = detail?.hasDetails == true;
                return _ConditionChip(
                  condition: c,
                  hasDetails: hasDetail,
                  existingDetail: detail,
                  onRefresh: onRefresh,
                );
              }).toList(),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Tap a condition to add injury level, mobility status, and more. This helps AI create better milestone plans for you.',
              style:
                  context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final Condition condition;
  final bool hasDetails;
  final ConditionDetail? existingDetail;
  final VoidCallback onRefresh;
  const _ConditionChip({
    required this.condition,
    required this.hasDetails,
    this.existingDetail,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ConditionDetailsSheet(
            condition: condition,
            existingDetail: existingDetail,
          ),
        );
        onRefresh();
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: hasDetails ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: hasDetails
                ? cs.primary.withValues(alpha: 0.4)
                : cs.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasDetails ? Icons.check_circle : Icons.add_circle_outline,
              size: 16,
              color: hasDetails ? cs.primary : cs.onSurfaceVariant,
            ),
            SizedBox(width: 6),
            Text(
              condition.name,
              style: context.textStyles.labelMedium?.withColor(
                hasDetails ? cs.onPrimaryContainer : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = context.watch<UserProvider>().currentUser;
    final prefs = user?.preferences ?? const {};
    final loc = (prefs['location'] as Map<String, dynamic>?) ?? const {};
    final hasLoc = loc.isNotEmpty && loc['lat'] != null && loc['lng'] != null;
    final label = (loc['label'] as String?)?.trim();
    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    final cc = (loc['countryCode'] as String?)?.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.06),
            cs.secondary.withValues(alpha: 0.06)
          ],
        ),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 420;

            Widget leadingIcon = Container(
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
              ),
              child: Icon(Icons.my_location, color: cs.primary),
            );

            Widget header = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Preferred location',
                    style: context.textStyles.titleMedium?.semiBold),
                if (hasLoc) ...[
                  SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.secondary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: cs.secondary.withValues(alpha: 0.16)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: cs.secondary),
                        SizedBox(width: 4),
                        Text('Saved',
                            style: context.textStyles.labelSmall
                                ?.withColor(cs.onSurface)),
                      ],
                    ),
                  ),
                ]
              ],
            );

            Widget chipsArea = hasLoc
                ? Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if ((label?.isNotEmpty ?? false))
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: cs.primary.withValues(alpha: 0.16)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.place, size: 16, color: cs.primary),
                              SizedBox(width: 6),
                              Text(
                                label!,
                                style: context.textStyles.labelMedium
                                    ?.withColor(cs.onSurface),
                              ),
                            ],
                          ),
                        ),
                      if (cc != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color:
                                    cs.outlineVariant.withValues(alpha: 0.20)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flag_outlined,
                                  size: 16, color: cs.onSurfaceVariant),
                              SizedBox(width: 6),
                              Text(
                                cc,
                                style: context.textStyles.labelMedium
                                    ?.withColor(cs.onSurface),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                : Text(
                    'No preferred location saved yet. Save one from Resources.',
                    style: context.textStyles.bodyMedium
                        ?.withColor(cs.onSurfaceVariant),
                  );

            Widget action = OutlinedButton.icon(
              onPressed: () => context.push('/resources'),
              icon: const Icon(Icons.edit_location_alt),
              label: const Text('Update'),
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      leadingIcon,
                      SizedBox(width: AppSpacing.md),
                      Expanded(child: header),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  chipsArea,
                  SizedBox(height: AppSpacing.sm),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                leadingIcon,
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      SizedBox(height: AppSpacing.xs),
                      chipsArea,
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}
