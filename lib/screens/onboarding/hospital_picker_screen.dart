import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/organization.dart';
import 'package:wellspring/providers/theme_provider.dart';
import 'package:wellspring/services/organization_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/theme.dart';

/// A lightweight one-step screen to choose a hospital (St. Louis area)
/// for users who already have an account but haven't picked a hospital yet.
///
/// On selection, we persist preferences.hospitalId, apply the theme instantly,
/// and navigate back to the intended destination.
class HospitalPickerScreen extends StatefulWidget {
  const HospitalPickerScreen({super.key, this.from});
  final String? from; // original destination to return to

  @override
  State<HospitalPickerScreen> createState() => _HospitalPickerScreenState();
}

class _HospitalPickerScreenState extends State<HospitalPickerScreen> {
  final _organizationService = OrganizationService();
  final _userService = UserService();
  final _searchCtrl = TextEditingController();
  List<Organization> _organizations = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      debugPrint('HospitalPickerScreen: Loading organizations...');
      final list = await _organizationService.getAllOrganizations();
      debugPrint('HospitalPickerScreen: Loaded ${list.length} organizations');
      setState(() => _organizations = list);
    } catch (e) {
      debugPrint('HospitalPickerScreen._load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Organization> get _visibleOrganizations {
    if (_query.isEmpty) return _organizations;
    final q = _query.toLowerCase();
    return _organizations.where((o) =>
      o.name.toLowerCase().contains(q) || o.slug.toLowerCase().contains(q)
    ).toList();
  }

  Future<void> _select(Organization org) async {
    debugPrint('HospitalPickerScreen: Selected organization: ${org.name} (${org.id})');
    try {
      debugPrint('HospitalPickerScreen: Applying theme...');
      await context.read<ThemeProvider>().applyOrganization(org);
      debugPrint('HospitalPickerScreen: Updating preferences...');
      await _userService.updatePreferences({'organizationId': org.id});
      debugPrint('HospitalPickerScreen: Preferences updated');
      // Generate or update patient code tied to this organization
      try {
        await _userService.ensurePatientCodeForCurrentUser(organizationId: org.id);
      } catch (e) {
        debugPrint('HospitalPickerScreen._select ensurePatientCode error: $e');
      }
    } catch (e) {
      debugPrint('HospitalPickerScreen._select error: $e');
    }
    if (!mounted) return;
    // If onboarding isn't complete, move directly into the questionnaire flow next
    try {
      final done = await _userService.isOnboardingCompleted();
      debugPrint('HospitalPickerScreen: Onboarding completed: $done');
      if (!done) {
        debugPrint('HospitalPickerScreen: Navigating to questionnaire');
        context.go('/onboarding/questionnaire');
        return;
      }
    } catch (e) {
      debugPrint('HospitalPickerScreen._select onboarding check error: $e');
    }
    final dest = (widget.from != null && widget.from!.isNotEmpty) ? widget.from! : '/';
    debugPrint('HospitalPickerScreen: Navigating to: $dest');
    context.go(dest);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassyScaffold(
      appBar: AppBar(
        title: const Text('Choose your organization'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "We'll customize colors and content for your selected organization. Choose the one you're working with!",
                  style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await SupabaseConfig.auth.signOut();
                        if (mounted) context.go('/auth');
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to login'),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        // Skip organization selection for now - set a default
                        try {
                          if (_organizations.isNotEmpty) {
                            await _userService.updatePreferences({'organizationId': _organizations.first.id});
                            await context.read<ThemeProvider>().applyOrganization(_organizations.first);
                          }
                          // Check if onboarding is done
                          final done = await _userService.isOnboardingCompleted();
                          if (!done && mounted) {
                            context.go('/onboarding/questionnaire');
                          } else if (mounted) {
                            context.go('/');
                          }
                        } catch (e) {
                          debugPrint('Skip organization error: $e');
                          if (mounted) context.go('/');
                        }
                      },
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Skip'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search organizations',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_loading)
                  const Center(child: CenteredLoadingSkeleton())
                else if (_visibleOrganizations.isEmpty)
                  Row(
                    children: [
                      Icon(Icons.search_off, color: cs.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text('No organizations match your search.',
                            style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant)),
                      ),
                    ],
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _visibleOrganizations.length,
                      itemBuilder: (context, i) {
                        final org = _visibleOrganizations[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            onTap: () => _select(org),
                            child: Container(
                              padding: AppSpacing.paddingMd,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                                border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.business_outlined, color: cs.primary),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(org.name, style: context.textStyles.titleMedium?.semiBold),
                                        if (org.slug.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                                            child: Text('@${org.slug}',
                                                style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Icon(Icons.chevron_right_rounded, color: cs.outline),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}
