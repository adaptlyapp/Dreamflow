import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wellspring/models/education_resource.dart';
import 'package:wellspring/models/goal.dart';
import 'package:wellspring/models/milestone.dart';
import 'package:wellspring/models/patient_connection.dart';
import 'package:wellspring/models/medical_supply.dart';
import 'package:wellspring/services/education_service.dart';
import 'package:wellspring/services/family_service.dart';
import 'package:wellspring/services/goal_service.dart';
import 'package:wellspring/services/milestone_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/services/medical_supply_service.dart';
import 'package:wellspring/theme.dart';

/// Audience for the Education Hub. `family` uses the patient connection to
/// pull conditions for the linked patient; `patient` uses the signed-in
/// user's own conditions directly.
enum EducationAudience { family, patient }

class FamilyEducationScreen extends StatefulWidget {
  const FamilyEducationScreen({
    super.key,
    this.audience = EducationAudience.family,
  });

  final EducationAudience audience;

  @override
  State<FamilyEducationScreen> createState() => _FamilyEducationScreenState();
}

class _FamilyEducationScreenState extends State<FamilyEducationScreen>
    with SingleTickerProviderStateMixin {
  final _familyService = FamilyService();
  final _userService = UserService();
  final _goalService = GoalService();
  final _milestoneService = MilestoneService();
  final _eduService = EducationService.instance;
  final _supplyService = MedicalSupplyService.instance;

  late final TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _supplySearchCtrl = TextEditingController();

  bool _loading = true;
  String _userId = '';
  PatientConnection? _connection;
  List<String> _patientConditions = [];
  Map<String, List<EducationResource>> _recommendedByCondition = {};
  List<EducationResource> _genericRecommended = [];
  Set<String> _favoriteIds = <String>{};
  String _search = '';
  String _selectedCategory = 'All';
  String _supplySearch = '';
  String? _selectedSupplyCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _supplySearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await _userService.getCurrentUser();
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      _userId = user.id;
      final isPatient = widget.audience == EducationAudience.patient;
      final conn = isPatient
          ? null
          : await _familyService.getPrimaryConnection(user.id);

      final hints = <String>[];
      List<String> conditions = const [];
      // Determine whose conditions/goals/milestones to use.
      final String? subjectId = isPatient ? user.id : conn?.patientId;
      if (isPatient) {
        conditions = user.conditions;
      }
      if (subjectId != null) {
        if (!isPatient) {
          try {
            final patient = await _userService.getUserById(subjectId);
            conditions = patient?.conditions ?? const [];
          } catch (e) {
            debugPrint('[Education] patient fetch error: $e');
          }
        }
        try {
          final goals = await _goalService.getActiveGoals(subjectId);
          for (final Goal g in goals) {
            hints.add(g.title);
            final desc = g.description;
            if (desc != null && desc.isNotEmpty) hints.add(desc);
          }
          final milestones =
              await _milestoneService.list(userId: subjectId);
          for (final Milestone m in milestones) {
            hints.add(m.title);
          }
        } catch (e) {
          debugPrint('[FamilyEducation] hint fetch error: $e');
        }
      }

      final favs = await _eduService.getFavorites(user.id);
      final byCondition = conditions.isEmpty
          ? <String, List<EducationResource>>{}
          : _eduService.recommendedByCondition(conditions);
      // Fallback: if no condition mapped, use goal/milestone hints
      final generic = byCondition.isEmpty
          ? _eduService.recommendedFor(hints, limit: 6)
          : <EducationResource>[];

      if (!mounted) return;
      setState(() {
        _connection = conn;
        _patientConditions = conditions;
        _recommendedByCondition = byCondition;
        _genericRecommended = generic;
        _favoriteIds = favs;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[FamilyEducation] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite(EducationResource r) async {
    if (_userId.isEmpty) return;
    final updated = await _eduService.toggleFavorite(_userId, r.id);
    if (!mounted) return;
    setState(() => _favoriteIds = updated);
  }

  List<EducationResource> get _filteredAll {
    var list = _eduService.all();
    if (_selectedCategory != 'All') {
      list = list.where((r) => r.category == _selectedCategory).toList();
    }
    if (_search.isNotEmpty) {
      list = list.where((r) => r.matchesQuery(_search)).toList();
    }
    return list;
  }

  List<EducationResource> get _savedList =>
      _eduService.all().where((r) => _favoriteIds.contains(r.id)).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F14),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, color: cs.primary, size: 22),
            const SizedBox(width: 10),
            Text(
              'Education Hub',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(widget.audience == EducationAudience.patient
                  ? '/'
                  : '/family/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: cs.primary,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelPadding: const EdgeInsets.symmetric(horizontal: 0),
            tabs: const [
              Tab(icon: Icon(Icons.star_outline), text: 'For You'),
              Tab(icon: Icon(Icons.grid_view_rounded), text: 'Browse'),
              Tab(icon: Icon(Icons.medical_services_outlined), text: 'Supplies'),
              Tab(icon: Icon(Icons.bookmark_outline), text: 'Saved'),
            ],
          ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildForYou(cs),
                  _buildBrowse(cs),
                  _buildSupplies(cs),
                  _buildSaved(cs),
                ],
              ),
            ),
    );
  }

  // ---------- For You ----------
  Widget _buildForYou(ColorScheme cs) {
    final isPatient = widget.audience == EducationAudience.patient;
    final patientName = _connection?.patientName;
    final hasConditionMatches = _recommendedByCondition.isNotEmpty;
    String subtitle;
    if (hasConditionMatches) {
      final who = isPatient ? 'your' : '${patientName ?? 'your loved one'}\'s';
      subtitle =
          'Curated to $who condition${_patientConditions.length == 1 ? '' : 's'}: ${_patientConditions.join(", ")}.';
    } else {
      subtitle = 'Trusted education from MedlinePlus and NIH-backed sources.';
    }
    final heroTitle = isPatient
        ? 'Recommended for you'
        : (patientName != null
            ? 'Recommended for $patientName'
            : 'Recommended for your family');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _HeroBanner(
          title: heroTitle,
          subtitle: subtitle,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (hasConditionMatches) ...[
          for (final entry in _recommendedByCondition.entries) ...[
            _SectionHeader(
              icon: Icons.medical_information_outlined,
              title: 'For ${entry.key}',
            ),
            const SizedBox(height: AppSpacing.sm),
            ...entry.value.map((r) => _ResourceCard(
                  resource: r,
                  isFavorite: _favoriteIds.contains(r.id),
                  onTap: () => _openDetail(r),
                  onFavorite: () => _toggleFavorite(r),
                )),
            const SizedBox(height: AppSpacing.lg),
          ],
        ] else if (_genericRecommended.isNotEmpty) ...[
          ..._genericRecommended.map((r) => _ResourceCard(
                resource: r,
                isFavorite: _favoriteIds.contains(r.id),
                onTap: () => _openDetail(r),
                onFavorite: () => _toggleFavorite(r),
              )),
        ] else
          _EmptyState(
            icon: Icons.auto_awesome,
            title: 'Personalizing your hub',
            subtitle: isPatient
                ? 'As your conditions, goals, and milestones are added, we\'ll surface the most relevant content here.'
                : 'As your loved one\'s conditions, goals, and milestones are added, we\'ll surface the most relevant content here.',
          ),
        const SizedBox(height: AppSpacing.lg),
        _SectionHeader(
          icon: Icons.favorite_outline,
          title: 'Caregiver Essentials',
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._eduService
            .byCategory('Caregiver Education')
            .map((r) => _ResourceCard(
                  resource: r,
                  isFavorite: _favoriteIds.contains(r.id),
                  onTap: () => _openDetail(r),
                  onFavorite: () => _toggleFavorite(r),
                )),
        const SizedBox(height: AppSpacing.xl),
        _SectionHeader(
          icon: Icons.video_library_outlined,
          title: 'Educational Video Library',
        ),
        const SizedBox(height: AppSpacing.md),
        ..._videosForPatient().map((r) => _ResourceCard(
              resource: r,
              isFavorite: _favoriteIds.contains(r.id),
              onTap: () => _openDetail(r),
              onFavorite: () => _toggleFavorite(r),
            )),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  /// Videos filtered to the patient's conditions (falls back to all videos).
  List<EducationResource> _videosForPatient() {
    final allVideos = _eduService
        .all()
        .where((r) => r.type == EducationResourceType.video)
        .toList();
    if (_recommendedByCondition.isEmpty) return allVideos;
    final categories =
        _recommendedByCondition.values.expand((l) => l).map((r) => r.category).toSet();
    final filtered =
        allVideos.where((v) => categories.contains(v.category)).toList();
    return filtered.isEmpty ? allVideos : filtered;
  }

  // ---------- Browse ----------
  Widget _buildBrowse(ColorScheme cs) {
    final categories = ['All', ...EducationService.categories];
    final list = _filteredAll;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search by keyword, condition, symptom…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                    },
                  ),
            filled: true,
            fillColor: cs.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) {
              final c = categories[i];
              final selected = _selectedCategory == c;
              return ChoiceChip(
                label: Text(c),
                selected: selected,
                onSelected: (_) => setState(() => _selectedCategory = c),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${list.length} ${list.length == 1 ? 'resource' : 'resources'}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (list.isEmpty)
          _EmptyState(
            icon: Icons.search_off,
            title: 'No matches',
            subtitle: 'Try a different keyword or category.',
          )
        else
          ...list.map((r) => _ResourceCard(
                resource: r,
                isFavorite: _favoriteIds.contains(r.id),
                onTap: () => _openDetail(r),
                onFavorite: () => _toggleFavorite(r),
              )),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  // ---------- Saved ----------
  Widget _buildSaved(ColorScheme cs) {
    final saved = _savedList;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (saved.isEmpty)
          _EmptyState(
            icon: Icons.bookmark_outline,
            title: 'No saved resources yet',
            subtitle:
                'Tap the bookmark icon on any resource to save it here for quick access.',
          )
        else
          ...saved.map((r) => _ResourceCard(
                resource: r,
                isFavorite: true,
                onTap: () => _openDetail(r),
                onFavorite: () => _toggleFavorite(r),
              )),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  void _openDetail(EducationResource r) {
    context.push('/family/education/detail', extra: r);
  }

  // ---------- Supplies ----------
  Widget _buildSupplies(ColorScheme cs) {
    if (_selectedSupplyCategory != null) {
      return _buildSupplyCategoryDetail(cs, _selectedSupplyCategory!);
    }

    final categories = MedicalSupplyService.categories;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primaryContainer,
                cs.secondaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Text('🏥', style: TextStyle(fontSize: 40)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medical Supplies & Equipment',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Comprehensive guides for catheters, mobility aids, wound care, and more',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Browse by Category',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.4,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return _SupplyCategoryCard(
              category: category,
              onTap: () => setState(() => _selectedSupplyCategory = category.id),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildSupplyCategoryDetail(ColorScheme cs, String categoryId) {
    final category = _supplyService.getCategoryById(categoryId);
    final supplies = _supplyService.byCategory(categoryId);
    final filteredSupplies = _supplySearch.isEmpty
        ? supplies
        : supplies.where((s) => s.matchesQuery(_supplySearch)).toList();

    if (category == null) {
      return const Center(child: Text('Category not found'));
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                _selectedSupplyCategory = null;
                _supplySearch = '';
                _supplySearchCtrl.clear();
              }),
            ),
            const SizedBox(width: 8),
            Text(
              category.emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    category.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _supplySearchCtrl,
          onChanged: (v) => setState(() => _supplySearch = v),
          decoration: InputDecoration(
            hintText: 'Search supplies...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _supplySearch.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _supplySearchCtrl.clear();
                      setState(() => _supplySearch = '');
                    },
                  ),
            filled: true,
            fillColor: cs.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (filteredSupplies.isEmpty)
          _EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No supplies found',
            subtitle: _supplySearch.isEmpty
                ? 'More supplies coming soon to this category'
                : 'Try different search terms',
          )
        else
          ...filteredSupplies.map((supply) => _SupplyCard(
                supply: supply,
                onTap: () => _showSupplyDetail(supply),
              )),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  void _showSupplyDetail(MedicalSupply supply) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _SupplyDetailSheet(supply: supply),
    );
  }
}

// =====================================================================
// Components
// =====================================================================

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.25),
            cs.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, color: cs.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: cs.primary, size: 22),
        const SizedBox(width: AppSpacing.sm),
        Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
      ],
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.resource,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  final EducationResource resource;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  IconData get _typeIcon {
    switch (resource.type) {
      case EducationResourceType.video:
        return Icons.play_circle_fill;
      case EducationResourceType.article:
        return Icons.article_outlined;
      case EducationResourceType.guide:
        return Icons.menu_book_outlined;
      case EducationResourceType.anatomy:
        return Icons.accessibility_new;
    }
  }

  Color _typeColor(ColorScheme cs) {
    switch (resource.type) {
      case EducationResourceType.video:
        return const Color(0xFFEF4444);
      case EducationResourceType.article:
        return const Color(0xFF3B82F6);
      case EducationResourceType.guide:
        return const Color(0xFF10B981);
      case EducationResourceType.anatomy:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _typeColor(cs);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(_typeIcon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resource.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.3,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Pill(
                          label: resource.type.label,
                          color: accent,
                        ),
                        _Pill(
                          label: resource.category,
                          color: cs.primary,
                        ),
                        _Pill(
                          label: '${resource.estimatedMinutes} min',
                          color: cs.outline,
                          filled: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFavorite,
                tooltip: isFavorite ? 'Remove from saved' : 'Save',
                icon: Icon(
                  isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                  color: isFavorite ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    this.filled = true,
  });
  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: color.withValues(alpha: filled ? 0.0 : 0.4),
            width: filled ? 0 : 1),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: filled ? color : color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});
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
            child: Icon(icon, size: 40, color: cs.outline),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// =====================================================================
