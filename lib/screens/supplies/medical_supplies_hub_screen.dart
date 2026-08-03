import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wellspring/models/medical_supply.dart';
import 'package:wellspring/services/medical_supply_service.dart';
import 'package:wellspring/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class MedicalSuppliesHubScreen extends StatefulWidget {
  const MedicalSuppliesHubScreen({super.key});

  @override
  State<MedicalSuppliesHubScreen> createState() => _MedicalSuppliesHubScreenState();
}

class _MedicalSuppliesHubScreenState extends State<MedicalSuppliesHubScreen> {
  final _service = MedicalSupplyService.instance;
  final _searchController = TextEditingController();
  String? _selectedCategory;
  List<MedicalSupply> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    setState(() {
      _isSearching = query.isNotEmpty;
      _searchResults = query.isEmpty ? [] : _service.search(query);
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _isSearching = false;
      _searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primaryContainer, cs.secondaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_selectedCategory != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => setState(() => _selectedCategory = null),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => context.pop(),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Medical Supplies & Equipment',
                              style: context.textStyles.headlineSmall?.semiBold,
                            ),
                            if (_selectedCategory == null)
                              Text(
                                'Comprehensive guides for all your medical supply needs',
                                style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search supplies and equipment...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _clearSearch,
                            )
                          : null,
                      filled: true,
                      fillColor: cs.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => _performSearch(),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isSearching
                  ? _buildSearchResults()
                  : _selectedCategory != null
                      ? _buildCategoryDetail(_selectedCategory!)
                      : _buildCategoryGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = MedicalSupplyService.categories;

    return GridView.builder(
      padding: AppSpacing.paddingLg,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryCard(
          category: category,
          onTap: () => setState(() => _selectedCategory = category.id),
        );
      },
    );
  }

  Widget _buildCategoryDetail(String categoryId) {
    final category = _service.getCategoryById(categoryId);
    final supplies = _service.byCategory(categoryId);

    if (category == null) return const SizedBox.shrink();

    return ListView(
      padding: AppSpacing.paddingLg,
      children: [
        // Category header
        Container(
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              Text(
                category.emoji,
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: context.textStyles.titleLarge?.semiBold,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.description,
                      style: context.textStyles.bodyMedium?.withColor(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Supplies list
        if (supplies.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'More supplies coming soon',
                    style: context.textStyles.bodyLarge?.withColor(
                      Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...supplies.map((supply) => _SupplyCard(supply: supply)),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No supplies found',
              style: context.textStyles.titleMedium?.withColor(
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different search terms',
              style: context.textStyles.bodyMedium?.withColor(
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: AppSpacing.paddingLg,
      children: _searchResults.map((supply) => _SupplyCard(supply: supply)).toList(),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final SupplyCategory category;
  final VoidCallback onTap;

  const _CategoryCard({
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
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primaryContainer.withValues(alpha: 0.3),
                cs.secondaryContainer.withValues(alpha: 0.3),
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
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 8),
              Text(
                category.name,
                style: context.textStyles.titleSmall?.semiBold,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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

  const _SupplyCard({required this.supply});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () => _showSupplyDetail(context, supply),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (supply.iconEmoji != null) ...[
                    Text(
                      supply.iconEmoji!,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supply.name,
                          style: context.textStyles.titleMedium?.semiBold,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          supply.whoUsesIt,
                          style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
              if (supply.commonBrands.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: supply.commonBrands.take(3).map((brand) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        brand,
                        style: context.textStyles.labelSmall,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSupplyDetail(BuildContext context, MedicalSupply supply) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _SupplyDetailSheet(supply: supply),
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
                    Text(
                      supply.iconEmoji!,
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Text(
                      supply.name,
                      style: context.textStyles.headlineSmall?.semiBold,
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
                    child: Text(supply.description, style: context.textStyles.bodyMedium),
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    context,
                    icon: Icons.person_outline,
                    title: 'Who uses it?',
                    child: Text(supply.whoUsesIt, style: context.textStyles.bodyMedium),
                  ),
                  if (supply.commonBrands.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      icon: Icons.label_outline,
                      title: 'Common Brands',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: supply.commonBrands.map((brand) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text(brand, style: context.textStyles.bodyMedium?.semiBold),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  if (supply.resources.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      icon: Icons.school_outlined,
                      title: 'Instructional Resources',
                      child: Column(
                        children: supply.resources.map((resource) {
                          return _ResourceLink(resource: resource);
                        }).toList(),
                      ),
                    ),
                  ],
                  if (supply.maintenance != null) ...[
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      icon: Icons.cleaning_services_outlined,
                      title: 'Cleaning & Maintenance',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cleaning:', style: context.textStyles.labelLarge?.semiBold),
                          const SizedBox(height: 4),
                          Text(supply.maintenance!.cleaningInstructions, style: context.textStyles.bodyMedium),
                          const SizedBox(height: 12),
                          Text('Replacement:', style: context.textStyles.labelLarge?.semiBold),
                          const SizedBox(height: 4),
                          Text(supply.maintenance!.replacementSchedule, style: context.textStyles.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                  if (supply.troubleshooting != null) ...[
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      icon: Icons.build_outlined,
                      title: 'Troubleshooting',
                      child: Text(supply.troubleshooting!, style: context.textStyles.bodyMedium),
                    ),
                  ],
                  if (supply.whereToObtain.isNotEmpty) ...[
                    const SizedBox(height: 24),
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
                                      Text(option.source, style: context.textStyles.labelLarge?.semiBold),
                                      const SizedBox(height: 2),
                                      Text(option.details, style: context.textStyles.bodySmall),
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
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      icon: Icons.medical_services_outlined,
                      title: 'Insurance & Coverage',
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
                                    style: context.textStyles.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('💡 Tips:', style: context.textStyles.labelLarge?.semiBold),
                          const SizedBox(height: 4),
                          Text(supply.insuranceInfo!.tips, style: context.textStyles.bodyMedium),
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
            Text(title, style: context.textStyles.titleMedium?.semiBold),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _ResourceLink extends StatelessWidget {
  final InstructionalResource resource;

  const _ResourceLink({required this.resource});

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
                      style: context.textStyles.bodyMedium?.semiBold,
                    ),
                    if (resource.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        resource.description!,
                        style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
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
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
