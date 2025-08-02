import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/scenario_config.dart';
import '../models/scenario_models.dart';

/// Service for dynamically loading scenario configurations
class ScenarioLoader {
  static final ScenarioLoader _instance = ScenarioLoader._internal();
  factory ScenarioLoader() => _instance;
  ScenarioLoader._internal();

  static ScenarioLoader get instance => _instance;

  Map<String, dynamic>? _manifestCache;
  final Map<String, ScenarioConfig> _scenarioCache = {};
  final Map<String, Map<String, dynamic>> _menuCache = {};

  /// Load the scenario manifest
  Future<Map<String, dynamic>> getManifest() async {
    if (_manifestCache != null) return _manifestCache!;

    try {
      final manifestString = await rootBundle.loadString(
        'assets/data/scenario_manifest.json',
      );
      _manifestCache = jsonDecode(manifestString) as Map<String, dynamic>;
      return _manifestCache!;
    } catch (e) {
      throw Exception('Failed to load scenario manifest: $e');
    }
  }

  /// Get all available scenarios from manifest
  Future<List<ScenarioMetadata>> getAvailableScenarios() async {
    final manifest = await getManifest();
    final scenarios = manifest['scenarios'] as Map<String, dynamic>;

    return scenarios.entries.map((entry) {
      final scenarioData = entry.value as Map<String, dynamic>;
      return ScenarioMetadata(
        id: entry.key,
        name: scenarioData['name'] as String,
        description: scenarioData['description'] as String,
        type: ScenarioType.values.firstWhere(
          (e) => e.toString().split('.').last == scenarioData['type'],
        ),
        level: DifficultyLevel.values.firstWhere(
          (e) => e.toString().split('.').last == scenarioData['level'],
        ),
        enabled: scenarioData['enabled'] as bool? ?? true,
        requiredScore: scenarioData['requiredScore'] as int? ?? 0,
        menuFile: scenarioData['menuFile'] as String?,
      );
    }).toList();
  }

  /// Load a specific scenario configuration
  Future<ScenarioConfig> loadScenario(String scenarioId) async {
    // Check cache first
    if (_scenarioCache.containsKey(scenarioId)) {
      return _scenarioCache[scenarioId]!;
    }

    try {
      final manifest = await getManifest();
      final scenarios = manifest['scenarios'] as Map<String, dynamic>;

      if (!scenarios.containsKey(scenarioId)) {
        throw Exception('Scenario $scenarioId not found in manifest');
      }

      final scenarioInfo = scenarios[scenarioId] as Map<String, dynamic>;
      final scenarioFile = scenarioInfo['file'] as String;

      // Load scenario configuration
      final configString = await rootBundle.loadString(
        'assets/data/$scenarioFile',
      );
      final configJson = jsonDecode(configString) as Map<String, dynamic>;

      // Load menu data if specified
      Map<String, dynamic>? menuData;
      final menuFile = scenarioInfo['menuFile'] as String?;
      if (menuFile != null) {
        menuData = await loadMenuData(menuFile);
      }

      // Create scenario config
      final config = ScenarioConfig.fromJson({
        ...configJson,
        'menuData': menuData,
      });

      // Cache the config
      _scenarioCache[scenarioId] = config;
      return config;
    } catch (e) {
      throw Exception('Failed to load scenario $scenarioId: $e');
    }
  }

  /// Load menu data for a scenario
  Future<Map<String, dynamic>> loadMenuData(String menuFile) async {
    // Check cache first
    if (_menuCache.containsKey(menuFile)) {
      return _menuCache[menuFile]!;
    }

    try {
      final menuString = await rootBundle.loadString('assets/data/$menuFile');
      final menuData = jsonDecode(menuString) as Map<String, dynamic>;

      // Cache the menu data
      _menuCache[menuFile] = menuData;
      return menuData;
    } catch (e) {
      throw Exception('Failed to load menu file $menuFile: $e');
    }
  }

  /// Get scenarios by difficulty level
  Future<List<ScenarioMetadata>> getScenariosByDifficulty(
    DifficultyLevel level,
  ) async {
    final allScenarios = await getAvailableScenarios();
    return allScenarios.where((scenario) => scenario.level == level).toList();
  }

  /// Get scenarios by type
  Future<List<ScenarioMetadata>> getScenariosByType(ScenarioType type) async {
    final allScenarios = await getAvailableScenarios();
    return allScenarios.where((scenario) => scenario.type == type).toList();
  }

  /// Check if a scenario is unlocked for the user
  bool isScenarioUnlocked(ScenarioMetadata scenario, int userScore) {
    return scenario.enabled && userScore >= scenario.requiredScore;
  }

  /// Clear all caches (useful for testing or updates)
  void clearCache() {
    _manifestCache = null;
    _scenarioCache.clear();
    _menuCache.clear();
  }

  /// Validate scenario configuration
  bool validateScenarioConfig(ScenarioConfig config) {
    try {
      // Basic validation
      if (config.id.isEmpty || config.name.isEmpty) return false;
      if (config.npcRole.isEmpty || config.scenarioContext.isEmpty)
        return false;

      // Scoring rules validation
      if (config.scoringRules.passingScore < 0 ||
          config.scoringRules.passingScore > 100) {
        return false;
      }

      // Behavior rules validation
      if (config.behaviorRules.guidanceLevel < 0.0 ||
          config.behaviorRules.guidanceLevel > 1.0) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Metadata about a scenario from the manifest
class ScenarioMetadata {
  final String id;
  final String name;
  final String description;
  final ScenarioType type;
  final DifficultyLevel level;
  final bool enabled;
  final int requiredScore;
  final String? menuFile;

  const ScenarioMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.level,
    required this.enabled,
    required this.requiredScore,
    this.menuFile,
  });

  @override
  String toString() {
    return 'ScenarioMetadata(id: $id, name: $name, type: $type, level: $level)';
  }
}
