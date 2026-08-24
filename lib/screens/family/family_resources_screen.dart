import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wellspring/models/patient_connection.dart';
import 'package:wellspring/models/patient_note.dart';
import 'package:wellspring/models/patient_resource.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';

enum ResourceTab { files, notes }

class FamilyResourcesScreen extends StatefulWidget {
  const FamilyResourcesScreen({super.key});

  @override
  State<FamilyResourcesScreen> createState() => _FamilyResourcesScreenState();
}

class _FamilyResourcesScreenState extends State<FamilyResourcesScreen> {
  final _familyService = FamilyService();
  final _userService = UserService();
  bool _showTutorial = false;
  ResourceTab _selectedTab = ResourceTab.files;

  bool _loading = true;
  String _search = '';
  PatientConnection? _connection;
  List<PatientResource> _resources = [];
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
    final hasSeenTutorial = await _familyService.hasTutorialBeenSeen(user.id, 'resources');
    if (mounted) setState(() => _showTutorial = !hasSeenTutorial);
  }

  Future<void> _dismissTutorial() async {
    final user = await _userService.getCurrentUser();
    if (user != null) await _familyService.markTutorialSeen(user.id, 'resources');
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
          _resources = [];
          _notes = [];
          _loading = false;
        });
        return;
      }
      final results = await Future.wait([
        _familyService.getPatientResources(conn.patientId),
        _familyService.getPatientNotes(conn.patientId),
      ]);
      if (!mounted) return;
      setState(() {
        _connection = conn;
        _resources = results[0] as List<PatientResource>;
        _notes = results[1] as List<PatientNote>;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[FamilyResourcesScreen] _loadData error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PatientResource> get _filteredResources {
    if (_search.isEmpty) return _resources;
    final q = _search.toLowerCase();
    return _resources.where((r) =>
        r.title.toLowerCase().contains(q) ||
        (r.description?.toLowerCase().contains(q) ?? false)).toList();
  }

  List<PatientNote> get _filteredNotes {
    if (_search.isEmpty) return _notes;
    final q = _search.toLowerCase();
    return _notes.where((n) =>
        n.title.toLowerCase().contains(q) ||
        n.body.toLowerCase().contains(q)).toList();
  }

  Future<void> _openResource(PatientResource resource) async {
    final urlStr = resource.url;
    if (urlStr == null || urlStr.isEmpty) {
      _showResourceDetail(resource);
      return;
    }
    final uri = Uri.tryParse(urlStr);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image.asset(
            isDark
              ? 'assets/images/ChatGPT_Image_Aug_3_2026_07_26_30_AM.png'
              : 'assets/images/Misty_Mountain_Sunrise_Road.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
            ),
          ),
        ),
        // Content
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.family_restroom, color: cs.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Adaptly Family',
              style: context.textStyles.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
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
                    Icon(Icons.folder, color: Colors.blue, size: 28),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Resources',
                      style: context.textStyles.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _selectedTab == ResourceTab.files
                      ? 'Files and materials shared by the care team'
                      : 'Notes shared with you by the care team',
                  style: context.textStyles.bodyLarge?.withColor(cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.lg),

                SegmentedButton<ResourceTab>(
                  segments: [
                    ButtonSegment(
                      value: ResourceTab.files,
                      label: Text('Files (${_resources.length})'),
                      icon: const Icon(Icons.insert_drive_file_outlined),
                    ),
                    ButtonSegment(
                      value: ResourceTab.notes,
                      label: Text('Notes (${_notes.length})'),
                      icon: const Icon(Icons.menu_book_outlined),
                    ),
                  ],
                  selected: {_selectedTab},
                  onSelectionChanged: (Set<ResourceTab> s) =>
                      setState(() => _selectedTab = s.first),
                  style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: _selectedTab == ResourceTab.files
                        ? 'Search resources...'
                        : 'Search notes...',
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
                  _EmptyState(
                    icon: Icons.link_off,
                    title: 'Not connected',
                    subtitle: 'Connect to a patient to view shared resources.',
                  )
                else if (_selectedTab == ResourceTab.files)
                  _buildFilesSection(cs)
                else
                  _buildNotesSection(cs),

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
                      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder, size: 64, color: cs.primary),
                          const SizedBox(height: AppSpacing.lg),
                          Text('Resources', style: context.textStyles.headlineSmall, textAlign: TextAlign.center),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Access files, guides, and care notes shared by your loved one\'s care team.',
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
        ),
      ],
    );
  }

  Widget _buildFilesSection(ColorScheme cs) {
    final list = _filteredResources;
    if (list.isEmpty) {
      return _EmptyState(
        icon: Icons.folder_open,
        title: 'No resources yet',
        subtitle: 'Files and materials shared by the care team will appear here.',
      );
    }
    return Column(
      children: list
          .map((r) => _ResourceCard(
                resource: r,
                onOpen: () => _openResource(r),
                onDetails: () => _showResourceDetail(r),
              ))
          .toList(),
    );
  }

  Widget _buildNotesSection(ColorScheme cs) {
    final list = _filteredNotes;
    if (list.isEmpty) {
      return _EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No notes yet',
        subtitle: 'Notes shared with family by the care team will appear here.',
      );
    }
    return Column(
      children: list.map((n) => _NoteCard(note: n, onTap: () => _showNoteDetail(n))).toList(),
    );
  }

  void _showResourceDetail(PatientResource resource) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('MMMM d, yyyy').format(resource.createdAt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    resource.typeLabel.toUpperCase(),
                    style: context.textStyles.labelSmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(resource.title, style: context.textStyles.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text('Shared on $dateStr',
                    style: context.textStyles.labelSmall?.copyWith(color: cs.outline)),
                if (resource.fileSize != null) ...[
                  const SizedBox(height: 4),
                  Text(_formatFileSize(resource.fileSize!),
                      style: context.textStyles.labelSmall?.copyWith(color: cs.outline)),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (resource.description != null && resource.description!.isNotEmpty) ...[
                  Text('Description',
                      style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(resource.description!,
                      style: context.textStyles.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant, height: 1.5)),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (resource.url != null && resource.url!.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openResource(resource),
                      icon: Icon(resource.isFileUpload ? Icons.download : Icons.open_in_new),
                      label: Text(resource.isFileUpload ? 'Download' : 'Open Link'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
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
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.resource,
    required this.onOpen,
    required this.onDetails,
  });

  final PatientResource resource;
  final VoidCallback onOpen;
  final VoidCallback onDetails;

  IconData get _icon {
    switch (resource.type) {
      case PatientResourceType.video: return Icons.play_circle_outline;
      case PatientResourceType.article: return Icons.article_outlined;
      case PatientResourceType.pdf: return Icons.picture_as_pdf_outlined;
      case PatientResourceType.exercise: return Icons.fitness_center;
      case PatientResourceType.link: return Icons.link;
      case PatientResourceType.other: return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('MMM d, yyyy').format(resource.createdAt);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onDetails,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(_icon, size: 32, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(resource.title,
                            style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainer,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(resource.typeLabel, style: context.textStyles.labelSmall),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (resource.description != null && resource.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(resource.description!,
                      style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(dateStr,
                      style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
                  if (resource.fileSize != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    Text(_formatFileSize(resource.fileSize!),
                        style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
                  ],
                ],
              ),
              if (resource.url != null && resource.url!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: Icon(resource.isFileUpload ? Icons.download : Icons.open_in_new),
                  label: Text(resource.isFileUpload ? 'Download' : 'Open Link'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
                        style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
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
}
