import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Web storage access for deep link handling
// Note: keep web-specific imports out of main unless strictly needed.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/firebase_options.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/providers/theme_provider.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:wellspring/screens/conditions/condition_detail_screen.dart';
import 'package:wellspring/screens/conditions/conditions_screen.dart';
import 'package:wellspring/screens/community/community_hub_screen.dart';
import 'package:wellspring/screens/communities/community_detail_screen.dart';
import 'package:wellspring/screens/home/home_screen.dart';
import 'package:wellspring/screens/main_navigation.dart';
import 'package:wellspring/screens/onboarding/welcome_screen.dart';
import 'package:wellspring/screens/onboarding/hospital_picker_screen.dart';
import 'package:wellspring/screens/auth/sign_in_screen.dart';
import 'package:wellspring/screens/auth/sms_mfa_screen.dart';
import 'package:wellspring/screens/auth/auth_callback_screen.dart';
import 'package:wellspring/screens/auth/password_reset_screen.dart';
import 'package:wellspring/screens/tracker/add_entry_screen.dart';
import 'package:wellspring/screens/tracker/tracker_screen.dart';
import 'package:wellspring/screens/tracker/recent_entries_screen.dart';
import 'package:wellspring/screens/tracker/tracker_entry_detail_screen.dart';
import 'package:wellspring/models/tracker_entry.dart';
import 'package:wellspring/models/onboarding_prefill.dart';
import 'package:wellspring/screens/onboarding/questionnaire_screen.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/screens/settings/account_settings_screen.dart';
import 'package:wellspring/screens/profile/profile_screen.dart';
import 'package:wellspring/screens/profile/user_profile_screen.dart';
import 'package:wellspring/screens/goals/plan_editor_screen.dart';
import 'package:wellspring/screens/goals/milestone_education_page.dart';
import 'package:wellspring/services/tutorial_service.dart';
import 'package:wellspring/screens/applications/application_form_screen.dart';
import 'package:wellspring/screens/admin/admin_approval_screen.dart';
import 'package:wellspring/screens/admin/suggestion_approval_screen.dart';
import 'package:wellspring/screens/admin/admin_suggestions_queue_screen.dart';
import 'package:wellspring/screens/admin/data_migration_screen.dart';
import 'package:wellspring/services/analytics_service.dart';
import 'package:wellspring/services/notification_service.dart';
import 'package:wellspring/services/health_service.dart';
import 'package:wellspring/screens/settings/privacy_policy_screen.dart';
import 'package:wellspring/screens/settings/terms_conditions_screen.dart';
import 'package:wellspring/screens/settings/two_step_verification_screen.dart';
import 'package:wellspring/screens/achievements/achievements_screen.dart';
import 'package:wellspring/screens/therapist/connected_therapist_screen.dart';
import 'package:wellspring/widgets/smooth_page.dart';
import 'package:wellspring/screens/family/family_onboarding_screen.dart';
import 'package:wellspring/screens/family/family_dashboard_screen.dart';
import 'package:wellspring/screens/family/family_navigation.dart';
import 'package:wellspring/screens/family/family_health_screen.dart';
import 'package:wellspring/screens/family/family_journey_screen.dart';
import 'package:wellspring/screens/family/family_member_journey_screen.dart';
import 'package:wellspring/screens/family/family_journey_detail_screen.dart';
import 'package:wellspring/screens/family/family_resources_screen.dart';
import 'package:wellspring/screens/family/family_education_screen.dart';
import 'package:wellspring/screens/family/family_daily_care_timeline_screen.dart';
import 'package:wellspring/models/education_resource.dart';
import 'package:wellspring/screens/family/family_alerts_screen.dart';
import 'package:wellspring/screens/family/family_messages_screen.dart';
import 'package:wellspring/screens/family/family_therapist_screen.dart';
import 'package:wellspring/screens/family/family_add_health_log_screen.dart';
import 'package:wellspring/models/user.dart' as models;
import 'package:wellspring/screens/recovery/recovery_blueprint_wizard.dart';
import 'package:wellspring/screens/recovery/care_team_schedule_screen.dart';
import 'package:wellspring/models/recovery_blueprint.dart';
import 'package:wellspring/screens/journey/journey_screen.dart';
import 'package:wellspring/screens/journey/journey_builder_screen.dart';
import 'package:wellspring/screens/journey/milestone_detail_screen.dart';
import 'package:wellspring/screens/journey/arie_journey_creator_screen.dart';
import 'package:wellspring/screens/goals/your_plan_screen.dart';

