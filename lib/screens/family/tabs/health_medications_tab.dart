import 'package:flutter/material.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/models/user.dart';
import 'package:wellspring/theme.dart';
import 'package:intl/intl.dart';

/// Family-side view of the patient's medication history.
///
/// Restructured for clarity:
///  • Header summary tiles (total doses, days tracked, top med, latest log)
///  • 30-day adherence strip (which days had medications logged)
///  • Per-medication frequency list with proportional progress bars
///  • Timeline of recent logs (grouped by date) with dose + effect chips
class HealthMedicationsTab extends StatelessWidget {
  const HealthMedicationsTab({super.key, required this.entries, this.patientUser});

  final List<TrackerEntry> entries;
  final User? patientUser;

  static const Color _accent = Color(0xFF22D3EE);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ---------- Aggregations ----------
    final medDayCount = <String, int>{};
    final medDoseCount = <String, int>{};
    int totalDoses = 0;
    int daysWithMeds = 0;
    DateTime? lastLogDate;

    // Newest -> oldest by date
    final sortedEntries = [...entries]..sort((a, b) => b.date.compareTo(a.date));

    final daysWithMedSet = <String>{};
    for (final e in sortedEntries) {
      final logs = e.medicationLogs;
      final plain = e.medications;
      final hasAny =
          (logs != null && logs.isNotEmpty) || (plain != null && plain.isNotEmpty);
      if (!hasAny) continue;

      lastLogDate ??= e.date;
      daysWithMedSet.add(DateFormat('yyyy-MM-dd').format(e.date));

      if (logs != null && logs.isNotEmpty) {
        final seenForThisDay = <String>{};
        for (final l in logs) {
          final name = l.name.trim();
          if (name.isEmpty) continue;
          totalDoses += 1;
          medDoseCount[name] = (medDoseCount[name] ?? 0) + 1;
          if (seenForThisDay.add(name)) {
            medDayCount[name] = (medDayCount[name] ?? 0) + 1;
          }
        }
      } else if (plain != null) {
        for (final name in plain) {
          if (name.trim().isEmpty) continue;
          medDayCount[name] = (medDayCount[name] ?? 0) + 1;
          medDoseCount[name] = (medDoseCount[name] ?? 0) + 1;
          totalDoses += 1;
        }
      }
    }
    daysWithMeds = daysWithMedSet.length;

    final sortedMeds = medDayCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topMedName = sortedMeds.isNotEmpty ? sortedMeds.first.key : null;

    // Recent meds entries (timeline)
    final recentMedEntries = sortedEntries
        .where((e) =>
            (e.medicationLogs?.isNotEmpty ?? false) ||
            (e.medications?.isNotEmpty ?? false))
        .take(14)
        .toList();

