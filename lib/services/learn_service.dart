import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/learn_models.dart';

/// Service for loading and managing educational content
class LearnService {
  static LearnService? _instance;
  static LearnService get instance => _instance ??= LearnService._();

  LearnService._();

  // Cache for loaded content to avoid repeated asset loading
  LearnContent? _cachedContent;

  /// Load and parse all learn content from JSON assets
  Future<LearnContent> loadLearnContent() async {
    // Return cached content if available
    if (_cachedContent != null) {
      return _cachedContent!;
    }

    try {
      // Load both JSON files in parallel
      final futures = await Future.wait([
        _loadEducationalModule(),
        _loadBehavioralModule(),
      ]);

      final educational = futures[0] as EducationalModule;
      final behavioral = futures[1] as BehavioralModule;

      _cachedContent = LearnContent(
        educational: educational,
        behavioral: behavioral,
      );

      return _cachedContent!;
    } catch (e) {
      throw LearnServiceException('Failed to load learn content: $e');
    }
  }

  /// Load educational module from JSON asset
  Future<EducationalModule> _loadEducationalModule() async {
    try {
      final jsonString = await rootBundle.loadString('assets/learn/educational_module.json');
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      return EducationalModule.fromJson(jsonData);
    } catch (e) {
      throw LearnServiceException('Failed to load educational module: $e');
    }
  }

  /// Load behavioral module from JSON asset
  Future<BehavioralModule> _loadBehavioralModule() async {
    try {
      final jsonString = await rootBundle.loadString('assets/learn/behavioural_module.json');
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      return BehavioralModule.fromJson(jsonData);
    } catch (e) {
      throw LearnServiceException('Failed to load behavioral module: $e');
    }
  }

  /// Search allergen sections by name (case-insensitive)
  List<LearnSection> searchAllergens(
    String query,
    EducationalModule educational,
  ) {
    if (query.isEmpty) {
      return educational.allergenSections;
    }

    final lowerQuery = query.toLowerCase();
    return educational.allergenSections.where((section) {
      final heading = section.heading.toLowerCase();
      final content = section.content.join(' ').toLowerCase();
      return heading.contains(lowerQuery) || content.contains(lowerQuery);
    }).toList();
  }

  /// Search behavioral sections by content (case-insensitive)
  List<LearnSection> searchBehavioral(
    String query,
    BehavioralModule behavioral,
  ) {
    if (query.isEmpty) {
      return behavioral.meaningfulSections;
    }

    final lowerQuery = query.toLowerCase();
    return behavioral.meaningfulSections.where((section) {
      final heading = section.heading.toLowerCase();
      final content = section.content.join(' ').toLowerCase();
      return heading.contains(lowerQuery) || content.contains(lowerQuery);
    }).toList();
  }

  /// Get allergen-specific sections with icons
  List<AllergenSectionData> getAllergenSections(EducationalModule educational) {
    return educational.allergenSections.map((section) {
      return AllergenSectionData(
        section: section,
        icon: AllergenInfo.getIcon(section.heading),
        isAllergen: AllergenInfo.isAllergenSection(section.heading),
      );
    }).toList();
  }

  /// Clear cached content (useful for testing or refreshing)
  void clearCache() {
    _cachedContent = null;
  }

  /// Check if content is loaded and cached
  bool get isContentCached => _cachedContent != null;
}

/// Data wrapper for allergen section with additional metadata
class AllergenSectionData {
  final LearnSection section;
  final String icon;
  final bool isAllergen;

  const AllergenSectionData({
    required this.section,
    required this.icon,
    required this.isAllergen,
  });

  String get title => section.heading.replaceAll(':', '').trim();
  List<String> get content => section.content;
  bool get hasContent => content.isNotEmpty;
}

/// Custom exception for learn service errors
class LearnServiceException implements Exception {
  final String message;

  const LearnServiceException(this.message);

  @override
  String toString() => 'LearnServiceException: $message';
}
