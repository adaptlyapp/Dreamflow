import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/group.dart';
import 'package:wellspring/models/post.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/group_service.dart';
import 'package:wellspring/services/post_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/post_card.dart';
import 'package:wellspring/widgets/comments_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:wellspring/widgets/skeletons.dart';
import 'package:uuid/uuid.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;
  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final _groups = GroupService();
  final _posts = PostService();
  Group? _group;
  bool _loading = true;
  List<Post> _items = [];
  bool _loadingPosts = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final g = await _groups.getGroupById(widget.communityId);
    setState(() {
      _group = g;
      _loading = false;
    });
    await _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final items = await _posts.getCommunityPosts(widget.communityId);
      setState(() {
        _items = items;
        _loadingPosts = false;
      });
    } catch (e) {
      debugPrint('CommunityDetail._loadPosts error: $e');
      setState(() {
        _items = [];
        _loadingPosts = false;
      });
    }
  }

  Future<void> _joinOrLeave() async {
    if (_group == null) return;
    try {
      if (_group!.isJoined) {
        await _groups.leaveGroup(_group!.id);
      } else {
        await _groups.joinGroup(_group!.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      await _load();
    }
  }

  Future<void> _openComposer() async {
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => _ComposeCommunityPostSheet(
        communityId: widget.communityId,
        postService: _posts,
      ),
    );
    await _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading || _group == null) {
      return const Scaffold(body: Center(child: CenteredLoadingSkeleton()));
    }
    final g = _group!;
    final uid = context.read<UserProvider>().currentUser?.id ?? auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    final isOwner = uid.isNotEmpty && (uid == (g.ownerId ?? ''));
    final isPending = g.membershipStatus == 'pending';
    return Scaffold(
      appBar: AppBar(
        title: Text(g.name),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => _openManageSheet(g),
              tooltip: 'Manage',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            Container(
              padding: AppSpacing.paddingLg,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: scheme.primary,
                        child: Icon(
                          g.type == 'condition' ? Icons.medical_information_outlined : Icons.interests_outlined,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(g.name, style: context.textStyles.titleLarge?.semiBold, overflow: TextOverflow.ellipsis)),
                                if (isOwner)
                                  Padding(
                                    padding: EdgeInsets.only(left: AppSpacing.xs),
                                    child: Icon(Icons.shield_outlined, size: 18, color: scheme.primary),
                                  ),
                              ],
                            ),
                            Row(children: [
                              Icon(g.privacy == 'private' ? Icons.lock_outline : Icons.public, size: 16, color: scheme.onSurfaceVariant),
                              SizedBox(width: 4),
                              Text('${g.memberCount} members • ${g.privacy == 'private' ? 'Private' : 'Open'}', style: context.textStyles.bodySmall?.withColor(scheme.onSurfaceVariant)),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(g.description, style: context.textStyles.bodyMedium),
                  SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: () {
                          if (isOwner) {
                            return OutlinedButton.icon(
                              onPressed: () => _openManageSheet(g),
                              icon: const Icon(Icons.admin_panel_settings_outlined),
                              label: const Text('Manage'),
                            );
                          }
                          if (g.isJoined) {
                            return OutlinedButton.icon(
                              onPressed: _joinOrLeave,
                              icon: const Icon(Icons.logout),
                              label: const Text('Leave'),
                            );
                          }
                          if (isPending) {
                            return OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.hourglass_empty),
                              label: const Text('Requested'),
                            );
                          }
                          return FilledButton.icon(
                            onPressed: _joinOrLeave,
                            icon: const Icon(Icons.group_add, color: Colors.white),
                            label: Text(g.privacy == 'private' ? 'Request to join' : 'Join'),
                          );
                        }(),
                      ),
                      if (g.isJoined) ...[
                        SizedBox(width: AppSpacing.sm),
                        FilledButton.icon(
                          onPressed: _openComposer,
                          icon: const Icon(Icons.edit, color: Colors.white),
                          label: const Text('Write post'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Posts
            Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: _loadingPosts
                  ? const Center(child: CenteredLoadingSkeleton())
                  : _items.isEmpty
                      ? Center(
                          child: Column(
                            children: [
                              const Icon(Icons.forum_outlined, size: 64),
                              SizedBox(height: AppSpacing.md),
                              Text('No posts yet', style: context.textStyles.titleMedium),
                              if (g.isJoined) ...[
                                SizedBox(height: AppSpacing.md),
                                FilledButton.icon(
                                  onPressed: _openComposer,
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  label: const Text('Start the conversation'),
                                ),
                              ]
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            for (final p in _items)
                              PostCard(
                                post: p,
                                onLike: () async {
                                  await _posts.likePost(p.id);
                                  await _loadPosts();
                                },
                                onComment: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    showDragHandle: true,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                                    ),
                                    builder: (context) => CommentsSheet(post: p, service: _posts),
                                  ).then((_) => _loadPosts());
                                },
                                onDeleted: _loadPosts,
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openManageSheet(Group g) async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => _ManageMembersSheet(group: g, service: _groups),
    );
    if (deleted == true) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Community deleted')));
      }
      return;
    }
    await _load();
  }
}

