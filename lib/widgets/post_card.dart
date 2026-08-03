import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/models/plan_timeline.dart';
import 'package:wellspring/models/post.dart';
import 'package:wellspring/services/plan_timeline_service.dart';
import 'package:wellspring/services/post_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/glass_card.dart';
import 'package:wellspring/widgets/plan_share_sheet.dart';
import 'package:wellspring/widgets/skeletons.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onDeleted;

  const PostCard({super.key, required this.post, this.onLike, this.onComment, this.onDeleted});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _pulseForward = true;
  bool _savingPlan = false;
  final PlanTimelineService _timelineService = PlanTimelineService();
  final UserService _userService = UserService();
  final Uuid _uuid = const Uuid();

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  IconData _getTypeIcon() {
    switch (widget.post.type) {
      case 'article':
        return Icons.article_outlined;
      case 'resource':
        return Icons.bookmark_outline;
      case 'update':
        return Icons.campaign_outlined;
      case 'plan_template':
        return Icons.checklist_rtl;
      default:
        return Icons.people_outline;
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: cs.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.delete_outline, color: cs.error, size: 18),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Delete post?', style: ctx.textStyles.titleLarge?.semiBold)),
                  IconButton(icon: Icon(Icons.close, color: cs.onSurfaceVariant), onPressed: () => Navigator.of(ctx).pop(false))
                ]),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'This will permanently remove the post and its comments. This action cannot be undone.',
                  style: ctx.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                ),
                SizedBox(height: AppSpacing.md),
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    label: const Text('Cancel'),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    icon: Icon(Icons.delete, color: cs.onPrimary),
                    label: Text('Delete', style: ctx.textStyles.labelLarge?.withColor(cs.onPrimary)),
                    style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(cs.error)),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true) return;
    try {
      await PostService().deletePost(widget.post.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted')));
      }
      if (widget.onDeleted != null) widget.onDeleted!();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  String _deriveConditionName(String fallbackId) {
    for (final line in widget.post.content.split('\n')) {
      if (line.toLowerCase().startsWith('plan template for')) {
        final parts = line.split(RegExp('plan template for', caseSensitive: false));
        if (parts.isNotEmpty) {
          final name = parts.last.trim();
          if (name.isNotEmpty) return name;
        }
      }
    }
    return fallbackId.isNotEmpty ? fallbackId : 'My plan';
  }

  String _preferredConditionId() {
    if (widget.post.relatedConditions.isNotEmpty) {
      final first = widget.post.relatedConditions.first.trim();
      if (first.isNotEmpty) return first;
    }
    return 'general';
  }

  DateTime? _parseDueDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var value = raw.trim();
    // Strip leading weekday like "Thu," to match shared template format
    value = value.replaceFirst(RegExp(r'^[A-Za-z]{3},\s*'), '');

    DateTime? parsed;
    final parsers = [
      DateFormat.yMMMd(),
      DateFormat.MMMd(),
      DateFormat('MMM d, y'),
      DateFormat('MMM d'),
    ];

    for (final fmt in parsers) {
      try {
        parsed = fmt.parseLoose(value);
        break;
      } catch (_) {}
    }

    if (parsed == null) return null;

    // If the parsed date has no year, anchor it to this year (or next if already past)
    if (parsed.year == 1970 || parsed.year == 0 || parsed.year == 1) {
      final now = DateTime.now();
      var withYear = DateTime(now.year, parsed.month, parsed.day);
      if (withYear.isBefore(now.subtract(const Duration(days: 1)))) {
        withYear = DateTime(now.year + 1, parsed.month, parsed.day);
      }
      return withYear;
    }

    return parsed;
  }

  List<_ParsedPlanStep> _extractSteps(String content) {
    final lines = content.split('\n');
    final steps = <_ParsedPlanStep>[];
    for (final rawLine in lines) {
      final line = rawLine.trimLeft();
      if (line.isEmpty) continue;

      final match = RegExp(r'^([☑☐-]?)\s*(\d+)[\).]?\s*(.+)$').firstMatch(line);
      if (match != null) {
        final status = match.group(1);
        var body = match.group(3)?.trim() ?? '';
        DateTime? dueDate;
        final dueMatch = RegExp(r'\(.*?Due\s+([^)]+)\)').firstMatch(body);
        if (dueMatch != null) {
          dueDate = _parseDueDate(dueMatch.group(1));
          body = body.replaceFirst(dueMatch.group(0) ?? '', '').trim();
        }
        if (body.isEmpty) body = 'Step ${steps.length + 1}';
        steps.add(_ParsedPlanStep(title: body, description: null, dueDate: dueDate, completed: status == '☑'));
        continue;
      }

      if (steps.isNotEmpty && line.startsWith(RegExp(r'[·•-]'))) {
        final desc = line.replaceFirst(RegExp(r'^[·•-]+'), '').trim();
        if (desc.isNotEmpty) {
          final last = steps.removeLast();
          steps.add(last.copyWith(description: desc));
        }
      }
    }
    return steps;
  }

  String _extractNote(String content) {
    final lines = content.split('\n');
    final noteLines = <String>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (RegExp(r'^([☑☐-]?)\s*\d+[\).]').hasMatch(line)) break;
      if (line.toLowerCase().startsWith('plan template for')) continue;
      if (line.toLowerCase().startsWith('steps:')) continue;
      noteLines.add(line);
    }
    return noteLines.join(' ');
  }

  List<Milestone> _buildMilestonesFromTemplate({required String userId, required String conditionId}) {
    final parsed = _extractSteps(widget.post.content);
    if (parsed.isEmpty) return [];
    final now = DateTime.now();
    final baseDate = DateTime(now.year, now.month, now.day);
    return List.generate(parsed.length, (index) {
      final step = parsed[index];
      final dueDate = step.dueDate ?? baseDate.add(Duration(days: 7 * (index + 1)));
      return Milestone(
        id: _uuid.v4(),
        userId: userId,
        conditionId: conditionId,
        title: step.title,
        description: step.description,
        dueDate: dueDate,
        completed: step.completed,
        order: index,
        createdAt: now,
        updatedAt: now,
      );
    });
  }

  Future<void> _savePlanToMyPlans(BuildContext context) async {
    if (_savingPlan) return;
    debugPrint('[PostCard] Save CTA tapped post=${widget.post.id} type=${widget.post.type}');
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to save plans.')));
      return;
    }

    final conditionId = _preferredConditionId();
    final conditionName = _deriveConditionName(conditionId);
    final milestones = _buildMilestonesFromTemplate(userId: userId, conditionId: conditionId);
    debugPrint('[PostCard] Parsed ${milestones.length} milestones for condition=$conditionId');
    if (milestones.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read this plan template.')));
      return;
    }

    debugPrint('[PostCard] Saving plan template ${widget.post.id} for condition=$conditionId steps=${milestones.length}');
    setState(() => _savingPlan = true);
    try {
      Future<PlanTimeline> createTimeline() => _timelineService.createFromMilestones(
            userId: userId,
            conditionId: conditionId,
            conditionName: conditionName,
            name: 'From ${widget.post.authorName}',
            milestones: milestones,
            setCurrent: false,
          );

      PlanTimeline timeline;
      try {
        timeline = await createTimeline();
      } on PostgrestException catch (e) {
        if (e.code == '23503' && e.message.contains('plan_timelines_user_id_fkey')) {
          debugPrint('[PostCard] Missing Supabase user row for $userId, provisioning and retrying.');
          await _userService.getCurrentUser();
          timeline = await createTimeline();
        } else {
          rethrow;
        }
      }

      await _timelineService.setCurrentAndActivate(
        timeline: timeline,
        userId: userId,
        conditionId: conditionId,
        replaceActivePlan: true,
      );

      try {
        await Clipboard.setData(ClipboardData(text: widget.post.content));
      } on PlatformException catch (err) {
        debugPrint('[PostCard] Clipboard copy failed: $err');
      } catch (err) {
        debugPrint('[PostCard] Clipboard copy unexpected error: $err');
      }
      if (mounted) {
        final suffix = conditionName.isNotEmpty ? ' for $conditionName' : '';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to your plans$suffix')));
        final safeId = Uri.encodeComponent(conditionId);
        final planName = conditionName.isNotEmpty ? conditionName : 'Plan';
        context.push('/plan/$safeId', extra: planName);
      }
    } catch (e) {
      debugPrint('[PostCard] Save plan failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save plan: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingPlan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meId = SupabaseConfig.auth.currentUser?.id;
    final isOwner = meId != null && meId == widget.post.authorId;
    final isPlanTemplate = widget.post.type == 'plan_template';
    final conditionId = isPlanTemplate ? _preferredConditionId() : null;
    final conditionName = isPlanTemplate ? _deriveConditionName(conditionId ?? '') : null;
    final previewMilestones = isPlanTemplate ? _buildMilestonesFromTemplate(userId: 'preview', conditionId: conditionId ?? 'general') : const <Milestone>[];
    final note = isPlanTemplate ? _extractNote(widget.post.content) : '';
    final card = GlassCard(
      showGlow: widget.post.likesCount > 10,
      padding: AppSpacing.paddingMd,
      borderRadius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () => context.push('/u/${widget.post.authorId}'),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    widget.post.authorName[0].toUpperCase(),
                    style: context.textStyles.titleMedium?.withColor(
                      Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.post.authorName, style: context.textStyles.titleSmall?.semiBold),
                      Row(
                        children: [
                          Icon(_getTypeIcon(), size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          SizedBox(width: 4),
                          Text(
                            _getTimeAgo(widget.post.createdAt),
                            style: context.textStyles.bodySmall?.withColor(
                              Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.post.type == 'plan_template')
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary.withOpacity(0.25), Theme.of(context).colorScheme.secondary.withOpacity(0.2)]),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text('Plan', style: context.textStyles.labelMedium?.semiBold),
                  ),
                if (widget.post.type == 'plan_template') SizedBox(width: AppSpacing.sm),
                if (isOwner)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    onSelected: (value) {
                      if (value == 'delete') _confirmDelete(context);
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
                          SizedBox(width: 8),
                          Text('Delete', style: ctx.textStyles.bodyMedium?.withColor(Theme.of(ctx).colorScheme.error)),
                        ]),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),
          if (isPlanTemplate && previewMilestones.isNotEmpty) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: PlanSharePreviewCard(conditionName: conditionName ?? 'Plan', milestones: previewMilestones, note: note),
            ),
          ] else
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(widget.post.content, style: context.textStyles.bodyMedium),
            ),
          if ((widget.post.mediaUrl ?? widget.post.imageUrl) != null) ...[
            SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: _PostMedia(mediaUrl: widget.post.mediaUrl ?? widget.post.imageUrl!, mediaType: widget.post.mediaType ?? 'image'),
            ),
          ],
          SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              InkWell(
                onTap: widget.onLike,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.post.isLiked ? Icons.favorite : Icons.favorite_outline,
                        size: 20,
                        color: widget.post.isLiked ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${widget.post.likesCount}',
                        style: context.textStyles.bodySmall?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: widget.onComment,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${widget.post.commentsCount}',
                        style: context.textStyles.bodySmall?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.post.type == 'plan_template')
                TextButton.icon(
                  onPressed: _savingPlan
                      ? null
                      : () {
                          debugPrint('[PostCard] Save button pressed post=${widget.post.id}');
                          _savePlanToMyPlans(context);
                        },
                  icon: _savingPlan
                      ? SizedBox(width: 16, height: 16, child: const InlineLoadingDot())
                      : Icon(Icons.library_add_check_outlined, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  label: Text(
                    _savingPlan ? 'Saving…' : 'Save to plan',
                    style: context.textStyles.bodySmall?.withColor(Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _pulseForward ? 1 : 0),
      duration: const Duration(seconds: 6),
      curve: Curves.easeInOut,
      onEnd: () => setState(() => _pulseForward = !_pulseForward),
      builder: (context, value, child) {
        final cs = Theme.of(context).colorScheme;
        final primary = cs.primary.withOpacity(0.08 + 0.04 * value);
        final secondary = cs.secondary.withOpacity(0.06 + 0.05 * (1 - value));
        return Container(
          margin: EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + value, -1),
              end: Alignment(1 - value, 1),
              colors: [primary, secondary],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg + 2),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(AppRadius.lg + 2),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withOpacity(0.12 + 0.06 * value),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: card,
    );
  }
}

