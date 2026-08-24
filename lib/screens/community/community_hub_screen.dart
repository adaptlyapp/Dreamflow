import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/group.dart';
import 'package:wellspring/models/post.dart';
import 'package:wellspring/models/resource.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:wellspring/services/group_service.dart';
import 'package:wellspring/services/post_service.dart';
import 'package:wellspring/services/resource_service.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/widgets/post_card.dart';
import 'package:wellspring/widgets/comments_sheet.dart';
import 'package:wellspring/widgets/rating_stars.dart';
import 'package:wellspring/services/ratings_service.dart';
import 'package:wellspring/models/resource_rating.dart';
import 'package:wellspring/widgets/hours_badge.dart';
import 'package:wellspring/widgets/phone_link.dart';
import 'package:wellspring/widgets/recommend_resource_sheet.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/widgets/glass_card.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
// Saved-location: explicit save to profile is supported via UserService

class CommunityHubScreen extends StatefulWidget {
  final String? initialTab; // 'feed' | 'communities' | 'resources' | 'explore'
  const CommunityHubScreen({super.key, this.initialTab});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _controller;
  static const double _topTabsHeight = 56;
  static const double _expandedAppBarHeight = 164;

  @override
  void initState() {
    super.initState();
    final startIndex = () {
      switch (widget.initialTab) {
        case 'communities':
          return 1;
        case 'resources':
          return 2;
        case 'explore':
          return 3;
        default:
          return 0;
      }
    }();
    _controller =
        TabController(length: 4, vsync: this, initialIndex: startIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final gradients = Theme.of(context).extension<AppGradients>();

    return GlassyScaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: false,
            snap: false,
            backgroundColor: scheme.surface,
            surfaceTintColor: scheme.surface,
            elevation: 0,
            expandedHeight: _expandedAppBarHeight,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                // NestedScrollView + SliverAppBar + TabBar can cause the flexible title
                // to paint under the TabBar if we rely on FlexibleSpaceBar.title.
                // This custom layout keeps the subtitle *above* the TabBar and fades
                // it out as the app bar collapses.
                final minHeight = kToolbarHeight + _topTabsHeight;
                final maxHeight = _expandedAppBarHeight;
                final t = ((constraints.maxHeight - minHeight) /
                        (maxHeight - minHeight))
                    .clamp(0.0, 1.0);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration:
                          BoxDecoration(gradient: gradients?.backgroundGlow),
                      child: const SizedBox.expand(),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          _topTabsHeight + AppSpacing.sm,
                        ),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Community & Resources',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyles.titleLarge?.semiBold,
                              ),
                              SizedBox(height: AppSpacing.xs),
                              ClipRect(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  heightFactor: t,
                                  child: Opacity(
                                    opacity: t,
                                    child: Text(
                                      'Find support, share updates, and discover trusted places.',
                                      style: context.textStyles.bodySmall
                                          ?.withColor(scheme.onSurfaceVariant),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            actions: [
              Padding(
                padding: EdgeInsetsDirectional.only(end: AppSpacing.md),
                child: IconButton(
                  tooltip: 'Recommend a place',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      showDragHandle: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadius.lg),
                        ),
                      ),
                      builder: (_) => const RecommendResourceSheet(),
                    );
                  },
                  icon: Icon(Icons.add_location_alt_outlined,
                      color: scheme.onSurface),
                ),
              )
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(_topTabsHeight),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: _controller,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    tabs: const [
                      Tab(text: 'Feed'),
                      Tab(text: 'Communities'),
                      Tab(text: 'Resources'),
                      Tab(text: 'Explore'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _controller,
          children: const [
            _FeedTab(),
            _CommunitiesTab(),
            _ResourcesTab(),
            _ExploreTab(),
          ],
        ),
      ),
    );
  }
}

class _FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;
  const _FadeSlideIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    // Keep animations subtle; cap stagger so long lists don't feel laggy.
    final staggerMs = (index.clamp(0, 10)) * 35;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 380 + staggerMs),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) {
        final v = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 10),
            child: child,
          ),
        );
      },
    );
  }
}

class _FeedTab extends StatefulWidget {
  const _FeedTab();

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  final _postService = PostService();
  final _conditionService = ConditionService();
  List<Post> _posts = [];
  bool _loading = true;
  List<Condition> _myConditions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = context.read<UserProvider>().currentUser;
    final posts = await _postService.getPersonalizedFeed(
      userConditions: user?.conditions,
    );
    // Load user's condition objects for composer chips
    final allConds = await _conditionService.getAllConditions();
    final mine = (user?.conditions ?? []);
    setState(() {
      _posts = posts;
      _loading = false;
      _myConditions = allConds.where((c) => mine.contains(c.id)).toList();
    });
  }

  Future<void> _like(String id) async {
    await _postService.likePost(id);
    await _load();
  }

  void _openComments(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => CommentsSheet(post: post, service: _postService),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CenteredLoadingSkeleton());
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            SizedBox(height: AppSpacing.md),
            Text('No posts yet',
                style: context.textStyles.titleLarge?.withColor(
                    Theme.of(context).colorScheme.onSurfaceVariant)),
            SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () async {
                final posted = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.lg)),
                  ),
                  builder: (context) => _ComposePostSheet(
                    service: _postService,
                    myConditions: _myConditions,
                  ),
                );
                if (posted == true) {
                  await _load();
                }
              },
              icon: Icon(Icons.add, color: Colors.white),
              label: const Text('Create your first post'),
            )
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: EdgeInsets.all(AppSpacing.lg),
        itemCount: _posts.length + 1,
        itemBuilder: (context, i) {
          if (i == 0)
            return _ComposerTeaser(onTap: () async {
              final posted = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                ),
                builder: (context) => _ComposePostSheet(
                  service: _postService,
                  myConditions: _myConditions,
                ),
              );
              if (posted == true) {
                await _load();
              }
            });
          final post = _posts[i - 1];
          return PostCard(
            post: post,
            onLike: () => _like(post.id),
            onComment: () => _openComments(post),
            onDeleted: _load,
          );
        },
      ),
    );
  }
}

