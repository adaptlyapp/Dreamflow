import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/models/condition_detail.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/services/guidance_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/glass_card.dart';

class ConditionsScreen extends StatefulWidget {
  const ConditionsScreen({super.key});

  @override
  State<ConditionsScreen> createState() => _ConditionsScreenState();
}

class _ConditionsScreenState extends State<ConditionsScreen>
    with AutomaticKeepAliveClientMixin {
  final _conditionService = ConditionService();
  final _guidance = GuidanceService();
  final _userService = UserService();
  List<Condition> _filteredConditions = [];
  List<Condition> _recentlyAdded = [];
  bool _isLoading = true;
  String? _userId;
  DateTime? _diagnosisDate;
  List<String> _selectedConditionIds = [];

  @override
  void initState() {
    super.initState();
    _loadConditions();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadConditions() async {
    setState(() => _isLoading = true);
    try {
      final all = await _conditionService.getAllConditions();
      // Recently added surfacing is best-effort; never block the UI here.
      List<Condition> recent = const [];
      // Temporarily disable direct service call to avoid hot-reload stale-instance issues on web.
      // We'll keep the card hidden rather than risking a render loop if the method is missing.
      // try {
      //   recent = await _conditionService.getRecentlyAddedConditions();
      // } catch (e) {
      //   debugPrint('getRecentlyAddedConditions unavailable or failed: $e');
      // }
      final user = await _userService.getCurrentUser();
      // Show only the user's selected conditions
      final userConditionIds = user?.conditions ?? [];
      // Map legacy IDs forward (in case we refreshed to the catalog and old numeric ids exist)
      final myIds = <String>{};
      if (userConditionIds.isNotEmpty) {
        for (final id in userConditionIds) {
          // Resolve to a condition and then use its canonical id
          final c = await _conditionService.getConditionById(id);
          if (c != null) myIds.add(c.id);
        }
      }
      // Attach user-specific condition details (if any) directly to the Condition
      // so the Conditions page can render them without re-reading preferences.
      final prefs = user?.preferences ?? const <String, dynamic>{};
      final myConditions = myIds.isEmpty
          ? <Condition>[]
          : all.where((c) => myIds.contains(c.id)).map((c) {
              final detail = ConditionDetail.tryFromUserPreferences(
                preferences: prefs,
                conditionId: c.id,
              );
              if (detail == null) return c;
              return c.copyWith(userDetail: detail);
            }).toList();

      if (!mounted) return;
      setState(() {
// my conditions (default view)
        _filteredConditions = myConditions; // default filtered list
        _recentlyAdded = recent;
        _isLoading = false;
        _userId = user?.id;
        _diagnosisDate = user?.diagnosisDate;
        _selectedConditionIds = List<String>.from(userConditionIds);
      });
    } catch (e) {
      debugPrint('Failed loading Condition Hubs: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      // Keep UI usable even if something goes wrong.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to load Condition Hubs. Please try again.')),
      );
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
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
          RefreshIndicator.adaptive(
        onRefresh: _loadConditions,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'My hubs',
                              style: context.textStyles.titleLarge?.semiBold,
                            ),
                          ),
                          if (!_isLoading)
                            _CountPill(count: _filteredConditions.length),
                        ],
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'Tap a condition to open your plan and timeline.',
                        style: context.textStyles.bodySmall?.withColor(
                          scheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CenteredLoadingSkeleton()),
              )
            else if (_filteredConditions.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyMyConditions(),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                sliver: SliverList.separated(
                  itemCount: _filteredConditions.length +
                      ((_recentlyAdded.isNotEmpty) ? 1 : 0),
                  separatorBuilder: (_, __) => SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    if (_recentlyAdded.isNotEmpty && i == 0) {
                      return _RecentlyAddedCard(
                        items: _recentlyAdded,
                        onAdd: (c) async {
                          try {
                            final current =
                                List<String>.from(_selectedConditionIds);
                            if (!current.contains(c.id)) {
                              current.add(c.id);
                              try {
                                await context
                                    .read<UserProvider>()
                                    .updateConditions(
                                      current,
                                    );
                              } catch (e) {
                                debugPrint(
                                  'UserProvider not available, fallback to service. $e',
                                );
                                await _userService.updateConditions(current);
                              }
                              if (!mounted) return;
                              setState(() => _selectedConditionIds = current);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Added ${c.name} to your hubs')),
                              );
                              await _loadConditions();
                            }
                          } catch (e) {
                            debugPrint(
                              'Failed to add condition from recently added card: $e',
                            );
                          }
                        },
                        onDismiss: () async {
                          try {
                            await _conditionService
                                .clearRecentlyAddedConditions();
                            if (mounted) setState(() => _recentlyAdded = []);
                          } catch (e) {
                            debugPrint(
                                'Failed to dismiss recently added card: $e');
                          }
                        },
                      );
                    }
                    final index = _recentlyAdded.isNotEmpty ? i - 1 : i;
                    final condition = _filteredConditions[index];
                    return _ConditionHubTile(
                      condition: condition,
                      stageLabel: _guidance.stageLabel(_diagnosisDate),
                      userId: _userId,
                      onTap: () => context.push('/condition/${condition.id}'),
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

  Future<void> _openManageConditions() async {
    try {
      final allConditions = await _conditionService.getAllConditions();
      allConditions
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final current = List<String>.from(_selectedConditionIds);

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        builder: (context) {
          final tempSelected = current.toSet();
          final searchCtl = TextEditingController();
          List<Condition> visible = List.of(allConditions);

          void applyFilter(String q) {
            final lower = q.toLowerCase();
            visible = allConditions
                .where((c) =>
                    c.name.toLowerCase().contains(lower) ||
                    c.description.toLowerCase().contains(lower))
                .toList();
            visible.sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          }

          return StatefulBuilder(
            builder: (context, setSheetState) {
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.8,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                builder: (context, scrollCtl) {
                  return Padding(
                    padding: EdgeInsets.only(
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                      top: AppSpacing.md,
                      bottom: MediaQuery.of(context).viewInsets.bottom +
                          AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            margin: EdgeInsets.only(bottom: AppSpacing.md),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                                child: Text('Manage conditions',
                                    style: context
                                        .textStyles.titleLarge?.semiBold)),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                              onPressed: () => context.pop(),
                            )
                          ],
                        ),
                        SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: searchCtl,
                          autofocus: true,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.search,
                          onChanged: (q) => setSheetState(() {
                            applyFilter(q);
                          }),
                          decoration: InputDecoration(
                            hintText: 'Search conditions...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.6,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.error,
                                width: 1,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          ),
                        ),
                        SizedBox(height: AppSpacing.md),
                        Expanded(
                          child: ListView.builder(
                            controller: scrollCtl,
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final c = visible[index];
                              final checked = tempSelected.contains(c.id);
                              return CheckboxListTile(
                                value: checked,
                                onChanged: (v) {
                                  setSheetState(() {
                                    if (v == true)
                                      tempSelected.add(c.id);
                                    else
                                      tempSelected.remove(c.id);
                                  });
                                },
                                title: Text(c.name.toUpperCase()),
                                subtitle: Text(
                                  c.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: Icon(Icons.save,
                                color: Theme.of(context).colorScheme.onPrimary),
                            label: Text('Save changes'),
                            onPressed: () async {
                              try {
                                final ids = tempSelected.toList();
                                try {
                                  await context
                                      .read<UserProvider>()
                                      .updateConditions(ids);
                                } catch (e) {
                                  debugPrint(
                                      'UserProvider not available, falling back. $e');
                                  await _userService.updateConditions(ids);
                                }
                                if (mounted) {
                                  setState(() => _selectedConditionIds = ids);
                                  context.pop();
                                  await _loadConditions();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('Conditions updated')),
                                    );
                                  }
                                }
                              } catch (e) {
                                debugPrint('Failed to update conditions: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Failed to update conditions')),
                                );
                              }
                            },
                          ),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint('Error opening manage conditions: $e');
    }
  }
}

