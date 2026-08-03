import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/models/patient_connection.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/screens/family/tabs/health_pain_tab.dart';
import 'package:wellspring/screens/family/tabs/health_medications_tab.dart';
import 'package:wellspring/screens/family/tabs/health_vitals_tab.dart';
import 'package:wellspring/screens/family/tabs/health_nutrition_tab.dart';
import 'package:wellspring/screens/family/tabs/family_nutrition_collaborative_tab.dart';
import 'package:wellspring/screens/family/tabs/health_daily_log_tab.dart';
import 'package:wellspring/screens/family/tabs/health_charts_tab.dart';
import 'package:wellspring/screens/family/tabs/health_intelligence_tab.dart';
import 'package:wellspring/screens/family/tabs/health_infection_risk_tab.dart';

class FamilyHealthScreen extends StatefulWidget {
  const FamilyHealthScreen({super.key});

  @override
  State<FamilyHealthScreen> createState() => _FamilyHealthScreenState();
}

class _FamilyHealthScreenState extends State<FamilyHealthScreen> with SingleTickerProviderStateMixin {
  final _familyService = FamilyService();
  final _userService = UserService();
  
  late TabController _tabController;
  List<PatientConnection> _connections = [];
  PatientConnection? _selectedConnection;
  List<TrackerEntry> _entries = [];
  bool _loading = true;
  String _error = '';

  final List<String> _tabLabels = [
    'Pain',
    'Medications',
    'Vitals',
    'Nutrition',
    'Daily Log',
    'Charts',
    'Intelligence',
    'Infection Risk'
  ];

