import 'dart:math' as math;
import 'package:wellspring/models/tracker_entry.dart';

/// Utility class for tracker analytics and pattern detection
class TrackerAnalytics {
  
  /// Calculate Pearson correlation coefficient between two metrics
  static double calculateCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 3) return 0;
    
    final n = x.length;
    final meanX = x.reduce((a, b) => a + b) / n;
    final meanY = y.reduce((a, b) => a + b) / n;
    
    double numerator = 0;
    double sumXSq = 0;
    double sumYSq = 0;
    
    for (int i = 0; i < n; i++) {
      final dx = x[i] - meanX;
      final dy = y[i] - meanY;
      numerator += dx * dy;
      sumXSq += dx * dx;
      sumYSq += dy * dy;
    }
    
    if (sumXSq == 0 || sumYSq == 0) return 0;
    
    return numerator / math.sqrt(sumXSq * sumYSq);
  }
  
  /// Get correlation strength label
  static String getCorrelationStrength(double r) {
    final abs = r.abs();
    if (abs >= 0.7) return 'Strong';
    if (abs >= 0.4) return 'Moderate';
    if (abs >= 0.2) return 'Weak';
    return 'None';
  }
  
  /// Get correlation direction
  static String getCorrelationDirection(double r) {
    if (r > 0.2) return 'Positive';
    if (r < -0.2) return 'Negative';
    return 'None';
  }
  
  /// Convert correlation to risk score (0-100)
  static int correlationToRiskScore(double r, {bool inverse = false}) {
    // For metrics where negative correlation is bad (e.g., sleep vs pain)
    if (inverse) {
      return ((1 - r) * 50).round().clamp(0, 100);
    }
    // For metrics where positive correlation is good
    return (r * 100).round().clamp(0, 100);
  }
  
  /// Generate plain-English insight from correlation
  static String generateCorrelationInsight(String metric1, String metric2, double r) {
    final strength = getCorrelationStrength(r);
    final direction = getCorrelationDirection(r);
    
    if (direction == 'None') {
      return 'No clear pattern between $metric1 and $metric2.';
    }
    
    if (metric1 == 'Sleep' && metric2 == 'Pain') {
      if (r < -0.3) {
        return 'Better sleep strongly linked to lower pain. Prioritize sleep quality.';
      }
      return 'Sleep and pain show weak correlation.';
    }
    
    if (metric1 == 'Activity' && metric2 == 'Pain') {
      if (r > 0.3) {
        return 'Higher activity increases pain. Consider reducing intensity.';
      } else if (r < -0.3) {
        return 'Movement helps reduce pain. Maintain activity levels.';
      }
      return 'Activity has minimal impact on pain levels.';
    }
    
    if (metric1 == 'Sleep' && metric2 == 'Energy') {
      if (r > 0.4) {
        return 'Quality sleep significantly boosts energy. Keep sleep routine consistent.';
      }
      return 'Sleep quality moderately affects energy levels.';
    }
    
    if (metric1 == 'Mood' && metric2 == 'Pain') {
      if (r < -0.4) {
        return 'Pain significantly impacts mood. Focus on pain management strategies.';
      }
      return 'Mood and pain are somewhat connected.';
    }
    
    return '$strength $direction correlation detected between $metric1 and $metric2.';
  }
  
  /// Calculate mobility & functional recovery index (0-100)
  static Map<String, dynamic> calculateMobilityIndex(List<TrackerEntry> entries) {
    if (entries.isEmpty) {
      return {'score': 0, 'components': {}, 'trend': 'stable'};
    }
    
    // Component scores
    double stepsScore = 0;
    double painControlScore = 0;
    double energyScore = 0;
    double activityScore = 0;
    
    int stepsCount = 0;
    int painCount = 0;
    int energyCount = 0;
    int activityCount = 0;
    
    for (final entry in entries) {
      if (entry.steps != null) {
        stepsScore += (entry.steps! / 5000 * 100).clamp(0, 100);
        stepsCount++;
      }
      if (entry.painLevel != null) {
        painControlScore += ((10 - entry.painLevel!) / 10 * 100);
        painCount++;
      }
      if (entry.energyLevel != null) {
        energyScore += (entry.energyLevel! / 10 * 100);
        energyCount++;
      }
      if (entry.activities != null && entry.activities!.isNotEmpty) {
        activityScore += 100;
        activityCount++;
      }
    }
    
    // Average scores
    if (stepsCount > 0) stepsScore /= stepsCount;
    if (painCount > 0) painControlScore /= painCount;
    if (energyCount > 0) energyScore /= energyCount;
    if (activityCount > 0) activityScore /= activityCount;
    
    // Weighted composite (steps 30%, pain 30%, energy 25%, activity 15%)
    final composite = (stepsScore * 0.3 + painControlScore * 0.3 + energyScore * 0.25 + activityScore * 0.15).round();
    
    // Calculate trend (first half vs second half)
    String trend = 'stable';
    if (entries.length >= 14) {
      final mid = entries.length ~/ 2;
      final recent = entries.sublist(0, mid);
      final older = entries.sublist(mid);
      
      final recentScore = calculateMobilityIndex(recent)['score'] as int;
      final olderScore = calculateMobilityIndex(older)['score'] as int;
      
      if (recentScore > olderScore + 5) trend = 'improving';
      if (recentScore < olderScore - 5) trend = 'declining';
    }
    
    return {
      'score': composite,
      'components': {
        'steps': stepsScore.round(),
        'painControl': painControlScore.round(),
        'energy': energyScore.round(),
        'activity': activityScore.round(),
      },
      'trend': trend,
    };
  }
  
  /// Calculate medication adherence and effectiveness
  static Map<String, dynamic> analyzeMedicationAdherence(List<TrackerEntry> entries, String medName) {
    final daysWithMed = entries.where((e) => 
      e.medications?.any((m) => m.toLowerCase().contains(medName.toLowerCase())) ?? false
    ).toList();
    
    final daysWithoutMed = entries.where((e) => 
      !(e.medications?.any((m) => m.toLowerCase().contains(medName.toLowerCase())) ?? false)
    ).toList();
    
    if (daysWithMed.isEmpty) {
      return {
        'adherence': 0,
        'avgPainOn': 0,
        'avgPainOff': 0,
        'effectiveness': 'Unknown',
      };
    }
    
    final adherence = (daysWithMed.length / entries.length * 100).round();
    
    double avgPainOn = 0;
    int painOnCount = 0;
    for (final entry in daysWithMed) {
      if (entry.painLevel != null) {
        avgPainOn += entry.painLevel!;
        painOnCount++;
      }
    }
    if (painOnCount > 0) avgPainOn /= painOnCount;
    
    double avgPainOff = 0;
    int painOffCount = 0;
    for (final entry in daysWithoutMed) {
      if (entry.painLevel != null) {
        avgPainOff += entry.painLevel!;
        painOffCount++;
      }
    }
    if (painOffCount > 0) avgPainOff /= painOffCount;
    
    String effectiveness = 'Neutral';
    if (avgPainOn < avgPainOff - 1) effectiveness = 'Effective';
    if (avgPainOn > avgPainOff + 1) effectiveness = 'Review';
    
    return {
      'adherence': adherence,
      'avgPainOn': avgPainOn,
      'avgPainOff': avgPainOff,
      'effectiveness': effectiveness,
    };
  }
  
  /// Calculate environmental risk (trigger impact)
  static Map<String, dynamic> analyzeTriggerRisk(List<TrackerEntry> entries, String triggerName) {
    int frequency = 0;
    double totalNextDayPain = 0;
    int nextDayPainCount = 0;
    
    final sortedEntries = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      if (entry.triggers?.any((t) => t.toLowerCase().contains(triggerName.toLowerCase())) ?? false) {
        frequency++;
        
        // Check next day's pain
        if (i < sortedEntries.length - 1) {
          final nextDay = sortedEntries[i + 1];
          if (nextDay.painLevel != null) {
            totalNextDayPain += nextDay.painLevel!;
            nextDayPainCount++;
          }
        }
      }
    }
    
    final avgNextDayPain = nextDayPainCount > 0 ? totalNextDayPain / nextDayPainCount : 0;
    
    // Risk score: frequency * impact
    final riskScore = (frequency / entries.length * avgNextDayPain * 10).clamp(0, 100).round();
    
    return {
      'frequency': frequency,
      'avgNextDayPain': avgNextDayPain,
      'riskScore': riskScore,
    };
  }
  
  /// Generate auto-insights from tracker data
  static List<Map<String, dynamic>> generateAutoInsights(List<TrackerEntry> entries) {
    final insights = <Map<String, dynamic>>[];
    
    if (entries.isEmpty) return insights;
    
    // Pain trend
    final painEntries = entries.where((e) => e.painLevel != null).toList();
    if (painEntries.length >= 7) {
      final mid = painEntries.length ~/ 2;
      final recentPain = painEntries.sublist(0, mid).fold<double>(0, (sum, e) => sum + e.painLevel!) / mid;
      final olderPain = painEntries.sublist(mid).fold<double>(0, (sum, e) => sum + e.painLevel!) / (painEntries.length - mid);
      final painChange = recentPain - olderPain;
      
      insights.add({
        'category': 'Pain Trend',
        'severity': painChange > 1 ? 'warning' : painChange < -1 ? 'success' : 'info',
        'value': recentPain.toStringAsFixed(1),
        'change': painChange > 0 ? '+${painChange.toStringAsFixed(1)}' : painChange.toStringAsFixed(1),
        'description': painChange > 1 
            ? 'Pain has increased recently' 
            : painChange < -1 
                ? 'Pain has improved significantly' 
                : 'Pain levels are stable',
      });
    }
    
    // Sleep quality
    final sleepEntries = entries.where((e) => e.sleepQuality != null).toList();
    if (sleepEntries.isNotEmpty) {
      final avgSleep = sleepEntries.fold<double>(0, (sum, e) => sum + e.sleepQuality!) / sleepEntries.length;
      insights.add({
        'category': 'Sleep Quality',
        'severity': avgSleep >= 7 ? 'success' : avgSleep >= 5 ? 'info' : 'warning',
        'value': '${avgSleep.toStringAsFixed(1)} hrs',
        'change': '',
        'description': avgSleep >= 7 
            ? 'Getting consistent quality sleep' 
            : avgSleep >= 5 
                ? 'Sleep could be improved' 
                : 'Poor sleep may affect recovery',
      });
    }
    
    // Steps goal
    final stepsEntries = entries.where((e) => e.steps != null).toList();
    if (stepsEntries.isNotEmpty) {
      final avgSteps = stepsEntries.fold<int>(0, (sum, e) => sum + e.steps!) / stepsEntries.length;
      insights.add({
        'category': 'Steps Goal',
        'severity': avgSteps >= 5000 ? 'success' : avgSteps >= 2000 ? 'info' : 'warning',
        'value': '${avgSteps.round()}',
        'change': '',
        'description': avgSteps >= 5000 
            ? 'Meeting daily activity goals' 
            : avgSteps >= 2000 
                ? 'Moderate activity level' 
                : 'Consider increasing daily movement',
      });
    }
    
    // High pain + low sleep correlation
    final highPainLowSleep = entries.where((e) => 
      e.painLevel != null && e.painLevel! >= 7 && 
      e.sleepQuality != null && e.sleepQuality! < 5
    ).length;
    
    if (highPainLowSleep >= 3) {
      insights.add({
        'category': 'Pain & Sleep',
        'severity': 'critical',
        'value': '$highPainLowSleep days',
        'change': '',
        'description': 'High pain combined with poor sleep requires attention',
      });
    }
    
    return insights;
  }
}
