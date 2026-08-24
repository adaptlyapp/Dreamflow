import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/theme.dart';

/// Dedicated password reset screen that handles the Supabase recovery flow.
/// 
/// When a user clicks a password reset link from their email, Supabase
/// redirects them here with the recovery token already applied to the session.
/// This screen lets them enter a new password.
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, required this.uri});

  final Uri uri;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSessionLoading = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _passwordUpdated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _handleRecoverySession();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Handle the recovery session from the email link
  Future<void> _handleRecoverySession() async {
    final effectiveUri = kIsWeb ? Uri.base : widget.uri;
    debugPrint('[PasswordReset] Handling recovery session');
    debugPrint('[PasswordReset] URI: $effectiveUri');
    
    // Check for errors in the URL
    final errorDescription = effectiveUri.queryParameters['error_description'] ?? 
                             effectiveUri.queryParameters['error'];
    if (errorDescription != null) {
      setState(() {
        _error = Uri.decodeComponent(errorDescription).replaceAll('+', ' ');
        _isSessionLoading = false;
      });
      return;
    }

    try {
      // Try to get session from URL (this handles the recovery token)
      final hasCode = effectiveUri.queryParameters['code']?.isNotEmpty == true;
      if (hasCode) {
        await SupabaseConfig.auth.getSessionFromUrl(effectiveUri);
        debugPrint('[PasswordReset] Session established from recovery link');
      }
      
      // Check if we have a valid session
      final session = SupabaseConfig.auth.currentSession;
      if (session == null) {
        setState(() {
          _error = 'Password reset link is invalid or has expired. Please request a new one.';
          _isSessionLoading = false;
        });
        return;
      }
      
      setState(() => _isSessionLoading = false);
    } on AuthException catch (e) {
      debugPrint('[PasswordReset] Auth exception: ${e.message}');
      setState(() {
        _error = e.message.isNotEmpty 
            ? e.message 
            : 'Password reset link is invalid or has expired.';
        _isSessionLoading = false;
      });
    } catch (e) {
      debugPrint('[PasswordReset] Unknown error: $e');
      setState(() {
        _error = 'Could not verify the reset link. Please try again.';
        _isSessionLoading = false;
      });
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await SupabaseConfig.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      
      debugPrint('[PasswordReset] Password updated successfully');
      
      // The user is now authenticated with the new password via the recovery session.
      // No need to sign in again - just redirect them to the app.
      setState(() {
        _passwordUpdated = true;
        _isLoading = false;
      });
      
      // Auto-redirect after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          context.go('/');
        }
      });
    } on AuthException catch (e) {
      debugPrint('[PasswordReset] Password update failed: ${e.message}');
      setState(() {
        _error = e.message.isNotEmpty 
            ? e.message 
            : 'Could not update password. Please try again.';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[PasswordReset] Unknown error: $e');
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textStyles = context.textStyles;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: _buildContent(cs, textStyles),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs, TextTheme textStyles) {
    // Loading state
    if (_isSessionLoading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_reset, color: cs.primary, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text('Verifying reset link...', style: textStyles.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          const CircularProgressIndicator(strokeWidth: 3),
        ],
      );
    }

    // Error state (expired/invalid link)
    if (_error != null && !_passwordUpdated) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text('Reset link issue', style: textStyles.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () async {
              // Sign out first to avoid redirect loop
              try {
                await SupabaseConfig.auth.signOut();
              } catch (e) {
                debugPrint('[PasswordReset] Sign out error: $e');
              }
              if (context.mounted) {
                context.go('/auth');
              }
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to sign in'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You can request a new password reset from the sign in page.',
            style: textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // Success state
    if (_passwordUpdated) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, color: cs.primary, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text('Password updated!', style: textStyles.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your password has been successfully changed. You\'re now signed in and will be redirected shortly.',
            style: textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Continue now'),
          ),
        ],
      );
    }

    // Password entry form
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_reset, color: cs.primary, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Set new password',
            style: textStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter your new password below. Make sure it\'s at least 8 characters long.',
            style: textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _updatePassword(),
            decoration: InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: cs.onErrorContainer, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _error!,
                      style: textStyles.bodySmall?.withColor(cs.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _isLoading ? null : _updatePassword,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Update password'),
          ),
          
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _isLoading ? null : () async {
              // Sign out first to avoid redirect loop
              try {
                await SupabaseConfig.auth.signOut();
              } catch (e) {
                debugPrint('[PasswordReset] Sign out error: $e');
              }
              if (context.mounted) {
                context.go('/auth');
              }
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
