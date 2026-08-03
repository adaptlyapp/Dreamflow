import 'package:flutter/material.dart';
import 'package:wellspring/models/group.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/skeletons.dart';

/// Result returned from [PlanShareSheet] containing the edited content and
/// optional community destination.
class PlanShareResult {
  final String content;
  final Group? community;

  PlanShareResult({required this.content, this.community});
}

/// Bottom sheet for previewing and editing a milestone plan template and
/// selecting where to share it (feed or a joined community).
class PlanShareSheet extends StatefulWidget {
  final String conditionName;
  final List<Milestone> milestones;
  final String initialNote;
  final Future<List<Group>> Function() loadCommunities;

  const PlanShareSheet({super.key, required this.conditionName, required this.milestones, required this.initialNote, required this.loadCommunities});

  @override
  State<PlanShareSheet> createState() => _PlanShareSheetState();
}

class _PlanShareSheetState extends State<PlanShareSheet> {
  late final TextEditingController _noteController;
  String _destination = 'feed';
  bool _loadingCommunities = true;
  List<Group> _communities = [];
  Group? _selectedCommunity;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
    _fetchCommunities();
  }

  Future<void> _fetchCommunities() async {
    try {
      final list = await widget.loadCommunities();
      if (!mounted) return;
      setState(() {
        _communities = list;
        _selectedCommunity = list.isNotEmpty ? list.first : null;
      });
    } catch (e) {
      debugPrint('PlanShareSheet communities error: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingCommunities = false);
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _composeTemplateText();
    if (_destination == 'community' && _selectedCommunity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a community to share to.')));
      return;
    }
    Navigator.of(context).pop(PlanShareResult(content: text, community: _destination == 'community' ? _selectedCommunity : null));
  }

  String _composeTemplateText() {
    final loc = MaterialLocalizations.of(context);
    final completed = widget.milestones.where((m) => m.completed).length;
    final upcoming = widget.milestones
        .where((m) => m.dueDate != null && !m.completed)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final nextDue = upcoming.isNotEmpty ? upcoming.first : null;
    final note = _noteController.text.trim();

    final buffer = StringBuffer();
    buffer.writeln('Plan template for ${widget.conditionName}');
    buffer.writeln('Steps: ${widget.milestones.length} | Completed: $completed${nextDue != null ? ' | Next due: ${loc.formatMediumDate(nextDue.dueDate!)}' : ''}');
    if (note.isNotEmpty) buffer.writeln('\n$note');

    for (int i = 0; i < widget.milestones.length; i++) {
      final m = widget.milestones[i];
      final status = m.completed ? '☑' : '☐';
      final due = m.dueDate != null ? 'Due ${loc.formatMediumDate(m.dueDate!)}' : 'No due date';
      buffer.writeln('$status ${i + 1}. ${m.title} ($due)');
      if (m.description != null && m.description!.isNotEmpty) {
        buffer.writeln('   · ${m.description}');
      }
    }

    buffer.writeln('\nCopy to your plan and check off each milestone as you go.');
    return buffer.toString().trim();
  }

  Widget _buildDestinationPicker(ColorScheme scheme) {
    final hasCommunities = _communities.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Destination', style: context.textStyles.labelLarge?.semiBold),
        SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: const Text('Feed'),
              selected: _destination == 'feed',
              onSelected: (_) => setState(() => _destination = 'feed'),
            ),
            ChoiceChip(
              label: const Text('Community'),
              selected: _destination == 'community',
              onSelected: hasCommunities ? (_) => setState(() => _destination = 'community') : null,
            ),
          ],
        ),
        if (_destination == 'community') ...[
          SizedBox(height: AppSpacing.sm),
          if (_loadingCommunities)
            const SizedBox(height: 32, child: InlineLoadingDot())
          else if (_communities.isEmpty)
            Text('Join a community to share this plan there.', style: context.textStyles.bodyMedium?.withColor(scheme.onSurfaceVariant))
          else
            DropdownButtonFormField<Group>(
              value: _selectedCommunity,
              items: _communities
                  .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                  .toList(),
              onChanged: (g) => setState(() => _selectedCommunity = g),
              decoration: const InputDecoration(labelText: 'Choose community'),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share plan', style: context.textStyles.titleLarge?.semiBold),
            SizedBox(height: AppSpacing.xs),
            Text('Preview and edit your ${widget.milestones.length}-step plan for ${widget.conditionName}.', style: context.textStyles.bodyMedium?.withColor(scheme.onSurfaceVariant)),
            SizedBox(height: AppSpacing.md),
            PlanSharePreviewCard(conditionName: widget.conditionName, milestones: widget.milestones, note: _noteController.text),
            SizedBox(height: AppSpacing.md),
            Text('Add a note (optional)', style: context.textStyles.labelLarge?.semiBold),
            SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Add context or encouragement...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            _buildDestinationPicker(scheme),
            SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlanSharePreviewCard extends StatelessWidget {
  final String conditionName;
  final List<Milestone> milestones;
  final String note;

  const PlanSharePreviewCard({super.key, required this.conditionName, required this.milestones, required this.note});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = MaterialLocalizations.of(context);
    final completed = milestones.where((m) => m.completed).length;
    final nextDue = milestones
        .where((m) => m.dueDate != null && !m.completed)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final upcoming = nextDue.isNotEmpty ? nextDue.first : null;
    final visibleCount = milestones.length > 4 ? 4 : milestones.length;
    final visibleMilestones = List.generate(visibleCount, (i) => MapEntry(i, milestones[i]));
    final remainingCount = milestones.length - visibleCount;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: scheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Icon(Icons.timeline, color: scheme.primary),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(conditionName, style: context.textStyles.titleMedium?.semiBold),
                    Text('${milestones.length} milestones • $completed completed', style: context.textStyles.bodySmall?.withColor(scheme.onSurfaceVariant)),
                    if (upcoming != null)
                      Text('Next due ${loc.formatMediumDate(upcoming.dueDate!)}', style: context.textStyles.bodySmall?.withColor(scheme.primary)),
                  ],
                ),
              ),
            ],
          ),
          if (note.trim().isNotEmpty) ...[
            SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: AppSpacing.paddingSm,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Text(note.trim(), style: context.textStyles.bodyMedium),
            ),
          ],
          SizedBox(height: AppSpacing.sm),
          ...visibleMilestones.map((entry) => Padding(
                padding: EdgeInsets.only(bottom: visibleMilestones.last == entry ? 0 : AppSpacing.sm),
                child: PlanSharePreviewTile(milestone: entry.value, index: entry.key + 1),
              )),
          if (remainingCount > 0) ...[
            SizedBox(height: AppSpacing.xs),
            Text('+$remainingCount more milestones', style: context.textStyles.bodySmall?.withColor(scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class PlanSharePreviewTile extends StatelessWidget {
  final Milestone milestone;
  final int index;

  const PlanSharePreviewTile({super.key, required this.milestone, required this.index});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loc = MaterialLocalizations.of(context);
    final due = milestone.dueDate != null ? loc.formatMediumDate(milestone.dueDate!) : 'No due date';
    final statusBackground = milestone.completed ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final statusColor = milestone.completed ? scheme.onPrimaryContainer : scheme.onSurface;

    return Container(
      padding: AppSpacing.paddingSm,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(milestone.completed ? Icons.check_circle : Icons.radio_button_unchecked, color: milestone.completed ? scheme.primary : scheme.onSurfaceVariant),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: scheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: Text('#$index', style: context.textStyles.labelSmall?.withColor(scheme.primary)),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(milestone.title, style: context.textStyles.labelLarge?.semiBold, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Chip(
                      label: Text('Due $due', style: context.textStyles.labelSmall?.withColor(scheme.onPrimary)),
                      backgroundColor: scheme.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    Chip(
                      label: Text(milestone.completed ? 'Completed' : 'Upcoming', style: context.textStyles.labelSmall?.withColor(statusColor)),
                      backgroundColor: statusBackground,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  ],
                ),
                if (milestone.description != null && milestone.description!.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.xs),
                  Text(milestone.description!, style: context.textStyles.bodySmall?.withColor(scheme.onSurfaceVariant), maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}