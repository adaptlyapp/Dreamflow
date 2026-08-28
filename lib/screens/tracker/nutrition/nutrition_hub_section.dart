import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wellspring/models/nutrition.dart';
import 'package:wellspring/models/nutrition_hub.dart';
import 'package:wellspring/services/nutrition_hub_service.dart';
import 'package:wellspring/theme.dart';

typedef LogFoodCallback = Future<void> Function(
    FoodEntry food, MealType mealType);

/// Compact card shown inside the Nutrition tracker tab that introduces the
/// Nutrition Hub and opens the full-screen hub experience.
class NutritionHubCard extends StatelessWidget {
  final List<String> conditions;
  final LogFoodCallback onLogFood;

  const NutritionHubCard(
      {super.key, required this.conditions, required this.onLogFood});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final hub = NutritionHubService.instance;
    final picks = hub.recommendedForConditions(conditions, max: 6);

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.55),
            cs.tertiaryContainer.withValues(alpha: 0.45),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: cs.surface, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.menu_book_outlined, color: cs.primary),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nutrition Hub', style: text.titleSmall?.semiBold),
                    SizedBox(height: 2),
                    Text(
                      'NIH & MedlinePlus food database, recipes & eating plans — curated for you.',
                      style: text.bodySmall?.withColor(cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _openHub(context),
                icon: Icon(Icons.arrow_forward,
                    size: 18, color: cs.onPrimaryContainer),
                label: Text('Open',
                    style: text.labelLarge?.semiBold
                        .withColor(cs.onPrimaryContainer)),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: picks.length,
              padding: EdgeInsets.zero,
              separatorBuilder: (_, __) => SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final f = picks[i];
                return _FoodPickChip(
                  food: f,
                  onTap: () => _openFood(context, f),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openHub(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          NutritionHubSheet(conditions: conditions, onLogFood: onLogFood),
    );
  }

  void _openFood(BuildContext context, FoodEntry food) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodDetailSheet(food: food, onLog: onLogFood),
    );
  }
}

