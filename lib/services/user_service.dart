import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:wellspring/models/user.dart' as models;
import 'package:wellspring/services/achievement_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/utils/web_entry_uri.dart';
import 'package:wellspring/auth/supabase_auth_manager.dart';

class UserService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final AchievementService _achievements = AchievementService();
  static const String _onboardingKey = 'onboarding_completed';
  static const String _prefHasSeenTutorial = 'hasSeenTutorial';
  static const String _prefLocation = 'location';
  static const String _prefHospitalId = 'hospitalId';
  static const String _prefMfaPrefix = 'mfa_verified_';
  
  /// Get the web portal URL dynamically based on platform
  /// For web: uses current origin
  /// For mobile: uses Supabase URL
  static String get _webPortalUrl {
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return SupabaseConfig.supabaseUrl;
  }

  static models.User? _cachedUser;
  static DateTime? _cachedAt;
  static bool? _cachedOnboarding;
  static DateTime? _cachedOnboardingAt;
  static String? _cachedOnboardingUserId;
  static String? _cachedOnboardingRole;
  static String? _mfaVerifiedUserId;

  Future<void> signInWithEmail({
    required String email,
    required String password,
    models.UserRole? role,
  }) async {
    try {
      await _resetMfaVerification();
      await _supabase.auth.signInWithPassword(email: email, password: password);
      
      // If role is specified, save it as the last active role and touch the profile
      if (role != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_active_role', role.value);
        debugPrint('UserService.signInWithEmail: Saved last_active_role=${role.value}');
        
        // Clear the cached user so getCurrentUser() will reload with the new role
        _cachedUser = null;
        _cachedAt = null;
        debugPrint('UserService.signInWithEmail: Cleared user cache to force reload');
        
        // Update the profile's updated_at to mark it as recently active
        final authUser = _supabase.auth.currentUser;
        if (authUser != null) {
          try {
            await _supabase
                .from('users')
                .update({'updated_at': DateTime.now().toIso8601String()})
                .eq('auth_user_id', authUser.id)
                .eq('role', role.value);
            debugPrint('UserService.signInWithEmail: Updated profile timestamp for role=${role.value}');
          } catch (updateError) {
            debugPrint('UserService.signInWithEmail: Failed to update profile timestamp (non-fatal): $updateError');
          }
        }
      }
    } on AuthException catch (e) {
      debugPrint('UserService.signInWithEmail error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('UserService.signInWithEmail unknown error: $e');
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      debugPrint('[UserService] signInWithGoogle: Starting...');
      await _resetMfaVerification();
      final url = _oauthRedirectTo();
      debugPrint('[UserService] signInWithGoogle: redirectTo URL = $url');
      debugPrint('[UserService] signInWithGoogle: Calling auth.signInWithOAuth...');
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: url,
      );
      debugPrint('[UserService] signInWithGoogle: signInWithOAuth completed (should have redirected on web)');
    } on AuthException catch (e) {
      debugPrint('[UserService] signInWithGoogle AuthException: ${e.message} (statusCode: ${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[UserService] signInWithGoogle unknown error: $e');
      rethrow;
    }
  }

  Future<models.User?> signInWithApple(dynamic context) async {
    try {
      await _resetMfaVerification();
      // Use SupabaseAuthManager which handles native Apple Sign-In on iOS
      // Returns the user directly without any browser redirect
      final auth = SupabaseAuthManager();
      final user = await auth.signInWithApple(context);
      return user;
    } on AuthException catch (e) {
      debugPrint('UserService.signInWithApple error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('UserService.signInWithApple unknown error: $e');
      rethrow;
    }
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
    models.UserRole role = models.UserRole.patient,
  }) async {
    try {
      await _resetMfaVerification();
      debugPrint('UserService: Starting signUp for $email with role: ${role.value}');
      
      // Try to sign up (for new emails) or sign in (for existing auth users creating a second profile)
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: _emailRedirectTo(),
      );
      debugPrint('UserService: signUp response - user: ${response.user?.id}, session: ${response.session != null}');
      
      // If signup returns a user but no session, email exists. Try to sign in.
      if (response.user != null && response.session == null) {
        debugPrint('UserService: signUp returned user but no session. Attempting sign-in.');
        try {
          final signInResponse = await _supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
          if (signInResponse.user == null) {
            throw AuthException('Email confirmation may be required. Please check your inbox.');
          }
          debugPrint('UserService: Signed in successfully');
        } catch (signInError) {
          debugPrint('UserService: Sign-in failed: $signInError');
          // Check if it's an email confirmation error
          if (signInError is AuthException && 
              signInError.message.toLowerCase().contains('email not confirmed')) {
            // Email confirmation required - return gracefully, don't throw
            // The sign-in screen will detect no session and show the confirmation message
            debugPrint('UserService: Email confirmation required, returning gracefully');
            return;
          }
          // Check if it's an invalid credentials error (wrong password for existing account)
          if (signInError is AuthException && 
              (signInError.message.toLowerCase().contains('invalid login credentials') ||
               signInError.message.toLowerCase().contains('invalid credentials'))) {
            throw AuthException('This email already has an account. Please use "Sign In" with your existing password to add a ${role.value} profile.');
          }
          throw AuthException('This email already exists. Please use "Sign In" to continue.');
        }
      }
      // If signup returns null user, something else went wrong
      else if (response.user == null) {
        debugPrint('UserService: signUp returned null user, unexpected error');
        throw Exception('Failed to create account. Please try again or contact support.');
      }

      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        throw Exception('Failed to retrieve authenticated user after sign up/sign in');
      }

      // CRITICAL: Set last_active_role FIRST before any async database operations
      // This ensures that if the router calls getCurrentUser() during registration,
      // it will look for the correct role instead of falling back to patient
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_active_role', role.value);
      debugPrint('UserService.registerWithEmail: Set last_active_role to ${role.value} BEFORE profile check');
      
      // Clear caches immediately so getCurrentUser() will fetch fresh data with the new role
      _cachedUser = null;
      _cachedAt = null;
      _cachedOnboarding = null;
      _cachedOnboardingAt = null;
      _cachedOnboardingUserId = null;
      _cachedOnboardingRole = null;
      debugPrint('UserService.registerWithEmail: Cleared all caches to force reload with role=${role.value}');

      // Check if this auth user already has a profile with this role
      final existingProfile = await _supabase
          .from('users')
          .select('id, role')
          .eq('auth_user_id', authUser.id)
          .eq('role', role.value)
          .maybeSingle();

      if (existingProfile != null) {
        debugPrint('UserService: Auth user ${authUser.id} already has a ${role.value} profile. Registration complete (existing profile).');
        return;
      }

      final nameFromEmail = displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : email.split('@').first;

      final now = DateTime.now();
      
      // Check if this is their first profile
      final existingProfiles = await _supabase
          .from('users')
          .select('id')
          .eq('auth_user_id', authUser.id)
          .limit(1);
      
      // Generate profile ID: use auth ID for first profile, new UUID for additional profiles
      final isFirstProfile = existingProfiles.isEmpty;
      final profileId = isFirstProfile ? authUser.id : const Uuid().v4();
      
      debugPrint('UserService: Inserting user profile (auth_user_id=${authUser.id}, role=${role.value}, profile_id=$profileId, is_first=$isFirstProfile)');
      try {
        await _supabase.from('users').insert({
          'id': profileId,
          'auth_user_id': authUser.id,
          'name': nameFromEmail,
          'email': email,
          'role': role.value,
          'onboarding_completed': false,
          'conditions': [],
          'interests': [],
          'preferences': {},
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
        debugPrint('UserService: User profile inserted successfully with id=$profileId for role=${role.value}');
      } catch (insertError) {
        debugPrint('UserService: Failed to insert user profile: $insertError');
        rethrow;
      }

      // Initialize achievements for the auth user (only once)
      try {
        final hasAchievements = await _supabase
            .from('user_achievements')
            .select('user_id')
            .eq('user_id', authUser.id)
            .limit(1);
        
        if (hasAchievements.isEmpty) {
          await _achievements.initializeAchievementsForUser(authUser.id);
          debugPrint('UserService: Achievements initialized');
        }
      } catch (achError) {
        debugPrint('UserService: Failed to initialize achievements (non-fatal): $achError');
      }
    } on AuthException catch (e) {
      debugPrint('UserService.registerWithEmail AuthException: ${e.message} (code: ${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('UserService.registerWithEmail unknown error: $e');
      rethrow;
    }
  }


  Future<void> sendSmsCode({required String phoneNumber}) async {
    final normalized = _normalizePhone(phoneNumber);
    if (normalized.isEmpty) {
      throw AuthException('Enter a valid phone number with country code.');
    }

    try {
      await _supabase.auth.signInWithOtp(
        phone: normalized,
        channel: OtpChannel.sms,
      );
    } on AuthException catch (e) {
      debugPrint('UserService.sendSmsCode error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('UserService.sendSmsCode unknown error: $e');
      rethrow;
    }
  }

  Future<bool> verifySmsCode({
    required String phoneNumber,
    required String smsCode,
  }) async {
    final normalized = _normalizePhone(phoneNumber);
    final code = smsCode.trim();
    if (normalized.isEmpty) {
      throw AuthException('Enter a valid phone number with country code.');
    }
    if (code.isEmpty) {
      throw AuthException('Enter the code we sent you.');
    }

    try {
      final response = await _supabase.auth.verifyOTP(
        phone: normalized,
        token: code,
        type: OtpType.sms,
      );

      final authUser = response.user ?? _supabase.auth.currentUser;
      if (authUser == null) {
        throw AuthException('Verification failed. Try again.');
      }

      final createdProfile = await _ensureProfileForPhoneUser(
        authUser,
        phoneNumber: normalized,
      );
      await _markMfaVerifiedForSession();
      return createdProfile;
    } on AuthException catch (e) {
      debugPrint('UserService.verifySmsCode error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('UserService.verifySmsCode unknown error: $e');
      rethrow;
    }
  }

  Future<void> startSmsMfa({required String phoneNumber}) async {
    final normalized = _normalizePhone(phoneNumber);
    if (normalized.isEmpty) {
      throw AuthException('Enter a valid phone number with country code.');
    }

    try {
      await _resetMfaVerification();
      await _supabase.auth.updateUser(UserAttributes(phone: normalized));
    } on AuthException catch (e) {
      debugPrint('UserService.startSmsMfa error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('UserService.startSmsMfa unknown error: $e');
      rethrow;
    }
  }

  Future<void> verifySmsMfa({
    required String phoneNumber,
    required String smsCode,
  }) async {
    final normalized = _normalizePhone(phoneNumber);
    final code = smsCode.trim();
    if (normalized.isEmpty) {
      throw AuthException('Enter a valid phone number with country code.');
    }
    if (code.isEmpty) {
      throw AuthException('Enter the code we sent you.');
    }

    try {
      final response = await _supabase.auth.verifyOTP(
        phone: normalized,
        token: code,
        type: OtpType.sms,
      );

      final user = response.user ?? _supabase.auth.currentUser;
      if (user == null) {
        throw AuthException('Verification failed. Try again.');
      }

      await _storePhonePreference(normalized);
      await _markMfaVerifiedForSession();
    } on AuthException catch (e) {
      debugPrint('UserService.verifySmsMfa error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('UserService.verifySmsMfa unknown error: $e');
      rethrow;
    }
  }

  Future<void> startEmailMfa() async {
    final email = _supabase.auth.currentUser?.email?.trim() ?? '';
    if (email.isEmpty) {
      throw AuthException('Sign in with an email account to verify by email.');
    }

    await _resetMfaVerification();

    // Prefer reauthenticate() (Supabase's "reauthentication" template) when the
    // client SDK supports verifying that OTP type.
    //
    // Note: Some versions of supabase_flutter do NOT expose a reauthentication
    // OtpType in the Dart enum. In that case, the code can be sent but cannot be
    // verified via `verifyOTP(type: ...)` reliably.
    //
    // When that happens, we fall back to sending a standard Email OTP (still a
    // numeric code) via signInWithOtp(shouldCreateUser: false).
    final reauthType = _findOtpTypeByNames(['reauthentication', 'reauthenticate']);
    debugPrint(
        'UserService.startEmailMfa: Sending email OTP. preferReauth=${reauthType != null} email=$email');
    try {
      if (reauthType != null) {
        await _supabase.auth.reauthenticate();
        debugPrint('UserService.startEmailMfa: Reauthentication OTP sent successfully');
      } else {
        await _supabase.auth.signInWithOtp(
          email: email,
          shouldCreateUser: false,
          emailRedirectTo: _emailRedirectTo(),
        );
        debugPrint('UserService.startEmailMfa: Email OTP sent via signInWithOtp (fallback)');
      }
    } on AuthException catch (e) {
      debugPrint('UserService.startEmailMfa error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('UserService.startEmailMfa unknown error: $e');
      rethrow;
    }
  }


  Future<void> verifyEmailMfa({required String emailCode}) async {
    final email = _supabase.auth.currentUser?.email?.trim() ?? '';
    final sanitized = emailCode.replaceAll(RegExp(r'[^0-9]'), '').trim();

    if (email.isEmpty) {
      throw AuthException('Sign in with an email account to verify by email.');
    }
    if (sanitized.isEmpty) {
      throw AuthException('Enter the verification code.');
    }

    debugPrint('UserService.verifyEmailMfa: Verifying email code for $email');
    debugPrint('UserService.verifyEmailMfa: Code length=${sanitized.length}, code=$sanitized');

    // Try multiple OTP types because different Supabase auth configurations
    // can label the same numeric code differently (email, magiclink, etc.).
    //
    // IMPORTANT: Some SDK versions do not include a reauthentication OtpType.
    // In that case we still try ALL known OtpType values to maximize success.
    final ordered = <OtpType>[];
    void add(OtpType? t) {
      if (t != null && !ordered.contains(t)) ordered.add(t);
    }

    // Most common for code-based email OTP.
    add(_findOtpTypeByNames(['email']));
    add(_findOtpTypeByNames(['magiclink', 'magic_link']));
    add(_findOtpTypeByNames(['reauthentication', 'reauthenticate']));
    add(_findOtpTypeByNames(['recovery']));
    add(_findOtpTypeByNames(['signup']));
    add(_findOtpTypeByNames(['invite']));

    // Finally, try anything else the SDK exposes.
    for (final t in OtpType.values) {
      add(t);
    }

    final typesToTry = List<OtpType>.unmodifiable(ordered);
    
    AuthException? lastError;
    
    for (final type in typesToTry) {
      try {
        debugPrint('UserService.verifyEmailMfa: Attempting with type=${type.toString()}');
        final response = await _supabase.auth.verifyOTP(
          email: email,
          token: sanitized,
          type: type,
        );

        final user = response.user ?? _supabase.auth.currentUser;
        if (user == null) {
          throw AuthException('Verification failed. Try again.');
        }

        debugPrint('UserService.verifyEmailMfa: Verification successful with type=${type.toString()}');
        await _markMfaVerifiedForSession();
        return;
      } on AuthException catch (e) {
        lastError = e;
        debugPrint('UserService.verifyEmailMfa: Failed with type=${type.toString()}, error=${e.message}');
        // Continue to next type
      } catch (e) {
        lastError = AuthException('Verification failed: $e');
        debugPrint('UserService.verifyEmailMfa: Unknown error with type=${type.toString()}, error=$e');
        // Continue to next type
      }
    }

    // All attempts failed
    debugPrint('UserService.verifyEmailMfa: All verification attempts failed');
    if (lastError != null) {
      throw _mapOtpError(lastError);
    }
    throw AuthException('Verification failed. Try again.');
  }

  Future<void> skipSmsMfaForSession() async {
    await _markMfaVerifiedForSession();
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      debugPrint('UserService.sendPasswordReset called with email: $email');
      
      // Call the custom password reset API endpoint with 'partner' portal
      final url = Uri.parse('$_webPortalUrl/api/reset-password');
      debugPrint('UserService.sendPasswordReset: Calling API at $url');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'portal': 'partner',
        }),
      );
      
      debugPrint('UserService.sendPasswordReset: Response status=${response.statusCode}');
      
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Failed to send password reset email');
      }
      
      debugPrint('UserService.sendPasswordReset completed successfully');
    } catch (e) {
      debugPrint('UserService.sendPasswordReset error: $e');
      rethrow;
    }
  }

  /// Get current Supabase session (null if not authenticated or email not confirmed)
  Future<Session?> getCurrentSession() async {
    try {
      final session = _supabase.auth.currentSession;
      return session;
    } catch (e) {
      debugPrint('UserService.getCurrentSession error: $e');
      return null;
    }
  }

  Future<models.User?> getCurrentUser() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return null;

      // Check SharedPreferences FIRST to see if the role has changed
      // First check pending_oauth_role (saved before OAuth redirect), then last_active_role
      final prefs = await SharedPreferences.getInstance();
      final pendingRole = prefs.getString('pending_oauth_role');
      final lastActiveRole = pendingRole ?? prefs.getString('last_active_role');
      
      // CRITICAL: If there's a pending OAuth role, save it as last_active_role IMMEDIATELY
      // before any profile queries, so all code uses the correct role
      if (pendingRole != null) {
        await prefs.setString('last_active_role', pendingRole);
        await prefs.remove('pending_oauth_role');
        debugPrint('UserService.getCurrentUser: Saved pending OAuth role as last_active_role: $pendingRole');
      }

      // Return cached user if still fresh AND role hasn't changed
      if (_cachedUser != null && _cachedAt != null) {
        final age = DateTime.now().difference(_cachedAt!);
        final roleMatches = lastActiveRole == null || _cachedUser!.role.value == lastActiveRole;
        if (age.inSeconds < 30 && roleMatches) {
          return _cachedUser;
        }
        if (!roleMatches) {
          debugPrint('UserService.getCurrentUser: Role changed from ${_cachedUser!.role.value} to $lastActiveRole, invalidating cache');
        }
      }

      // With the new auth_user_id schema, one auth user can have multiple profiles
      // Load all profiles for this auth user
      final profiles = await _supabase
          .from('users')
          .select()
          .eq('auth_user_id', authUser.id)
          .order('updated_at', ascending: false); // Most recently active first

      if (profiles.isEmpty) {
        // Fallback: Try loading by id (backwards compatibility)
        final legacyProfile = await _supabase
            .from('users')
            .select()
            .eq('id', authUser.id)
            .maybeSingle();

        if (legacyProfile != null) {
          final u = _userFromMap(legacyProfile);
          _cachedUser = u;
          _cachedAt = DateTime.now();
          return u;
        }

        // If no profile exists, create one
        final provisioned = await _provisionMissingUser(authUser);
        if (provisioned != null) {
          _cachedUser = provisioned;
          _cachedAt = DateTime.now();
          return provisioned;
        }
        return null;
      }

      // Multiple profiles exist - determine which one to use
      // Priority: 1. Last active role from SharedPreferences, 2. Most recently updated
      
      models.User? selectedProfile;
      if (lastActiveRole != null) {
        // Try to find the profile matching the last active role
        debugPrint('UserService.getCurrentUser: Looking for profile with role=$lastActiveRole');
        try {
          selectedProfile = profiles
              .map((data) => _userFromMap(data))
              .firstWhere((u) => u.role.value == lastActiveRole);
          debugPrint('UserService.getCurrentUser: Selected profile role=${selectedProfile.role.value}');
        } catch (e) {
          // Profile with requested role doesn't exist yet
          // It might be in the process of being created by registerWithEmail()
          // Wait a moment and retry the query before provisioning
          debugPrint('UserService.getCurrentUser: No profile found for role=$lastActiveRole, waiting 500ms then retrying...');
          await Future.delayed(const Duration(milliseconds: 500));
          
          final retryProfiles = await _supabase
              .from('users')
              .select()
              .eq('auth_user_id', authUser.id)
              .eq('role', lastActiveRole)
              .maybeSingle();
          
          if (retryProfiles != null) {
            debugPrint('UserService.getCurrentUser: Found $lastActiveRole profile after retry!');
            selectedProfile = _userFromMap(retryProfiles);
          } else {
            // Still not found - provision it
            debugPrint('UserService.getCurrentUser: Still not found after retry, provisioning new profile');
            final provisioned = await _provisionMissingProfile(
              authUser,
              role: models.UserRole.values.firstWhere(
                (r) => r.value == lastActiveRole,
                orElse: () => models.UserRole.patient,
              ),
            );
            if (provisioned != null) {
              _cachedUser = provisioned;
              _cachedAt = DateTime.now();
              await prefs.setString('last_active_role', provisioned.role.value);
              return provisioned;
            }
            // If provisioning failed, fall back to first profile
            debugPrint('UserService.getCurrentUser: Failed to provision $lastActiveRole profile, using first profile');
            selectedProfile = _userFromMap(profiles.first);
          }
        }
      } else {
        // Default to most recently updated profile
        debugPrint('UserService.getCurrentUser: No last_active_role, using most recent profile');
        selectedProfile = _userFromMap(profiles.first);
        debugPrint('UserService.getCurrentUser: Selected profile role=${selectedProfile.role.value}');
      }

      _cachedUser = selectedProfile;
      _cachedAt = DateTime.now();
      
      // Save the active role for next time
      await prefs.setString('last_active_role', selectedProfile.role.value);
      
      return selectedProfile;
    } catch (e) {
      debugPrint('UserService.getCurrentUser error: $e');
    }
    return null;
  }

  Future<models.User?> getUserById(String userId) async {
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data != null) {
        return _userFromMap(data);
      }
    } catch (e) {
      debugPrint('UserService.getUserById error: $e');
    }
    return null;
  }

  Future<void> saveUser(models.User user) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        throw Exception('Not authenticated');
      }

      final data = {
        'id': user.id,
        'auth_user_id': authUser.id, // CRITICAL: Always include auth_user_id for upsert
        'role': user.role.value, // CRITICAL: Always include role for multi-profile support
        'name': user.name,
        'email': user.email,
        'profile_image_url': user.profileImageUrl,
        'patient_code': user.patientCode,
        'onboarding_completed': user.onboardingCompleted,
        'conditions': user.conditions,
        'diagnosis_date': user.diagnosisDate?.toIso8601String(),
        'interests': user.interests,
        'medications': user.medications.map((m) => m.toJson()).toList(),
        'preferences': user.preferences,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('users').upsert(data);

      if (_cachedUser != null && _cachedUser!.id == user.id) {
        _cachedUser = user;
        _cachedAt = DateTime.now();
      }
    } catch (e) {
      debugPrint('UserService.saveUser error: $e');
      rethrow;
    }
  }

  Future<void> updateUserProfile({
    String? name,
    String? email,
    String? profileImageUrl,
  }) async {
    try {
      final user = await getCurrentUser();
      if (user != null) {
        final updatedUser = user.copyWith(
          name: name,
          email: email,
          profileImageUrl: profileImageUrl,
        );
        await saveUser(updatedUser);
      }
    } catch (e) {
      debugPrint('UserService.updateUserProfile error: $e');
      rethrow;
    }
  }

  Future<void> updateConditions(List<String> conditions) async {
    try {
      final user = await getCurrentUser();
      if (user != null) {
        final updatedUser = user.copyWith(conditions: conditions);
        await saveUser(updatedUser);
      }
    } catch (e) {
      debugPrint('UserService.updateConditions error: $e');
      rethrow;
    }
  }

  Future<void> updatePreferences(Map<String, dynamic> preferences) async {
    try {
      final user = await getCurrentUser();
      if (user != null) {
        final updatedUser = user.copyWith(preferences: preferences);
        await saveUser(updatedUser);
      }
    } catch (e) {
      debugPrint('UserService.updatePreferences error: $e');
      rethrow;
    }
  }

  Future<bool> isOnboardingCompleted() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return false;

      // Get the current role to check the right profile's onboarding status
      final prefs = await SharedPreferences.getInstance();
      final lastActiveRole = prefs.getString('last_active_role') ?? 'patient';
      
      if (_cachedOnboarding != null &&
          _cachedOnboardingAt != null &&
          _cachedOnboardingUserId == authUser.id &&
          _cachedOnboardingRole == lastActiveRole) {
        final age = DateTime.now().difference(_cachedOnboardingAt!);
        if (age.inSeconds < 30) {
          debugPrint('UserService.isOnboardingCompleted: Using cache for role=$lastActiveRole, value=$_cachedOnboarding');
          return _cachedOnboarding!;
        }
      }

      // Reset cache when switching accounts or roles
      if (_cachedOnboardingUserId != authUser.id || _cachedOnboardingRole != lastActiveRole) {
        debugPrint('UserService.isOnboardingCompleted: Cache invalidated (userId changed or role changed to $lastActiveRole)');
        _cachedOnboarding = null;
        _cachedOnboardingAt = null;
        _cachedOnboardingUserId = authUser.id;
        _cachedOnboardingRole = lastActiveRole;
      }

      // Query for the specific profile by auth_user_id AND role
      final data = await _supabase
          .from('users')
          .select('id, onboarding_completed, preferences, conditions, diagnosis_date, role')
          .eq('auth_user_id', authUser.id)
          .eq('role', lastActiveRole)
          .maybeSingle();
      
      debugPrint('UserService.isOnboardingCompleted: Queried for role=$lastActiveRole, data=${data != null ? "found" : "not found"}');

      if (data != null) {
        final userRole = data['role'] as String?;
        final isFamilyUser = userRole == 'family';
        final userId = data['id'] as String;
        
        final prefs = (data['preferences'] as Map<String, dynamic>?) ?? {};
        final hospitalId = (prefs[_prefHospitalId] as String?)?.trim();
        final organizationId = (prefs['organizationId'] as String?)?.trim();
        final conditions = (data['conditions'] as List?)?.cast<String>() ?? [];
        final hasDiagnosisDate = data['diagnosis_date'] != null;
        final hasOrganization = (organizationId != null && organizationId.isNotEmpty) || 
                               (hospitalId != null && hospitalId.isNotEmpty);
        final looksComplete = hasOrganization &&
            (conditions.isNotEmpty || hasDiagnosisDate);
        final looksEmptyProfile = !hasOrganization &&
            conditions.isEmpty &&
            !hasDiagnosisDate;

        // SPECIAL CHECK FOR FAMILY USERS: Check if they have existing patient connections from partner web OR local storage
        if (isFamilyUser) {
          debugPrint('UserService.isOnboardingCompleted: Checking for existing patient connections...');
          
          // FIRST: Check local storage connections (mobile app connections)
          try {
            final localPrefs = await SharedPreferences.getInstance();
            final connectionsJson = localPrefs.getString('patient_connections');
            if (connectionsJson != null && connectionsJson.isNotEmpty) {
              final List<dynamic> connectionsList = jsonDecode(connectionsJson);
              final userConnections = connectionsList
                  .where((c) => c['familyMemberId'] == userId && (c['isActive'] ?? true))
                  .toList();
              
              if (userConnections.isNotEmpty) {
                debugPrint('UserService.isOnboardingCompleted: ✓ Found ${userConnections.length} existing connections in local storage!');
                debugPrint('UserService.isOnboardingCompleted: → Auto-completing onboarding for returning family user');
                
                // Auto-complete their onboarding since they're already connected
                await _supabase
                    .from('users')
                    .update({'onboarding_completed': true})
                    .eq('id', userId);
                
                _cachedOnboarding = true;
                _cachedOnboardingAt = DateTime.now();
                _cachedOnboardingUserId = authUser.id;
                _cachedOnboardingRole = lastActiveRole;
                return true;
              }
            }
          } catch (e) {
            debugPrint('UserService.isOnboardingCompleted: Error checking local connections: $e');
          }
          
          // SECOND: Check family_patient_links table (partner web portal connections)
          try {
            // First, get the family_member.id by looking up via auth_user_id
            final familyMemberData = await _supabase
                .from('family_members')
                .select('id')
                .eq('auth_user_id', authUser.id)
                .maybeSingle();
            
            if (familyMemberData != null) {
              final familyMemberId = familyMemberData['id'] as String;
              debugPrint('UserService.isOnboardingCompleted: Found family_member record: $familyMemberId');
              
              // Check if they have any patient links
              final links = await _supabase
                  .from('family_patient_links')
                  .select('id, patient_id')
                  .eq('family_member_id', familyMemberId)
                  .limit(1);
              
              if (links.isNotEmpty) {
                debugPrint('UserService.isOnboardingCompleted: ✓ Found existing patient connection from partner web!');
                debugPrint('UserService.isOnboardingCompleted: → Auto-completing onboarding for family user');
                
                // Auto-complete their onboarding since they're already connected
                await _supabase
                    .from('users')
                    .update({'onboarding_completed': true})
                    .eq('id', userId);
                
                _cachedOnboarding = true;
                _cachedOnboardingAt = DateTime.now();
                _cachedOnboardingUserId = authUser.id;
                _cachedOnboardingRole = lastActiveRole;
                return true;
              } else {
                debugPrint('UserService.isOnboardingCompleted: No patient connections found in Supabase');
              }
            } else {
              debugPrint('UserService.isOnboardingCompleted: No family_member record found');
            }
          } catch (e) {
            debugPrint('UserService.isOnboardingCompleted: Error checking family_patient_links: $e');
          }
        }

        final serverFlag = data['onboarding_completed'] as bool?;
        if (serverFlag != null) {
          // Family users don't need conditions/diagnosis to complete onboarding
          // They only need to connect to a patient, which is validated elsewhere
          final effective = isFamilyUser ? serverFlag : (serverFlag && !looksEmptyProfile);
          _cachedOnboarding = effective;
          _cachedOnboardingAt = DateTime.now();
          _cachedOnboardingUserId = authUser.id;
          _cachedOnboardingRole = lastActiveRole;
          debugPrint('UserService.isOnboardingCompleted: Server flag for role=$lastActiveRole is $effective (isFamilyUser=$isFamilyUser)');
          return effective;
        }

        if (looksComplete) {
          _cachedOnboarding = true;
          _cachedOnboardingAt = DateTime.now();
          _cachedOnboardingUserId = authUser.id;
          _cachedOnboardingRole = lastActiveRole;
          debugPrint('UserService.isOnboardingCompleted: Profile looks complete for role=$lastActiveRole');
          return true;
        }
      }

      // Profile not found or onboarding not complete
      debugPrint('UserService.isOnboardingCompleted: No data found for role=$lastActiveRole, returning false');
      _cachedOnboarding = false;
      _cachedOnboardingAt = DateTime.now();
      _cachedOnboardingUserId = authUser.id;
      _cachedOnboardingRole = lastActiveRole;
      return false;
    } catch (e) {
      debugPrint('UserService.isOnboardingCompleted error: $e');
      return false;
    }
  }

  Future<void> completeOnboarding(models.User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, true);

      final doc = user.copyWith(onboardingCompleted: true);
      await saveUser(doc);

      _cachedOnboarding = true;
      _cachedOnboardingAt = DateTime.now();
      _cachedOnboardingUserId = user.id;

      await _trackMembershipMilestones(user.id);
    } catch (e) {
      debugPrint('UserService.completeOnboarding error: $e');
      rethrow;
    }
  }

  Future<String?> ensurePatientCodeForCurrentUser({String? hospitalId, String? organizationId}) async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) return null;
    
    // Use organizationId if provided, otherwise fall back to hospitalId
    final entityId = organizationId ?? hospitalId;
    if (entityId == null) return null;

    try {
      // Get current user profile to update
      final currentUser = await getCurrentUser();
      if (currentUser == null) {
        debugPrint('UserService.ensurePatientCodeForCurrentUser: No current user profile');
        return null;
      }

      final data = await _supabase
          .from('users')
          .select('id, auth_user_id, patient_code, preferences')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (data != null) {
        final existingCode = (data['patient_code'] as String?)?.trim();
        final prefs = (data['preferences'] as Map<String, dynamic>?) ?? {};
        final existingOrganizationId = (prefs['organizationId'] as String?)?.trim();
        final existingHospitalId = (prefs[_prefHospitalId] as String?)?.trim();
        final storedAuthUserId = data['auth_user_id'] as String?;

        // CRITICAL: Check if existing code needs to be regenerated due to ID format change
        // Old codes used profile ID, new codes use auth_user_id
        final needsRegeneration = existingCode != null && 
            existingCode.isNotEmpty && 
            storedAuthUserId != null &&
            storedAuthUserId != currentUser.id; // If auth_user_id differs from profile ID, code might be old format

        // Check if code matches current organization/hospital and doesn't need regeneration
        if ((existingCode != null && existingCode.isNotEmpty) && 
            (existingOrganizationId == entityId || existingHospitalId == entityId) &&
            !needsRegeneration) {
          debugPrint('UserService.ensurePatientCodeForCurrentUser: Using existing code $existingCode');
          return existingCode;
        }

        // Generate new code using auth_user_id (consistent across all profiles)
        final newCode = _composePatientCode(uid: authUser.id, entityId: entityId);
        final updatedPrefs = Map<String, dynamic>.from(prefs);
        
        // Store in the appropriate field
        if (organizationId != null) {
          updatedPrefs['organizationId'] = organizationId;
        } else if (hospitalId != null) {
          updatedPrefs[_prefHospitalId] = hospitalId;
        }

        if (needsRegeneration) {
          debugPrint('UserService.ensurePatientCodeForCurrentUser: Regenerating code from $existingCode to $newCode (auth_user_id format)');
        } else {
          debugPrint('UserService.ensurePatientCodeForCurrentUser: Generating new code $newCode');
        }

        await _supabase.from('users').update({
          'patient_code': newCode,
          'preferences': updatedPrefs,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', currentUser.id);

        return newCode;
      }

      // No existing profile data, generate new code
      final newCode = _composePatientCode(uid: authUser.id, entityId: entityId);
      return newCode;
    } catch (e) {
      debugPrint('UserService.ensurePatientCodeForCurrentUser error: $e');
      return _composePatientCode(uid: authUser.id, entityId: entityId);
    }
  }

  Future<void> _storePhonePreference(String phoneNumber) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return;

      final data = await _supabase
          .from('users')
          .select('preferences')
          .eq('id', authUser.id)
          .maybeSingle();

      final prefs = Map<String, dynamic>.from((data?['preferences'] as Map<String, dynamic>?) ?? {});
      prefs['phoneNumber'] = phoneNumber;

      await _supabase.from('users').update({
        'preferences': prefs,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', authUser.id);
    } catch (e) {
      debugPrint('UserService._storePhonePreference error: $e');
    }
  }


  OtpType? _findOtpTypeByNames(List<String> names) {
    final targets = names.map((n) => n.toLowerCase()).toSet();
    for (final type in OtpType.values) {
      final name = type.toString().split('.').last.toLowerCase();
      if (targets.contains(name)) {
        return type;
      }
    }
    return null;
  }

  AuthException _mapOtpError(AuthException e) {
    final msg = e.message.toLowerCase();
    final hasExpired = msg.contains('expired');
    final hasInvalid = msg.contains('invalid') || msg.contains('token') || msg.contains('otp');
    if (hasExpired && !hasInvalid) {
      return AuthException('Code expired. Request a new code.');
    }
    if (hasInvalid && !hasExpired) {
      return AuthException('Invalid code. Please try again.');
    }
    if (hasExpired && hasInvalid) {
      return AuthException('Code is invalid or expired. Request a new one.');
    }
    return e;
  }

  String _composePatientCode({required String uid, required String entityId}) {
    String prefix;
    final parts = entityId.split(RegExp(r'[_\s-]+')).where((p) => p.trim().isNotEmpty).toList();
    if (parts.isNotEmpty) {
      final letters = parts.take(3).map((p) => p[0].toUpperCase()).join();
      prefix = letters.padRight(3, 'X');
    } else {
      final clean = entityId.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
      prefix = (clean.isNotEmpty ? clean.substring(0, clean.length.clamp(0, 3)) : 'ORG').padRight(3, 'X');
    }
    final cleanedUid = uid.replaceAll(RegExp('[^A-Za-z0-9]'), '');
    final tail = (cleanedUid.length >= 6 ? cleanedUid.substring(cleanedUid.length - 6) : cleanedUid.padLeft(6, '0')).toUpperCase();
    return '$prefix-$tail';
  }

  bool isMfaVerifiedForSession() {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return false;
    return uid == _mfaVerifiedUserId;
  }

  Future<void> _markMfaVerifiedForSession() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid != null) {
      _mfaVerifiedUserId = uid;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('$_prefMfaPrefix$uid', true);
      } catch (e) {
        debugPrint('Persist MFA flag error: $e');
      }
    }
  }

  Future<void> _resetMfaVerification() async {
    _mfaVerifiedUserId = null;
    final uid = _supabase.auth.currentUser?.id;
    if (uid != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_prefMfaPrefix$uid');
      } catch (e) {
        debugPrint('Reset MFA flag error: $e');
      }
    }
  }

  String _emailRedirectTo() {
    // Dreamflow One-Click web hosting does not reliably support deep-link paths
    // like `/auth/callback`. Prefer returning to app root (`/`) and let the
    // router forward `?code=...` to `/auth/callback` internally.
    return _buildWebEntryUri().toString();
  }

  String? _oauthRedirectTo({String? from}) {
    // Web needs an http(s) URL that matches one of the redirect URLs configured
    // in Supabase Auth settings.
    if (kIsWeb) {
      final qp = <String, String>{};
      if (from != null && from.trim().isNotEmpty) {
        qp['from'] = from;
      }
      final entryUri = _buildWebEntryUri().replace(queryParameters: qp.isEmpty ? null : qp);
      debugPrint('UserService OAuth redirectTo (web): $entryUri');
      return entryUri.toString();
    }

    // On mobile, explicitly specify the deep link callback URL
    // This must match the URL scheme configured in iOS Info.plist and added to
    // Supabase Auth redirect URLs allowlist
    final mobileCallback = 'com.Adaptly.app://login-callback/';
    debugPrint('UserService OAuth redirectTo (mobile): $mobileCallback');
    return mobileCallback;
  }

  String _passwordResetRedirectTo() {
    // For password reset, we need to redirect to the specific reset page
    if (kIsWeb) {
      final baseUri = _buildWebEntryUri();
      // Ensure path ends correctly without extra slashes or malformed query strings
      var basePath = baseUri.path;
      // Remove trailing slash if present
      if (basePath.endsWith('/')) {
        basePath = basePath.substring(0, basePath.length - 1);
      }
      // Construct the reset path
      final resetPath = '$basePath/auth/reset-password';
      // Build the URI without any query parameters or fragments
      final resetUri = Uri(
        scheme: baseUri.scheme,
        host: baseUri.host,
        port: baseUri.port,
        path: resetPath,
      );
      debugPrint('UserService passwordReset redirectTo (web): $resetUri');
      return resetUri.toString();
    }

    // On mobile, use a deep link that will route to the password reset screen
    return 'io.supabase://reset-password';
  }

  /// Builds a stable web entry URI (app root), preserving any hosting base
  /// prefix (Dreamflow Preview runs under a deep path).
  Uri _buildWebEntryUri() => buildWebAppEntryUri(Uri.base);

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingKey);
      await prefs.remove('last_active_role');
      await prefs.remove('pending_oauth_role');
      _cachedUser = null;
      _cachedAt = null;
       _cachedOnboarding = null;
       _cachedOnboardingAt = null;
       _cachedOnboardingUserId = null;
       _cachedOnboardingRole = null;
      await _resetMfaVerification();
      await _supabase.auth.signOut();
      debugPrint('UserService.logout: Cleared all cached state and signed out');
    } catch (e) {
      debugPrint('UserService.logout error: $e');
      rethrow;
    }
  }

  Future<void> restoreMfaVerification() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      _mfaVerifiedUserId = null;
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final verified = prefs.getBool('$_prefMfaPrefix$uid') ?? false;
      _mfaVerifiedUserId = verified ? uid : null;
    } catch (e) {
      debugPrint('Restore MFA flag error: $e');
      _mfaVerifiedUserId = null;
    }
  }

  Future<void> deleteAccount({required String currentPassword}) async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) throw Exception('Not signed in');

    try {
      final email = authUser.email;
      if (email == null || email.trim().isEmpty) {
        throw Exception('Missing email on user');
      }

      await _supabase.auth.signInWithPassword(email: email, password: currentPassword);

      await _supabase.from('users').delete().eq('id', authUser.id);

      await _supabase.auth.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingKey);
    } catch (e) {
      debugPrint('UserService.deleteAccount error: $e');
      rethrow;
    }
  }

  Future<void> pinUser({
    required String targetUserId,
    required String targetName,
    String? targetImageUrl,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('Not signed in');
      if (authUser.id == targetUserId) return;

      final user = await getCurrentUser();
      if (user != null) {
        final prefs = Map<String, dynamic>.from(user.preferences);
        final pinnedList = (prefs['pinnedInfluencers'] as List?)?.cast<String>() ?? [];
        if (!pinnedList.contains(targetUserId)) {
          pinnedList.add(targetUserId);
          prefs['pinnedInfluencers'] = pinnedList;
          await updatePreferences(prefs);
        }
      }
    } catch (e) {
      debugPrint('UserService.pinUser error: $e');
      rethrow;
    }
  }

  Future<void> unpinUser(String targetUserId) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('Not signed in');

      final user = await getCurrentUser();
      if (user != null) {
        final prefs = Map<String, dynamic>.from(user.preferences);
        final pinnedList = (prefs['pinnedInfluencers'] as List?)?.cast<String>() ?? [];
        pinnedList.remove(targetUserId);
        prefs['pinnedInfluencers'] = pinnedList;
        await updatePreferences(prefs);
      }
    } catch (e) {
      debugPrint('UserService.unpinUser error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> lookupPatientByAccessCode(String accessCode) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('Not signed in');

      final response = await _supabase.functions.invoke(
        'lookup-patient-by-access-code',
        body: {
          'access_code': accessCode.toUpperCase().trim(),
          'user_id': authUser.id,
        },
      );

      if (response.status != 200) {
        final error = response.data['error'] ?? 'Unknown error';
        throw Exception(error);
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('UserService.lookupPatientByAccessCode error: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> watchPinnedUsers() {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) {
      return const Stream<List<Map<String, dynamic>>>.empty();
    }

    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', authUser.id)
        .asyncMap((rows) async {
          if (rows.isEmpty) return <Map<String, dynamic>>[];
          final prefs = (rows.first['preferences'] as Map<String, dynamic>?) ?? {};
          final ids = (prefs['pinnedInfluencers'] as List?)?.cast<String>() ?? [];
          return await _fetchUsersByIds(ids);
        });
  }

  Future<List<Map<String, dynamic>>> getPinnedUsersOnce() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return [];

      final data = await _supabase
          .from('users')
          .select('preferences')
          .eq('id', authUser.id)
          .maybeSingle();

      if (data != null) {
        final prefs = (data['preferences'] as Map<String, dynamic>?) ?? {};
        final ids = (prefs['pinnedInfluencers'] as List?)?.cast<String>() ?? [];
        return await _fetchUsersByIds(ids);
      }
      return [];
    } catch (e) {
      debugPrint('UserService.getPinnedUsersOnce error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      // Filter out invalid UUIDs (e.g., old Firebase IDs)
      final validIds = ids.where(_isValidUuid).toList();
      if (validIds.isEmpty) return [];

      final results = <Map<String, dynamic>>[];
      for (var i = 0; i < validIds.length; i += 10) {
        final chunk = validIds.sublist(i, (i + 10).clamp(0, validIds.length));
        final data = await _supabase
            .from('users')
            .select()
            .inFilter('id', chunk);
        results.addAll(List<Map<String, dynamic>>.from(data));
      }
      return results;
    } catch (e) {
      debugPrint('UserService._fetchUsersByIds error: $e');
      return [];
    }
  }

  bool _isValidUuid(String id) {
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidPattern.hasMatch(id);
  }

  Future<Map<String, String>> getVisibilityForUserIds(List<String> ids) async {
    try {
      final maps = await _fetchUsersByIds(ids);
      final vis = <String, String>{};
      for (final m in maps) {
        final id = (m['id'] as String?) ?? '';
        final prefs = (m['preferences'] as Map<String, dynamic>?) ?? {};
        final v = (prefs['privacy.visibility'] as String?) ?? 'community';
        if (id.isNotEmpty) vis[id] = v;
      }
      return vis;
    } catch (e) {
      debugPrint('UserService.getVisibilityForUserIds error: $e');
      return {};
    }
  }

  Future<bool> hasSeenTutorial() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return true;

      final data = await _supabase
          .from('users')
          .select('preferences')
          .eq('id', authUser.id)
          .maybeSingle();

      if (data != null) {
        final prefs = (data['preferences'] as Map<String, dynamic>?) ?? {};
        return (prefs[_prefHasSeenTutorial] as bool?) == true;
      }
      return true;
    } catch (e) {
      debugPrint('UserService.hasSeenTutorial error: $e');
      return true;
    }
  }

  Future<void> setHasSeenTutorial(bool value) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return;

      final user = await getCurrentUser();
      if (user != null) {
        final prefs = Map<String, dynamic>.from(user.preferences);
        prefs[_prefHasSeenTutorial] = value;
        await updatePreferences(prefs);
      }
    } catch (e) {
      debugPrint('UserService.setHasSeenTutorial error: $e');
    }
  }

  Future<bool> _ensureProfileForPhoneUser(
    User authUser, {
    required String phoneNumber,
  }) async {
    final existing = await _supabase
        .from('users')
        .select()
        .eq('id', authUser.id)
        .maybeSingle();

    if (existing != null) return false;

    final digits = phoneNumber.replaceAll(RegExp('[^0-9]'), '');
    final suffix = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : digits.padLeft(4, '0');
    final fallbackEmail = 'sms-$suffix-${authUser.id}@adaptly.phone';
    final now = DateTime.now();

    await _supabase.from('users').insert({
      'id': authUser.id,
      'auth_user_id': authUser.id,
      'role': 'patient', // Phone auth defaults to patient role
      'name': 'Member $suffix',
      'email': fallbackEmail,
      'profile_image_url': authUser.userMetadata?['avatar_url'],
      'onboarding_completed': false,
      'conditions': [],
      'interests': [],
      'preferences': {
        'phoneNumber': phoneNumber,
      },
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    await _achievements.initializeAchievementsForUser(authUser.id);
    return true;
  }

  String _normalizePhone(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (digits.length < 8 || digits.length > 15) return '';
    return '+$digits';
  }

  Future<void> savePreferredLocation({
    required String label,
    required double lat,
    required double lng,
    String? countryCode,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) throw Exception('Not signed in');

      final user = await getCurrentUser();
      if (user != null) {
        final prefs = Map<String, dynamic>.from(user.preferences);
        prefs[_prefLocation] = {
          'label': label,
          'lat': lat,
          'lng': lng,
          if (countryCode != null && countryCode.trim().isNotEmpty) 
            'countryCode': countryCode.trim().toUpperCase(),
          'updatedAt': DateTime.now().toIso8601String(),
        };
        await updatePreferences(prefs);
      }
    } catch (e) {
      debugPrint('UserService.savePreferredLocation error: $e');
      rethrow;
    }
  }

  Future<void> _trackMembershipMilestones(String userId) async {
    try {
      final data = await _supabase
          .from('users')
          .select('created_at')
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return;

      final createdStr = data['created_at'] as String?;
      if (createdStr == null) return;

      final created = DateTime.parse(createdStr);
      final now = DateTime.now();
      final daysSinceJoin = now.difference(created).inDays;

      await _achievements.updateProgress(userId, 'one_month', daysSinceJoin);
      await _achievements.updateProgress(userId, 'six_months', daysSinceJoin);
      await _achievements.updateProgress(userId, 'one_year', daysSinceJoin);
    } catch (e) {
      debugPrint('UserService._trackMembershipMilestones error: $e');
    }
  }

  Future<void> trackResourceView(String userId) async {
    try {
      await _achievements.incrementProgress(userId, 'explorer');
      await _achievements.incrementProgress(userId, 'knowledge_seeker');
    } catch (e) {
      debugPrint('UserService.trackResourceView error: $e');
    }
  }

  Future<void> trackResearchClick(String userId) async {
    try {
      await _achievements.incrementProgress(userId, 'researcher');
    } catch (e) {
      debugPrint('UserService.trackResearchClick error: $e');
    }
  }

  /// Provisions a new profile for an existing auth user with a specific role
  /// Used when user signs in with a role they don't have a profile for yet
  Future<models.User?> _provisionMissingProfile(
    User authUser, {
    required models.UserRole role,
  }) async {
    try {
      // First check if the profile was just created by another process (race condition protection)
      final existing = await _supabase
          .from('users')
          .select()
          .eq('auth_user_id', authUser.id)
          .eq('role', role.value)
          .maybeSingle();
      
      if (existing != null) {
        debugPrint('UserService._provisionMissingProfile: ${role.value} profile already exists (created by another process)');
        return _userFromMap(existing);
      }
      
      final nameFromEmail = authUser.email?.split('@').first;
      final phone = authUser.phone;
      final now = DateTime.now();
      
      debugPrint('UserService._provisionMissingProfile: Creating ${role.value} profile for auth_user_id=${authUser.id}');
      
      // Check if this is the first profile for this auth user
      final existingProfiles = await _supabase
          .from('users')
          .select('id')
          .eq('auth_user_id', authUser.id)
          .limit(1);
      
      // For first profile, use auth user ID. For additional profiles, generate new UUID
      final isFirstProfile = existingProfiles.isEmpty;
      final profileId = isFirstProfile ? authUser.id : const Uuid().v4();
      
      final profileMap = {
        'id': profileId,
        'auth_user_id': authUser.id,
        'role': role.value,
        'name': (authUser.userMetadata?['full_name'] as String?)?.trim().isNotEmpty == true
            ? (authUser.userMetadata?['full_name'] as String)
            : (nameFromEmail?.isNotEmpty == true ? nameFromEmail : 'Member'),
        'email': authUser.email ?? 'user-${authUser.id}@adaptly.app',
        'profile_image_url': authUser.userMetadata?['avatar_url'],
        'onboarding_completed': false,
        'conditions': <String>[],
        'interests': <String>[],
        'preferences': {
          if (phone != null && phone.trim().isNotEmpty) 'phoneNumber': phone,
        },
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final result = await _supabase.from('users').insert(profileMap).select().single();
      debugPrint('UserService._provisionMissingProfile: Successfully created ${role.value} profile with id=${result['id']}');
      return _userFromMap(result);
    } catch (e) {
      debugPrint('UserService._provisionMissingProfile error: $e');
      // If insert failed due to duplicate, try to fetch the existing profile
      try {
        final existing = await _supabase
            .from('users')
            .select()
            .eq('auth_user_id', authUser.id)
            .eq('role', role.value)
            .maybeSingle();
        
        if (existing != null) {
          debugPrint('UserService._provisionMissingProfile: Found existing ${role.value} profile after insert error');
          return _userFromMap(existing);
        }
      } catch (fetchError) {
        debugPrint('UserService._provisionMissingProfile: Failed to fetch after error: $fetchError');
      }
      return null;
    }
  }

  Future<models.User?> _provisionMissingUser(User authUser) async {
    try {
      final nameFromEmail = authUser.email?.split('@').first;
      final phone = authUser.phone;
      final now = DateTime.now();
      
      // Get the role from SharedPreferences to provision the correct profile
      // First check pending_oauth_role (saved before OAuth redirect), then last_active_role
      final prefs = await SharedPreferences.getInstance();
      final lastActiveRole = prefs.getString('pending_oauth_role') ?? prefs.getString('last_active_role') ?? 'patient';
      debugPrint('UserService._provisionMissingUser: Provisioning with role=$lastActiveRole');
      
      // Clear pending_oauth_role after reading it
      await prefs.remove('pending_oauth_role');
      
      final profileMap = {
        'id': authUser.id,
        'auth_user_id': authUser.id,
        'role': lastActiveRole, // CRITICAL: Include role when provisioning
        'name': (authUser.userMetadata?['full_name'] as String?)?.trim().isNotEmpty == true
            ? (authUser.userMetadata?['full_name'] as String)
            : (nameFromEmail?.isNotEmpty == true ? nameFromEmail : 'Member'),
        'email': authUser.email ?? 'user-${authUser.id}@adaptly.app',
        'profile_image_url': authUser.userMetadata?['avatar_url'],
        'onboarding_completed': false,
        'conditions': <String>[],
        'interests': <String>[],
        'preferences': {
          if (phone != null && phone.trim().isNotEmpty) 'phoneNumber': phone,
        },
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      await _supabase.from('users').insert(profileMap);
      await _achievements.initializeAchievementsForUser(authUser.id);
      return _userFromMap(profileMap);
    } catch (e) {
      debugPrint('UserService._provisionMissingUser error: $e');
      return null;
    }
  }

  models.User _userFromMap(Map<String, dynamic> data) {
    return models.User.fromJson({
      'id': data['id'],
      'name': data['name'],
      'email': data['email'],
      'profileImageUrl': data['profile_image_url'],
      'patientCode': data['patient_code'],
      'role': data['role'], // CRITICAL: Include role from database
      'onboardingCompleted': data['onboarding_completed'] ?? false, // CRITICAL: Default to false, not true
      'conditions': data['conditions'] ?? [],
      'diagnosisDate': data['diagnosis_date'],
      'interests': data['interests'] ?? [],
      'medications': data['medications'] ?? [],
      'preferences': data['preferences'] ?? {},
      'createdAt': data['created_at'],
      'updatedAt': data['updated_at'],
    });
  }
}