void main() async {
WidgetsFlutterBinding.ensureInitialized();

// Surface full stack traces for UI build errors (especially on web where
// some exceptions only show a terse message by default).
FlutterError.onError = (details) {
FlutterError.presentError(details);
debugPrint('Flutter error: ${details.exceptionAsString()}');
if (details.stack != null) {
debugPrint(details.stack.toString());
}
};

// Initialize Firebase
try {
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
debugPrint('Firebase initialized successfully');
} catch (e) {
debugPrint('Firebase initialization error: $e');
}

// Initialize Supabase
try {
await SupabaseConfig.initialize();
debugPrint('Supabase initialized successfully');
} catch (e) {
debugPrint('Supabase initialization error: $e');
}
// Restore MFA state so existing sessions are not re-prompted unnecessarily
try {
await UserService().restoreMfaVerification();
} catch (e) {
debugPrint('Restore MFA state error: $e');
}
// Firestore: enable persistence and increase cache for faster repeat reads
try {
FirebaseFirestore.instance.settings = const Settings(
persistenceEnabled: true,
cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
debugPrint('Firestore persistence enabled with unlimited cache');
} catch (e) {
debugPrint('Firestore settings apply error (ignored): $e');
}
// Image cache: allow more decoded images to stay resident (improves scrolling perf)
try {
// ~200MB cache budget for decoded images; adjust at runtime if needed
PaintingBinding.instance.imageCache.maximumSizeBytes = 200 * 1024 * 1024;
debugPrint('Image cache size increased');
} catch (e) {
debugPrint('Image cache tuning failed (ignored): $e');
}
// Initialize Analytics (safe no-op on web if Analytics not fully configured)
try {
await AnalyticsService.instance.init();
} catch (e) {
debugPrint('Analytics init error: $e');
}
// Initialize local notifications and request permission (best-effort).
try {
await NotificationService.instance.init();
// Permission prompt is OS-level; if denied the user can re-enable in Settings.
unawaited(NotificationService.instance.requestPermission().then((granted) {
if (granted) {
// Schedule the always-on daily re-engagement reminders that push users
// back into the app (morning + evening). Safe to call repeatedly; the
// service cancels stale ids first.
unawaited(NotificationService.instance
.scheduleDailyEngagementReminders());
}
}));
} catch (e) {
debugPrint('NotificationService init error: $e');
}

// Initialize Apple Health auto-sync on iOS (best-effort)
if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
try {
final healthService = HealthService();
final hasAuth = await healthService.hasAuthorization();
if (hasAuth) {
// Enable background delivery and start auto-sync
await healthService.enableBackgroundDelivery();
debugPrint('Health auto-sync enabled on app launch');
}
} catch (e) {
debugPrint('Health auto-sync init error: $e');
}
}

runApp(const MyApp());
}

class MyApp extends StatelessWidget {
const MyApp({super.key});

// One-time flag to ensure we only trigger maintenance tasks once per run

@override
Widget build(BuildContext context) {
return MultiProvider(
providers: [
ChangeNotifierProvider(create: (_) => UserProvider()),
ChangeNotifierProvider(create: (_) => ThemeProvider()),
],
child: ShowCaseWidget(
// Keep this at app root so targets are always discoverable across pages
builder: (ctx) {
// Register root context for tutorial so ShowCaseWidget.of(...) never returns null
TutorialService().registerRootShowcaseContext(ctx);
// Load theme from user prefs on first frame
WidgetsBinding.instance.addPostFrameCallback((_) {
try {
ctx.read<ThemeProvider>().loadFromUserPreferences();
} catch (e) {
debugPrint('Theme preload error: $e');
}

// Patient code backfill was Firebase-specific and not needed for Supabase
});
final themeProv = ctx.watch<ThemeProvider>();
return MaterialApp.router(
title: 'Adaptly',
debugShowCheckedModeBanner: false,
theme: themeProv.lightTheme,
darkTheme: themeProv.darkTheme,
// Auto-switch based on system brightness (iOS/Android settings)
themeMode: ThemeMode.system,
routerConfig: _router,
);
},
),
);
}
}

class GoRouterRefreshStream extends ChangeNotifier {
GoRouterRefreshStream(Stream<dynamic> stream) {
_sub = stream.asBroadcastStream().listen((_) {
try {
notifyListeners();
} catch (e) {
debugPrint('GoRouterRefreshStream notify error: $e');
}
});
}
late final StreamSubscription<dynamic> _sub;
@override
void dispose() {
_sub.cancel();
super.dispose();
}
}

/// Minimal sessionStorage wrapper used for web-only deep link handling.
///
/// This is intentionally defensive:
/// - On non-web platforms it returns null / no-ops.
/// - On web it guards against unexpected storage access failures.

// Create router outside of build() to prevent recreating with duplicate GlobalKeys
// Use stable GlobalKeys to prevent duplicate key errors with Navigator
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final _router = GoRouter(
navigatorKey: _rootNavigatorKey,
initialLocation: '/',
refreshListenable: GoRouterRefreshStream(SupabaseConfig.auth.onAuthStateChange.map((e) => e.session)),
// Error page builder as fallback for any unhandled route errors
errorBuilder: (context, state) {
final location = state.uri.toString();
debugPrint('[router] errorBuilder for location: $location');

// Check if this is a Supabase error redirect
if (location.contains('error=') || location.contains('error_code=') || location.contains('otp_expired')) {
// Extract error info for display
String errorCode = 'otp_expired';
String errorDescription = 'Email link is invalid or has expired';

// Try to parse error params
final errorMatch = RegExp(r'error_code=([^&]+)').firstMatch(location);
if (errorMatch != null) errorCode = Uri.decodeComponent(errorMatch.group(1) ?? 'otp_expired');

final descMatch = RegExp(r'error_description=([^&#]+)').firstMatch(location);
if (descMatch != null) errorDescription = Uri.decodeComponent(descMatch.group(1) ?? errorDescription).replaceAll('+', ' ');

// Show the password reset screen with error state
WidgetsBinding.instance.addPostFrameCallback((_) {
context.go('/auth/reset-password?error=$errorCode&error_description=${Uri.encodeComponent(errorDescription)}');
});

// Return a loading screen while redirecting
return Scaffold(
body: Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const CircularProgressIndicator(),
const SizedBox(height: 16),
Text('Redirecting...', style: Theme.of(context).textTheme.bodyMedium),
],
),
),
);
}

