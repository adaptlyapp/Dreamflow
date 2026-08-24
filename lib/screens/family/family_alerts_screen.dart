import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';

class FamilyAlertsScreen extends StatefulWidget {
  const FamilyAlertsScreen({super.key});

  @override
  State<FamilyAlertsScreen> createState() => _FamilyAlertsScreenState();
}

class _FamilyAlertsScreenState extends State<FamilyAlertsScreen> {
  final _familyService = FamilyService();
  final _userService = UserService();
  bool _showTutorial = false;
  bool _loading = true;
  List<Map<String, dynamic>> _alerts = [];
  String? _patientName;

  @override
  void initState() {
    super.initState();
    _checkTutorial();
    _loadAlerts();
  }

  Future<void> _checkTutorial() async {
    final user = await _userService.getCurrentUser();
    if (user == null) return;
    final hasSeenTutorial = await _familyService.hasTutorialBeenSeen(user.id, 'alerts');
    setState(() => _showTutorial = !hasSeenTutorial);
  }

  Future<void> _dismissTutorial() async {
    final user = await _userService.getCurrentUser();
    if (user != null) await _familyService.markTutorialSeen(user.id, 'alerts');
    setState(() => _showTutorial = false);
  }

  Future<void> _loadAlerts() async {
    setState(() => _loading = true);
    try {
      final user = await _userService.getCurrentUser();
      if (user == null) return;

      final connections = await _familyService.getConnectionsForFamily(user.id);
      if (connections.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final connection = connections.first;
      final alerts = await _familyService.generateAlerts(connection.patientId);

      setState(() {
        _alerts = alerts;
        _patientName = connection.patientName;
        _loading = false;
      });
    } catch (e) {
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
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.family_restroom, color: cs.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Adaptly Family',
              style: context.textStyles.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _alerts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _patientName == null ? Icons.link_off : Icons.notifications_none,
                              size: 64,
                              color: _patientName == null ? cs.outline : cs.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              _patientName == null ? 'No Patient Connection' : 'No Alerts',
                              style: context.textStyles.headlineSmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _patientName != null
                                  ? 'Everything looks good for $_patientName'
                                  : 'Please complete the family onboarding to connect to a patient.',
                              style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                            if (_patientName == null) ...[
                              const SizedBox(height: AppSpacing.xl),
                              FilledButton.icon(
                                onPressed: () => context.go('/family/onboarding'),
                                icon: const Icon(Icons.person_add),
                                label: const Text('Connect to Patient'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAlerts,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: _alerts.length,
                        itemBuilder: (context, index) {
                          final alert = _alerts[index];
                          final type = alert['type'] as String;
                          
                          Color cardColor;
                          Color iconColor;
                          Color textColor;
                          
                          switch (type) {
                            case 'warning':
                              cardColor = const Color(0xFF3D1F1F);
                              iconColor = const Color(0xFFFF6B6B);
                              textColor = Colors.white;
                              break;
                            case 'caution':
                              cardColor = const Color(0xFF3D2F1F);
                              iconColor = const Color(0xFFFFB74D);
                              textColor = Colors.white;
                              break;
                            case 'success':
                              cardColor = const Color(0xFF1F3D1F);
                              iconColor = const Color(0xFF66BB6A);
                              textColor = Colors.white;
                              break;
                            default:
                              cardColor = const Color(0xFF1E2530);
                              iconColor = cs.primary;
                              textColor = Colors.white;
                          }
                          
                          return Card(
                            color: cardColor,
                            margin: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                    ),
                                    child: Icon(alert['icon'] as IconData, color: iconColor, size: 24),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                alert['title'] as String,
                                                style: context.textStyles.titleSmall?.copyWith(
                                                  color: textColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              alert['time'] as String,
                                              style: context.textStyles.labelSmall?.copyWith(
                                                color: textColor.withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          alert['subtitle'] as String,
                                          style: context.textStyles.bodyMedium?.copyWith(
                                            color: textColor.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          if (_showTutorial)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
                child: SafeArea(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(AppSpacing.xl),
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications, size: 64, color: cs.primary),
                          const SizedBox(height: AppSpacing.lg),
                          Text('Alerts & Updates', style: context.textStyles.headlineSmall, textAlign: TextAlign.center),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'See important recovery updates, missed logs, concerning trends, or care-team notices.',
                            style: context.textStyles.bodyLarge?.withColor(cs.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          FilledButton(onPressed: _dismissTutorial, child: const Text('Got it')),
                        ],
                      ),
                    ),
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
}
