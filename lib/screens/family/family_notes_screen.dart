import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wellspring/models/patient_connection.dart';
import 'package:wellspring/models/patient_note.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';

class FamilyNotesScreen extends StatefulWidget {
  const FamilyNotesScreen({super.key});

  @override
  State<FamilyNotesScreen> createState() => _FamilyNotesScreenState();
}

class _FamilyNotesScreenState extends State<FamilyNotesScreen> {
  final _familyService = FamilyService();
  final _userService = UserService();
  bool _showTutorial = false;
  bool _loading = true;
  String _search = '';
  PatientConnection? _connection;
  List<PatientNote> _notes = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _checkTutorial();
    await _loadData();
  }

  Future<void> _checkTutorial() async {
    final user = await _userService.getCurrentUser();
    if (user == null) return;
    final hasSeenTutorial = await _familyService.hasTutorialBeenSeen(user.id, 'notes');
    if (mounted) setState(() => _showTutorial = !hasSeenTutorial);
  }

  Future<void> _dismissTutorial() async {
    final user = await _userService.getCurrentUser();
    if (user != null) await _familyService.markTutorialSeen(user.id, 'notes');
    setState(() => _showTutorial = false);
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = await _userService.getCurrentUser();
      if (user == null) {
        setState(() => _loading = false);
        return;
      }
      final conn = await _familyService.getPrimaryConnection(user.id);
      if (conn == null) {
        setState(() {
          _connection = null;
          _notes = [];
          _loading = false;
        });
        return;
      }
      final notes = await _familyService.getPatientNotes(conn.patientId);
      if (!mounted) return;
      setState(() {
        _connection = conn;
        _notes = notes;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[FamilyNotesScreen] _loadData error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PatientNote> get _filtered {
    if (_search.isEmpty) return _notes;
    final q = _search.toLowerCase();
    return _notes
        .where((n) => n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.family_restroom, color: cs.primary, size: 20),
            const SizedBox(width: 10),
            Text('Adaptly Family',
                style: context.textStyles.titleMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0B0F14),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book, color: Colors.green, size: 28),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Care Notes',
                        style: context.textStyles.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Notes shared with you by the care team',
                    style: context.textStyles.bodyLarge?.withColor(cs.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: cs.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_connection == null)
                  _emptyState(cs,
                      icon: Icons.link_off,
                      title: 'Not connected',
                      subtitle: 'Connect to a patient to view shared notes.')
                else if (_filtered.isEmpty)
                  _emptyState(cs,
                      icon: Icons.menu_book_outlined,
                      title: 'No notes yet',
                      subtitle: 'Notes shared with family by the care team will appear here.')
                else
                  ..._filtered.map((n) => _NoteCard(note: n, onTap: () => _showNoteDetail(n))),
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
              ],
            ),
          ),
          if (_showTutorial)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
                child: SafeArea(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(AppSpacing.xl),
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                          color: cs.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.note_alt, size: 64, color: cs.primary),
                          const SizedBox(height: AppSpacing.lg),
                          Text('Care Notes',
                              style: context.textStyles.headlineSmall, textAlign: TextAlign.center),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Read notes that the care team has chosen to share with family.',
                            style: context.textStyles.bodyLarge?.withColor(cs.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          FilledButton(onPressed: _dismissTutorial, child: const Text('Got it')),
                        ],
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

  Widget _emptyState(ColorScheme cs,
      {required IconData icon, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration:
                BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
            child: Icon(icon, size: 48, color: cs.outline),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: context.textStyles.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle,
              style: context.textStyles.bodyMedium?.withColor(cs.outline),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _showNoteDetail(PatientNote note) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('MMMM d, yyyy • h:mm a').format(note.createdAt);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (note.pinned)
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: Icon(Icons.push_pin, size: 20, color: cs.primary),
                          ),
                        Expanded(child: Text(note.title, style: context.textStyles.titleLarge)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        note.noteTypeLabel,
                        style: context.textStyles.labelSmall?.copyWith(
                            color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(dateStr,
                        style: context.textStyles.labelSmall?.copyWith(color: cs.outline)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(note.body,
                      style: context.textStyles.bodyLarge?.copyWith(height: 1.6)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});
  final PatientNote note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('MMM d, yyyy').format(note.createdAt);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.pinned)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: Icon(Icons.push_pin, size: 16, color: cs.primary),
                    ),
                  Expanded(
                    child: Text(note.title,
                        style: context.textStyles.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(note.noteTypeLabel, style: context.textStyles.labelSmall),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(dateStr,
                  style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.md),
              Text(note.body,
                  style: context.textStyles.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