class _ComposerTeaser extends StatelessWidget {
  final VoidCallback onTap;
  const _ComposerTeaser({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child:
                    Icon(Icons.add_comment, color: scheme.onPrimaryContainer),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Share something with your community…',
                  style: context.textStyles.bodyMedium
                      ?.withColor(scheme.onSurfaceVariant),
                ),
              ),
              Icon(Icons.edit_outlined, color: scheme.onSurfaceVariant)
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposePostSheet extends StatefulWidget {
  final PostService service;
  final List<Condition> myConditions;
  const _ComposePostSheet({required this.service, required this.myConditions});

  @override
  State<_ComposePostSheet> createState() => _ComposePostSheetState();
}

class _ComposePostSheetState extends State<_ComposePostSheet> {
  final _content = TextEditingController();
  final _mediaUrl = TextEditingController();
  String _mediaKind = 'none'; // none | image | video
  late List<String> _selectedConditions;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _selectedConditions = widget.myConditions.map((c) => c.id).toList();
  }

  @override
  void dispose() {
    _content.dispose();
    _mediaUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _content.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    final user = context.read<UserProvider>().currentUser;
    final now = DateTime.now();
    final post = Post(
      id: const Uuid().v4(),
      authorId: user?.id ?? 'me',
      authorName: user?.name ?? 'You',
      content: text,
      mediaUrl: _mediaKind == 'none'
          ? null
          : _mediaUrl.text.trim().isEmpty
              ? null
              : _mediaUrl.text.trim(),
      mediaType: _mediaKind == 'none' ? null : _mediaKind,
      type: 'community',
      relatedConditions: _selectedConditions,
      likesCount: 0,
      commentsCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    await widget.service.addPost(post);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Create post',
                  style: context.textStyles.titleLarge?.semiBold),
              SizedBox(height: AppSpacing.md),
              TextField(
                controller: _content,
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                ),
                minLines: 3,
                maxLines: 6,
              ),
              SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const Text('No media'),
                    selected: _mediaKind == 'none',
                    onSelected: (_) => setState(() => _mediaKind = 'none'),
                  ),
                  ChoiceChip(
                    label: const Text('Image URL'),
                    selected: _mediaKind == 'image',
                    onSelected: (_) => setState(() => _mediaKind = 'image'),
                  ),
                  ChoiceChip(
                    label: const Text('Video URL'),
                    selected: _mediaKind == 'video',
                    onSelected: (_) => setState(() => _mediaKind = 'video'),
                  ),
                ],
              ),
              if (_mediaKind != 'none') ...[
                SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _mediaUrl,
                  decoration: InputDecoration(
                    hintText: _mediaKind == 'image'
                        ? 'Paste image URL (https://...)'
                        : 'Paste video URL (https://...)',
                    prefixIcon: Icon(_mediaKind == 'image'
                        ? Icons.image_outlined
                        : Icons.play_circle_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
              if (widget.myConditions.isNotEmpty) ...[
                SizedBox(height: AppSpacing.md),
                Text('Related conditions',
                    style: context.textStyles.labelLarge?.semiBold),
                SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final c in widget.myConditions)
                      FilterChip(
                        label: Text(c.name),
                        selected: _selectedConditions.contains(c.id),
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _selectedConditions.add(c.id);
                            } else {
                              _selectedConditions.remove(c.id);
                            }
                          });
                        },
                        padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      ),
                  ],
                ),
              ],
              SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _posting ? null : _submit,
                  icon: Icon(Icons.send, color: Colors.white),
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

// CommentsSheet moved to lib/widgets/comments_sheet.dart and used here

class _CommunitiesTab extends StatefulWidget {
  const _CommunitiesTab();

  @override
  State<_CommunitiesTab> createState() => _CommunitiesTabState();
}