// Detail Screen
// =====================================================================

class FamilyEducationDetailScreen extends StatefulWidget {
  const FamilyEducationDetailScreen({super.key, required this.resource});
  final EducationResource resource;

  @override
  State<FamilyEducationDetailScreen> createState() =>
      _FamilyEducationDetailScreenState();
}

class _FamilyEducationDetailScreenState
    extends State<FamilyEducationDetailScreen> {
  final _eduService = EducationService.instance;
  final _userService = UserService();

  String _userId = '';
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _initFavorite();
  }

  Future<void> _initFavorite() async {
    final user = await _userService.getCurrentUser();
    if (user == null) return;
    _userId = user.id;
    final fav = await _eduService.isFavorite(user.id, widget.resource.id);
    if (!mounted) return;
    setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    if (_userId.isEmpty) return;
    final updated =
        await _eduService.toggleFavorite(_userId, widget.resource.id);
    if (!mounted) return;
    setState(() => _isFavorite = updated.contains(widget.resource.id));
  }

  Future<void> _openSource() async {
    final uri = Uri.tryParse(widget.resource.url);
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    } catch (e) {
      debugPrint('[EducationDetail] launch error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = widget.resource;
    final related = _eduService.related(r);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F14),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/family/education'),
        ),
        title: Text(
          r.type.label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.bookmark : Icons.bookmark_outline,
              color: Colors.white,
            ),
            tooltip: _isFavorite ? 'Remove from saved' : 'Save',
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Hero(resource: r),
          const SizedBox(height: AppSpacing.lg),
          Text(r.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.verified_outlined,
                  size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'Source: ${r.sourceName}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.schedule, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '${r.estimatedMinutes} min',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openSource,
              icon: Icon(r.type == EducationResourceType.video
                  ? Icons.play_arrow
                  : Icons.open_in_new),
              label: Text(r.type == EducationResourceType.video
                  ? 'Watch on ${r.sourceName}'
                  : 'Open on ${r.sourceName}'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(icon: Icons.summarize_outlined, title: 'Summary'),
          const SizedBox(height: AppSpacing.sm),
          Text(r.summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(
              icon: Icons.check_circle_outline, title: 'Key Takeaways'),
          const SizedBox(height: AppSpacing.sm),
          ...r.keyTakeaways.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, color: cs.primary, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      t,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(
              icon: Icons.lightbulb_outline, title: 'Why It Matters'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              border:
                  Border.all(color: cs.primary.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              r.whyItMatters,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.5),
            ),
          ),
          if (related.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            _SectionTitle(
                icon: Icons.layers_outlined, title: 'Related Resources'),
            const SizedBox(height: AppSpacing.sm),
            ...related.map((rel) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: Icon(
                      rel.type == EducationResourceType.video
                          ? Icons.play_circle_fill
                          : Icons.article_outlined,
                      color: cs.primary,
                    ),
                    title: Text(rel.title,
                        style: Theme.of(context).textTheme.titleSmall),
                    subtitle: Text(rel.type.label,
                        style: Theme.of(context).textTheme.labelSmall),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/family/education/detail',
                        extra: rel),
                  ),
                )),
          ],
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Educational content only — not medical advice. Always confirm with your care team.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.resource});
  final EducationResource resource;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color accent;
    IconData icon;
    switch (resource.type) {
      case EducationResourceType.video:
        accent = const Color(0xFFEF4444);
        icon = Icons.play_circle_fill;
        break;
      case EducationResourceType.article:
        accent = const Color(0xFF3B82F6);
        icon = Icons.article_outlined;
        break;
      case EducationResourceType.guide:
        accent = const Color(0xFF10B981);
        icon = Icons.menu_book_outlined;
        break;
      case EducationResourceType.anatomy:
        accent = const Color(0xFFF59E0B);
        icon = Icons.accessibility_new;
        break;
    }
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(icon,
                size: 80, color: Colors.white.withValues(alpha: 0.95)),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                resource.category,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                resource.sourceName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          // bottom-left to avoid using onSurface
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.0),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: cs.primary, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// =====================================================================
// Medical Supplies Components
// =====================================================================

