import 'package:flutter/material.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/utils/tracker_analytics.dart';
import 'package:wellspring/theme.dart';

class HealthIntelligenceTab extends StatelessWidget {
  const HealthIntelligenceTab({
    super.key,
    required this.patientId,
    required this.entries,
  });

  final String patientId;
  final List<TrackerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // Generate auto-insights
    final autoInsights = TrackerAnalytics.generateAutoInsights(entries);
    
    // Calculate mobility index
    final mobilityIndex = TrackerAnalytics.calculateMobilityIndex(entries);
    
    // Pattern correlations
    final correlations = _calculateCorrelations();
    
    // Medication analysis
    final medications = _extractUniqueMedications();
    
    // Trigger risks
    final triggers = _extractUniqueTriggers();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Intelligence & Analytics',
            style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'AI-powered insights from ${entries.length} entries',
            style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),
          
          // Mobility & Functional Recovery Index
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.insights, color: cs.primary, size: 24),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Functional Recovery Index',
                        style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: (mobilityIndex['score'] as int) / 100,
                                strokeWidth: 12,
                                backgroundColor: cs.surfaceContainerHighest,
                                color: _getScoreColor(mobilityIndex['score'] as int),
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  '${mobilityIndex['score']}',
                                  style: context.textStyles.displaySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getScoreColor(mobilityIndex['score'] as int),
                                  ),
                                ),
                                Text(
                                  '/ 100',
                                  style: context.textStyles.labelLarge?.withColor(cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Chip(
                          label: Text(
                            mobilityIndex['trend'] == 'improving' ? '↑ Improving' :
                            mobilityIndex['trend'] == 'declining' ? '↓ Declining' : '— Stable',
                          ),
                          backgroundColor: mobilityIndex['trend'] == 'improving' ? Colors.green.withValues(alpha: 0.2) :
                                           mobilityIndex['trend'] == 'declining' ? Colors.red.withValues(alpha: 0.2) : cs.surfaceContainerHighest,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Component Breakdown', style: context.textStyles.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  ..._buildComponentBars(mobilityIndex['components'] as Map<String, dynamic>, cs),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Pattern Intelligence
          if (correlations.isNotEmpty) ...[
            Text(
              'Pattern Intelligence',
              style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...correlations.map((corr) => _CorrelationCard(
              metric1: corr['metric1'] as String,
              metric2: corr['metric2'] as String,
              correlation: corr['r'] as double,
              riskScore: corr['riskScore'] as int,
              insight: corr['insight'] as String,
            )),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          // Medication Adherence
          if (medications.isNotEmpty) ...[
            Text(
              'Medication Adherence',
              style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...medications.take(5).map((med) {
              final analysis = TrackerAnalytics.analyzeMedicationAdherence(entries, med);
              return _MedicationCard(
                name: med,
                adherence: analysis['adherence'] as int,
                avgPainOn: analysis['avgPainOn'] as double,
                avgPainOff: analysis['avgPainOff'] as double,
                effectiveness: analysis['effectiveness'] as String,
              );
            }),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          // Environmental Risk
          if (triggers.isNotEmpty) ...[
            Text(
              'Environmental Risk Modeling',
              style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...triggers.take(5).map((trigger) {
              final analysis = TrackerAnalytics.analyzeTriggerRisk(entries, trigger);
              return _TriggerRiskCard(
                trigger: trigger,
                frequency: analysis['frequency'] as int,
                avgNextDayPain: analysis['avgNextDayPain'] as double,
                riskScore: analysis['riskScore'] as int,
              );
            }),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          // Auto-Generated Insights
          if (autoInsights.isNotEmpty) ...[
            Text(
              'Auto-Generated Insights',
              style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...autoInsights.map((insight) {
              final severity = insight['severity'] as String;
              final iconColor = severity == 'critical' ? Colors.red.shade300 :
                                severity == 'warning' ? Colors.orange.shade300 :
                                severity == 'success' ? Colors.green.shade300 :
                                cs.primary;
              return Card(
                color: _getSeverityColor(severity, cs),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        _getSeverityIcon(severity),
                        color: iconColor,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight['category'] as String,
                              style: context.textStyles.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              insight['description'] as String,
                              style: context.textStyles.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                            ),
                          ],
                        ),
                      ),
                      if ((insight['value'] as String).isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              insight['value'] as String,
                              style: context.textStyles.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if ((insight['change'] as String).isNotEmpty)
                              Text(
                                insight['change'] as String,
                                style: context.textStyles.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.7)),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.amber;
    return Colors.red;
  }

  List<Widget> _buildComponentBars(Map<String, dynamic> components, ColorScheme cs) {
    final items = [
      {'label': 'Steps', 'value': components['steps'] as int, 'color': Colors.green},
      {'label': 'Pain Control', 'value': components['painControl'] as int, 'color': Colors.red},
      {'label': 'Energy', 'value': components['energy'] as int, 'color': Colors.amber},
      {'label': 'Activity', 'value': components['activity'] as int, 'color': Colors.blue},
    ];
    
    return items.map((item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(item['label'] as String)),
                Text('${item['value']}/100'),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: (item['value'] as int) / 100,
              backgroundColor: cs.surfaceContainerHighest,
              color: item['color'] as Color,
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Map<String, dynamic>> _calculateCorrelations() {
    final correlations = <Map<String, dynamic>>[];
    
    // Extract data points
    final painPoints = <double>[];
    final sleepPoints = <double>[];
    final energyPoints = <double>[];
    final stepsPoints = <double>[];
    
    for (final entry in entries) {
      if (entry.painLevel != null && entry.sleepQuality != null) {
        painPoints.add(entry.painLevel!.toDouble());
        sleepPoints.add(entry.sleepQuality!.toDouble());
      }
      if (entry.energyLevel != null) {
        energyPoints.add(entry.energyLevel!.toDouble());
      }
      if (entry.steps != null) {
        stepsPoints.add(entry.steps!.toDouble());
      }
    }
    
    // Sleep vs Pain
    if (painPoints.length >= 7 && sleepPoints.length >= 7) {
      final r = TrackerAnalytics.calculateCorrelation(sleepPoints, painPoints);
      correlations.add({
        'metric1': 'Sleep',
        'metric2': 'Pain',
        'r': r,
        'riskScore': TrackerAnalytics.correlationToRiskScore(r, inverse: true),
        'insight': TrackerAnalytics.generateCorrelationInsight('Sleep', 'Pain', r),
      });
    }
    
    // Sleep vs Energy
    if (sleepPoints.length >= 7 && energyPoints.length >= 7) {
      final minLen = sleepPoints.length < energyPoints.length ? sleepPoints.length : energyPoints.length;
      final r = TrackerAnalytics.calculateCorrelation(
        sleepPoints.sublist(0, minLen),
        energyPoints.sublist(0, minLen),
      );
      correlations.add({
        'metric1': 'Sleep',
        'metric2': 'Energy',
        'r': r,
        'riskScore': TrackerAnalytics.correlationToRiskScore(r),
        'insight': TrackerAnalytics.generateCorrelationInsight('Sleep', 'Energy', r),
      });
    }
    
    return correlations;
  }

  List<String> _extractUniqueMedications() {
    final meds = <String>{};
    for (final entry in entries) {
      if (entry.medications != null) {
        meds.addAll(entry.medications!);
      }
    }
    return meds.toList();
  }

  List<String> _extractUniqueTriggers() {
    final triggers = <String>{};
    for (final entry in entries) {
      if (entry.triggers != null) {
        triggers.addAll(entry.triggers!);
      }
    }
    return triggers.toList();
  }

  Color _getSeverityColor(String severity, ColorScheme cs) {
    switch (severity) {
      case 'critical':
        return const Color(0xFF3D1F1F); // Dark red
      case 'warning':
        return const Color(0xFF3D2F1F); // Dark orange
      case 'success':
        return const Color(0xFF1F3D1F); // Dark green
      default:
        return cs.primaryContainer;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'success':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }
}

class _CorrelationCard extends StatelessWidget {
  const _CorrelationCard({
    required this.metric1,
    required this.metric2,
    required this.correlation,
    required this.riskScore,
    required this.insight,
  });

  final String metric1;
  final String metric2;
  final double correlation;
  final int riskScore;
  final String insight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strength = TrackerAnalytics.getCorrelationStrength(correlation);
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$metric1 vs $metric2',
                    style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text('r = ${correlation.toStringAsFixed(2)}'),
                  backgroundColor: cs.primaryContainer,
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$strength correlation • Risk Score: $riskScore/100',
              style: context.textStyles.labelMedium?.withColor(cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              insight,
              style: context.textStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.name,
    required this.adherence,
    required this.avgPainOn,
    required this.avgPainOff,
    required this.effectiveness,
  });

  final String name;
  final int adherence;
  final double avgPainOn;
  final double avgPainOff;
  final String effectiveness;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    Color effectColor;
    if (effectiveness == 'Effective') {
      effectColor = Colors.green;
    } else if (effectiveness == 'Review') {
      effectColor = Colors.orange;
    } else {
      effectColor = cs.onSurfaceVariant;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(effectiveness),
                  backgroundColor: effectColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(color: effectColor),
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Adherence: $adherence%', style: context.textStyles.bodyMedium),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: adherence / 100,
              backgroundColor: cs.surfaceContainerHighest,
              color: adherence >= 80 ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Avg pain on medication: ${avgPainOn.toStringAsFixed(1)}/10 • '
              'off medication: ${avgPainOff.toStringAsFixed(1)}/10',
              style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriggerRiskCard extends StatelessWidget {
  const _TriggerRiskCard({
    required this.trigger,
    required this.frequency,
    required this.avgNextDayPain,
    required this.riskScore,
  });

  final String trigger;
  final int frequency;
  final double avgNextDayPain;
  final int riskScore;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    Color riskColor;
    if (riskScore >= 70) {
      riskColor = Colors.red;
    } else if (riskScore >= 40) {
      riskColor = Colors.orange;
    } else {
      riskColor = Colors.green;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trigger,
              style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Frequency: $frequency times • Avg next-day pain: ${avgNextDayPain.toStringAsFixed(1)}/10',
              style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: riskScore / 100,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: riskColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Risk: $riskScore%',
                  style: context.textStyles.labelMedium?.copyWith(color: riskColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
