import 'package:flutter/material.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/theme.dart';

class HealthNutritionTab extends StatelessWidget {
  const HealthNutritionTab({super.key, required this.entries});

  final List<TrackerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // Extract nutrition data from customFields.nutritionV1
    final nutritionEntries = entries.where((e) => 
      e.customFields != null && e.customFields!['nutritionV1'] != null
    ).toList();
    
    if (nutritionEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_outlined, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No nutrition data logged',
              style: context.textStyles.bodyLarge?.withColor(cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    
    // Calculate nutrition averages
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalWater = 0;
    int count = 0;
    
    for (final entry in nutritionEntries) {
      final nutrition = entry.customFields!['nutritionV1'] as Map<String, dynamic>?;
      if (nutrition != null) {
        totalCalories += (nutrition['calories'] as num?)?.toDouble() ?? 0;
        totalProtein += (nutrition['protein'] as num?)?.toDouble() ?? 0;
        totalCarbs += (nutrition['carbs'] as num?)?.toDouble() ?? 0;
        totalFat += (nutrition['fat'] as num?)?.toDouble() ?? 0;
        totalWater += (nutrition['water'] as num?)?.toDouble() ?? 0;
        count++;
      }
    }
    
    final avgCalories = count > 0 ? totalCalories / count : 0;
    final avgProtein = count > 0 ? totalProtein / count : 0;
    final avgCarbs = count > 0 ? totalCarbs / count : 0;
    final avgFat = count > 0 ? totalFat / count : 0;
    final avgWater = count > 0 ? totalWater / count : 0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nutrition Overview',
            style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Averages from ${nutritionEntries.length} logged days',
            style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),
          
          // Average nutrition cards
          Row(
            children: [
              Expanded(
                child: _NutritionCard(
                  label: 'Calories',
                  value: '${avgCalories.round()}',
                  unit: 'kcal',
                  color: Colors.orange,
                  icon: Icons.local_fire_department,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _NutritionCard(
                  label: 'Protein',
                  value: '${avgProtein.round()}',
                  unit: 'g',
                  color: Colors.red,
                  icon: Icons.fitness_center,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _NutritionCard(
                  label: 'Carbs',
                  value: '${avgCarbs.round()}',
                  unit: 'g',
                  color: Colors.amber,
                  icon: Icons.bakery_dining,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _NutritionCard(
                  label: 'Fat',
                  value: '${avgFat.round()}',
                  unit: 'g',
                  color: Colors.purple,
                  icon: Icons.water_drop,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Icon(Icons.local_drink, color: Colors.blue, size: 32),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Water Intake', style: context.textStyles.labelLarge),
                        const SizedBox(height: 4),
                        Text(
                          '${avgWater.toStringAsFixed(1)} L/day',
                          style: context.textStyles.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Nutrition context
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: cs.onPrimaryContainer),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Nutrition Insights',
                        style: context.textStyles.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Patient has logged nutrition data for ${nutritionEntries.length} days. '
                    'Daily averages show ${avgCalories.round()} calories, '
                    '${avgProtein.round()}g protein, and ${avgWater.toStringAsFixed(1)}L water.',
                    style: context.textStyles.bodyMedium?.withColor(cs.onPrimaryContainer),
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

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;

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
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(label, style: context.textStyles.labelMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: context.textStyles.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
                    style: context.textStyles.labelMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
