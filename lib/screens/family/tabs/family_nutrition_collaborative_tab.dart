import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/family_nutrition.dart';
import 'package:wellspring/models/nutrition.dart';
import 'package:wellspring/models/user.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/family_nutrition_service.dart';
import 'package:wellspring/services/food_database_service.dart';
import 'package:wellspring/services/user_service.dart';
import 'package:wellspring/theme.dart';

/// Collaborative family nutrition tracker with comprehensive food search
class FamilyNutritionCollaborativeTab extends StatefulWidget {
  const FamilyNutritionCollaborativeTab({
    super.key,
    required this.patientId,
  });

  final String patientId;

  @override
  State<FamilyNutritionCollaborativeTab> createState() => _FamilyNutritionCollaborativeTabState();
}

class _FamilyNutritionCollaborativeTabState extends State<FamilyNutritionCollaborativeTab> {
  final _familyNutrition = FamilyNutritionService();
  final _foodDb = FoodDatabaseService();

  bool _loading = true;
  DateTime _selectedDate = DateTime.now();
  List<FamilyNutritionEntry> _entries = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _foodDb.initialize().then((_) => _reload());
  }

  DateTime get _normalizedDate => DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final entries = await _familyNutrition.getEntriesForDate(
        patientId: widget.patientId,
        date: _normalizedDate,
      );

      // Get weekly stats
      final startOfWeek = _normalizedDate.subtract(Duration(days: _normalizedDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      final stats = await _familyNutrition.getFamilyStatistics(
        patientId: widget.patientId,
        startDate: startOfWeek,
        endDate: endOfWeek,
      );

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[FamilyNutritionTab] _reload error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addWaterForUser(String userId, String userName, String? photoUrl) async {
    await _familyNutrition.addWater(
      patientId: widget.patientId,
      userId: userId,
      userName: userName,
      userPhotoUrl: photoUrl,
      date: _normalizedDate,
      ml: 250, // Add 250ml (1 cup)
    );
    await _reload();
  }

  Future<void> _openFoodSearch(String userId, String userName, String? photoUrl, MealType mealType) async {
    final selectedFood = await showModalBottomSheet<FoodDatabaseEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FoodSearchSheet(),
    );

    if (selectedFood == null) return;

    try {
      await _familyNutrition.addFoodToMeal(
        patientId: widget.patientId,
        userId: userId,
        userName: userName,
        userPhotoUrl: photoUrl,
        date: _normalizedDate,
        mealType: mealType,
        foodItem: selectedFood.toFoodItemLog(),
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${selectedFood.name} to ${mealType.label}')),
      );
    } catch (e) {
      debugPrint('[FamilyNutritionTab] _openFoodSearch error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add food')),
      );
    }
  }

  Future<void> _viewUserDayDetails(FamilyNutritionEntry entry) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UserDayDetailsSheet(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Date selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                      _reload();
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        DateFormat('EEEE, MMM d').format(_normalizedDate),
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _normalizedDate.isBefore(DateTime.now())
                        ? () {
                            setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                            _reload();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Weekly stats overview
          Text('This Week\'s Overview', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatPill(
                    label: 'Avg Calories',
                    value: '${(_stats['avgCalories'] ?? 0).round()}',
                    color: Colors.orange,
                  ),
                  _StatPill(
                    label: 'Avg Protein',
                    value: '${(_stats['avgProtein'] ?? 0).round()}g',
                    color: Colors.red,
                  ),
                  _StatPill(
                    label: 'Avg Water',
                    value: '${(_stats['avgWater'] ?? 0).toStringAsFixed(1)}L',
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Quick add for current user
          if (currentUser != null) ...[
            Text('Quick Add', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: currentUser.profileImageUrl != null
                              ? NetworkImage(currentUser.profileImageUrl!)
                              : null,
                          child: currentUser.profileImageUrl == null
                              ? Text(currentUser.name[0].toUpperCase())
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Log for ${currentUser.name}',
                          style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _QuickActionChip(
                          icon: Icons.local_drink,
                          label: 'Water',
                          color: Colors.blue,
                          onTap: () => _addWaterForUser(
                            currentUser.id,
                            currentUser.name,
                            currentUser.profileImageUrl,
                          ),
                        ),
                        _QuickActionChip(
                          icon: Icons.breakfast_dining,
                          label: 'Breakfast',
                          color: Colors.amber,
                          onTap: () => _openFoodSearch(
                            currentUser.id,
                            currentUser.name,
                            currentUser.profileImageUrl,
                            MealType.breakfast,
                          ),
                        ),
                        _QuickActionChip(
                          icon: Icons.lunch_dining,
                          label: 'Lunch',
                          color: Colors.green,
                          onTap: () => _openFoodSearch(
                            currentUser.id,
                            currentUser.name,
                            currentUser.profileImageUrl,
                            MealType.lunch,
                          ),
                        ),
                        _QuickActionChip(
                          icon: Icons.dinner_dining,
                          label: 'Dinner',
                          color: Colors.deepOrange,
                          onTap: () => _openFoodSearch(
                            currentUser.id,
                            currentUser.name,
                            currentUser.profileImageUrl,
                            MealType.dinner,
                          ),
                        ),
                        _QuickActionChip(
                          icon: Icons.cookie,
                          label: 'Snack',
                          color: Colors.purple,
                          onTap: () => _openFoodSearch(
                            currentUser.id,
                            currentUser.name,
                            currentUser.profileImageUrl,
                            MealType.snack,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // Family members' logs for selected date
          Text('Family Logs', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),

          if (_entries.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.restaurant_outlined, size: 48, color: cs.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No nutrition logs for this date',
                        style: text.bodyMedium?.withColor(cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...(_entries.map((entry) => _UserDayCard(
                  entry: entry,
                  onTap: () => _viewUserDayDetails(entry),
                ))),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLogSheet(currentUser),
        icon: const Icon(Icons.add),
        label: const Text('Add Log'),
      ),
    );
  }

  Future<void> _showAddLogSheet(User? currentUser) async {
    debugPrint('[FamilyNutritionTab] _showAddLogSheet called with user: ${currentUser?.name ?? "null"}');
    
    // Get fresh user from UserService directly (more reliable than provider in family portal)
    User? user;
    try {
      final userService = UserService();
      user = await userService.getCurrentUser();
      debugPrint('[FamilyNutritionTab] Fresh user from UserService: ${user?.name ?? "null"} (${user?.id ?? "null"})');
    } catch (e) {
      debugPrint('[FamilyNutritionTab] Error getting user: $e');
    }
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify current user. Please try again.')),
      );
      return;
    }
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddLogSheet(
        patientId: widget.patientId,
        currentUser: user,
        onLogAdded: _reload,
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    return Column(
      children: [
        Text(
          value,
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: text.labelSmall),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _UserDayCard extends StatelessWidget {
  const _UserDayCard({
    required this.entry,
    required this.onTap,
  });

  final FamilyNutritionEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final macros = entry.nutritionLog.totalMacros;
    final waterL = entry.nutritionLog.waterMl / 1000.0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: entry.userPhotoUrl != null
                        ? NetworkImage(entry.userPhotoUrl!)
                        : null,
                    child: entry.userPhotoUrl == null
                        ? Text(entry.userName[0].toUpperCase())
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.userName,
                          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${entry.nutritionLog.completedMealsCount}/${entry.nutritionLog.totalMealsCount} meals logged',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MacroPill(
                    label: 'Cal',
                    value: '${macros.calories}',
                    color: Colors.orange,
                  ),
                  _MacroPill(
                    label: 'Pro',
                    value: '${macros.proteinG.round()}g',
                    color: Colors.red,
                  ),
                  _MacroPill(
                    label: 'Carbs',
                    value: '${macros.carbsG.round()}g',
                    color: Colors.amber,
                  ),
                  _MacroPill(
                    label: 'Fat',
                    value: '${macros.fatsG.round()}g',
                    color: Colors.purple,
                  ),
                  _MacroPill(
                    label: 'Water',
                    value: '${waterL.toStringAsFixed(1)}L',
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    return Column(
      children: [
        Text(
          value,
          style: text.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: text.labelSmall),
      ],
    );
  }
}

class _UserDayDetailsSheet extends StatelessWidget {
  const _UserDayDetailsSheet({required this.entry});

  final FamilyNutritionEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;
    final log = entry.nutritionLog;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: entry.userPhotoUrl != null
                      ? NetworkImage(entry.userPhotoUrl!)
                      : null,
                  child: entry.userPhotoUrl == null
                      ? Text(entry.userName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.userName,
                        style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('EEEE, MMM d').format(entry.date),
                        style: text.bodyMedium?.withColor(cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Water
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_drink, color: Colors.blue),
                title: const Text('Water Intake'),
                trailing: Text(
                  '${(log.waterMl / 1000.0).toStringAsFixed(1)}L / ${(log.waterGoalMl / 1000.0).toStringAsFixed(1)}L',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Meals
            for (final mealType in MealType.values) ...[
              Text(
                mealType.label,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              _MealCard(meal: log.meals[mealType] ?? MealLog.empty(mealType)),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});

  final MealLog meal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;

    if (meal.items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Text(
              'No items logged',
              style: text.bodyMedium?.withColor(cs.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in meal.items) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name, style: text.bodyLarge),
                subtitle: item.notes != null ? Text(item.notes!) : null,
                trailing: Text(
                  '${item.macros.calories} cal',
                  style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  '${meal.totalMacros.calories} cal • ${meal.totalMacros.proteinG.round()}g protein',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddLogSheet extends StatefulWidget {
  const _AddLogSheet({
    required this.patientId,
    required this.currentUser,
    required this.onLogAdded,
  });

  final String patientId;
  final User? currentUser;
  final VoidCallback onLogAdded;

  @override
  State<_AddLogSheet> createState() => _AddLogSheetState();
}

class _AddLogSheetState extends State<_AddLogSheet> {
  final _familyNutrition = FamilyNutritionService();
  final _foodDb = FoodDatabaseService();
  
  User? _selectedUser;
  String? _selectedAction;

  @override
  void initState() {
    super.initState();
    _foodDb.initialize();
    // Default to current user
    _selectedUser = widget.currentUser;
    debugPrint('[_AddLogSheet] initState: currentUser = ${widget.currentUser?.name ?? "null"} (${widget.currentUser?.id ?? "null"})');
    debugPrint('[_AddLogSheet] initState: _selectedUser = ${_selectedUser?.name ?? "null"} (${_selectedUser?.id ?? "null"})');
  }

  Future<void> _addWater() async {
    debugPrint('[_AddLogSheet] _addWater called');
    if (_selectedUser == null) {
      debugPrint('[_AddLogSheet] _addWater: No user selected');
      return;
    }
    
    try {
      debugPrint('[_AddLogSheet] Adding water for ${_selectedUser!.name}');
      await _familyNutrition.addWater(
        patientId: widget.patientId,
        userId: _selectedUser!.id,
        userName: _selectedUser!.name,
        userPhotoUrl: _selectedUser!.profileImageUrl,
        date: DateTime.now(),
        ml: 250,
      );
      
      debugPrint('[_AddLogSheet] Water added successfully');
      if (!mounted) return;
      Navigator.pop(context);
      widget.onLogAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added water for ${_selectedUser!.name}')),
      );
    } catch (e) {
      debugPrint('[_AddLogSheet] _addWater error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add water: $e')),
      );
    }
  }

  Future<void> _addFood(MealType mealType) async {
    debugPrint('[_AddLogSheet] _addFood called for ${mealType.label}');
    if (_selectedUser == null) {
      debugPrint('[_AddLogSheet] _addFood: No user selected');
      return;
    }
    
    debugPrint('[_AddLogSheet] Opening food search sheet');
    final selectedFood = await showModalBottomSheet<FoodDatabaseEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FoodSearchSheet(),
    );

    debugPrint('[_AddLogSheet] Food search result: ${selectedFood?.name ?? "null"}');
    if (selectedFood == null || !mounted) return;

    try {
      debugPrint('[_AddLogSheet] Adding ${selectedFood.name} to ${mealType.label}');
      await _familyNutrition.addFoodToMeal(
        patientId: widget.patientId,
        userId: _selectedUser!.id,
        userName: _selectedUser!.name,
        userPhotoUrl: _selectedUser!.profileImageUrl,
        date: DateTime.now(),
        mealType: mealType,
        foodItem: selectedFood.toFoodItemLog(),
      );
      
      debugPrint('[_AddLogSheet] Food added successfully');
      if (!mounted) return;
      Navigator.pop(context);
      widget.onLogAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${selectedFood.name} to ${mealType.label} for ${_selectedUser!.name}')),
      );
    } catch (e) {
      debugPrint('[_AddLogSheet] _addFood error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add food: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.lg,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Add Nutrition Log',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // User selector
          if (_selectedUser != null) ...[
            Text('Log for:', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: _selectedUser!.profileImageUrl != null
                      ? NetworkImage(_selectedUser!.profileImageUrl!)
                      : null,
                  child: _selectedUser!.profileImageUrl == null
                      ? Text(_selectedUser!.name[0].toUpperCase())
                      : null,
                ),
                title: Text(_selectedUser!.name),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Action selector
          Text('What would you like to log?', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.2,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _ActionCard(
                icon: Icons.local_drink,
                label: 'Water',
                color: Colors.blue,
                onTap: _addWater,
              ),
              _ActionCard(
                icon: Icons.breakfast_dining,
                label: 'Breakfast',
                color: Colors.amber,
                onTap: () => _addFood(MealType.breakfast),
              ),
              _ActionCard(
                icon: Icons.lunch_dining,
                label: 'Lunch',
                color: Colors.green,
                onTap: () => _addFood(MealType.lunch),
              ),
              _ActionCard(
                icon: Icons.dinner_dining,
                label: 'Dinner',
                color: Colors.deepOrange,
                onTap: () => _addFood(MealType.dinner),
              ),
              _ActionCard(
                icon: Icons.cookie,
                label: 'Snack',
                color: Colors.purple,
                onTap: () => _addFood(MealType.snack),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final cs = Theme.of(context).colorScheme;
    
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      color: cs.surface,
      child: InkWell(
        onTap: () {
          debugPrint('[_ActionCard] Tapped: $label');
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: text.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodSearchSheet extends StatefulWidget {
  @override
  State<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends State<_FoodSearchSheet> with SingleTickerProviderStateMixin {
  final _foodDb = FoodDatabaseService();
  final _searchController = TextEditingController();
  late final TabController _tabController;
  
  List<FoodDatabaseEntry> _usdaResults = [];
  bool _usdaLoading = false;
  String? _usdaErrorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Only USDA and Custom tabs
    _foodDb.initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _performUSDASearch(String query) async {
    debugPrint('[_FoodSearchSheet] _performUSDASearch called with query: "$query"');
    
    if (query.trim().isEmpty) {
      debugPrint('[_FoodSearchSheet] Query is empty, clearing results');
      setState(() {
        _usdaResults = [];
        _usdaErrorMessage = null;
      });
      return;
    }

    debugPrint('[_FoodSearchSheet] Setting loading state = true');
    setState(() {
      _usdaLoading = true;
      _usdaErrorMessage = null;
    });
    
    try {
      debugPrint('[_FoodSearchSheet] Calling searchUSDAFoods...');
      final results = await _foodDb.searchUSDAFoods(query, limit: 50);
      debugPrint('[_FoodSearchSheet] Received ${results.length} results from USDA API');
      
      if (!mounted) return;
      setState(() {
        _usdaResults = results;
        _usdaLoading = false;
        _usdaErrorMessage = null;
      });
      debugPrint('[_FoodSearchSheet] Updated UI with ${results.length} results');
    } catch (e) {
      debugPrint('[_FoodSearchSheet] _performUSDASearch error: $e');
      if (!mounted) return;
      setState(() {
        _usdaResults = [];
        _usdaLoading = false;
        _usdaErrorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _showCreateCustomFoodDialog() async {
    final nameController = TextEditingController();
    final servingSizeController = TextEditingController();
    final servingSizeGController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();
    final fiberController = TextEditingController();
    final sugarController = TextEditingController();
    final sodiumController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Custom Food'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Food Name *', hintText: 'e.g., Grandma\'s Apple Pie'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: servingSizeController,
                      decoration: const InputDecoration(labelText: 'Serving Size *', hintText: 'e.g., 1 slice'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: servingSizeGController,
                      decoration: const InputDecoration(labelText: 'Weight (g)', hintText: '100'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Nutrition Facts', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: caloriesController,
                decoration: const InputDecoration(labelText: 'Calories', hintText: '0'),
                keyboardType: TextInputType.number,
              ),
              Row(
                children: [
                  Expanded(child: TextField(controller: proteinController, decoration: const InputDecoration(labelText: 'Protein (g)'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: carbsController, decoration: const InputDecoration(labelText: 'Carbs (g)'), keyboardType: TextInputType.number)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: TextField(controller: fatController, decoration: const InputDecoration(labelText: 'Fat (g)'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: fiberController, decoration: const InputDecoration(labelText: 'Fiber (g)'), keyboardType: TextInputType.number)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: TextField(controller: sugarController, decoration: const InputDecoration(labelText: 'Sugar (g)'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: sodiumController, decoration: const InputDecoration(labelText: 'Sodium (mg)'), keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Recipe notes, ingredients...'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Food name is required')));
      return;
    }

    try {
      await _foodDb.addCustomFood(
        name: name,
        servingSize: servingSizeController.text.trim().isEmpty ? '100g' : servingSizeController.text.trim(),
        servingSizeG: double.tryParse(servingSizeGController.text) ?? 100,
        macros: NutritionMacros(
          calories: int.tryParse(caloriesController.text) ?? 0,
          proteinG: double.tryParse(proteinController.text) ?? 0,
          carbsG: double.tryParse(carbsController.text) ?? 0,
          fatsG: double.tryParse(fatController.text) ?? 0,
          fiberG: double.tryParse(fiberController.text) ?? 0,
          sugarG: double.tryParse(sugarController.text) ?? 0,
          sodiumMg: int.tryParse(sodiumController.text) ?? 0,
        ),
        notes: notesController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Created "$name"')));
      // Refresh custom foods tab
      setState(() {});
    } catch (e) {
      debugPrint('[_FoodSearchSheet] _showCreateCustomFoodDialog error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create custom food')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = context.textStyles;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Food Database',
                      style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _showCreateCustomFoodDialog,
                      icon: const Icon(Icons.add_circle),
                      tooltip: 'Create Custom Food',
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search foods...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _performUSDASearch('');
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (query) {
                    if (_tabController.index == 0) {
                      _performUSDASearch(query);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TabBar(
                  controller: _tabController,
                  onTap: (index) {
                    if (index == 0 && _searchController.text.isNotEmpty) {
                      _performUSDASearch(_searchController.text);
                    }
                  },
                  tabs: const [
                    Tab(text: 'USDA (350K+)'),
                    Tab(text: 'My Foods'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // USDA search tab
                _buildFoodListView(
                  loading: _usdaLoading,
                  results: _usdaResults,
                  cs: cs,
                  text: text,
                  emptyMessage: _usdaErrorMessage ?? (_searchController.text.isEmpty
                      ? 'Enter a search query to access\n350,000+ foods from USDA database'
                      : 'No foods found in USDA database'),
                  isError: _usdaErrorMessage != null,
                ),
                
                // My custom foods tab
                _buildCustomFoodsTab(cs, text),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodListView({
    required bool loading,
    required List<FoodDatabaseEntry> results,
    required ColorScheme cs,
    required TextTheme text,
    String? emptyMessage,
    bool isError = false,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.search_off,
                size: 64,
                color: isError ? cs.error : cs.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                emptyMessage ?? 'No foods found',
                style: text.bodyLarge?.withColor(isError ? cs.error : cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (isError) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Create a custom food in the "My Foods" tab instead',
                  style: text.bodySmall?.withColor(cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: results.length,
      itemBuilder: (ctx, index) {
        final food = results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            title: Text(
              food.name,
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${food.brand} • ${food.category}\n${food.servingSize} • ${food.macros.calories.toStringAsFixed(0)} cal',
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${food.macros.proteinG.round()}g pro',
                  style: text.labelSmall,
                ),
                Text(
                  '${food.macros.carbsG.round()}g carbs',
                  style: text.labelSmall,
                ),
              ],
            ),
            onTap: () => Navigator.pop(context, food),
          ),
        );
      },
    );
  }

  Widget _buildCustomFoodsTab(ColorScheme cs, TextTheme text) {
    final customFoods = _foodDb.getCustomFoods();
    
    if (customFoods.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No custom foods yet',
              style: text.titleMedium?.withColor(cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap the + button above to create your own',
              style: text.bodyMedium?.withColor(cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: customFoods.length,
      itemBuilder: (ctx, index) {
        final customFood = customFoods[index];
        final foodEntry = customFood.toFoodDatabaseEntry();
        
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.star, color: cs.onPrimaryContainer, size: 20),
            ),
            title: Text(
              customFood.name,
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${customFood.servingSize} • ${customFood.macros.calories.toStringAsFixed(0)} cal\n${customFood.notes.isNotEmpty ? customFood.notes : "Custom food"}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Custom Food?'),
                    content: Text('Are you sure you want to delete "${customFood.name}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  await _foodDb.deleteCustomFood(customFood.id);
                  setState(() {});
                }
              },
            ),
            onTap: () => Navigator.pop(context, foodEntry),
          ),
        );
      },
    );
  }
}
