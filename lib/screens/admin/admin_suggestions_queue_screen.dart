import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/services/resource_suggestion_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/models/resource_suggestion.dart';

class AdminSuggestionsQueueScreen extends StatefulWidget {
  const AdminSuggestionsQueueScreen({super.key});

  @override
  State<AdminSuggestionsQueueScreen> createState() =>
      _AdminSuggestionsQueueScreenState();
}

class _AdminSuggestionsQueueScreenState
    extends State<AdminSuggestionsQueueScreen> {
  final _supabase = SupabaseConfig.client;
  final _service = ResourceSuggestionService();

  final _searchCtrl = TextEditingController();
  String _typeFilter = 'all';
  bool _acting = false;
  String? _error;
  bool _backfilling = false;
  List<ResourceSuggestion> _suggestions = [];
  bool _loading = true;

  bool get _isAdminEmail {
    final email = SupabaseConfig.auth.currentUser?.email?.toLowerCase();
    return email == 'adaptlyapp@gmail.com' || email == 'dpaine170014@gmail.com';
  }

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loading = true);
    try {
      var query = _supabase
          .from('resource_suggestions')
          .select()
          .eq('status', 'pending');

      if (_typeFilter != 'all') {
        query = query.eq('type', _typeFilter);
      }

      final response =
          await query.order('created_at', ascending: false).limit(200);
      final list = <ResourceSuggestion>[];
      for (final row in response) {
        try {
          final id = row['id'].toString();
          list.add(ResourceSuggestion.fromJson(row, id));
        } catch (e) {
          debugPrint('Failed to parse suggestion: $e');
        }
      }

      if (mounted) {
        setState(() {
          _suggestions = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('AdminSuggestionsQueueScreen._loadSuggestions error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load suggestions: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _approve(String id) async {
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      await _service.approveSuggestionAndPublish(id);
      await _loadSuggestions(); // Reload the list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Approved & published')));
      }
    } catch (e) {
      debugPrint('AdminSuggestionsQueueScreen.approve error: $e');
      setState(() {
        _error = 'Failed to approve: $e';
      });
    } finally {
      if (mounted)
        setState(() {
          _acting = false;
        });
    }
  }

  Future<void> _reject(String id) async {
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      await _service.rejectSuggestion(id);
      await _loadSuggestions(); // Reload the list
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Rejected')));
      }
    } catch (e) {
      debugPrint('AdminSuggestionsQueueScreen.reject error: $e');
      setState(() {
        _error = 'Failed to reject: $e';
      });
    } finally {
      if (mounted)
        setState(() {
          _acting = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_isAdminEmail) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pending Approvals'),
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
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, color: cs.error, size: 36),
                const SizedBox(height: 12),
                const Text('Unauthorized'),
                const SizedBox(height: 8),
                const Text(
                    'Sign in with an admin account to view the approvals queue.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.go(
                      '/auth?from=${Uri.encodeComponent('/admin/suggestions')}'),
                  icon: Icon(Icons.login, color: cs.onPrimary),
                  label: Text('Sign in as admin',
                      style: TextStyle(color: cs.onPrimary)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
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
        actions: [
          IconButton(
            tooltip: 'Data Migration',
            onPressed: () => context.push('/admin/migration'),
            icon: const Icon(Icons.sync, color: Colors.black),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadSuggestions,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search by name, city, specialty'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _typeFilter,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All types')),
                      DropdownMenuItem(
                          value: 'service', child: Text('Service')),
                      DropdownMenuItem(
                          value: 'therapist', child: Text('Therapist')),
                      DropdownMenuItem(value: 'center', child: Text('Center')),
                      DropdownMenuItem(
                          value: 'hospital', child: Text('Hospital')),
                      DropdownMenuItem(
                          value: 'pharmacy', child: Text('Pharmacy')),
                    ],
                    onChanged: (v) {
                      setState(() => _typeFilter = v ?? 'all');
                      _loadSuggestions();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_backfilling) const LinearProgressIndicator(minHeight: 2),
              if (_error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_error!, style: TextStyle(color: cs.error)),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CenteredLoadingSkeleton())
                    : _buildSuggestionsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _suggestions.where((s) {
      if (query.isEmpty) return true;
      final hay = [
        s.name,
        s.city ?? '',
        s.state ?? '',
        (s.specialties).join(', '),
      ].join(' ').toLowerCase();
      return hay.contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No pending suggestions'));
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = filtered[i];
        final subtitle = [
          s.type,
          s.city ?? '',
          s.state ?? '',
        ].where((str) => str.trim().isNotEmpty).join(' • ');

        return Card(
          child: ListTile(
            title: Text(s.name),
            subtitle: Text(subtitle),
            onTap: () => context.push('/admin/suggestions/approval?id=${s.id}'),
            trailing: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _acting ? null : () => _reject(s.id),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Reject'),
                ),
                FilledButton.icon(
                  onPressed: _acting ? null : () => _approve(s.id),
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('Approve'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


}