class _CommunitiesTabState extends State<_CommunitiesTab>
    with SingleTickerProviderStateMixin {
  final _groupService = GroupService();
  List<Group> _all = [];
  List<Group> _displayed = [];
  bool _loading = true;
  late TabController _filterController;

  @override
  void initState() {
    super.initState();
    _filterController = TabController(length: 3, vsync: this);
    _filterController.addListener(() => _applyFilter());
    // Ensure user is loaded so owner checks work
    final userProv = context.read<UserProvider>();
    if (userProv.currentUser == null) {
      userProv.loadUser();
    }
    _load();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _load({bool preserveOnEmpty = false}) async {
    setState(() => _loading = true);
    final groups = await _groupService.getAllGroups();
    if (preserveOnEmpty && groups.isEmpty && _all.isNotEmpty) {
      // Keep the locally inserted list (likely reads are blocked by rules)
      debugPrint(
          'CommunitiesHub: keeping local list due to empty refresh (possibly permission-denied)');
      setState(() {
        _applyFilter();
        _loading = false;
      });
      return;
    }
    setState(() {
      _all = groups;
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    final keys = ['all', 'condition', 'interest'];
    final key = keys[_filterController.index];
    setState(() {
      _displayed =
          key == 'all' ? _all : _all.where((g) => g.type == key).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CenteredLoadingSkeleton());
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                  child: Text('Communities',
                      style: context.textStyles.titleLarge?.semiBold)),
              FilledButton.icon(
                onPressed: () async {
                  final typeForSheet = () {
                    final idx = _filterController.index;
                    if (idx == 1) return 'condition';
                    if (idx == 2) return 'interest';
                    return 'interest';
                  }();
                  final created = await showModalBottomSheet<Group?>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadius.lg)),
                    ),
                    builder: (context) =>
                        _CreateCommunitySheet(initialType: typeForSheet),
                  );
                  if (created != null) {
                    setState(() {
                      _all = [created, ..._all];
                      // Switch to created type tab if filtered out
                      if (created.type == 'condition' &&
                          _filterController.index != 1) {
                        _filterController.index = 1;
                      } else if (created.type == 'interest' &&
                          _filterController.index != 2) {
                        _filterController.index = 2;
                      }
                      _applyFilter();
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Community created')),
                      );
                    }
                  }
                  // Background refresh but keep local if reads are blocked
                  await _load(preserveOnEmpty: true);
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Create'),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _filterController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Condition'),
            Tab(text: 'Interest')
          ],
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        Expanded(
          child: _displayed.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      SizedBox(height: AppSpacing.md),
                      Text('No communities found',
                          style: context.textStyles.titleLarge?.withColor(
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        'Try switching categories or create one for your interests.',
                        textAlign: TextAlign.center,
                        style: context.textStyles.bodyMedium
                            ?.withColor(scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                      AppSpacing.lg, AppSpacing.xl),
                  itemCount: _displayed.length,
                  separatorBuilder: (_, __) => SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final group = _displayed[i];
                    return _FadeSlideIn(
                      index: i,
                      child: _HubCommunityCard(
                        group: group,
                        onTap: () => context.push('/group/${group.id}'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _HubCommunityCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  const _HubCommunityCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = context.read<UserProvider>().currentUser?.id ??
        auth.FirebaseAuth.instance.currentUser?.uid;
    final isOwner = (uid != null && uid.isNotEmpty) && (group.ownerId == uid);

    IconData typeIcon() => group.type == 'condition'
        ? Icons.medical_information_outlined
        : Icons.interests_outlined;

    return GlassCard(
      onTap: onTap,
      padding: AppSpacing.paddingLg,
      borderRadius: AppRadius.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: Icon(typeIcon(), color: scheme.onPrimaryContainer),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: context.textStyles.titleMedium?.semiBold,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOwner)
                          Padding(
                            padding: EdgeInsets.only(left: AppSpacing.xs),
                            child: Icon(Icons.shield_outlined,
                                size: 18, color: scheme.primary),
                          ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                            group.privacy == 'private'
                                ? Icons.lock_outline
                                : Icons.public,
                            size: 14,
                            color: scheme.onSurfaceVariant),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${group.memberCount} members • ${group.privacy == 'private' ? 'Private' : 'Open'}',
                            style: context.textStyles.bodySmall
                                ?.withColor(scheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            group.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.bodyMedium
                ?.withColor(scheme.onSurfaceVariant),
          ),
          SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MetaPill(
                icon: group.type == 'condition'
                    ? Icons.medical_services_outlined
                    : Icons.tag,
                label: group.type == 'condition'
                    ? 'Condition group'
                    : 'Interest group',
              ),
              if ((group.relatedCondition ?? '').trim().isNotEmpty)
                _MetaPill(
                    icon: Icons.link, label: group.relatedCondition!.trim()),
              if (isOwner)
                _MetaPill(icon: Icons.verified_user_outlined, label: 'Owner'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          SizedBox(width: 6),
          Text(label,
              style: context.textStyles.labelSmall
                  ?.withColor(scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _CreateCommunitySheet extends StatefulWidget {
  final String initialType; // 'interest' | 'condition'
  const _CreateCommunitySheet({this.initialType = 'interest'});

  @override
  State<_CreateCommunitySheet> createState() => _CreateCommunitySheetState();
}

class _CreateCommunitySheetState extends State<_CreateCommunitySheet> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String _type = 'interest';
  String? _relatedCondition;
  String _privacy = 'open';
  bool _saving = false;
  final _service = GroupService();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.initialType == 'condition' || widget.initialType == 'interest') {
      _type = widget.initialType;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    debugPrint('CreateCommunity(Hub): submit tapped');
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      debugPrint('CreateCommunity(Hub): form invalid');
      return;
    }
    setState(() => _saving = true);
    try {
      debugPrint(
          'CreateCommunity(Hub): creating name="${_name.text.trim()}" type=$_type privacy=$_privacy');
      final created = await _service.createGroup(
        name: _name.text.trim(),
        description: _desc.text.trim(),
        type: _type,
        relatedCondition: _type == 'condition' ? _relatedCondition : null,
        privacy: _privacy,
      );
      if (!mounted) return;
      debugPrint('CreateCommunity(Hub): created id=${created.id}');
      Navigator.of(context).pop(created);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to create: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Create community',
                    style: context.textStyles.titleLarge?.semiBold),
                SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Please enter a name';
                    if (t.length < 3)
                      return 'Name must be at least 3 characters';
                    return null;
                  },
                ),
                SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _desc,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Please enter a short description';
                    return null;
                  },
                ),
                SizedBox(height: AppSpacing.md),
                Text('Category',
                    style: context.textStyles.labelLarge?.semiBold),
                SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Interest'),
                      selected: _type == 'interest',
                      onSelected: (_) => setState(() {
                        _type = 'interest';
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Condition'),
                      selected: _type == 'condition',
                      onSelected: (_) => setState(() {
                        _type = 'condition';
                      }),
                    ),
                  ],
                ),
                if (_type == 'condition') ...[
                  SizedBox(height: AppSpacing.md),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Related Condition ID (optional)',
                      hintText: 'e.g., "ms"',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                    ),
                    onChanged: (v) =>
                        _relatedCondition = v.trim().isEmpty ? null : v.trim(),
                  ),
                ],
                SizedBox(height: AppSpacing.md),
                Text('Access', style: context.textStyles.labelLarge?.semiBold),
                SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Open access'),
                      selected: _privacy == 'open',
                      onSelected: (_) => setState(() {
                        _privacy = 'open';
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Private (approval)'),
                      selected: _privacy == 'private',
                      onSelected: (_) => setState(() {
                        _privacy = 'private';
                      }),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: Text(_saving ? 'Creating…' : 'Create community'),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResourcesTab extends StatefulWidget {
  const _ResourcesTab();

  @override
  State<_ResourcesTab> createState() => _ResourcesTabState();
}

class _ExploreTab extends StatefulWidget {
  const _ExploreTab();

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> {
  final _service = ResourceService();
  final _location = TextEditingController();
  double? _userLat;
  double? _userLng;
  double _radiusMiles = 10; // default radius
  bool _loading = true;
  List<Resource> _items = [];
  bool _triedDeviceLocation = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Try device location once so Explore can “just display” when permission is granted.
      if ((_userLat == null || _userLng == null) && !_triedDeviceLocation) {
        _triedDeviceLocation = true;
        await _useDeviceLocation(silent: true);
      }

      // When still no coordinates, show empty and ask for a location
      if (_userLat == null || _userLng == null) {
        setState(() {
          _items = [];
          _loading = false;
        });
        return;
      }

      final approved = await _service.getApprovedNearbyResources(
        userLat: _userLat!,
        userLng: _userLng!,
        maxDistanceMiles: _radiusMiles,
      );

      if (!mounted) return;
      setState(() {
        _items = approved;
        _loading = false;
      });
    } catch (e) {
      debugPrint('ExploreTab _load error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _useDeviceLocation({required bool silent}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission not granted.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
      });
      await _load();
    } catch (e) {
      debugPrint('ExploreTab device location error: $e');
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get your current location.')),
        );
      }
    }
  }

  Future<void> _useTypedLocation() async {
    final q = _location.text.trim();
    if (q.isEmpty) return;
    try {
      final geo = await _service.geocodeAddress(q);
      if (geo != null) {
        setState(() {
          _userLat = (geo['lat'] as num).toDouble();
          _userLng = (geo['lng'] as num).toDouble();
        });
        await _load();
      }
    } catch (e) {
      debugPrint('ExploreTab geocode error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(
            'Explore nearby (approved)',
            style: context.textStyles.titleLarge?.semiBold,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _location,
                  decoration: const InputDecoration(
                    hintText: 'Enter a city or ZIP',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _useTypedLocation(),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              FilledButton(
                  onPressed: _useTypedLocation, child: const Text('Set')),
              SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: 'Use my location',
                onPressed: () => _useDeviceLocation(silent: false),
                icon: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Row(
            children: [
              Text(
                'Within ${_radiusMiles.toStringAsFixed(0)} mi',
                style: context.textStyles.labelLarge,
              ),
              Expanded(
                child: Slider(
                  value: _radiusMiles,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: '${_radiusMiles.toStringAsFixed(0)} mi',
                  onChanged: (v) => setState(() => _radiusMiles = v),
                  onChangeEnd: (_) => _load(),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Expanded(
          child: _loading
              ? const Center(child: CenteredLoadingSkeleton())
              : (_userLat == null || _userLng == null)
                  ? Center(
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            SizedBox(height: AppSpacing.md),
                            Text(
                              'Search a location to see approved recommendations nearby.',
                              textAlign: TextAlign.center,
                              style: context.textStyles.bodyLarge?.withColor(
                                Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : (_items.isEmpty)
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.place_outlined,
                                size: 64,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              SizedBox(height: AppSpacing.md),
                              Text(
                                'No approved places within ${_radiusMiles.toStringAsFixed(0)} miles',
                                style:
                                    context.textStyles.titleMedium?.withColor(
                                  Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding:
                              EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          itemCount: _items.length,
                          itemBuilder: (context, i) =>
                              _HubResourceCard(resource: _items[i]),
                        ),
        ),
      ],
    );
  }
}

class _ResourcesTabState extends State<_ResourcesTab> {
  final _service = ResourceService();
  final _query = TextEditingController();
  final _location = TextEditingController();
  final _userService = UserService();
  final _ratingsService = RatingsService();
  String _type = 'all';
  List<Resource> _items = [];
  // Keep the full list from the latest fetch; search filters this locally
  List<Resource> _allItems = [];
  bool _loading = true;
  final Map<String, ResourceRatingSummary> _summaries = {};
  // Location-aware state
  double? _userLat;
  double? _userLng;
  String? _userLocationLabel;
  double? _maxDistanceMiles; // null => All distances
  // Saved-location removed: no profile syncing
  // Advanced filters
  bool _openNow = false;
  double _minRating = 0;
  int _minReviews = 0;
  final Set<int> _priceLevels = <int>{};
  bool _sortByRating = false;
  bool _rankByDistance = false;
  final Set<String> _googleTypes = <String>{};
  String? _region;
  String? _language = 'en';
  // Therapists: exact name filter
  bool _therapyNameOnly = false;
  // Debounce for type-to-search
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _service.searchResources(
      // Always fetch by location and filters; apply text search locally
      query: null,
      type: _type == 'all' ? null : _type,
      location: null,
      userLat: _userLat,
      userLng: _userLng,
      maxDistance: _maxDistanceMiles,
      openNow: _openNow,
      minRating: _minRating > 0 ? _minRating : null,
      minUserRatings: _minReviews > 0 ? _minReviews : null,
      priceLevels: _priceLevels.isEmpty ? null : _priceLevels.toList(),
      sortByRating: _sortByRating,
      language: _language,
      region: _region,
      rankBy: _rankByDistance ? 'distance' : 'prominence',
      includeGoogleTypes: _googleTypes.isEmpty ? null : _googleTypes.toList(),
    );
    // Apply therapist name strict/group preference
    List<Resource> adjusted = res;
    if (_type == 'therapist') {
      bool isTherapyName(Resource r) {
        final n = r.name.toLowerCase();
        return n.contains('therapy') || n.contains('therapist');
      }

      if (_therapyNameOnly) {
        adjusted = adjusted.where(isTherapyName).toList();
      } else {
        adjusted.sort((a, b) {
          final aExact = (a.name.toLowerCase().contains('therapy') ||
                  a.name.toLowerCase().contains('therapist'))
              ? 1
              : 0;
          final bExact = (b.name.toLowerCase().contains('therapy') ||
                  b.name.toLowerCase().contains('therapist'))
              ? 1
              : 0;
          if (aExact != bExact) return bExact.compareTo(aExact);
          return a.distance.compareTo(b.distance);
        });
      }
    }
    if (!mounted) return;
    setState(() {
      _allItems = adjusted;
      _loading = false;
    });
    // Apply any in-progress text filter to the freshly loaded list
    _applyLocalTextFilter();
    unawaited(_loadRatings());
  }

  void _debouncedSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _applyLocalTextFilter();
    });
  }

  void _runSearch() {
    // Only filter locally; fetching happens when location/filters change
    _applyLocalTextFilter();
  }

  void _applyLocalTextFilter() {
    final q = _query.text.trim().toLowerCase();
    debugPrint(
        'CommunityHub.ResourcesTab._applyLocalTextFilter q="$q" all=${_allItems.length}');
    if (q.isEmpty) {
      setState(() {
        _items = List<Resource>.from(_allItems);
      });
      debugPrint(
          'CommunityHub.ResourcesTab._applyLocalTextFilter -> reset to ${_items.length} items');
      return;
    }
    final filtered = _allItems.where((r) {
      final n = r.name.toLowerCase();
      final addr = r.address.toLowerCase();
      final loc = r.location.toLowerCase();
      final typ = r.type.toLowerCase();
      final specs = r.specialty.map((s) => s.toLowerCase());
      return n.contains(q) ||
          addr.contains(q) ||
          loc.contains(q) ||
          typ.contains(q) ||
          specs.any((s) => s.contains(q));
    }).toList();
    setState(() => _items = filtered);
    debugPrint(
        'CommunityHub.ResourcesTab._applyLocalTextFilter -> ${filtered.length} items');
  }

  Future<void> _loadRatings() async {
    try {
      final ids = _items.take(20).map((r) => r.id).toList();
      if (ids.isEmpty) return;
      final batch = await _ratingsService.getSummariesBatch(ids);
      if (!mounted) return;
      setState(() => _summaries.addAll(batch));
      final googleIds = ids.where((id) => id.startsWith('gpl_')).take(6);
      for (final id in googleIds) {
        unawaited(_ratingsService.ensureFreshGoogleSummary(id).then((s) {
          if (!mounted) return;
          setState(() => _summaries[id] = s);
        }));
      }
    } catch (e) {
      debugPrint('CommunityHub._ResourcesTab _loadRatings error: $e');
    }
  }

  Resource _applySummary(Resource r) {
    final s = _summaries[r.id];
    if (s == null) return r;
    if (s.countCombined > 0 && s.avgCombined > 0) {
      return r.copyWith(rating: s.avgCombined, reviewCount: s.countCombined);
    }
    return r;
  }

  // Saved-location removed: we only use typed location while browsing

  void _openFiltersSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        bool tOpenNow = _openNow;
        double tMinRating = _minRating;
        int tMinReviews = _minReviews;
        final Set<int> tPrices = {..._priceLevels};
        bool tSortByRating = _sortByRating;
        bool tRankByDistance = _rankByDistance;
        final Set<String> tTypes = {..._googleTypes};
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              final cs = Theme.of(ctx).colorScheme;
              Widget priceChip(int level) => FilterChip(
                    label: Text([
                      '\$',
                      '\$\$',
                      '\$\$\$',
                      '\$\$\$\$',
                      '\$\$\$\$\$'
                    ][level]),
                    selected: tPrices.contains(level),
                    onSelected: (_) => setSheet(() {
                      if (tPrices.contains(level))
                        tPrices.remove(level);
                      else
                        tPrices.add(level);
                    }),
                  );
              FilterChip typeChip(String label, String type) => FilterChip(
                    label: Text(label),
                    selected: tTypes.contains(type),
                    onSelected: (_) => setSheet(() {
                      if (tTypes.contains(type))
                        tTypes.remove(type);
                      else
                        tTypes.add(type);
                    }),
                  );
              return SafeArea(
                child: Padding(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.tune, color: cs.primary),
                        SizedBox(width: AppSpacing.sm),
                        Text('Fine-tune results',
                            style: context.textStyles.titleLarge?.semiBold),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheet(() {
                              tOpenNow = false;
                              tMinRating = 0;
                              tMinReviews = 0;
                              tPrices.clear();
                              tSortByRating = false;
                              tRankByDistance = false;
                              tTypes.clear();
                            });
                          },
                          child: const Text('Reset'),
                        )
                      ]),
                      SizedBox(height: AppSpacing.md),
                      SwitchListTile(
                          value: tOpenNow,
                          onChanged: (v) => setSheet(() => tOpenNow = v),
                          title: const Text('Open now')),
                      SizedBox(height: AppSpacing.sm),
                      Text('Minimum rating'),
                      Slider(
                          value: tMinRating,
                          onChanged: (v) => setSheet(() =>
                              tMinRating = double.parse(v.toStringAsFixed(1))),
                          divisions: 10,
                          min: 0,
                          max: 5,
                          label: tMinRating.toStringAsFixed(1)),
                      SizedBox(height: AppSpacing.sm),
                      Text('Minimum reviews: $tMinReviews'),
                      Slider(
                          value: tMinReviews.toDouble(),
                          onChanged: (v) =>
                              setSheet(() => tMinReviews = v.round()),
                          divisions: 10,
                          min: 0,
                          max: 500,
                          label: '$tMinReviews'),
                      SizedBox(height: AppSpacing.sm),
                      Text('Price levels'),
                      Wrap(spacing: AppSpacing.sm, children: [
                        priceChip(0),
                        priceChip(1),
                        priceChip(2),
                        priceChip(3),
                        priceChip(4)
                      ]),
                      SizedBox(height: AppSpacing.md),
                      Text('Sort'),
                      Row(children: [
                        ChoiceChip(
                            label: const Text('Nearest'),
                            selected: !tSortByRating,
                            onSelected: (_) => setSheet(() {
                                  tSortByRating = false;
                                })),
                        SizedBox(width: AppSpacing.sm),
                        ChoiceChip(
                            label: const Text('Top rated'),
                            selected: tSortByRating,
                            onSelected: (_) => setSheet(() {
                                  tSortByRating = true;
                                })),
                      ]),
                      SizedBox(height: AppSpacing.md),
                      Text('Nearby search ranking'),
                      Row(children: [
                        ChoiceChip(
                            label: const Text('Prominence'),
                            selected: !tRankByDistance,
                            onSelected: (_) => setSheet(() {
                                  tRankByDistance = false;
                                })),
                        SizedBox(width: AppSpacing.sm),
                        ChoiceChip(
                            label: const Text('Distance'),
                            selected: tRankByDistance,
                            onSelected: (_) => setSheet(() {
                                  tRankByDistance = true;
                                })),
                      ]),
                      SizedBox(height: AppSpacing.md),
                      Text('Google place types'),
                      Wrap(spacing: AppSpacing.sm, children: [
                        typeChip('Hospital', 'hospital'),
                        typeChip('Clinic', 'clinic'),
                        typeChip('Doctor', 'doctor'),
                        typeChip('Physiotherapist', 'physiotherapist'),
                        typeChip('Psychologist', 'psychologist'),
                        typeChip('Pharmacy', 'pharmacy'),
                        typeChip('Dentist', 'dentist'),
                        typeChip('Health', 'health'),
                      ]),
                      SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _openNow = tOpenNow;
                              _minRating = tMinRating;
                              _minReviews = tMinReviews;
                              _priceLevels
                                ..clear()
                                ..addAll(tPrices);
                              _sortByRating = tSortByRating;
                              _rankByDistance = tRankByDistance;
                              _googleTypes
                                ..clear()
                                ..addAll(tTypes);
                            });
                            Navigator.of(ctx).pop();
                            _load();
                          },
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text('Apply filters'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _applyTypedLocation({bool saveToProfile = false}) async {
    final q = _location.text.trim();
    if (q.isEmpty) return;
    final result = await _service.geocodeAddress(q);
    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find that location')),
        );
      }
      return;
    }
    setState(() {
      _userLat = (result['lat'] as num).toDouble();
      _userLng = (result['lng'] as num).toDouble();
      _userLocationLabel = (result['label'] as String?) ?? q;
      _location.text = _userLocationLabel!;
      _region = (result['countryCode'] as String?)?.toUpperCase();
    });
    if (saveToProfile) {
      try {
        await _userService.savePreferredLocation(
          label: _userLocationLabel ?? q,
          lat: _userLat!,
          lng: _userLng!,
          countryCode: _region,
        );
        if (mounted) {
          // Refresh in-memory user so Profile reflects the new location immediately
          try {
            await context.read<UserProvider>().loadUser();
          } catch (e) {
            debugPrint(
                'CommunityHub.ResourcesTab post-save refresh user error: $e');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location saved to profile')),
          );
        }
      } catch (e) {
        debugPrint('CommunityHub.ResourcesTab savePreferredLocation error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save location to profile')),
          );
        }
      }
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    // Saved-location removed: no profile sync
    return Column(
      children: [
        Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _location,
                decoration: InputDecoration(
                  hintText: 'Enter city, ZIP, or address…',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Apply location',
                        icon: Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () =>
                            _applyTypedLocation(saveToProfile: false),
                      ),
                      IconButton(
                        tooltip: 'Save to profile',
                        icon: Icon(
                          Icons.bookmark_add_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () =>
                            _applyTypedLocation(saveToProfile: true),
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _applyTypedLocation(saveToProfile: false),
              ),
              SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _query,
                decoration: InputDecoration(
                  hintText: 'Search resources…',
                  prefixIcon: const Icon(Icons.search),
                  suffix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_query.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() => _query.clear());
                            _applyLocalTextFilter();
                          },
                        ),
                      IconButton(
                        tooltip: 'Search',
                        icon: Icon(
                          Icons.arrow_forward,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: _runSearch,
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                textAlign: TextAlign.center,
                onChanged: (_) {
                  setState(() {});
                  _debouncedSearch();
                },
                onSubmitted: (_) => _runSearch(),
              ),
              SizedBox(height: AppSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ChipFilter(
                      label: 'All Types',
                      selected: _type == 'all',
                      onTap: () {
                        setState(() {
                          _type = 'all';
                        });
                        _load();
                      },
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _ChipFilter(
                      label: 'Therapist',
                      selected: _type == 'therapist',
                      onTap: () {
                        setState(() {
                          _type = 'therapist';
                          _therapyNameOnly = true;
                        });
                        _load();
                      },
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _ChipFilter(
                      label: 'Hospital',
                      selected: _type == 'hospital',
                      onTap: () {
                        setState(() {
                          _type = 'hospital';
                          _therapyNameOnly = false;
                        });
                        _load();
                      },
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _ChipFilter(
                      label: 'Service',
                      selected: _type == 'service',
                      onTap: () {
                        setState(() {
                          _type = 'service';
                          _therapyNameOnly = false;
                        });
                        _load();
                      },
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _ChipFilter(
                      label: 'Pharmacy',
                      selected: _type == 'pharmacy',
                      onTap: () {
                        setState(() {
                          _type = 'pharmacy';
                          _therapyNameOnly = false;
                        });
                        _load();
                      },
                    ),
                    if (_type == 'therapist') ...[
                      SizedBox(width: AppSpacing.md),
                      _ChipFilter(
                        label: 'Therapy name only',
                        selected: _therapyNameOnly,
                        onTap: () {
                          setState(() {
                            _therapyNameOnly = !_therapyNameOnly;
                          });
                          _load();
                        },
                      ),
                    ],
                    SizedBox(width: AppSpacing.md),
                    Icon(
                      Icons.straighten,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: AppSpacing.xs),
                    _ChipFilter(
                      label: 'All distances',
                      selected: _maxDistanceMiles == null,
                      onTap: () {
                        setState(() {
                          _maxDistanceMiles = null;
                        });
                        _load();
                      },
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _ChipFilter(
                      label: '5 mi',
                      selected: _maxDistanceMiles == 5,
                      onTap: () {
                        setState(() {
                          _maxDistanceMiles = 5;
                        });
                        _load();
                      },
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _ChipFilter(
                      label: '10 mi',
                      selected: _maxDistanceMiles == 10,
                      onTap: () {
                        setState(() {
                          _maxDistanceMiles = 10;
                        });
                        _load();
                      },
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _ChipFilter(
                      label: '25 mi',
                      selected: _maxDistanceMiles == 25,
                      onTap: () {
                        setState(() {
                          _maxDistanceMiles = 25;
                        });
                        _load();
                      },
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _ChipFilter(
                      label: '50 mi',
                      selected: _maxDistanceMiles == 50,
                      onTap: () {
                        setState(() {
                          _maxDistanceMiles = 50;
                        });
                        _load();
                      },
                    ),
                    SizedBox(width: AppSpacing.md),
                    TextButton.icon(
                      onPressed: _openFiltersSheet,
                      icon: Icon(Icons.tune,
                          color: Theme.of(context).colorScheme.primary),
                      label: Text(
                        'Filters',
                        style: context.textStyles.labelLarge?.withColor(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CenteredLoadingSkeleton())
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          SizedBox(height: AppSpacing.md),
                          Text('No resources found',
                              style: context.textStyles.titleLarge?.withColor(
                                  Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ],
                      ),
                    )
                  : Builder(builder: (context) {
                      if (_type == 'therapist' && !_therapyNameOnly) {
                        bool isTherapyName(Resource r) {
                          final n = r.name.toLowerCase();
                          return n.contains('therapy') ||
                              n.contains('therapist');
                        }

                        final exact = _items.where(isTherapyName).toList();
                        final others =
                            _items.where((r) => !isTherapyName(r)).toList();
                        final children = <Widget>[];
                        if (exact.isNotEmpty) {
                          children.add(Padding(
                            padding: EdgeInsets.fromLTRB(
                                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                            child: Text('Exact “therapy” matches',
                                style: context.textStyles.titleSmall?.semiBold),
                          ));
                          children.addAll(exact
                              .map((r) => _HubResourceCard(resource: r))
                              .toList());
                        }
                        if (others.isNotEmpty) {
                          children.add(Padding(
                            padding: EdgeInsets.fromLTRB(AppSpacing.lg,
                                AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                            child: Text('Other therapists',
                                style: context.textStyles.titleSmall?.semiBold),
                          ));
                          children.addAll(others
                              .map((r) => _HubResourceCard(resource: r))
                              .toList());
                        }
                        return ListView(children: children);
                      }
                      return ListView.builder(
                        padding:
                            EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final withSummary = _applySummary(_items[i]);
                          return _HubResourceCard(resource: withSummary);
                        },
                      );
                    }),
        ),
      ],
    );
  }
}

class _ChipFilter extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChipFilter(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
    );
  }
}

// ignore: unused_element
class _LocationBanner extends StatelessWidget {
  final String text;
  final String actionLabel;
  final VoidCallback onTap;
  const _LocationBanner({
    required this.text,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.my_location, color: cs.onSurfaceVariant),
          SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(text,
                  style:
                      context.textStyles.bodyMedium?.withColor(cs.onSurface))),
          TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.my_location),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _HubResourceCard extends StatelessWidget {
  final Resource resource;
  const _HubResourceCard({required this.resource});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  resource.type == 'therapist'
                      ? Icons.person_outline
                      : (resource.type == 'center' ||
                              resource.type == 'hospital')
                          ? Icons.local_hospital_outlined
                          : (resource.type == 'pharmacy'
                              ? Icons.local_pharmacy_outlined
                              : Icons.medical_services_outlined),
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(resource.name,
                        style: context.textStyles.titleMedium?.semiBold),
                    if (resource.rating > 0 && resource.reviewCount > 0)
                      Row(children: [
                        RatingStars(
                            rating: resource.rating,
                            reviews: resource.reviewCount,
                            size: 14),
                        SizedBox(width: 8),
                        Text(resource.rating.toStringAsFixed(1),
                            style: context.textStyles.bodySmall),
                      ])
                    else
                      Row(children: [
                        Icon(Icons.star_outline,
                            size: 16,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        SizedBox(width: 6),
                        Text('No ratings',
                            style: context.textStyles.bodySmall?.withColor(
                                Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ]),
                  ],
                ),
              ),
            ]),
            SizedBox(height: AppSpacing.sm),
            if (resource.address.isNotEmpty) ...[
              Row(children: [
                Icon(Icons.place_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    resource.address,
                    style: context.textStyles.bodySmall?.withColor(
                        Theme.of(context).colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ]),
              SizedBox(height: AppSpacing.xs),
            ],
            Row(children: [
              Icon(Icons.location_on_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${resource.location} • ${resource.distance.toStringAsFixed(1)} mi',
                  style: context.textStyles.bodySmall?.withColor(
                      Theme.of(context).colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ]),
            SizedBox(height: AppSpacing.xs),
            HoursBadge(availability: resource.availability, dense: true),
            if (resource.contactPhone != null) ...[
              SizedBox(height: AppSpacing.sm),
              PhoneLink(phone: resource.contactPhone!, dense: true),
            ],
            // Review submissions are disabled for now
          ],
        ),
      ),
    );
  }
}
