import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/services/achievement_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/theme.dart';

/// Full-featured dedicated Journey page accessible from Family Portal
class FamilyJourneyDetailScreen extends StatefulWidget {
  const FamilyJourneyDetailScreen({super.key});

  @override
  State<FamilyJourneyDetailScreen> createState() => _FamilyJourneyDetailScreenState();
}

class _FamilyJourneyDetailScreenState extends State<FamilyJourneyDetailScreen> {
  final _familyService = FamilyService();
  final _userService = UserService();
  final _achievementService = AchievementService();
  bool _isLoading = true;
  Map<String, dynamic>? _journeyData;
  String? _patientId;
  String? _patientName;
  String? _selectedConditionId;
  List<Map<String, String>> _conditions = [];
  List<Map<String, dynamic>> _achievements = [];
  String? _expandedMilestoneId;
  Map<String, dynamic>? _milestoneResources;
  bool _loadingResources = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = await _userService.getCurrentUser();
      if (user == null) return;
      
      final connection = await _familyService.getPrimaryConnection(user.id);
      if (connection == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final journeyData = await _familyService.getJourneyData(connection.patientId);
      
      // Extract conditions
      final conditionsMap = journeyData['conditions'] as Map<String, String>? ?? {};
      final conditionsList = conditionsMap.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
      
      // Load achievements
      final achievementRows = await SupabaseConfig.client
          .from('user_achievements')
          .select('*')
          .eq('user_id', connection.patientId)
          .eq('unlocked', true);
      
      setState(() {
        _journeyData = journeyData;
        _patientId = connection.patientId;
        _patientName = connection.patientName;
        _conditions = conditionsList;
        _selectedConditionId = conditionsList.isNotEmpty ? conditionsList.first['id'] : null;
        _achievements = List<Map<String, dynamic>>.from(achievementRows);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading journey detail: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMilestoneResources(Map<String, dynamic> milestone) async {
    if (_loadingResources) return;
    
    setState(() {
      _loadingResources = true;
      _milestoneResources = null;
    });

    try {
      final conditionName = _conditions.firstWhere(
        (c) => c['id'] == _selectedConditionId,
        orElse: () => {'name': 'condition'},
      )['name'];

      final response = await http.post(
        Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/ai-milestone-resources'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
        body: jsonEncode({
          'milestoneTitle': milestone['title'] ?? '',
          'milestoneDescription': milestone['description'] ?? '',
          'conditionName': conditionName ?? 'recovery',
          'patientName': _patientName ?? 'patient',
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _milestoneResources = jsonDecode(response.body);
          _loadingResources = false;
        });
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading resources: $e');
      setState(() => _loadingResources = false);
    }
  }

  void _toggleMilestone(String milestoneId, Map<String, dynamic> milestone) {
    if (_expandedMilestoneId == milestoneId) {
      setState(() {
        _expandedMilestoneId = null;
        _milestoneResources = null;
      });
    } else {
      setState(() => _expandedMilestoneId = milestoneId);
      _loadMilestoneResources(milestone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recovery Journey')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_journeyData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recovery Journey')),
        body: const Center(child: Text('No journey data available')),
      );
    }

    final milestones = (_journeyData!['milestones'] as List?) ?? [];
    final filteredMilestones = _selectedConditionId != null
        ? milestones.where((m) => m['conditionId'] == _selectedConditionId).toList()
        : milestones;
    
    final completedCount = filteredMilestones.where((m) => m['completed'] == true).length;
    final totalCount = filteredMilestones.length;
    final nextMilestone = filteredMilestones.cast<Map<String, dynamic>?>().firstWhere(
      (m) => m?['completed'] != true,
      orElse: () => null,
    );

    final activeGoals = ((_journeyData!['goals'] as List?) ?? [])
        .where((g) => g['active'] == true)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 20),
            const SizedBox(width: 8),
            Text('${_patientName?.split(' ').first ?? 'Patient'}\'s Journey'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Condition filter
            if (_conditions.isNotEmpty) ...[
              _ConditionFilterDropdown(
                conditions: _conditions,
                selectedId: _selectedConditionId,
                onChanged: (id) => setState(() => _selectedConditionId = id),
              ),
              const SizedBox(height: 24),
            ],

            // Progress Overview
            _ProgressOverviewSection(
              completedCount: completedCount,
              totalCount: totalCount,
              achievementsCount: _achievements.length,
            ),
            const SizedBox(height: 24),

            // Next Step Card
            if (nextMilestone != null) ...[
              _NextStepCard(milestone: nextMilestone),
              const SizedBox(height: 24),
            ],

            // Milestone List
            _MilestoneListSection(
              milestones: filteredMilestones,
              expandedId: _expandedMilestoneId,
              resources: _milestoneResources,
              loadingResources: _loadingResources,
              onToggle: _toggleMilestone,
              patientName: _patientName,
            ),
            const SizedBox(height: 24),

            // Active Goals Chart
            if (activeGoals.isNotEmpty) ...[
              _ActiveGoalsChart(goals: activeGoals),
              const SizedBox(height: 24),
            ],

            // Achievements
            if (_achievements.isNotEmpty) ...[
              _AchievementsSection(achievements: _achievements),
              const SizedBox(height: 24),
            ],

            // AI Suggestions
            _AISuggestionsCard(
              completedCount: completedCount,
              totalCount: totalCount,
              nextMilestoneTitle: nextMilestone?['title'],
              patientName: _patientName ?? 'patient',
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionFilterDropdown extends StatelessWidget {
  const _ConditionFilterDropdown({
    required this.conditions,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Map<String, String>> conditions;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedName = conditions.firstWhere(
      (c) => c['id'] == selectedId,
      orElse: () => {'name': 'All Conditions'},
    )['name'];

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Filter by Condition', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                ...conditions.map((c) {
                  final isSelected = c['id'] == selectedId;
                  return ListTile(
                    title: Text(c['name'] ?? ''),
                    trailing: isSelected ? const Icon(Icons.check, color: Colors.teal) : null,
                    onTap: () {
                      onChanged(c['id']);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.filter_list, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(selectedName ?? 'All Conditions', style: context.textStyles.bodyMedium)),
            Icon(Icons.keyboard_arrow_down, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ProgressOverviewSection extends StatelessWidget {
  const _ProgressOverviewSection({
    required this.completedCount,
    required this.totalCount,
    required this.achievementsCount,
  });

  final int completedCount;
  final int totalCount;
  final int achievementsCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final percentage = totalCount > 0 ? (completedCount / totalCount * 100).toInt() : 0;

    return Row(
      children: [
        // Radial progress chart
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            value: completedCount.toDouble(),
                            color: Colors.teal,
                            radius: 20,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: (totalCount - completedCount).toDouble(),
                            color: cs.surfaceContainerHighest,
                            radius: 20,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                    Text('$percentage%', style: context.textStyles.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.teal)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Stats grid
        Expanded(
          child: Column(
            children: [
              _StatCard('Completed', completedCount.toString(), Colors.teal),
              const SizedBox(height: 8),
              _StatCard('Remaining', (totalCount - completedCount).toString(), Colors.orange),
              const SizedBox(height: 8),
              _StatCard('Achievements', achievementsCount.toString(), Colors.amber),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.textStyles.labelMedium),
          Text(value, style: context.textStyles.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.milestone});
  final Map<String, dynamic> milestone;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.teal.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.my_location, color: Colors.teal.shade700, size: 20),
                const SizedBox(width: 8),
                Text('Next Step', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
              ],
            ),
            const SizedBox(height: 12),
            Text(milestone['title'] ?? '', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            if (milestone['description'] != null) ...[
              const SizedBox(height: 8),
              Text(milestone['description'], style: context.textStyles.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _MilestoneListSection extends StatelessWidget {
  const _MilestoneListSection({
    required this.milestones,
    required this.expandedId,
    required this.resources,
    required this.loadingResources,
    required this.onToggle,
    required this.patientName,
  });

  final List milestones;
  final String? expandedId;
  final Map<String, dynamic>? resources;
  final bool loadingResources;
  final Function(String, Map<String, dynamic>) onToggle;
  final String? patientName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Milestones', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...milestones.asMap().entries.map((entry) {
          final index = entry.key;
          final m = entry.value;
          final milestoneId = m['id']?.toString() ?? index.toString();
          final isExpanded = expandedId == milestoneId;
          
          return _MilestoneCard(
            milestone: m,
            index: index,
            isExpanded: isExpanded,
            resources: isExpanded ? resources : null,
            loadingResources: isExpanded && loadingResources,
            onToggle: () => onToggle(milestoneId, m),
          );
        }).toList(),
      ],
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.milestone,
    required this.index,
    required this.isExpanded,
    required this.resources,
    required this.loadingResources,
    required this.onToggle,
  });

  final Map<String, dynamic> milestone;
  final int index;
  final bool isExpanded;
  final Map<String, dynamic>? resources;
  final bool loadingResources;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompleted = milestone['completed'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted ? Colors.teal : Colors.transparent,
                      border: Border.all(color: isCompleted ? Colors.teal : cs.outline, width: 2),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : Text('${index + 1}', style: context.textStyles.labelMedium),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone['title'] ?? 'Milestone ${index + 1}',
                          style: context.textStyles.bodyLarge?.copyWith(
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (milestone['description'] != null && !isExpanded) ...[
                          const SizedBox(height: 4),
                          Text(
                            milestone['description'],
                            style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('Resources', style: context.textStyles.labelSmall),
                    avatar: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 16),
                    side: BorderSide.none,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            if (loadingResources)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Finding resources for this milestone...'),
                    ],
                  ),
                ),
              )
            else if (resources != null)
              _MilestoneResourcesPanel(resources: resources!),
          ],
        ],
      ),
    );
  }
}

class _MilestoneResourcesPanel extends StatelessWidget {
  const _MilestoneResourcesPanel({required this.resources});
  final Map<String, dynamic> resources;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Summary
          if (resources['aiSummary'] != null) ...[
            Text('What This Means', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(resources['aiSummary'], style: context.textStyles.bodyMedium),
            const SizedBox(height: 20),
          ],

          // How You Can Help
          if (resources['howYouCanHelp'] != null) ...[
            Text('How You Can Help', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(resources['howYouCanHelp'] as List).map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: context.textStyles.bodyMedium),
                  Expanded(child: Text(tip, style: context.textStyles.bodyMedium)),
                ],
              ),
            )).toList(),
            const SizedBox(height: 20),
          ],

          // Practice at Home
          if (resources['practiceAtHome'] != null) ...[
            Text('Practice at Home', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...(resources['practiceAtHome'] as List).map((activity) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.blue.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(activity['name'] ?? '', style: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        if (activity['frequency'] != null)
                          Chip(
                            label: Text(activity['frequency'], style: context.textStyles.labelSmall),
                            backgroundColor: Colors.blue.withValues(alpha: 0.2),
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...(activity['instructions'] as List).asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${e.key + 1}. ${e.value}', style: context.textStyles.bodySmall),
                    )).toList(),
                  ],
                ),
              ),
            )).toList(),
            const SizedBox(height: 20),
          ],

          // Nearby Locations
          if (resources['nearbyLocations'] != null) ...[
            Text('Nearby Locations to Explore', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...(resources['nearbyLocations'] as List).map((loc) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.place, color: Colors.red),
                title: Text(loc['type'] ?? ''),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _launchUrl('https://www.google.com/maps/search/${Uri.encodeComponent(loc['searchQuery'] ?? '')}'),
              ),
            )).toList(),
            const SizedBox(height: 20),
          ],

          // Resources
          if (resources['resources'] != null) ...[
            Text('Information & Resources', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...(resources['resources'] as List).map((res) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  res['type'] == 'video' ? Icons.play_circle : res['type'] == 'app' ? Icons.phone_android : Icons.article,
                  color: Colors.teal,
                ),
                title: Text(res['title'] ?? ''),
                subtitle: Text(res['type'] ?? ''),
                trailing: const Icon(Icons.search, size: 18),
                onTap: () => _launchUrl('https://www.google.com/search?q=${Uri.encodeComponent(res['searchQuery'] ?? '')}'),
              ),
            )).toList(),
            const SizedBox(height: 20),
          ],

          // Products
          if (resources['products'] != null) ...[
            Text('Recommended Products', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Consult your care team before purchasing', style: context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            ...(resources['products'] as List).map((prod) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.orange.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(prod['name'] ?? '', style: context.textStyles.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        if (prod['priceRange'] != null)
                          Text(prod['priceRange'], style: context.textStyles.labelMedium?.copyWith(color: Colors.orange.shade700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(prod['description'] ?? '', style: context.textStyles.bodySmall),
                    const SizedBox(height: 4),
                    Text('Why it helps: ${prod['reason'] ?? ''}', style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _launchUrl('https://www.amazon.com/s?k=${Uri.encodeComponent(prod['searchQuery'] ?? '')}'),
                        icon: const Icon(Icons.shopping_cart, size: 16),
                        label: const Text('View on Amazon'),
                      ),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ],
        ],
      ),
    );
  }
}

