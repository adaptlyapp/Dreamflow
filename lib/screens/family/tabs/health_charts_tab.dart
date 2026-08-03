import 'package:flutter/material.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/theme.dart';
import 'package:fl_chart/fl_chart.dart';

class HealthChartsTab extends StatelessWidget {
  const HealthChartsTab({super.key, required this.entries});

  final List<TrackerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final familyService = FamilyService();
    
    // Calculate averages
    final painEntries = entries.where((e) => e.painLevel != null).toList();
    final sleepEntries = entries.where((e) => e.sleepQuality != null).toList();
    final stepsEntries = entries.where((e) => e.steps != null).toList();
    final energyEntries = entries.where((e) => e.energyLevel != null).toList();
    
    final avgPain = painEntries.isNotEmpty 
        ? painEntries.fold<double>(0, (sum, e) => sum + e.painLevel!) / painEntries.length 
        : 0.0;
    final avgSleep = sleepEntries.isNotEmpty 
        ? sleepEntries.fold<double>(0, (sum, e) => sum + e.sleepQuality!) / sleepEntries.length 
        : 0.0;
    final avgSteps = stepsEntries.isNotEmpty 
        ? stepsEntries.fold<int>(0, (sum, e) => sum + e.steps!) / stepsEntries.length 
        : 0.0;
    final avgEnergy = energyEntries.isNotEmpty 
        ? energyEntries.fold<double>(0, (sum, e) => sum + e.energyLevel!) / energyEntries.length 
        : 0.0;
    
    final painTrend = familyService.calculateTrend(painEntries, 'pain');
    final sleepTrend = familyService.calculateTrend(sleepEntries, 'sleep');
    final energyTrend = familyService.calculateTrend(energyEntries, 'energy');
    
    // Mood distribution
    final moodCounts = <String, int>{};
    for (final entry in entries) {
      if (entry.mood != null) {
        final mood = entry.mood!.toLowerCase();
        moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
      }
    }
    
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insert_chart_outlined, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No health data yet',
                style: context.textStyles.titleMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Charts will appear once the patient logs health entries',
                style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary stat cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Avg Pain',
                  value: avgPain.toStringAsFixed(1),
                  trend: painTrend,
                  color: cs.error,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  label: 'Avg Sleep',
                  value: '${avgSleep.toStringAsFixed(1)}h',
                  trend: sleepTrend,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Avg Steps',
                  value: avgSteps.round().toString(),
                  trend: '',
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  label: 'Avg Energy',
                  value: avgEnergy.toStringAsFixed(1),
                  trend: energyTrend,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // All Metrics Composite Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health Trends',
                    style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Last ${entries.length} entries',
                    style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 2,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: cs.outline.withValues(alpha: 0.1),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: 2,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    value.toInt().toString(),
                                    style: context.textStyles.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          // Pain (area)
                          if (painEntries.isNotEmpty)
                            LineChartBarData(
                              spots: painEntries
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value.painLevel!.toDouble()))
                                  .toList(),
                              isCurved: true,
                              color: cs.error,
                              barWidth: 2.5,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: cs.error.withValues(alpha: 0.1),
                              ),
                            ),
                          // Sleep (line)
                          if (sleepEntries.isNotEmpty)
                            LineChartBarData(
                              spots: sleepEntries
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value.sleepQuality!.toDouble()))
                                  .toList(),
                              isCurved: true,
                              color: const Color(0xFF6366F1),
                              barWidth: 2.5,
                              dotData: const FlDotData(show: false),
                            ),
                          // Energy (dashed)
                          if (energyEntries.isNotEmpty)
                            LineChartBarData(
                              spots: energyEntries
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value.energyLevel!.toDouble()))
                                  .toList(),
                              isCurved: true,
                              color: const Color(0xFFF59E0B),
                              barWidth: 2.5,
                              dotData: const FlDotData(show: false),
                              dashArray: [6, 4],
                            ),
                        ],
                        minY: 0,
                        maxY: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Legend
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (painEntries.isNotEmpty)
                        _ChartLegend(label: 'Pain', color: cs.error),
                      if (sleepEntries.isNotEmpty)
                        _ChartLegend(label: 'Sleep', color: const Color(0xFF6366F1)),
                      if (energyEntries.isNotEmpty)
                        _ChartLegend(label: 'Energy', color: const Color(0xFFF59E0B), isDashed: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Mood Distribution Donut
          if (moodCounts.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mood Distribution',
                      style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 180,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: PieChart(
                              PieChartData(
                                sections: moodCounts.entries.map((entry) {
                                  final color = _getMoodColor(entry.key);
                                  return PieChartSectionData(
                                    value: entry.value.toDouble(),
                                    title: '${entry.value}',
                                    color: color,
                                    radius: 60,
                                    titleStyle: context.textStyles.labelMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                }).toList(),
                                centerSpaceRadius: 35,
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            flex: 1,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: moodCounts.entries.map((entry) {
                                final color = _getMoodColor(entry.key);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: context.textStyles.labelSmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

Color _getMoodColor(String mood) {
  final moodLower = mood.toLowerCase();
  if (moodLower.contains('great')) {
    return const Color(0xFF10B981);
  } else if (moodLower.contains('good')) {
    return const Color(0xFF14B8A6);
  } else if (moodLower.contains('okay')) {
    return const Color(0xFFF59E0B);
  } else if (moodLower.contains('low')) {
    return const Color(0xFFEF4444);
  } else {
    return const Color(0xFF991B1B);
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
    required this.label,
    required this.color,
    this.isDashed = false,
  });

  final String label;
  final Color color;
  final bool isDashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isDashed ? 16 : 12,
          height: 2.5,
          decoration: BoxDecoration(
            color: isDashed ? null : color,
            border: isDashed ? Border.all(color: color, width: 2) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.textStyles.labelSmall,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.color,
  });

  final String label;
  final String value;
  final String trend;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: context.textStyles.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: context.textStyles.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (trend.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    trend == 'Improving' ? Icons.trending_up : 
                    trend == 'Worsening' ? Icons.trending_down : Icons.trending_flat,
                    size: 12,
                    color: trend == 'Improving' ? const Color(0xFF10B981) : 
                           trend == 'Worsening' ? const Color(0xFFEF4444) : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trend,
                    style: context.textStyles.labelSmall?.copyWith(
                      color: trend == 'Improving' ? const Color(0xFF10B981) : 
                             trend == 'Worsening' ? const Color(0xFFEF4444) : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
