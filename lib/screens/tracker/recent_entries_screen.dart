import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/models/pain_detail.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/tracker_service.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/theme.dart';

class RecentEntriesScreen extends StatelessWidget {
  const RecentEntriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<UserProvider>().currentUser?.id;
    final service = TrackerService();

    return Scaffold(
      appBar: AppBar(
        title: Text('Recent Entries', style: context.textStyles.titleLarge?.semiBold),
        centerTitle: true,
      ),
      body: userId == null
          ? _EmptyState(message: 'Sign in to view your recent entries')
          : StreamBuilder<List<TrackerEntry>>(
              stream: service.recentEntriesStream(
                userId,
                limit: 50,
                includeNutrition: true,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CenteredLoadingSkeleton());
                }
                if (snapshot.hasError) {
                  return _EmptyState(message: 'Could not load entries');
                }
                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return _EmptyState(message: 'No recent entries');
                }
                return ListView.separated(
                  padding: AppSpacing.paddingLg.copyWith(top: AppSpacing.lg),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    // Check entry type and show appropriate card
                    if (e.isNutritionOnlyEntry) {
                      return _NutritionEntryCard(entry: e);
                    } else if (e.isMedicationOnlyEntry) {
                      return _MedicationEntryCard(entry: e);
                    }
                    return _TrackerEntryCard(entry: e);
                  },
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_chart_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
            SizedBox(height: AppSpacing.md),
            Text(message, style: context.textStyles.titleMedium?.withColor(Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final double? maxWidth;

  const _MetricChip({required this.label, required this.icon, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (maxWidth ?? MediaQuery.sizeOf(context).width) * 1.0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outline.withValues(alpha: 0.18), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PainMapPreview extends StatelessWidget {
  final List<PainDetail> painMap;
  const _PainMapPreview({required this.painMap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.paddingSm,
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: cs.error.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.healing, size: 14, color: cs.error),
              SizedBox(width: 4),
              Text(
                'Pain Locations',
                style: context.textStyles.labelSmall?.semiBold.withColor(cs.error),
              ),
            ],
          ),
          SizedBox(height: 4),
          ...painMap.take(3).map((pain) => Padding(
            padding: EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 6, color: cs.onSurfaceVariant),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${BodyAreas.displayName(pain.area)} • ${PainTypes.displayName(pain.type)} (${pain.intensity}/10)',
                        style: context.textStyles.bodySmall?.semiBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (pain.note != null && pain.note!.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text(
                      '"${pain.note}"',
                      style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant).copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          )),
          if (painMap.length > 3)
            Padding(
              padding: EdgeInsets.only(top: 4, left: 12),
              child: Text(
                '+${painMap.length - 3} more',
                style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatFriendlyDate(DateTime date, DateTime createdAt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  final diff = d.difference(today).inDays;
  final time = DateFormat('h:mm a').format(createdAt);
  if (diff == 0) return 'Today • $time';
  if (diff == -1) return 'Yesterday • $time';
  return '${DateFormat('EEE, MMM d, yyyy').format(date)} • $time';
}

/// Card for regular tracker entries with health metrics
class _TrackerEntryCard extends StatelessWidget {
  final TrackerEntry entry;
  const _TrackerEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = entry;
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () => context.push('/tracker/entry', extra: e),
      child: Card(
        color: cs.secondaryContainer.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: cs.secondary.withValues(alpha: 0.3), width: 1),
        ),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.monitor_heart_outlined, size: 18, color: cs.secondary),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tracker Log', style: context.textStyles.labelMedium?.semiBold.withColor(cs.secondary)),
                        Text(
                          _formatFriendlyDate(e.date, e.createdAt),
                          style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (e.painLevel != null)
                      _MetricChip(
                        label: 'Pain: ${e.painLevel}/10',
                        icon: Icons.healing_outlined,
                        maxWidth: constraints.maxWidth,
                      ),
                    if (e.painMap != null && e.painMap!.isNotEmpty)
                      _MetricChip(
                        label: '${e.painMap!.length} pain locations',
                        icon: Icons.location_on_outlined,
                        maxWidth: constraints.maxWidth,
                      ),
                    if (e.mood != null)
                      _MetricChip(
                        label: 'Mood: ${e.mood}',
                        icon: Icons.mood_outlined,
                        maxWidth: constraints.maxWidth,
                      ),
                    if (e.energyLevel != null)
                      _MetricChip(
                        label: 'Energy: ${e.energyLevel}/10',
                        icon: Icons.bolt_outlined,
                        maxWidth: constraints.maxWidth,
                      ),
                    if (e.sleepQuality != null)
                      _MetricChip(
                        label: 'Sleep: ${e.sleepQuality}h',
                        icon: Icons.bedtime_outlined,
                        maxWidth: constraints.maxWidth,
                      ),
                    if (e.spasmFrequency != null)
                      _MetricChip(
                        label: 'Spasms: ${e.spasmFrequency}',
                        icon: Icons.accessibility_new_outlined,
                        maxWidth: constraints.maxWidth,
                      ),
                    if (e.bladderSuccess != null)
                      _MetricChip(
                        label: e.bladderSuccess! ? 'Bladder: ✓' : 'Bladder: –',
                        icon: Icons.water_drop_outlined,
                        maxWidth: constraints.maxWidth,
                      ),
                    if (e.bowelProgram != null)
                      _MetricChip(
                        label: e.bowelProgram! ? 'Bowel: ✓' : 'Bowel: –',
                        icon: Icons.medical_services_outlined,
                        maxWidth: constraints.maxWidth,
                      ),
                    if (e.steps != null)
                      _MetricChip(
                        label: 'Steps: ${e.steps}',
                        icon: Icons.directions_walk,
                        maxWidth: constraints.maxWidth,
                      ),
                    if (e.systolicBP != null && e.diastolicBP != null)
                      _MetricChip(
                        label: 'BP: ${e.systolicBP}/${e.diastolicBP}',
                        icon: Icons.monitor_heart_outlined,
                        maxWidth: constraints.maxWidth,
                      ),
                  ],
                ),
              ),
              if (e.painMap != null && e.painMap!.isNotEmpty) ...[
                SizedBox(height: AppSpacing.sm),
                _PainMapPreview(painMap: e.painMap!),
              ],
              if ((e.notes ?? '').isNotEmpty) ...[
                SizedBox(height: AppSpacing.sm),
                Text(e.notes!, style: context.textStyles.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Card for nutrition-only entries with a distinct visual style
class _NutritionEntryCard extends StatelessWidget {
  final TrackerEntry entry;
  const _NutritionEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = entry;
    
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () => context.push('/tracker/entry', extra: e),
      child: Card(
        color: cs.tertiaryContainer.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: cs.tertiary.withValues(alpha: 0.3), width: 1),
        ),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.tertiary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.restaurant_outlined, size: 18, color: cs.tertiary),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nutrition Log', style: context.textStyles.labelMedium?.semiBold.withColor(cs.tertiary)),
                        Text(
                          _formatFriendlyDate(e.date, e.createdAt),
                          style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.tertiary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Daily Log',
                      style: context.textStyles.labelSmall?.semiBold.withColor(cs.tertiary),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'View detailed nutrition and meal information',
                style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card for medication-only entries with a distinct visual style
class _MedicationEntryCard extends StatelessWidget {
  final TrackerEntry entry;
  const _MedicationEntryCard({required this.entry});

  String _formatMedTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final dt = DateTime.parse(isoTime);
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = entry;
    final medications = e.medications ?? [];
    final logs = e.medicationLogs ?? [];
    
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () => context.push('/tracker/entry', extra: e),
      child: Card(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.3), width: 1),
        ),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.medication_rounded, size: 18, color: cs.primary),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Medication Log', style: context.textStyles.labelMedium?.semiBold.withColor(cs.primary)),
                        Text(
                          _formatFriendlyDate(e.date, e.createdAt),
                          style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${medications.length} ${medications.length == 1 ? 'med' : 'meds'}',
                      style: context.textStyles.labelSmall?.semiBold.withColor(cs.primary),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              // List medications with their logged times
              ...logs.map((log) {
                final time = _formatMedTime(log.takenAt);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: cs.primary),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          log.name,
                          style: context.textStyles.bodyMedium?.semiBold,
                        ),
                      ),
                      if (log.doseMg != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '${log.doseMg}mg',
                            style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                          ),
                        ),
                      if (time.isNotEmpty)
                        Text(time, style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
                    ],
                  ),
                );
              }),
              // Show any medications without logs
              ...medications.where((m) => !logs.any((l) => l.name == m)).map((medName) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: cs.primary),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(medName, style: context.textStyles.bodyMedium?.semiBold),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
