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
import 'package:wellspring/widgets/glass_card.dart';
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
    final from =
        mounted ? GoRouterState.of(context).uri.queryParameters['from'] : null;
    final target =
        (from != null && from.isNotEmpty) ? Uri.decodeComponent(from) : '/';

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

    final fieldBg = isLight
        ? Colors.white.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.06);
    final fieldText = isLight ? Colors.black : Colors.white;
    final fieldHint = isLight
        ? Colors.black.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.7);
    final fieldIcon = isLight
        ? Colors.black.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.85);

    final sanitizedCode =
        _codeController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final canVerify = sanitizedCode.isNotEmpty;
    final contactLabel = _email ?? 'your email address';
    final isCoolingDown = _cooldownSeconds > 0;

    final titleColor = isLight ? Colors.black : Colors.white;
    final subtitleColor = isLight
        ? Colors.black.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.7);

    return GlassyScaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
          icon: Icon(Icons.arrow_back, color: titleColor),
        ),
        title: Text('Verify your email', style: context.textStyles.titleLarge?.semiBold?.withColor(titleColor)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: GlassCard(
                showGlow: true,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: Theme.of(context).extension<AppGradients>()?.buttonGloss,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Icon(Icons.mail_outline, color: Colors.white.withValues(alpha: 0.95)),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Protect your account', style: context.textStyles.headlineSmall?.semiBold?.withColor(titleColor)),
                              const SizedBox(height: 6),
                              Text(
                                'We’ll email you a one‑time code to confirm it’s really you.',
                                style: context.textStyles.bodyMedium?.withColor(subtitleColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, color: cs.onErrorContainer),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(_error!, style: context.textStyles.bodyMedium?.withColor(cs.onErrorContainer)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    _EmailTargetPill(email: contactLabel),
                    const SizedBox(height: AppSpacing.lg),
                    _StepList(
                      sent: _codeSent,
                      isCoolingDown: isCoolingDown,
                      cooldownSeconds: _cooldownSeconds,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: (!_codeSent && _codeController.text.isEmpty)
                          ? SizedBox(
                              key: const ValueKey('send'),
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: (_sending || _skipping || isCoolingDown) ? null : _sendCode,
                                icon: _sending
                                    ? const SizedBox(width: 16, height: 16, child: InlineLoadingDot())
                                    : const Icon(Icons.mark_email_read_outlined),
                                label: Text(_isCoolingDownLabel(isCoolingDown)),
                              ),
                            )
                          : Column(
                              key: const ValueKey('verify'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
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
                                    hintText: 'Enter the code from your email',
                                    filled: true,
                                    fillColor: fieldBg,
                                    prefixIcon: Icon(Icons.verified_outlined, color: fieldIcon),
                                    labelStyle: context.textStyles.bodyMedium?.withColor(fieldHint),
                                    floatingLabelStyle: context.textStyles.bodyMedium?.withColor(fieldText),
                                    hintStyle: context.textStyles.bodyMedium?.withColor(fieldHint),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  style: context.textStyles.titleMedium?.withColor(fieldText),
                                  cursorColor: cs.primary,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: (_verifying || _skipping || !canVerify) ? null : _verify,
                                    icon: _verifying
                                        ? const SizedBox(width: 16, height: 16, child: InlineLoadingDot())
                                        : Icon(Icons.verified_user_outlined, color: cs.onPrimary),
                                    label: Text('Verify & continue', style: context.textStyles.labelLarge?.withColor(cs.onPrimary)),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: (_sending || _skipping || isCoolingDown) ? null : _sendCode,
                                    icon: _sending
                                        ? const SizedBox(width: 16, height: 16, child: InlineLoadingDot())
                                        : Icon(Icons.refresh, color: titleColor),
                                    label: Text(_isCoolingDownLabel(isCoolingDown), style: context.textStyles.labelLarge?.withColor(titleColor)),
                                  ),
                                ),
                              ],
                            ),
                    ),
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

class _EmailTargetPill extends StatelessWidget {
  final String email;
  const _EmailTargetPill({required this.email});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight
        ? Colors.white.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.08);
    final fg = isLight ? Colors.black : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: isLight ? 0.3 : 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.alternate_email, size: 18, color: fg.withValues(alpha: 0.85)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepList extends StatelessWidget {
  final bool sent;
  final bool isCoolingDown;
  final int cooldownSeconds;

  const _StepList({required this.sent, required this.isCoolingDown, required this.cooldownSeconds});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final fg = isLight ? Colors.black : Colors.white;
    final subtle = fg.withValues(alpha: 0.7);
    final chipBg = isLight
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.08);
    final chipFg = fg.withValues(alpha: 0.85);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(sent ? Icons.mark_email_read_outlined : Icons.outgoing_mail, size: 16, color: chipFg),
                  const SizedBox(width: 8),
                  Text(
                    sent ? 'Code sent' : 'One‑time email code',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: chipFg),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (isCoolingDown)
              Text(
                '${cooldownSeconds}s',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: subtle),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _StepRow(
          index: 1,
          icon: Icons.mark_email_read_outlined,
          title: sent ? 'Check your inbox' : 'Tap “Email code”',
          subtitle: sent
              ? 'Look for a message with your 6‑digit code (check Spam/Promotions).'
              : 'We’ll send a secure code to your email address.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _StepRow(
          index: 2,
          icon: Icons.pin,
          title: 'Enter the code here',
          subtitle: 'Type the code exactly as shown (numbers only).',
        ),
        const SizedBox(height: AppSpacing.sm),
        _StepRow(
          index: 3,
          icon: Icons.verified_user_outlined,
          title: 'Verify & continue',
          subtitle: 'If it fails, request a fresh code and try again.',
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;

  const _StepRow({required this.index, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final fg = isLight ? Colors.black : Colors.white;
    final subtle = fg.withValues(alpha: 0.7);
    final ringBg = isLight
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.08);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: ringBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              '$index',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg.withValues(alpha: 0.9), fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: fg.withValues(alpha: 0.9)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: subtle)),
            ],
          ),
        ),
      ],
    );
  }
}