// For other unknown routes, show a simple error with home button
return Scaffold(
body: Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const Icon(Icons.error_outline, size: 64, color: Colors.grey),
const SizedBox(height: 16),
Text('Page not found', style: Theme.of(context).textTheme.titleLarge),
const SizedBox(height: 8),
TextButton(
onPressed: () => context.go('/'),
child: const Text('Go Home'),
),
],
),
),
);
},
redirect: (context, state) async {
// ========== FIRST: Check raw URL for Supabase error params ==========
// This MUST be the very first check because go_router may misparse the URL.
// Supabase sends errors like: /?error=access_denied&error_code=otp_expired#/auth?from=...
// go_router sees the hash as the path, so we need to check the raw URL.
final fullUrl = state.uri.toString();
debugPrint('[router] REDIRECT START: fullUrl=$fullUrl path=${state.uri.path}');

// Check if the raw URL contains OTP/password reset error indicators
if (fullUrl.contains('error_code=otp_expired') ||
(fullUrl.contains('error=access_denied') && fullUrl.contains('error_description='))) {
// Don't redirect if already on password reset
if (state.uri.path == '/auth/reset-password') {
debugPrint('[router] Already on password reset, no redirect needed');
return null;
}

// Extract error info from the full URL
String errorCode = 'otp_expired';
String errorDescription = 'Email link is invalid or has expired';

final codeMatch = RegExp(r'error_code=([^&#]+)').firstMatch(fullUrl);
if (codeMatch != null) errorCode = Uri.decodeComponent(codeMatch.group(1) ?? 'otp_expired');

final descMatch = RegExp(r'error_description=([^&#]+)').firstMatch(fullUrl);
if (descMatch != null) errorDescription = Uri.decodeComponent(descMatch.group(1) ?? errorDescription).replaceAll('+', ' ');

debugPrint('[router] OTP error detected in URL, redirecting to password reset: $errorCode');
return '/auth/reset-password?error=$errorCode&error_description=${Uri.encodeComponent(errorDescription)}';
}

// ---- OAuth safety net (Dreamflow preview / web) ---------------------------------
// In some environments the OAuth redirect may land on the site root with
// `?code=...` instead of our intended `/auth/callback` path.
//
// If we don't forward this to the callback route, our auth guard will
// immediately bounce to `/auth` and the one-time code is lost.
//
// Also handle error redirects (expired/invalid OTP links) which have ?error=...
// OR #error=... (Supabase uses hash fragments for some error redirects)
// OR malformed paths like /error=access_denied&... (edge case with some redirects)

// Handle errors from JS redirect (reset_error param set by web/index.html script)
final hasResetError = state.uri.queryParameters['reset_error']?.isNotEmpty == true;
if (hasResetError) {
final errorCode = state.uri.queryParameters['reset_error'] ?? 'otp_expired';
final errorDescription = state.uri.queryParameters['error_description'] ?? 'Email link is invalid or has expired';
debugPrint('[router] reset_error detected, forwarding to password reset: $errorCode');
return '/auth/reset-password?error=$errorCode&error_description=${Uri.encodeComponent(errorDescription)}';
}

// Check if the path itself contains error= (malformed redirect from Supabase)
final pathContainsError = state.uri.path.contains('error=');
if (pathContainsError) {
// The path is actually query params - extract and forward to callback
final errorParams = state.uri.path.startsWith('/')
? state.uri.path.substring(1)
: state.uri.path;
debugPrint('[router] malformed error path detected, forwarding: $errorParams');
return '/auth/callback?$errorParams';
}

final hasOAuthCode = state.uri.queryParameters['code']?.isNotEmpty == true;
final hasOAuthError = state.uri.queryParameters['error']?.isNotEmpty == true;

// Check for error in hash fragment (Supabase sends errors like #error=access_denied&...)
final fragment = state.uri.fragment;
final hasFragmentError = fragment.contains('error=');

// Detect password reset links (type=recovery in URL or fragment)
final urlType = state.uri.queryParameters['type'];
final fragmentType = fragment.contains('type=recovery') ? 'recovery' : null;
final isRecoveryFlow = urlType == 'recovery' || fragmentType == 'recovery';

final isAuthCallbackRoute = state.uri.path == '/auth/callback';
final isPasswordResetRoute = state.uri.path == '/auth/reset-password';

// Route password recovery links to the dedicated reset screen
if (isRecoveryFlow && hasOAuthCode && !isPasswordResetRoute) {
final forwarded = Uri(path: '/auth/reset-password', query: state.uri.query).toString();
debugPrint('[router] forwarding password recovery to $forwarded (from ${state.uri})');
return forwarded;
}

if ((hasOAuthCode || hasOAuthError || hasFragmentError) && !isAuthCallbackRoute && !isPasswordResetRoute) {
// If error is in fragment, convert it to query params for the callback screen
String queryString = state.uri.query;
if (hasFragmentError && queryString.isEmpty) {
queryString = fragment;
}

// Check if this is an OTP/password reset error - redirect to password reset screen directly
final errorCode = state.uri.queryParameters['error_code'] ?? '';
final isOtpError = errorCode == 'otp_expired' ||
queryString.contains('otp_expired') ||
queryString.contains('error=access_denied');

if (isOtpError && !hasOAuthCode) {
// Extract error description
String errorDescription = 'Email link is invalid or has expired';
final descMatch = RegExp(r'error_description=([^&#]+)').firstMatch(queryString);
if (descMatch != null) {
errorDescription = Uri.decodeComponent(descMatch.group(1) ?? errorDescription).replaceAll('+', ' ');
}
final forwarded = '/auth/reset-password?error=$errorCode&error_description=${Uri.encodeComponent(errorDescription)}';
debugPrint('[router] forwarding OTP error to password reset: $forwarded');
return forwarded;
}

final forwarded = Uri(path: '/auth/callback', query: queryString).toString();
debugPrint('[router] forwarding OAuth ${hasOAuthCode ? 'code' : 'error'} to $forwarded (from ${state.uri})');
return forwarded;
}

// Allow one-click moderation links to open without forcing sign-in
// so the approval token flow can run. This path is self-secured by
// Firestore rules that validate approvalToken.
final isSuggestionApprovalPath = state.uri.path == '/admin/suggestions/approval';
final hasApprovalToken = state.uri.queryParameters['token']?.isNotEmpty == true;
if (isSuggestionApprovalPath && hasApprovalToken) {
return null;
}

// For OAuth callback paths, give Supabase extra time to establish the session
// This prevents the router from seeing null session during the brief processing window
final isCallbackPath = state.uri.path == '/auth/callback';
if (isCallbackPath && SupabaseConfig.auth.currentUser == null) {
debugPrint('[router] On callback path with no session yet, waiting for session...');
await Future.delayed(const Duration(milliseconds: 500));
}

final authUser = SupabaseConfig.auth.currentUser;
final userService = UserService();
debugPrint('[router] evaluate redirect: path=${state.uri.path} auth=${authUser?.id ?? 'none'} uri=${state.uri}');

// Pre-compute route flags early for use throughout redirect logic
final isAuthRoute = state.uri.path == '/auth';
final isMfaRoute = state.uri.path == '/auth/mfa';
final isOnboardingRoute = state.uri.path.startsWith('/onboarding');

// IMPORTANT: Get user first, THEN check onboarding
// This ensures that if we provision a new profile (e.g., family), the onboarding check sees it
models.User? currentUserDoc = authUser != null ? await userService.getCurrentUser() : null;
final isOnboardingCompleted = await userService.isOnboardingCompleted();

// If user is authenticated but profile doesn't exist yet (OAuth race condition),
// wait a bit and retry once to let the profile be created
if (authUser != null && currentUserDoc == null) {
debugPrint('[router] User authenticated but profile not found, retrying after delay...');
await Future.delayed(const Duration(milliseconds: 800));
currentUserDoc = await userService.getCurrentUser();
debugPrint('[router] Retry result: ${currentUserDoc != null ? 'found' : 'still missing'}');

// ========== AUTO-FIX FOR BROKEN ACCOUNTS ==========
// If still no profile after retry, this is a broken account (auth exists but no user profile)
// This can happen when session expires during onboarding or database save fails
// Recovery: redirect to onboarding so they can complete their profile
if (currentUserDoc == null && !isOnboardingRoute && !isAuthRoute && !isMfaRoute && !isAuthCallbackRoute && !isPasswordResetRoute) {
debugPrint('[router] ⚠️ BROKEN ACCOUNT DETECTED: auth_id=${authUser.id} email=${authUser.email}');
debugPrint('[router] ✓ Auto-recovery: Redirecting to onboarding to recreate profile');

// Clear any cached onboarding state to force them through the questionnaire
try {
final prefs = await SharedPreferences.getInstance();
await prefs.remove('onboarding_completed');
await prefs.remove('last_active_role');
debugPrint('[router] Cleared onboarding cache for fresh start');
} catch (e) {
debugPrint('[router] Failed to clear onboarding cache: $e');
}

// Redirect to questionnaire - their email will be pre-filled from auth
return '/onboarding/questionnaire';
}
}

final bool hasExistingAccount = currentUserDoc != null;

// Check user role for routing
final userRole = currentUserDoc?.role ?? models.UserRole.patient;
final isFamilyUser = userRole == models.UserRole.family;
debugPrint('[router] User role: ${userRole.value}, isFamilyUser: $isFamilyUser');
final isFamilyRoute = state.uri.path.startsWith('/family');
final isFamilyOnboarding = state.uri.path == '/family/onboarding';
final isHospitalPickerRoute = state.matchedLocation == '/onboarding/hospital';
final callbackFrom = state.uri.queryParameters['from'];
final callbackTarget = callbackFrom != null && callbackFrom.isNotEmpty
? Uri.decodeComponent(callbackFrom)
: (isFamilyUser ? '/family/dashboard' : '/');

// If not authenticated, force to /auth except when already there
if (authUser == null) {
if (!isAuthRoute && !isMfaRoute && !isAuthCallbackRoute && !isPasswordResetRoute) {
// Preserve deep link so we can send user back after sign-in
final from = Uri.encodeComponent(state.uri.toString());
return '/auth?from=$from';
}
return null;
}

// Require SMS MFA after sign-in before entering the app
final mfaVerified = userService.isMfaVerifiedForSession();
debugPrint('[router] MFA check: verified=$mfaVerified isMfaRoute=$isMfaRoute');
if (!mfaVerified && !isMfaRoute) {
final from = state.uri.path == '/auth'
? (state.uri.queryParameters['from'] ?? '/')
: (isAuthCallbackRoute ? callbackTarget : state.uri.toString());
debugPrint('[router] Redirecting to MFA: from=$from');
return '/auth/mfa?from=${Uri.encodeComponent(from)}';
}
if (isMfaRoute && mfaVerified) {
final from = state.uri.queryParameters['from'];
if (from != null && from.isNotEmpty) {
return Uri.decodeComponent(from);
}
if (!isOnboardingCompleted) {
return isFamilyUser ? '/family/onboarding' : '/onboarding';
}
return isFamilyUser ? '/family/dashboard' : '/';
}

// If authenticated and on /auth, decide where to go next
if (isAuthRoute) {
// Check if we should go through MFA first
if (!mfaVerified) {
final from = state.uri.queryParameters['from'] ?? (isFamilyUser ? '/family/dashboard' : '/');
return '/auth/mfa?from=${Uri.encodeComponent(from)}';
}

// If onboarding isn't done, jump into onboarding flow
if (!isOnboardingCompleted) {
return isFamilyUser ? '/family/onboarding' : '/onboarding';
}
final from = state.uri.queryParameters['from'];
if (from != null && from.isNotEmpty) {
return Uri.decodeComponent(from);
}
return isFamilyUser ? '/family/dashboard' : '/';
}

if (isAuthCallbackRoute) {
// Check if we should go through MFA first
if (!mfaVerified) {
return '/auth/mfa?from=${Uri.encodeComponent(callbackTarget)}';
}

if (!isOnboardingCompleted) {
return isFamilyUser ? '/family/onboarding' : '/onboarding';
}
return callbackTarget;
}

// Require onboarding completion after auth (use server flag with legacy-safe default)
if (!isOnboardingCompleted && !isOnboardingRoute && !isFamilyOnboarding && !isMfaRoute) {
debugPrint('[router] onboarding incomplete -> /onboarding or /family/onboarding');
return isFamilyUser ? '/family/onboarding' : '/onboarding';
}

// Check if this is a shared route accessible by both patient and family users
final isSettingsRoute = state.uri.path.startsWith('/settings') || state.uri.path.startsWith('/legal');

// If family user tries to access patient routes, redirect to family dashboard
// Exception: settings and legal routes are accessible by everyone
if (isFamilyUser && !isFamilyRoute && !isAuthRoute && !isMfaRoute && !isAuthCallbackRoute && !isPasswordResetRoute && !isSettingsRoute) {
debugPrint('[router] family user accessing patient route -> /family/dashboard');
return '/family/dashboard';
}

// If patient user tries to access family routes, redirect to patient home
if (!isFamilyUser && isFamilyRoute) {
debugPrint('[router] patient user accessing family route -> /');
return '/';
}

// Additional guard: if user is authenticated but has not selected an organization yet,
// route them to the organization picker once, preserving the destination.
// Skip this check if already on any onboarding route to prevent loops
if (!isOnboardingRoute && !isMfaRoute) {
final prefs = currentUserDoc?.preferences ?? const {};
final organizationId = (prefs['organizationId'] as String?)?.trim();
final hospitalId = (prefs['hospitalId'] as String?)?.trim();
final missingOrganization = (organizationId == null || organizationId.isEmpty) &&
(hospitalId == null || hospitalId.isEmpty);
debugPrint('[router] organization check: hasExisting=$hasExistingAccount organizationId=${organizationId ?? '(none)'} hospitalId=${hospitalId ?? '(none)'} missing=$missingOrganization onOnboarding=$isOnboardingRoute onHospitalPicker=$isHospitalPickerRoute');
if (missingOrganization) {
final from = Uri.encodeComponent(state.uri.toString());
debugPrint('[router] redirect -> /onboarding/hospital?from=$from');
return '/onboarding/hospital?from=$from';
}
}

return null;
},
routes: [
GoRoute(
path: '/auth',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('Auth');
return SmoothTransitionPage(child: const SignInScreen());
},
),
GoRoute(
path: '/auth/mfa',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('SmsMfa');
return SmoothTransitionPage(child: const SmsMfaScreen());
},
),
GoRoute(
path: '/auth/callback',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('AuthCallback');
return SmoothTransitionPage(child: AuthCallbackScreen(uri: state.uri));
},
),
GoRoute(
path: '/auth/reset-password',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('PasswordReset');
return SmoothTransitionPage(child: PasswordResetScreen(uri: state.uri));
},
),
GoRoute(
path: '/onboarding',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('OnboardingWelcome');
return SmoothTransitionPage(child: WelcomeScreen());
},
),
GoRoute(
path: '/onboarding/hospital',
pageBuilder: (context, state) {
final from = state.uri.queryParameters['from'];
AnalyticsService.instance.logScreenView('OnboardingHospital');
return SmoothTransitionPage(child: HospitalPickerScreen(from: from));
},
),
GoRoute(
path: '/onboarding/questionnaire',
pageBuilder: (context, state) {
final prefill = state.extra as OnboardingPrefill?;
AnalyticsService.instance.logScreenView('OnboardingQuestionnaire');
return SmoothTransitionPage(child: QuestionnaireScreen(prefill: prefill));
},
),
ShellRoute(
builder: (context, state, child) {
int currentIndex = 0;
if (state.uri.path == '/') {
currentIndex = 0;
} else if (state.uri.path == '/conditions' || state.uri.path.startsWith('/condition/') || state.uri.path == '/plans' || state.uri.path.startsWith('/plan/')) {
currentIndex = 1;
} else if (state.uri.path == '/communities' || state.uri.path == '/resources' || state.uri.path == '/hub') {
currentIndex = 2;
} else if (state.uri.path == '/tracker' || state.uri.path == '/tracker/add' || state.uri.path == '/tracker/recent' || state.uri.path == '/tracker/entry') {
currentIndex = 3;
} else if (state.uri.path == '/profile' || state.uri.path == '/achievements' || state.uri.path.startsWith('/u/')) {
currentIndex = 4;
}

// Log high-level tab screen views based on location
final path = state.uri.path;
if (path == '/') {
AnalyticsService.instance.logScreenView('Home');
} else if (path == '/journey' || path.startsWith('/journey/') || path == '/arie-journey-creator') {
AnalyticsService.instance.logScreenView('Journey');
} else if (path == '/conditions' || path.startsWith('/condition/') || path == '/plans' || path.startsWith('/plan/')) {
AnalyticsService.instance.logScreenView('Conditions');
} else if (path == '/communities' || path == '/resources' || path == '/hub') {
AnalyticsService.instance.logScreenView('CommunityHub');
} else if (path == '/tracker' || path == '/tracker/add' || path == '/tracker/recent' || path == '/tracker/entry') {
AnalyticsService.instance.logScreenView('Tracker');
} else if (path == '/profile') {
AnalyticsService.instance.logScreenView('Profile');
}

return MainNavigation(
currentIndex: currentIndex,
child: child,
);
},
routes: [
GoRoute(
path: '/',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('Home');
return SmoothTransitionPage(child: HomeScreen());
},
),
GoRoute(
path: '/profile',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('Profile');
return SmoothTransitionPage(child: ProfileScreen());
},
),
GoRoute(
path: '/u/:id',
pageBuilder: (context, state) {
final id = state.pathParameters['id']!;
AnalyticsService.instance.logScreenView('UserProfile');
return SmoothTransitionPage(child: UserProfileScreen(userId: id));
},
),
GoRoute(
path: '/conditions',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('Conditions');
return SmoothTransitionPage(child: ConditionsScreen());
},
),
GoRoute(
path: '/communities',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('Communities');
return SmoothTransitionPage(child: CommunityHubScreen(initialTab: 'communities'));
},
),
GoRoute(
path: '/resources',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('Resources');
final tab = state.uri.queryParameters['tab']?.trim().toLowerCase();
final initialTab = (tab == 'explore') ? 'explore' : 'resources';
return SmoothTransitionPage(child: CommunityHubScreen(initialTab: initialTab));
},
),
GoRoute(
path: '/hub',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('Hub');
return SmoothTransitionPage(child: CommunityHubScreen(initialTab: 'feed'));
},
),
GoRoute(
path: '/journey',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('Journey');
return SmoothTransitionPage(child: const JourneyScreen());
},
),
GoRoute(
path: '/arie-journey-creator',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('ArieJourneyCreator');
return SmoothTransitionPage(child: const ArieJourneyCreatorScreen());
},
),
GoRoute(
path: '/group/:id',
pageBuilder: (context, state) {
final id = state.pathParameters['id']!;
AnalyticsService.instance.logScreenView('GroupDetail');
return SmoothTransitionPage(child: CommunityDetailScreen(communityId: id));
},
),
GoRoute(
path: '/tracker',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('Tracker');
return SmoothTransitionPage(child: TrackerScreen());
},
),
GoRoute(
path: '/tracker/recent',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('TrackerRecent');
return SmoothTransitionPage(child: RecentEntriesScreen());
},
),
GoRoute(
path: '/tracker/entry',
pageBuilder: (context, state) {
final entry = state.extra as dynamic;
AnalyticsService.instance.logScreenView('TrackerEntryDetail');
return SmoothTransitionPage(child: TrackerEntryDetailScreen(entry: entry));
},
),
GoRoute(
path: '/achievements',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('Achievements');
return SmoothTransitionPage(child: const AchievementsScreen());
},
),
GoRoute(
path: '/therapist',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('ConnectedTherapist');
return SmoothTransitionPage(child: const ConnectedTherapistScreen());
},
),
GoRoute(
path: '/plans',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('YourPlan');
return SmoothTransitionPage(child: const YourPlanScreen());
},
),
GoRoute(
path: '/plan/:id',
pageBuilder: (context, state) {
final id = state.pathParameters['id']!;
String name = 'Plan';
String? initialQuestion;
if (state.extra is String) {
name = (state.extra as String?) ?? 'Plan';
} else if (state.extra is Map) {
final data = state.extra as Map;
name = (data['conditionName'] as String?) ?? 'Plan';
initialQuestion = data['initialQuestion'] as String?;
}
AnalyticsService.instance.logScreenView('PlanEditor');
return SmoothTransitionPage(child: PlanEditorScreen(conditionId: id, conditionName: name, initialQuestion: initialQuestion));
},
),
    ],
    ),
    GoRoute(
      path: '/journey/builder',
      pageBuilder: (context, state) {
        AnalyticsService.instance.logScreenView('JourneyBuilder');
        return SmoothTransitionPage(child: const JourneyBuilderScreen());
      },
    ),
    GoRoute(
      path: '/journey/milestone/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        AnalyticsService.instance.logScreenView('MilestoneDetail');
        return SmoothTransitionPage(child: MilestoneDetailScreen(milestoneId: id));
      },
    ),
    GoRoute(
      path: '/condition/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        AnalyticsService.instance.logScreenView('ConditionDetail');
        return SmoothTransitionPage(child: ConditionDetailScreen(conditionId: id));
      },
    ),
    GoRoute(
      path: '/tracker/add',
      pageBuilder: (context, state) {
        AnalyticsService.instance.logScreenView('TrackerAdd');
        final existing = state.extra is TrackerEntry ? state.extra as TrackerEntry : null;
        return SmoothTransitionPage(child: AddEntryScreen(existing: existing));
      },
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) {
        final section = state.uri.queryParameters['section'];
        AnalyticsService.instance.logScreenView('Settings');
        return SmoothTransitionPage(child: AccountSettingsScreen(initialSection: section));
      },
    ),
    GoRoute(
      path: '/milestones/learn-more',
      pageBuilder: (context, state) {
        final args = state.extra;
        if (args is! MilestoneEducationArgs) {
          debugPrint('[router] /milestones/learn-more missing MilestoneEducationArgs; argsType=${args.runtimeType}');
          return SmoothTransitionPage(
            child: Scaffold(
              appBar: AppBar(title: const Text('Learn more')),
              body: const Center(child: Text('Missing milestone context. Please go back and try again.')),
            ),
          );
        }
        AnalyticsService.instance.logScreenView('MilestoneLearnMore');
        return SmoothTransitionPage(
          child: MilestoneEducationPage(
            stepTitle: args.stepTitle,
            stepDescription: args.stepDescription,
            conditionName: args.conditionName,
            conditionDetailsSummary: args.conditionDetailsSummary,
          ),
        );
      },
    ),
    GoRoute(
      path: '/legal/privacy',
      pageBuilder: (context, state) {
        AnalyticsService.instance.logScreenView('PrivacyPolicy');
        return SmoothTransitionPage(child: const PrivacyPolicyScreen());
      },
    ),
    GoRoute(
      path: '/legal/terms',
      pageBuilder: (context, state) {
        AnalyticsService.instance.logScreenView('TermsConditions');
        return SmoothTransitionPage(child: const TermsConditionsScreen());
      },
    ),
    GoRoute(
      path: '/settings/2fa',
      pageBuilder: (context, state) {
        AnalyticsService.instance.logScreenView('TwoStepVerification');
        return SmoothTransitionPage(child: const TwoStepVerificationScreen());
      },
    ),
    GoRoute(
      path: '/apply',
      pageBuilder: (context, state) {
        AnalyticsService.instance.logScreenView('ApplicationForm');
        return SmoothTransitionPage(child: const ApplicationFormScreen());
      },
    ),
    GoRoute(
      path: '/admin/suggestions',
      pageBuilder: (context, state) {
        AnalyticsService.instance.logScreenView('AdminSuggestionsQueue');
        return SmoothTransitionPage(child: const AdminSuggestionsQueueScreen());
      },
    ),
    GoRoute(
      path: '/admin/approval',
      pageBuilder: (context, state) {
        final id = state.uri.queryParameters['id'] ?? '';
        final action = state.uri.queryParameters['action'];
        AnalyticsService.instance.logScreenView('AdminApproval');
        return SmoothTransitionPage(child: AdminApprovalScreen(id: id, action: action));
      },
    ),
    GoRoute(
      path: '/admin/suggestions/approval',
      pageBuilder: (context, state) {
        final id = state.uri.queryParameters['id'] ?? '';
        final action = state.uri.queryParameters['action'];
        final token = state.uri.queryParameters['token'];
        AnalyticsService.instance.logScreenView('AdminSuggestionApproval');
        return SmoothTransitionPage(child: SuggestionApprovalScreen(id: id, action: action, token: token));
      },
    ),
    GoRoute(
      path: '/admin/migration',
      pageBuilder: (context, state) {
        AnalyticsService.instance.logScreenView('DataMigration');
        return SmoothTransitionPage(child: const DataMigrationScreen());
      },
    ),
