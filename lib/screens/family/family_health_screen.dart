import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/models/patient_connection.dart';
import 'package:wellspring/models/user.dart';
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

class _FamilyHealthScreenState extends State<FamilyHealthScreen>
    with SingleTickerProviderStateMixin {
  final _familyService = FamilyService();
  final _userService = UserService();

  late TabController _tabController;
  List<PatientConnection> _connections = [];
  PatientConnection? _selectedConnection;
  List<TrackerEntry> _entries = [];
  User? _patientUser;
  bool _loading = true;
  String _error = '';

  // Available tabs (all options)
  final List<_TabConfig> _allTabs = [
    _TabConfig(id: 'pain', label: 'Pain', icon: Icons.favorite_border),
    _TabConfig(
        id: 'medications',
        label: 'Medications',
        icon: Icons.medication_outlined),
    _TabConfig(
        id: 'vitals', label: 'Vitals', icon: Icons.monitor_heart_outlined),
    _TabConfig(
        id: 'nutrition', label: 'Nutrition', icon: Icons.restaurant_outlined),
    _TabConfig(id: 'daily_log', label: 'Daily Log', icon: Icons.calendar_today),
    _TabConfig(id: 'charts', label: 'Charts', icon: Icons.bar_chart),
    _TabConfig(
        id: 'intelligence',
        label: 'Intelligence',
        icon: Icons.psychology_outlined),
    _TabConfig(
        id: 'infection_risk',
        label: 'Infection Risk',
        icon: Icons.warning_amber_outlined),
  ];

  // Currently active tabs (can be reordered/hidden)
  List<_TabConfig> _activeTabs = [];

  @override
  void initState() {
    super.initState();
    _loadTabPreferences();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTabPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList('family_health_tab_order');
      final hiddenTabs = prefs.getStringList('family_health_hidden_tabs') ?? [];

      setState(() {
        if (savedOrder != null && savedOrder.isNotEmpty) {
          // Restore saved order, filtering out hidden tabs
          _activeTabs = savedOrder
              .where((id) => !hiddenTabs.contains(id))
              .map((id) => _allTabs.firstWhere((tab) => tab.id == id,
                  orElse: () => _allTabs.first))
              .toList();
        } else {
          // Default: show all tabs
          _activeTabs = List.from(_allTabs);
        }

        _tabController = TabController(length: _activeTabs.length, vsync: this);
      });

      _loadData();
    } catch (e) {
      debugPrint('[FamilyHealth] Error loading tab preferences: $e');
      setState(() {
        _activeTabs = List.from(_allTabs);
        _tabController = TabController(length: _activeTabs.length, vsync: this);
      });
      _loadData();
    }
  }

  Future<void> _saveTabPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabOrder = _activeTabs.map((tab) => tab.id).toList();
      await prefs.setStringList('family_health_tab_order', tabOrder);
      debugPrint('[FamilyHealth] Saved tab order: $tabOrder');
    } catch (e) {
      debugPrint('[FamilyHealth] Error saving tab preferences: $e');
    }
  }

  Future<void> _toggleTabVisibility(String tabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hiddenTabs = prefs.getStringList('family_health_hidden_tabs') ?? [];

      if (_activeTabs.any((t) => t.id == tabId)) {
        // Hide tab
        if (_activeTabs.length <= 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('At least one tab must be visible')),
          );
          return;
        }
        hiddenTabs.add(tabId);
        setState(() {
          _activeTabs.removeWhere((t) => t.id == tabId);
          _tabController.dispose();
          _tabController =
              TabController(length: _activeTabs.length, vsync: this);
        });
      } else {
        // Show tab
        hiddenTabs.remove(tabId);
        final tab = _allTabs.firstWhere((t) => t.id == tabId);
        setState(() {
          _activeTabs.add(tab);
          _tabController.dispose();
          _tabController =
              TabController(length: _activeTabs.length, vsync: this);
        });
      }

      await prefs.setStringList('family_health_hidden_tabs', hiddenTabs);
      await _saveTabPreferences();
    } catch (e) {
      debugPrint('[FamilyHealth] Error toggling tab visibility: $e');
    }
  }

  void _showTabCustomizationSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: cs.outlineVariant)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  cs.primary,
                                  cs.primary.withValues(alpha: 0.7)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child:
                                Icon(Icons.tune, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            'Customize Tabs',
                            style: context.textStyles.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),

                    // Instructions
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: cs.primary, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Long-press and drag to reorder tabs. Tap to hide/show.',
                                style: context.textStyles.bodySmall
                                    ?.copyWith(color: cs.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Active tabs (reorderable)
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg),
                        itemCount: _activeTabs.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final tab = _activeTabs.removeAt(oldIndex);
                            _activeTabs.insert(newIndex, tab);
                            _saveTabPreferences();
                          });
                          setModalState(() {});
                        },
                        itemBuilder: (context, index) {
                          final tab = _activeTabs[index];
                          return Padding(
                            key: ValueKey(tab.id),
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  children: [
                                    // Drag handle
                                    Icon(Icons.drag_handle,
                                        color: cs.onSurfaceVariant, size: 24),
                                    const SizedBox(width: AppSpacing.md),

                                    // Icon and label
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            cs.primary.withValues(alpha: 0.2),
                                            cs.primary.withValues(alpha: 0.1)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(tab.icon,
                                          color: cs.primary, size: 20),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(
                                        tab.label,
                                        style: context.textStyles.bodyLarge
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const SizedBox(width: 32),

                                    // Visibility toggle
                                    Padding(
                                      padding: const EdgeInsets.only(right: 24),
                                      child: IconButton(
                                        icon: Icon(Icons.visibility,
                                            color: cs.primary, size: 20),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8),
                                        constraints: const BoxConstraints(
                                            minWidth: 40, minHeight: 40),
                                        onPressed: () {
                                          _toggleTabVisibility(tab.id);
                                          setModalState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Hidden tabs section
                    if (_allTabs.length > _activeTabs.length) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          border:
                              Border(top: BorderSide(color: cs.outlineVariant)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hidden Tabs',
                              style: context.textStyles.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: _allTabs
                                  .where((tab) => !_activeTabs.contains(tab))
                                  .map((tab) {
                                return ActionChip(
                                  avatar: Icon(tab.icon,
                                      size: 16, color: cs.onSurfaceVariant),
                                  label: Text(tab.label),
                                  onPressed: () {
                                    _toggleTabVisibility(tab.id);
                                    setModalState(() {});
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
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
        debugPrint(
            '[FamilyHealth]   📋 Connection: "${conn.patientName}" | Patient ID: ${conn.patientId} | Connection ID: ${conn.id}');
      }

      if (connections.isEmpty) {
        debugPrint('[FamilyHealth] ❌ No patient connections found');
        debugPrint(
            '[FamilyHealth] → Family member needs to complete onboarding first');
        setState(() {
          _error = 'No patient connections found';
          _loading = false;
        });
        return;
      }

      final selectedConn = connections.first;
      debugPrint(
          '[FamilyHealth] ✓ Selected patient: ${selectedConn.patientName}');
      debugPrint('[FamilyHealth] ✓ Patient ID: ${selectedConn.patientId}');

      // Load patient's user object to get medications and other data
      debugPrint('[FamilyHealth] ✓ Fetching patient user object...');
      final patientUser =
          await _userService.getUserById(selectedConn.patientId);
      debugPrint(
          '[FamilyHealth] ✓ Patient medications: ${patientUser?.medications.length ?? 0}');

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
        _patientUser = patientUser;
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

      final patientUser = await _userService.getUserById(connection.patientId);

      setState(() {
        _selectedConnection = connection;
        _entries = entries;
        _patientUser = patientUser;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image.asset(
            isDark
                ? 'assets/images/ChatGPT_Image_Aug_3_2026_07_26_30_AM.png'
                : 'assets/images/Misty_Mountain_Sunrise_Road.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
            ),
          ),
        ),
        // Content
        GlassyScaffold(
          useFamilyBackground: true,
          useThemedBackground: false,
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
            backgroundColor: Colors.transparent,
            forceMaterialTransparency: true,
            actions: [
              IconButton(
                icon: Icon(Icons.tune, color: cs.primary, size: 22),
                onPressed: _showTabCustomizationSheet,
                tooltip: 'Customize tabs',
                iconSize: 24,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
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
                                    (_error == 'No patient connections found'
                                            ? cs.primary
                                            : cs.error)
                                        .withValues(alpha: 0.15),
                                    (_error == 'No patient connections found'
                                            ? cs.primary
                                            : cs.error)
                                        .withValues(alpha: 0.05),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _error == 'No patient connections found'
                                    ? Icons.link_off
                                    : Icons.error_outline,
                                size: 64,
                                color: _error == 'No patient connections found'
                                    ? cs.primary
                                    : cs.error,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(_error,
                                style: context.textStyles.headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center),
                            if (_error == 'No patient connections found') ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Please complete the family onboarding to connect to a patient.',
                                style: context.textStyles.bodyMedium
                                    ?.withColor(cs.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            FilledButton.icon(
                              onPressed:
                                  _error == 'No patient connections found'
                                      ? () => context.go('/family/onboarding')
                                      : _loadData,
                              icon: Icon(
                                  _error == 'No patient connections found'
                                      ? Icons.person_add
                                      : Icons.refresh),
                              label: Text(
                                  _error == 'No patient connections found'
                                      ? 'Connect to Patient'
                                      : 'Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // Header with patient selector
                        Container(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                              AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Patient selector
                              if (_connections.isNotEmpty &&
                                  _connections.length > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.xs),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: cs.outline.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedConnection?.id,
                                      dropdownColor: cs.surfaceContainerHighest,
                                      style: context.textStyles.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                      icon: Icon(Icons.arrow_drop_down,
                                          color: cs.primary),
                                      items: _connections.map((conn) {
                                        return DropdownMenuItem(
                                          value: conn.id,
                                          child: Text(conn.patientName),
                                        );
                                      }).toList(),
                                      onChanged: (id) {
                                        if (id != null) {
                                          final conn = _connections
                                              .firstWhere((c) => c.id == id);
                                          _switchPatient(conn);
                                        }
                                      },
                                    ),
                                  ),
                                )
                              else if (_selectedConnection != null)
                                Text(
                                  _selectedConnection!.patientName,
                                  style: context.textStyles.headlineMedium
                                      ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 14, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Last 30 days • ${_entries.length > 30 ? 30 : _entries.length} entries',
                                    style:
                                        context.textStyles.bodyMedium?.copyWith(
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
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md),
                            child: Row(
                              children:
                                  List.generate(_activeTabs.length, (index) {
                                final tab = _activeTabs[index];
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      right: AppSpacing.sm),
                                  child: _TabChip(
                                    label: tab.label,
                                    icon: tab.icon,
                                    isSelected: _tabController.index == index,
                                    onTap: () {
                                      setState(
                                          () => _tabController.index = index);
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
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppRadius.lg)),
                            ),
                            child: _selectedConnection != null
                                ? TabBarView(
                                    controller: _tabController,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: _activeTabs
                                        .map((tab) => _buildTabContent(tab))
                                        .toList(),
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
        ),
      ],
    );
  }

  Widget _buildTabContent(_TabConfig tab) {
    final limitedEntries =
        _entries.length > 30 ? _entries.sublist(0, 30) : _entries;

    switch (tab.id) {
      case 'pain':
        return HealthPainTab(entries: limitedEntries);
      case 'medications':
        return HealthMedicationsTab(
            entries: limitedEntries, patientUser: _patientUser);
      case 'vitals':
        return HealthVitalsTab(
            entries: limitedEntries, patientId: _selectedConnection!.patientId);
      case 'nutrition':
        return FamilyNutritionCollaborativeTab(
            patientId: _selectedConnection!.patientId);
      case 'daily_log':
        return HealthDailyLogTab(entries: limitedEntries);
      case 'charts':
        return HealthChartsTab(entries: limitedEntries);
      case 'intelligence':
        return HealthIntelligenceTab(
            patientId: _selectedConnection!.patientId, entries: limitedEntries);
      case 'infection_risk':
        return HealthInfectionRiskTab(entries: limitedEntries);
      default:
        return Center(child: Text('Unknown tab: ${tab.id}'));
    }
  }
}

class _TabConfig {
  final String id;
  final String label;
  final IconData icon;

  const _TabConfig({required this.id, required this.label, required this.icon});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TabConfig && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
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
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    cs.primary.withValues(alpha: 0.25),
                    cs.primary.withValues(alpha: 0.15),
                  ],
                )
              : null,
          color: isSelected
              ? null
              : cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outline.withValues(alpha: 0.2),
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
