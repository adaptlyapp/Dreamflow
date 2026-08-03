import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wellspring/models/family_nutrition.dart';
import 'package:wellspring/models/nutrition.dart';
import 'package:uuid/uuid.dart';

/// Comprehensive food database with USDA API, fast food chains, and custom foods
class FoodDatabaseService {
  static final FoodDatabaseService _instance = FoodDatabaseService._internal();
  factory FoodDatabaseService() => _instance;
  FoodDatabaseService._internal();

  late final List<FoodDatabaseEntry> _database;
  List<CustomFoodEntry> _customFoods = [];
  bool _initialized = false;

  // USDA FoodData Central API
  // Get your free API key at: https://fdc.nal.usda.gov/api-key-signup.html
  static const String _usdaApiKey = 'HBKcWJBaL5Lf0eh6Hlg4HEDC6zziIldhgfpgUp00';
  static const String _usdaBaseUrl = 'https://api.nal.usda.gov/fdc/v1';
  static const String _customFoodsKey = 'custom_foods_v1';

  /// Initialize the food database
  Future<void> initialize() async {
    if (_initialized) return;
    _database = _buildDatabase();
    await _loadCustomFoods();
    _initialized = true;
    debugPrint('[FoodDatabaseService] Initialized with ${_database.length} built-in foods + ${_customFoods.length} custom foods');
  }

