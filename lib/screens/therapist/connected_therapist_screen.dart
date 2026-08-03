import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wellspring/models/patient_note.dart';
import 'package:wellspring/models/patient_resource.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/therapist_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/skeletons.dart';

/// Screen displaying notes and resources from the user's connected therapist/healthcare provider.
class ConnectedTherapistScreen extends StatefulWidget {
  const ConnectedTherapistScreen({super.key});

  @override
  State<ConnectedTherapistScreen> createState() => _ConnectedTherapistScreenState();
}

class _ConnectedTherapistScreenState extends State<ConnectedTherapistScreen>
    with SingleTickerProviderStateMixin {
  final _therapistService = TherapistService();
  late TabController _tabController;

  bool _isLoading = true;
  List<PatientNote> _notes = [];
  List<PatientResource> _resources = [];
  Map<String, int> _summary = {};

  NoteType? _selectedNoteType;
  PatientResourceType? _selectedResourceType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final userId = context.read<UserProvider>().currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final results = await Future.wait([
        _therapistService.getNotesForPatient(userId),
        _therapistService.getResourcesForPatient(userId),
        _therapistService.getPatientSummary(userId),
      ]);

      if (mounted) {
        setState(() {
          _notes = results[0] as List<PatientNote>;
          _resources = results[1] as List<PatientResource>;
          _summary = results[2] as Map<String, int>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ConnectedTherapistScreen._loadData error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<PatientNote> get _filteredNotes {
    if (_selectedNoteType == null) return _notes;
    return _notes.where((n) => n.noteType == _selectedNoteType).toList();
  }

  List<PatientResource> get _filteredResources {
    if (_selectedResourceType == null) return _resources;
    return _resources.where((r) => r.type == _selectedResourceType).toList();
  }

  Future<void> _openResourceUrl(PatientResource resource) async {
    final urlStr = resource.url;
    if (urlStr == null || urlStr.isEmpty) return;

    final uri = Uri.tryParse(urlStr);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Care Team'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.note_alt_outlined),
              text: 'Notes (${_summary['totalNotes'] ?? 0})',
            ),
            Tab(
              icon: const Icon(Icons.library_books_outlined),
              text: 'Resources (${_summary['totalResources'] ?? 0})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CenteredLoadingSkeleton())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildNotesTab(cs),
                  _buildResourcesTab(cs),
                ],
              ),
            ),
    );
  }

  Widget _buildNotesTab(ColorScheme cs) {
    return Column(
      children: [
        // Summary card
        _buildNotesSummaryCard(cs),
        // Note type filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: FilterChip(
                  label: const Text('All'),
                  selected: _selectedNoteType == null,
                  onSelected: (_) => setState(() => _selectedNoteType = null),
                  selectedColor: cs.primaryContainer,
                  checkmarkColor: cs.onPrimaryContainer,
                ),
              ),
              ...NoteType.values.map((type) {
                final isSelected = type == _selectedNoteType;
                return Padding(
                  padding: EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: Text(_noteTypeLabel(type)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedNoteType = type),
                    selectedColor: cs.primaryContainer,
                    checkmarkColor: cs.onPrimaryContainer,
                  ),
                );
              }),
            ],
          ),
        ),
        // Notes list
        Expanded(
          child: _filteredNotes.isEmpty
              ? _buildEmptyState(
                  icon: Icons.note_alt_outlined,
                  title: 'No notes yet',
                  subtitle: 'Notes from your care team will appear here',
                )
              : ListView.builder(
                  padding: EdgeInsets.all(AppSpacing.md),
                  itemCount: _filteredNotes.length,
                  itemBuilder: (context, index) => _buildNoteCard(_filteredNotes[index], cs),
                ),
        ),
      ],
    );
  }

  String _noteTypeLabel(NoteType type) {
    switch (type) {
      case NoteType.session: return 'Session';
      case NoteType.progress: return 'Progress';
      case NoteType.observation: return 'Observation';
      case NoteType.goalUpdate: return 'Goal Update';
      case NoteType.general: return 'General';
    }
  }

  Widget _buildNotesSummaryCard(ColorScheme cs) {
    final pinnedCount = _summary['pinnedNotes'] ?? 0;

    return Container(
      margin: EdgeInsets.all(AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.primaryContainer.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.onPrimaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.medical_services_outlined, color: cs.onPrimaryContainer, size: 32),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Provider Notes',
                  style: context.textStyles.titleMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${_notes.length} total notes${pinnedCount > 0 ? ' • $pinnedCount pinned' : ''}',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(PatientNote note, ColorScheme cs) {
    final dateStr = DateFormat('MMM d, yyyy').format(note.createdAt);

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showNoteDetail(note),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.pinned)
                    Padding(
                      padding: EdgeInsets.only(right: AppSpacing.xs),
                      child: Icon(Icons.push_pin, size: 16, color: cs.primary),
                    ),
                  Expanded(
                    child: Text(
                      note.title,
                      style: context.textStyles.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getNoteTypeColor(note.noteType, cs).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      note.noteTypeLabel,
                      style: context.textStyles.labelSmall?.copyWith(
                        color: _getNoteTypeColor(note.noteType, cs),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                note.body,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: cs.outline),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Care Team',
                      style: context.textStyles.labelSmall?.copyWith(color: cs.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: context.textStyles.labelSmall?.copyWith(color: cs.outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getNoteTypeColor(NoteType type, ColorScheme cs) {
    switch (type) {
      case NoteType.session: return Colors.purple;
      case NoteType.progress: return Colors.green;
      case NoteType.observation: return Colors.orange;
      case NoteType.goalUpdate: return Colors.blue;
      case NoteType.general: return cs.primary;
    }
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
              // Handle
              Container(
                margin: EdgeInsets.only(top: AppSpacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (note.pinned)
                          Padding(
                            padding: EdgeInsets.only(right: AppSpacing.xs),
                            child: Icon(Icons.push_pin, size: 20, color: cs.primary),
                          ),
                        Expanded(
                          child: Text(
                            note.title,
                            style: context.textStyles.titleLarge,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.sm),
                    // Note type badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getNoteTypeColor(note.noteType, cs).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        note.noteTypeLabel,
                        style: context.textStyles.labelSmall?.copyWith(
                          color: _getNoteTypeColor(note.noteType, cs),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: cs.primaryContainer,
                          child: Icon(Icons.person, size: 16, color: cs.onPrimaryContainer),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'Care Team',
                          style: context.textStyles.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      dateStr,
                      style: context.textStyles.labelSmall?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    note.body,
                    style: context.textStyles.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourcesTab(ColorScheme cs) {
    final fileCount = _summary['fileResources'] ?? 0;
    final linkCount = _summary['linkResources'] ?? 0;

    return Column(
      children: [
        // Summary card
        Container(
          margin: EdgeInsets.all(AppSpacing.md),
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.secondaryContainer, cs.secondaryContainer.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _buildStatItem(
                icon: Icons.insert_drive_file_outlined,
                value: fileCount.toString(),
                label: 'Files',
                color: Colors.blue,
              ),
              Container(
                width: 1,
                height: 40,
                color: cs.onSecondaryContainer.withValues(alpha: 0.2),
                margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              _buildStatItem(
                icon: Icons.link,
                value: linkCount.toString(),
                label: 'Links',
                color: Colors.green,
              ),
            ],
          ),
        ),
        // Resource type filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: FilterChip(
                  label: const Text('All'),
                  selected: _selectedResourceType == null,
                  onSelected: (_) => setState(() => _selectedResourceType = null),
                  selectedColor: cs.secondaryContainer,
                  checkmarkColor: cs.onSecondaryContainer,
                ),
              ),
              ...PatientResourceType.values.map((type) {
                final isSelected = type == _selectedResourceType;
                return Padding(
                  padding: EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: Text(_resourceTypeLabel(type)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedResourceType = type),
                    selectedColor: cs.secondaryContainer,
                    checkmarkColor: cs.onSecondaryContainer,
                  ),
                );
              }),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        // Resources list
        Expanded(
          child: _filteredResources.isEmpty
              ? _buildEmptyState(
                  icon: Icons.library_books_outlined,
                  title: 'No resources yet',
                  subtitle: 'Resources shared by your care team will appear here',
                )
              : ListView.builder(
                  padding: EdgeInsets.all(AppSpacing.md),
                  itemCount: _filteredResources.length,
                  itemBuilder: (context, index) => _buildResourceCard(_filteredResources[index], cs),
                ),
        ),
      ],
    );
  }

  String _resourceTypeLabel(PatientResourceType type) {
    switch (type) {
      case PatientResourceType.exercise: return 'Exercise';
      case PatientResourceType.pdf: return 'PDF';
      case PatientResourceType.video: return 'Video';
      case PatientResourceType.article: return 'Article';
      case PatientResourceType.link: return 'Link';
      case PatientResourceType.other: return 'Other';
    }
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: context.textStyles.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: context.textStyles.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResourceCard(PatientResource resource, ColorScheme cs) {
    final dateStr = DateFormat('MMM d, yyyy').format(resource.createdAt);

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showResourceDetail(resource),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resource type icon
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: _getResourceTypeColor(resource.type, cs).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getResourceTypeIcon(resource.type),
                  color: _getResourceTypeColor(resource.type, cs),
                  size: 24,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: context.textStyles.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (resource.description != null) ...[
                      SizedBox(height: 4),
                      Text(
                        resource.description!,
                        style: context.textStyles.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            resource.typeLabel,
                            style: context.textStyles.labelSmall,
                          ),
                        ),
                        if (resource.isFileUpload) ...[
                          SizedBox(width: AppSpacing.sm),
                          Icon(Icons.cloud_download_outlined, size: 14, color: cs.outline),
                        ],
                        const Spacer(),
                        Text(
                          dateStr,
                          style: context.textStyles.labelSmall?.copyWith(color: cs.outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Open icon
              if (resource.url != null)
                IconButton(
                  icon: Icon(Icons.open_in_new, color: cs.primary),
                  onPressed: () => _openResourceUrl(resource),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getResourceTypeIcon(PatientResourceType type) {
    switch (type) {
      case PatientResourceType.video: return Icons.play_circle_outline;
      case PatientResourceType.article: return Icons.article_outlined;
      case PatientResourceType.pdf: return Icons.picture_as_pdf_outlined;
      case PatientResourceType.exercise: return Icons.fitness_center;
      case PatientResourceType.link: return Icons.link;
      case PatientResourceType.other: return Icons.folder_outlined;
    }
  }

  Color _getResourceTypeColor(PatientResourceType type, ColorScheme cs) {
    switch (type) {
      case PatientResourceType.video: return Colors.red;
      case PatientResourceType.article: return Colors.blue;
      case PatientResourceType.pdf: return Colors.deepOrange;
      case PatientResourceType.exercise: return Colors.green;
      case PatientResourceType.link: return Colors.purple;
      case PatientResourceType.other: return cs.primary;
    }
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
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
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
                SizedBox(height: AppSpacing.lg),
                // Type badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getResourceTypeColor(resource.type, cs).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getResourceTypeIcon(resource.type),
                        size: 16,
                        color: _getResourceTypeColor(resource.type, cs),
                      ),
                      SizedBox(width: 6),
                      Text(
                        resource.typeLabel.toUpperCase(),
                        style: context.textStyles.labelSmall?.copyWith(
                          color: _getResourceTypeColor(resource.type, cs),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                // Title
                Text(
                  resource.title,
                  style: context.textStyles.titleLarge,
                ),
                SizedBox(height: AppSpacing.sm),
                // Provider info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: cs.secondaryContainer,
                      child: Icon(Icons.person, size: 16, color: cs.onSecondaryContainer),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      'Care Team',
                      style: context.textStyles.labelMedium,
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Shared on $dateStr',
                  style: context.textStyles.labelSmall?.copyWith(color: cs.outline),
                ),
                // File info
                if (resource.isFileUpload) ...[
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.insert_drive_file_outlined, size: 14, color: cs.outline),
                      SizedBox(width: 4),
                      Text(
                        resource.mimeType ?? 'File',
                        style: context.textStyles.labelSmall?.copyWith(color: cs.outline),
                      ),
                      if (resource.fileSize != null) ...[
                        Text(' • ', style: context.textStyles.labelSmall?.copyWith(color: cs.outline)),
                        Text(
                          _formatFileSize(resource.fileSize!),
                          style: context.textStyles.labelSmall?.copyWith(color: cs.outline),
                        ),
                      ],
                    ],
                  ),
                ],
                SizedBox(height: AppSpacing.lg),
                // Description
                if (resource.description != null) ...[
                  Text(
                    'Description',
                    style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    resource.description!,
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg),
                ],
                // Action button
                if (resource.url != null && resource.url!.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openResourceUrl(resource),
                      icon: Icon(resource.isFileUpload ? Icons.download : Icons.open_in_new),
                      label: Text(resource.isFileUpload ? 'Download' : 'Open Link'),
                    ),
                  ),
                SizedBox(height: AppSpacing.lg),
              ],
            ),
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: cs.outline),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: context.textStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: context.textStyles.bodyMedium?.copyWith(color: cs.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