class _ComposeCommunityPostSheet extends StatefulWidget {
  final String communityId;
  final PostService postService;
  const _ComposeCommunityPostSheet({required this.communityId, required this.postService});

  @override
  State<_ComposeCommunityPostSheet> createState() => _ComposeCommunityPostSheetState();
}

class _ComposeCommunityPostSheetState extends State<_ComposeCommunityPostSheet> {
  final _content = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _content.text.trim();
    if (text.isEmpty) return;
    final user = context.read<UserProvider>().currentUser;
    if (user == null) return;
    setState(() => _posting = true);
    final now = DateTime.now();
    final postId = const Uuid().v4();
    final post = Post(
      id: postId,
      authorId: user.id,
      authorName: user.name,
      content: text,
      mediaUrl: null,
      mediaType: null,
      communityId: widget.communityId,
      type: 'community',
      relatedConditions: user.conditions,
      likesCount: 0,
      commentsCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await widget.postService.addPost(post);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Write a post', style: context.textStyles.titleLarge?.semiBold),
              SizedBox(height: AppSpacing.md),
              TextField(
                controller: _content,
                minLines: 3,
                maxLines: 7,
                decoration: InputDecoration(
                  hintText: 'Share an update, experience, or question…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _posting ? null : _submit,
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: Text(_posting ? 'Posting…' : 'Post'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _ManageMembersSheet extends StatefulWidget {
  final Group group;
  final GroupService service;
  const _ManageMembersSheet({required this.group, required this.service});

  @override
  State<_ManageMembersSheet> createState() => _ManageMembersSheetState();
}

class _ManageMembersSheetState extends State<_ManageMembersSheet> {
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = await widget.service.getPendingRequests(widget.group.id);
    setState(() {
      _pending = p;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.paddingLg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manage members', style: context.textStyles.titleLarge?.semiBold),
          SizedBox(height: AppSpacing.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: const Center(child: CenteredLoadingSkeleton()),
            )
          else if (_pending.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.inbox_outlined),
                  const SizedBox(width: 8),
                  Text('No pending requests', style: context.textStyles.bodyMedium),
                ],
              ),
            )
          else
            ...[
              Text('Pending requests', style: context.textStyles.labelLarge?.semiBold),
              SizedBox(height: AppSpacing.sm),
              for (final r in _pending)
                Card(
                  child: Padding(
                    padding: AppSpacing.paddingMd,
                    child: Row(
                      children: [
                        CircleAvatar(
                          child: Text((r['displayName'] as String? ?? 'User').substring(0, 1).toUpperCase()),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(child: Text(r['displayName'] as String? ?? r['userId'] as String)),
                        IconButton(
                          tooltip: 'Reject',
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            await widget.service.rejectMember(widget.group.id, r['userId'] as String);
                            await _load();
                          },
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            await widget.service.approveMember(widget.group.id, r['userId'] as String);
                            await _load();
                          },
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text('Approve'),
                        )
                      ],
                    ),
                  ),
                )
            ],

          // Danger zone
          SizedBox(height: AppSpacing.lg),
          Divider(height: 1),
          SizedBox(height: AppSpacing.lg),
          Text('Danger zone', style: context.textStyles.labelLarge?.semiBold),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Delete this community and all of its posts, comments, and memberships. This action cannot be undone.',
            style: context.textStyles.bodySmall?.withColor(Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _deleting ? null : () => _confirmDelete(context),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              label: Text(_deleting ? 'Deleting…' : 'Delete community'),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete community?', style: context.textStyles.titleLarge?.semiBold),
              SizedBox(height: AppSpacing.sm),
              Text(
                'This will permanently remove the community, its posts, comments, and memberships.',
                style: context.textStyles.bodyMedium?.withColor(scheme.onSurfaceVariant),
              ),
              SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      ),
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom),
            ],
          ),
        );
      },
    );
    if (confirmed == true) {
      await _deleteNow();
    }
  }

  Future<void> _deleteNow() async {
    setState(() => _deleting = true);
    try {
      await widget.service.deleteGroup(widget.group.id);
      if (!mounted) return;
      Navigator.of(context).pop(true); // close manage sheet and signal deletion
    } catch (e) {
      debugPrint('ManageMembers: delete error $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}