  /// Load custom foods from shared preferences
  Future<void> _loadCustomFoods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_customFoodsKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _customFoods = jsonList.map((json) => CustomFoodEntry.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('[FoodDatabaseService] _loadCustomFoods error: $e');
      _customFoods = [];
    }
  }

  /// Save custom foods to shared preferences
  Future<void> _saveCustomFoods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _customFoods.map((f) => f.toJson()).toList();
      await prefs.setString(_customFoodsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[FoodDatabaseService] _saveCustomFoods error: $e');
    }
  }

  /// Add a custom food entry
  Future<CustomFoodEntry> addCustomFood({
    required String name,
    required String servingSize,
    required double servingSizeG,
    required NutritionMacros macros,
    String notes = '',
  }) async {
    final customFood = CustomFoodEntry(
      id: const Uuid().v4(),
      name: name,
      servingSize: servingSize,
      servingSizeG: servingSizeG,
      macros: macros,
      notes: notes,
      createdAt: DateTime.now(),
    );
    
    _customFoods.add(customFood);
    await _saveCustomFoods();
    debugPrint('[FoodDatabaseService] Added custom food: $name');
    return customFood;
  }

  /// Delete a custom food entry
  Future<void> deleteCustomFood(String id) async {
    _customFoods.removeWhere((f) => f.id == id);
    await _saveCustomFoods();
    debugPrint('[FoodDatabaseService] Deleted custom food: $id');
  }

  /// Get all custom foods
  List<CustomFoodEntry> getCustomFoods() => List.unmodifiable(_customFoods);

  /// Search USDA FoodData Central API
  Future<List<FoodDatabaseEntry>> searchUSDAFoods(String query, {int limit = 200}) async {
    debugPrint('[FoodDatabaseService] searchUSDAFoods called with query: "$query", limit: $limit');
    
    if (query.trim().isEmpty) {
      debugPrint('[FoodDatabaseService] Query is empty, returning empty list');
      return [];
    }
    
    try {
      final url = Uri.parse('$_usdaBaseUrl/foods/search').replace(queryParameters: {
        'api_key': _usdaApiKey,
        'query': query,
        'pageSize': limit.toString(),
        'dataType': 'Branded,SR Legacy', // Branded foods and USDA standard reference
      });

      debugPrint('[FoodDatabaseService] Making HTTP request to: ${url.toString().replaceAll(_usdaApiKey, 'HIDDEN')}');
      final response = await http.get(url);
      debugPrint('[FoodDatabaseService] HTTP response status: ${response.statusCode}');
      
      if (response.statusCode == 429) {
        debugPrint('[FoodDatabaseService] USDA API rate limit exceeded (429). DEMO_KEY has limited quota.');
        throw Exception('USDA API rate limit exceeded. Please wait a few minutes or create a custom food instead.');
      }
      
      if (response.statusCode != 200) {
        debugPrint('[FoodDatabaseService] USDA API error: ${response.statusCode} - ${response.body}');
        throw Exception('USDA API error (${response.statusCode}). Please try again or create a custom food.');
      }

      final data = jsonDecode(response.body);
      debugPrint('[FoodDatabaseService] Successfully decoded JSON response');
      final foods = <FoodDatabaseEntry>[];
      
      final foodsList = data['foods'] as List? ?? [];
      debugPrint('[FoodDatabaseService] Found ${foodsList.length} foods in API response');
      
      for (final item in foodsList) {
        try {
          final foodNutrients = item['foodNutrients'] as List? ?? [];
          
          // Extract nutrition info
          double calories = 0, protein = 0, carbs = 0, fat = 0, fiber = 0, sugar = 0, sodium = 0;
          
          for (final nutrient in foodNutrients) {
            final name = nutrient['nutrientName']?.toString().toLowerCase() ?? '';
            final value = (nutrient['value'] as num?)?.toDouble() ?? 0;
            
            if (name.contains('energy') || name.contains('calories')) calories = value;
            else if (name.contains('protein')) protein = value;
            else if (name.contains('carbohydrate')) carbs = value;
            else if (name.contains('total lipid') || name.contains('fat')) fat = value;
            else if (name.contains('fiber')) fiber = value;
            else if (name.contains('sugars')) sugar = value;
            else if (name.contains('sodium')) sodium = value;
          }

          final foodCode = item['fdcId']?.toString() ?? '';
          final description = item['description']?.toString() ?? 'Unknown Food';
          final brandOwner = item['brandOwner']?.toString() ?? item['brandName']?.toString() ?? 'USDA';
          final servingSize = item['servingSize']?.toString() ?? '100';
          final servingSizeUnit = item['servingSizeUnit']?.toString() ?? 'g';
          
          foods.add(FoodDatabaseEntry(
            id: 'usda_$foodCode',
            name: description,
            brand: brandOwner,
            category: 'USDA Database',
            macros: NutritionMacros(
              calories: calories.round(),
              proteinG: protein,
              carbsG: carbs,
              fatsG: fat,
              fiberG: fiber,
              sugarG: sugar,
              sodiumMg: sodium.round(),
            ),
            servingSize: '$servingSize$servingSizeUnit',
            servingSizeG: double.tryParse(servingSize) ?? 100,
            searchTags: [description.toLowerCase()],
          ));
        } catch (e) {
          debugPrint('[FoodDatabaseService] Error parsing USDA food item: $e');
        }
      }
      
      debugPrint('[FoodDatabaseService] Successfully parsed ${foods.length} foods from API response');
      return foods;
    } catch (e) {
      debugPrint('[FoodDatabaseService] searchUSDAFoods error: $e');
      rethrow;
    }
  }

  /// Search foods by query with smart ranking (includes custom foods)
  List<FoodDatabaseEntry> searchFoods(String query, {
    String? category,
    String? brand,
    int limit = 50,
  }) {
    if (!_initialized) {
      initialize();
      return [];
    }
    
    // Combine built-in foods with custom foods
    final allFoods = [
      ..._database,
      ..._customFoods.map((cf) => cf.toFoodDatabaseEntry()),
    ];
    
    if (query.trim().isEmpty && category == null && brand == null) {
      return allFoods.take(limit).toList();
    }

    final q = query.trim().toLowerCase();
    final results = <({FoodDatabaseEntry food, int score})>[];

    for (final food in allFoods) {
      // Category filter
      if (category != null && food.category != category) continue;
      
      // Brand filter
      if (brand != null && food.brand != brand) continue;

      // Score calculation
      int score = 0;
      final nameLower = food.name.toLowerCase();
      final brandLower = food.brand.toLowerCase();

      // Exact match (highest priority)
      if (nameLower == q || brandLower == q) {
        score += 1000;
      }

      // Starts with query
      if (nameLower.startsWith(q) || brandLower.startsWith(q)) {
        score += 500;
      }

      // Contains query
      if (nameLower.contains(q) || brandLower.contains(q)) {
        score += 250;
      }

      // Search tags match
      for (final tag in food.searchTags) {
        final tagLower = tag.toLowerCase();
        if (tagLower == q) score += 400;
        if (tagLower.startsWith(q)) score += 200;
        if (tagLower.contains(q)) score += 100;
      }

      // Multi-word matching
      final queryWords = q.split(' ').where((w) => w.isNotEmpty).toList();
      if (queryWords.length > 1) {
        final fullText = '$nameLower $brandLower ${food.searchTags.join(' ').toLowerCase()}';
        int wordMatches = 0;
        for (final word in queryWords) {
          if (fullText.contains(word)) wordMatches++;
        }
        if (wordMatches == queryWords.length) score += 300;
        if (wordMatches > 0) score += wordMatches * 50;
      }

      if (score > 0) {
        results.add((food: food, score: score));
      }
    }

    // Sort by score descending
    results.sort((a, b) => b.score.compareTo(a.score));

    return results.take(limit).map((r) => r.food).toList();
  }

  /// Get all unique brands
  List<String> getAllBrands() {
    if (!_initialized) initialize();
    return _database.map((f) => f.brand).toSet().toList()..sort();
  }

  /// Get all unique categories
  List<String> getAllCategories() {
    if (!_initialized) initialize();
    return _database.map((f) => f.category).toSet().toList()..sort();
  }

  /// Get foods by brand
  List<FoodDatabaseEntry> getFoodsByBrand(String brand) {
    if (!_initialized) initialize();
    return _database.where((f) => f.brand == brand).toList();
  }

  /// Get foods by category
  List<FoodDatabaseEntry> getFoodsByCategory(String category) {
    if (!_initialized) initialize();
    return _database.where((f) => f.category == category).toList();
  }

  /// Build the comprehensive food database
  List<FoodDatabaseEntry> _buildDatabase() {
    final foods = <FoodDatabaseEntry>[];

    // ========== FAST FOOD CHAINS ==========

    // McDonald's
    foods.addAll([
      FoodDatabaseEntry(
        id: 'mcdonalds_bigmac',
        name: 'Big Mac',
        brand: "McDonald's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 550, proteinG: 25, carbsG: 45, fatsG: 30, fiberG: 3, sugarG: 9, sodiumMg: 1010),
        servingSize: '1 sandwich',
        servingSizeG: 219,
        searchTags: ['burger', 'sandwich', 'beef'],
      ),
      FoodDatabaseEntry(
        id: 'mcdonalds_quarter_pounder',
        name: 'Quarter Pounder with Cheese',
        brand: "McDonald's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 520, proteinG: 30, carbsG: 41, fatsG: 26, fiberG: 3, sugarG: 10, sodiumMg: 1120),
        servingSize: '1 sandwich',
        servingSizeG: 199,
        searchTags: ['burger', 'cheese', 'beef'],
      ),
      FoodDatabaseEntry(
        id: 'mcdonalds_mcchicken',
        name: 'McChicken',
        brand: "McDonald's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 400, proteinG: 14, carbsG: 39, fatsG: 21, fiberG: 2, sugarG: 5, sodiumMg: 560),
        servingSize: '1 sandwich',
        servingSizeG: 145,
        searchTags: ['chicken', 'sandwich', 'fried'],
      ),
      FoodDatabaseEntry(
        id: 'mcdonalds_nuggets_6pc',
        name: 'Chicken McNuggets (6 piece)',
        brand: "McDonald's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 250, proteinG: 15, carbsG: 15, fatsG: 15, fiberG: 1, sugarG: 0, sodiumMg: 450),
        servingSize: '6 pieces',
        servingSizeG: 96,
        searchTags: ['chicken', 'nuggets', 'fried'],
      ),
      FoodDatabaseEntry(
        id: 'mcdonalds_fries_medium',
        name: 'French Fries (Medium)',
        brand: "McDonald's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 340, proteinG: 4, carbsG: 44, fatsG: 16, fiberG: 4, sugarG: 0, sodiumMg: 230),
        servingSize: '1 medium',
        servingSizeG: 117,
        searchTags: ['fries', 'potato', 'fried'],
      ),
      FoodDatabaseEntry(
        id: 'mcdonalds_egg_mcmuffin',
        name: 'Egg McMuffin',
        brand: "McDonald's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 310, proteinG: 17, carbsG: 30, fatsG: 13, fiberG: 2, sugarG: 3, sodiumMg: 770),
        servingSize: '1 sandwich',
        servingSizeG: 142,
        searchTags: ['breakfast', 'egg', 'muffin'],
      ),
    ]);

    // Burger King
    foods.addAll([
      FoodDatabaseEntry(
        id: 'bk_whopper',
        name: 'Whopper',
        brand: 'Burger King',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 657, proteinG: 28, carbsG: 49, fatsG: 40, fiberG: 2, sugarG: 11, sodiumMg: 980),
        servingSize: '1 sandwich',
        servingSizeG: 290,
        searchTags: ['burger', 'beef', 'sandwich'],
      ),
      FoodDatabaseEntry(
        id: 'bk_chicken_sandwich',
        name: 'Chicken Sandwich',
        brand: 'Burger King',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 670, proteinG: 28, carbsG: 48, fatsG: 40, fiberG: 2, sugarG: 6, sodiumMg: 1360),
        servingSize: '1 sandwich',
        servingSizeG: 219,
        searchTags: ['chicken', 'sandwich', 'fried'],
      ),
      FoodDatabaseEntry(
        id: 'bk_fries_medium',
        name: 'French Fries (Medium)',
        brand: 'Burger King',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 380, proteinG: 4, carbsG: 49, fatsG: 18, fiberG: 4, sugarG: 0, sodiumMg: 530),
        servingSize: '1 medium',
        servingSizeG: 116,
        searchTags: ['fries', 'potato', 'fried'],
      ),
    ]);

    // Subway
    foods.addAll([
      FoodDatabaseEntry(
        id: 'subway_turkey_6inch',
        name: 'Turkey Breast (6 inch)',
        brand: 'Subway',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 280, proteinG: 18, carbsG: 46, fatsG: 3.5, fiberG: 5, sugarG: 8, sodiumMg: 810),
        servingSize: '6 inch sub',
        servingSizeG: 238,
        searchTags: ['sub', 'sandwich', 'turkey', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'subway_bmt_6inch',
        name: 'Italian B.M.T. (6 inch)',
        brand: 'Subway',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 410, proteinG: 19, carbsG: 46, fatsG: 16, fiberG: 5, sugarG: 8, sodiumMg: 1260),
        servingSize: '6 inch sub',
        servingSizeG: 243,
        searchTags: ['sub', 'sandwich', 'italian', 'meat'],
      ),
      FoodDatabaseEntry(
        id: 'subway_veggie_6inch',
        name: 'Veggie Delite (6 inch)',
        brand: 'Subway',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 230, proteinG: 8, carbsG: 44, fatsG: 2.5, fiberG: 5, sugarG: 7, sodiumMg: 410),
        servingSize: '6 inch sub',
        servingSizeG: 166,
        searchTags: ['sub', 'sandwich', 'vegetarian', 'veggie', 'healthy'],
      ),
    ]);

    // Starbucks
    foods.addAll([
      FoodDatabaseEntry(
        id: 'starbucks_latte_grande',
        name: 'Caffè Latte (Grande)',
        brand: 'Starbucks',
        category: 'Beverages',
        macros: const NutritionMacros(calories: 190, proteinG: 12, carbsG: 18, fatsG: 7, fiberG: 0, sugarG: 17, sodiumMg: 150),
        servingSize: '16 fl oz',
        servingSizeG: 473,
        searchTags: ['coffee', 'milk', 'latte', 'drink'],
      ),
      FoodDatabaseEntry(
        id: 'starbucks_frappuccino_grande',
        name: 'Caramel Frappuccino (Grande)',
        brand: 'Starbucks',
        category: 'Beverages',
        macros: const NutritionMacros(calories: 380, proteinG: 5, carbsG: 66, fatsG: 15, fiberG: 0, sugarG: 54, sodiumMg: 230),
        servingSize: '16 fl oz',
        servingSizeG: 473,
        searchTags: ['coffee', 'sweet', 'caramel', 'frozen', 'drink'],
      ),
      FoodDatabaseEntry(
        id: 'starbucks_bagel',
        name: 'Plain Bagel',
        brand: 'Starbucks',
        category: 'Breakfast',
        macros: const NutritionMacros(calories: 280, proteinG: 10, carbsG: 56, fatsG: 1.5, fiberG: 2, sugarG: 6, sodiumMg: 450),
        servingSize: '1 bagel',
        servingSizeG: 113,
        searchTags: ['bagel', 'bread', 'breakfast'],
      ),
    ]);

    // Chipotle
    foods.addAll([
      FoodDatabaseEntry(
        id: 'chipotle_chicken_bowl',
        name: 'Chicken Bowl (with rice, beans, cheese)',
        brand: 'Chipotle',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 630, proteinG: 45, carbsG: 62, fatsG: 21, fiberG: 11, sugarG: 4, sodiumMg: 1530),
        servingSize: '1 bowl',
        servingSizeG: 510,
        searchTags: ['bowl', 'chicken', 'mexican', 'rice', 'beans'],
      ),
      FoodDatabaseEntry(
        id: 'chipotle_burrito',
        name: 'Chicken Burrito',
        brand: 'Chipotle',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 1020, proteinG: 61, carbsG: 110, fatsG: 37, fiberG: 18, sugarG: 5, sodiumMg: 2310),
        servingSize: '1 burrito',
        servingSizeG: 635,
        searchTags: ['burrito', 'chicken', 'mexican', 'wrap'],
      ),
    ]);

    // Pizza Hut
    foods.addAll([
      FoodDatabaseEntry(
        id: 'pizzahut_pepperoni_slice',
        name: 'Pepperoni Pizza (1 slice, large)',
        brand: 'Pizza Hut',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 280, proteinG: 12, carbsG: 30, fatsG: 12, fiberG: 2, sugarG: 3, sodiumMg: 640),
        servingSize: '1 slice',
        servingSizeG: 105,
        searchTags: ['pizza', 'pepperoni', 'cheese'],
      ),
      FoodDatabaseEntry(
        id: 'pizzahut_cheese_slice',
        name: 'Cheese Pizza (1 slice, large)',
        brand: 'Pizza Hut',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 240, proteinG: 10, carbsG: 29, fatsG: 9, fiberG: 2, sugarG: 3, sodiumMg: 520),
        servingSize: '1 slice',
        servingSizeG: 95,
        searchTags: ['pizza', 'cheese'],
      ),
    ]);

    // Panera Bread
    foods.addAll([
      FoodDatabaseEntry(
        id: 'panera_chicken_noodle_soup',
        name: 'Chicken Noodle Soup (Cup)',
        brand: 'Panera Bread',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 120, proteinG: 9, carbsG: 14, fatsG: 3, fiberG: 1, sugarG: 2, sodiumMg: 860),
        servingSize: '1 cup (8 oz)',
        servingSizeG: 227,
        searchTags: ['soup', 'chicken', 'noodle', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'panera_caesar_salad',
        name: 'Caesar Salad (whole)',
        brand: 'Panera Bread',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 440, proteinG: 23, carbsG: 16, fatsG: 32, fiberG: 4, sugarG: 3, sodiumMg: 980),
        servingSize: '1 salad',
        servingSizeG: 315,
        searchTags: ['salad', 'caesar', 'lettuce', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'panera_broccoli_cheddar_soup',
        name: 'Broccoli Cheddar Soup (Cup)',
        brand: 'Panera Bread',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 230, proteinG: 9, carbsG: 16, fatsG: 15, fiberG: 2, sugarG: 4, sodiumMg: 860),
        servingSize: '1 cup (8 oz)',
        servingSizeG: 227,
        searchTags: ['soup', 'broccoli', 'cheese', 'cheddar'],
      ),
    ]);

    // Wendy's
    foods.addAll([
      FoodDatabaseEntry(
        id: 'wendys_dave_single',
        name: "Dave's Single",
        brand: "Wendy's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 570, proteinG: 30, carbsG: 39, fatsG: 34, fiberG: 2, sugarG: 8, sodiumMg: 940),
        servingSize: '1 burger',
        servingSizeG: 271,
        searchTags: ['burger', 'beef', 'sandwich'],
      ),
      FoodDatabaseEntry(
        id: 'wendys_chicken_nuggets_10pc',
        name: 'Chicken Nuggets (10 piece)',
        brand: "Wendy's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 450, proteinG: 21, carbsG: 30, fatsG: 28, fiberG: 2, sugarG: 0, sodiumMg: 890),
        servingSize: '10 pieces',
        servingSizeG: 155,
        searchTags: ['chicken', 'nuggets', 'fried'],
      ),
      FoodDatabaseEntry(
        id: 'wendys_spicy_chicken',
        name: 'Spicy Chicken Sandwich',
        brand: "Wendy's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 500, proteinG: 28, carbsG: 49, fatsG: 21, fiberG: 2, sugarG: 7, sodiumMg: 1240),
        servingSize: '1 sandwich',
        servingSizeG: 218,
        searchTags: ['chicken', 'spicy', 'sandwich'],
      ),
      FoodDatabaseEntry(
        id: 'wendys_chili',
        name: 'Chili (small)',
        brand: "Wendy's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 240, proteinG: 17, carbsG: 24, fatsG: 7, fiberG: 6, sugarG: 7, sodiumMg: 880),
        servingSize: '1 small',
        servingSizeG: 227,
        searchTags: ['chili', 'soup', 'beans', 'beef'],
      ),
    ]);

    // Taco Bell
    foods.addAll([
      FoodDatabaseEntry(
        id: 'tacobell_crunchy_taco',
        name: 'Crunchy Taco',
        brand: 'Taco Bell',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 170, proteinG: 8, carbsG: 13, fatsG: 9, fiberG: 3, sugarG: 1, sodiumMg: 310),
        servingSize: '1 taco',
        servingSizeG: 78,
        searchTags: ['taco', 'mexican', 'beef', 'crunchy'],
      ),
      FoodDatabaseEntry(
        id: 'tacobell_bean_burrito',
        name: 'Bean Burrito',
        brand: 'Taco Bell',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 350, proteinG: 13, carbsG: 54, fatsG: 9, fiberG: 8, sugarG: 3, sodiumMg: 1050),
        servingSize: '1 burrito',
        servingSizeG: 198,
        searchTags: ['burrito', 'beans', 'mexican', 'vegetarian'],
      ),
      FoodDatabaseEntry(
        id: 'tacobell_quesadilla',
        name: 'Chicken Quesadilla',
        brand: 'Taco Bell',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 510, proteinG: 27, carbsG: 38, fatsG: 27, fiberG: 3, sugarG: 4, sodiumMg: 1250),
        servingSize: '1 quesadilla',
        servingSizeG: 184,
        searchTags: ['quesadilla', 'chicken', 'cheese', 'mexican'],
      ),
      FoodDatabaseEntry(
        id: 'tacobell_chalupa',
        name: 'Beef Chalupa Supreme',
        brand: 'Taco Bell',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 350, proteinG: 13, carbsG: 30, fatsG: 19, fiberG: 3, sugarG: 5, sodiumMg: 580),
        servingSize: '1 chalupa',
        servingSizeG: 153,
        searchTags: ['chalupa', 'beef', 'mexican'],
      ),
    ]);

    // KFC
    foods.addAll([
      FoodDatabaseEntry(
        id: 'kfc_original_chicken',
        name: 'Original Recipe Chicken Breast',
        brand: 'KFC',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 390, proteinG: 39, carbsG: 11, fatsG: 21, fiberG: 0, sugarG: 0, sodiumMg: 1150),
        servingSize: '1 breast',
        servingSizeG: 161,
        searchTags: ['chicken', 'fried', 'breast'],
      ),
      FoodDatabaseEntry(
        id: 'kfc_coleslaw',
        name: 'Coleslaw (individual)',
        brand: 'KFC',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 170, proteinG: 1, carbsG: 13, fatsG: 13, fiberG: 2, sugarG: 10, sodiumMg: 230),
        servingSize: '1 serving',
        servingSizeG: 113,
        searchTags: ['coleslaw', 'salad', 'side'],
      ),
      FoodDatabaseEntry(
        id: 'kfc_mashed_potatoes',
        name: 'Mashed Potatoes with Gravy',
        brand: 'KFC',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 120, proteinG: 2, carbsG: 18, fatsG: 4.5, fiberG: 1, sugarG: 1, sodiumMg: 520),
        servingSize: '1 individual',
        servingSizeG: 136,
        searchTags: ['potatoes', 'mashed', 'gravy', 'side'],
      ),
      FoodDatabaseEntry(
        id: 'kfc_biscuit',
        name: 'Biscuit',
        brand: 'KFC',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 180, proteinG: 3, carbsG: 22, fatsG: 9, fiberG: 1, sugarG: 2, sodiumMg: 570),
        servingSize: '1 biscuit',
        servingSizeG: 57,
        searchTags: ['biscuit', 'bread', 'side'],
      ),
    ]);

    // Domino's
    foods.addAll([
      FoodDatabaseEntry(
        id: 'dominos_pepperoni_medium',
        name: 'Pepperoni Pizza (1 slice, medium hand-tossed)',
        brand: "Domino's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 290, proteinG: 12, carbsG: 33, fatsG: 12, fiberG: 2, sugarG: 3, sodiumMg: 690),
        servingSize: '1 slice',
        servingSizeG: 102,
        searchTags: ['pizza', 'pepperoni', 'cheese'],
      ),
      FoodDatabaseEntry(
        id: 'dominos_cheese_medium',
        name: 'Cheese Pizza (1 slice, medium hand-tossed)',
        brand: "Domino's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 250, proteinG: 10, carbsG: 32, fatsG: 9, fiberG: 2, sugarG: 3, sodiumMg: 560),
        servingSize: '1 slice',
        servingSizeG: 90,
        searchTags: ['pizza', 'cheese'],
      ),
      FoodDatabaseEntry(
        id: 'dominos_chicken_wings',
        name: 'Hot Buffalo Wings (1 piece)',
        brand: "Domino's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 60, proteinG: 5, carbsG: 1, fatsG: 4, fiberG: 0, sugarG: 0, sodiumMg: 390),
        servingSize: '1 piece',
        servingSizeG: 26,
        searchTags: ['wings', 'chicken', 'buffalo', 'spicy'],
      ),
    ]);

    // Chick-fil-A
    foods.addAll([
      FoodDatabaseEntry(
        id: 'chickfila_sandwich',
        name: 'Chicken Sandwich',
        brand: 'Chick-fil-A',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 440, proteinG: 28, carbsG: 41, fatsG: 19, fiberG: 1, sugarG: 6, sodiumMg: 1820),
        servingSize: '1 sandwich',
        servingSizeG: 183,
        searchTags: ['chicken', 'sandwich', 'fried'],
      ),
      FoodDatabaseEntry(
        id: 'chickfila_nuggets_8pc',
        name: 'Chicken Nuggets (8 count)',
        brand: 'Chick-fil-A',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 250, proteinG: 27, carbsG: 11, fatsG: 11, fiberG: 1, sugarG: 1, sodiumMg: 990),
        servingSize: '8 pieces',
        servingSizeG: 113,
        searchTags: ['chicken', 'nuggets', 'fried'],
      ),
      FoodDatabaseEntry(
        id: 'chickfila_waffle_fries',
        name: 'Waffle Potato Fries (medium)',
        brand: 'Chick-fil-A',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 420, proteinG: 5, carbsG: 45, fatsG: 24, fiberG: 5, sugarG: 0, sodiumMg: 280),
        servingSize: '1 medium',
        servingSizeG: 125,
        searchTags: ['fries', 'waffle', 'potato'],
      ),
      FoodDatabaseEntry(
        id: 'chickfila_grilled_sandwich',
        name: 'Grilled Chicken Sandwich',
        brand: 'Chick-fil-A',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 390, proteinG: 29, carbsG: 44, fatsG: 12, fiberG: 3, sugarG: 10, sodiumMg: 840),
        servingSize: '1 sandwich',
        servingSizeG: 225,
        searchTags: ['chicken', 'grilled', 'sandwich', 'healthy'],
      ),
    ]);

    // Dunkin' Donuts
    foods.addAll([
      FoodDatabaseEntry(
        id: 'dunkin_glazed_donut',
        name: 'Glazed Donut',
        brand: "Dunkin'",
        category: 'Breakfast',
        macros: const NutritionMacros(calories: 260, proteinG: 3, carbsG: 33, fatsG: 13, fiberG: 1, sugarG: 12, sodiumMg: 350),
        servingSize: '1 donut',
        servingSizeG: 60,
        searchTags: ['donut', 'glazed', 'sweet', 'breakfast'],
      ),
      FoodDatabaseEntry(
        id: 'dunkin_coffee_medium',
        name: 'Hot Coffee (medium)',
        brand: "Dunkin'",
        category: 'Beverages',
        macros: const NutritionMacros(calories: 5, proteinG: 0, carbsG: 0, fatsG: 0, fiberG: 0, sugarG: 0, sodiumMg: 10),
        servingSize: '14 fl oz',
        servingSizeG: 414,
        searchTags: ['coffee', 'drink', 'hot'],
      ),
      FoodDatabaseEntry(
        id: 'dunkin_latte_medium',
        name: 'Latte (medium)',
        brand: "Dunkin'",
        category: 'Beverages',
        macros: const NutritionMacros(calories: 120, proteinG: 6, carbsG: 10, fatsG: 6, fiberG: 0, sugarG: 9, sodiumMg: 105),
        servingSize: '14 fl oz',
        servingSizeG: 414,
        searchTags: ['coffee', 'latte', 'milk', 'drink'],
      ),
      FoodDatabaseEntry(
        id: 'dunkin_bacon_egg_cheese',
        name: 'Bacon, Egg & Cheese on English Muffin',
        brand: "Dunkin'",
        category: 'Breakfast',
        macros: const NutritionMacros(calories: 410, proteinG: 20, carbsG: 35, fatsG: 21, fiberG: 1, sugarG: 3, sodiumMg: 1030),
        servingSize: '1 sandwich',
        servingSizeG: 165,
        searchTags: ['breakfast', 'sandwich', 'bacon', 'egg'],
      ),
    ]);

    // Arby's
    foods.addAll([
      FoodDatabaseEntry(
        id: 'arbys_roast_beef_classic',
        name: 'Classic Roast Beef',
        brand: "Arby's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 360, proteinG: 23, carbsG: 37, fatsG: 14, fiberG: 2, sugarG: 5, sodiumMg: 970),
        servingSize: '1 sandwich',
        servingSizeG: 154,
        searchTags: ['roast beef', 'sandwich', 'beef'],
      ),
      FoodDatabaseEntry(
        id: 'arbys_curly_fries',
        name: 'Curly Fries (medium)',
        brand: "Arby's",
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 550, proteinG: 7, carbsG: 69, fatsG: 28, fiberG: 6, sugarG: 1, sodiumMg: 1480),
        servingSize: '1 medium',
        servingSizeG: 170,
        searchTags: ['fries', 'curly', 'potato'],
      ),
    ]);

    // Five Guys
    foods.addAll([
      FoodDatabaseEntry(
        id: 'fiveguys_hamburger',
        name: 'Hamburger',
        brand: 'Five Guys',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 700, proteinG: 39, carbsG: 40, fatsG: 43, fiberG: 2, sugarG: 8, sodiumMg: 430),
        servingSize: '1 burger',
        servingSizeG: 240,
        searchTags: ['burger', 'beef', 'hamburger'],
      ),
      FoodDatabaseEntry(
        id: 'fiveguys_fries_regular',
        name: 'Five Guys Style Fries (regular)',
        brand: 'Five Guys',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 950, proteinG: 13, carbsG: 122, fatsG: 48, fiberG: 11, sugarG: 2, sodiumMg: 450),
        servingSize: '1 regular',
        servingSizeG: 350,
        searchTags: ['fries', 'potato', 'cajun'],
      ),
      FoodDatabaseEntry(
        id: 'fiveguys_grilled_cheese',
        name: 'Grilled Cheese Sandwich',
        brand: 'Five Guys',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 470, proteinG: 19, carbsG: 40, fatsG: 26, fiberG: 2, sugarG: 8, sodiumMg: 1040),
        servingSize: '1 sandwich',
        servingSizeG: 180,
        searchTags: ['grilled cheese', 'sandwich', 'cheese', 'vegetarian'],
      ),
    ]);

    // Panda Express
    foods.addAll([
      FoodDatabaseEntry(
        id: 'panda_orange_chicken',
        name: 'Orange Chicken',
        brand: 'Panda Express',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 490, proteinG: 19, carbsG: 51, fatsG: 23, fiberG: 2, sugarG: 19, sodiumMg: 620),
        servingSize: '1 serving',
        servingSizeG: 156,
        searchTags: ['chicken', 'orange', 'chinese', 'sweet'],
      ),
      FoodDatabaseEntry(
        id: 'panda_fried_rice',
        name: 'Fried Rice',
        brand: 'Panda Express',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 520, proteinG: 11, carbsG: 85, fatsG: 16, fiberG: 2, sugarG: 3, sodiumMg: 850),
        servingSize: '1 serving',
        servingSizeG: 227,
        searchTags: ['rice', 'fried rice', 'chinese'],
      ),
      FoodDatabaseEntry(
        id: 'panda_beijing_beef',
        name: 'Beijing Beef',
        brand: 'Panda Express',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 470, proteinG: 13, carbsG: 46, fatsG: 26, fiberG: 2, sugarG: 24, sodiumMg: 890),
        servingSize: '1 serving',
        servingSizeG: 170,
        searchTags: ['beef', 'chinese', 'sweet', 'spicy'],
      ),
      FoodDatabaseEntry(
        id: 'panda_chow_mein',
        name: 'Chow Mein',
        brand: 'Panda Express',
        category: 'Fast Food',
        macros: const NutritionMacros(calories: 510, proteinG: 13, carbsG: 80, fatsG: 17, fiberG: 6, sugarG: 8, sodiumMg: 860),
        servingSize: '1 serving',
        servingSizeG: 227,
        searchTags: ['noodles', 'chow mein', 'chinese'],
      ),
    ]);

    // ========== GENERIC COMMON FOODS ==========

    // Fruits
    foods.addAll([
      FoodDatabaseEntry(
        id: 'apple',
        name: 'Apple',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 95, proteinG: 0.5, carbsG: 25, fatsG: 0.3, fiberG: 4, sugarG: 19, sodiumMg: 2),
        servingSize: '1 medium (182g)',
        servingSizeG: 182,
        searchTags: ['fruit', 'healthy', 'snack'],
      ),
      FoodDatabaseEntry(
        id: 'banana',
        name: 'Banana',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 105, proteinG: 1.3, carbsG: 27, fatsG: 0.4, fiberG: 3, sugarG: 14, sodiumMg: 1),
        servingSize: '1 medium (118g)',
        servingSizeG: 118,
        searchTags: ['fruit', 'healthy', 'snack', 'potassium'],
      ),
      FoodDatabaseEntry(
        id: 'orange',
        name: 'Orange',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 62, proteinG: 1.2, carbsG: 15, fatsG: 0.2, fiberG: 3, sugarG: 12, sodiumMg: 0),
        servingSize: '1 medium (131g)',
        servingSizeG: 131,
        searchTags: ['fruit', 'citrus', 'healthy', 'vitamin c'],
      ),
      FoodDatabaseEntry(
        id: 'strawberries',
        name: 'Strawberries',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 46, proteinG: 1, carbsG: 11, fatsG: 0.4, fiberG: 3, sugarG: 7, sodiumMg: 1),
        servingSize: '1 cup (144g)',
        servingSizeG: 144,
        searchTags: ['fruit', 'berries', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'blueberries',
        name: 'Blueberries',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 84, proteinG: 1.1, carbsG: 21, fatsG: 0.5, fiberG: 3.6, sugarG: 15, sodiumMg: 1),
        servingSize: '1 cup (148g)',
        servingSizeG: 148,
        searchTags: ['fruit', 'berries', 'healthy', 'antioxidants'],
      ),
      FoodDatabaseEntry(
        id: 'grapes',
        name: 'Grapes',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 104, proteinG: 1.1, carbsG: 27, fatsG: 0.2, fiberG: 1.4, sugarG: 23, sodiumMg: 3),
        servingSize: '1 cup (151g)',
        servingSizeG: 151,
        searchTags: ['fruit', 'snack', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'watermelon',
        name: 'Watermelon',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 46, proteinG: 0.9, carbsG: 11, fatsG: 0.2, fiberG: 0.6, sugarG: 9, sodiumMg: 2),
        servingSize: '1 cup (154g)',
        servingSizeG: 154,
        searchTags: ['fruit', 'melon', 'hydrating', 'summer'],
      ),
      FoodDatabaseEntry(
        id: 'pineapple',
        name: 'Pineapple',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 82, proteinG: 0.9, carbsG: 22, fatsG: 0.2, fiberG: 2.3, sugarG: 16, sodiumMg: 2),
        servingSize: '1 cup chunks (165g)',
        servingSizeG: 165,
        searchTags: ['fruit', 'tropical', 'vitamin c'],
      ),
      FoodDatabaseEntry(
        id: 'mango',
        name: 'Mango',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 99, proteinG: 1.4, carbsG: 25, fatsG: 0.6, fiberG: 2.6, sugarG: 23, sodiumMg: 1),
        servingSize: '1 cup (165g)',
        servingSizeG: 165,
        searchTags: ['fruit', 'tropical', 'sweet'],
      ),
      FoodDatabaseEntry(
        id: 'peach',
        name: 'Peach',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 59, proteinG: 1.4, carbsG: 14, fatsG: 0.4, fiberG: 2.3, sugarG: 13, sodiumMg: 0),
        servingSize: '1 medium (150g)',
        servingSizeG: 150,
        searchTags: ['fruit', 'stone fruit', 'summer'],
      ),
      FoodDatabaseEntry(
        id: 'pear',
        name: 'Pear',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 101, proteinG: 0.6, carbsG: 27, fatsG: 0.2, fiberG: 5.5, sugarG: 17, sodiumMg: 2),
        servingSize: '1 medium (178g)',
        servingSizeG: 178,
        searchTags: ['fruit', 'fiber', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'raspberries',
        name: 'Raspberries',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 64, proteinG: 1.5, carbsG: 15, fatsG: 0.8, fiberG: 8, sugarG: 5, sodiumMg: 1),
        servingSize: '1 cup (123g)',
        servingSizeG: 123,
        searchTags: ['fruit', 'berries', 'fiber', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'blackberries',
        name: 'Blackberries',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 62, proteinG: 2, carbsG: 14, fatsG: 0.7, fiberG: 7.6, sugarG: 7, sodiumMg: 1),
        servingSize: '1 cup (144g)',
        servingSizeG: 144,
        searchTags: ['fruit', 'berries', 'fiber', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'cantaloupe',
        name: 'Cantaloupe',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 54, proteinG: 1.3, carbsG: 13, fatsG: 0.3, fiberG: 1.6, sugarG: 12, sodiumMg: 26),
        servingSize: '1 cup (177g)',
        servingSizeG: 177,
        searchTags: ['fruit', 'melon', 'vitamin a'],
      ),
      FoodDatabaseEntry(
        id: 'kiwi',
        name: 'Kiwi',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 42, proteinG: 0.8, carbsG: 10, fatsG: 0.4, fiberG: 2.1, sugarG: 6, sodiumMg: 2),
        servingSize: '1 medium (69g)',
        servingSizeG: 69,
        searchTags: ['fruit', 'vitamin c', 'tropical'],
      ),
      FoodDatabaseEntry(
        id: 'cherries',
        name: 'Cherries',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 87, proteinG: 1.5, carbsG: 22, fatsG: 0.3, fiberG: 3, sugarG: 18, sodiumMg: 0),
        servingSize: '1 cup (138g)',
        servingSizeG: 138,
        searchTags: ['fruit', 'stone fruit', 'antioxidants'],
      ),
      FoodDatabaseEntry(
        id: 'grapefruit',
        name: 'Grapefruit',
        brand: 'Generic',
        category: 'Fruits',
        macros: const NutritionMacros(calories: 52, proteinG: 0.9, carbsG: 13, fatsG: 0.2, fiberG: 2, sugarG: 9, sodiumMg: 0),
        servingSize: '1/2 medium (123g)',
        servingSizeG: 123,
        searchTags: ['fruit', 'citrus', 'vitamin c', 'tangy'],
      ),
    ]);

    // Vegetables
    foods.addAll([
      FoodDatabaseEntry(
        id: 'broccoli',
        name: 'Broccoli (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 55, proteinG: 3.7, carbsG: 11, fatsG: 0.6, fiberG: 5, sugarG: 2, sodiumMg: 64),
        servingSize: '1 cup (156g)',
        servingSizeG: 156,
        searchTags: ['vegetable', 'healthy', 'green'],
      ),
      FoodDatabaseEntry(
        id: 'carrot',
        name: 'Carrot',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 25, proteinG: 0.6, carbsG: 6, fatsG: 0.1, fiberG: 2, sugarG: 3, sodiumMg: 42),
        servingSize: '1 medium (61g)',
        servingSizeG: 61,
        searchTags: ['vegetable', 'healthy', 'orange'],
      ),
      FoodDatabaseEntry(
        id: 'salad_mix',
        name: 'Mixed Green Salad',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 15, proteinG: 1, carbsG: 3, fatsG: 0.2, fiberG: 2, sugarG: 1, sodiumMg: 15),
        servingSize: '1 cup (55g)',
        servingSizeG: 55,
        searchTags: ['salad', 'lettuce', 'healthy', 'green'],
      ),
      FoodDatabaseEntry(
        id: 'spinach',
        name: 'Spinach (raw)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 7, proteinG: 0.9, carbsG: 1, fatsG: 0.1, fiberG: 0.7, sugarG: 0.1, sodiumMg: 24),
        servingSize: '1 cup (30g)',
        servingSizeG: 30,
        searchTags: ['vegetable', 'leafy', 'green', 'iron'],
      ),
      FoodDatabaseEntry(
        id: 'tomato',
        name: 'Tomato',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 22, proteinG: 1.1, carbsG: 5, fatsG: 0.2, fiberG: 1.5, sugarG: 3.2, sodiumMg: 6),
        servingSize: '1 medium (123g)',
        servingSizeG: 123,
        searchTags: ['vegetable', 'salad', 'red'],
      ),
      FoodDatabaseEntry(
        id: 'bell_pepper',
        name: 'Bell Pepper (red)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 37, proteinG: 1.2, carbsG: 9, fatsG: 0.4, fiberG: 3, sugarG: 6, sodiumMg: 5),
        servingSize: '1 medium (119g)',
        servingSizeG: 119,
        searchTags: ['vegetable', 'pepper', 'vitamin c'],
      ),
      FoodDatabaseEntry(
        id: 'cucumber',
        name: 'Cucumber',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 16, proteinG: 0.7, carbsG: 4, fatsG: 0.2, fiberG: 0.5, sugarG: 2, sodiumMg: 2),
        servingSize: '1 cup (104g)',
        servingSizeG: 104,
        searchTags: ['vegetable', 'hydrating', 'salad'],
      ),
      FoodDatabaseEntry(
        id: 'cauliflower',
        name: 'Cauliflower (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 29, proteinG: 2.3, carbsG: 6, fatsG: 0.6, fiberG: 2.9, sugarG: 2.4, sodiumMg: 32),
        servingSize: '1 cup (124g)',
        servingSizeG: 124,
        searchTags: ['vegetable', 'white', 'low carb'],
      ),
      FoodDatabaseEntry(
        id: 'zucchini',
        name: 'Zucchini (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 20, proteinG: 1.5, carbsG: 4, fatsG: 0.3, fiberG: 1.4, sugarG: 2.5, sodiumMg: 5),
        servingSize: '1 cup (180g)',
        servingSizeG: 180,
        searchTags: ['vegetable', 'squash', 'low calorie'],
      ),
      FoodDatabaseEntry(
        id: 'green_beans',
        name: 'Green Beans (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 44, proteinG: 2.4, carbsG: 10, fatsG: 0.4, fiberG: 4, sugarG: 5.3, sodiumMg: 1),
        servingSize: '1 cup (125g)',
        servingSizeG: 125,
        searchTags: ['vegetable', 'green', 'beans'],
      ),
      FoodDatabaseEntry(
        id: 'sweet_potato',
        name: 'Sweet Potato (baked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 103, proteinG: 2.3, carbsG: 24, fatsG: 0.2, fiberG: 3.8, sugarG: 7.4, sodiumMg: 41),
        servingSize: '1 medium (114g)',
        servingSizeG: 114,
        searchTags: ['potato', 'sweet', 'vitamin a', 'carb'],
      ),
      FoodDatabaseEntry(
        id: 'potato',
        name: 'Potato (baked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 161, proteinG: 4.3, carbsG: 37, fatsG: 0.2, fiberG: 3.8, sugarG: 1.9, sodiumMg: 10),
        servingSize: '1 medium (173g)',
        servingSizeG: 173,
        searchTags: ['potato', 'carb', 'starch'],
      ),
      FoodDatabaseEntry(
        id: 'corn',
        name: 'Corn (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 143, proteinG: 5, carbsG: 31, fatsG: 2.2, fiberG: 3.6, sugarG: 6.8, sodiumMg: 23),
        servingSize: '1 cup (154g)',
        servingSizeG: 154,
        searchTags: ['corn', 'vegetable', 'sweet'],
      ),
      FoodDatabaseEntry(
        id: 'asparagus',
        name: 'Asparagus (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 27, proteinG: 3, carbsG: 5, fatsG: 0.3, fiberG: 2.8, sugarG: 2, sodiumMg: 13),
        servingSize: '1 cup (134g)',
        servingSizeG: 134,
        searchTags: ['vegetable', 'green', 'asparagus'],
      ),
      FoodDatabaseEntry(
        id: 'mushrooms',
        name: 'Mushrooms (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 44, proteinG: 3.3, carbsG: 8, fatsG: 0.7, fiberG: 3.4, sugarG: 3.3, sodiumMg: 5),
        servingSize: '1 cup (156g)',
        servingSizeG: 156,
        searchTags: ['mushroom', 'vegetable', 'umami'],
      ),
      FoodDatabaseEntry(
        id: 'onion',
        name: 'Onion',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 44, proteinG: 1.2, carbsG: 10, fatsG: 0.1, fiberG: 1.9, sugarG: 4.7, sodiumMg: 4),
        servingSize: '1 medium (110g)',
        servingSizeG: 110,
        searchTags: ['onion', 'vegetable', 'aromatic'],
      ),
      FoodDatabaseEntry(
        id: 'kale',
        name: 'Kale (raw)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 33, proteinG: 2.9, carbsG: 6, fatsG: 0.6, fiberG: 2.6, sugarG: 2.3, sodiumMg: 29),
        servingSize: '1 cup (67g)',
        servingSizeG: 67,
        searchTags: ['kale', 'superfood', 'leafy', 'green'],
      ),
      FoodDatabaseEntry(
        id: 'brussels_sprouts',
        name: 'Brussels Sprouts (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 56, proteinG: 4, carbsG: 11, fatsG: 0.8, fiberG: 4.1, sugarG: 2.7, sodiumMg: 33),
        servingSize: '1 cup (156g)',
        servingSizeG: 156,
        searchTags: ['vegetable', 'cruciferous', 'green'],
      ),
      FoodDatabaseEntry(
        id: 'eggplant',
        name: 'Eggplant (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 35, proteinG: 0.8, carbsG: 9, fatsG: 0.2, fiberG: 2.5, sugarG: 3.2, sodiumMg: 1),
        servingSize: '1 cup (99g)',
        servingSizeG: 99,
        searchTags: ['eggplant', 'vegetable', 'purple'],
      ),
    ]);

    // Proteins
    foods.addAll([
      FoodDatabaseEntry(
        id: 'chicken_breast',
        name: 'Chicken Breast (grilled)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 165, proteinG: 31, carbsG: 0, fatsG: 3.6, fiberG: 0, sugarG: 0, sodiumMg: 74),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['chicken', 'meat', 'protein', 'lean'],
      ),
      FoodDatabaseEntry(
        id: 'salmon',
        name: 'Salmon (grilled)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 175, proteinG: 25, carbsG: 0, fatsG: 8, fiberG: 0, sugarG: 0, sodiumMg: 75),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['fish', 'seafood', 'protein', 'omega3'],
      ),
      FoodDatabaseEntry(
        id: 'eggs',
        name: 'Eggs (scrambled)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 140, proteinG: 12, carbsG: 2, fatsG: 10, fiberG: 0, sugarG: 2, sodiumMg: 170),
        servingSize: '2 large eggs',
        servingSizeG: 100,
        searchTags: ['egg', 'breakfast', 'protein'],
      ),
      FoodDatabaseEntry(
        id: 'ground_beef',
        name: 'Ground Beef (cooked, 80% lean)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 230, proteinG: 22, carbsG: 0, fatsG: 15, fiberG: 0, sugarG: 0, sodiumMg: 75),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['beef', 'meat', 'protein'],
      ),
      FoodDatabaseEntry(
        id: 'turkey_breast',
        name: 'Turkey Breast (roasted)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 125, proteinG: 26, carbsG: 0, fatsG: 1.8, fiberG: 0, sugarG: 0, sodiumMg: 55),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['turkey', 'meat', 'protein', 'lean'],
      ),
      FoodDatabaseEntry(
        id: 'tuna',
        name: 'Tuna (canned in water)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 90, proteinG: 20, carbsG: 0, fatsG: 1, fiberG: 0, sugarG: 0, sodiumMg: 320),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['tuna', 'fish', 'seafood', 'canned'],
      ),
      FoodDatabaseEntry(
        id: 'shrimp',
        name: 'Shrimp (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 84, proteinG: 18, carbsG: 0, fatsG: 1, fiberG: 0, sugarG: 0, sodiumMg: 190),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['shrimp', 'seafood', 'protein', 'low calorie'],
      ),
      FoodDatabaseEntry(
        id: 'pork_chop',
        name: 'Pork Chop (grilled)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 180, proteinG: 25, carbsG: 0, fatsG: 8, fiberG: 0, sugarG: 0, sodiumMg: 60),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['pork', 'meat', 'protein'],
      ),
      FoodDatabaseEntry(
        id: 'bacon',
        name: 'Bacon (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 126, proteinG: 9, carbsG: 1, fatsG: 10, fiberG: 0, sugarG: 0, sodiumMg: 450),
        servingSize: '3 slices',
        servingSizeG: 30,
        searchTags: ['bacon', 'pork', 'breakfast'],
      ),
      FoodDatabaseEntry(
        id: 'steak',
        name: 'Steak (sirloin, grilled)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 180, proteinG: 26, carbsG: 0, fatsG: 7.5, fiberG: 0, sugarG: 0, sodiumMg: 65),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['steak', 'beef', 'protein', 'meat'],
      ),
      FoodDatabaseEntry(
        id: 'chicken_thigh',
        name: 'Chicken Thigh (roasted)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 180, proteinG: 22, carbsG: 0, fatsG: 9.5, fiberG: 0, sugarG: 0, sodiumMg: 80),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['chicken', 'meat', 'protein', 'dark meat'],
      ),
      FoodDatabaseEntry(
        id: 'tilapia',
        name: 'Tilapia (baked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 110, proteinG: 23, carbsG: 0, fatsG: 2.5, fiberG: 0, sugarG: 0, sodiumMg: 50),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['tilapia', 'fish', 'protein', 'lean'],
      ),
      FoodDatabaseEntry(
        id: 'tofu',
        name: 'Tofu (firm)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 94, proteinG: 10, carbsG: 2.3, fatsG: 5, fiberG: 1, sugarG: 0, sodiumMg: 10),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['tofu', 'soy', 'protein', 'vegetarian', 'vegan'],
      ),
      FoodDatabaseEntry(
        id: 'black_beans',
        name: 'Black Beans (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 227, proteinG: 15, carbsG: 41, fatsG: 0.9, fiberG: 15, sugarG: 0.6, sodiumMg: 2),
        servingSize: '1 cup (172g)',
        servingSizeG: 172,
        searchTags: ['beans', 'legume', 'protein', 'fiber', 'vegetarian'],
      ),
      FoodDatabaseEntry(
        id: 'chickpeas',
        name: 'Chickpeas (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 269, proteinG: 14.5, carbsG: 45, fatsG: 4, fiberG: 12.5, sugarG: 7.9, sodiumMg: 11),
        servingSize: '1 cup (164g)',
        servingSizeG: 164,
        searchTags: ['chickpeas', 'garbanzo', 'legume', 'protein', 'vegetarian'],
      ),
      FoodDatabaseEntry(
        id: 'lentils',
        name: 'Lentils (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 230, proteinG: 18, carbsG: 40, fatsG: 0.8, fiberG: 15.6, sugarG: 3.6, sodiumMg: 4),
        servingSize: '1 cup (198g)',
        servingSizeG: 198,
        searchTags: ['lentils', 'legume', 'protein', 'fiber', 'vegetarian'],
      ),
      FoodDatabaseEntry(
        id: 'sausage',
        name: 'Pork Sausage (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 300, proteinG: 16, carbsG: 2, fatsG: 25, fiberG: 0, sugarG: 0, sodiumMg: 700),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['sausage', 'pork', 'breakfast', 'meat'],
      ),
    ]);

    // Grains & Carbs
    foods.addAll([
      FoodDatabaseEntry(
        id: 'white_rice',
        name: 'White Rice (cooked)',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 205, proteinG: 4.2, carbsG: 45, fatsG: 0.4, fiberG: 0.6, sugarG: 0.1, sodiumMg: 2),
        servingSize: '1 cup (158g)',
        servingSizeG: 158,
        searchTags: ['rice', 'grain', 'carb'],
      ),
      FoodDatabaseEntry(
        id: 'brown_rice',
        name: 'Brown Rice (cooked)',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 216, proteinG: 5, carbsG: 45, fatsG: 1.8, fiberG: 3.5, sugarG: 0.7, sodiumMg: 10),
        servingSize: '1 cup (195g)',
        servingSizeG: 195,
        searchTags: ['rice', 'grain', 'carb', 'healthy', 'whole grain'],
      ),
      FoodDatabaseEntry(
        id: 'pasta',
        name: 'Pasta (cooked)',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 220, proteinG: 8, carbsG: 43, fatsG: 1.3, fiberG: 2.5, sugarG: 0.8, sodiumMg: 1),
        servingSize: '1 cup (140g)',
        servingSizeG: 140,
        searchTags: ['pasta', 'noodle', 'grain', 'carb', 'italian'],
      ),
      FoodDatabaseEntry(
        id: 'bread_wheat',
        name: 'Whole Wheat Bread',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 80, proteinG: 4, carbsG: 14, fatsG: 1, fiberG: 2, sugarG: 2, sodiumMg: 150),
        servingSize: '1 slice (28g)',
        servingSizeG: 28,
        searchTags: ['bread', 'wheat', 'grain', 'sandwich'],
      ),
      FoodDatabaseEntry(
        id: 'oatmeal',
        name: 'Oatmeal (cooked)',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 150, proteinG: 5, carbsG: 27, fatsG: 3, fiberG: 4, sugarG: 1, sodiumMg: 0),
        servingSize: '1 cup (234g)',
        servingSizeG: 234,
        searchTags: ['oatmeal', 'oats', 'breakfast', 'grain', 'healthy'],
      ),
    ]);

    // Dairy
    foods.addAll([
      FoodDatabaseEntry(
        id: 'milk_2percent',
        name: 'Milk (2% fat)',
        brand: 'Generic',
        category: 'Dairy',
        macros: const NutritionMacros(calories: 122, proteinG: 8, carbsG: 12, fatsG: 5, fiberG: 0, sugarG: 12, sodiumMg: 115),
        servingSize: '1 cup (244g)',
        servingSizeG: 244,
        searchTags: ['milk', 'dairy', 'drink'],
      ),
      FoodDatabaseEntry(
        id: 'greek_yogurt',
        name: 'Greek Yogurt (plain, non-fat)',
        brand: 'Generic',
        category: 'Dairy',
        macros: const NutritionMacros(calories: 100, proteinG: 17, carbsG: 7, fatsG: 0, fiberG: 0, sugarG: 7, sodiumMg: 65),
        servingSize: '5.3 oz (150g)',
        servingSizeG: 150,
        searchTags: ['yogurt', 'dairy', 'protein', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'cheddar_cheese',
        name: 'Cheddar Cheese',
        brand: 'Generic',
        category: 'Dairy',
        macros: const NutritionMacros(calories: 115, proteinG: 7, carbsG: 0.4, fatsG: 9, fiberG: 0, sugarG: 0, sodiumMg: 180),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['cheese', 'dairy'],
      ),
    ]);

    // Snacks
    foods.addAll([
      FoodDatabaseEntry(
        id: 'almonds',
        name: 'Almonds',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 160, proteinG: 6, carbsG: 6, fatsG: 14, fiberG: 3.5, sugarG: 1, sodiumMg: 0),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['nuts', 'snack', 'healthy', 'protein'],
      ),
      FoodDatabaseEntry(
        id: 'peanut_butter',
        name: 'Peanut Butter',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 190, proteinG: 8, carbsG: 7, fatsG: 16, fiberG: 2, sugarG: 3, sodiumMg: 140),
        servingSize: '2 tbsp (32g)',
        servingSizeG: 32,
        searchTags: ['peanut', 'butter', 'protein', 'spread'],
      ),
      FoodDatabaseEntry(
        id: 'potato_chips',
        name: 'Potato Chips',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 150, proteinG: 2, carbsG: 15, fatsG: 10, fiberG: 1, sugarG: 0, sodiumMg: 180),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['chips', 'snack', 'potato', 'salty'],
      ),
      FoodDatabaseEntry(
        id: 'walnuts',
        name: 'Walnuts',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 185, proteinG: 4.3, carbsG: 4, fatsG: 18, fiberG: 2, sugarG: 0.7, sodiumMg: 1),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['nuts', 'snack', 'healthy', 'omega3'],
      ),
      FoodDatabaseEntry(
        id: 'cashews',
        name: 'Cashews',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 157, proteinG: 5, carbsG: 9, fatsG: 12, fiberG: 1, sugarG: 2, sodiumMg: 3),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['nuts', 'snack', 'cashew'],
      ),
      FoodDatabaseEntry(
        id: 'pistachios',
        name: 'Pistachios',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 159, proteinG: 6, carbsG: 8, fatsG: 13, fiberG: 3, sugarG: 2, sodiumMg: 0),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['nuts', 'snack', 'pistachio'],
      ),
      FoodDatabaseEntry(
        id: 'popcorn',
        name: 'Popcorn (air-popped)',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 31, proteinG: 1, carbsG: 6, fatsG: 0.4, fiberG: 1.2, sugarG: 0.1, sodiumMg: 1),
        servingSize: '1 cup (8g)',
        servingSizeG: 8,
        searchTags: ['popcorn', 'snack', 'low calorie'],
      ),
      FoodDatabaseEntry(
        id: 'pretzels',
        name: 'Pretzels',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 108, proteinG: 3, carbsG: 23, fatsG: 0.8, fiberG: 1, sugarG: 1, sodiumMg: 410),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['pretzels', 'snack', 'salty'],
      ),
      FoodDatabaseEntry(
        id: 'crackers',
        name: 'Wheat Crackers',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 120, proteinG: 3, carbsG: 20, fatsG: 3.5, fiberG: 2, sugarG: 3, sodiumMg: 200),
        servingSize: '5 crackers (28g)',
        servingSizeG: 28,
        searchTags: ['crackers', 'snack', 'wheat'],
      ),
      FoodDatabaseEntry(
        id: 'hummus',
        name: 'Hummus',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 50, proteinG: 2, carbsG: 6, fatsG: 2.5, fiberG: 1, sugarG: 0, sodiumMg: 105),
        servingSize: '2 tbsp (30g)',
        servingSizeG: 30,
        searchTags: ['hummus', 'chickpea', 'dip', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'trail_mix',
        name: 'Trail Mix',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 140, proteinG: 4, carbsG: 13, fatsG: 9, fiberG: 2, sugarG: 7, sodiumMg: 45),
        servingSize: '1/4 cup (38g)',
        servingSizeG: 38,
        searchTags: ['trail mix', 'nuts', 'dried fruit', 'snack'],
      ),
      FoodDatabaseEntry(
        id: 'protein_bar',
        name: 'Protein Bar',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 200, proteinG: 20, carbsG: 22, fatsG: 6, fiberG: 3, sugarG: 8, sodiumMg: 180),
        servingSize: '1 bar (50g)',
        servingSizeG: 50,
        searchTags: ['protein', 'bar', 'snack', 'fitness'],
      ),
      FoodDatabaseEntry(
        id: 'granola_bar',
        name: 'Granola Bar',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 100, proteinG: 2, carbsG: 15, fatsG: 4, fiberG: 1, sugarG: 7, sodiumMg: 75),
        servingSize: '1 bar (24g)',
        servingSizeG: 24,
        searchTags: ['granola', 'bar', 'snack', 'oats'],
      ),
      FoodDatabaseEntry(
        id: 'beef_jerky',
        name: 'Beef Jerky',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 116, proteinG: 9, carbsG: 3, fatsG: 7, fiberG: 0, sugarG: 3, sodiumMg: 590),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['jerky', 'beef', 'protein', 'snack'],
      ),
      FoodDatabaseEntry(
        id: 'rice_cakes',
        name: 'Rice Cakes',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 35, proteinG: 0.7, carbsG: 7, fatsG: 0.3, fiberG: 0.4, sugarG: 0, sodiumMg: 29),
        servingSize: '1 cake (9g)',
        servingSizeG: 9,
        searchTags: ['rice cakes', 'snack', 'low calorie'],
      ),
      FoodDatabaseEntry(
        id: 'cheese_sticks',
        name: 'String Cheese',
        brand: 'Generic',
        category: 'Snacks',
        macros: const NutritionMacros(calories: 80, proteinG: 6, carbsG: 1, fatsG: 6, fiberG: 0, sugarG: 0, sodiumMg: 200),
        servingSize: '1 stick (28g)',
        servingSizeG: 28,
        searchTags: ['cheese', 'string cheese', 'snack', 'protein'],
      ),
    ]);

    // Desserts
    foods.addAll([
      FoodDatabaseEntry(
        id: 'chocolate_chip_cookie',
        name: 'Chocolate Chip Cookie',
        brand: 'Generic',
        category: 'Desserts',
        macros: const NutritionMacros(calories: 140, proteinG: 2, carbsG: 18, fatsG: 7, fiberG: 1, sugarG: 10, sodiumMg: 105),
        servingSize: '1 cookie (30g)',
        servingSizeG: 30,
        searchTags: ['cookie', 'chocolate', 'dessert', 'sweet'],
      ),
      FoodDatabaseEntry(
        id: 'brownie',
        name: 'Brownie',
        brand: 'Generic',
        category: 'Desserts',
        macros: const NutritionMacros(calories: 227, proteinG: 3, carbsG: 36, fatsG: 9, fiberG: 1.5, sugarG: 24, sodiumMg: 175),
        servingSize: '1 square (56g)',
        servingSizeG: 56,
        searchTags: ['brownie', 'chocolate', 'dessert', 'sweet'],
      ),
      FoodDatabaseEntry(
        id: 'vanilla_ice_cream',
        name: 'Vanilla Ice Cream',
        brand: 'Generic',
        category: 'Desserts',
        macros: const NutritionMacros(calories: 137, proteinG: 2.3, carbsG: 16, fatsG: 7, fiberG: 0.5, sugarG: 14, sodiumMg: 53),
        servingSize: '1/2 cup (66g)',
        servingSizeG: 66,
        searchTags: ['ice cream', 'vanilla', 'dessert', 'frozen'],
      ),
      FoodDatabaseEntry(
        id: 'chocolate_cake',
        name: 'Chocolate Cake with Frosting',
        brand: 'Generic',
        category: 'Desserts',
        macros: const NutritionMacros(calories: 352, proteinG: 5, carbsG: 51, fatsG: 16, fiberG: 2, sugarG: 35, sodiumMg: 299),
        servingSize: '1 slice (95g)',
        servingSizeG: 95,
        searchTags: ['cake', 'chocolate', 'dessert', 'frosting'],
      ),
      FoodDatabaseEntry(
        id: 'apple_pie',
        name: 'Apple Pie',
        brand: 'Generic',
        category: 'Desserts',
        macros: const NutritionMacros(calories: 296, proteinG: 2.5, carbsG: 43, fatsG: 13, fiberG: 2, sugarG: 20, sodiumMg: 266),
        servingSize: '1 slice (117g)',
        servingSizeG: 117,
        searchTags: ['pie', 'apple', 'dessert', 'pastry'],
      ),
      FoodDatabaseEntry(
        id: 'cheesecake',
        name: 'Cheesecake',
        brand: 'Generic',
        category: 'Desserts',
        macros: const NutritionMacros(calories: 321, proteinG: 5.5, carbsG: 25, fatsG: 23, fiberG: 0.4, sugarG: 19, sodiumMg: 251),
        servingSize: '1 slice (80g)',
        servingSizeG: 80,
        searchTags: ['cheesecake', 'dessert', 'cheese', 'sweet'],
      ),
      FoodDatabaseEntry(
        id: 'chocolate_bar',
        name: 'Milk Chocolate Bar',
        brand: 'Generic',
        category: 'Desserts',
        macros: const NutritionMacros(calories: 235, proteinG: 3.4, carbsG: 26, fatsG: 13, fiberG: 1.5, sugarG: 24, sodiumMg: 35),
        servingSize: '1 bar (43g)',
        servingSizeG: 43,
        searchTags: ['chocolate', 'candy', 'dessert', 'sweet'],
      ),
      FoodDatabaseEntry(
        id: 'cupcake',
        name: 'Cupcake with Frosting',
        brand: 'Generic',
        category: 'Desserts',
        macros: const NutritionMacros(calories: 305, proteinG: 3.5, carbsG: 45, fatsG: 13, fiberG: 1, sugarG: 30, sodiumMg: 220),
        servingSize: '1 cupcake (76g)',
        servingSizeG: 76,
        searchTags: ['cupcake', 'cake', 'dessert', 'frosting'],
      ),
      FoodDatabaseEntry(
        id: 'pudding',
        name: 'Chocolate Pudding',
        brand: 'Generic',
        category: 'Desserts',
        macros: const NutritionMacros(calories: 158, proteinG: 4.3, carbsG: 25, fatsG: 4.5, fiberG: 1, sugarG: 20, sodiumMg: 146),
        servingSize: '1 cup (142g)',
        servingSizeG: 142,
        searchTags: ['pudding', 'chocolate', 'dessert', 'creamy'],
      ),
      FoodDatabaseEntry(
        id: 'oreo_cookies',
        name: 'Oreo Cookies',
        brand: 'Generic',
        category: 'Desserts',
        macros: const NutritionMacros(calories: 160, proteinG: 2, carbsG: 25, fatsG: 7, fiberG: 1, sugarG: 14, sodiumMg: 135),
        servingSize: '3 cookies (34g)',
        servingSizeG: 34,
        searchTags: ['oreo', 'cookies', 'chocolate', 'dessert'],
      ),
    ]);

    // Prepared Foods & Meals
    foods.addAll([
      FoodDatabaseEntry(
        id: 'pepperoni_pizza_frozen',
        name: 'Frozen Pepperoni Pizza',
        brand: 'Generic',
        category: 'Prepared Foods',
        macros: const NutritionMacros(calories: 320, proteinG: 13, carbsG: 39, fatsG: 12, fiberG: 2, sugarG: 5, sodiumMg: 730),
        servingSize: '1/4 pizza (149g)',
        servingSizeG: 149,
        searchTags: ['pizza', 'frozen', 'pepperoni', 'meal'],
      ),
      FoodDatabaseEntry(
        id: 'mac_and_cheese',
        name: 'Mac and Cheese',
        brand: 'Generic',
        category: 'Prepared Foods',
        macros: const NutritionMacros(calories: 310, proteinG: 11, carbsG: 44, fatsG: 10, fiberG: 2, sugarG: 7, sodiumMg: 720),
        servingSize: '1 cup (200g)',
        servingSizeG: 200,
        searchTags: ['macaroni', 'cheese', 'pasta', 'comfort food'],
      ),
      FoodDatabaseEntry(
        id: 'chicken_nuggets_frozen',
        name: 'Frozen Chicken Nuggets',
        brand: 'Generic',
        category: 'Prepared Foods',
        macros: const NutritionMacros(calories: 280, proteinG: 13, carbsG: 18, fatsG: 17, fiberG: 1, sugarG: 0, sodiumMg: 470),
        servingSize: '5 pieces (85g)',
        servingSizeG: 85,
        searchTags: ['chicken', 'nuggets', 'frozen', 'fried'],
      ),
      FoodDatabaseEntry(
        id: 'lasagna',
        name: 'Lasagna (meat)',
        brand: 'Generic',
        category: 'Prepared Foods',
        macros: const NutritionMacros(calories: 310, proteinG: 18, carbsG: 30, fatsG: 13, fiberG: 3, sugarG: 8, sodiumMg: 720),
        servingSize: '1 piece (215g)',
        servingSizeG: 215,
        searchTags: ['lasagna', 'pasta', 'italian', 'meat'],
      ),
      FoodDatabaseEntry(
        id: 'chicken_pot_pie',
        name: 'Chicken Pot Pie',
        brand: 'Generic',
        category: 'Prepared Foods',
        macros: const NutritionMacros(calories: 450, proteinG: 12, carbsG: 42, fatsG: 26, fiberG: 2, sugarG: 4, sodiumMg: 860),
        servingSize: '1 pie (198g)',
        servingSizeG: 198,
        searchTags: ['pot pie', 'chicken', 'pie', 'comfort food'],
      ),
      FoodDatabaseEntry(
        id: 'burrito_frozen',
        name: 'Frozen Bean & Cheese Burrito',
        brand: 'Generic',
        category: 'Prepared Foods',
        macros: const NutritionMacros(calories: 280, proteinG: 10, carbsG: 43, fatsG: 8, fiberG: 5, sugarG: 2, sodiumMg: 680),
        servingSize: '1 burrito (142g)',
        servingSizeG: 142,
        searchTags: ['burrito', 'frozen', 'beans', 'mexican'],
      ),
      FoodDatabaseEntry(
        id: 'fish_sticks',
        name: 'Fish Sticks',
        brand: 'Generic',
        category: 'Prepared Foods',
        macros: const NutritionMacros(calories: 210, proteinG: 10, carbsG: 20, fatsG: 9, fiberG: 1, sugarG: 1, sodiumMg: 380),
        servingSize: '6 sticks (102g)',
        servingSizeG: 102,
        searchTags: ['fish', 'sticks', 'frozen', 'breaded'],
      ),
      FoodDatabaseEntry(
        id: 'ramen_noodles',
        name: 'Instant Ramen Noodles',
        brand: 'Generic',
        category: 'Prepared Foods',
        macros: const NutritionMacros(calories: 380, proteinG: 8, carbsG: 52, fatsG: 14, fiberG: 2, sugarG: 2, sodiumMg: 1820),
        servingSize: '1 package (85g)',
        servingSizeG: 85,
        searchTags: ['ramen', 'noodles', 'instant', 'asian'],
      ),
      FoodDatabaseEntry(
        id: 'hot_dog',
        name: 'Hot Dog with Bun',
        brand: 'Generic',
        category: 'Prepared Foods',
        macros: const NutritionMacros(calories: 290, proteinG: 10, carbsG: 24, fatsG: 17, fiberG: 1, sugarG: 4, sodiumMg: 810),
        servingSize: '1 hot dog',
        servingSizeG: 100,
        searchTags: ['hot dog', 'sausage', 'bun', 'american'],
      ),
      FoodDatabaseEntry(
        id: 'pizza_rolls',
        name: 'Pizza Rolls',
        brand: 'Generic',
        category: 'Prepared Foods',
        macros: const NutritionMacros(calories: 220, proteinG: 8, carbsG: 33, fatsG: 7, fiberG: 2, sugarG: 3, sodiumMg: 480),
        servingSize: '6 rolls (85g)',
        servingSizeG: 85,
        searchTags: ['pizza', 'rolls', 'frozen', 'snack'],
      ),
    ]);

    // Beverages
    foods.addAll([
      FoodDatabaseEntry(
        id: 'orange_juice',
        name: 'Orange Juice',
        brand: 'Generic',
        category: 'Beverages',
        macros: const NutritionMacros(calories: 110, proteinG: 2, carbsG: 26, fatsG: 0, fiberG: 0.5, sugarG: 21, sodiumMg: 0),
        servingSize: '8 fl oz (240ml)',
        servingSizeG: 240,
        searchTags: ['juice', 'orange', 'drink', 'vitamin c'],
      ),
      FoodDatabaseEntry(
        id: 'soda_cola',
        name: 'Cola Soda',
        brand: 'Generic',
        category: 'Beverages',
        macros: const NutritionMacros(calories: 140, proteinG: 0, carbsG: 39, fatsG: 0, fiberG: 0, sugarG: 39, sodiumMg: 45),
        servingSize: '12 fl oz (355ml)',
        servingSizeG: 355,
        searchTags: ['soda', 'cola', 'drink', 'sweet'],
      ),
      FoodDatabaseEntry(
        id: 'water',
        name: 'Water',
        brand: 'Generic',
        category: 'Beverages',
        macros: const NutritionMacros(calories: 0, proteinG: 0, carbsG: 0, fatsG: 0, fiberG: 0, sugarG: 0, sodiumMg: 0),
        servingSize: '8 fl oz (240ml)',
        servingSizeG: 240,
        searchTags: ['water', 'drink', 'hydration', 'healthy'],
      ),
    ]);

    // ========== EXPANDED WHOLESOME FOODS ==========

    // More Nuts & Seeds
    foods.addAll([
      FoodDatabaseEntry(
        id: 'sunflower_seeds',
        name: 'Sunflower Seeds',
        brand: 'Generic',
        category: 'Nuts & Seeds',
        macros: const NutritionMacros(calories: 165, proteinG: 5.5, carbsG: 7, fatsG: 14, fiberG: 3, sugarG: 1, sodiumMg: 1),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['seeds', 'healthy', 'snack', 'vitamin e'],
      ),
      FoodDatabaseEntry(
        id: 'chia_seeds',
        name: 'Chia Seeds',
        brand: 'Generic',
        category: 'Nuts & Seeds',
        macros: const NutritionMacros(calories: 138, proteinG: 4.7, carbsG: 12, fatsG: 8.7, fiberG: 10, sugarG: 0, sodiumMg: 5),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['seeds', 'superfood', 'omega3', 'fiber', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'flax_seeds',
        name: 'Ground Flaxseed',
        brand: 'Generic',
        category: 'Nuts & Seeds',
        macros: const NutritionMacros(calories: 150, proteinG: 5, carbsG: 8, fatsG: 12, fiberG: 8, sugarG: 0, sodiumMg: 9),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['flax', 'seeds', 'omega3', 'fiber', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'pumpkin_seeds',
        name: 'Pumpkin Seeds',
        brand: 'Generic',
        category: 'Nuts & Seeds',
        macros: const NutritionMacros(calories: 151, proteinG: 7, carbsG: 5, fatsG: 13, fiberG: 1.7, sugarG: 0.4, sodiumMg: 5),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['seeds', 'snack', 'healthy', 'zinc'],
      ),
      FoodDatabaseEntry(
        id: 'sesame_seeds',
        name: 'Sesame Seeds',
        brand: 'Generic',
        category: 'Nuts & Seeds',
        macros: const NutritionMacros(calories: 160, proteinG: 5, carbsG: 7, fatsG: 14, fiberG: 4, sugarG: 0, sodiumMg: 3),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['sesame', 'seeds', 'calcium', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'hemp_seeds',
        name: 'Hemp Seeds',
        brand: 'Generic',
        category: 'Nuts & Seeds',
        macros: const NutritionMacros(calories: 166, proteinG: 9.5, carbsG: 2.6, fatsG: 14.6, fiberG: 1.2, sugarG: 0.5, sodiumMg: 2),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['hemp', 'seeds', 'protein', 'omega3', 'superfood'],
      ),
      FoodDatabaseEntry(
        id: 'pecans',
        name: 'Pecans',
        brand: 'Generic',
        category: 'Nuts & Seeds',
        macros: const NutritionMacros(calories: 196, proteinG: 2.6, carbsG: 4, fatsG: 20, fiberG: 2.7, sugarG: 1.1, sodiumMg: 0),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['pecans', 'nuts', 'snack', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'macadamia_nuts',
        name: 'Macadamia Nuts',
        brand: 'Generic',
        category: 'Nuts & Seeds',
        macros: const NutritionMacros(calories: 204, proteinG: 2.2, carbsG: 4, fatsG: 21, fiberG: 2.4, sugarG: 1.3, sodiumMg: 1),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['macadamia', 'nuts', 'snack', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'brazil_nuts',
        name: 'Brazil Nuts',
        brand: 'Generic',
        category: 'Nuts & Seeds',
        macros: const NutritionMacros(calories: 187, proteinG: 4, carbsG: 3, fatsG: 19, fiberG: 2.1, sugarG: 0.7, sodiumMg: 1),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['brazil nuts', 'nuts', 'selenium', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'hazelnuts',
        name: 'Hazelnuts',
        brand: 'Generic',
        category: 'Nuts & Seeds',
        macros: const NutritionMacros(calories: 178, proteinG: 4.2, carbsG: 4.7, fatsG: 17, fiberG: 2.7, sugarG: 1.2, sodiumMg: 0),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['hazelnuts', 'nuts', 'snack', 'vitamin e'],
      ),
      FoodDatabaseEntry(
        id: 'almond_butter',
        name: 'Almond Butter',
        brand: 'Generic',
        category: 'Nuts & Seeds',
        macros: const NutritionMacros(calories: 196, proteinG: 6.7, carbsG: 6, fatsG: 18, fiberG: 3.3, sugarG: 2, sodiumMg: 2),
        servingSize: '2 tbsp (32g)',
        servingSizeG: 32,
        searchTags: ['almond', 'butter', 'spread', 'protein', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'cashew_butter',
        name: 'Cashew Butter',
        brand: 'Generic',
        category: 'Nuts & Seeds',
        macros: const NutritionMacros(calories: 188, proteinG: 5.6, carbsG: 9, fatsG: 16, fiberG: 1, sugarG: 2, sodiumMg: 5),
        servingSize: '2 tbsp (32g)',
        servingSizeG: 32,
        searchTags: ['cashew', 'butter', 'spread', 'protein'],
      ),
      FoodDatabaseEntry(
        id: 'tahini',
        name: 'Tahini (Sesame Butter)',
        brand: 'Generic',
        category: 'Nuts & Seeds',
        macros: const NutritionMacros(calories: 178, proteinG: 5, carbsG: 6, fatsG: 16, fiberG: 2.8, sugarG: 0, sodiumMg: 34),
        servingSize: '2 tbsp (30g)',
        servingSizeG: 30,
        searchTags: ['tahini', 'sesame', 'butter', 'spread', 'calcium'],
      ),
    ]);

    // More Grains & Complex Carbs
    foods.addAll([
      FoodDatabaseEntry(
        id: 'quinoa',
        name: 'Quinoa (cooked)',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 222, proteinG: 8, carbsG: 39, fatsG: 3.6, fiberG: 5, sugarG: 1.6, sodiumMg: 13),
        servingSize: '1 cup (185g)',
        servingSizeG: 185,
        searchTags: ['quinoa', 'grain', 'superfood', 'protein', 'gluten free'],
      ),
      FoodDatabaseEntry(
        id: 'farro',
        name: 'Farro (cooked)',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 200, proteinG: 7, carbsG: 42, fatsG: 1.3, fiberG: 5, sugarG: 1, sodiumMg: 5),
        servingSize: '1 cup (170g)',
        servingSizeG: 170,
        searchTags: ['farro', 'grain', 'ancient grain', 'fiber', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'barley',
        name: 'Barley (cooked)',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 193, proteinG: 3.6, carbsG: 44, fatsG: 0.7, fiberG: 6, sugarG: 0.8, sodiumMg: 5),
        servingSize: '1 cup (157g)',
        servingSizeG: 157,
        searchTags: ['barley', 'grain', 'fiber', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'bulgur',
        name: 'Bulgur (cooked)',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 151, proteinG: 5.6, carbsG: 34, fatsG: 0.4, fiberG: 8, sugarG: 0.2, sodiumMg: 9),
        servingSize: '1 cup (182g)',
        servingSizeG: 182,
        searchTags: ['bulgur', 'grain', 'wheat', 'fiber', 'middle eastern'],
      ),
      FoodDatabaseEntry(
        id: 'millet',
        name: 'Millet (cooked)',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 207, proteinG: 6, carbsG: 41, fatsG: 1.7, fiberG: 2.3, sugarG: 0.2, sodiumMg: 3),
        servingSize: '1 cup (174g)',
        servingSizeG: 174,
        searchTags: ['millet', 'grain', 'gluten free', 'ancient grain'],
      ),
      FoodDatabaseEntry(
        id: 'couscous',
        name: 'Couscous (cooked)',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 176, proteinG: 6, carbsG: 36, fatsG: 0.3, fiberG: 2.2, sugarG: 0.2, sodiumMg: 8),
        servingSize: '1 cup (157g)',
        servingSizeG: 157,
        searchTags: ['couscous', 'grain', 'pasta', 'mediterranean'],
      ),
      FoodDatabaseEntry(
        id: 'wild_rice',
        name: 'Wild Rice (cooked)',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 166, proteinG: 6.5, carbsG: 35, fatsG: 0.6, fiberG: 3, sugarG: 1.2, sodiumMg: 5),
        servingSize: '1 cup (164g)',
        servingSizeG: 164,
        searchTags: ['wild rice', 'rice', 'grain', 'protein', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'whole_wheat_pasta',
        name: 'Whole Wheat Pasta (cooked)',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 174, proteinG: 7.5, carbsG: 37, fatsG: 0.8, fiberG: 6.3, sugarG: 1, sodiumMg: 4),
        servingSize: '1 cup (140g)',
        servingSizeG: 140,
        searchTags: ['pasta', 'whole wheat', 'grain', 'fiber', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'rye_bread',
        name: 'Rye Bread',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 83, proteinG: 2.7, carbsG: 15.5, fatsG: 1.1, fiberG: 1.9, sugarG: 1.2, sodiumMg: 211),
        servingSize: '1 slice (32g)',
        servingSizeG: 32,
        searchTags: ['bread', 'rye', 'grain', 'fiber'],
      ),
      FoodDatabaseEntry(
        id: 'sourdough_bread',
        name: 'Sourdough Bread',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 93, proteinG: 4, carbsG: 18, fatsG: 0.6, fiberG: 1, sugarG: 1.5, sodiumMg: 177),
        servingSize: '1 slice (36g)',
        servingSizeG: 36,
        searchTags: ['bread', 'sourdough', 'grain', 'fermented'],
      ),
      FoodDatabaseEntry(
        id: 'english_muffin',
        name: 'Whole Wheat English Muffin',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 134, proteinG: 5.8, carbsG: 26, fatsG: 1.5, fiberG: 4.4, sugarG: 2.5, sodiumMg: 220),
        servingSize: '1 muffin (57g)',
        servingSizeG: 57,
        searchTags: ['english muffin', 'bread', 'breakfast', 'whole wheat'],
      ),
      FoodDatabaseEntry(
        id: 'bagel',
        name: 'Whole Wheat Bagel',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 247, proteinG: 10, carbsG: 48, fatsG: 1.5, fiberG: 7.4, sugarG: 5.5, sodiumMg: 430),
        servingSize: '1 bagel (89g)',
        servingSizeG: 89,
        searchTags: ['bagel', 'bread', 'breakfast', 'whole wheat'],
      ),
      FoodDatabaseEntry(
        id: 'tortilla_wheat',
        name: 'Whole Wheat Tortilla',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 130, proteinG: 4, carbsG: 22, fatsG: 3.5, fiberG: 3, sugarG: 1, sodiumMg: 250),
        servingSize: '1 tortilla (49g)',
        servingSizeG: 49,
        searchTags: ['tortilla', 'wrap', 'whole wheat', 'mexican'],
      ),
      FoodDatabaseEntry(
        id: 'pita_bread',
        name: 'Whole Wheat Pita Bread',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 170, proteinG: 6, carbsG: 35, fatsG: 1.7, fiberG: 4.7, sugarG: 1, sodiumMg: 340),
        servingSize: '1 pita (64g)',
        servingSizeG: 64,
        searchTags: ['pita', 'bread', 'whole wheat', 'mediterranean'],
      ),
      FoodDatabaseEntry(
        id: 'granola',
        name: 'Granola',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 200, proteinG: 4, carbsG: 32, fatsG: 7, fiberG: 3, sugarG: 10, sodiumMg: 55),
        servingSize: '1/2 cup (48g)',
        servingSizeG: 48,
        searchTags: ['granola', 'oats', 'breakfast', 'cereal'],
      ),
      FoodDatabaseEntry(
        id: 'cream_of_wheat',
        name: 'Cream of Wheat (cooked)',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 133, proteinG: 3.8, carbsG: 28, fatsG: 0.5, fiberG: 1, sugarG: 0, sodiumMg: 9),
        servingSize: '1 cup (241g)',
        servingSizeG: 241,
        searchTags: ['cream of wheat', 'hot cereal', 'breakfast'],
      ),
      FoodDatabaseEntry(
        id: 'grits',
        name: 'Grits (cooked)',
        brand: 'Generic',
        category: 'Grains',
        macros: const NutritionMacros(calories: 151, proteinG: 3.6, carbsG: 32, fatsG: 0.5, fiberG: 0.8, sugarG: 0.2, sodiumMg: 7),
        servingSize: '1 cup (242g)',
        servingSizeG: 242,
        searchTags: ['grits', 'corn', 'breakfast', 'southern'],
      ),
    ]);

    // More Dairy & Alternatives
    foods.addAll([
      FoodDatabaseEntry(
        id: 'cottage_cheese',
        name: 'Cottage Cheese (low-fat)',
        brand: 'Generic',
        category: 'Dairy',
        macros: const NutritionMacros(calories: 163, proteinG: 28, carbsG: 6, fatsG: 2.3, fiberG: 0, sugarG: 6, sodiumMg: 918),
        servingSize: '1 cup (226g)',
        servingSizeG: 226,
        searchTags: ['cottage cheese', 'dairy', 'protein', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'ricotta_cheese',
        name: 'Ricotta Cheese (part skim)',
        brand: 'Generic',
        category: 'Dairy',
        macros: const NutritionMacros(calories: 171, proteinG: 14, carbsG: 6, fatsG: 10, fiberG: 0, sugarG: 0.3, sodiumMg: 155),
        servingSize: '1/2 cup (124g)',
        servingSizeG: 124,
        searchTags: ['ricotta', 'cheese', 'dairy', 'italian'],
      ),
      FoodDatabaseEntry(
        id: 'feta_cheese',
        name: 'Feta Cheese',
        brand: 'Generic',
        category: 'Dairy',
        macros: const NutritionMacros(calories: 75, proteinG: 4, carbsG: 1.2, fatsG: 6, fiberG: 0, sugarG: 1.2, sodiumMg: 316),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['feta', 'cheese', 'dairy', 'greek', 'mediterranean'],
      ),
      FoodDatabaseEntry(
        id: 'mozzarella_cheese',
        name: 'Mozzarella Cheese (part skim)',
        brand: 'Generic',
        category: 'Dairy',
        macros: const NutritionMacros(calories: 72, proteinG: 7, carbsG: 0.8, fatsG: 4.5, fiberG: 0, sugarG: 0.3, sodiumMg: 175),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['mozzarella', 'cheese', 'dairy', 'italian'],
      ),
      FoodDatabaseEntry(
        id: 'swiss_cheese',
        name: 'Swiss Cheese',
        brand: 'Generic',
        category: 'Dairy',
        macros: const NutritionMacros(calories: 106, proteinG: 8, carbsG: 1.5, fatsG: 8, fiberG: 0, sugarG: 0.4, sodiumMg: 54),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['swiss', 'cheese', 'dairy'],
      ),
      FoodDatabaseEntry(
        id: 'parmesan_cheese',
        name: 'Parmesan Cheese (grated)',
        brand: 'Generic',
        category: 'Dairy',
        macros: const NutritionMacros(calories: 22, proteinG: 2, carbsG: 0.2, fatsG: 1.4, fiberG: 0, sugarG: 0, sodiumMg: 76),
        servingSize: '1 tbsp (5g)',
        servingSizeG: 5,
        searchTags: ['parmesan', 'cheese', 'dairy', 'italian'],
      ),
      FoodDatabaseEntry(
        id: 'cream_cheese',
        name: 'Cream Cheese',
        brand: 'Generic',
        category: 'Dairy',
        macros: const NutritionMacros(calories: 99, proteinG: 2, carbsG: 1.6, fatsG: 10, fiberG: 0, sugarG: 1, sodiumMg: 84),
        servingSize: '2 tbsp (29g)',
        servingSizeG: 29,
        searchTags: ['cream cheese', 'cheese', 'dairy', 'spread'],
      ),
      FoodDatabaseEntry(
        id: 'sour_cream',
        name: 'Sour Cream',
        brand: 'Generic',
        category: 'Dairy',
        macros: const NutritionMacros(calories: 46, proteinG: 0.6, carbsG: 1.1, fatsG: 4.6, fiberG: 0, sugarG: 0.5, sodiumMg: 11),
        servingSize: '2 tbsp (24g)',
        servingSizeG: 24,
        searchTags: ['sour cream', 'dairy', 'topping'],
      ),
      FoodDatabaseEntry(
        id: 'butter',
        name: 'Butter',
        brand: 'Generic',
        category: 'Dairy',
        macros: const NutritionMacros(calories: 102, proteinG: 0.1, carbsG: 0, fatsG: 11.5, fiberG: 0, sugarG: 0, sodiumMg: 91),
        servingSize: '1 tbsp (14g)',
        servingSizeG: 14,
        searchTags: ['butter', 'dairy', 'fat', 'cooking'],
      ),
      FoodDatabaseEntry(
        id: 'almond_milk',
        name: 'Almond Milk (unsweetened)',
        brand: 'Generic',
        category: 'Dairy Alternatives',
        macros: const NutritionMacros(calories: 30, proteinG: 1, carbsG: 1, fatsG: 2.5, fiberG: 0, sugarG: 0, sodiumMg: 170),
        servingSize: '1 cup (240ml)',
        servingSizeG: 240,
        searchTags: ['almond milk', 'milk alternative', 'vegan', 'dairy free'],
      ),
      FoodDatabaseEntry(
        id: 'oat_milk',
        name: 'Oat Milk',
        brand: 'Generic',
        category: 'Dairy Alternatives',
        macros: const NutritionMacros(calories: 120, proteinG: 3, carbsG: 16, fatsG: 5, fiberG: 2, sugarG: 7, sodiumMg: 100),
        servingSize: '1 cup (240ml)',
        servingSizeG: 240,
        searchTags: ['oat milk', 'milk alternative', 'vegan', 'dairy free'],
      ),
      FoodDatabaseEntry(
        id: 'soy_milk',
        name: 'Soy Milk (unsweetened)',
        brand: 'Generic',
        category: 'Dairy Alternatives',
        macros: const NutritionMacros(calories: 80, proteinG: 7, carbsG: 4, fatsG: 4, fiberG: 1, sugarG: 1, sodiumMg: 90),
        servingSize: '1 cup (240ml)',
        servingSizeG: 240,
        searchTags: ['soy milk', 'milk alternative', 'protein', 'vegan', 'dairy free'],
      ),
      FoodDatabaseEntry(
        id: 'coconut_milk',
        name: 'Coconut Milk (unsweetened)',
        brand: 'Generic',
        category: 'Dairy Alternatives',
        macros: const NutritionMacros(calories: 45, proteinG: 0, carbsG: 1, fatsG: 4.5, fiberG: 0, sugarG: 0, sodiumMg: 25),
        servingSize: '1 cup (240ml)',
        servingSizeG: 240,
        searchTags: ['coconut milk', 'milk alternative', 'vegan', 'dairy free'],
      ),
      FoodDatabaseEntry(
        id: 'kefir',
        name: 'Kefir (low-fat)',
        brand: 'Generic',
        category: 'Dairy',
        macros: const NutritionMacros(calories: 104, proteinG: 9, carbsG: 12, fatsG: 2.5, fiberG: 0, sugarG: 12, sodiumMg: 125),
        servingSize: '1 cup (243g)',
        servingSizeG: 243,
        searchTags: ['kefir', 'dairy', 'probiotic', 'fermented', 'yogurt'],
      ),
    ]);

    // More Proteins & Seafood
    foods.addAll([
      FoodDatabaseEntry(
        id: 'cod',
        name: 'Cod (baked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 89, proteinG: 19, carbsG: 0, fatsG: 0.7, fiberG: 0, sugarG: 0, sodiumMg: 66),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['cod', 'fish', 'protein', 'lean', 'seafood'],
      ),
      FoodDatabaseEntry(
        id: 'halibut',
        name: 'Halibut (grilled)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 119, proteinG: 23, carbsG: 0, fatsG: 2.5, fiberG: 0, sugarG: 0, sodiumMg: 58),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['halibut', 'fish', 'protein', 'lean', 'seafood'],
      ),
      FoodDatabaseEntry(
        id: 'trout',
        name: 'Rainbow Trout (baked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 143, proteinG: 20, carbsG: 0, fatsG: 6, fiberG: 0, sugarG: 0, sodiumMg: 48),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['trout', 'fish', 'protein', 'omega3', 'seafood'],
      ),
      FoodDatabaseEntry(
        id: 'mahi_mahi',
        name: 'Mahi Mahi (grilled)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 93, proteinG: 20, carbsG: 0, fatsG: 0.8, fiberG: 0, sugarG: 0, sodiumMg: 96),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['mahi mahi', 'fish', 'protein', 'lean', 'seafood'],
      ),
      FoodDatabaseEntry(
        id: 'scallops',
        name: 'Scallops (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 94, proteinG: 17, carbsG: 2.5, fatsG: 1.2, fiberG: 0, sugarG: 0, sodiumMg: 667),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['scallops', 'seafood', 'protein', 'lean'],
      ),
      FoodDatabaseEntry(
        id: 'crab',
        name: 'Crab (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 82, proteinG: 16, carbsG: 0, fatsG: 1.3, fiberG: 0, sugarG: 0, sodiumMg: 293),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['crab', 'seafood', 'protein', 'lean'],
      ),
      FoodDatabaseEntry(
        id: 'lobster',
        name: 'Lobster (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 76, proteinG: 16, carbsG: 1, fatsG: 0.5, fiberG: 0, sugarG: 0, sodiumMg: 413),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['lobster', 'seafood', 'protein', 'lean'],
      ),
      FoodDatabaseEntry(
        id: 'mussels',
        name: 'Mussels (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 146, proteinG: 20, carbsG: 6, fatsG: 3.8, fiberG: 0, sugarG: 0, sodiumMg: 314),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['mussels', 'seafood', 'protein', 'iron'],
      ),
      FoodDatabaseEntry(
        id: 'sardines',
        name: 'Sardines (canned in oil)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 191, proteinG: 23, carbsG: 0, fatsG: 11, fiberG: 0, sugarG: 0, sodiumMg: 465),
        servingSize: '3.75 oz can (92g)',
        servingSizeG: 92,
        searchTags: ['sardines', 'fish', 'canned', 'omega3', 'calcium'],
      ),
      FoodDatabaseEntry(
        id: 'anchovies',
        name: 'Anchovies',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 42, proteinG: 6, carbsG: 0, fatsG: 2, fiberG: 0, sugarG: 0, sodiumMg: 734),
        servingSize: '1 oz (28g)',
        servingSizeG: 28,
        searchTags: ['anchovies', 'fish', 'canned', 'salty'],
      ),
      FoodDatabaseEntry(
        id: 'tempeh',
        name: 'Tempeh',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 162, proteinG: 15, carbsG: 9, fatsG: 9, fiberG: 0, sugarG: 0, sodiumMg: 9),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['tempeh', 'soy', 'protein', 'vegan', 'vegetarian', 'fermented'],
      ),
      FoodDatabaseEntry(
        id: 'seitan',
        name: 'Seitan (wheat protein)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 104, proteinG: 21, carbsG: 4, fatsG: 0.5, fiberG: 0, sugarG: 0, sodiumMg: 10),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['seitan', 'wheat', 'protein', 'vegan', 'vegetarian'],
      ),
      FoodDatabaseEntry(
        id: 'edamame',
        name: 'Edamame (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 189, proteinG: 17, carbsG: 15, fatsG: 8, fiberG: 8, sugarG: 3, sodiumMg: 9),
        servingSize: '1 cup (155g)',
        servingSizeG: 155,
        searchTags: ['edamame', 'soybean', 'protein', 'healthy', 'vegetarian'],
      ),
      FoodDatabaseEntry(
        id: 'pinto_beans',
        name: 'Pinto Beans (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 245, proteinG: 15, carbsG: 45, fatsG: 1.1, fiberG: 15, sugarG: 0.6, sodiumMg: 2),
        servingSize: '1 cup (171g)',
        servingSizeG: 171,
        searchTags: ['pinto beans', 'beans', 'legume', 'fiber', 'vegetarian'],
      ),
      FoodDatabaseEntry(
        id: 'kidney_beans',
        name: 'Kidney Beans (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 225, proteinG: 15, carbsG: 40, fatsG: 0.9, fiberG: 11, sugarG: 0.6, sodiumMg: 2),
        servingSize: '1 cup (177g)',
        servingSizeG: 177,
        searchTags: ['kidney beans', 'beans', 'legume', 'fiber', 'vegetarian'],
      ),
      FoodDatabaseEntry(
        id: 'navy_beans',
        name: 'Navy Beans (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 255, proteinG: 15, carbsG: 47, fatsG: 1.1, fiberG: 19, sugarG: 0.7, sodiumMg: 2),
        servingSize: '1 cup (182g)',
        servingSizeG: 182,
        searchTags: ['navy beans', 'beans', 'legume', 'fiber', 'vegetarian'],
      ),
      FoodDatabaseEntry(
        id: 'split_peas',
        name: 'Split Peas (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 231, proteinG: 16, carbsG: 41, fatsG: 0.8, fiberG: 16, sugarG: 5.7, sodiumMg: 4),
        servingSize: '1 cup (196g)',
        servingSizeG: 196,
        searchTags: ['split peas', 'peas', 'legume', 'fiber', 'vegetarian'],
      ),
      FoodDatabaseEntry(
        id: 'white_beans',
        name: 'White Beans (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 249, proteinG: 17, carbsG: 45, fatsG: 0.6, fiberG: 11, sugarG: 0.3, sodiumMg: 11),
        servingSize: '1 cup (179g)',
        servingSizeG: 179,
        searchTags: ['white beans', 'beans', 'legume', 'fiber', 'vegetarian'],
      ),
      FoodDatabaseEntry(
        id: 'lamb_chop',
        name: 'Lamb Chop (grilled)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 200, proteinG: 21, carbsG: 0, fatsG: 12, fiberG: 0, sugarG: 0, sodiumMg: 65),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['lamb', 'meat', 'protein'],
      ),
      FoodDatabaseEntry(
        id: 'duck',
        name: 'Duck (roasted)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 171, proteinG: 20, carbsG: 0, fatsG: 9.5, fiberG: 0, sugarG: 0, sodiumMg: 55),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['duck', 'poultry', 'protein'],
      ),
      FoodDatabaseEntry(
        id: 'bison',
        name: 'Ground Bison (cooked)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 152, proteinG: 22, carbsG: 0, fatsG: 7, fiberG: 0, sugarG: 0, sodiumMg: 48),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['bison', 'buffalo', 'meat', 'protein', 'lean'],
      ),
      FoodDatabaseEntry(
        id: 'venison',
        name: 'Venison (roasted)',
        brand: 'Generic',
        category: 'Proteins',
        macros: const NutritionMacros(calories: 134, proteinG: 26, carbsG: 0, fatsG: 2.7, fiberG: 0, sugarG: 0, sodiumMg: 46),
        servingSize: '3 oz (85g)',
        servingSizeG: 85,
        searchTags: ['venison', 'deer', 'meat', 'protein', 'lean', 'wild game'],
      ),
    ]);

    // Healthy Fats & Oils
    foods.addAll([
      FoodDatabaseEntry(
        id: 'olive_oil',
        name: 'Olive Oil (extra virgin)',
        brand: 'Generic',
        category: 'Healthy Fats',
        macros: const NutritionMacros(calories: 119, proteinG: 0, carbsG: 0, fatsG: 13.5, fiberG: 0, sugarG: 0, sodiumMg: 0),
        servingSize: '1 tbsp (13.5g)',
        servingSizeG: 13.5,
        searchTags: ['olive oil', 'oil', 'healthy fat', 'mediterranean', 'cooking'],
      ),
      FoodDatabaseEntry(
        id: 'avocado_oil',
        name: 'Avocado Oil',
        brand: 'Generic',
        category: 'Healthy Fats',
        macros: const NutritionMacros(calories: 124, proteinG: 0, carbsG: 0, fatsG: 14, fiberG: 0, sugarG: 0, sodiumMg: 0),
        servingSize: '1 tbsp (14g)',
        servingSizeG: 14,
        searchTags: ['avocado oil', 'oil', 'healthy fat', 'cooking'],
      ),
      FoodDatabaseEntry(
        id: 'coconut_oil',
        name: 'Coconut Oil',
        brand: 'Generic',
        category: 'Healthy Fats',
        macros: const NutritionMacros(calories: 121, proteinG: 0, carbsG: 0, fatsG: 13.5, fiberG: 0, sugarG: 0, sodiumMg: 0),
        servingSize: '1 tbsp (13.5g)',
        servingSizeG: 13.5,
        searchTags: ['coconut oil', 'oil', 'cooking', 'mct'],
      ),
      FoodDatabaseEntry(
        id: 'avocado',
        name: 'Avocado',
        brand: 'Generic',
        category: 'Healthy Fats',
        macros: const NutritionMacros(calories: 234, proteinG: 2.9, carbsG: 12, fatsG: 21, fiberG: 9.2, sugarG: 0.9, sodiumMg: 11),
        servingSize: '1 avocado (136g)',
        servingSizeG: 136,
        searchTags: ['avocado', 'healthy fat', 'fiber', 'potassium'],
      ),
      FoodDatabaseEntry(
        id: 'olives',
        name: 'Olives (black)',
        brand: 'Generic',
        category: 'Healthy Fats',
        macros: const NutritionMacros(calories: 25, proteinG: 0.2, carbsG: 1.5, fatsG: 2.3, fiberG: 0.7, sugarG: 0, sodiumMg: 192),
        servingSize: '5 large (19g)',
        servingSizeG: 19,
        searchTags: ['olives', 'healthy fat', 'mediterranean', 'snack'],
      ),
    ]);

    // More Vegetables & Greens
    foods.addAll([
      FoodDatabaseEntry(
        id: 'arugula',
        name: 'Arugula',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 5, proteinG: 0.5, carbsG: 0.7, fatsG: 0.1, fiberG: 0.3, sugarG: 0.4, sodiumMg: 5),
        servingSize: '1 cup (20g)',
        servingSizeG: 20,
        searchTags: ['arugula', 'rocket', 'leafy', 'salad', 'green'],
      ),
      FoodDatabaseEntry(
        id: 'romaine',
        name: 'Romaine Lettuce',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 8, proteinG: 0.6, carbsG: 1.5, fatsG: 0.1, fiberG: 1, sugarG: 0.6, sodiumMg: 4),
        servingSize: '1 cup (47g)',
        servingSizeG: 47,
        searchTags: ['romaine', 'lettuce', 'leafy', 'salad', 'green'],
      ),
      FoodDatabaseEntry(
        id: 'swiss_chard',
        name: 'Swiss Chard (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 35, proteinG: 3.3, carbsG: 7, fatsG: 0.1, fiberG: 3.7, sugarG: 1.9, sodiumMg: 313),
        servingSize: '1 cup (175g)',
        servingSizeG: 175,
        searchTags: ['chard', 'swiss chard', 'leafy', 'green', 'vitamin k'],
      ),
      FoodDatabaseEntry(
        id: 'collard_greens',
        name: 'Collard Greens (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 49, proteinG: 4, carbsG: 9, fatsG: 0.7, fiberG: 5.3, sugarG: 0.9, sodiumMg: 30),
        servingSize: '1 cup (190g)',
        servingSizeG: 190,
        searchTags: ['collard greens', 'leafy', 'green', 'southern'],
      ),
      FoodDatabaseEntry(
        id: 'bok_choy',
        name: 'Bok Choy (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 20, proteinG: 2.7, carbsG: 3, fatsG: 0.3, fiberG: 1.7, sugarG: 1.5, sodiumMg: 58),
        servingSize: '1 cup (170g)',
        servingSizeG: 170,
        searchTags: ['bok choy', 'chinese cabbage', 'asian', 'green'],
      ),
      FoodDatabaseEntry(
        id: 'cabbage',
        name: 'Cabbage (raw)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 22, proteinG: 1.1, carbsG: 5, fatsG: 0.1, fiberG: 2.2, sugarG: 2.9, sodiumMg: 16),
        servingSize: '1 cup (89g)',
        servingSizeG: 89,
        searchTags: ['cabbage', 'vegetable', 'cruciferous', 'vitamin c'],
      ),
      FoodDatabaseEntry(
        id: 'radish',
        name: 'Radishes',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 19, proteinG: 0.8, carbsG: 4, fatsG: 0.1, fiberG: 1.9, sugarG: 2.2, sodiumMg: 45),
        servingSize: '1 cup (116g)',
        servingSizeG: 116,
        searchTags: ['radish', 'vegetable', 'crunchy', 'low calorie'],
      ),
      FoodDatabaseEntry(
        id: 'celery',
        name: 'Celery',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 14, proteinG: 0.7, carbsG: 3, fatsG: 0.2, fiberG: 1.6, sugarG: 1.4, sodiumMg: 80),
        servingSize: '1 cup (101g)',
        servingSizeG: 101,
        searchTags: ['celery', 'vegetable', 'low calorie', 'snack'],
      ),
      FoodDatabaseEntry(
        id: 'beets',
        name: 'Beets (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 58, proteinG: 2.2, carbsG: 13, fatsG: 0.2, fiberG: 3.4, sugarG: 9.2, sodiumMg: 106),
        servingSize: '1 cup (136g)',
        servingSizeG: 136,
        searchTags: ['beets', 'beetroot', 'vegetable', 'nitrates'],
      ),
      FoodDatabaseEntry(
        id: 'turnips',
        name: 'Turnips (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 34, proteinG: 1.1, carbsG: 8, fatsG: 0.1, fiberG: 3.1, sugarG: 4.7, sodiumMg: 25),
        servingSize: '1 cup (156g)',
        servingSizeG: 156,
        searchTags: ['turnips', 'root vegetable', 'low calorie'],
      ),
      FoodDatabaseEntry(
        id: 'parsnips',
        name: 'Parsnips (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 111, proteinG: 1.6, carbsG: 27, fatsG: 0.4, fiberG: 5.6, sugarG: 6.4, sodiumMg: 15),
        servingSize: '1 cup (156g)',
        servingSizeG: 156,
        searchTags: ['parsnips', 'root vegetable', 'sweet', 'fiber'],
      ),
      FoodDatabaseEntry(
        id: 'butternut_squash',
        name: 'Butternut Squash (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 82, proteinG: 1.8, carbsG: 22, fatsG: 0.2, fiberG: 6.6, sugarG: 4, sodiumMg: 8),
        servingSize: '1 cup (205g)',
        servingSizeG: 205,
        searchTags: ['butternut squash', 'squash', 'winter squash', 'vitamin a'],
      ),
      FoodDatabaseEntry(
        id: 'acorn_squash',
        name: 'Acorn Squash (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 115, proteinG: 2.3, carbsG: 30, fatsG: 0.3, fiberG: 9, sugarG: 0, sodiumMg: 8),
        servingSize: '1 cup (205g)',
        servingSizeG: 205,
        searchTags: ['acorn squash', 'squash', 'winter squash', 'fiber'],
      ),
      FoodDatabaseEntry(
        id: 'spaghetti_squash',
        name: 'Spaghetti Squash (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 42, proteinG: 1, carbsG: 10, fatsG: 0.4, fiberG: 2.2, sugarG: 3.9, sodiumMg: 28),
        servingSize: '1 cup (155g)',
        servingSizeG: 155,
        searchTags: ['spaghetti squash', 'squash', 'low carb', 'pasta alternative'],
      ),
      FoodDatabaseEntry(
        id: 'artichoke',
        name: 'Artichoke (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 64, proteinG: 3.5, carbsG: 14, fatsG: 0.4, fiberG: 6.9, sugarG: 1.3, sodiumMg: 72),
        servingSize: '1 medium (128g)',
        servingSizeG: 128,
        searchTags: ['artichoke', 'vegetable', 'fiber', 'mediterranean'],
      ),
      FoodDatabaseEntry(
        id: 'okra',
        name: 'Okra (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 36, proteinG: 3, carbsG: 7.5, fatsG: 0.3, fiberG: 4, sugarG: 3.2, sodiumMg: 8),
        servingSize: '1 cup (160g)',
        servingSizeG: 160,
        searchTags: ['okra', 'vegetable', 'southern', 'fiber'],
      ),
      FoodDatabaseEntry(
        id: 'leeks',
        name: 'Leeks (cooked)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 38, proteinG: 1, carbsG: 9, fatsG: 0.2, fiberG: 1.2, sugarG: 2.5, sodiumMg: 13),
        servingSize: '1 cup (124g)',
        servingSizeG: 124,
        searchTags: ['leeks', 'vegetable', 'aromatic', 'onion family'],
      ),
      FoodDatabaseEntry(
        id: 'fennel',
        name: 'Fennel (raw)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 27, proteinG: 1.1, carbsG: 6, fatsG: 0.2, fiberG: 2.7, sugarG: 3.2, sodiumMg: 45),
        servingSize: '1 cup (87g)',
        servingSizeG: 87,
        searchTags: ['fennel', 'vegetable', 'licorice', 'aromatic'],
      ),
      FoodDatabaseEntry(
        id: 'jicama',
        name: 'Jicama (raw)',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 49, proteinG: 0.9, carbsG: 11, fatsG: 0.1, fiberG: 6.4, sugarG: 2.5, sodiumMg: 5),
        servingSize: '1 cup (130g)',
        servingSizeG: 130,
        searchTags: ['jicama', 'vegetable', 'crunchy', 'fiber', 'mexican'],
      ),
      FoodDatabaseEntry(
        id: 'watercress',
        name: 'Watercress',
        brand: 'Generic',
        category: 'Vegetables',
        macros: const NutritionMacros(calories: 4, proteinG: 0.8, carbsG: 0.4, fatsG: 0, fiberG: 0.5, sugarG: 0.2, sodiumMg: 14),
        servingSize: '1 cup (34g)',
        servingSizeG: 34,
        searchTags: ['watercress', 'leafy', 'green', 'peppery', 'superfood'],
      ),
    ]);

    // Beverages
    foods.addAll([
      FoodDatabaseEntry(
        id: 'green_tea',
        name: 'Green Tea (brewed, unsweetened)',
        brand: 'Generic',
        category: 'Beverages',
        macros: const NutritionMacros(calories: 2, proteinG: 0.5, carbsG: 0, fatsG: 0, fiberG: 0, sugarG: 0, sodiumMg: 2),
        servingSize: '1 cup (240ml)',
        servingSizeG: 240,
        searchTags: ['green tea', 'tea', 'drink', 'antioxidant', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'black_tea',
        name: 'Black Tea (brewed, unsweetened)',
        brand: 'Generic',
        category: 'Beverages',
        macros: const NutritionMacros(calories: 2, proteinG: 0, carbsG: 0.7, fatsG: 0, fiberG: 0, sugarG: 0, sodiumMg: 5),
        servingSize: '1 cup (240ml)',
        servingSizeG: 240,
        searchTags: ['black tea', 'tea', 'drink', 'caffeine'],
      ),
      FoodDatabaseEntry(
        id: 'coffee_black',
        name: 'Black Coffee (brewed)',
        brand: 'Generic',
        category: 'Beverages',
        macros: const NutritionMacros(calories: 2, proteinG: 0.3, carbsG: 0, fatsG: 0, fiberG: 0, sugarG: 0, sodiumMg: 5),
        servingSize: '1 cup (240ml)',
        servingSizeG: 240,
        searchTags: ['coffee', 'drink', 'caffeine', 'black'],
      ),
      FoodDatabaseEntry(
        id: 'orange_juice',
        name: 'Orange Juice (100%)',
        brand: 'Generic',
        category: 'Beverages',
        macros: const NutritionMacros(calories: 112, proteinG: 1.7, carbsG: 26, fatsG: 0.5, fiberG: 0.5, sugarG: 21, sodiumMg: 2),
        servingSize: '1 cup (240ml)',
        servingSizeG: 240,
        searchTags: ['orange juice', 'juice', 'drink', 'vitamin c'],
      ),
      FoodDatabaseEntry(
        id: 'apple_juice',
        name: 'Apple Juice (100%)',
        brand: 'Generic',
        category: 'Beverages',
        macros: const NutritionMacros(calories: 114, proteinG: 0.2, carbsG: 28, fatsG: 0.3, fiberG: 0.2, sugarG: 24, sodiumMg: 10),
        servingSize: '1 cup (240ml)',
        servingSizeG: 240,
        searchTags: ['apple juice', 'juice', 'drink'],
      ),
      FoodDatabaseEntry(
        id: 'coconut_water',
        name: 'Coconut Water',
        brand: 'Generic',
        category: 'Beverages',
        macros: const NutritionMacros(calories: 46, proteinG: 1.7, carbsG: 9, fatsG: 0.5, fiberG: 2.6, sugarG: 6, sodiumMg: 252),
        servingSize: '1 cup (240ml)',
        servingSizeG: 240,
        searchTags: ['coconut water', 'drink', 'hydration', 'electrolytes'],
      ),
      FoodDatabaseEntry(
        id: 'kombucha',
        name: 'Kombucha (unflavored)',
        brand: 'Generic',
        category: 'Beverages',
        macros: const NutritionMacros(calories: 30, proteinG: 0, carbsG: 7, fatsG: 0, fiberG: 0, sugarG: 2, sodiumMg: 10),
        servingSize: '1 cup (240ml)',
        servingSizeG: 240,
        searchTags: ['kombucha', 'drink', 'fermented', 'probiotic', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'protein_shake',
        name: 'Protein Shake (whey, water)',
        brand: 'Generic',
        category: 'Beverages',
        macros: const NutritionMacros(calories: 120, proteinG: 24, carbsG: 3, fatsG: 1.5, fiberG: 0, sugarG: 1, sodiumMg: 50),
        servingSize: '1 scoop (30g)',
        servingSizeG: 30,
        searchTags: ['protein shake', 'protein', 'drink', 'fitness', 'whey'],
      ),
    ]);

    // Condiments & Flavor Enhancers
    foods.addAll([
      FoodDatabaseEntry(
        id: 'guacamole',
        name: 'Guacamole',
        brand: 'Generic',
        category: 'Condiments',
        macros: const NutritionMacros(calories: 50, proteinG: 0.6, carbsG: 3, fatsG: 4.5, fiberG: 2, sugarG: 0.5, sodiumMg: 105),
        servingSize: '2 tbsp (30g)',
        servingSizeG: 30,
        searchTags: ['guacamole', 'avocado', 'dip', 'healthy'],
      ),
      FoodDatabaseEntry(
        id: 'salsa',
        name: 'Salsa',
        brand: 'Generic',
        category: 'Condiments',
        macros: const NutritionMacros(calories: 9, proteinG: 0.4, carbsG: 2, fatsG: 0.1, fiberG: 0.6, sugarG: 1.3, sodiumMg: 194),
        servingSize: '2 tbsp (30g)',
        servingSizeG: 30,
        searchTags: ['salsa', 'dip', 'tomato', 'mexican', 'low calorie'],
      ),
      FoodDatabaseEntry(
        id: 'mustard',
        name: 'Yellow Mustard',
        brand: 'Generic',
        category: 'Condiments',
        macros: const NutritionMacros(calories: 3, proteinG: 0.2, carbsG: 0.3, fatsG: 0.2, fiberG: 0.2, sugarG: 0.1, sodiumMg: 57),
        servingSize: '1 tsp (5g)',
        servingSizeG: 5,
        searchTags: ['mustard', 'condiment', 'low calorie'],
      ),
      FoodDatabaseEntry(
        id: 'hot_sauce',
        name: 'Hot Sauce',
        brand: 'Generic',
        category: 'Condiments',
        macros: const NutritionMacros(calories: 1, proteinG: 0.1, carbsG: 0.1, fatsG: 0, fiberG: 0, sugarG: 0, sodiumMg: 124),
        servingSize: '1 tsp (5g)',
        servingSizeG: 5,
        searchTags: ['hot sauce', 'condiment', 'spicy', 'low calorie'],
      ),
      FoodDatabaseEntry(
        id: 'honey',
        name: 'Honey',
        brand: 'Generic',
        category: 'Condiments',
        macros: const NutritionMacros(calories: 64, proteinG: 0.1, carbsG: 17, fatsG: 0, fiberG: 0, sugarG: 17, sodiumMg: 1),
        servingSize: '1 tbsp (21g)',
        servingSizeG: 21,
        searchTags: ['honey', 'sweetener', 'natural'],
      ),
      FoodDatabaseEntry(
        id: 'maple_syrup',
        name: 'Pure Maple Syrup',
        brand: 'Generic',
        category: 'Condiments',
        macros: const NutritionMacros(calories: 52, proteinG: 0, carbsG: 13, fatsG: 0, fiberG: 0, sugarG: 12, sodiumMg: 2),
        servingSize: '1 tbsp (20g)',
        servingSizeG: 20,
        searchTags: ['maple syrup', 'syrup', 'sweetener', 'pancakes'],
      ),
      FoodDatabaseEntry(
        id: 'balsamic_vinegar',
        name: 'Balsamic Vinegar',
        brand: 'Generic',
        category: 'Condiments',
        macros: const NutritionMacros(calories: 14, proteinG: 0, carbsG: 3, fatsG: 0, fiberG: 0, sugarG: 2, sodiumMg: 4),
        servingSize: '1 tbsp (15ml)',
        servingSizeG: 15,
        searchTags: ['balsamic', 'vinegar', 'dressing', 'italian'],
      ),
      FoodDatabaseEntry(
        id: 'soy_sauce',
        name: 'Soy Sauce',
        brand: 'Generic',
        category: 'Condiments',
        macros: const NutritionMacros(calories: 8, proteinG: 1.3, carbsG: 0.8, fatsG: 0, fiberG: 0.1, sugarG: 0.1, sodiumMg: 879),
        servingSize: '1 tbsp (15ml)',
        servingSizeG: 15,
        searchTags: ['soy sauce', 'sauce', 'asian', 'salty'],
      ),
      FoodDatabaseEntry(
        id: 'pesto',
        name: 'Basil Pesto',
        brand: 'Generic',
        category: 'Condiments',
        macros: const NutritionMacros(calories: 80, proteinG: 2, carbsG: 1, fatsG: 8, fiberG: 0.5, sugarG: 0, sodiumMg: 200),
        servingSize: '2 tbsp (30g)',
        servingSizeG: 30,
        searchTags: ['pesto', 'sauce', 'basil', 'italian'],
      ),
      FoodDatabaseEntry(
        id: 'ranch_dressing',
        name: 'Ranch Dressing',
        brand: 'Generic',
        category: 'Condiments',
        macros: const NutritionMacros(calories: 73, proteinG: 0.4, carbsG: 1.4, fatsG: 7.7, fiberG: 0, sugarG: 1, sodiumMg: 135),
        servingSize: '2 tbsp (30ml)',
        servingSizeG: 30,
        searchTags: ['ranch', 'dressing', 'salad', 'creamy'],
      ),
      FoodDatabaseEntry(
        id: 'italian_dressing',
        name: 'Italian Dressing',
        brand: 'Generic',
        category: 'Condiments',
        macros: const NutritionMacros(calories: 43, proteinG: 0.1, carbsG: 1.5, fatsG: 4.2, fiberG: 0, sugarG: 1.2, sodiumMg: 243),
        servingSize: '2 tbsp (30ml)',
        servingSizeG: 30,
        searchTags: ['italian', 'dressing', 'salad', 'vinaigrette'],
      ),
      FoodDatabaseEntry(
        id: 'caesar_dressing',
        name: 'Caesar Dressing',
        brand: 'Generic',
        category: 'Condiments',
        macros: const NutritionMacros(calories: 78, proteinG: 0.5, carbsG: 0.5, fatsG: 8.5, fiberG: 0, sugarG: 0.4, sodiumMg: 158),
        servingSize: '2 tbsp (30ml)',
        servingSizeG: 30,
        searchTags: ['caesar', 'dressing', 'salad', 'creamy'],
      ),
    ]);

    return foods;
  }
}