class _ParsedPlanStep {
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool completed;

  const _ParsedPlanStep({required this.title, this.description, this.dueDate, this.completed = false});

  _ParsedPlanStep copyWith({String? description, DateTime? dueDate}) => _ParsedPlanStep(
        title: title,
        description: description ?? this.description,
        dueDate: dueDate ?? this.dueDate,
        completed: completed,
      );
}

class _PostMedia extends StatelessWidget {
  final String mediaUrl;
  final String mediaType; // 'image' | 'video'

  const _PostMedia({required this.mediaUrl, required this.mediaType});

  @override
  Widget build(BuildContext context) {
    if (mediaType == 'video') {
      return _PostVideoPlayer(url: mediaUrl);
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Image.network(
        mediaUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(Icons.image_not_supported_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _PostVideoPlayer extends StatefulWidget {
  final String url;
  const _PostVideoPlayer({required this.url});

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (mounted) setState(() => _initialized = true);
    });
    _controller.addListener(() {
      if (mounted) setState(() => _playing = _controller.value.isPlaying);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_initialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AspectRatio(
      aspectRatio: _initialized && _controller.value.aspectRatio != 0
          ? _controller.value.aspectRatio
          : 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_initialized)
            VideoPlayer(_controller)
          else
            Container(color: bg, child: const Center(child: CenteredLoadingSkeleton())),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggle,
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