// Catch-all route for malformed Supabase error redirects
// These come as paths like "/error=access_denied&error_code=otp_expired&..."
GoRoute(
  path: '/:errorPath(error=.*)',
  redirect: (context, state) {
    final errorPath = state.pathParameters['errorPath'] ?? '';
    debugPrint('[router] catch-all matched error path: $errorPath');

    // Extract error info
    String errorCode = 'otp_expired';
    String errorDescription = 'Email link is invalid or has expired';

    final errorMatch = RegExp(r'error_code=([^&]+)').firstMatch(errorPath);
    if (errorMatch != null) errorCode = Uri.decodeComponent(errorMatch.group(1) ?? 'otp_expired');

    final descMatch = RegExp(r'error_description=([^&#]+)').firstMatch(errorPath);
    if (descMatch != null) errorDescription = Uri.decodeComponent(descMatch.group(1) ?? errorDescription).replaceAll('+', ' ');

    return '/auth/reset-password?error=$errorCode&error_description=${Uri.encodeComponent(errorDescription)}';
  },
),
// Family portal routes
GoRoute(
path: '/family/onboarding',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('FamilyOnboarding');
return SmoothTransitionPage(child: const FamilyOnboardingScreen());
},
),
ShellRoute(
builder: (context, state, child) {
int currentIndex = 0;
final path = state.uri.path;
if (path == '/family/dashboard') {
currentIndex = 0;
} else if (path == '/family/health') {
currentIndex = 1;
} else if (path == '/family/journey') {
currentIndex = 2;
} else if (path == '/family/resources') {
currentIndex = 3;
} else if (path == '/family/alerts') {
currentIndex = 4;
}

return FamilyNavigation(
currentIndex: currentIndex,
child: child,
);
},
routes: [
GoRoute(
path: '/family/dashboard',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('FamilyDashboard');
return SmoothTransitionPage(child: const FamilyDashboardScreen());
},
),
        GoRoute(
          path: '/family/health',
          pageBuilder: (context, state) {
            AnalyticsService.instance.logScreenView('FamilyHealth');
            return SmoothTransitionPage(child: const FamilyHealthScreen());
          },
        ),
        GoRoute(
          path: '/family/add-health-log',
          pageBuilder: (context, state) {
            AnalyticsService.instance.logScreenView('FamilyAddHealthLog');
            return SmoothTransitionPage(child: const FamilyAddHealthLogScreen());
          },
        ),
        GoRoute(
          path: '/family/journey',
          pageBuilder: (context, state) {
            AnalyticsService.instance.logScreenView('FamilyJourney');
            return SmoothTransitionPage(child: const FamilyJourneyScreen());
          },
        ),
        GoRoute(
          path: '/family/my-journey',
          pageBuilder: (context, state) {
            AnalyticsService.instance.logScreenView('FamilyMemberJourney');
            return SmoothTransitionPage(child: const FamilyMemberJourneyScreen());
          },
        ),
        GoRoute(
          path: '/family/journey-detail',
          pageBuilder: (context, state) {
            AnalyticsService.instance.logScreenView('FamilyJourneyDetail');
            return SmoothTransitionPage(child: const FamilyJourneyDetailScreen());
          },
        ),
        GoRoute(
          path: '/family/resources',
          pageBuilder: (context, state) {
            AnalyticsService.instance.logScreenView('FamilyResources');
            return SmoothTransitionPage(child: const FamilyResourcesScreen());
          },
        ),
        GoRoute(
          path: '/family/alerts',
          pageBuilder: (context, state) {
            AnalyticsService.instance.logScreenView('FamilyAlerts');
            return SmoothTransitionPage(child: const FamilyAlertsScreen());
          },
        ),
        GoRoute(
          path: '/family/messages',
          pageBuilder: (context, state) {
            AnalyticsService.instance.logScreenView('FamilyMessages');
            return SmoothTransitionPage(child: const FamilyMessagesScreen());
          },
        ),
        GoRoute(
          path: '/family/therapist',
          pageBuilder: (context, state) {
            AnalyticsService.instance.logScreenView('FamilyTherapist');
            return SmoothTransitionPage(child: const FamilyTherapistScreen());
          },
        ),
        GoRoute(
          path: '/family/recovery-blueprint/schedule',
          pageBuilder: (context, state) {
            final patientId = state.extra as String?;
            AnalyticsService.instance.logScreenView('FamilyCareTeamSchedule');
            return SmoothTransitionPage(child: CareTeamScheduleScreen(patientId: patientId));
          },
        ),
        GoRoute(
          path: '/family/recovery-blueprint/timeline',
          pageBuilder: (context, state) {
            final patientId = state.extra as String?;
            AnalyticsService.instance.logScreenView('FamilyDailyCareTimeline');
            return SmoothTransitionPage(child: FamilyDailyCareTimelineScreen(patientId: patientId));
          },
        ),
      ],
    ),