class _SupplyCategoryCard extends StatelessWidget {
  final SupplyCategory category;
  final VoidCallback onTap;

  const _SupplyCategoryCard({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primaryContainer.withValues(alpha: 0.4),
                cs.secondaryContainer.withValues(alpha: 0.4),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                category.emoji,
                style: const TextStyle(fontSize: 36),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  category.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplyCard extends StatelessWidget {
  final MedicalSupply supply;
  final VoidCallback onTap;

  const _SupplyCard({
    required this.supply,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              if (supply.iconEmoji != null) ...[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Center(
                    child: Text(
                      supply.iconEmoji!,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supply.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      supply.whoUsesIt,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.3,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (supply.commonBrands.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: supply.commonBrands.take(2).map((brand) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              brand,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplyDetailSheet extends StatelessWidget {
  final MedicalSupply supply;

  const _SupplyDetailSheet({required this.supply});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  if (supply.iconEmoji != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        supply.iconEmoji!,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Text(
                      supply.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  _buildSection(
                    context,
                    icon: Icons.info_outline,
                    title: 'What is it?',
                    child: Text(supply.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSection(
                    context,
                    icon: Icons.person_outline,
                    title: 'Who uses it?',
                    child: Text(supply.whoUsesIt, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                  ),
                  if (supply.commonBrands.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildSection(
                      context,
                      icon: Icons.label_outline,
                      title: 'Common Brands',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: supply.commonBrands.map((brand) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text(brand, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  if (supply.resources.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildSection(
                      context,
                      icon: Icons.school_outlined,
                      title: 'Educational Resources',
                      child: Column(
                        children: supply.resources.map((resource) {
                          return _ResourceLinkCard(resource: resource);
                        }).toList(),
                      ),
                    ),
                  ],
                  if (supply.maintenance != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildSection(
                      context,
                      icon: Icons.cleaning_services_outlined,
                      title: 'Maintenance',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cleaning:', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(supply.maintenance!.cleaningInstructions, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                          const SizedBox(height: 12),
                          Text('Replacement:', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(supply.maintenance!.replacementSchedule, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                  if (supply.troubleshooting != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildSection(
                      context,
                      icon: Icons.build_outlined,
                      title: 'Troubleshooting',
                      child: Text(supply.troubleshooting!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                    ),
                  ],
                  if (supply.whereToObtain.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildSection(
                      context,
                      icon: Icons.shopping_bag_outlined,
                      title: 'Where to Obtain',
                      child: Column(
                        children: supply.whereToObtain.map((option) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.store, size: 20, color: cs.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(option.source, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(option.details, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  if (supply.insuranceInfo != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildSection(
                      context,
                      icon: Icons.medical_services_outlined,
                      title: 'Insurance Coverage',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.tertiaryContainer,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: cs.onTertiaryContainer),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    supply.insuranceInfo!.coverage,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('💡 Tips:', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(supply.insuranceInfo!.tips, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _ResourceLinkCard extends StatelessWidget {
  final InstructionalResource resource;

  const _ResourceLinkCard({required this.resource});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _launchUrl(resource.url),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  resource.type.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (resource.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        resource.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.3,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.open_in_new, size: 20, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Failed to launch URL: $e');
    }
  }
}
