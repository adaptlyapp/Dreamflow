import 'package:flutter/material.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/theme.dart';
import 'package:intl/intl.dart';

class HealthInfectionRiskTab extends StatelessWidget {
  const HealthInfectionRiskTab({super.key, required this.entries});

  final List<TrackerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final familyService = FamilyService();
    
    // Detect infection signals
    final signals = familyService.detectInfectionSignals(entries);
    
    // Check for fever
    final feverEntries = entries.where((e) => 
      e.temperature != null && e.temperature! >= 100.4
    ).toList();
    
    // Check for infection-related symptoms
    final infectionSymptoms = [
      'fever', 'chills', 'sweating', 'infection', 'drainage', 'pus',
      'redness', 'swelling', 'dysuria', 'cloudy urine', 'foul smell',
      'increased spasms', 'fatigue', 'confusion'
    ];
    
    final symptomsFound = <String, List<DateTime>>{};
    for (final entry in entries) {
      if (entry.symptoms != null) {
        for (final symptom in entry.symptoms!) {
          for (final keyword in infectionSymptoms) {
            if (symptom.toLowerCase().contains(keyword)) {
              if (!symptomsFound.containsKey(keyword)) {
                symptomsFound[keyword] = [];
              }
              symptomsFound[keyword]!.add(entry.date);
            }
          }
        }
      }
    }
    
    // Calculate overall risk score
    int riskScore = 0;
    if (feverEntries.isNotEmpty) riskScore += 40;
    if (symptomsFound.isNotEmpty) riskScore += 30;
    if (signals.where((s) => s['severity'] == 'critical').isNotEmpty) riskScore += 30;
    riskScore = riskScore.clamp(0, 100);
    
    String riskLevel;
    Color riskColor;
    IconData riskIcon;
    if (riskScore >= 70) {
      riskLevel = 'High Risk';
      riskColor = Colors.red;
      riskIcon = Icons.error;
    } else if (riskScore >= 40) {
      riskLevel = 'Moderate Risk';
      riskColor = Colors.orange;
      riskIcon = Icons.warning;
    } else if (riskScore > 0) {
      riskLevel = 'Low Risk';
      riskColor = Colors.amber;
      riskIcon = Icons.info;
    } else {
      riskLevel = 'No Concerns';
      riskColor = Colors.green;
      riskIcon = Icons.check_circle;
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Infection Risk Analysis',
            style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'AI-powered infection detection from ${entries.length} entries',
            style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),
          
          // Overall Risk Score
          Card(
            color: riskColor.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Icon(riskIcon, size: 64, color: riskColor),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    riskLevel,
                    style: context.textStyles.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: riskColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Risk Score: $riskScore/100',
                    style: context.textStyles.titleMedium?.withColor(riskColor),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (riskScore >= 40) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: riskColor),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Potential infection indicators detected. Contact healthcare provider if symptoms persist.',
                              style: context.textStyles.bodyMedium?.copyWith(color: riskColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          
          // Infection Signals
          if (signals.isNotEmpty) ...[
            Text(
              'Detected Signals',
              style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...signals.map((signal) {
              final severity = signal['severity'] as String;
              Color signalColor;
              IconData signalIcon;
              
              if (severity == 'critical') {
                signalColor = Colors.red;
                signalIcon = Icons.error;
              } else if (severity == 'warning') {
                signalColor = Colors.orange;
                signalIcon = Icons.warning;
              } else {
                signalColor = Colors.amber;
                signalIcon = Icons.info;
              }
              
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                color: signalColor.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(signalIcon, color: signalColor, size: 24),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              signal['title'] as String,
                              style: context.textStyles.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: signalColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              signal['description'] as String,
                              style: context.textStyles.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat.yMMMd().format(signal['date'] as DateTime),
                              style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.lg),
          ],
          
          // Temperature Monitoring
          if (feverEntries.isNotEmpty) ...[
            Text(
              'Temperature Monitoring',
              style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.thermostat, color: Colors.red, size: 28),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Elevated Temperature Detected',
                            style: context.textStyles.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${feverEntries.length} days with fever (≥100.4°F)',
                      style: context.textStyles.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...feverEntries.take(5).map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Text(
                              DateFormat.MMMd().format(entry.date),
                              style: context.textStyles.labelMedium,
                            ),
                            const Spacer(),
                            Text(
                              '${entry.temperature!.toStringAsFixed(1)}°F',
                              style: context.textStyles.labelMedium?.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
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
          
          // Infection-Related Symptoms
          if (symptomsFound.isNotEmpty) ...[
            Text(
              'Infection-Related Symptoms',
              style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${symptomsFound.length} infection indicators found',
                      style: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...symptomsFound.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.circle, size: 8, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.key.toUpperCase(),
                                    style: context.textStyles.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text('${entry.value.length}×'),
                                  backgroundColor: Colors.orange.withValues(alpha: 0.2),
                                  labelStyle: TextStyle(color: Colors.orange, fontSize: 12),
                                  padding: EdgeInsets.zero,
                                  side: BorderSide.none,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(
                                'Last seen: ${DateFormat.MMMd().format(entry.value.first)}',
                                style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant),
                              ),
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
          
          // Clinical Guidance
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.medical_information, color: cs.onPrimaryContainer),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Clinical Guidance',
                        style: context.textStyles.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Watch for these infection warning signs:',
                    style: context.textStyles.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...[
                    'Temperature ≥100.4°F',
                    'Cloudy or foul-smelling urine',
                    'Increased muscle spasms',
                    'New or worsening pain',
                    'Chills, sweating, or fatigue',
                    'Redness, warmth, or drainage from wounds',
                  ].map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: context.textStyles.bodyMedium?.withColor(cs.onPrimaryContainer)),
                        Expanded(
                          child: Text(
                            item,
                            style: context.textStyles.bodyMedium?.withColor(cs.onPrimaryContainer),
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: AppSpacing.md),
                  if (riskScore >= 40)
                    Text(
                      '⚠️ Contact your healthcare provider promptly if symptoms persist or worsen.',
                      style: context.textStyles.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
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
