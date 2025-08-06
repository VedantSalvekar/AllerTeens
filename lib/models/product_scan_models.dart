import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for representing a scanned product result
class ProductScanResult {
  final String barcode;
  final String? productName;
  final String? imageUrl;
  final List<String> ingredients;
  final List<String> allergens;
  final List<String> traces;
  final bool isSuccessful;
  final String? errorMessage;
  final AllergenVerdict verdict;
  final List<String> matchedAllergens;
  final DateTime scannedAt;

  const ProductScanResult({
    required this.barcode,
    this.productName,
    this.imageUrl,
    this.ingredients = const [],
    this.allergens = const [],
    this.traces = const [],
    required this.isSuccessful,
    this.errorMessage,
    required this.verdict,
    this.matchedAllergens = const [],
    required this.scannedAt,
  });

  /// Create a failed scan result
  factory ProductScanResult.failure({
    required String barcode,
    required String errorMessage,
  }) {
    return ProductScanResult(
      barcode: barcode,
      isSuccessful: false,
      errorMessage: errorMessage,
      verdict: AllergenVerdict.unknown,
      scannedAt: DateTime.now(),
    );
  }

  /// Create from OpenFoodFacts API response
  factory ProductScanResult.fromOpenFoodFacts({
    required String barcode,
    required Map<String, dynamic> productData,
    required List<String> userAllergens,
  }) {
    final productName = productData['product_name'] as String?;
    final imageUrl = productData['image_url'] as String?;
    
    // Parse ingredients
    final ingredientsText = productData['ingredients_text'] as String? ?? '';
    final ingredients = ingredientsText.isNotEmpty 
        ? [ingredientsText] 
        : <String>[];

    // Parse allergens
    final allergensTags = (productData['allergens_tags'] as List?)?.cast<String>() ?? <String>[];
    final allergens = allergensTags
        .map((tag) => _cleanAllergenTag(tag))
        .where((allergen) => allergen.isNotEmpty)
        .toList();

    // Parse traces
    final tracesTags = (productData['traces_tags'] as List?)?.cast<String>() ?? <String>[];
    final traces = tracesTags
        .map((tag) => _cleanAllergenTag(tag))
        .where((trace) => trace.isNotEmpty)
        .toList();

    // Determine allergen matches and verdict
    final matchedAllergens = _findMatchedAllergens(
      userAllergens: userAllergens,
      productAllergens: allergens,
      productTraces: traces,
      ingredients: ingredients,
    );

    final verdict = matchedAllergens.isEmpty 
        ? AllergenVerdict.safe 
        : AllergenVerdict.risky;

    return ProductScanResult(
      barcode: barcode,
      productName: productName,
      imageUrl: imageUrl,
      ingredients: ingredients,
      allergens: allergens,
      traces: traces,
      isSuccessful: true,
      verdict: verdict,
      matchedAllergens: matchedAllergens,
      scannedAt: DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'barcode': barcode,
      'productName': productName,
      'imageUrl': imageUrl,
      'ingredients': ingredients,
      'allergens': allergens,
      'traces': traces,
      'isSuccessful': isSuccessful,
      'errorMessage': errorMessage,
      'verdict': verdict.name,
      'matchedAllergens': matchedAllergens,
      'scannedAt': Timestamp.fromDate(scannedAt),
    };
  }

  /// Create from Firestore document
  factory ProductScanResult.fromFirestore(Map<String, dynamic> data) {
    return ProductScanResult(
      barcode: data['barcode'] as String,
      productName: data['productName'] as String?,
      imageUrl: data['imageUrl'] as String?,
      ingredients: (data['ingredients'] as List?)?.cast<String>() ?? [],
      allergens: (data['allergens'] as List?)?.cast<String>() ?? [],
      traces: (data['traces'] as List?)?.cast<String>() ?? [],
      isSuccessful: data['isSuccessful'] as bool,
      errorMessage: data['errorMessage'] as String?,
      verdict: AllergenVerdict.fromString(data['verdict'] as String? ?? 'unknown'),
      matchedAllergens: (data['matchedAllergens'] as List?)?.cast<String>() ?? [],
      scannedAt: (data['scannedAt'] as Timestamp).toDate(),
    );
  }

