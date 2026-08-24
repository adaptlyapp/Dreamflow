import 'package:flutter/material.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/theme.dart';
import 'package:fl_chart/fl_chart.dart';

class HealthVitalsTab extends StatelessWidget {
  const HealthVitalsTab({
    super.key,
    required this.entries,
    required this.patientId,
  });

  final List<TrackerEntry> entries;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final familyService = FamilyService();
    
    // Latest entry vitals
    final latest = entries.isNotEmpty ? entries.first : null;
    final latestHR = latest?.heartRate?.toDouble();
    final latestSystolic = latest?.systolicBP?.toDouble();
    final latestDiastolic = latest?.diastolicBP?.toDouble();
    final latestTemp = latest?.temperature;
    final latestWeight = latest?.weight;
    final latestBladder = latest?.bladderSuccess;
    final latestSpasms = latest?.spasmFrequency;
    
    // Get contextual labels
    final hrContext = familyService.getVitalContext(latestHR, 'heartRate');
    final tempContext = familyService.getVitalContext(latestTemp, 'temperature');
    
    // BP chart data
    final bpEntries = entries.where((e) => e.systolicBP != null && e.diastolicBP != null).take(30).toList();
    final avgSystolic = bpEntries.isNotEmpty 
        ? bpEntries.fold<int>(0, (sum, e) => sum + e.systolicBP!) / bpEntries.length 
        : 0;
    final avgDiastolic = bpEntries.isNotEmpty 
        ? bpEntries.fold<int>(0, (sum, e) => sum + e.diastolicBP!) / bpEntries.length 
        : 0;
    
    String bpLabel = 'Normal';
    if (avgSystolic >= 140 || avgDiastolic >= 90) {
      bpLabel = 'Elevated';
    } else if (avgSystolic >= 130 || avgDiastolic >= 85) {
      bpLabel = 'Slightly elevated';
    }
    
    // Heart rate data
    final hrEntries = entries.where((e) => e.heartRate != null).take(30).toList();
    final avgHR = hrEntries.isNotEmpty 
        ? hrEntries.fold<int>(0, (sum, e) => sum + e.heartRate!) / hrEntries.length 
        : 0;
    
    String hrLabel = 'Normal';
    if (avgHR > 100) {
      hrLabel = 'Tachycardia';
    } else if (avgHR < 60) {
      hrLabel = 'Bradycardia';
    }
    
    // Weight data
    final weightEntries = entries.where((e) => e.weight != null).take(30).toList();
    String weightTrend = 'stable';
    if (weightEntries.length >= 2) {
      final recent = weightEntries.first.weight!;
      final old = weightEntries.last.weight!;
      if (recent > old + 1) weightTrend = 'gained';
      if (recent < old - 1) weightTrend = 'lost';
    }
    
    // Activities frequency
    final activityCounts = <String, int>{};
    for (final entry in entries) {
      if (entry.activities != null) {
        for (final activity in entry.activities!) {
          activityCounts[activity] = (activityCounts[activity] ?? 0) + 1;
        }
      }
    }
    final sortedActivities = activityCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 6-card grid
          Row(
            children: [
              Expanded(
                child: _VitalCard(
                  label: 'Heart Rate',
                  value: latestHR != null ? '${latestHR.toInt()} bpm' : '—',
                  status: hrContext['label']!,
                  icon: Icons.favorite,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _VitalCard(
                  label: 'Blood Pressure',
                  value: latestSystolic != null && latestDiastolic != null 
                      ? '${latestSystolic.toInt()}/${latestDiastolic.toInt()}' 
                      : '—',
                  status: '',
                  icon: Icons.monitor_heart,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _VitalCard(
                  label: 'Temperature',
                  value: latestTemp != null ? '${latestTemp.toStringAsFixed(1)}°F' : '—',
                  status: tempContext['label']!,
                  icon: Icons.thermostat,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _VitalCard(
                  label: 'Weight',
                  value: latestWeight != null ? '${latestWeight.toStringAsFixed(1)} kg' : '—',
                  status: '',
                  icon: Icons.monitor_weight,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _VitalCard(
                  label: 'Bladder',
                  value: latestBladder != null ? (latestBladder ? 'Success' : 'Issue') : '—',
                  status: '',
                  icon: Icons.water_drop,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _VitalCard(
                  label: 'Spasms',
                  value: latestSpasms != null ? latestSpasms.toString() : '—',
                  status: 'frequency',
                  icon: Icons.air,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          
          // Blood Pressure Chart
          if (bpEntries.length >= 3) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Blood Pressure — 30 Days',
                      style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Average: ${avgSystolic.round()}/${avgDiastolic.round()} mmHg — $bpLabel',
                      style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
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
                              spots: bpEntries
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value.systolicBP!.toDouble()))
                                  .toList(),
                              isCurved: true,
                              color: Colors.purple,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                            ),
                            LineChartBarData(
                              spots: bpEntries
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value.diastolicBP!.toDouble()))
                                  .toList(),
                              isCurved: true,
                              color: Colors.purple.shade300,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                            ),
                          ],
                          minY: 40,
                          maxY: 180,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          // Heart Rate Chart
          if (hrEntries.length >= 3) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Heart Rate — 30 Days',
                      style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Average: ${avgHR.round()} bpm — $hrLabel',
                      style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      height: 150,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
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
                              spots: hrEntries
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value.heartRate!.toDouble()))
                                  .toList(),
                              isCurved: true,
                              color: Colors.red,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.red.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                          minY: 40,
                          maxY: 140,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          // Weight Chart
          if (weightEntries.length >= 3) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight — 30 Days',
                      style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Trend: ${weightTrend.toUpperCase()}',
                      style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      height: 150,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text('${value.toInt()}kg', style: context.textStyles.bodySmall);
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
                              spots: weightEntries
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value.weight!))
                                  .toList(),
                              isCurved: true,
                              color: Colors.blue,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          // Activities Bar Chart
          if (sortedActivities.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activities Logged — 30 Days',
                      style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ...sortedActivities.take(8).map((entry) {
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
                              color: Colors.green,
                            ),
                          ],
                        ),
                      );
                    }),
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

class _VitalCard extends StatelessWidget {
  const _VitalCard({
    required this.label,
    required this.value,
    required this.status,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String status;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: context.textStyles.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (status.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                status,
                style: context.textStyles.labelSmall?.copyWith(color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
