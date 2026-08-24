import 'package:flutter/material.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/theme.dart';
import 'package:fl_chart/fl_chart.dart';

class HealthPainTab extends StatelessWidget {
  const HealthPainTab({super.key, required this.entries});

  final List<TrackerEntry> entries;

  String _getPainLabel(double pain) {
    if (pain == 0) return 'None';
    if (pain <= 3) return 'Minimal';
    if (pain <= 5) return 'Mild';
    if (pain <= 7) return 'Moderate';
    if (pain <= 9) return 'Severe';
    return 'Extreme';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    final painEntries = entries.where((e) => e.painLevel != null).toList();
    final last7Pain = painEntries.take(7).toList();
    
    final latestPain = painEntries.isNotEmpty ? painEntries.first.painLevel!.toDouble() : 0.0;
    final avg7Pain = last7Pain.isNotEmpty 
        ? last7Pain.fold<double>(0, (sum, e) => sum + e.painLevel!) / last7Pain.length 
        : 0.0;
    final avg30Pain = painEntries.isNotEmpty 
        ? painEntries.fold<double>(0, (sum, e) => sum + e.painLevel!) / painEntries.length 
        : 0.0;
    final highPainDays = last7Pain.where((e) => e.painLevel! >= 7).length;
    
    // Collect symptoms frequency
    final symptomCounts = <String, int>{};
    for (final entry in entries) {
      if (entry.symptoms != null) {
        for (final symptom in entry.symptoms!) {
          symptomCounts[symptom] = (symptomCounts[symptom] ?? 0) + 1;
        }
      }
    }
    final sortedSymptoms = symptomCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Collect triggers frequency
    final triggerCounts = <String, int>{};
    for (final entry in entries) {
      if (entry.triggers != null) {
        for (final trigger in entry.triggers!) {
          triggerCounts[trigger] = (triggerCounts[trigger] ?? 0) + 1;
        }
      }
    }
    final sortedTriggers = triggerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // High vs mild days
    final highDays = painEntries.where((e) => e.painLevel! >= 7).length;
    final mildDays = painEntries.where((e) => e.painLevel! < 4).length;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 stat cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Latest',
                  value: latestPain.toInt().toString(),
                  subtitle: _getPainLabel(latestPain),
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatCard(
                  label: '7-day Avg',
                  value: avg7Pain.toStringAsFixed(1),
                  subtitle: '',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: '30-day Avg',
                  value: avg30Pain.toStringAsFixed(1),
                  subtitle: '',
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatCard(
                  label: 'High Days (7d)',
                  value: highPainDays.toString(),
                  subtitle: 'pain ≥7',
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          
          // Pain Level Area Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pain Level — 30 Days',
                    style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$highDays high pain days (≥7) • $mildDays mild days (<4)',
                    style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 200,
                    child: painEntries.isNotEmpty
                        ? LineChart(
                            LineChartData(
                              gridData: FlGridData(show: true, drawVerticalLine: false),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    getTitlesWidget: (value, meta) {
                                      return Text(value.toInt().toString(), style: context.textStyles.bodySmall);
                                    },
                                  ),
                                ),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: painEntries
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(e.key.toDouble(), e.value.painLevel!.toDouble()))
                                      .toList(),
                                  isCurved: true,
                                  color: Colors.red.shade400,
                                  barWidth: 3,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (spot, percent, barData, index) {
                                      return FlDotCirclePainter(
                                        radius: spot.y >= 7 ? 5 : 3,
                                        color: spot.y >= 7 ? Colors.red : Colors.red.shade300,
                                      );
                                    },
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.red.withValues(alpha: 0.15),
                                  ),
                                ),
                              ],
                              minY: 0,
                              maxY: 10,
                            ),
                          )
                        : Center(child: Text('No pain data', style: context.textStyles.bodyMedium)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Reported Symptoms (horizontal bar chart)
          if (sortedSymptoms.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reported Symptoms',
                      style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...sortedSymptoms.take(8).map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(entry.key, style: context.textStyles.bodyMedium)),
                                Text('${entry.value} days', style: context.textStyles.labelSmall),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: entry.value / entries.length,
                              backgroundColor: cs.surfaceContainerHighest,
                              color: Colors.red.shade300,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          // Pain Triggers (badge cloud)
          if (sortedTriggers.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pain Triggers',
                      style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: sortedTriggers.take(10).map((entry) {
                        return Chip(
                          label: Text('${entry.key} ×${entry.value}'),
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          side: BorderSide(color: Colors.red.shade300),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 120,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: context.textStyles.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: context.textStyles.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: context.textStyles.labelSmall?.copyWith(color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