class _FoodPickChip extends StatelessWidget {
  final FoodEntry food;
  final VoidCallback onTap;
  const _FoodPickChip({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 132,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(food.emoji, style: const TextStyle(fontSize: 22)),
            SizedBox(height: 4),
            Text(food.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall?.semiBold),
            SizedBox(height: 2),
            Text(
                '${food.caloriesPerServing} kcal • ${food.proteinG.toStringAsFixed(0)}P',
                style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
            const Spacer(),
            if (food.tags.isNotEmpty)
              Text('#${food.tags.first}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.withColor(cs.primary)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Full Hub
// =============================================================================

class NutritionHubSheet extends StatefulWidget {
  final List<String> conditions;
  final LogFoodCallback onLogFood;
  const NutritionHubSheet(
      {super.key, required this.conditions, required this.onLogFood});

  @override
  State<NutritionHubSheet> createState() => _NutritionHubSheetState();
}

class _NutritionHubSheetState extends State<NutritionHubSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';
  FoodCategory? _category;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _searchCtrl.addListener(() {
      if (_searchCtrl.text != _query) setState(() => _query = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final hub = NutritionHubService.instance;

    final foods = hub.searchFoods(query: _query, category: _category);
    final recipes = hub.searchRecipes(query: _query);
    final articles = hub.searchArticles(query: _query);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xxl)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: AppSpacing.paddingLg
                    .copyWith(top: 0, bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.restaurant_menu,
                        color: cs.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nutrition Hub',
                              style: text.titleLarge?.semiBold),
                          Text(
                            'NIH & MedlinePlus-backed food intelligence',
                            style:
                                text.labelSmall?.withColor(cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: context.pop,
                      icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: AppSpacing.paddingLg.copyWith(top: 0),
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search foods, recipes, conditions, nutrition…',
                    prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                    suffixIcon: _query.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              FocusScope.of(context).unfocus();
                            },
                            icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                          ),
                    filled: true,
                    fillColor:
                        cs.surfaceContainerHighest.withValues(alpha: 0.55),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.40)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.40)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide:
                          BorderSide(color: cs.primary.withValues(alpha: 0.70)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  style: text.bodyMedium,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: text.labelLarge?.semiBold,
                tabs: const [
                  Tab(text: 'For You'),
                  Tab(text: 'Foods'),
                  Tab(text: 'Recipes'),
                  Tab(text: 'Eating Plans'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _ForYouTab(
                      conditions: widget.conditions,
                      onOpenFood: _openFood,
                      onOpenRecipe: _openRecipe,
                      onOpenPlan: _openPlan,
                      onOpenArticle: _openArticle,
                      scrollController: scrollController,
                    ),
                    _FoodsTab(
                      foods: foods,
                      activeCategory: _category,
                      onCategory: (c) => setState(() => _category = c),
                      onOpenFood: _openFood,
                      scrollController: scrollController,
                    ),
                    _RecipesTab(
                        recipes: recipes, scrollController: scrollController),
                    _PlansTab(
                        plans: hub.plans, scrollController: scrollController),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openFood(FoodEntry food) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodDetailSheet(food: food, onLog: widget.onLogFood),
    );
  }

  void _openRecipe(NutritionRecipe r) => _openExternal(r.url);
  void _openPlan(NutritionPlan p) => _openExternal(p.url);
  void _openArticle(NutritionArticle a) => _openExternal(a.url);

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }
}

// =============================================================================

class _ForYouTab extends StatelessWidget {
  final List<String> conditions;
  final ValueChanged<FoodEntry> onOpenFood;
  final ValueChanged<NutritionRecipe> onOpenRecipe;
  final ValueChanged<NutritionPlan> onOpenPlan;
  final ValueChanged<NutritionArticle> onOpenArticle;
  final ScrollController scrollController;

  const _ForYouTab({
    required this.conditions,
    required this.onOpenFood,
    required this.onOpenRecipe,
    required this.onOpenPlan,
    required this.onOpenArticle,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final hub = NutritionHubService.instance;
    final foods = hub.recommendedForConditions(conditions, max: 8);
    final recipes = hub.recommendedRecipesForConditions(conditions, max: 6);
    final articles = hub.articles.take(4).toList();
    final plans = hub.plans.take(3).toList();

    return ListView(
      controller: scrollController,
      padding: AppSpacing.paddingLg,
      children: [
        if (conditions.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border:
                  Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.health_and_safety_outlined,
                    size: 18, color: cs.onPrimaryContainer),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Curated for: ${conditions.take(4).join(', ')}${conditions.length > 4 ? ' +${conditions.length - 4}' : ''}',
                    style: text.labelSmall?.semiBold
                        .withColor(cs.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),
        ],
        _SectionHeader(icon: Icons.local_dining, title: 'Recommended foods'),
        SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: foods.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, i) =>
              _FoodTile(food: foods[i], onTap: () => onOpenFood(foods[i])),
        ),
        SizedBox(height: AppSpacing.lg),
        _SectionHeader(
            icon: Icons.menu_book, title: 'Recipes from NIH & MedlinePlus'),
        SizedBox(height: AppSpacing.sm),
        for (final r in recipes) ...[
          _RecipeRow(recipe: r, onTap: () => onOpenRecipe(r)),
          SizedBox(height: AppSpacing.sm),
        ],
        SizedBox(height: AppSpacing.lg),
        _SectionHeader(
            icon: Icons.tips_and_updates_outlined,
            title: 'Eating plans worth knowing'),
        SizedBox(height: AppSpacing.sm),
        for (final p in plans) ...[
          _PlanRow(plan: p, onTap: () => onOpenPlan(p)),
          SizedBox(height: AppSpacing.sm),
        ],
        SizedBox(height: AppSpacing.lg),
        _SectionHeader(icon: Icons.article_outlined, title: 'Learn the basics'),
        SizedBox(height: AppSpacing.sm),
        for (final a in articles) ...[
          _ArticleRow(article: a, onTap: () => onOpenArticle(a)),
          SizedBox(height: AppSpacing.sm),
        ],
        SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _FoodsTab extends StatelessWidget {
  final List<FoodEntry> foods;
  final FoodCategory? activeCategory;
  final ValueChanged<FoodCategory?> onCategory;
  final ValueChanged<FoodEntry> onOpenFood;
  final ScrollController scrollController;

  const _FoodsTab({
    required this.foods,
    required this.activeCategory,
    required this.onCategory,
    required this.onOpenFood,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:
                EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6),
            children: [
              _CatChip(
                label: 'All',
                emoji: '✨',
                selected: activeCategory == null,
                onTap: () => onCategory(null),
              ),
              SizedBox(width: AppSpacing.sm),
              for (final c in FoodCategory.values) ...[
                _CatChip(
                  label: c.label,
                  emoji: c.emoji,
                  selected: activeCategory == c,
                  onTap: () => onCategory(c),
                ),
                SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
        Expanded(
          child: foods.isEmpty
              ? Center(
                  child: Padding(
                    padding: AppSpacing.paddingLg,
                    child: Text('No foods match your search yet.',
                        style: text.bodyMedium?.withColor(cs.onSurfaceVariant)),
                  ),
                )
              : GridView.builder(
                  controller: scrollController,
                  padding: AppSpacing.paddingLg,
                  itemCount: foods.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, i) => _FoodTile(
                      food: foods[i], onTap: () => onOpenFood(foods[i])),
                ),
        ),
      ],
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip(
      {required this.label,
      required this.emoji,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.15)
              : cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.5)
                  : cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            SizedBox(width: 6),
            Text(label,
                style: (selected
                    ? text.labelMedium?.semiBold.withColor(cs.primary)
                    : text.labelMedium?.withColor(cs.onSurface))),
          ],
        ),
      ),
    );
  }
}

class _RecipesTab extends StatelessWidget {
  final List<NutritionRecipe> recipes;
  final ScrollController scrollController;
  const _RecipesTab({required this.recipes, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    if (recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Text('No recipes match your search yet.',
              style: text.bodyMedium?.withColor(cs.onSurfaceVariant)),
        ),
      );
    }
    return ListView.separated(
      controller: scrollController,
      padding: AppSpacing.paddingLg,
      itemCount: recipes.length,
      separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _RecipeRow(
          recipe: recipes[i], onTap: () => _open(context, recipes[i].url)),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _PlansTab extends StatelessWidget {
  final List<NutritionPlan> plans;
  final ScrollController scrollController;
  const _PlansTab({required this.plans, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      padding: AppSpacing.paddingLg,
      itemCount: plans.length,
      separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) =>
          _PlanRow(plan: plans[i], onTap: () => _open(context, plans[i].url)),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// =============================================================================
// Tile widgets
// =============================================================================

class _FoodTile extends StatelessWidget {
  final FoodEntry food;
  final VoidCallback onTap;
  const _FoodTile({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(food.emoji, style: const TextStyle(fontSize: 24)),
            SizedBox(height: 6),
            Text(food.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall?.semiBold),
            SizedBox(height: 2),
            Text(
                '${food.caloriesPerServing} kcal • ${food.proteinG.toStringAsFixed(0)}P ${food.carbsG.toStringAsFixed(0)}C ${food.fatG.toStringAsFixed(0)}F',
                style: text.labelSmall?.withColor(cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            if (food.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: food.tags
                    .take(2)
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(t,
                              style: text.labelSmall?.withColor(cs.primary)),
                        ))
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecipeRow extends StatelessWidget {
  final NutritionRecipe recipe;
  final VoidCallback onTap;
  const _RecipeRow({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: cs.secondaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.restaurant, color: cs.onSecondaryContainer),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title,
                      style: text.titleSmall?.semiBold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2),
                  Text(recipe.description,
                      style: text.bodySmall?.withColor(cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4),
                  Text('${recipe.sourceName} • ${recipe.estMinutes} min',
                      style: text.labelSmall?.withColor(cs.primary)),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final NutritionPlan plan;
  final VoidCallback onTap;
  const _PlanRow({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: cs.tertiaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.bookmark_outline,
                      color: cs.onTertiaryContainer),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.name, style: text.titleSmall?.semiBold),
                      Text(plan.tagline,
                          style: text.labelSmall?.withColor(cs.primary)),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new, size: 18, color: cs.onSurfaceVariant),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            Text(plan.description,
                style: text.bodySmall?.withColor(cs.onSurfaceVariant)),
            SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: plan.goodFor
                  .take(4)
                  .map((g) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(g,
                            style: text.labelSmall?.withColor(cs.primary)),
                      ))
                  .toList(growable: false),
            ),
            SizedBox(height: AppSpacing.sm),
            Text('Emphasize: ${plan.emphasize.take(5).join(', ')}',
                style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
            SizedBox(height: 2),
            Text('Limit: ${plan.limit.take(4).join(', ')}',
                style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
            SizedBox(height: 4),
            Text(plan.sourceName,
                style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ArticleRow extends StatelessWidget {
  final NutritionArticle article;
  final VoidCallback onTap;
  const _ArticleRow({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.article_outlined, color: cs.primary),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title, style: text.titleSmall?.semiBold),
                  SizedBox(height: 2),
                  Text(article.summary,
                      style: text.bodySmall?.withColor(cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4),
                  Text(
                      '${article.sourceName} • ${article.estReadMinutes} min read',
                      style: text.labelSmall?.withColor(cs.primary)),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    return Row(
      children: [
        Icon(icon, color: cs.primary, size: 18),
        SizedBox(width: AppSpacing.sm),
        Text(title, style: text.titleSmall?.semiBold),
      ],
    );
  }
}

// =============================================================================
// Food detail sheet (with "Log to meal" action)
// =============================================================================

class FoodDetailSheet extends StatelessWidget {
  final FoodEntry food;
  final LogFoodCallback onLog;
  const FoodDetailSheet({super.key, required this.food, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    Widget macro(String label, String v, IconData icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border:
                  Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: cs.primary),
                SizedBox(height: 4),
                Text(v, style: text.titleSmall?.semiBold),
                Text(label,
                    style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
              ],
            ),
          ),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(food.emoji, style: const TextStyle(fontSize: 32)),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(food.name, style: text.titleLarge?.semiBold),
                          Text('${food.category.label} • ${food.servingLabel}',
                              style: text.labelSmall
                                  ?.withColor(cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    IconButton(
                        onPressed: context.pop,
                        icon: Icon(Icons.close, color: cs.onSurfaceVariant)),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Row(children: [
                  macro('Calories', '${food.caloriesPerServing}',
                      Icons.local_fire_department_outlined),
                  SizedBox(width: AppSpacing.sm),
                  macro('Protein', '${food.proteinG.toStringAsFixed(1)}g',
                      Icons.fitness_center_outlined),
                ]),
                SizedBox(height: AppSpacing.sm),
                Row(children: [
                  macro('Carbs', '${food.carbsG.toStringAsFixed(1)}g',
                      Icons.grain_outlined),
                  SizedBox(width: AppSpacing.sm),
                  macro('Fat', '${food.fatG.toStringAsFixed(1)}g',
                      Icons.opacity_outlined),
                  SizedBox(width: AppSpacing.sm),
                  macro('Fiber', '${food.fiberG.toStringAsFixed(1)}g',
                      Icons.eco_outlined),
                ]),
                SizedBox(height: AppSpacing.lg),
                if (food.healthBenefits.isNotEmpty) ...[
                  Text('Why it\'s good for you',
                      style: text.titleSmall?.semiBold),
                  SizedBox(height: AppSpacing.sm),
                  for (final b in food.healthBenefits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 16, color: cs.primary),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(b, style: text.bodySmall)),
                        ],
                      ),
                    ),
                  SizedBox(height: AppSpacing.md),
                ],
                if (food.goodForConditions.isNotEmpty) ...[
                  Text('Helpful for', style: text.titleSmall?.semiBold),
                  SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: food.goodForConditions
                        .map((c) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(c,
                                  style:
                                      text.labelSmall?.withColor(cs.primary)),
                            ))
                        .toList(growable: false),
                  ),
                  SizedBox(height: AppSpacing.md),
                ],
                if (food.note != null) ...[
                  Container(
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: cs.onErrorContainer, size: 18),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                            child: Text(food.note!,
                                style: text.bodySmall
                                    ?.withColor(cs.onErrorContainer))),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                ],
                SizedBox(height: AppSpacing.sm),
                Text('Log to a meal', style: text.titleSmall?.semiBold),
                SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final t in MealType.values)
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await onLog(food, t);
                          if (context.mounted) context.pop();
                        },
                        icon: Icon(_iconFor(t), size: 16),
                        label: Text(t.label),
                      ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                Center(
                  child: Text(
                      'Data informed by NIH MyPlate & MedlinePlus guidelines.',
                      style: text.labelSmall?.withColor(cs.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(MealType t) => switch (t) {
        MealType.breakfast => Icons.wb_sunny_outlined,
        MealType.lunch => Icons.lunch_dining_outlined,
        MealType.dinner => Icons.dinner_dining_outlined,
        MealType.snack => Icons.cookie_outlined,
      };
}
