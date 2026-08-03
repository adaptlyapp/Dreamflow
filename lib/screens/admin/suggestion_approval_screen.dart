import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:wellspring/services/resource_service.dart';
import 'package:wellspring/firebase_options.dart';
import 'package:wellspring/widgets/skeletons.dart';

class SuggestionApprovalScreen extends StatefulWidget {
  const SuggestionApprovalScreen({super.key, required this.id, this.action, this.token});

  final String id;
  final String? action; // approve | reject | null
  final String? token; // secure approval token from email link

  @override
  State<SuggestionApprovalScreen> createState() => _SuggestionApprovalScreenState();
}

class _SuggestionApprovalScreenState extends State<SuggestionApprovalScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;
  bool acting = false;
  bool unauthorized = false;
  String? signedInEmail;

  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // If opened from email with token+action, perform action immediately without requiring sign-in
    final tokenDebug = widget.token == null
        ? 'null'
        : (widget.token!.length <= 6
            ? widget.token
            : '${widget.token!.substring(0, 3)}***${widget.token!.substring(widget.token!.length - 3)}');
    debugPrint('SuggestionApprovalScreen.init: id=${widget.id}, action=${widget.action}, token=$tokenDebug');
    if ((widget.token != null && widget.token!.isNotEmpty) && (widget.action == 'approve' || widget.action == 'reject')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _actWithToken(widget.action!);
      });
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final doc = await _db.collection('resource_suggestions').doc(widget.id).get();
      if (!doc.exists) {
        setState(() { error = 'Suggestion not found'; });
      } else {
        setState(() { data = doc.data(); });
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        setState(() {
          unauthorized = true;
          signedInEmail = auth.FirebaseAuth.instance.currentUser?.email;
          error = 'Unauthorized. Please sign in with an admin account to moderate suggestions.';
        });
      } else {
        setState(() { error = 'Failed to load: ${e.message ?? e.code}'; });
      }
    } catch (e) {
      setState(() { error = 'Failed to load: $e'; });
    } finally {
      setState(() { loading = false; });
    }
  }

  Future<void> _reject() async => _setStatus('rejected');

  Future<void> _approve() async {
    if (data == null) return;
    setState(() => acting = true);
    try {
      final m = Map<String, dynamic>.from(data!);
      // Extract fields from suggestion schema (handles both old and new keys)
      final name = (m['resourceName'] ?? m['name'] ?? '').toString();
      final type = (m['type'] ?? 'service').toString();
      final address = (m['addressLine'] ?? m['address'] ?? '').toString();
      final city = (m['city'] ?? '').toString();
      final state = (m['stateProvince'] ?? m['state'] ?? '').toString();
      final postal = (m['postalCode'] ?? '').toString();
      final country = (m['country'] ?? '').toString();
      double? lat;
      double? lng;
      try {
        if (m['coordinates'] is Map) {
          final c = (m['coordinates'] as Map).cast<String, dynamic>();
          lat = (c['lat'] is num) ? (c['lat'] as num).toDouble() : null;
          lng = (c['lng'] is num) ? (c['lng'] as num).toDouble() : null;
        } else {
          lat = (m['lat'] is num) ? (m['lat'] as num).toDouble() : null;
          lng = (m['lng'] is num) ? (m['lng'] as num).toDouble() : null;
        }
      } catch (_) {}
      final phone = (m['phone'] ?? '').toString();
      final website = (m['website'] ?? '').toString();
      final contactEmail = (m['contactEmail'] ?? '').toString();
      final specialties = (m['specialties'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

      // Geocode if missing coords
      if (lat == null || lng == null) {
        try {
          final rs = ResourceService();
          final addrParts = [address, city, state, postal, country].where((e) => (e).toString().trim().isNotEmpty).join(', ');
          final geo = await rs.geocodeAddress(addrParts.isEmpty ? name : addrParts);
          if (geo != null) {
            lat = (geo['lat'] as num?)?.toDouble();
            lng = (geo['lng'] as num?)?.toDouble();
          }
        } catch (e) {
          debugPrint('SuggestionApprovalScreen: geocode on approve failed: $e');
        }
      }

      // Create curated resource
      final curated = <String, dynamic>{
        'name': name,
        'type': type,
        'address': address,
        if (city.isNotEmpty) 'city': city,
        if (state.isNotEmpty) 'state': state,
        if (postal.isNotEmpty) 'postalCode': postal,
        if (country.isNotEmpty) 'country': country,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (phone.isNotEmpty) 'phone': phone,
        if (website.isNotEmpty) 'website': website,
        if (contactEmail.isNotEmpty) 'contactEmail': contactEmail,
        if (specialties.isNotEmpty) 'specialties': specialties,
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'suggestion',
        'sourceId': widget.id,
      };

      final batch = _db.batch();
      final curatedRef = _db.collection('resources_curated').doc();
      final suggestionRef = _db.collection('resource_suggestions').doc(widget.id);
      batch.set(curatedRef, curated);
      batch.update(suggestionRef, {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'publishedResourceId': curatedRef.id,
      });
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suggestion approved and published')));
        context.go('/');
      }
    } catch (e, st) {
      debugPrint('SuggestionApprovalScreen: approve failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  // Token-based moderation path for one-click from email (no sign-in required)
  Future<void> _actWithToken(String action) async {
    setState(() { loading = true; acting = true; error = null; unauthorized = false; });
    try {
      final isApprove = action == 'approve';
      final tokenDebug = widget.token == null
          ? 'null'
          : (widget.token!.length <= 6
              ? widget.token
              : '${widget.token!.substring(0, 3)}***${widget.token!.substring(widget.token!.length - 3)}');
      debugPrint('SuggestionApprovalScreen.tokenAction: id=${widget.id}, action=$action, token=$tokenDebug');

      // Prefer calling Cloud Function to publish curated resource server-side
      bool publishedViaCF = false;
      try {
        final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
        final region = 'us-central1';
        final cfUrl = Uri.parse('https://$region-$projectId.cloudfunctions.net/moderateResourceSuggestion?id=${Uri.encodeComponent(widget.id)}&token=${Uri.encodeComponent(widget.token ?? '')}&action=${Uri.encodeComponent(action)}');
        final resp = await http.get(cfUrl).timeout(const Duration(seconds: 12));
        debugPrint('SuggestionApprovalScreen: CF moderate status=${resp.statusCode} body=${resp.body}');
        if (resp.statusCode == 200) publishedViaCF = true;
      } catch (e) {
        debugPrint('SuggestionApprovalScreen: CF moderate request failed (will fallback to token status-only): $e');
      }

      if (!publishedViaCF) {
        // Fallback to status-only token update (rules-validated)
        await _db.collection('resource_suggestions').doc(widget.id).set({
          'status': isApprove ? 'approved' : 'rejected',
          if (isApprove) 'approvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'approvalToken': widget.token,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        final msg = isApprove
            ? (publishedViaCF ? 'Suggestion approved and published.' : 'Suggestion approved. Sign in to publish.')
            : 'Suggestion rejected.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        context.go('/');
      }
    } on FirebaseException catch (e) {
      debugPrint('SuggestionApprovalScreen: token action failed: ${e.code} ${e.message}');
      if (mounted) setState(() {
        if (e.code == 'permission-denied') {
          unauthorized = true;
          // Friendlier message for old emails or mismatched tokens
          error = 'This approval link could not be validated. It may be an older email or the token has expired. Please submit again or sign in as admin.';
        } else {
          error = e.message ?? e.code;
        }
      });
    } catch (e, st) {
      debugPrint('SuggestionApprovalScreen: token action failed: $e\n$st');
      if (mounted) setState(() { error = 'Failed: $e'; });
    } finally {
      if (mounted) setState(() { loading = false; acting = false; });
    }
  }

  Future<void> _setStatus(String status) async {
    setState(() => acting = true);
    try {
      await _db.collection('resource_suggestions').doc(widget.id).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to $status')));
        context.go('/');
      }
    } catch (e) {
      debugPrint('SuggestionApprovalScreen: setStatus failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Moderate Suggestion')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: loading
              ? const Center(child: CenteredLoadingSkeleton())
              : error != null
                  ? _UnauthorizedOrErrorView(
                      message: error!,
                      unauthorized: unauthorized,
                      signedInEmail: signedInEmail,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Suggestion ID: ${widget.id}', style: theme.textTheme.labelSmall),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (data?['resourceName'] ?? data?['name'] ?? 'Unnamed') as String,
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text('Type: ${(data?['type'] ?? 'service')}'),
                                const SizedBox(height: 8),
                                Text('Address: ${(data?['addressLine'] ?? data?['address'] ?? '')}'),
                                if ((data?['city'] ?? '').toString().isNotEmpty || (data?['stateProvince'] ?? data?['state'] ?? '').toString().isNotEmpty)
                                  Text('${(data?['city'] ?? '')}${((data?['city'] ?? '').toString().isNotEmpty && (data?['stateProvince'] ?? data?['state'] ?? '').toString().isNotEmpty) ? ', ' : ''}${(data?['stateProvince'] ?? data?['state'] ?? '')}'),
                                const SizedBox(height: 8),
                                Text('Phone: ${(data?['phone'] ?? '—')}'),
                                Text('Website: ${(data?['website'] ?? '—')}'),
                                Text('Email: ${(data?['contactEmail'] ?? '—')}'),
                                const SizedBox(height: 8),
                                Text('Specialties: ${((data?['specialties'] as List<dynamic>? ?? []).isEmpty) ? '—' : (data!['specialties'] as List<dynamic>).join(', ')}'),
                                const SizedBox(height: 12),
                                Text('Status: ${data?['status'] ?? 'pending'}', style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: acting ? null : _approve,
                              icon: const Icon(Icons.check, color: Colors.white),
                              label: const Text('Approve & Publish'),
                            ),
                            OutlinedButton.icon(
                              onPressed: acting ? null : _reject,
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

class _UnauthorizedOrErrorView extends StatelessWidget {
  const _UnauthorizedOrErrorView({required this.message, required this.unauthorized, this.signedInEmail});

  final String message;
  final bool unauthorized;
  final String? signedInEmail;

  void _goToSignIn(BuildContext context) {
    final from = Uri.encodeComponent(GoRouterState.of(context).uri.toString());
    context.go('/auth?from=$from');
  }

  Future<void> _signOutAndSwitch(BuildContext context) async {
    try {
      await auth.FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('SuggestionApprovalScreen: signOut error: $e');
    }
    _goToSignIn(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!unauthorized) {
      return Center(child: Text(message));
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, color: cs.error, size: 36),
            const SizedBox(height: 12),
            Text('Unauthorized', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (signedInEmail != null && signedInEmail!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Currently signed in as: $signedInEmail', style: Theme.of(context).textTheme.labelSmall),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _goToSignIn(context),
                  icon: Icon(Icons.login, color: cs.onPrimary),
                  label: Text('Sign in as admin', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onPrimary)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _signOutAndSwitch(context),
                  icon: const Icon(Icons.switch_account),
                  label: const Text('Switch account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
