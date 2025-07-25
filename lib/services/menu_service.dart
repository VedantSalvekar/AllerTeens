import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service for managing restaurant menu data and allergen safety
class MenuService {
  static MenuService? _instance;
  static MenuService get instance => _instance ??= MenuService._();
  MenuService._();

  RestaurantMenu? _menu;

  /// Load menu data from JSON file
  Future<RestaurantMenu> loadMenu() async {
    if (_menu != null) return _menu!;

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/restaurant_menu.json',
      );
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      _menu = RestaurantMenu.fromJson(jsonData);
      debugPrint(
        '✅ [MENU] Loaded menu with ${_menu!.getAllItems().length} items',
      );
      return _menu!;
    } catch (e) {
      debugPrint('❌ [MENU] Error loading menu: $e');
      rethrow;
    }
  }

  /// Get menu formatted for AI waiter
  String formatMenuForAI(List<String> userAllergies) {
    if (_menu == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('=== RESTAURANT MENU ===');

    for (final section in _menu!.menuSections) {
      buffer.writeln('\n--- ${section.section.toUpperCase()} ---');

      for (final item in section.items) {
        final isSafe = isItemSafeForUser(item, userAllergies);
        final safetyIndicator = isSafe
            ? '✅ SAFE'
            : '⚠️  CONTAINS USER ALLERGENS';

        buffer.writeln('• ${item.name} - £${item.price.toStringAsFixed(2)}');
        buffer.writeln('  ${item.description}');
        buffer.writeln('  Allergens: ${item.allergens.join(', ')}');
        if (item.hiddenAllergens.isNotEmpty) {
          buffer.writeln(
            '  Hidden allergens: ${item.hiddenAllergens.join(', ')}',
          );
        }
        buffer.writeln('  Safety: $safetyIndicator');
        buffer.writeln('');
      }
    }

    return buffer.toString();
  }

  /// Check if a menu item is safe for user with given allergies
  bool isItemSafeForUser(MenuItem item, List<String> userAllergies) {
    final allItemAllergens = [...item.allergens, ...item.hiddenAllergens];

    for (final userAllergy in userAllergies) {
      for (final itemAllergen in allItemAllergens) {
        if (_allergenMatches(userAllergy, itemAllergen)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Check if two allergen strings match (handles variations)
  bool _allergenMatches(String userAllergy, String itemAllergen) {
    final normalizedUser = _normalizeAllergen(userAllergy);
    final normalizedItem = _normalizeAllergen(itemAllergen);

    // Direct match
    if (normalizedUser == normalizedItem) return true;

    // Check if item allergen contains user allergen
    if (normalizedItem.contains(normalizedUser)) return true;

    // Special cases
    final synonyms = {
      'dairy': ['milk'],
      'nuts': ['tree nuts', 'tree nut'],
      'shellfish': ['crustaceans', 'molluscs'],
      'wheat': ['gluten'],
    };

    for (final entry in synonyms.entries) {
      if (normalizedUser == entry.key &&
          entry.value.any((syn) => normalizedItem.contains(syn))) {
        return true;
      }
      if (entry.value.contains(normalizedUser) &&
          normalizedItem.contains(entry.key)) {
        return true;
      }
    }

    return false;
  }

  /// Normalize allergen name for comparison
  String _normalizeAllergen(String allergen) {
    return allergen
        .toLowerCase()
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '') // Remove parentheses
        .replaceAll(RegExp(r'[^a-z\s]'), '') // Remove special chars
        .trim();
  }

  /// Get safe menu items for user
  List<MenuItem> getSafeItemsForUser(List<String> userAllergies) {
    if (_menu == null) return [];

    return _menu!
        .getAllItems()
        .where((item) => isItemSafeForUser(item, userAllergies))
        .toList();
  }

  /// Get unsafe menu items for user
  List<MenuItem> getUnsafeItemsForUser(List<String> userAllergies) {
    if (_menu == null) return [];

    return _menu!
        .getAllItems()
        .where((item) => !isItemSafeForUser(item, userAllergies))
        .toList();
  }

  /// Find menu item by name (fuzzy matching)
  MenuItem? findItemByName(String name) {
    if (_menu == null) return null;

    final lowerName = name.toLowerCase();

    // Try exact match first
    for (final item in _menu!.getAllItems()) {
      if (item.name.toLowerCase() == lowerName) {
        return item;
      }
    }

    // Try partial match
    for (final item in _menu!.getAllItems()) {
      if (item.name.toLowerCase().contains(lowerName) ||
          lowerName.contains(item.name.toLowerCase())) {
        return item;
      }
    }

    return null;
  }

  /// Format menu for display dialog (simple version with prices)
  String formatMenuForDisplay() {
    if (_menu == null) return '';

    final buffer = StringBuffer();

    for (final section in _menu!.menuSections) {
      buffer.writeln('${section.section.toUpperCase()}\n');

      for (final item in section.items) {
        buffer.writeln('${item.name} - £${item.price.toStringAsFixed(2)}');
        buffer.writeln('${item.description}\n');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }
}

/// Data models for menu structure
class RestaurantMenu {
  final String restaurantName;
  final List<MenuSection> menuSections;

  RestaurantMenu({required this.restaurantName, required this.menuSections});

  factory RestaurantMenu.fromJson(Map<String, dynamic> json) {
    return RestaurantMenu(
      restaurantName: json['restaurant_name'] ?? '',
      menuSections: (json['menu_sections'] as List<dynamic>)
          .map((section) => MenuSection.fromJson(section))
          .toList(),
    );
  }

  List<MenuItem> getAllItems() {
    return menuSections.expand((section) => section.items).toList();
  }
}

class MenuSection {
  final String section;
  final List<MenuItem> items;

  MenuSection({required this.section, required this.items});

  factory MenuSection.fromJson(Map<String, dynamic> json) {
    return MenuSection(
      section: json['section'] ?? '',
      items: (json['items'] as List<dynamic>)
          .map((item) => MenuItem.fromJson(item))
          .toList(),
    );
  }
}

class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> allergens;
  final List<String> hiddenAllergens;
  final dynamic modifiableToSafe; // can be bool or string
  final List<String> suggestedQuestions;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.allergens,
    required this.hiddenAllergens,
    required this.modifiableToSafe,
    required this.suggestedQuestions,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      allergens: List<String>.from(json['allergens'] ?? []),
      hiddenAllergens: List<String>.from(json['hidden_allergens'] ?? []),
      modifiableToSafe: json['modifiable_to_safe'] ?? false,
      suggestedQuestions: List<String>.from(json['suggested_questions'] ?? []),
    );
  }

  bool get canBeModifiedToSafe {
    if (modifiableToSafe is bool) return modifiableToSafe as bool;
    if (modifiableToSafe is String)
      return modifiableToSafe == 'true' || modifiableToSafe == 'sometimes';
    return false;
  }
}