GoRoute(
path: '/family/education',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('FamilyEducation');
return SmoothTransitionPage(child: const FamilyEducationScreen());
},
),
GoRoute(
path: '/family/education/detail',
pageBuilder: (context, state) {
final resource = state.extra as EducationResource?;
AnalyticsService.instance.logScreenView('FamilyEducationDetail');
if (resource == null) {
return SmoothTransitionPage(child: const FamilyEducationScreen());
}
return SmoothTransitionPage(
child: FamilyEducationDetailScreen(resource: resource),
);
},
),
// Patient-facing Education Hub: uses the signed-in user's own conditions
GoRoute(
path: '/education',
pageBuilder: (context, state) {
AnalyticsService.instance.logScreenView('PatientEducation');
return SmoothTransitionPage(
child: const FamilyEducationScreen(
audience: EducationAudience.patient,
),
);
},
),
GoRoute(
path: '/education/detail',
pageBuilder: (context, state) {
final resource = state.extra as EducationResource?;
AnalyticsService.instance.logScreenView('PatientEducationDetail');
if (resource == null) {
return SmoothTransitionPage(
child: const FamilyEducationScreen(
audience: EducationAudience.patient,
),
);
}
return SmoothTransitionPage(
child: FamilyEducationDetailScreen(resource: resource),
);
},
),
GoRoute(
path: '/family/recovery-blueprint/wizard',
pageBuilder: (context, state) {
// extra can be either a String (patientId) or RecoveryBlueprint (existing)
final extra = state.extra;
final patientId = extra is String ? extra : null;
final existing = extra is RecoveryBlueprint ? extra : null;
AnalyticsService.instance.logScreenView('FamilyRecoveryBlueprintWizard');
return SmoothTransitionPage(child: RecoveryBlueprintWizard(existing: existing, patientId: patientId));
},
),
GoRoute(
path: '/recovery-blueprint/schedule',
pageBuilder: (context, state) {
final patientId = state.extra as String?;
AnalyticsService.instance.logScreenView('CareTeamSchedule');
return SmoothTransitionPage(child: CareTeamScheduleScreen(patientId: patientId));
},
),
],
);
