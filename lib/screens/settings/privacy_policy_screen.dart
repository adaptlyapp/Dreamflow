import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: cs.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adaptly Privacy Policy', style: context.textStyles.headlineSmall?.semiBold),
              SizedBox(height: AppSpacing.xs),
              Text('Effective Date: January 7, 2026', style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant)),
              SizedBox(height: AppSpacing.lg),
              _Section(
                title: 'Welcome',
                child: Text(
                  'Welcome! This Privacy Policy explains how Adaptly (“we,” “our,” or “us”) collects, uses, and protects your information when you use our app, website, and related services (collectively, the “Services”).\n\nShort version: we respect your data, we don’t do sketchy stuff, and we only collect what we actually need.',
                  style: context.textStyles.bodyMedium,
                ),
              ),
              _Section(
                title: '1. Information We Collect',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('a. Information You Provide', style: context.textStyles.titleSmall?.semiBold),
                  SizedBox(height: AppSpacing.xs),
                  _BulletList(items: const [
                    'Name',
                    'Email address',
                    'Account login information',
                    'Information you choose to enter into the app, such as plans, notes, preferences, or progress tracking',
                  ]),
                  SizedBox(height: AppSpacing.md),
                  Text('b. Automatically Collected Information', style: context.textStyles.titleSmall?.semiBold),
                  SizedBox(height: AppSpacing.xs),
                  _BulletList(items: const [
                    'Device type and operating system',
                    'App usage data (such as features used and interactions)',
                    'Log data including IP address and timestamps',
                  ]),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'This information helps us improve performance, reliability, and user experience.',
                    style: context.textStyles.bodyMedium,
                  ),
                ]),
              ),
              _Section(
                title: '2. Health-Related Information Disclaimer',
                child: Text(
                  'Adaptly does not provide medical advice, diagnosis, or treatment.\n\nAny health-related information you choose to enter into the app is used solely to:\n• Help organize your experience\n• Provide educational, supportive, or planning-based guidance\n• Improve app functionality and personalization\n\nAlways consult a qualified healthcare professional regarding medical decisions.',
                  style: context.textStyles.bodyMedium,
                ),
              ),
              _Section(
                title: '3. How We Use Your Information',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _BulletList(items: const [
                    'Provide and maintain the Services',
                    'Personalize your experience',
                    'Improve features, usability, and performance',
                    'Communicate with you regarding updates or support',
                    'Maintain security and prevent misuse',
                  ]),
                  SizedBox(height: AppSpacing.sm),
                  Text('We do not sell your personal data. Full stop.', style: context.textStyles.bodyMedium?.semiBold),
                ]),
              ),
              _Section(
                title: '4. Data Storage & Security',
                child: Text(
                  'We use industry-standard security measures to protect your information, including secure servers, encrypted connections, and access controls.\n\nWhile no system is perfectly secure, we continuously work to safeguard your data.',
                  style: context.textStyles.bodyMedium,
                ),
              ),
              _Section(
                title: '5. Third-Party Services',
                child: Text(
                  'Adaptly may use trusted third-party services (such as hosting, analytics, authentication, or payment providers) to operate the Services. These providers only access information necessary to perform their functions and are required to protect your data.',
                  style: context.textStyles.bodyMedium,
                ),
              ),
              _Section(
                title: '6. Your Rights & Choices',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('You have the right to:', style: context.textStyles.bodyMedium),
                  SizedBox(height: AppSpacing.xs),
                  _BulletList(items: const [
                    'Access your personal information',
                    'Request corrections or deletion',
                    'Delete your account at any time',
                  ]),
                  SizedBox(height: AppSpacing.sm),
                  Text('To exercise these rights, contact us at:', style: context.textStyles.bodyMedium),
                  SizedBox(height: AppSpacing.xs),
                  Row(children: [
                    const Icon(Icons.email_outlined),
                    SizedBox(width: 8),
                    SelectableText('adaptlyapp@gmail.com'),
                  ]),
                ]),
              ),
              _Section(
                title: '7. Data Retention',
                child: Text(
                  'We retain personal information only for as long as necessary to:\n• Provide the Services\n• Comply with legal obligations\n• Resolve disputes and enforce agreements\n\nWhen information is no longer needed, it is securely deleted.',
                  style: context.textStyles.bodyMedium,
                ),
              ),
              _Section(
                title: '8. Children’s Privacy',
                child: Text(
                  'Adaptly is not intended for use by individuals under the age of 13. We do not knowingly collect personal data from children.',
                  style: context.textStyles.bodyMedium,
                ),
              ),
              _Section(
                title: '9. Changes to This Policy',
                child: Text(
                  'We may update this Privacy Policy from time to time. When changes occur, we will update the effective date and notify users when appropriate.',
                  style: context.textStyles.bodyMedium,
                ),
              ),
              _Section(
                title: '10. Contact Us',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('If you have questions or concerns about this Privacy Policy or our data practices, please contact us at:',
                      style: context.textStyles.bodyMedium),
                  SizedBox(height: AppSpacing.xs),
                  Row(children: [
                    const Icon(Icons.email_outlined),
                    SizedBox(width: 8),
                    SelectableText('adaptlyapp@gmail.com'),
                  ]),
                ]),
              ),
              SizedBox(height: AppSpacing.lg),
              Center(
                child: Text('© ${DateTime.now().year} Adaptly', style: context.textStyles.labelMedium?.withColor(cs.onSurfaceVariant)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg),
      child: Card(
        color: cs.surface,
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.textStyles.titleLarge?.semiBold),
            SizedBox(height: AppSpacing.sm),
            child,
          ]),
        ),
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  const _BulletList({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((t) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6, color: cs.onSurfaceVariant),
                  ),
                  SizedBox(width: 8),
                  Expanded(child: Text(t, style: context.textStyles.bodyMedium)),
                ]),
              ))
          .toList(),
    );
  }
}