class _EmptyMyConditions extends StatelessWidget {
  const _EmptyMyConditions();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GlassCard(
              borderRadius: AppRadius.xl,
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.health_and_safety_outlined,
                        size: 34, color: scheme.primary),
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Text(
                    'No conditions added',
                    style: context.textStyles.titleLarge?.semiBold,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Visit Settings to add conditions and unlock\n'
                    'personalized milestones, plans, and resources.',
                    style: context.textStyles.bodyMedium?.withColor(
                      scheme.onSurface.withValues(alpha: 0.75),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}


class _ConditionHubTile extends StatefulWidget {
  final Condition condition;
  final String stageLabel;
  final String? userId;
  final VoidCallback onTap;

  const _ConditionHubTile({
    required this.condition,
    required this.stageLabel,
    required this.userId,
    required this.onTap,
  });

  @override
  State<_ConditionHubTile> createState() => _ConditionHubTileState();
}

class _ConditionHubTileState extends State<_ConditionHubTile> {
  final _guidance = GuidanceService();
  String? _advice;

  @override
  void initState() {
    super.initState();
    _loadAdvice();
  }

  Future<void> _loadAdvice() async {
    if (widget.userId == null) return;
    final advice = await _guidance.adviceSnapshot(
      userId: widget.userId!,
      condition: widget.condition,
    );
    if (!mounted) return;
    setState(() => _advice = advice);
  }

  String _userDetailSummary(ConditionDetail d) {
    final parts = <String>[];
    if (d.subType?.trim().isNotEmpty ?? false) parts.add(d.subType!.trim());
    if (d.injuryLevel?.trim().isNotEmpty ?? false)
      parts.add('Level ${d.injuryLevel!.trim()}');
    if (d.mobilityStatus?.trim().isNotEmpty ?? false)
      parts.add(d.mobilityStatus!.trim());
    if (d.requiresAssistance) parts.add('Assistance');
    if (d.assistiveDevices.isNotEmpty)
      parts.add(
          '${d.assistiveDevices.length} device${d.assistiveDevices.length == 1 ? '' : 's'}');
    if (d.challenges.isNotEmpty)
      parts.add(
          '${d.challenges.length} challenge${d.challenges.length == 1 ? '' : 's'}');

    if (parts.isEmpty && (d.additionalNotes?.trim().isNotEmpty ?? false)) {
      return d.additionalNotes!.trim();
    }
    if (parts.isEmpty) return '';
    return parts.take(4).join(' • ');
  }

  IconData _iconFromName(String name) {
    switch (name) {
      case 'self_improvement':
        return Icons.self_improvement;
      case 'battery_full':
        return Icons.battery_full;
      case 'psychology':
        return Icons.psychology;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'stylus_note':
        return Icons.edit_note;
      case 'bedtime':
        return Icons.bedtime;
      case 'spa':
        return Icons.spa;
      case 'monitor_heart':
        return Icons.monitor_heart;
      case 'restaurant':
        return Icons.restaurant;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'water_drop':
        return Icons.water_drop;
      case 'visibility':
        return Icons.visibility;
      case 'fitness_center':
        return Icons.fitness_center;
      default:
        return Icons.flag_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badges = _guidance.topBadgesFor(widget.condition);
    final detail = widget.condition.userDetail;
    final detailSummary = (detail != null && detail.hasDetails)
        ? _userDetailSummary(detail)
        : null;

    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: 1,
      child: GlassCard(
        borderRadius: AppRadius.lg,
        onTap: widget.onTap,
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.health_and_safety_rounded,
                      color: scheme.primary),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.condition.name,
                        style: context.textStyles.titleMedium?.semiBold,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6),
                      _StagePill(label: widget.stageLabel),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.9)),
              ],
            ),
            if (badges.isNotEmpty) ...[
              SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: badges.take(4).map((b) {
                  return _BadgeChip(
                    title: b.title,
                    icon: _iconFromName(b.iconName),
                    onTap: widget.onTap,
                  );
                }).toList(),
              ),
            ],
            if (detailSummary != null && detailSummary.trim().isNotEmpty) ...[
              SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border:
                      Border.all(color: scheme.outline.withValues(alpha: 0.10)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.person_outline, size: 18, color: scheme.primary),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        detailSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.bodySmall?.withColor(
                          scheme.onSurface.withValues(alpha: 0.82),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_advice != null && _advice!.trim().isNotEmpty) ...[
              SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border:
                      Border.all(color: scheme.outline.withValues(alpha: 0.10)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, color: scheme.tertiary),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _advice!,
                        style: context.textStyles.bodyMedium?.withColor(
                          scheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onTap,
                    icon: Icon(Icons.dashboard, color: scheme.onPrimary),
                    label: _PlanLabel(name: widget.condition.name),
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

class _PlanLabel extends StatelessWidget {
  final String name;
  const _PlanLabel({required this.name});

  String _label() {
    final parts = name.trim().split(RegExp(r"\s+"));
    final first = parts.isNotEmpty ? parts.first : name.trim();
    if (first.length > 12) return 'View My Plan';
    return 'View My $first Plan';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _label(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _RecentlyAddedCard extends StatelessWidget {
  final List<Condition> items;
  final void Function(Condition) onAdd;
  final VoidCallback onDismiss;

  const _RecentlyAddedCard({
    required this.items,
    required this.onAdd,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.new_releases, color: scheme.primary),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('New in the catalog',
                      style: context.textStyles.titleMedium?.semiBold),
                ),
                TextButton(
                  onPressed: onDismiss,
                  child: Text('Dismiss',
                      style: context.textStyles.labelLarge?.withColor(
                          isLight ? scheme.onSurface : scheme.primary)),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in items)
                    _MiniConditionCard(condition: c, onAdd: () => onAdd(c)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionsSliverHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onManage;

  const _ConditionsSliverHeader({
    required this.title,
    required this.subtitle,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 150,
      backgroundColor: isDark ? DarkModeColors.slate : scheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(title, style: context.textStyles.titleLarge?.semiBold),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: AppSpacing.md),
          child: IconButton(
            tooltip: 'Manage conditions',
            onPressed: onManage,
            icon: Icon(Icons.tune_rounded, color: scheme.onSurface),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      DarkModeColors.graphite,
                      DarkModeColors.slate,
                    ]
                  : [
                      scheme.primaryContainer.withValues(alpha: 0.65),
                      scheme.surface,
                    ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg, 64, AppSpacing.lg, AppSpacing.md),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  subtitle,
                  style: context.textStyles.bodyMedium?.withColor(
                    scheme.onSurface.withValues(alpha: 0.75),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;
  const _CountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.20)),
      ),
      child: Text(
        '$count',
        style: context.textStyles.labelLarge
            ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StagePill extends StatelessWidget {
  final String label;
  const _StagePill({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timelapse_rounded,
              size: 16, color: scheme.onSurfaceVariant),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Stage: $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.labelMedium
                  ?.withColor(scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _BadgeChip(
      {required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: scheme.onSecondaryContainer),
              SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.labelMedium
                      ?.withColor(scheme.onSecondaryContainer),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniConditionCard extends StatelessWidget {
  final Condition condition;
  final VoidCallback onAdd;
  const _MiniConditionCard({required this.condition, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 240,
      margin: EdgeInsets.only(right: AppSpacing.sm),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.health_and_safety,
                    size: 16, color: scheme.onSecondaryContainer),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  condition.name.toUpperCase(),
                  style: context.textStyles.titleSmall?.semiBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            condition.description.isEmpty
                ? 'No description available yet.'
                : condition.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.bodySmall?.withColor(scheme.onSurface),
          ),
          SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: Icon(Icons.add, color: Colors.white),
              label: const Text('Add to My Hub'),
            ),
          )
        ],
      ),
    );
  }
}
