import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/services/application_service.dart';
import 'package:wellspring/widgets/skeletons.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key, required this.id, required this.action});

  final String id;
  final String? action; // approve | reject | null

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  Map<String, dynamic>? appData;
  bool loading = true;
  String? error;
  bool acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await ApplicationService().getApplication(widget.id);
      setState(() { appData = data; });
    } catch (e) {
      setState(() { error = 'Failed to load: $e'; });
    } finally {
      setState(() { loading = false; });
    }
  }

  Future<void> _setStatus(String status) async {
    setState(() => acting = true);
    try {
      await ApplicationService().setStatus(id: widget.id, status: status);

      // Optional: email applicant
      final email = (appData?['email'] ?? '') as String;
      final name = (appData?['name'] ?? '') as String;
      if (email.isNotEmpty) {
        await ApplicationService().emailApplicant(
          toEmail: email,
          subject: status == 'approved' ? 'Your application was approved' : 'Your application was reviewed',
          text: status == 'approved'
              ? 'Hi $name, your application has been approved. We\'ll be in touch with next steps.'
              : 'Hi $name, your application has been reviewed. Status: $status.',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to $status')));
        context.go('/');
      }
    } catch (e) {
      debugPrint('Approval action failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Approval'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: loading
              ? const Center(child: CenteredLoadingSkeleton())
              : error != null
                  ? Center(child: Text(error!))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Application ID: ${widget.id}', style: theme.textTheme.labelSmall),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(appData?['name'] ?? '', style: theme.textTheme.titleLarge),
                                const SizedBox(height: 8),
                                Text('Email: ${appData?['email'] ?? ''}'),
                                Text('Phone: ${appData?['phone'] ?? ''}'),
                                const SizedBox(height: 12),
                                Text('Notes:', style: theme.textTheme.labelSmall),
                                Text(appData?['notes'] ?? ''),
                                const SizedBox(height: 12),
                                Text('Status: ${appData?['status'] ?? ''}', style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: acting ? null : () => _setStatus('approved'),
                              icon: const Icon(Icons.check, color: Colors.white),
                              label: const Text('Approve'),
                            ),
                            OutlinedButton.icon(
                              onPressed: acting ? null : () => _setStatus('rejected'),
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: const Text('Reject'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (widget.action == 'approve' || widget.action == 'reject')
                          Text('Action from link: ${widget.action}. Confirm above.', style: theme.textTheme.labelSmall),
                      ],
                    ),
        ),
      ),
    );
  }
}
