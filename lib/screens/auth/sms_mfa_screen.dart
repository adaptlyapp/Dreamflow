import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/animated_blobs.dart';
import 'package:wellspring/widgets/brand_logo.dart';
import 'package:wellspring/widgets/skeletons.dart';

class SmsMfaScreen extends StatefulWidget {
  const SmsMfaScreen({super.key});

  @override
  State<SmsMfaScreen> createState() => _SmsMfaScreenState();
}

class _SmsMfaScreenState extends State<SmsMfaScreen> {
  final _codeController = TextEditingController();
  final _userService = UserService();

  bool _sending = false;
  bool _verifying = false;
  bool _skipping = false;
  bool _codeSent = false;
  int _cooldownSeconds = 0;
  String? _email;
  String? _error;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _prefillEmail();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _prefillEmail() {
    try {
      final authEmail = SupabaseConfig.auth.currentUser?.email?.trim();
      if (authEmail != null && authEmail.isNotEmpty) {
        setState(() => _email = authEmail);
      }
    } catch (e) {
      debugPrint('Email MFA prefill error: $e');
    }
  }

  String _friendlyError(AuthException e) {
    final msg = e.message.toLowerCase();
    final hasExpired = msg.contains('expired');
    final hasInvalid =
        msg.contains('invalid') || msg.contains('token') || msg.contains('otp');
    if (hasExpired && !hasInvalid) {
      return 'Code expired. Request a new code.';
    }
    if (hasInvalid && !hasExpired) {
      return 'Invalid code. Please try again.';
    }
    if (hasExpired && hasInvalid) {
      return 'Code is invalid or expired. Request a new one.';
    }
    if (msg.contains('rate limit') || msg.contains('too many'))
      return 'Too many attempts. Please wait a minute.';
    if (msg.contains('email'))
      return 'Email service unavailable. Try again later.';
    return e.message.isNotEmpty ? e.message : 'Verification failed.';
  }

  String _isCoolingDownLabel(bool isCoolingDown) {
    if (isCoolingDown) {
      return _codeSent
          ? 'Resend in ${_cooldownSeconds}s'
          : 'Email in ${_cooldownSeconds}s';
    }
    return _codeSent ? 'Resend code' : 'Email code';
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _completeAndGo() async {
    // Capture navigation target BEFORE async operations
    final from = mounted ? GoRouterState.of(context).uri.queryParameters['from'] : null;
    final target = (from != null && from.isNotEmpty) ? Uri.decodeComponent(from) : '/';
    
    if (mounted) {
      await context.read<UserProvider>().loadUser();
    }

    if (!mounted) return;
    context.go(target);
  }

  Future<void> _sendCode() async {
    final email = _email?.trim() ?? '';
    if (email.isEmpty) {
      setState(() => _error =
          'No email on file. Please sign in again with your email account.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
      _codeController.clear();
    });

    try {
      await _userService.startEmailMfa();
      if (!mounted) return;
      setState(() => _codeSent = true);
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ New code sent. Check your email.')));
    } on AuthException catch (e) {
      setState(() => _error = _friendlyError(e));
      if (e.message.toLowerCase().contains('rate limit') ||
          e.message.toLowerCase().contains('too many')) {
        _startCooldown();
      }
    } catch (e) {
      debugPrint('Email MFA send error: $e');
      setState(
          () => _error = 'Could not send the email code. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      await _userService.verifyEmailMfa(emailCode: _codeController.text.trim());
      await _completeAndGo();
    } on AuthException catch (e) {
      setState(() => _error = _friendlyError(e));
    } catch (e) {
      debugPrint('Email MFA verify error: $e');
      setState(
          () => _error = 'We could not verify that code. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
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
    final sanitizedCode =
        _codeController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final canVerify = sanitizedCode.isNotEmpty;
    final contactLabel = _email ?? 'your email address';
    final isCoolingDown = _cooldownSeconds > 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            // If the user is stuck on MFA due to router redirects, going back to
            // /auth will immediately redirect back here (because the session is
            // still authenticated but not MFA-verified). Signing out first
            // makes "Back" behave like a true cancel.
            try {
              await SupabaseConfig.auth.signOut();
            } catch (e) {
              debugPrint('Failed to sign out while leaving MFA: $e');
            }
            if (context.mounted) context.go('/auth');
          },
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
        ),
        title: const Text('Verify your email'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AnimatedBlobs(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Icon(
                              Icons.mail_outline,
                              size: 48,
                              color: cs.onPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Protect your account',
                            style: context.textStyles.headlineSmall?.semiBold,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Enter the email code to finish signing in.',
                            style: context.textStyles.bodyMedium?.withColor(
                              cs.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xl),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.mail_outline, color: cs.primary),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    contactLabel,
                                    style: context.textStyles.bodyMedium
                                        ?.withColor(cs.onSurface),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Check your inbox for a verification code.',
                            style: context.textStyles.bodyMedium
                                ?.withColor(cs.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Codes can expire. If verification fails, request a fresh code and try again.',
                            style: context.textStyles.bodySmall
                                ?.withColor(cs.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          if (!_codeSent && _codeController.text.isEmpty) ...[
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed:
                                    (_sending || _skipping || isCoolingDown)
                                        ? null
                                        : _sendCode,
                                icon: _sending
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: InlineLoadingDot(),
                                      )
                                    : const Icon(Icons.mail_outline),
                                label:
                                    Text(_isCoolingDownLabel(isCoolingDown)),
                              ),
                            ),
                          ] else ...[
                            TextField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(12),
                              ],
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Verification code',
                                labelStyle: labelStyle,
                                floatingLabelStyle: labelStyle,
                                hintText: 'Enter the code',
                                hintStyle: hintStyle,
                                prefixIcon: Icon(Icons.verified_outlined,
                                    color: iconColor),
                                filled: isLight,
                                fillColor: fillColor,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: context.textStyles.bodyLarge
                                  ?.withColor(Colors.white),
                              cursorColor: Colors.white,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed:
                                    (_verifying || _skipping || !canVerify)
                                        ? null
                                        : _verify,
                                icon: _verifying
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: InlineLoadingDot(),
                                      )
                                    : Icon(Icons.verified_user_outlined,
                                        color: cs.onPrimary),
                                label: Text(
                                  'Verify & continue',
                                  style: context.textStyles.labelLarge
                                      ?.withColor(cs.onPrimary),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed:
                                    (_sending || _skipping || isCoolingDown)
                                        ? null
                                        : _sendCode,
                                icon: _sending
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: InlineLoadingDot(),
                                      )
                                    : const Icon(Icons.mail_outline),
                                label:
                                    Text(_isCoolingDownLabel(isCoolingDown)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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
