import 'package:flutter/material.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/theme.dart';
import 'package:intl/intl.dart';

class HealthDailyLogTab extends StatelessWidget {
  const HealthDailyLogTab({super.key, required this.entries});

  final List<TrackerEntry> entries;

  String _getMoodEmoji(String? mood) {
    if (mood == null) return '—';
    final lower = mood.toLowerCase();
    if (lower.contains('great')) return '😄';
    if (lower.contains('good')) return '🙂';
    if (lower.contains('okay')) return '😐';
    if (lower.contains('low')) return '😕';
    if (lower.contains('bad')) return '😞';
    return mood;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Full Chronological Log',
            style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${entries.length} entries over the last 30 days',
            style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Entries list
          ...entries.asMap().entries.map((mapEntry) {
            final entry = mapEntry.value;
            return _DailyLogCard(entry: entry);
          }),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _DailyLogCard extends StatefulWidget {
  const _DailyLogCard({required this.entry});

  final TrackerEntry entry;

  @override
  State<_DailyLogCard> createState() => _DailyLogCardState();
}

class _DailyLogCardState extends State<_DailyLogCard> {
  bool _expanded = false;

  String _getMoodEmoji(String? mood) {
    if (mood == null) return '—';
    final lower = mood.toLowerCase();
    if (lower.contains('great')) return '😄';
    if (lower.contains('good')) return '🙂';
    if (lower.contains('okay')) return '😐';
    if (lower.contains('low')) return '😕';
    if (lower.contains('bad')) return '😞';
    return mood;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entry = widget.entry;
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat.yMMMd().format(entry.date),
                        style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Icon(
                        _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: cs.onSurface,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  
                  // Quick metrics
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (entry.painLevel != null)
                        _MetricTile(
                          label: 'Pain',
                          value: '${entry.painLevel}/10',
                          color: Colors.red,
                        ),
                      if (entry.sleepQuality != null)
                        _MetricTile(
                          label: 'Sleep',
                          value: '${entry.sleepQuality}h',
                          color: Colors.indigo,
                        ),
                      if (entry.energyLevel != null)
                        _MetricTile(
                          label: 'Energy',
                          value: '${entry.energyLevel}/10',
                          color: Colors.amber,
                        ),
                      if (entry.steps != null)
                        _MetricTile(
                          label: 'Steps',
                          value: entry.steps.toString(),
                          color: Colors.green,
                        ),
                      if (entry.heartRate != null)
                        _MetricTile(
                          label: 'HR',
                          value: '${entry.heartRate} bpm',
                          color: Colors.pink,
                        ),
                      if (entry.systolicBP != null && entry.diastolicBP != null)
                        _MetricTile(
                          label: 'BP',
                          value: '${entry.systolicBP}/${entry.diastolicBP}',
                          color: Colors.purple,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  
                  // Mood badge
                  if (entry.mood != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        'Mood: ${_getMoodEmoji(entry.mood)} ${entry.mood}',
                        style: context.textStyles.labelSmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Expanded details
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pain Details Section
                  if (entry.painLevel != null || (entry.painMap != null && entry.painMap!.isNotEmpty)) ...[
                    _SectionHeader(title: 'Pain Details', icon: Icons.favorite_border, color: Colors.red),
                    const SizedBox(height: AppSpacing.sm),
                    if (entry.painLevel != null)
                      _InfoRow(label: 'Overall Pain Level', value: '${entry.painLevel}/10'),
                    if (entry.painMap != null && entry.painMap!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text('Pain Mapping:', style: context.textStyles.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ...entry.painMap!.map((pain) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${pain.area}: ${pain.type} (${pain.intensity}/10)${pain.note != null && pain.note!.isNotEmpty ? " - ${pain.note}" : ""}',
                          style: context.textStyles.bodySmall,
                        ),
                      )),
                    ],
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Vitals Section
                  if (entry.systolicBP != null || entry.diastolicBP != null || entry.heartRate != null || 
                      entry.weight != null || entry.temperature != null) ...[
                    _SectionHeader(title: 'Vital Signs', icon: Icons.monitor_heart_outlined, color: Colors.purple),
                    const SizedBox(height: AppSpacing.sm),
                    if (entry.systolicBP != null && entry.diastolicBP != null)
                      _InfoRow(label: 'Blood Pressure', value: '${entry.systolicBP}/${entry.diastolicBP} mmHg'),
                    if (entry.heartRate != null)
                      _InfoRow(label: 'Heart Rate', value: '${entry.heartRate} bpm'),
                    if (entry.weight != null)
                      _InfoRow(label: 'Weight', value: '${entry.weight} Lb'),
                    if (entry.temperature != null)
                      _InfoRow(label: 'Temperature', value: '${entry.temperature}°C'),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // SCI-Specific Metrics
                  if (entry.spasmFrequency != null || entry.bladderSuccess != null || entry.bowelProgram != null) ...[
                    _SectionHeader(title: 'SCI Metrics', icon: Icons.accessibility_new, color: Colors.blue),
                    const SizedBox(height: AppSpacing.sm),
                    if (entry.spasmFrequency != null)
                      _InfoRow(label: 'Spasm Frequency', value: '${entry.spasmFrequency} per day'),
                    if (entry.bladderSuccess != null)
                      _InfoRow(label: 'Bladder Success', value: entry.bladderSuccess! ? '✓ Yes' : '✗ No'),
                    if (entry.bowelProgram != null)
                      _InfoRow(label: 'Bowel Program', value: entry.bowelProgram! ? '✓ Completed' : '✗ Not completed'),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Medications with structured details
                  if ((entry.medications != null && entry.medications!.isNotEmpty) || 
                      (entry.medicationLogs != null && entry.medicationLogs!.isNotEmpty)) ...[
                    _SectionHeader(title: 'Medications', icon: Icons.medication_outlined, color: Colors.teal),
                    const SizedBox(height: AppSpacing.sm),
                    if (entry.medicationLogs != null && entry.medicationLogs!.isNotEmpty)
                      ...entry.medicationLogs!.map((med) => _MedicationLogItem(log: med))
                    else if (entry.medications != null && entry.medications!.isNotEmpty)
                      _DetailSection(
                        title: '',
                        icon: Icons.medication,
                        color: Colors.teal,
                        items: entry.medications!,
                      ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  
                  // Symptoms with structured details
                  if ((entry.symptoms != null && entry.symptoms!.isNotEmpty) ||
                      (entry.symptomLogs != null && entry.symptomLogs!.isNotEmpty)) ...[
                    _SectionHeader(title: 'Symptoms', icon: Icons.sick_outlined, color: Colors.orange),
                    const SizedBox(height: AppSpacing.sm),
                    if (entry.symptomLogs != null && entry.symptomLogs!.isNotEmpty)
                      ...entry.symptomLogs!.map((symptom) => _SymptomLogItem(log: symptom))
                    else if (entry.symptoms != null && entry.symptoms!.isNotEmpty)
                      _DetailSection(
                        title: '',
                        icon: Icons.sick,
                        color: Colors.orange,
                        items: entry.symptoms!,
                      ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  
                  // Triggers with structured details
                  if ((entry.triggers != null && entry.triggers!.isNotEmpty) ||
                      (entry.triggerLogs != null && entry.triggerLogs!.isNotEmpty)) ...[
                    _SectionHeader(title: 'Triggers', icon: Icons.warning_amber_outlined, color: Colors.deepOrange),
                    const SizedBox(height: AppSpacing.sm),
                    if (entry.triggerLogs != null && entry.triggerLogs!.isNotEmpty)
                      ...entry.triggerLogs!.map((trigger) => _TriggerLogItem(log: trigger))
                    else if (entry.triggers != null && entry.triggers!.isNotEmpty)
                      _DetailSection(
                        title: '',
                        icon: Icons.warning,
                        color: Colors.deepOrange,
                        items: entry.triggers!,
                      ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  
                  // Activities with structured details
                  if ((entry.activities != null && entry.activities!.isNotEmpty) ||
                      (entry.activityLogs != null && entry.activityLogs!.isNotEmpty)) ...[
                    _SectionHeader(title: 'Activities', icon: Icons.directions_run_outlined, color: Colors.blue),
                    const SizedBox(height: AppSpacing.sm),
                    if (entry.activityLogs != null && entry.activityLogs!.isNotEmpty)
                      ...entry.activityLogs!.map((activity) => _ActivityLogItem(log: activity))
                    else if (entry.activities != null && entry.activities!.isNotEmpty)
                      _DetailSection(
                        title: '',
                        icon: Icons.directions_run,
                        color: Colors.blue,
                        items: entry.activities!,
                      ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Nutrition data from customFields
                  if (entry.customFields?['nutritionV1'] != null) ...[
                    _SectionHeader(title: 'Nutrition', icon: Icons.restaurant_outlined, color: Colors.green),
                    const SizedBox(height: AppSpacing.sm),
                    _NutritionDetails(nutritionData: entry.customFields!['nutritionV1']),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  
                  // Notes
                  if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                    _SectionHeader(title: 'Notes', icon: Icons.notes_outlined, color: cs.primary),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      entry.notes!,
                      style: context.textStyles.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textStyles.labelSmall?.copyWith(
              color: color,
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: context.textStyles.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: context.textStyles.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        if (title.isNotEmpty) const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items.map((item) {
            return Chip(
              label: Text(item),
              backgroundColor: color.withValues(alpha: 0.1),
              side: BorderSide(color: color.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              labelStyle: context.textStyles.labelSmall,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: context.textStyles.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: context.textStyles.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: context.textStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MedicationLogItem extends StatelessWidget {
  const _MedicationLogItem({required this.log});

  final MedicationLog log;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final details = <String>[];
    
    if (log.doseMg != null) details.add('${log.doseMg}mg');
    if (log.takenAt != null) {
      final dt = DateTime.tryParse(log.takenAt!);
      if (dt != null) {
        details.add(DateFormat('h:mm a').format(dt));
      }
    }
    if (log.isPrn != null) details.add(log.isPrn! ? 'PRN' : 'Scheduled');
    if (log.effectScore != null) details.add('Effect: ${log.effectScore}/5');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            log.name,
            style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              details.join(' • '),
              style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _SymptomLogItem extends StatelessWidget {
  const _SymptomLogItem({required this.log});

  final SymptomLog log;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final details = <String>[];
    
    if (log.intensity != null) details.add('Intensity: ${log.intensity}/10');
    if (log.durationMin != null) details.add('${log.durationMin} min');
    if (log.bodyArea != null && log.bodyArea!.trim().isNotEmpty) details.add(log.bodyArea!);
    if (log.onsetAt != null) {
      final dt = DateTime.tryParse(log.onsetAt!);
      if (dt != null) {
        details.add('Started: ${DateFormat('h:mm a').format(dt)}');
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            log.name,
            style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              details.join(' • '),
              style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _TriggerLogItem extends StatelessWidget {
  const _TriggerLogItem({required this.log});

  final TriggerLog log;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final details = <String>[];
    
    if (log.temperatureF != null) details.add('${log.temperatureF}°F');
    if (log.durationMin != null) details.add('${log.durationMin} min');
    if (log.jacket == true) details.add('Jacket');
    if (log.gloves == true) details.add('Gloves');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            log.name,
            style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              details.join(' • '),
              style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityLogItem extends StatelessWidget {
  const _ActivityLogItem({required this.log});

  final ActivityLog log;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final details = <String>[];
    
    if (log.purpose != null && log.purpose!.trim().isNotEmpty) details.add(log.purpose!);
    if (log.distanceMi != null) details.add('${log.distanceMi} mi');
    if (log.assist != null && log.assist!.trim().isNotEmpty) details.add(log.assist!);
    if (log.fatigueAfter != null) details.add('Fatigue: ${log.fatigueAfter}/5');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            log.name,
            style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              details.join(' • '),
              style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _NutritionDetails extends StatelessWidget {
  const _NutritionDetails({required this.nutritionData});

  final Map<String, dynamic> nutritionData;

  @override
  Widget build(BuildContext context) {
    final calories = nutritionData['calories'];
    final protein = nutritionData['protein'];
    final carbs = nutritionData['carbs'];
    final fat = nutritionData['fat'];
    final water = nutritionData['water'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (calories != null) _InfoRow(label: 'Calories', value: '$calories kcal'),
        if (protein != null) _InfoRow(label: 'Protein', value: '$protein g'),
        if (carbs != null) _InfoRow(label: 'Carbs', value: '$carbs g'),
        if (fat != null) _InfoRow(label: 'Fat', value: '$fat g'),
        if (water != null) _InfoRow(label: 'Water', value: '$water ml'),
      ],
    );
  }
}
