import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/brand_logo.dart';
import 'package:wellspring/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:wellspring/auth/supabase_auth_manager.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegister = false;
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _appleLoading = false;
  String? _error;
  bool _isFamily = false; // true = Family Login, false = Patient Login

  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    // Clear any pending OAuth role from a previous session to ensure clean state
    _clearPendingOAuthRole();
  }

  Future<void> _clearPendingOAuthRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_oauth_role');
      // IMPORTANT: Don't clear last_active_role here!
      // If we clear it, getCurrentUser() will default to the most recently updated profile,
      // which can cause users to randomly switch between patient/family portals.
      // Only clear last_active_role on actual sign-out.
      debugPrint(
          '[SignIn] Cleared pending_oauth_role on screen init (preserved last_active_role)');
    } catch (e) {
      debugPrint('[SignIn] Error clearing OAuth roles: $e');
    }
  }

  void _openManualCodeEntry() {
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final target =
        from != null && from.isNotEmpty ? Uri.decodeComponent(from) : '/';
    final email = _emailController.text.trim();
    final emailParam =
        email.isNotEmpty ? '&email=${Uri.encodeComponent(email)}' : '';
    context.go(
        '/auth/callback?manual=1&from=${Uri.encodeComponent(target)}$emailParam');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final selectedRole = _isFamily ? UserRole.family : UserRole.patient;
    debugPrint(
        '[SignIn] _submitEmail: _isFamily=$_isFamily, selectedRole=${selectedRole.value}, isRegister=$_isRegister');

    try {
      if (_isRegister) {
        await _userService.registerWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: null,
          role: selectedRole,
        );
      } else {
        await _userService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: selectedRole,
        );
      }

      // Load provider user for in-app usage
      if (mounted) {
        await context.read<UserProvider>().loadUser();
      }

      // For new accounts, ensure the tutorial runs on first app session
      if (_isRegister) {
        try {
          await _userService.setHasSeenTutorial(false);
        } catch (e) {
          debugPrint('SignIn: setHasSeenTutorial(false) error: $e');
        }
      }

      // For newly registered users
      if (!mounted) return;

      if (_isRegister) {
        // Check if email confirmation is required
        final session = await _userService.getCurrentSession();
        if (session == null) {
          // Email confirmation required - show message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Please check your email to confirm your account, then sign in. Check your spam folder if you don\'t see it.'),
              duration: Duration(seconds: 6),
            ),
          );
          setState(() => _isRegister = false); // Switch to sign-in mode
          return;
        }
      }

      // Navigate to MFA screen (only if no errors were thrown above)
      if (!mounted) return;
      final from = GoRouterState.of(context).uri.queryParameters['from'];

      // Determine target based on registration status and onboarding completion
      String target;
      if (_isRegister) {
        // New registration - always go through onboarding
        target = _isFamily ? '/family/onboarding' : '/onboarding/questionnaire';
        debugPrint(
            '[SignIn] New registration for ${_isFamily ? "family" : "patient"}, routing to: $target');
      } else {
        // Sign-in - check if profile exists for this role
        final currentUser = await _userService.getCurrentUser();
        debugPrint(
            '[SignIn] Sign-in for ${_isFamily ? "family" : "patient"}, currentUser exists: ${currentUser != null}');

        if (currentUser == null) {
          // No profile exists for this role - this shouldn't happen on sign-in
          // Show error and suggest they create account instead
          setState(() {
            _error =
                'No ${_isFamily ? "family" : "patient"} account found. Please use "Create account" to add a ${_isFamily ? "family" : "patient"} profile.';
          });
          return;
        }

        // Check if onboarding is completed
        final isOnboardingCompleted =
            await _userService.isOnboardingCompleted();
        debugPrint('[SignIn] onboardingCompleted=$isOnboardingCompleted');
        if (!isOnboardingCompleted) {
          // Existing account but onboarding not completed - route to onboarding
          target =
              _isFamily ? '/family/onboarding' : '/onboarding/questionnaire';
          debugPrint('[SignIn] Incomplete onboarding, routing to: $target');
        } else {
          // Onboarding completed - use deep link or default home
          target = (from != null && from.isNotEmpty)
              ? Uri.decodeComponent(from)
              : (_isFamily ? '/family/dashboard' : '/');
          debugPrint('[SignIn] Onboarding completed, routing to: $target');
        }
      }

      context.go('/auth/mfa?from=${Uri.encodeComponent(target)}');
    } on AuthException catch (e) {
      debugPrint('Auth error: ${e.message}');
      setState(() {
        _error = _friendlyError(e);
      });
    } catch (e) {
      debugPrint('Auth unknown error: $e');
      setState(() {
        _error = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(AuthException e) {
    final msg = e.message.toLowerCase();

    // Check for specific multi-profile message first (before generic "already" check)
    if (msg.contains('already has an account') &&
        msg.contains('existing password')) {
      return e.message; // Return the full custom message
    }
    if (msg.contains('invalid') && msg.contains('email')) {
      return 'That email looks invalid.';
    }
    if (msg.contains('invalid login credentials') ||
        msg.contains('user not found')) {
      // Check if this might be an OAuth-only account (common scenario)
      return 'Incorrect email or password.\n\nIf you signed up with Google/Apple, click "Forgot password?" to set a password for your account.';
    }
    if (msg.contains('email') && msg.contains('already')) {
      return 'This email is already registered. Try signing in.';
    }
    if (msg.contains('weak password') ||
        msg.contains('password should be at least')) {
      return 'Please choose a stronger password (min 6 characters).';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email address. Check your inbox for a confirmation link.';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Too many attempts. Please wait a moment and retry.';
    }

    return e.message.isNotEmpty ? e.message : 'Authentication failed.';
  }

  Future<void> _signInWithGoogle() async {
    debugPrint('[SignIn] _signInWithGoogle called, _isFamily=$_isFamily');
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      // Save selected role for OAuth flow
      await _saveOAuthRole();
      debugPrint('[SignIn] Calling UserService.signInWithGoogle()...');
      await _userService.signInWithGoogle();

      debugPrint(
          '[SignIn] signInWithGoogle() completed (should redirect on web)');
      // On web, OAuth redirects away, so this code won't execute
      // On mobile, OAuth opens external browser and returns immediately
      // The callback will be handled when the user returns to the app
      if (kIsWeb) {
        // Web: should have redirected, won't reach here
      } else {
        // Mobile: show message and reset loading state
        if (mounted) {
          setState(() => _googleLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complete sign in in your browser, then return to the app'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      debugPrint('[SignIn] Google Auth error: ${e.message}');
      if (mounted) {
        setState(() {
          _googleLoading = false;
          _error =
              'Google sign in failed: ${e.message}\n\nPlease ensure Google OAuth is enabled in your Supabase project settings.';
        });
      }
    } catch (e) {
      debugPrint('[SignIn] Google Auth unknown error: $e');
      if (mounted) {
        setState(() {
          _googleLoading = false;
          _error = 'Something went wrong with Google sign in: $e';
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('[AppleSignIn] Button clicked, starting sign in');
    debugPrint('[AppleSignIn] Platform: ${kIsWeb ? "Web" : "Native (iOS/Android)"}');
    debugPrint('[AppleSignIn] Selected role: ${_isFamily ? "family" : "patient"}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    setState(() {
      _appleLoading = true;
      _error = null;
    });
    
    try {
      // STEP 1: Save selected role for OAuth flow
      debugPrint('[AppleSignIn] STEP 1: Saving OAuth role...');
      await _saveOAuthRole();
      debugPrint('[AppleSignIn] STEP 1: ✓ OAuth role saved');
      
      // STEP 2: Call UserService
      debugPrint('[AppleSignIn] STEP 2: Calling UserService.signInWithApple()...');
      final user = await _userService.signInWithApple(context);
      debugPrint('[AppleSignIn] STEP 2: ✓ UserService returned, user=${user?.id ?? "null"}');

      if (kIsWeb) {
        // Web: OAuth redirects away to browser, won't reach here
        debugPrint('[AppleSignIn] Web OAuth redirect should have occurred');
      } else {
        // Mobile (iOS/Android): Native Apple Sign-In completes immediately
        debugPrint('[AppleSignIn] STEP 3: Processing native sign-in result...');
        
        if (user != null && mounted) {
          debugPrint('[AppleSignIn] STEP 4: User authenticated, loading provider...');
          // Load user provider
          await context.read<UserProvider>().loadUser();
          debugPrint('[AppleSignIn] STEP 4: ✓ Provider loaded');
          
          // Navigate to appropriate screen based on onboarding status
          debugPrint('[AppleSignIn] STEP 5: Checking onboarding status...');
          final isOnboardingCompleted = await _userService.isOnboardingCompleted();
          debugPrint('[AppleSignIn] STEP 5: Onboarding completed = $isOnboardingCompleted');
          
          final from = GoRouterState.of(context).uri.queryParameters['from'];
          
          String target;
          if (!isOnboardingCompleted) {
            target = _isFamily ? '/family/onboarding' : '/onboarding/questionnaire';
          } else {
            target = (from != null && from.isNotEmpty)
                ? Uri.decodeComponent(from)
                : (_isFamily ? '/family/dashboard' : '/');
          }
          
          debugPrint('[AppleSignIn] STEP 6: Navigating to: $target');
          context.go(target);
          debugPrint('[AppleSignIn] ✓✓✓ Apple Sign-In COMPLETE ✓✓✓');
        } else if (user == null) {
          debugPrint('[AppleSignIn] ⚠️ User is null (likely cancelled by user)');
          if (mounted) {
            setState(() => _appleLoading = false);
          }
        } else {
          debugPrint('[AppleSignIn] ⚠️ Widget not mounted, cannot navigate');
          if (mounted) {
            setState(() => _appleLoading = false);
          }
        }
      }
    } on SignInWithAppleAuthorizationException catch (e, stackTrace) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[AppleSignIn] ✗ SignInWithAppleAuthorizationException');
      debugPrint('[AppleSignIn]   Code: ${e.code}');
      debugPrint('[AppleSignIn]   Message: ${e.message}');
      debugPrint('[AppleSignIn]   Stack: $stackTrace');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      if (e.code == AuthorizationErrorCode.canceled && mounted) {
        // User cancelled - just reset loading state, no error message
        debugPrint('[AppleSignIn] User cancelled (this is normal, not an error)');
        setState(() => _appleLoading = false);
      } else if (mounted) {
        setState(() {
          _appleLoading = false;
          _error = 'Apple sign in failed: ${e.message ?? e.code.toString()}';
        });
      }
    } on AuthException catch (e, stackTrace) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[AppleSignIn] ✗ Supabase AuthException');
      debugPrint('[AppleSignIn]   Message: ${e.message}');
      debugPrint('[AppleSignIn]   Status: ${e.statusCode}');
      debugPrint('[AppleSignIn]   Stack: $stackTrace');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      if (mounted) {
        setState(() {
          _appleLoading = false;
          _error = 'Apple sign in failed: ${e.message}';
        });
      }
    } catch (e, stackTrace) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[AppleSignIn] ✗ Unexpected error (${e.runtimeType})');
      debugPrint('[AppleSignIn]   Error: $e');
      debugPrint('[AppleSignIn]   Stack: $stackTrace');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      if (mounted) {
        setState(() {
          _appleLoading = false;
          _error = 'Apple sign in error: $e';
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    try {
      final url = Uri.parse('https://adaptlyapp.com/auth/forgot-password');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        setState(() => _error = 'Could not open password reset page.');
      }
    } catch (e) {
      debugPrint('Error opening password reset page: $e');
      if (!mounted) return;
      setState(() => _error = 'Could not open password reset page.');
    }
  }

  /// Save the selected role to SharedPreferences before OAuth redirect
  Future<void> _saveOAuthRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'pending_oauth_role', _isFamily ? 'family' : 'patient');
      debugPrint(
          '[SignIn] Saved OAuth role: ${_isFamily ? "family" : "patient"}');
    } catch (e) {
      debugPrint('[SignIn] Error saving OAuth role: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final fillColor = isLight ? const Color(0xFF2B2B2B) : null;
    final labelStyle = context.textStyles.labelLarge?.withColor(Colors.white);
    final hintStyle = context.textStyles.bodyMedium
        ?.withColor(Colors.white.withValues(alpha: 0.7));
    final iconColor = Colors.white.withValues(alpha: 0.9);
    return Scaffold(
      // Let the Scaffold adjust for the keyboard and avoid bottom overflow
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with wave effects
          Positioned.fill(
            child: Image.asset(
              'assets/images/ChatGPT_Image_Jul_13_2026_08_13_46_AM_1.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 850),
                        curve: Curves.easeOutBack,
                        tween: Tween(begin: 0.92, end: 1.0),
                        builder: (_, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Image.asset(
                          'assets/images/ChatGPT_Image_Jul_13_2026_12_13_23_PM.png',
                          fit: BoxFit.contain,
                          height: 200,
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, -30),
                        child: Text(
                          'A better tomorrow, together.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, -36),
                        child: Text(
                          _isRegister
                              ? 'Join Adaptly to personalize your support.'
                              : 'Join Adaptly to personalize your support.',
                          style: context.textStyles.bodyMedium?.withColor(
                            Colors.white.withValues(alpha: 0.65),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -30),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0A4D4D).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFF1E88FF)
                                  .withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ToggleButton(
                                  label: 'Patient Login',
                                  icon: Icons.person_outline,
                                  isSelected: !_isFamily,
                                  onTap: () =>
                                      setState(() => _isFamily = false),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _ToggleButton(
                                  label: 'Family Login',
                                  icon: Icons.group_outlined,
                                  isSelected: _isFamily,
                                  onTap: () => setState(() => _isFamily = true),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -24),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0A3D4D).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_error != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: cs.errorContainer,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: cs.onErrorContainer),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: context.textStyles.bodyMedium
                                              ?.withColor(
                                            cs.onErrorContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        hintText: 'Email address',
                                        hintStyle: context.textStyles.bodyMedium
                                            ?.withColor(
                                          Colors.white.withValues(alpha: 0.5),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.email_outlined,
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          size: 20,
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFF0A2D3D)
                                            .withValues(alpha: 0.8),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 16,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF1E88FF),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      style: context.textStyles.bodyLarge
                                          ?.withColor(Colors.white),
                                      cursorColor: const Color(0xFF1E88FF),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty)
                                          return 'Email is required';
                                        if (!v.contains('@'))
                                          return 'Enter a valid email';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscure,
                                      decoration: InputDecoration(
                                        hintText: 'Password',
                                        hintStyle: context.textStyles.bodyMedium
                                            ?.withColor(
                                          Colors.white.withValues(alpha: 0.5),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.lock_outline,
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                              () => _obscure = !_obscure),
                                          icon: Icon(
                                            _obscure
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: Colors.white
                                                .withValues(alpha: 0.7),
                                            size: 20,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFF0A2D3D)
                                            .withValues(alpha: 0.8),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 16,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF1E88FF),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      style: context.textStyles.bodyLarge
                                          ?.withColor(Colors.white),
                                      cursorColor: const Color(0xFF1E88FF),
                                      validator: (v) {
                                        if (v == null || v.isEmpty)
                                          return 'Password is required';
                                        if (v.length < 6)
                                          return 'Use at least 6 characters';
                                        return null;
                                      },
                                      onFieldSubmitted: (_) => _submitEmail(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _GradientLoginButton(
                                label:
                                    _isRegister ? 'Create account' : 'Log In',
                                showArrow: true,
                                loading: _loading,
                                onPressed: _loading ? null : _submitEmail,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      thickness: 1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md),
                                    child: Text(
                                      'OR',
                                      style: context.textStyles.labelSmall
                                          ?.withColor(
                                        Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SizedBox(
                                height: 50,
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: (_loading ||
                                          _googleLoading ||
                                          _appleLoading)
                                      ? null
                                      : _signInWithGoogle,
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0A2D3D)
                                        .withValues(alpha: 0.6),
                                    side: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _googleLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: InlineLoadingDot(),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 20,
                                              height: 20,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.g_mobiledata,
                                                size: 20,
                                                color: Color(0xFF1E88FF),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Continue with Google',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              SizedBox(
                                height: 50,
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: (_loading ||
                                          _googleLoading ||
                                          _appleLoading)
                                      ? null
                                      : _signInWithApple,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.black.withValues(alpha: 0.3),
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _appleLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: InlineLoadingDot(),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.apple,
                                              size: 20,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Continue with Apple',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isRegister
                                        ? 'Have an account?'
                                        : 'New here?',
                                    style: context.textStyles.bodyMedium
                                        ?.withColor(
                                      Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () => setState(() {
                                              _isRegister = !_isRegister;
                                              _error = null;
                                            }),
                                    child: Text(
                                      _isRegister
                                          ? 'Sign in'
                                          : 'Create account',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E88FF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!_isRegister)
                                Center(
                                  child: TextButton(
                                    onPressed: _loading ? null : _resetPassword,
                                    child: const Text(
                                      'Forgot password?',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF1E88FF)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient-styled brand wordmark for the sign-in header
class _BrandWordmark extends StatelessWidget {
  const _BrandWordmark({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                cs.primary,
                cs.tertiary,
              ],
            ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: context.textStyles.headlineMedium?.copyWith(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 3,
          width: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [
                cs.primary.withValues(alpha: 0.55),
                cs.tertiary.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1ED3CF) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? const Color(0xFF003D47)
                  : Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF003D47)
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient pill-shaped login button (blue → green) inspired by the Adaptly mockup.
class _GradientLoginButton extends StatelessWidget {
  const _GradientLoginButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    this.showArrow = false,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled && !loading ? 0.6 : 1.0,
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF1E88FF), // vivid blue
                Color(0xFF22D3A0), // mint/green
                Color(0xFF7BE38C), // light green
              ],
              stops: [0.0, 0.65, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E88FF).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onPressed,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (showArrow) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _AuthDivider extends StatelessWidget {
  const _AuthDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = context.textStyles.labelSmall?.withColor(cs.onSurfaceVariant);
    return Row(
      children: [
        Expanded(
            child: Divider(
                color: cs.outlineVariant.withValues(alpha: 0.6), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(label, style: style),
        ),
        Expanded(
            child: Divider(
                color: cs.outlineVariant.withValues(alpha: 0.6), height: 1)),
      ],
    );
  }
}