class _ActiveGoalsChart extends StatelessWidget {
  const _ActiveGoalsChart({required this.goals});
  final List goals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active Goals Progress', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              height: goals.length * 60.0,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: goals.asMap().entries.map((entry) {
                    final g = entry.value;
                    final progress = (g['progressThisPeriod'] ?? 0) / (g['targetPerPeriod'] ?? 1);
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: (progress * 100).clamp(0, 100),
                          color: Colors.teal,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 120,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= goals.length) return const SizedBox();
                          final goal = goals[value.toInt()];
                          final title = goal['title'] ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              title.length > 18 ? '${title.substring(0, 18)}...' : title,
                              style: context.textStyles.labelSmall,
                              textAlign: TextAlign.right,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem('${rod.toY.toInt()}%', const TextStyle(color: Colors.white));
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection({required this.achievements});
  final List<Map<String, dynamic>> achievements;

  static const _achievementLabels = {
    'first_entry': {'title': 'First Entry', 'desc': 'Logged the first health entry'},
    'tracker_week': {'title': 'Week Warrior', 'desc': 'Logged entries for 7 days'},
    'tracker_month': {'title': 'Month Master', 'desc': 'Logged entries for 30 days'},
    'tracker_streak_7': {'title': '7-Day Streak', 'desc': '7 consecutive days of tracking'},
    'tracker_streak_30': {'title': '30-Day Streak', 'desc': '30 consecutive days of tracking'},
    'first_goal': {'title': 'Goal Setter', 'desc': 'Created the first goal'},
    'goal_complete': {'title': 'Goal Achiever', 'desc': 'Completed a goal'},
    'milestone_1': {'title': 'First Milestone', 'desc': 'Completed the first milestone'},
    'milestone_5': {'title': 'Milestone Hunter', 'desc': 'Completed 5 milestones'},
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Achievements Unlocked', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                final ach = achievements[index];
                final achievementId = ach['achievement_id'];
                final label = _achievementLabels[achievementId] ?? {'title': 'Achievement', 'desc': 'Unlocked'};
                
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.workspace_premium, color: Colors.amber, size: 24),
                      const SizedBox(height: 8),
                      Text(label['title'] ?? '', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(label['desc'] ?? '', style: context.textStyles.labelSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AISuggestionsCard extends StatefulWidget {
  const _AISuggestionsCard({
    required this.completedCount,
    required this.totalCount,
    required this.nextMilestoneTitle,
    required this.patientName,
  });

  final int completedCount;
  final int totalCount;
  final String? nextMilestoneTitle;
  final String patientName;

  @override
  State<_AISuggestionsCard> createState() => _AISuggestionsCardState();
}

class _AISuggestionsCardState extends State<_AISuggestionsCard> {
  List<String>? _suggestions;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/ai-family-journey-suggestions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        },
        body: jsonEncode({
          'completedMilestones': widget.completedCount,
          'totalMilestones': widget.totalCount,
          'nextMilestoneTitle': widget.nextMilestoneTitle,
          'patientName': widget.patientName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _suggestions = List<String>.from(data['suggestions']);
          _loading = false;
        });
      } else {
        throw Exception('API error');
      }
    } catch (e) {
      debugPrint('Error loading suggestions: $e');
      setState(() {
        _suggestions = [
          'Celebrate ${widget.patientName}\'s progress by acknowledging both big wins and small daily achievements. Positive reinforcement builds confidence and motivation.',
          'Create a comfortable, distraction-free space where ${widget.patientName} can practice recovery exercises safely. Having a dedicated area makes it easier to maintain consistency.',
          'Schedule regular check-ins to discuss how ${widget.patientName} is feeling about their progress. Open communication helps identify challenges early and strengthens your support role.',
        ];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text('How You Can Help', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_suggestions != null)
              ..._suggestions!.asMap().entries.map((entry) => Padding(
                padding: EdgeInsets.only(bottom: entry.key < _suggestions!.length - 1 ? 12 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                      child: Center(
                        child: Text('${entry.key + 1}', style: context.textStyles.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.value, style: context.textStyles.bodyMedium)),
                  ],
                ),
              )).toList(),
          ],
        ),
      ),
    );
  }
}
