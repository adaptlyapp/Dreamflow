import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:wellspring/models/group.dart';
import 'package:wellspring/services/group_service.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/screens/communities/community_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:wellspring/widgets/brand_logo.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CreateCommunitySheet extends StatefulWidget {
  const _CreateCommunitySheet();

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
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Validate inputs and show inline errors instead of silently returning
    debugPrint('CreateCommunity: submit tapped');
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      debugPrint('CreateCommunity: form invalid');
      return;
    }
    setState(() => _saving = true);
    try {
      debugPrint('CreateCommunity: creating with name="${_name.text.trim()}" type=$_type privacy=$_privacy');
      final created = await _service.createGroup(
        name: _name.text.trim(),
        description: _desc.text.trim(),
        type: _type,
        relatedCondition: _type == 'condition' ? _relatedCondition : null,
        privacy: _privacy,
      );
      if (!mounted) return;
      debugPrint('CreateCommunity: created id=${created.id}');
      Navigator.of(context).pop(created);
    } catch (e) {
      debugPrint('CreateCommunity: error $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                Text('Create community', style: context.textStyles.titleLarge?.semiBold),
                SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Please enter a name';
                    if (t.length < 3) return 'Name must be at least 3 characters';
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
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
                Text('Category', style: context.textStyles.labelLarge?.semiBold),
                SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Interest'),
                      selected: _type == 'interest',
                      onSelected: (_) => setState(() { _type = 'interest'; }),
                    ),
                    ChoiceChip(
                      label: const Text('Condition'),
                      selected: _type == 'condition',
                      onSelected: (_) => setState(() { _type = 'condition'; }),
                    ),
                  ],
                ),
                if (_type == 'condition') ...[
                  SizedBox(height: AppSpacing.md),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Related Condition ID (optional)',
                      hintText: 'e.g., "ms"',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                    ),
                    onChanged: (v) => _relatedCondition = v.trim().isEmpty ? null : v.trim(),
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
                      onSelected: (_) => setState(() { _privacy = 'open'; }),
                    ),
                    ChoiceChip(
                      label: const Text('Private (approval)'),
                      selected: _privacy == 'private',
                      onSelected: (_) => setState(() { _privacy = 'private'; }),
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

class _CommunitiesScreenState extends State<CommunitiesScreen> with SingleTickerProviderStateMixin {
  final _groupService = GroupService();
  List<Group> _allGroups = [];
  List<Group> _displayedGroups = [];
  bool _isLoading = true;
  late TabController _tabController;
  // Tabs: 'mine' (Your communities) | 'explore' (Discover)
  String _currentTab = 'mine';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Ensure user is loaded so owner checks and names are available
    final userProv = context.read<UserProvider>();
    if (userProv.currentUser == null) {
      unawaited(userProv.loadUser());
    }
    _loadGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTab = ['mine', 'explore'][_tabController.index];
        _filterGroups();
      });
    }
  }

  Future<void> _loadGroups({bool preserveOnEmpty = false}) async {
    setState(() => _isLoading = true);
    final groups = await _groupService.getAllGroups();
    if (preserveOnEmpty && groups.isEmpty && _allGroups.isNotEmpty) {
      // Keep the locally inserted list (likely reads are blocked by rules)
      debugPrint('CommunitiesScreen: keeping local list due to empty refresh (possibly permission-denied)');
      setState(() {
        _filterGroups();
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _allGroups = groups;
      _filterGroups();
      _isLoading = false;
    });
  }

  void _filterGroups() {
    final uid = context.read<UserProvider>().currentUser?.id ?? auth.FirebaseAuth.instance.currentUser?.uid;
    setState(() {
      if (_currentTab == 'mine') {
        // Show owned groups, joined groups, and pending requests
        _displayedGroups = _allGroups.where((g) {
          final isOwner = (uid != null && uid.isNotEmpty) && (g.ownerId == uid);
          final isPending = (g.membershipStatus == 'pending');
          return g.isJoined || isOwner || isPending;
        }).toList();
      } else {
        // Explore: groups the user doesn't own and hasn't joined
        _displayedGroups = _allGroups.where((g) {
          final isOwner = (uid != null && uid.isNotEmpty) && (g.ownerId == uid);
          return !g.isJoined && !isOwner;
        }).toList();
      }
    });
  }

  Future<void> _toggleJoin(Group group) async {
    try {
      if (group.isJoined) {
        await _groupService.leaveGroup(group.id);
      } else {
        await _groupService.joinGroup(group.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      _loadGroups();
    }
  }

  Future<void> _openCreate() async {
    debugPrint('CommunitiesScreen: _openCreate tapped');
    final created = await showModalBottomSheet<Group?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => const _CreateCommunitySheet(),
    );
    debugPrint('CommunitiesScreen: bottom sheet closed; created=' + (created?.id ?? 'null'));
    if (created != null) {
      setState(() {
        _allGroups = [created, ..._allGroups];
        _filterGroups();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Community created')),
        );
      }
    }
    // Refresh in background when possible
    unawaited(_loadGroups(preserveOnEmpty: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/b0380405-152d-4717-8856-bf48d924b809.png',
              fit: BoxFit.cover,
            ),
          ),
          // Content
          SafeArea(
            child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(children: [
                      const BrandLogo(size: 56),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Communities', style: context.textStyles.headlineMedium?.semiBold, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                  FilledButton.icon(
                    onPressed: _openCreate,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Create'),
                  )
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Your communities'),
                Tab(text: 'Explore'),
              ],
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CenteredLoadingSkeleton())
                  : _displayedGroups.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(height: AppSpacing.md),
                              Text(
                                _currentTab == 'mine' ? "You haven't joined any communities yet" : 'No communities to explore',
                                style: context.textStyles.titleLarge?.withColor(
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.lg + MediaQuery.of(context).padding.bottom,
                          ),
                          itemCount: _displayedGroups.length,
                          itemBuilder: (context, index) {
                            final group = _displayedGroups[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: AppSpacing.md),
                              child: InkWell(
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => CommunityDetailScreen(communityId: group.id),
                                )),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                child: Padding(
                                  padding: AppSpacing.paddingMd,
                                  child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                          child: Icon(
                                            group.type == 'condition' ? Icons.medical_information_outlined : Icons.interests_outlined,
                                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                        SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(child: Text(group.name, style: context.textStyles.titleMedium?.semiBold, overflow: TextOverflow.ellipsis)),
                                                  Builder(
                                                    builder: (context) {
                                                      final uid = context.read<UserProvider>().currentUser?.id ?? auth.FirebaseAuth.instance.currentUser?.uid;
                                                      final isOwner = (uid != null && uid.isNotEmpty) && (group.ownerId == uid);
                                                      if (!isOwner) return const SizedBox.shrink();
                                                      return Padding(
                                                        padding: EdgeInsets.only(left: AppSpacing.xs),
                                                        child: Icon(Icons.shield_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                              Row(children: [
                                                Icon(group.privacy == 'private' ? Icons.lock_outline : Icons.public, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                                SizedBox(width: 4),
                                                Text(
                                                  '${group.memberCount} members • ${group.privacy == 'private' ? 'Private' : 'Open'}',
                                                  style: context.textStyles.bodySmall?.withColor(
                                                    Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ]),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: AppSpacing.sm),
                                    Text(
                                      group.description,
                                      style: context.textStyles.bodyMedium?.withColor(
                                        Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: AppSpacing.md),
                                    SizedBox(
                                      width: double.infinity,
                                      child: Builder(
                                        builder: (context) {
                                          final uid = context.read<UserProvider>().currentUser?.id ?? auth.FirebaseAuth.instance.currentUser?.uid;
                                          final isOwner = (uid != null && uid.isNotEmpty) && (group.ownerId == uid);
                                          if (isOwner) {
                                            return OutlinedButton(
                                              onPressed: null,
                                              style: OutlinedButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                                ),
                                              ),
                                              child: const Text('Owner'),
                                            );
                                          }
                                          if (group.isJoined) {
                                            return OutlinedButton(
                                              onPressed: () => _toggleJoin(group),
                                              style: OutlinedButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                                ),
                                              ),
                                              child: const Text('Leave'),
                                            );
                                          }
                                          if (group.membershipStatus == 'pending') {
                                            return OutlinedButton(
                                              onPressed: null,
                                              style: OutlinedButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                                ),
                                              ),
                                              child: const Text('Requested'),
                                            );
                                          }
                                          return FilledButton(
                                            onPressed: () => _toggleJoin(group),
                                            style: FilledButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                              ),
                                            ),
                                            child: Text(group.privacy == 'private' ? 'Request to join' : 'Join'),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            );
                          },
                        ),
            ),
          ],
        ),
            ),
        ],
      ),
    );
  }
}