  /// Clean allergen tags (remove language prefixes like 'en:')
  static String _cleanAllergenTag(String tag) {
    if (tag.contains(':')) {
      return tag.split(':').last.trim();
    }
    return tag.trim();
  }

  /// Find matched allergens between user profile and product
  static List<String> _findMatchedAllergens({
    required List<String> userAllergens,
    required List<String> productAllergens,
    required List<String> productTraces,
    required List<String> ingredients,
  }) {
    final matched = <String>[];
    
    for (final userAllergen in userAllergens) {
      final userAllergenLower = userAllergen.toLowerCase().trim();
      
      // Check direct allergen matches
      for (final productAllergen in productAllergens) {
        if (_isAllergenMatch(userAllergenLower, productAllergen.toLowerCase().trim())) {
          matched.add(userAllergen);
          break;
        }
      }
      
      // Check trace matches
      for (final trace in productTraces) {
        if (_isAllergenMatch(userAllergenLower, trace.toLowerCase().trim())) {
          matched.add(userAllergen);
          break;
        }
      }
      
      // Check ingredient text matches
      for (final ingredient in ingredients) {
        if (ingredient.toLowerCase().contains(userAllergenLower)) {
          matched.add(userAllergen);
          break;
        }
      }
    }
    
    return matched.toSet().toList(); // Remove duplicates
  }

  /// Check if two allergen strings match (with variations)
  static bool _isAllergenMatch(String userAllergen, String productAllergen) {
    if (userAllergen == productAllergen) return true;
    
    // Handle common variations
    final allergenMappings = {
      'milk': ['dairy', 'lactose', 'casein', 'whey'],
      'eggs': ['egg'],
      'peanuts': ['peanut', 'groundnut'],
      'tree nuts': ['nuts', 'almonds', 'walnuts', 'hazelnuts', 'cashews', 'pistachios', 'pecans'],
      'wheat': ['gluten'],
      'soya': ['soy', 'soybean'],
      'fish': ['seafood'],
      'crustaceans': ['shellfish', 'shrimp', 'crab', 'lobster'],
      'molluscs': ['mussels', 'oysters', 'clams', 'squid'],
    };
    
    // Check if user allergen has variations that match product allergen
    final variations = allergenMappings[userAllergen] ?? [];
    if (variations.contains(productAllergen)) return true;
    
    // Check reverse mapping
    for (final entry in allergenMappings.entries) {
      if (entry.value.contains(userAllergen) && entry.key == productAllergen) {
        return true;
      }
    }
    
    return false;
  }
}

/// Allergen risk verdict for a scanned product
enum AllergenVerdict {
  safe,
  risky,
  unknown;

  /// Create from string representation
  static AllergenVerdict fromString(String value) {
    switch (value.toLowerCase()) {
      case 'safe':
        return AllergenVerdict.safe;
      case 'risky':
        return AllergenVerdict.risky;
      default:
        return AllergenVerdict.unknown;
    }
  }

  /// Get display text for verdict
  String get displayText {
    switch (this) {
      case AllergenVerdict.safe:
        return 'Safe';
      case AllergenVerdict.risky:
        return 'Risk Detected';
      case AllergenVerdict.unknown:
        return 'Unknown';
    }
  }

  /// Get display icon for verdict
  String get displayIcon {
    switch (this) {
      case AllergenVerdict.safe:
        return '✅';
      case AllergenVerdict.risky:
        return '⚠️';
      case AllergenVerdict.unknown:
        return '❓';
    }
  }
}

/// Model for scan history entries stored in Firebase
class ScanHistoryEntry {
  final String id;
  final String userId;
  final ProductScanResult scanResult;
  final DateTime createdAt;

  const ScanHistoryEntry({
    required this.id,
    required this.userId,
    required this.scanResult,
    required this.createdAt,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'scanResult': scanResult.toFirestore(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Create from Firestore document
  factory ScanHistoryEntry.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ScanHistoryEntry(
      id: id,
      userId: data['userId'] as String,
      scanResult: ProductScanResult.fromFirestore(data['scanResult'] as Map<String, dynamic>),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}