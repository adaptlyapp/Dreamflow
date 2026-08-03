import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/supabase/supabase_config.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:wellspring/theme.dart';

class PinUserSheet extends StatefulWidget {
  const PinUserSheet({super.key});

  @override
  State<PinUserSheet> createState() => _PinUserSheetState();
}

class _PinUserSheetState extends State<PinUserSheet> {
  final _controller = TextEditingController();
  final _userService = UserService();
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];
  Set<String> _pinned = {};

  @override
  void initState() {
    super.initState();
    _loadPinned();
  }

  Future<void> _loadPinned() async {
    final pinned = await _userService.getPinnedUsersOnce();
    if (!mounted) return;
    setState(() => _pinned = pinned.map((e) => e['id'] as String).toSet());
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    try {
      setState(() => _loading = true);
      final me = context.read<UserProvider>().currentUser;
      final supabase = SupabaseConfig.client;
      
      final data = await supabase
          .from('users')
          .select()
          .ilike('name', '%${query.trim()}%')
          .limit(20);
      
      final items = (data as List)
          .map((e) => e as Map<String, dynamic>)
          .where((e) => e['id'] != me?.id)
          .toList();
      
      if (!mounted) return;
      setState(() {
        _results = items;
        _loading = false;
      });
    } catch (e) {
      debugPrint('PinUserSheet._search error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _togglePin(Map<String, dynamic> user) async {
    try {
      final id = user['id'] as String;
      if (_pinned.contains(id)) {
        await _userService.unpinUser(id);
        if (!mounted) return;
        setState(() => _pinned.remove(id));
      } else {
        await _userService.pinUser(
          targetUserId: id,
          targetName: user['name'] ?? 'User',
          targetImageUrl: user['profileImageUrl'],
        );
        if (!mounted) return;
        setState(() => _pinned.add(id));
      }
    } catch (e) {
      debugPrint('PinUserSheet._togglePin error: $e');
      if (!mounted) return;
      String message = 'Unable to update pin';
      if (e is PostgrestException) {
        message = 'Unable to update pin — ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Pin profiles', style: context.textStyles.titleLarge?.semiBold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _controller,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Search by name',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            if (_loading)
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: const Center(child: CenteredLoadingSkeleton()),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemBuilder: (context, index) {
                    final u = _results[index];
                    final id = u['id'] as String;
                    final name = u['name'] ?? 'User';
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 0),
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Text((name as String).isNotEmpty ? name[0].toUpperCase() : '?',
                            style: context.textStyles.titleMedium?.withColor(cs.onPrimaryContainer)),
                      ),
                      title: Text(name),
                      trailing: TextButton.icon(
                        onPressed: () => _togglePin(u),
                        icon: Icon(_pinned.contains(id) ? Icons.push_pin : Icons.push_pin_outlined),
                        label: Text(_pinned.contains(id) ? 'Unpin' : 'Pin'),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemCount: _results.length,
                ),
              ),
            SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
