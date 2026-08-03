import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:wellspring/auth/auth_manager.dart';
import 'package:wellspring/models/user.dart' as app;
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/utils/web_entry_uri.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

/// Supabase implementation of AuthManager
/// Provides email/password authentication using Supabase Auth
class SupabaseAuthManager extends AuthManager with EmailSignInManager, GoogleSignInManager, AppleSignInManager {
  static final SupabaseAuthManager _instance = SupabaseAuthManager._();
  SupabaseAuthManager._();
  factory SupabaseAuthManager() => _instance;

  // Google OAuth Client IDs from Supabase dashboard
  // Get these from: Supabase Dashboard > Authentication > Providers > Google

  @override
  Future<app.User?> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final response = await SupabaseConfig.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw 'Sign in failed';
      }

      // Fetch user profile from users table
      return await _getUserFromDatabase(response.user!.id);
    } on AuthException catch (e) {
      debugPrint('SupabaseAuth signInWithEmail error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('SupabaseAuth signInWithEmail error: $e');
      rethrow;
    }
  }

  @override
  Future<app.User?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      // Get the current URL for redirects (web) or use a custom scheme (mobile)
      String? redirectUrl;
      if (kIsWeb) {
        // Prefer returning to app root. Dreamflow one-click web hosting does not
        // reliably support deep-link paths like `/auth/callback`.
        redirectUrl = buildWebAppEntryUri(Uri.base).toString();
      }

      final response = await SupabaseConfig.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: redirectUrl,
      );

      if (response.user == null) {
        throw 'Sign up failed';
      }

      // Create user profile in users table
      final now = DateTime.now();
      final userData = {
        'id': response.user!.id,
        'name': email.split('@')[0],
        'email': email,
        'onboarding_completed': false,
        'conditions': [],
        'interests': [],
        'preferences': {},
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      await SupabaseConfig.client.from('users').insert(userData);

      // Return the newly created user
      return await _getUserFromDatabase(response.user!.id);
    } on AuthException catch (e) {
      debugPrint('SupabaseAuth createAccountWithEmail error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('SupabaseAuth createAccountWithEmail error: $e');
      rethrow;
    }
  }

  @override
  Future<app.User?> signInWithGoogle(BuildContext context) async {
    try {
      debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
      debugPrint('[SupabaseAuth] signInWithGoogle called, isWeb=$kIsWeb');
      debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
      
      // NOTE: Native Google Sign-In with google_sign_in package is not available in Dreamflow.
      // 
      // CURRENT BEHAVIOR: Uses browser OAuth for Google on all platforms.
      // The browser should automatically close and redirect back to the app using deep links.
      // 
      // IMPORTANT: After publishing your app and downloading the code:
      // You can implement native Google Sign-In to match the Apple implementation:
      //   1. Add google_sign_in package to pubspec.yaml
      //   2. Configure Google OAuth clients (Web + iOS) in Google Cloud Console
      //   3. The reversed client ID is already in ios/Runner/Info.plist
      //   4. Replace this browser flow with signInWithIdToken() like Apple does
      
      String? redirectUrl;
      if (kIsWeb) {
        redirectUrl = buildWebAppEntryUri(Uri.base).toString();
        debugPrint('[SupabaseAuth] Google OAuth redirectUrl (web): $redirectUrl');
      } else {
        // IMPORTANT: Must match CFBundleURLSchemes in Info.plist exactly (case-sensitive!)
        // iOS uses this to deep link back to the app and close the Safari browser
        redirectUrl = 'com.Adaptly.app://login-callback/';
        debugPrint('[SupabaseAuth] Google OAuth redirectUrl (mobile): $redirectUrl');
      }
      
      // Use inAppWebView mode to automatically close the browser on success
      await SupabaseConfig.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: LaunchMode.inAppWebView,
      );
      
      debugPrint('[SupabaseAuth] OAuth initiated with inAppWebView mode');
      debugPrint('[SupabaseAuth] Browser should close automatically after authentication');
      return null; // Session will be established via deep link callback
    } on AuthException catch (e) {
      debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
      debugPrint('[SupabaseAuth] ✗✗✗ Google Sign-In AuthException ✗✗✗');
      debugPrint('[SupabaseAuth] Message: ${e.message}');
      debugPrint('[SupabaseAuth] Status code: ${e.statusCode}');
      debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
      rethrow;
    } catch (e) {
      debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
      debugPrint('[SupabaseAuth] ✗✗✗ Google Sign-In Error ✗✗✗');
      debugPrint('[SupabaseAuth] Error: $e');
      debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
      rethrow;
    }
  }

  @override
  Future<app.User?> signInWithApple(BuildContext context) async {
    try {
      debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
      debugPrint('[SupabaseAuth] signInWithApple called, isWeb=$kIsWeb');
      debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
      
      if (kIsWeb) {
        // ============ WEB FLOW (uses browser OAuth) ============
        final redirectUrl = buildWebAppEntryUri(Uri.base).toString();
        debugPrint('[SupabaseAuth] Web: Using browser OAuth flow');
        debugPrint('[SupabaseAuth] Web: redirectUrl=$redirectUrl');
        
        await SupabaseConfig.auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: redirectUrl,
        );
        debugPrint('[SupabaseAuth] Web: OAuth redirect initiated');
        return null; // Session will be established via callback
      } else {
        // ============ MOBILE FLOW (iOS/Android - uses native authentication) ============
        // Following the official Supabase docs:
        // https://supabase.com/docs/guides/auth/social-login/auth-apple
        debugPrint('[SupabaseAuth] Mobile: Using NATIVE Apple Sign In');
        
        try {
          // Step 0: Check if Apple Sign-In is available on this device
          debugPrint('[SupabaseAuth] Step 0: Checking if Apple Sign-In is available...');
          debugPrint('[SupabaseAuth] Step 0: Platform check - kIsWeb=$kIsWeb');
          debugPrint('[SupabaseAuth] Step 0: Expected bundle ID: com.Adaptly.app');
          debugPrint('[SupabaseAuth] Step 0: Supabase URL: https://jcxylxmmbstfwiwexovy.supabase.co');
          
          final isAvailable = await SignInWithApple.isAvailable();
          debugPrint('[SupabaseAuth] Step 0: Apple Sign-In available = $isAvailable');
          
          if (!isAvailable) {
            debugPrint('[SupabaseAuth] Step 0: ✗ ERROR - Apple Sign-In not available!');
            debugPrint('[SupabaseAuth]   Common reasons:');
            debugPrint('[SupabaseAuth]   1. Running on iOS Simulator (requires physical device)');
            debugPrint('[SupabaseAuth]   2. iOS version < 13.0 (requires iOS 13+)');
            debugPrint('[SupabaseAuth]   3. Missing entitlements in Xcode project');
            debugPrint('[SupabaseAuth]   4. App not signed with proper provisioning profile');
            debugPrint('[SupabaseAuth]   5. Apple Sign In capability not enabled in App Store Connect');
            throw AuthException('Apple Sign-In is not available on this device.\n\nRequirements:\n• Physical iOS device (not simulator)\n• iOS 13.0 or later\n• Proper app signing\n\nPlease try Email or Google sign-in instead.');
          }
          debugPrint('[SupabaseAuth] Step 0: ✓ Apple Sign-In is available');
          
          // Step 1: Generate nonce for security
          debugPrint('[SupabaseAuth] Step 1: Generating nonce...');
          final rawNonce = SupabaseConfig.auth.generateRawNonce();
          final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
          debugPrint('[SupabaseAuth] Step 1: ✓ Nonce generated');
          
          // Step 2: Show Apple's native authorization sheet
          debugPrint('[SupabaseAuth] Step 2: Requesting Apple credentials (native sheet)...');
          final credential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
            nonce: hashedNonce,
          );
          debugPrint('[SupabaseAuth] Step 2: ✓ Got Apple credentials');
          debugPrint('[SupabaseAuth] Step 2:   identifier=${credential.userIdentifier}');
          debugPrint('[SupabaseAuth] Step 2:   email=${credential.email ?? "(nil)"}');
          debugPrint('[SupabaseAuth] Step 2:   givenName=${credential.givenName ?? "(nil)"}');
          debugPrint('[SupabaseAuth] Step 2:   familyName=${credential.familyName ?? "(nil)"}');
          
          // Step 3: Extract ID token
          debugPrint('[SupabaseAuth] Step 3: Extracting ID token...');
          final idToken = credential.identityToken;
          if (idToken == null || idToken.isEmpty) {
            debugPrint('[SupabaseAuth] Step 3: ✗ ERROR - No identity token!');
            throw AuthException('No identity token received from Apple. Please check your Apple Sign In configuration in Supabase.');
          }
          debugPrint('[SupabaseAuth] Step 3: ✓ ID token received (${idToken.length} chars)');
          
          // Step 4: Sign in to Supabase using the ID token
          // IMPORTANT: Use signInWithIdToken() NOT signInWithOAuth()
          // This exchanges the Apple token for a Supabase session without any browser
          debugPrint('[SupabaseAuth] Step 4: Calling Supabase signInWithIdToken()...');
          debugPrint('[SupabaseAuth] Step 4:   provider=apple, nonce length=${rawNonce.length}, token length=${idToken.length}');
          debugPrint('[SupabaseAuth] Step 4:   Supabase URL: ${SupabaseConfig.supabaseUrl}');
          debugPrint('[SupabaseAuth] Step 4:   This step validates Apple token with Supabase backend...');
          
          final response = await SupabaseConfig.auth.signInWithIdToken(
            provider: OAuthProvider.apple,
            idToken: idToken,
            nonce: rawNonce,
          );
          
          debugPrint('[SupabaseAuth] Step 4: ✓ Supabase API call completed');
          
          if (response.user == null) {
            debugPrint('[SupabaseAuth] Step 4: ✗ ERROR - Supabase returned null user');
            debugPrint('[SupabaseAuth] Step 4:   This usually means Apple provider configuration is incorrect!');
            debugPrint('[SupabaseAuth] Step 4:');
            debugPrint('[SupabaseAuth] Step 4:   ⚠️ REQUIRED CONFIGURATION IN SUPABASE DASHBOARD:');
            debugPrint('[SupabaseAuth] Step 4:   Dashboard → Authentication → Providers → Apple');
            debugPrint('[SupabaseAuth] Step 4:');
            debugPrint('[SupabaseAuth] Step 4:   ✓ Enabled: YES');
            debugPrint('[SupabaseAuth] Step 4:   ✓ Services ID: com.Adaptly.app');
            debugPrint('[SupabaseAuth] Step 4:   ✓ Redirect URL: https://jcxylxmmbstfwiwexovy.supabase.co/auth/v1/callback');
            debugPrint('[SupabaseAuth] Step 4:   ✓ Client ID (Team ID): (from Apple Developer)');
            debugPrint('[SupabaseAuth] Step 4:   ✓ Secret Key: (your .p8 private key)');
            debugPrint('[SupabaseAuth] Step 4:');
            debugPrint('[SupabaseAuth] Step 4:   ⚠️ REQUIRED IN APPLE DEVELOPER CONSOLE:');
            debugPrint('[SupabaseAuth] Step 4:   Services ID: com.Adaptly.app');
            debugPrint('[SupabaseAuth] Step 4:   Return URLs: https://jcxylxmmbstfwiwexovy.supabase.co/auth/v1/callback');
            throw AuthException('❌ Apple Sign-In Configuration Error\n\nSupabase could not authenticate your Apple ID.\n\nPlease verify in Supabase Dashboard:\n• Provider enabled\n• Services ID: com.Adaptly.app\n• Redirect URL: https://jcxylxmmbstfwiwexovy.supabase.co/auth/v1/callback\n• Team ID and Private Key uploaded\n\nCheck app logs for detailed config requirements.');
          }
          
          debugPrint('[SupabaseAuth] Step 4: ✓ Supabase session created');
          debugPrint('[SupabaseAuth] Step 4:   auth_user_id=${response.user!.id}');
          debugPrint('[SupabaseAuth] Step 4:   email=${response.user!.email ?? "(nil)"}');
          
          // Step 5: Build display name from Apple credentials
          String? displayName;
          if (credential.givenName != null || credential.familyName != null) {
            displayName = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
          }
          if (displayName != null && displayName.isNotEmpty) {
            debugPrint('[SupabaseAuth] Step 5: ✓ Display name: "$displayName"');
          } else {
            debugPrint('[SupabaseAuth] Step 5: No display name provided');
          }
          
          // Step 6: Ensure user profile exists in database
          debugPrint('[SupabaseAuth] Step 6: Ensuring user profile...');
          await _ensureOAuthProfile(response.user!, displayName, null);
          debugPrint('[SupabaseAuth] Step 6: ✓ Profile ensured');
          
          // Step 7: Fetch complete user model from database
          debugPrint('[SupabaseAuth] Step 7: Fetching user from database...');
          final user = await _getUserFromDatabase(response.user!.id);
          
          if (user == null) {
            debugPrint('[SupabaseAuth] Step 7: ✗ WARNING - Could not load user from DB!');
            debugPrint('[SupabaseAuth]   This may cause navigation issues.');
            debugPrint('[SupabaseAuth]   Trying to wait and retry...');
            
            // Wait a moment and retry (database might need time to propagate)
            await Future.delayed(const Duration(milliseconds: 500));
            final retryUser = await _getUserFromDatabase(response.user!.id);
            
            if (retryUser != null) {
              debugPrint('[SupabaseAuth] Step 7: ✓ User loaded after retry!');
              debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
              debugPrint('[SupabaseAuth] ✓✓✓ Apple Sign In COMPLETE ✓✓✓');
              debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
              return retryUser;
            }
            
            debugPrint('[SupabaseAuth] Step 7: ✗ Still failed after retry');
            throw AuthException('Failed to create user profile. Please try again.');
          }
          
          debugPrint('[SupabaseAuth] Step 7: ✓ User loaded successfully');
          debugPrint('[SupabaseAuth] Step 7:   profile_id=${user.id}');
          debugPrint('[SupabaseAuth] Step 7:   role=${user.role.value}');
          debugPrint('[SupabaseAuth] Step 7:   email=${user.email}');
          debugPrint('[SupabaseAuth] Step 7:   onboarding=${user.onboardingCompleted}');
          
          debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
          debugPrint('[SupabaseAuth] ✓✓✓ Apple Sign In COMPLETE ✓✓✓');
          debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
          return user;
          
        } on SignInWithAppleAuthorizationException catch (e) {
          debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
          debugPrint('[SupabaseAuth] Apple authorization exception: ${e.code}');
          debugPrint('[SupabaseAuth] Message: ${e.message}');
          debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
          if (e.code == AuthorizationErrorCode.canceled) {
            debugPrint('[SupabaseAuth] User cancelled (normal flow, not an error)');
            return null;
          }
          rethrow;
        }
      }
    } on AuthException catch (e) {
      debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
      debugPrint('[SupabaseAuth] ✗✗✗ Supabase AuthException ✗✗✗');
      debugPrint('[SupabaseAuth] Message: ${e.message}');
      debugPrint('[SupabaseAuth] Status code: ${e.statusCode}');
      debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
      debugPrint('[SupabaseAuth]');
      debugPrint('[SupabaseAuth] 🔍 TROUBLESHOOTING APPLE SIGN-IN:');
      debugPrint('[SupabaseAuth]');
      debugPrint('[SupabaseAuth] If you see "Invalid provider" or "Provider not found":');
      debugPrint('[SupabaseAuth]   → Apple provider not enabled in Supabase Dashboard');
      debugPrint('[SupabaseAuth]');
      debugPrint('[SupabaseAuth] If you see "Invalid credentials" or "Authentication failed":');
      debugPrint('[SupabaseAuth]   → Bundle ID mismatch (Supabase expects: com.Adaptly.app)');
      debugPrint('[SupabaseAuth]   → OR Team ID/Secret Key incorrect in Supabase');
      debugPrint('[SupabaseAuth]   → OR Services ID not configured in Apple Developer Console');
      debugPrint('[SupabaseAuth]');
      debugPrint('[SupabaseAuth] If you see "Redirect URI mismatch":');
      debugPrint('[SupabaseAuth]   → Apple Developer Services ID Return URL must be:');
      debugPrint('[SupabaseAuth]     https://jcxylxmmbstfwiwexovy.supabase.co/auth/v1/callback');
      debugPrint('[SupabaseAuth]');
      debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
      debugPrint('[SupabaseAuth] ✗✗✗ Unexpected error ✗✗✗');
      debugPrint('[SupabaseAuth] Error: $e');
      debugPrint('[SupabaseAuth] Stack trace: $stackTrace');
      debugPrint('[SupabaseAuth] ═══════════════════════════════════════════════════');
      rethrow;
    }
  }

  @override
  Future signOut() async {
    try {
      await SupabaseConfig.auth.signOut();
    } catch (e) {
      debugPrint('SupabaseAuth signOut error: $e');
      rethrow;
    }
  }

  @override
  Future deleteUser(BuildContext context) async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) throw 'No user signed in';

      // Delete user profile (cascade will handle related data)
      await SupabaseConfig.client.from('users').delete().eq('id', user.id);

      // This will also delete the auth user
      // Note: Requires admin privileges or proper RLS policies
      await SupabaseConfig.client.rpc('delete_user');
    } catch (e) {
      debugPrint('SupabaseAuth deleteUser error: $e');
      rethrow;
    }
  }

  @override
  Future updateEmail({
    required String email,
    required BuildContext context,
  }) async {
    try {
      await SupabaseConfig.auth.updateUser(UserAttributes(email: email));

      // Update email in users table
      final user = SupabaseConfig.auth.currentUser;
      if (user != null) {
        await SupabaseConfig.client.from('users').update({
          'email': email,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      }
    } catch (e) {
      debugPrint('SupabaseAuth updateEmail error: $e');
      rethrow;
    }
  }

  @override
  Future resetPassword({
    required String email,
    required BuildContext context,
  }) async {
    try {
      // Call custom API endpoint with partner portal option
      final apiUrl = kIsWeb ? Uri.base.origin : SupabaseConfig.supabaseUrl;
      final response = await http.post(
        Uri.parse('$apiUrl/api/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'portal': 'partner',
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body)['error'] ?? 'Failed to send reset email';
        throw error;
      }
    } catch (e) {
      debugPrint('SupabaseAuth resetPassword error: $e');
      rethrow;
    }
  }

  @override
  Future sendEmailVerification({required app.User user}) async {
    try {
      // Supabase sends verification emails automatically on signup
      // This method can be used to resend if needed
      await SupabaseConfig.auth.resend(
        type: OtpType.signup,
        email: user.email,
      );
    } catch (e) {
      debugPrint('SupabaseAuth sendEmailVerification error: $e');
      rethrow;
    }
  }

  @override
  Future refreshUser({required app.User user}) async {
    try {
      await SupabaseConfig.auth.refreshSession();
    } catch (e) {
      debugPrint('SupabaseAuth refreshUser error: $e');
      rethrow;
    }
  }

  /// Fetch user from database by auth ID
  Future<app.User?> _getUserFromDatabase(String authUserId) async {
    try {
      // Get the last active role from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final lastActiveRole = prefs.getString('last_active_role');
      
      debugPrint('[SupabaseAuth] _getUserFromDatabase: authUserId=$authUserId, lastActiveRole=$lastActiveRole');
      
      // Query for user profile matching auth_user_id
      // If lastActiveRole is set, prefer that role; otherwise get most recent
      final query = SupabaseConfig.client
          .from('users')
          .select()
          .eq('auth_user_id', authUserId);
      
      if (lastActiveRole != null) {
        // Try to get the profile with the last active role
        final data = await query.eq('role', lastActiveRole).maybeSingle();
        
        if (data != null) {
          debugPrint('[SupabaseAuth] Found profile with role=$lastActiveRole');
          return app.User.fromJson({
            'id': data['id'],
            'name': data['name'],
            'email': data['email'],
            'profileImageUrl': data['profile_image_url'],
            'patientCode': data['patient_code'],
            'role': data['role'],
            'onboardingCompleted': data['onboarding_completed'] ?? false,
            'conditions': data['conditions'] ?? [],
            'diagnosisDate': data['diagnosis_date'],
            'interests': data['interests'] ?? [],
            'preferences': data['preferences'] ?? {},
            'createdAt': data['created_at'],
            'updatedAt': data['updated_at'],
          });
        }
      }
      
      // If no lastActiveRole or profile not found, get the most recently updated profile
      debugPrint('[SupabaseAuth] No profile found with lastActiveRole, fetching most recent');
      final profiles = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('auth_user_id', authUserId)
          .order('updated_at', ascending: false);
      
      if (profiles.isEmpty) {
        debugPrint('[SupabaseAuth] No profiles found for authUserId=$authUserId');
        return null;
      }
      
      final data = profiles.first;
      debugPrint('[SupabaseAuth] Using most recent profile with role=${data['role']}');
      
      return app.User.fromJson({
        'id': data['id'],
        'name': data['name'],
        'email': data['email'],
        'profileImageUrl': data['profile_image_url'],
        'patientCode': data['patient_code'],
        'role': data['role'],
        'onboardingCompleted': data['onboarding_completed'] ?? false,
        'conditions': data['conditions'] ?? [],
        'diagnosisDate': data['diagnosis_date'],
        'interests': data['interests'] ?? [],
        'preferences': data['preferences'] ?? {},
        'createdAt': data['created_at'],
        'updatedAt': data['updated_at'],
      });
    } catch (e) {
      debugPrint('SupabaseAuth _getUserFromDatabase error: $e');
      return null;
    }
  }

  /// Get current authenticated user
  Future<app.User?> getCurrentUser() async {
    try {
      final authUser = SupabaseConfig.auth.currentUser;
      if (authUser == null) return null;

      return await _getUserFromDatabase(authUser.id);
    } catch (e) {
      debugPrint('SupabaseAuth getCurrentUser error: $e');
      return null;
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated => SupabaseConfig.auth.currentUser != null;

  /// Get auth state changes stream
  Stream<AuthState> get authStateChanges => SupabaseConfig.auth.onAuthStateChange;

  /// Ensure OAuth profile exists with correct role (for native auth)
  Future<void> _ensureOAuthProfile(User authUser, String? displayName, String? photoUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingRole = prefs.getString('pending_oauth_role');
      
      if (pendingRole == null) {
        debugPrint('[SupabaseAuth] No pending_oauth_role found, checking for existing profile');
        // If no pending role, try to find any existing profile for this user
        final existingProfiles = await SupabaseConfig.client
            .from('users')
            .select('id, role, updated_at')
            .eq('auth_user_id', authUser.id)
            .order('updated_at', ascending: false);
        
        if (existingProfiles.isNotEmpty) {
          // Use the most recently updated profile
          final mostRecent = existingProfiles.first;
          await prefs.setString('last_active_role', mostRecent['role']);
          debugPrint('[SupabaseAuth] Using existing profile with role: ${mostRecent['role']}');
          return;
        }
        
        // No existing profile and no pending role - create default patient profile
        debugPrint('[SupabaseAuth] No profile found, creating default patient profile');
        final now = DateTime.now();
        final nameFromEmail = authUser.email?.split('@').first ?? 'User';
        
        await SupabaseConfig.client.from('users').insert({
          'auth_user_id': authUser.id,
          'name': displayName ?? authUser.userMetadata?['full_name'] ?? authUser.userMetadata?['name'] ?? nameFromEmail,
          'email': authUser.email ?? 'user-${authUser.id}@adaptly.app',
          'role': 'patient',
          'profile_image_url': photoUrl ?? authUser.userMetadata?['avatar_url'] ?? authUser.userMetadata?['picture'],
          'onboarding_completed': false,
          'conditions': [],
          'interests': [],
          'preferences': {},
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
        
        await prefs.setString('last_active_role', 'patient');
        debugPrint('[SupabaseAuth] Created default patient profile');
        return;
      }
      
      debugPrint('[SupabaseAuth] Found pending_oauth_role: $pendingRole');
      
      final role = pendingRole == 'family' ? app.UserRole.family : app.UserRole.patient;
      
      // Check if a profile with this role already exists
      final existingProfile = await SupabaseConfig.client
          .from('users')
          .select('id')
          .eq('auth_user_id', authUser.id)
          .eq('role', role.value)
          .maybeSingle();
      
      if (existingProfile == null) {
        debugPrint('[SupabaseAuth] Creating new ${role.value} profile for OAuth user');
        
        final nameFromEmail = authUser.email?.split('@').first ?? 'User';
        final now = DateTime.now();
        
        await SupabaseConfig.client.from('users').insert({
          'auth_user_id': authUser.id,
          'name': displayName ?? authUser.userMetadata?['full_name'] ?? authUser.userMetadata?['name'] ?? nameFromEmail,
          'email': authUser.email ?? 'user-${authUser.id}@adaptly.app',
          'role': role.value,
          'profile_image_url': photoUrl ?? authUser.userMetadata?['avatar_url'] ?? authUser.userMetadata?['picture'],
          'onboarding_completed': false,
          'conditions': [],
          'interests': [],
          'preferences': {},
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
        
        debugPrint('[SupabaseAuth] Profile created successfully');
      } else {
        debugPrint('[SupabaseAuth] Profile already exists, updating timestamp');
        
        // Update the existing profile's timestamp to mark it as recently active
        await SupabaseConfig.client
            .from('users')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', existingProfile['id']);
      }
      
      // Save this role as the active role
      await prefs.setString('last_active_role', role.value);
      debugPrint('[SupabaseAuth] Set last_active_role to ${role.value}');
      
      // Clear the pending role
      await prefs.remove('pending_oauth_role');
      debugPrint('[SupabaseAuth] Cleared pending_oauth_role');
      
    } catch (e) {
      debugPrint('[SupabaseAuth] Error ensuring OAuth profile: $e');
      // Don't rethrow - let the auth flow continue even if profile creation fails
    }
  }
}
