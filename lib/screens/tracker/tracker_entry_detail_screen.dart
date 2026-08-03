import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/models/pain_detail.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/services/tracker_service.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/services/record_signing_service.dart';
import 'package:wellspring/services/audit_log_service.dart';

class TrackerEntryDetailScreen extends StatefulWidget {
  final TrackerEntry entry;
  const TrackerEntryDetailScreen({super.key, required this.entry});

  @override
  State<TrackerEntryDetailScreen> createState() =>
      _TrackerEntryDetailScreenState();
}

class _TrackerEntryDetailScreenState extends State<TrackerEntryDetailScreen> {
  late TrackerEntry _entry;
  final _trackerService = TrackerService();
  final _signingService = RecordSigningService();
  final _audit = AuditLogService();
  bool _isSigned = false;
  Map<String, dynamic>? _signMeta;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _loadSignMeta();
    // Debug: Log pain map data
    debugPrint(
        'TrackerEntryDetail: painMap=${_entry.painMap?.length ?? 0} items');
    if (_entry.painMap != null) {
      for (var pain in _entry.painMap!) {
        debugPrint(
            '  - ${pain.area}: ${pain.type} (${pain.intensity}/10) note="${pain.note}"');
      }
    }
    // Record a PHI read for viewing the entry details
    _audit.recordRead(
      subjectUid: _entry.userId,
      resource: 'users/${_entry.userId}/tracker_entries/${_entry.id}',
      resourceType: 'tracker_entry',
    );
  }

  Future<void> _onEdit() async {
    if (_isSigned) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Signed records are immutable. Editing is disabled.')));
      return;
    }
    final updated = await context.push<TrackerEntry>('/tracker/add', extra: _entry);
    if (updated != null && mounted) {
      setState(() => _entry = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry updated')),
      );
    }
  }

  Future<void> _onDelete() async {
    if (_isSigned) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed records cannot be deleted.')));
      return;
    }
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.delete_outline, color: cs.error),
                  SizedBox(width: AppSpacing.sm),
                  Text('Delete entry?',
                      style: context.textStyles.titleLarge?.semiBold),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'This action cannot be undone.',
                style: context.textStyles.bodyMedium
                    ?.withColor(cs.onSurfaceVariant),
              ),
              SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(cs.error),
                        foregroundColor: WidgetStatePropertyAll(cs.onError),
                      ),
                      onPressed: () => context.pop(true),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
              SizedBox(
                  height:
                      MediaQuery.of(context).padding.bottom + AppSpacing.sm),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      try {
        await _trackerService.deleteEntry(_entry.userId, _entry.id);
        if (!mounted) return;
        context.pop(true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete entry: $e')),
        );
      }
    }
  }

  Future<void> _loadSignMeta() async {
    try {
      final meta = await _trackerService.getSignMeta(_entry.userId, _entry.id);
      if (!mounted) return;
      setState(() {
        _signMeta = meta;
        _isSigned = (meta?['signed'] == true);
      });
    } catch (e) {
      // Non-fatal
    }
  }

  Future<void> _onSign() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.verified_outlined, color: cs.primary),
                SizedBox(width: AppSpacing.sm),
                Text('Digitally sign record',
                    style: context.textStyles.titleLarge?.semiBold),
              ]),
              SizedBox(height: AppSpacing.sm),
              Text(
                'This locks the entry and adds a tamper-evident signature. You will no longer be able to edit or delete it.',
                style: context.textStyles.bodyMedium
                    ?.withColor(cs.onSurfaceVariant),
              ),
              SizedBox(height: AppSpacing.lg),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => context.pop(false),
                        child: const Text('Cancel'))),
                SizedBox(width: AppSpacing.md),
                Expanded(
                    child: FilledButton(
                        onPressed: () => context.pop(true),
                        child: const Text('Sign now'))),
              ]),
              SizedBox(
                  height:
                      MediaQuery.of(context).padding.bottom + AppSpacing.sm),
            ],
          ),
        );
      },
    );
    if (confirmed != true) return;
    try {
      final res = await _signingService.signTrackerEntry(
          userId: _entry.userId, entryId: _entry.id);
      if (!mounted) return;
      setState(() {
        _signMeta = (res['signMeta'] as Map?)?.cast<String, dynamic>();
        _isSigned = true;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Record signed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to sign: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String _prettyDate(DateTime dt) {
      final now = DateTime.now();
      final isSameDay =
          dt.year == now.year && dt.month == now.month && dt.day == now.day;
      final yesterday = now.subtract(const Duration(days: 1));
      final isYesterday = dt.year == yesterday.year &&
          dt.month == yesterday.month &&
          dt.day == yesterday.day;
      if (isSameDay) {
        return 'Today • ${DateFormat('h:mm a').format(dt)}';
      }
      if (isYesterday) {
        return 'Yesterday • ${DateFormat('h:mm a').format(dt)}';
      }
      return DateFormat('EEE, MMM d, yyyy • h:mm a').format(dt);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Entry Details',
            style: context.textStyles.titleLarge?.semiBold),
        centerTitle: true,
        actions: [
          if (!_isSigned)
            IconButton(
              tooltip: 'Edit',
              onPressed: _onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          if (!_isSigned)
            IconButton(
              tooltip: 'Delete',
              onPressed: _onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          if (_isSigned)
            IconButton(
              tooltip: 'Signed',
              onPressed: null,
              icon: Icon(Icons.verified,
                  color: Theme.of(context).colorScheme.primary),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            builder: (context, t, child) {
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 12),
                  child: child,
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card with friendly date
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: AppSpacing.paddingLg,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _DateBadge(date: _entry.date),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('EEEE, MMM d, yyyy')
                                    .format(_entry.date),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyles.titleMedium?.semiBold,
                              ),
                              SizedBox(height: AppSpacing.xs),
                              Text(
                                _prettyDate(_entry.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyles.labelSmall
                                    ?.withColor(cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                if (_isSigned) ...[
                  SizedBox(height: AppSpacing.lg),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: AppSpacing.paddingLg,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.verified,
                                color: cs.primary, size: 22),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Digitally Signed',
                                    style: context
                                        .textStyles.titleMedium?.semiBold),
                                SizedBox(height: 4),
                                Text(
                                  _signMeta?['hashBase64'] != null
                                      ? 'Hash: ' +
                                          (_signMeta!['hashBase64'] as String)
                                              .substring(0, 16) +
                                          '…'
                                      : 'Tamper-evident signature added',
                                  style: context.textStyles.labelSmall
                                      ?.withColor(cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
                SizedBox(height: AppSpacing.lg),
                if (_entry.painLevel != null) ...[
                  _PainLevelCard(pain: _entry.painLevel!.clamp(0, 10)),
                  SizedBox(height: AppSpacing.lg),
                ],

                // Pain map summary
                if (_entry.painMap != null && _entry.painMap!.isNotEmpty) ...[
                  _PainMapSummary(painMap: _entry.painMap!),
                  SizedBox(height: AppSpacing.lg),
                ],
                // Metrics section header
                Row(
                  children: [
                    Icon(Icons.insights, size: 18, color: cs.onSurfaceVariant),
                    SizedBox(width: AppSpacing.xs),
                    Text('Metrics',
                        style: context.textStyles.labelSmall
                            ?.withColor(cs.onSurfaceVariant)),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                _MetricsGrid(entry: _entry),
                if ((_entry.notes ?? '').isNotEmpty) ...[
                  SizedBox(height: AppSpacing.lg),
                  // Notes section
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: AppSpacing.paddingLg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notes, color: cs.primary),
                              SizedBox(width: AppSpacing.sm),
                              Text('Notes',
                                  style:
                                      context.textStyles.titleMedium?.semiBold),
                            ],
                          ),
                          SizedBox(height: AppSpacing.sm),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: Text(
                              _entry.notes!,
                              style: context.textStyles.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if ((_entry.medications != null &&
                        _entry.medications!.isNotEmpty) ||
                    (_entry.symptoms != null && _entry.symptoms!.isNotEmpty) ||
                    (_entry.triggers != null && _entry.triggers!.isNotEmpty) ||
                    (_entry.activities != null &&
                        _entry.activities!.isNotEmpty)) ...[
                  SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Icon(Icons.list_alt,
                          size: 18, color: cs.onSurfaceVariant),
                      SizedBox(width: AppSpacing.xs),
                      Text('Additional Info',
                          style: context.textStyles.labelSmall
                              ?.withColor(cs.onSurfaceVariant)),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  if ((_entry.medicationLogs != null && _entry.medicationLogs!.isNotEmpty) ||
                      (_entry.medications != null && _entry.medications!.isNotEmpty))
                    _StructuredMedicationSection(entry: _entry),
                  if ((_entry.symptomLogs != null && _entry.symptomLogs!.isNotEmpty) ||
                      (_entry.symptoms != null && _entry.symptoms!.isNotEmpty))
                    _StructuredSymptomSection(entry: _entry),
                  if ((_entry.triggerLogs != null && _entry.triggerLogs!.isNotEmpty) ||
                      (_entry.triggers != null && _entry.triggers!.isNotEmpty))
                    _StructuredTriggerSection(entry: _entry),
                  if ((_entry.activityLogs != null && _entry.activityLogs!.isNotEmpty) ||
                      (_entry.activities != null && _entry.activities!.isNotEmpty))
                    _StructuredActivitySection(entry: _entry),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final TrackerEntry entry;
  const _MetricsGrid({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = <_MetricItem>[
      if (entry.mood != null)
        _MetricItem(
          title: 'Mood',
          value: entry.mood!,
          icon: Icons.mood_outlined,
        ),
      if (entry.steps != null)
        _MetricItem(
          title: 'Steps',
          value: '${entry.steps}',
          icon: Icons.directions_walk,
        ),
      if (entry.energyLevel != null)
        _MetricItem(
          title: 'Energy',
          value: '${entry.energyLevel}/10',
          icon: Icons.bolt_outlined,
          scaleOutOfTen: entry.energyLevel!.clamp(0, 10),
        ),
      if (entry.sleepQuality != null)
        _MetricItem(
          title: 'Sleep Hours',
          value: '${entry.sleepQuality}h',
          icon: Icons.bedtime_outlined,
          scaleOutOfTen: entry.sleepQuality!.clamp(0, 10),
        ),
      if (entry.systolicBP != null && entry.diastolicBP != null)
        _MetricItem(
          title: 'Blood Pressure',
          value: '${entry.systolicBP}/${entry.diastolicBP} mmHg',
          icon: Icons.monitor_heart_outlined,
        ),
      if (entry.heartRate != null)
        _MetricItem(
          title: 'Heart Rate',
          value: '${entry.heartRate} bpm',
          icon: Icons.favorite_border,
        ),
      if (entry.spasmFrequency != null)
        _MetricItem(
          title: 'Spasms',
          value: '${entry.spasmFrequency}',
          icon: Icons.accessibility_new_outlined,
        ),
      if (entry.bladderSuccess != null)
        _MetricItem(
          title: 'Bladder',
          value: entry.bladderSuccess! ? 'Yes' : 'No',
          icon: Icons.water_drop_outlined,
          valueChipColor:
              entry.bladderSuccess! ? cs.primary : cs.surfaceVariant,
          valueTextColor:
              entry.bladderSuccess! ? cs.onPrimary : cs.onSurfaceVariant,
        ),
      if (entry.bowelProgram != null)
        _MetricItem(
          title: 'Bowel Program',
          value: entry.bowelProgram! ? 'Yes' : 'No',
          icon: Icons.medical_services_outlined,
          valueChipColor: entry.bowelProgram! ? cs.primary : cs.surfaceVariant,
          valueTextColor:
              entry.bowelProgram! ? cs.onPrimary : cs.onSurfaceVariant,
        ),
      if (entry.weight != null)
        _MetricItem(
          title: 'Weight',
          value: '${entry.weight} Lb',
          icon: Icons.scale_outlined,
        ),
      if (entry.temperature != null)
        _MetricItem(
          title: 'Temperature',
          value: '${entry.temperature}\u00b0C',
          icon: Icons.thermostat_outlined,
        ),
    ];

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No metrics recorded for this entry',
          style: context.textStyles.bodyMedium
              ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 360 ? 1 : 2;
        const spacing = 12.0;
        final itemWidth = crossAxisCount == 1
            ? width
            : (width - spacing) / 2; // two columns with spacing

        // Use Wrap instead of Grid to allow variable-height cards (prevents overflow)
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final i in items)
              SizedBox(
                width: itemWidth,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: AppSpacing.paddingMd,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(i.icon,
                            color: Theme.of(context).colorScheme.primary,
                            size: 22),
                        SizedBox(width: AppSpacing.md),
                        Flexible(
                          fit: FlexFit.loose,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                i.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyles.labelSmall?.withColor(
                                  Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              SizedBox(height: 4),
                              _MetricValue(
                                value: i.value,
                                chipColor: i.valueChipColor,
                                textColor: i.valueTextColor,
                              ),
                              if (i.scaleOutOfTen != null) ...[
                                SizedBox(height: 6),
                                _TenSegmentMeter(value: i.scaleOutOfTen!),
                              ]
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DateBadge extends StatelessWidget {
  final DateTime date;
  const _DateBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final day = DateFormat('d').format(date);
    final month = DateFormat('MMM').format(date).toUpperCase();
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.18),
            cs.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25), width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              month,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.withColor(cs.onPrimaryContainer),
            ),
            Text(
              day,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.semiBold
                  .withColor(cs.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _PainLevelCard extends StatelessWidget {
  final int pain; // 0..10
  const _PainLevelCard({required this.pain});

  String _labelFor(int p) {
    if (p <= 2) return 'Minimal';
    if (p <= 4) return 'Mild';
    if (p <= 6) return 'Moderate';
    if (p <= 8) return 'Severe';
    return 'Extreme';
  }

  IconData _iconFor(int p) {
    if (p <= 2) return Icons.sentiment_very_satisfied;
    if (p <= 4) return Icons.sentiment_satisfied_alt;
    if (p <= 6) return Icons.sentiment_neutral;
    if (p <= 8) return Icons.sentiment_dissatisfied;
    return Icons.sentiment_very_dissatisfied;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = _labelFor(pain);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_iconFor(pain), color: cs.primary, size: 22),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pain Level',
                          style: context.textStyles.labelSmall
                              ?.withColor(cs.onSurfaceVariant)),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$pain/10',
                            style: context.textStyles.titleMedium?.semiBold,
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.error
                                  .withValues(alpha: pain >= 7 ? 0.20 : 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              label,
                              style: context.textStyles.labelSmall?.semiBold
                                  .withColor(cs.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            _GradientBar(value: pain / 10.0),
            SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0',
                    style: context.textStyles.labelSmall
                        ?.withColor(cs.onSurfaceVariant)),
                Text('10',
                    style: context.textStyles.labelSmall
                        ?.withColor(cs.onSurfaceVariant)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _GradientBar extends StatelessWidget {
  final double value; // 0..1
  const _GradientBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final thumbX = (width * value).clamp(8.0, width - 8.0);
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Track
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            // Fill
            FractionallySizedBox(
              widthFactor: value,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary,
                      cs.tertiary,
                      cs.error,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            // Thumb
            Positioned(
              left: thumbX - 8,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? cs.onSurface
                      : cs.surface,
                  border: Border.all(
                      color: cs.outline.withValues(alpha: 0.35), width: 1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricItem {
  final String title;
  final String value;
  final IconData icon;
  final Color? valueChipColor;
  final Color? valueTextColor;
  final int? scaleOutOfTen; // for 1..10 metrics like sleep/energy
  _MetricItem({
    required this.title,
    required this.value,
    required this.icon,
    this.valueChipColor,
    this.valueTextColor,
    this.scaleOutOfTen,
  });
}

class _MetricValue extends StatelessWidget {
  final String value;
  final Color? chipColor;
  final Color? textColor;
  const _MetricValue({required this.value, this.chipColor, this.textColor});

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles.titleSmall?.semiBold;
    // Use a light chip style when chipColor is provided (booleans), otherwise plain text
    if (chipColor != null) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ts
              ?.withColor(textColor ?? Theme.of(context).colorScheme.onPrimary),
        ),
      );
    }
    return Text(
      value,
      maxLines: 2, // allow wrap for longer values (e.g., Mood text)
      overflow: TextOverflow.ellipsis,
      style: ts,
    );
  }
}

class _TenSegmentMeter extends StatelessWidget {
  final int value; // 0..10
  const _TenSegmentMeter({required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const total = 10;
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: List.generate(total, (index) {
        final active = index < value;
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: index == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: active ? cs.primary : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _PainMapSummary extends StatelessWidget {
  final List<PainDetail> painMap;
  const _PainMapSummary({required this.painMap});

  Color _getIntensityColor(BuildContext context, int intensity) {
    final cs = Theme.of(context).colorScheme;
    if (intensity <= 3) return Colors.green;
    if (intensity <= 5) return Colors.amber;
    if (intensity <= 7) return Colors.orange;
    return cs.error;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5), width: 1),
      ),
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.primary.withValues(alpha: 0.15),
                        cs.primary.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.my_location, color: cs.primary, size: 20),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pain Details',
                          style: context.textStyles.titleMedium?.semiBold),
                      SizedBox(height: 4),
                      Text(
                        '${painMap.length} location${painMap.length == 1 ? '' : 's'}',
                        style: context.textStyles.bodySmall
                            ?.withColor(cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            ...painMap.asMap().entries.map((entry) {
              final index = entry.key;
              final pain = entry.value;
              final intensityColor =
                  _getIntensityColor(context, pain.intensity);

              return Padding(
                padding: EdgeInsets.only(
                    bottom: index < painMap.length - 1 ? AppSpacing.md : 0),
                child: Container(
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        cs.surfaceContainerHighest.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: intensityColor.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: intensityColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on,
                              size: 16,
                              color: intensityColor,
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  BodyAreas.displayName(pain.area),
                                  style:
                                      context.textStyles.titleSmall?.semiBold,
                                ),
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: cs.surface,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: cs.outlineVariant
                                              .withValues(alpha: 0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.donut_small,
                                              size: 12,
                                              color: cs.onSurfaceVariant),
                                          SizedBox(width: 4),
                                          Text(
                                            PainTypes.displayName(pain.type),
                                            style: context.textStyles.labelSmall
                                                ?.withColor(
                                                    cs.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: intensityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${pain.intensity}',
                                  style: context.textStyles.titleLarge?.semiBold
                                      .withColor(intensityColor),
                                ),
                                Text(
                                  '/10',
                                  style: context.textStyles.labelSmall
                                      ?.withColor(intensityColor.withValues(
                                          alpha: 0.7)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (pain.note != null && pain.note!.isNotEmpty) ...[
                        SizedBox(height: AppSpacing.sm),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.format_quote,
                                  size: 16,
                                  color: cs.primary.withValues(alpha: 0.6)),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  pain.note!,
                                  style: context.textStyles.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _ListSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary, size: 20),
                SizedBox(width: AppSpacing.sm),
                Text(title, style: context.textStyles.titleSmall?.semiBold),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: items
                  .map((item) => Chip(
                        label: Text(item),
                        backgroundColor: cs.secondaryContainer,
                        labelStyle: context.textStyles.bodySmall
                            ?.withColor(cs.onSecondaryContainer),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StructuredMedicationSection extends StatelessWidget {
  final TrackerEntry entry;
  const _StructuredMedicationSection({required this.entry});

  @override
  Widget build(BuildContext context) {
    final logs = entry.medicationLogs;
    if (logs != null && logs.isNotEmpty) {
      return _StructuredCardSection(
        title: 'Medications',
        icon: Icons.medication_outlined,
        children: logs
            .map(
              (m) => _StructuredRow(
                title: m.name,
                subtitle: _joinParts([
                  if (m.doseMg != null) '${m.doseMg} mg',
                  if (m.takenAt != null) _timeOnly(context, m.takenAt!),
                  if (m.isPrn != null) (m.isPrn! ? 'PRN' : 'Scheduled'),
                  if (m.effectScore != null) 'Helped ${m.effectScore}/5',
                ]),
              ),
            )
            .toList(),
      );
    }
    return _ListSection(
      title: 'Medications',
      icon: Icons.medication_outlined,
      items: entry.medications ?? const [],
    );
  }
}

class _StructuredSymptomSection extends StatelessWidget {
  final TrackerEntry entry;
  const _StructuredSymptomSection({required this.entry});

  @override
  Widget build(BuildContext context) {
    final logs = entry.symptomLogs;
    if (logs != null && logs.isNotEmpty) {
      return _StructuredCardSection(
        title: 'Symptoms',
        icon: Icons.sick_outlined,
        children: logs
            .map(
              (s) => _StructuredRow(
                title: s.name,
                subtitle: _joinParts([
                  if (s.intensity != null) 'Intensity ${s.intensity}/10',
                  if (s.durationMin != null) '${s.durationMin} min',
                  if ((s.bodyArea ?? '').trim().isNotEmpty) s.bodyArea!.trim(),
                  if (s.onsetAt != null) 'Started ${_timeOnly(context, s.onsetAt!)}',
                ]),
              ),
            )
            .toList(),
      );
    }
    return _ListSection(
      title: 'Symptoms',
      icon: Icons.sick_outlined,
      items: entry.symptoms ?? const [],
    );
  }
}

class _StructuredTriggerSection extends StatelessWidget {
  final TrackerEntry entry;
  const _StructuredTriggerSection({required this.entry});

  @override
  Widget build(BuildContext context) {
    final logs = entry.triggerLogs;
    if (logs != null && logs.isNotEmpty) {
      return _StructuredCardSection(
        title: 'Triggers',
        icon: Icons.warning_amber_outlined,
        children: logs
            .map(
              (t) => _StructuredRow(
                title: t.name,
                subtitle: _joinParts([
                  if (t.temperatureF != null) '${t.temperatureF}°F',
                  if (t.durationMin != null) '${t.durationMin} min',
                  if (t.jacket == true) 'Jacket',
                  if (t.gloves == true) 'Gloves',
                ]),
              ),
            )
            .toList(),
      );
    }
    return _ListSection(
      title: 'Triggers',
      icon: Icons.warning_amber_outlined,
      items: entry.triggers ?? const [],
    );
  }
}

class _StructuredActivitySection extends StatelessWidget {
  final TrackerEntry entry;
  const _StructuredActivitySection({required this.entry});

  @override
  Widget build(BuildContext context) {
    final logs = entry.activityLogs;
    if (logs != null && logs.isNotEmpty) {
      return _StructuredCardSection(
        title: 'Activities',
        icon: Icons.local_activity_outlined,
        children: logs
            .map(
              (a) => _StructuredRow(
                title: a.name,
                subtitle: _joinParts([
                  if ((a.purpose ?? '').trim().isNotEmpty) a.purpose!.trim(),
                  if (a.distanceMi != null) '${a.distanceMi} mi',
                  if ((a.assist ?? '').trim().isNotEmpty) 'Assist: ${a.assist!.trim()}',
                  if (a.fatigueAfter != null) 'Fatigue ${a.fatigueAfter}/5',
                ]),
              ),
            )
            .toList(),
      );
    }
    return _ListSection(
      title: 'Activities',
      icon: Icons.local_activity_outlined,
      items: entry.activities ?? const [],
    );
  }
}

class _StructuredCardSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _StructuredCardSection({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary, size: 20),
                SizedBox(width: AppSpacing.sm),
                Text(title, style: context.textStyles.titleSmall?.semiBold),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StructuredRow extends StatelessWidget {
  final String title;
  final String subtitle;
  const _StructuredRow({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.textStyles.titleSmall?.semiBold, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle.trim().isNotEmpty) ...[
              SizedBox(height: 4),
              Text(subtitle, style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
            ]
          ],
        ),
      ),
    );
  }
}

String _joinParts(List<String> parts) => parts.where((p) => p.trim().isNotEmpty).join(' • ');

String _timeOnly(BuildContext context, String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  return TimeOfDay.fromDateTime(dt).format(context);
}