  final List<IconData> _tabIcons = [
    Icons.favorite_border,
    Icons.medication_outlined,
    Icons.monitor_heart_outlined,
    Icons.restaurant_outlined,
    Icons.calendar_today,
    Icons.bar_chart,
    Icons.psychology_outlined,
    Icons.warning_amber_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _loading = true;
        _error = '';
      });

      debugPrint('[FamilyHealth] ========================================');
      debugPrint('[FamilyHealth] LOADING FAMILY HEALTH DATA');
      debugPrint('[FamilyHealth] ========================================');

      final user = await _userService.getCurrentUser();
      if (user == null) {
        debugPrint('[FamilyHealth] ❌ No current user found');
        setState(() {
          _error = 'Not logged in';
          _loading = false;
        });
        return;
      }

      debugPrint('[FamilyHealth] ✓ Current user: ${user.name} (${user.id})');
      debugPrint('[FamilyHealth] ✓ Loading patient connections...');

      final connections = await _familyService.getConnectionsForFamily(user.id);
      
      debugPrint('[FamilyHealth] ✓ Found ${connections.length} connection(s)');
      for (final conn in connections) {
        debugPrint('[FamilyHealth]   📋 Connection: "${conn.patientName}" | Patient ID: ${conn.patientId} | Connection ID: ${conn.id}');
      }
      
      if (connections.isEmpty) {
        debugPrint('[FamilyHealth] ❌ No patient connections found');
        debugPrint('[FamilyHealth] → Family member needs to complete onboarding first');
        setState(() {
          _error = 'No patient connections found';
          _loading = false;
        });
        return;
      }

      final selectedConn = connections.first;
      debugPrint('[FamilyHealth] ✓ Selected patient: ${selectedConn.patientName}');
      debugPrint('[FamilyHealth] ✓ Patient ID: ${selectedConn.patientId}');
      debugPrint('[FamilyHealth] ✓ Fetching tracker entries...');
      
      // Load last 90 days of entries
      final entries = await _familyService.getPatientRecentEntries(
        selectedConn.patientId,
        limit: 90,
      );

      debugPrint('[FamilyHealth] ========================================');
      debugPrint('[FamilyHealth] ✅ LOAD COMPLETE');
      debugPrint('[FamilyHealth] → Entries loaded: ${entries.length}');
      debugPrint('[FamilyHealth] ========================================');

      setState(() {
        _connections = connections;
        _selectedConnection = selectedConn;
        _entries = entries;
        _loading = false;
      });
      
      // Show warning if no data
      if (entries.isEmpty) {
        debugPrint('[FamilyHealth] ⚠️  WARNING: No tracker entries loaded');
        debugPrint('[FamilyHealth] → Check Debug Console for API errors');
        debugPrint('[FamilyHealth] → Possible causes:');
        debugPrint('[FamilyHealth]   1. Edge function not deployed');
        debugPrint('[FamilyHealth]   2. Patient has no health data logged');
        debugPrint('[FamilyHealth]   3. Patient ID mismatch in database');
      }
    } catch (e, stackTrace) {
      debugPrint('[FamilyHealth] ========================================');
      debugPrint('[FamilyHealth] ❌ EXCEPTION in _loadData');
      debugPrint('[FamilyHealth] Error: $e');
      debugPrint('[FamilyHealth] Stack trace: $stackTrace');
      debugPrint('[FamilyHealth] ========================================');
      setState(() {
        _error = 'Failed to load health data: $e';
        _loading = false;
      });
    }
  }

  Future<void> _switchPatient(PatientConnection connection) async {
    if (connection.id == _selectedConnection?.id) return;
    
    try {
      setState(() => _loading = true);
      
      final entries = await _familyService.getPatientRecentEntries(
        connection.patientId,
        limit: 90,
      );

      setState(() {
        _selectedConnection = connection;
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[FamilyHealth] Switch patient error: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GlassyScaffold(
      useFamilyBackground: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.favorite, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Health Tracker',
              style: context.textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                (_error == 'No patient connections found' ? cs.primary : cs.error).withValues(alpha: 0.15),
                                (_error == 'No patient connections found' ? cs.primary : cs.error).withValues(alpha: 0.05),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _error == 'No patient connections found' ? Icons.link_off : Icons.error_outline,
                            size: 64,
                            color: _error == 'No patient connections found' ? cs.primary : cs.error,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(_error, style: context.textStyles.headlineMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        if (_error == 'No patient connections found') ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Please complete the family onboarding to connect to a patient.',
                            style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton.icon(
                          onPressed: _error == 'No patient connections found' 
                              ? () => context.go('/family/onboarding')
                              : _loadData,
                          icon: Icon(_error == 'No patient connections found' ? Icons.person_add : Icons.refresh),
                          label: Text(_error == 'No patient connections found' ? 'Connect to Patient' : 'Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Header with patient selector
                    Container(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cs.primary.withValues(alpha: 0.12),
                            cs.primary.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Patient selector
                          if (_connections.isNotEmpty && _connections.length > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: cs.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedConnection?.id,
                                  dropdownColor: cs.surfaceContainerHighest,
                                  style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  icon: Icon(Icons.arrow_drop_down, color: cs.primary),
                                  items: _connections.map((conn) {
                                    return DropdownMenuItem(
                                      value: conn.id,
                                      child: Text(conn.patientName),
                                    );
                                  }).toList(),
                                  onChanged: (id) {
                                    if (id != null) {
                                      final conn = _connections.firstWhere((c) => c.id == id);
                                      _switchPatient(conn);
                                    }
                                  },
                                ),
                              ),
                            )
                          else if (_selectedConnection != null)
                            Text(
                              _selectedConnection!.patientName,
                              style: context.textStyles.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(
                                'Last 30 days • ${_entries.length > 30 ? 30 : _entries.length} entries',
                                style: context.textStyles.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tabs
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Row(
                          children: List.generate(_tabLabels.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: _TabChip(
                                label: _tabLabels[index],
                                icon: _tabIcons[index],
                                isSelected: _tabController.index == index,
                                onTap: () {
                                  setState(() => _tabController.index = index);
                                },
                              ),
                            );
                          }),
                        ),
                      ),
                    ),

                    // Tab content
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                        ),
                        child: _selectedConnection != null 
                          ? TabBarView(
                              controller: _tabController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                HealthPainTab(
                                  entries: _entries.length > 30 ? _entries.sublist(0, 30) : _entries,
                                ),
                                HealthMedicationsTab(
                                  entries: _entries.length > 30 ? _entries.sublist(0, 30) : _entries,
                                ),
                                HealthVitalsTab(
                                  entries: _entries.length > 30 ? _entries.sublist(0, 30) : _entries,
                                ),
                                FamilyNutritionCollaborativeTab(
                                  patientId: _selectedConnection!.patientId,
                                ),
                                HealthDailyLogTab(
                                  entries: _entries.length > 30 ? _entries.sublist(0, 30) : _entries,
                                ),
                                HealthChartsTab(
                                  entries: _entries.length > 30 ? _entries.sublist(0, 30) : _entries,
                                ),
                                HealthIntelligenceTab(
                                  patientId: _selectedConnection!.patientId,
                                  entries: _entries.length > 30 ? _entries.sublist(0, 30) : _entries,
                                ),
                                HealthInfectionRiskTab(
                                  entries: _entries.length > 30 ? _entries.sublist(0, 30) : _entries,
                                ),
                              ],
                            )
                          : Center(
                              child: Text(
                                'No patient selected',
                                style: context.textStyles.bodyLarge,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    cs.primary.withValues(alpha: 0.25),
                    cs.primary.withValues(alpha: 0.15),
                  ],
                )
              : null,
          color: isSelected ? null : cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? cs.primary.withValues(alpha: 0.5) : cs.outline.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: context.textStyles.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
