import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/post.dart';
import 'package:wellspring/models/user.dart' as models;
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/post_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/comments_sheet.dart';
import 'package:wellspring/widgets/post_card.dart';
import 'package:wellspring/widgets/skeletons.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _postService = PostService();
  final _userService = UserService();
  bool _loading = true;
  models.User? _user;
  List<Post> _posts = [];
  bool _pinned = false;
  bool _canView = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      setState(() => _loading = true);
      final u = await _userService.getUserById(widget.userId);
      // Determine visibility gating before fetching posts
      final me = context.read<UserProvider>().currentUser;
      String vis = 'community';
      if (u != null) {
        final prefs = u.preferences;
        vis = (prefs['privacy.visibility'] as String?) ?? 'community';
      }
      bool allowed;
      if (u == null) {
        allowed = false;
      } else if (me != null && me.id == u.id) {
        allowed = true; // always see your own
      } else if (vis == 'private') {
        allowed = false;
      } else if (vis == 'community') {
        allowed = me != null; // require sign-in
      } else {
        allowed = true; // public
      }

      List<Post> posts = const [];
      if (allowed) {
        posts = await _postService.getUserPosts(widget.userId);
      }
      final pinnedList = await _userService.getPinnedUsersOnce();
      if (!mounted) return;
      setState(() {
        _user = u;
        _posts = posts;
        _pinned = pinnedList.any((e) => e['id'] == widget.userId);
        _canView = allowed;
        _loading = false;
      });
    } catch (e) {
      debugPrint('UserProfileScreen._bootstrap error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _togglePin() async {
    try {
      final me = context.read<UserProvider>().currentUser;
      if (me == null || _user == null) return;
      if (_pinned) {
        await _userService.unpinUser(widget.userId);
      } else {
        await _userService.pinUser(
          targetUserId: widget.userId,
          targetName: _user!.name,
          targetImageUrl: _user!.profileImageUrl,
        );
      }
      if (!mounted) return;
      setState(() => _pinned = !_pinned);
    } catch (e) {
      debugPrint('UserProfileScreen._togglePin error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update pin')), // minimal feedback
      );
    }
  }

  Future<void> _handleLike(String postId) async {
    await _postService.likePost(postId);
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = _user?.name ?? 'Profile';
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CenteredLoadingSkeleton())
            : RefreshIndicator(
                onRefresh: _bootstrap,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          top: AppSpacing.lg,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: Icon(Icons.arrow_back, color: cs.onSurface),
                            ),
                            Expanded(
                              child: Text(
                                title,
                                style: context.textStyles.headlineMedium?.semiBold,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (_canView)
                            TextButton.icon(
                              onPressed: _togglePin,
                              icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
                              label: Text(_pinned ? 'Pinned' : 'Pin'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
                  if (_user != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: _HeaderCard(user: _user!),
                        ),
                      ),
                    SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
                  if (!_canView) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Card(
                          child: Padding(
                            padding: AppSpacing.paddingMd,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lock_outline, color: cs.onSurfaceVariant),
                                SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    'This profile is private',
                                    style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Text('Posts', style: context.textStyles.titleLarge?.semiBold),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
                    if (_posts.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: Card(
                            child: Padding(
                              padding: AppSpacing.paddingMd,
                              child: Row(
                                children: [
                                  Icon(Icons.article_outlined, color: cs.onSurfaceVariant),
                                  SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      'No posts yet.',
                                      style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
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
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                                  ),
                                  builder: (_) => CommentsSheet(post: p, service: _postService),
                                ).then((_) => _bootstrap());
                              },
                              onDeleted: _bootstrap,
                            );
                          },
                        ),
                      ),
                  ],
                    SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final models.User user;
  const _HeaderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = (user.name.isNotEmpty ? user.name[0] : '?').toUpperCase();
    final url = user.profileImageUrl?.trim();

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

    return Card(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primaryContainer,
                image: provider != null
                    ? DecorationImage(image: provider, fit: BoxFit.cover)
                    : null,
              ),
              alignment: Alignment.center,
              child: provider == null
                  ? Text(initial, style: context.textStyles.headlineSmall?.withColor(cs.onPrimaryContainer))
                  : null,
            ),
            SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: context.textStyles.titleLarge?.semiBold),
                  if (user.email.isNotEmpty) ...[
                    SizedBox(height: AppSpacing.xs),
                    Text(user.email, style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
                  ],
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
