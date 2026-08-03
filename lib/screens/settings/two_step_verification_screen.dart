import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/skeletons.dart';

class TwoStepVerificationScreen extends StatefulWidget {
  const TwoStepVerificationScreen({super.key});

  @override
  State<TwoStepVerificationScreen> createState() => _TwoStepVerificationScreenState();
}

class _TwoStepVerificationScreenState extends State<TwoStepVerificationScreen> {
  bool _loading = true;
  bool _working = false;
  List<auth.MultiFactorInfo> _factors = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final u = auth.FirebaseAuth.instance.currentUser;
      if (u == null) {
        setState(() {
          _factors = const [];
          _loading = false;
        });
        return;
      }
      final list = await u.multiFactor.getEnrolledFactors();
      setState(() {
        _factors = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('2FA refresh error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enrollSmsFactor() async {
    if (_working) return;
    setState(() => _working = true);
    final cs = Theme.of(context).colorScheme;
    try {
      final user = auth.FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      String phone = '';
      String? verificationId;
      String smsCode = '';

      // 1) Ask for phone number
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
        builder: (context) {
          final ctl = TextEditingController();
          return Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 44, height: 4, margin: EdgeInsets.only(bottom: AppSpacing.md), decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                ),
                Row(
                  children: [
                    Expanded(child: Text('Add phone number', style: context.textStyles.titleLarge?.semiBold)),
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close, color: cs.onSurfaceVariant)),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Text('We’ll send a 6‑digit code to verify it for two‑step sign‑in.', style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant)),
                SizedBox(height: AppSpacing.md),
                TextField(
                  controller: ctl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number', hintText: '+1 415‑555‑1234'),
                ),
                SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () {
                      phone = ctl.text.trim();
                      Navigator.of(context).pop();
                    },
                    icon: Icon(Icons.sms, color: cs.onPrimary),
                    label: const Text('Send code'),
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (!mounted) return;
      if (phone.isEmpty) {
        setState(() => _working = false);
        return;
      }

      // 2) Start enrollment verification
      final session = await user.multiFactor.getSession();
      await auth.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        multiFactorSession: session,
        verificationCompleted: (cred) {
          // Auto-retrieval on Android – not used here. We'll wait for code entry.
        },
        verificationFailed: (e) {
          debugPrint('2FA enroll verify failed: ${e.code} ${e.message}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send code')));
          }
        },
        codeSent: (id, _) async {
          verificationId = id;
          // 3) Prompt for code
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: cs.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
            builder: (context) {
              final ctl = TextEditingController();
              return Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 44, height: 4, margin: EdgeInsets.only(bottom: AppSpacing.md), decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
                    Row(children: [
                      Expanded(child: Text('Enter verification code', style: context.textStyles.titleLarge?.semiBold)),
                      IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close, color: cs.onSurfaceVariant)),
                    ]),
                    SizedBox(height: AppSpacing.sm),
                    Text('We sent a code to $phone', style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant)),
                    SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: ctl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '6‑digit code'),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () {
                          smsCode = ctl.text.trim();
                          Navigator.of(context).pop();
                        },
                        icon: Icon(Icons.verified, color: cs.onPrimary),
                        label: const Text('Verify'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );

      if (!mounted) return;
      if ((verificationId ?? '').isEmpty || smsCode.isEmpty) {
        setState(() => _working = false);
        return;
      }

      final credential = auth.PhoneAuthProvider.credential(verificationId: verificationId!, smsCode: smsCode);
      final assertion = auth.PhoneMultiFactorGenerator.getAssertion(credential);
      await user.multiFactor.enroll(assertion, displayName: 'SMS');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Two‑step verification enabled')));
      }
      await _refresh();
    } catch (e) {
      debugPrint('2FA enroll error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to enable two‑step verification')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _unenroll(String factorUid) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final user = auth.FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      await user.multiFactor.unenroll(factorUid: factorUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Two‑step verification disabled')));
      }
      await _refresh();
    } catch (e) {
      debugPrint('2FA unenroll error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to disable two‑step verification')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          tooltip: 'Back',
        ),
        title: const Text('Two‑Step Verification'),
      ),
      body: _loading
          ? const Center(child: CenteredLoadingSkeleton())
          : Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: AppSpacing.paddingMd,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.shield_outlined, color: cs.primary),
                            SizedBox(width: AppSpacing.sm),
                            Text('Two‑Step Verification (SMS disabled)', style: context.textStyles.titleMedium?.semiBold),
                          ]),
                          SizedBox(height: AppSpacing.xs),
                          Text('Per policy, SMS‑based two‑step verification is disabled. Access controls are enforced without SMS codes.', style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant)),
                          SizedBox(height: AppSpacing.md),
                          if (_factors.isEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: AppSpacing.paddingMd,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: cs.onSurfaceVariant),
                                  SizedBox(width: AppSpacing.sm),
                                  Expanded(child: Text('No two‑step factors are enrolled. SMS enrollment is disabled.', style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant))),
                                ],
                              ),
                            ),
                          ] else ...[
                            ..._factors.map((f) {
                              final isPhone = f is auth.PhoneMultiFactorInfo;
                              final label = isPhone ? (f.phoneNumber ?? 'Phone') : (f.displayName ?? 'Factor');
                              return Container(
                                width: double.infinity,
                                margin: EdgeInsets.only(bottom: AppSpacing.sm),
                                padding: AppSpacing.paddingMd,
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.verified_user, color: cs.secondary),
                                    SizedBox(width: AppSpacing.sm),
                                    Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
                                    TextButton.icon(
                                      onPressed: _working ? null : () => _unenroll(f.uid),
                                      icon: Icon(Icons.delete_outline, color: cs.error),
                                      label: Text('Remove', style: context.textStyles.labelLarge?.withColor(cs.error)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
