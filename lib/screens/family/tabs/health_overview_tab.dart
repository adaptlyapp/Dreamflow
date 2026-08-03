import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/models/recovery_blueprint.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/recovery_blueprint_service.dart';
import 'package:wellspring/theme.dart';
import 'package:fl_chart/fl_chart.dart';

class HealthOverviewTab extends StatefulWidget {
  const HealthOverviewTab({
    super.key,
    required this.patientId,
    required this.entries,
  });

  final String patientId;
  final List<TrackerEntry> entries;

  @override
  State<HealthOverviewTab> createState() => _HealthOverviewTabState();
}

class _HealthOverviewTabState extends State<HealthOverviewTab> {
  final _blueprintService = RecoveryBlueprintService();
  RecoveryBlueprint? _blueprint;
  bool _loadingBlueprint = true;

  @override
  void initState() {
    super.initState();
    _loadBlueprint();
  }

  Future<void> _loadBlueprint() async {
    setState(() => _loadingBlueprint = true);
    final blueprint = await _blueprintService.getByUserId(widget.patientId);
    setState(() {
      _blueprint = blueprint;
      _loadingBlueprint = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final familyService = FamilyService();
    
    // Calculate snapshot metrics from last 7 entries
    final last7 = widget.entries.take(7).toList();
    
    // Calculate trends
    final painTrend = familyService.calculateTrend(last7, 'pain');
    final sleepTrend = familyService.calculateTrend(last7, 'sleep');
    final stepsTrend = familyService.calculateTrend(last7, 'steps');
    final energyTrend = familyService.calculateTrend(last7, 'energy');
    
    // Get most recent non-null values (not just the latest entry)
    double? latestPain;
    double? latestSleep;
    double? latestSteps;
    double? latestEnergy;
    
    for (final entry in widget.entries) {
      if (latestPain == null && entry.painLevel != null) {
        latestPain = entry.painLevel!.toDouble();
      }
      if (latestSleep == null && entry.sleepQuality != null) {
        latestSleep = entry.sleepQuality!.toDouble();
      }
      if (latestSteps == null && entry.steps != null) {
        latestSteps = entry.steps!.toDouble();
      }
      if (latestEnergy == null && entry.energyLevel != null) {
        latestEnergy = entry.energyLevel!.toDouble();
      }
      
      // Break early if all values are found
      if (latestPain != null && latestSleep != null && latestSteps != null && latestEnergy != null) {
        break;
      }
    }
    
    // Chart data (last 14 days, chronological)
    final chartData = familyService.getChartData(widget.entries, limit: 14);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick access bar
          const _QuickAccessBar(),
          const SizedBox(height: AppSpacing.lg),
          // 4 Snapshot cards
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Pain',
                  value: latestPain != null ? '${latestPain.toInt()}/10' : '—',
                  trend: painTrend,
                  color: Colors.red,
                  icon: Icons.favorite,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MetricCard(
                  label: 'Sleep',
                  value: latestSleep != null ? '${latestSleep.toInt()}h' : '—',
                  trend: sleepTrend,
                  color: Colors.indigo,
                  icon: Icons.bedtime,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Steps',
                  value: latestSteps != null ? latestSteps.toInt().toString() : '—',
                  trend: stepsTrend,
                  color: Colors.green,
                  icon: Icons.directions_walk,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MetricCard(
                  label: 'Energy',
                  value: latestEnergy != null ? '${latestEnergy.toInt()}/10' : '—',
                  trend: energyTrend,
                  color: Colors.amber,
                  icon: Icons.bolt,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Daily Steps Bar Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Steps — 14 Days',
                    style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 150,
                    child: chartData.isNotEmpty
                        ? BarChart(
                            BarChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        '${(value / 1000).toInt()}k',
                                        style: context.textStyles.bodySmall,
                                      );
                                    },
                                  ),
                                ),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: chartData
                                  .asMap()
                                  .entries
                                  .where((e) => e.value['steps'] != null)
                                  .map((e) => BarChartGroupData(
                                        x: e.key,
                                        barRods: [
                                          BarChartRodData(
                                            toY: e.value['steps'],
                                            color: Colors.green,
                                            width: 12,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ],
                                      ))
                                  .toList(),
                            ),
                          )
                        : Center(child: Text('No data', style: context.textStyles.bodyMedium)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Average: ${chartData.where((d) => d['steps'] != null).isNotEmpty ? (chartData.where((d) => d['steps'] != null).fold<double>(0, (sum, d) => sum + d['steps']) / chartData.where((d) => d['steps'] != null).length).round() : 0} steps/day',
                    style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String trend;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    Color trendColor;
    IconData trendIcon;
    Color cardBgColor;
    
    if (trend == 'Improving') {
      trendColor = const Color(0xFF66BB6A);
      trendIcon = Icons.trending_up;
      cardBgColor = const Color(0xFF1F3D1F);
    } else if (trend == 'Worsening') {
      trendColor = const Color(0xFFFF6B6B);
      trendIcon = Icons.trending_down;
      cardBgColor = const Color(0xFF3D1F1F);
    } else {
      trendColor = cs.onSurfaceVariant;
      trendIcon = Icons.trending_flat;
      cardBgColor = const Color(0xFF1E2530);
    }
    
    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
              Text(
                label,
                style: context.textStyles.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: context.textStyles.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(trendIcon, size: 14, color: trendColor),
              const SizedBox(width: 4),
              Text(
                trend,
                style: context.textStyles.labelSmall?.copyWith(
                  color: trendColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAccessBar extends StatelessWidget {
  const _QuickAccessBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = <_QuickAccessItem>[
      _QuickAccessItem(
        label: 'Blueprint',
        icon: Icons.map_outlined,
        color: cs.primary,
        onTap: () => context.push('/family/recovery-blueprint/wizard'),
      ),
      _QuickAccessItem(
        label: 'Schedule',
        icon: Icons.event_note_outlined,
        color: Colors.teal,
        onTap: () => context.push('/family/recovery-blueprint/schedule'),
      ),
      _QuickAccessItem(
        label: 'Alerts',
        icon: Icons.notifications_outlined,
        color: Colors.orange,
        onTap: () => context.go('/family/alerts'),
      ),
      _QuickAccessItem(
        label: 'Journey',
        icon: Icons.timeline,
        color: Colors.purple,
        onTap: () => context.go('/family/journey'),
      ),
      _QuickAccessItem(
        label: 'Resources',
        icon: Icons.folder_outlined,
        color: Colors.indigo,
        onTap: () => context.go('/family/resources'),
      ),
      _QuickAccessItem(
        label: 'Education',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () => context.push('/family/education'),
      ),
    ];

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) => _QuickAccessButton(item: items[i]),
      ),
    );
  }
}

class _QuickAccessItem {
  _QuickAccessItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _QuickAccessButton extends StatelessWidget {
  const _QuickAccessButton({required this.item});

  final _QuickAccessItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, size: 20, color: item.color),
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
              style: context.textStyles.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
