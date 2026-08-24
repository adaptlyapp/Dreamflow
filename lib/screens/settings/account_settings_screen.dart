import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:wellspring/models/condition.dart';
import 'package:wellspring/models/user.dart' as app_user;
import 'package:wellspring/openai/openai_config.dart' as ai;
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/condition_service.dart';
import 'package:wellspring/services/application_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/services/resource_service.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wellspring/providers/theme_provider.dart';
import 'package:wellspring/services/notification_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  final String? initialSection;
  
  const AccountSettingsScreen({super.key, this.initialSection});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _userService = UserService();
  final _conditionService = ConditionService();
  final _applicationService = ApplicationService();
  final _resourceService = ResourceService();
  
  bool _loading = true;
  app_user.User? _user;
  
  // Profile fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _diagnosisDate;
  List<String> _selectedConditions = [];
  List<Condition> _allConditions = [];
  
  // App settings
  bool _notificationsEnabled = true;
  bool _socialNotificationsEnabled = true;
  bool _achievementNotificationsEnabled = true;
  bool _familyAlertsEnabled = true;
  bool _medicationRemindersEnabled = true;
  bool _goalRemindersEnabled = true;
  bool _milestoneRemindersEnabled = true;
  
  // Section keys for scrolling
  final _profileKey = GlobalKey();
  final _appKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = await _userService.getCurrentUser();
      final conditions = await _conditionService.getAllConditions();
      
      // CRITICAL FIX: Ensure patient code is generated for patient users if missing
      if (user != null && 
          user.role == app_user.UserRole.patient && 
          (user.patientCode == null || user.patientCode!.isEmpty)) {
        debugPrint('AccountSettings: Patient code missing, generating now...');
        
        // Try to get hospital/organization from preferences
        final hospitalId = user.preferences['hospitalId'] as String?;
        final organizationId = user.preferences['organizationId'] as String?;
        
        if (hospitalId != null || organizationId != null) {
          try {
            final generatedCode = await _userService.ensurePatientCodeForCurrentUser(
              hospitalId: hospitalId,
              organizationId: organizationId,
            );
            debugPrint('AccountSettings: Generated patient code: $generatedCode');
            
            // Reload user to get the updated patient code
            final updatedUser = await _userService.getCurrentUser();
            if (updatedUser != null) {
              setState(() => _user = updatedUser);
            }
          } catch (e) {
            debugPrint('AccountSettings: Failed to generate patient code: $e');
          }
        } else {
          debugPrint('AccountSettings: Cannot generate patient code - no hospital/organization set');
        }
      }
      
      if (!mounted) return;
      
      setState(() {
        if (_user == null) _user = user;
        _allConditions = conditions;
        
        // Load profile data
        _nameController.text = user?.name ?? '';
        _emailController.text = user?.email ?? '';
        _diagnosisDate = user?.diagnosisDate?.toIso8601String().split('T').first;
        _selectedConditions = List<String>.from(user?.conditions ?? []);
        
        // Load notification preferences
        _notificationsEnabled = (user?.preferences['notificationsEnabled'] as bool?) ?? true;
        _socialNotificationsEnabled = (user?.preferences['socialNotificationsEnabled'] as bool?) ?? true;
        _achievementNotificationsEnabled = (user?.preferences['achievementNotificationsEnabled'] as bool?) ?? true;
        _familyAlertsEnabled = (user?.preferences['familyAlertsEnabled'] as bool?) ?? true;
        _medicationRemindersEnabled = (user?.preferences['medicationRemindersEnabled'] as bool?) ?? true;
        _goalRemindersEnabled = (user?.preferences['goalRemindersEnabled'] as bool?) ?? true;
        _milestoneRemindersEnabled = (user?.preferences['milestoneRemindersEnabled'] as bool?) ?? true;
        
        _loading = false;
      });
      
      // Scroll to section if specified
      if (widget.initialSection != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSection(widget.initialSection!));
      }
    } catch (e) {
      debugPrint('AccountSettings: Error loading data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToSection(String section) {
    GlobalKey? key;
    if (section == 'profile') key = _profileKey;
    if (section == 'app') key = _appKey;
    
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;
    
    try {
      await _userService.updateUserProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
      );
      
      if (mounted) {
        await context.read<UserProvider>().loadUser();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _saveAppSettings() async {
    if (_user == null) return;
    
    try {
      final updatedPrefs = {
        ..._user!.preferences,
        'notificationsEnabled': _notificationsEnabled,
        'socialNotificationsEnabled': _socialNotificationsEnabled,
        'achievementNotificationsEnabled': _achievementNotificationsEnabled,
        'familyAlertsEnabled': _familyAlertsEnabled,
        'medicationRemindersEnabled': _medicationRemindersEnabled,
        'goalRemindersEnabled': _goalRemindersEnabled,
        'milestoneRemindersEnabled': _milestoneRemindersEnabled,
      };
      
      await _userService.updatePreferences(updatedPrefs);
      
      if (mounted) {
        await context.read<UserProvider>().loadUser();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } catch (e) {
      debugPrint('Error saving app settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _testNotification() async {
    try {
      debugPrint('');
      debugPrint('════════════════════════════════════════');
      debugPrint('🧪 NOTIFICATION TEST STARTED');
      debugPrint('════════════════════════════════════════');
      
      // Initialize notification service
      debugPrint('📱 Step 1: Initializing notification service...');
      await NotificationService.instance.init();
      debugPrint('✅ Step 1: Initialization complete');
      
      // Request permission
      debugPrint('📱 Step 2: Requesting notification permission...');
      debugPrint('⚠️  YOU SHOULD SEE A SYSTEM PERMISSION DIALOG NOW');
      final hasPermission = await NotificationService.instance.requestPermission();
      debugPrint('📱 Step 2: Permission result: ${hasPermission ? "✅ GRANTED" : "❌ DENIED"}');
      
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Permission denied! Enable notifications in Settings app.'),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.red,
            ),
          );
        }
        debugPrint('════════════════════════════════════════');
        debugPrint('❌ TEST FAILED: Permission denied');
        debugPrint('SOLUTION: Go to Settings app > Adaptly > Notifications > Allow Notifications');
        debugPrint('════════════════════════════════════════');
        return;
      }
      
      // Send test notification
      debugPrint('📱 Step 3: Sending test notification...');
      await NotificationService.instance.showNow(
        id: 999999,
        title: '✅ Test Notification',
        body: 'If you see this, notifications are working!',
        channelId: NotificationService.generalChannelId,
      );
      debugPrint('✅ Step 3: Notification sent successfully');
      
      debugPrint('════════════════════════════════════════');
      debugPrint('✅ NOTIFICATION TEST COMPLETED');
      debugPrint('Check your device notification center now!');
      debugPrint('════════════════════════════════════════');
      debugPrint('');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb 
                ? '✅ Test complete! Check Debug Console for detailed logs' 
                : '✅ Test notification sent! Check your notification center.'
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('════════════════════════════════════════');
      debugPrint('❌ NOTIFICATION TEST FAILED');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('════════════════════════════════════════');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Test failed: $e'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CenteredLoadingSkeleton())
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Section
                  _Section(
                    key: _profileKey,
                    title: 'Profile',
                    subtitle: 'Your personal information',
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: _saveProfile,
                          child: const Text('Save Profile'),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: AppSpacing.xl),
                  
                  // Notifications Section
                  _Section(
                    key: _appKey,
                    title: 'Notifications',
                    subtitle: 'Manage your notification preferences',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          value: _notificationsEnabled,
                          onChanged: (v) => setState(() => _notificationsEnabled = v),
                          title: const Text('Enable all notifications'),
                          subtitle: const Text('Master switch for all notifications'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        SizedBox(height: AppSpacing.sm),
                        Opacity(
                          opacity: _notificationsEnabled ? 1.0 : 0.5,
                          child: Column(
                            children: [
                              SwitchListTile(
                                value: _socialNotificationsEnabled && _notificationsEnabled,
                                onChanged: _notificationsEnabled ? (v) => setState(() => _socialNotificationsEnabled = v) : null,
                                title: const Text('Social notifications'),
                                subtitle: const Text('Likes, comments, messages'),
                                contentPadding: EdgeInsets.zero,
                              ),
                              SwitchListTile(
                                value: _achievementNotificationsEnabled && _notificationsEnabled,
                                onChanged: _notificationsEnabled ? (v) => setState(() => _achievementNotificationsEnabled = v) : null,
                                title: const Text('Achievement unlocks'),
                                subtitle: const Text('When you earn new achievements'),
                                contentPadding: EdgeInsets.zero,
                              ),
                              SwitchListTile(
                                value: _familyAlertsEnabled && _notificationsEnabled,
                                onChanged: _notificationsEnabled ? (v) => setState(() => _familyAlertsEnabled = v) : null,
                                title: const Text('Family health alerts'),
                                subtitle: const Text('Important health updates'),
                                contentPadding: EdgeInsets.zero,
                              ),
                              SwitchListTile(
                                value: _medicationRemindersEnabled && _notificationsEnabled,
                                onChanged: _notificationsEnabled ? (v) => setState(() => _medicationRemindersEnabled = v) : null,
                                title: const Text('Medication reminders'),
                                subtitle: const Text('Daily medication schedules'),
                                contentPadding: EdgeInsets.zero,
                              ),
                              SwitchListTile(
                                value: _goalRemindersEnabled && _notificationsEnabled,
                                onChanged: _notificationsEnabled ? (v) => setState(() => _goalRemindersEnabled = v) : null,
                                title: const Text('Goal reminders'),
                                subtitle: const Text('Stay on track with your goals'),
                                contentPadding: EdgeInsets.zero,
                              ),
                              SwitchListTile(
                                value: _milestoneRemindersEnabled && _notificationsEnabled,
                                onChanged: _notificationsEnabled ? (v) => setState(() => _milestoneRemindersEnabled = v) : null,
                                title: const Text('Milestone reminders'),
                                subtitle: const Text('Upcoming milestone due dates'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: AppSpacing.md),
                        
                        OutlinedButton.icon(
                          onPressed: _testNotification,
                          icon: const Icon(Icons.notification_add_outlined),
                          label: const Text('Test Notification'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        
                        SizedBox(height: AppSpacing.lg),
                        
                        FilledButton(
                          onPressed: _saveAppSettings,
                          child: const Text('Save Notification Settings'),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: AppSpacing.xl),
                  
                  // Family Connection Section
                  if (_user?.patientCode != null)
                    _Section(
                      title: 'Family Connection',
                      subtitle: 'Share your code with family members',
                      child: Container(
                        padding: AppSpacing.paddingLg,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cs.primaryContainer,
                              cs.secondaryContainer,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Icon(Icons.family_restroom, color: cs.primary, size: 24),
                                ),
                                SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Your Patient Code',
                                        style: context.textStyles.titleMedium?.semiBold,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Family members need this code to connect',
                                        style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: AppSpacing.lg),
                            Container(
                              padding: AppSpacing.paddingMd,
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _user!.patientCode!,
                                      style: context.textStyles.headlineSmall?.copyWith(
                                        fontFamily: 'monospace',
                                        letterSpacing: 2,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      await Clipboard.setData(ClipboardData(text: _user!.patientCode!));
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('✓ Patient code copied to clipboard'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.copy),
                                    tooltip: 'Copy code',
                                    style: IconButton.styleFrom(
                                      backgroundColor: cs.primaryContainer,
                                      foregroundColor: cs.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: AppSpacing.md),
                            Container(
                              padding: AppSpacing.paddingMd,
                              decoration: BoxDecoration(
                                color: cs.tertiaryContainer.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                border: Border.all(color: cs.tertiary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline, color: cs.tertiary, size: 20),
                                  SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      'Share this code with your family members, caregivers, or care team so they can view your health information and support your recovery.',
                                      style: context.textStyles.bodySmall?.withColor(cs.onSurface),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  if (_user?.patientCode != null)
                    SizedBox(height: AppSpacing.xl),
                  
                  // Security Section
                  _Section(
                    title: 'Security',
                    subtitle: 'Protect your account',
                    child: Column(
                      children: [
                        _SettingsTile(
                          icon: Icons.security,
                          title: 'Two-Step Verification',
                          subtitle: 'Add an extra layer of security',
                          onTap: () => context.push('/settings/2fa'),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: AppSpacing.xl),
                  
                  // Legal Section
                  _Section(
                    title: 'Legal',
                    subtitle: 'Policies and terms',
                    child: Column(
                      children: [
                        _SettingsTile(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          subtitle: 'How we handle your data',
                          onTap: () => context.push('/legal/privacy'),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        _SettingsTile(
                          icon: Icons.description_outlined,
                          title: 'Terms & Conditions',
                          subtitle: 'Our terms of service',
                          onTap: () => context.push('/legal/terms'),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: AppSpacing.xl),
                  
                  // About Section
                  _Section(
                    title: 'About',
                    child: Column(
                      children: [
                        _SettingsTile(
                          icon: Icons.info_outline,
                          title: 'Version',
                          subtitle: '1.0.0',
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: AppSpacing.xxl),
                  
                  // Logout Section
                  _Section(
                    title: 'Account',
                    subtitle: 'Sign out of your account',
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Logout'),
                            content: const Text('Are you sure you want to logout?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirmed == true && mounted) {
                          try {
                            await context.read<UserProvider>().logout();
                            if (mounted) {
                              context.go('/auth');
                            }
                          } catch (e) {
                            debugPrint('Logout error: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Logout failed: $e')),
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: AppSpacing.xxl),
                  
                  // Danger Zone
                  Container(
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: cs.error.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber, color: cs.error, size: 20),
                            SizedBox(width: AppSpacing.sm),
                            Text(
                              'Danger Zone',
                              style: context.textStyles.titleSmall?.semiBold.withColor(cs.error),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final passwordController = TextEditingController();
                            final confirm = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Account'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'This action cannot be undone. All your data will be permanently deleted.',
                                    ),
                                    SizedBox(height: AppSpacing.md),
                                    TextField(
                                      controller: passwordController,
                                      decoration: const InputDecoration(
                                        labelText: 'Enter your password to confirm',
                                        border: OutlineInputBorder(),
                                      ),
                                      obscureText: true,
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(context).pop(passwordController.text),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: cs.error,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            
                            if (confirm != null && confirm.isNotEmpty && mounted) {
                              try {
                                await _userService.deleteAccount(currentPassword: confirm);
                                if (mounted) {
                                  await context.read<UserProvider>().logout();
                                  context.go('/auth');
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to delete account: $e')),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Delete Account'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.error,
                            side: BorderSide(color: cs.error),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  
  const _Section({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textStyles.headlineSmall?.semiBold,
        ),
        if (subtitle != null) ...[
          SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: context.textStyles.bodyMedium?.withColor(
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: cs.onPrimaryContainer, size: 20),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.titleSmall?.semiBold),
                  if (subtitle != null) ...[
                    SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