    // ---------- Empty state ----------
    if (sortedMeds.isEmpty) {
      return _EmptyState(cs: cs);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Patient's Current Medications ----
          if (patientUser != null && patientUser!.medications.isNotEmpty) ...[
            _SectionHeader(
              title: 'Current Medications',
              subtitle: '${patientUser!.medications.length} prescribed medication${patientUser!.medications.length != 1 ? 's' : ''}',
              icon: Icons.medication_liquid,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...patientUser!.medications.map((med) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _accent.withValues(alpha: 0.08),
                    _accent.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _accent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.medication, color: _accent, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          med.name,
                          style: context.textStyles.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (med.dosage != null && med.dosage!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            med.dosage!,
                            style: context.textStyles.bodyMedium?.withColor(
                              cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (med.times.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: med.times.map((time) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                time,
                                style: context.textStyles.labelSmall?.copyWith(
                                  color: _accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: AppSpacing.xl),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          // ---- Summary tiles ----
          _SummaryGrid(
            totalDoses: totalDoses,
            daysWithMeds: daysWithMeds,
            uniqueMeds: sortedMeds.length,
            topMed: topMedName,
            lastLogDate: lastLogDate,
            accent: _accent,
          ),

          const SizedBox(height: AppSpacing.lg),

          // ---- Adherence strip ----
          _SectionHeader(
            title: 'Last 30 Days',
            subtitle: 'Days a medication was logged',
            icon: Icons.calendar_today_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AdherenceStrip(
            entries: sortedEntries,
            accent: _accent,
          ),

          const SizedBox(height: AppSpacing.xl),

          // ---- Medication frequency ----
          _SectionHeader(
            title: 'By Medication',
            subtitle: '${sortedMeds.length} unique • $totalDoses doses logged',
            icon: Icons.medication_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          _MedFrequencyList(
            items: sortedMeds,
            doseCounts: medDoseCount,
            accent: _accent,
          ),

          const SizedBox(height: AppSpacing.xl),

          // ---- Recent timeline ----
          _SectionHeader(
            title: 'Recent Log',
            subtitle: 'Last ${recentMedEntries.length} day${recentMedEntries.length == 1 ? '' : 's'} with meds',
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          _RecentTimeline(
            entries: recentMedEntries,
            accent: _accent,
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// =============================================================================
// Summary tiles
// =============================================================================

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.totalDoses,
    required this.daysWithMeds,
    required this.uniqueMeds,
    required this.topMed,
    required this.lastLogDate,
    required this.accent,
  });

  final int totalDoses;
  final int daysWithMeds;
  final int uniqueMeds;
  final String? topMed;
  final DateTime? lastLogDate;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final lastLog = lastLogDate == null ? '—' : _relativeDate(lastLogDate!);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Total Doses',
                value: '$totalDoses',
                sublabel: '30 days',
                icon: Icons.local_pharmacy_rounded,
                color: accent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                label: 'Days Tracked',
                value: '$daysWithMeds',
                sublabel: 'of 30',
                icon: Icons.event_available_rounded,
                color: const Color(0xFF34D399),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Top Med',
                value: topMed ?? '—',
                sublabel: '$uniqueMeds total',
                icon: Icons.star_rounded,
                color: const Color(0xFFFBBF24),
                valueFontSize: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                label: 'Last Log',
                value: lastLog,
                sublabel: lastLogDate != null
                    ? DateFormat('MMM d').format(lastLogDate!)
                    : '',
                icon: Icons.schedule_rounded,
                color: const Color(0xFF60A5FA),
                valueFontSize: 18,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _relativeDate(DateTime d) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '${days}d ago';
    if (days < 30) return '${(days / 7).floor()}w ago';
    return '${(days / 30).floor()}mo ago';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    required this.color,
    this.valueFontSize = 22,
  });

  final String label;
  final String value;
  final String sublabel;
  final IconData icon;
  final Color color;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: context.textStyles.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: valueFontSize,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (sublabel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: context.textStyles.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Adherence strip — 30 day dot row
// =============================================================================

class _AdherenceStrip extends StatelessWidget {
  const _AdherenceStrip({required this.entries, required this.accent});

  final List<TrackerEntry> entries;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final startDay = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 29));

    // Map yyyy-MM-dd -> dose count
    final byDay = <String, int>{};
    for (final e in entries) {
      final key = DateFormat('yyyy-MM-dd').format(e.date);
      final logs = e.medicationLogs;
      final plain = e.medications;
      final c =
          (logs?.length ?? 0) + (logs != null ? 0 : (plain?.length ?? 0));
      if (c > 0) {
        byDay[key] = (byDay[key] ?? 0) + c;
      }
    }

    final maxDose = byDay.values.fold<int>(0, (m, v) => v > m ? v : m);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(builder: (context, c) {
              const gap = 4.0;
              final cellWidth = ((c.maxWidth - gap * 29) / 30).clamp(4.0, 18.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(30, (i) {
                  final day = startDay.add(Duration(days: i));
                  final key = DateFormat('yyyy-MM-dd').format(day);
                  final doses = byDay[key] ?? 0;
                  double intensity = 0;
                  if (doses > 0 && maxDose > 0) {
                    intensity = 0.35 + (doses / maxDose) * 0.65;
                  }
                  final color = doses == 0
                      ? cs.onSurfaceVariant.withValues(alpha: 0.12)
                      : accent.withValues(alpha: intensity);
                  return Container(
                    width: cellWidth,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: doses > 0
                          ? Border.all(
                              color: accent.withValues(alpha: 0.4), width: 0.5)
                          : null,
                    ),
                  );
                }),
              );
            }),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM d').format(startDay),
                  style: context.textStyles.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                Row(
                  children: [
                    Text(
                      'Less',
                      style: context.textStyles.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                    ...List.generate(4, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: i == 0
                                ? cs.onSurfaceVariant.withValues(alpha: 0.12)
                                : accent.withValues(alpha: 0.3 + i * 0.22),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 6),
                    Text(
                      'More',
                      style: context.textStyles.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                Text(
                  'Today',
                  style: context.textStyles.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Frequency list
// =============================================================================

class _MedFrequencyList extends StatelessWidget {
  const _MedFrequencyList({
    required this.items,
    required this.doseCounts,
    required this.accent,
  });

  final List<MapEntry<String, int>> items;
  final Map<String, int> doseCounts;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxDays = items.first.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.08)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.medication_rounded,
                          color: accent, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].key,
                            style: context.textStyles.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: items[i].value / maxDays,
                              minHeight: 6,
                              backgroundColor:
                                  cs.onSurfaceVariant.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${items[i].value}',
                          style: context.textStyles.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          items[i].value == 1 ? 'day' : 'days',
                          style: context.textStyles.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Recent timeline
// =============================================================================

class _RecentTimeline extends StatelessWidget {
  const _RecentTimeline({required this.entries, required this.accent});

  final List<TrackerEntry> entries;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < entries.length; i++) ...[
              _TimelineRow(
                entry: entries[i],
                isFirst: i == 0,
                isLast: i == entries.length - 1,
                accent: accent,
              ),
            ],
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Text(
                    'No medication entries yet',
                    style: context.textStyles.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.accent,
  });

  final TrackerEntry entry;
  final bool isFirst;
  final bool isLast;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final logs = entry.medicationLogs;
    final hasStructured = logs != null && logs.isNotEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date column
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM').format(entry.date).toUpperCase(),
                    style: context.textStyles.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    DateFormat('d').format(entry.date),
                    style: context.textStyles.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    DateFormat('EEE').format(entry.date),
                    style: context.textStyles.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          // Rail
          Column(
            children: [
              Container(
                width: 2,
                height: 8,
                color: isFirst
                    ? Colors.transparent
                    : cs.onSurfaceVariant.withValues(alpha: 0.18),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: accent.withValues(alpha: 0.25), width: 3),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast
                      ? Colors.transparent
                      : cs.onSurfaceVariant.withValues(alpha: 0.18),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : AppSpacing.md),
              child: hasStructured
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final l in logs) ...[
                          _MedLogTile(log: l, accent: accent),
                          if (l != logs.last) const SizedBox(height: 6),
                        ],
                      ],
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: (entry.medications ?? const <String>[])
                          .map((m) => _MedChip(name: m, accent: accent))
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedLogTile extends StatelessWidget {
  const _MedLogTile({required this.log, required this.accent});

  final MedicationLog log;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pieces = <String>[];
    if (log.doseMg != null) pieces.add('${log.doseMg} mg');
    if (log.takenAt != null) {
      try {
        final t = DateTime.parse(log.takenAt!);
        pieces.add(DateFormat.jm().format(t));
      } catch (_) {}
    }
    if (log.isPrn == true) pieces.add('PRN');

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.name,
                  style: context.textStyles.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (pieces.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    pieces.join(' • '),
                    style: context.textStyles.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          if (log.effectScore != null) _EffectBadge(score: log.effectScore!),
        ],
      ),
    );
  }
}

class _EffectBadge extends StatelessWidget {
  const _EffectBadge({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    if (score >= 4) {
      color = const Color(0xFF34D399);
      label = 'Helped';
    } else if (score >= 2) {
      color = const Color(0xFFFBBF24);
      label = 'Some';
    } else {
      color = const Color(0xFFF87171);
      label = 'Little';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: context.textStyles.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MedChip extends StatelessWidget {
  const _MedChip({required this.name, required this.accent});
  final String name;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        name,
        style: context.textStyles.labelMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// =============================================================================
// Section header + empty state
// =============================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle,
                style: context.textStyles.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.medication_outlined,
                      size: 48, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No medications logged',
                  style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Once daily entries include medications,\nthey\'ll appear here.',
                  textAlign: TextAlign.center,
                  style: context.textStyles.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
