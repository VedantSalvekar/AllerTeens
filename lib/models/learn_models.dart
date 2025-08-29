/// Data models for Learn module content
class LearnSection {
  final String heading;
  final List<String> content;

  const LearnSection({required this.heading, required this.content});

  factory LearnSection.fromJson(Map<String, dynamic> json) {
    return LearnSection(
      heading: json['heading'] as String,
      content: List<String>.from(json['content'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {'heading': heading, 'content': content};
  }
}

/// Educational module containing allergen information
class EducationalModule {
  final String title;
  final List<LearnSection> sections;

  const EducationalModule({required this.title, required this.sections});

  factory EducationalModule.fromJson(Map<String, dynamic> json) {
    return EducationalModule(
      title: json['title'] as String,
      sections: (json['sections'] as List)
          .map((section) => LearnSection.fromJson(section))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'sections': sections.map((section) => section.toJson()).toList(),
    };
  }

  /// Get all allergen-specific sections (excluding general educational content)
  List<LearnSection> get allergenSections {
    return sections
        .where(
          (section) =>
              section.heading != 'Educational:' &&
              section.heading != 'Allergens:' &&
              section.heading != 'Tests:' &&
              section.heading.isNotEmpty,
        )
        .toList();
  }

  /// Get general educational sections
  List<LearnSection> get generalSections {
    return sections
        .where(
          (section) =>
              section.heading == 'Educational:' ||
              section.heading == 'Allergens:' ||
              section.heading == 'Tests:',
        )
        .toList();
  }
}

/// Behavioral module containing lifestyle and safety advice
class BehavioralModule {
  final String title;
  final List<LearnSection> sections;

  const BehavioralModule({required this.title, required this.sections});

  factory BehavioralModule.fromJson(Map<String, dynamic> json) {
    return BehavioralModule(
      title: json['title'] as String,
      sections: (json['sections'] as List)
          .map((section) => LearnSection.fromJson(section))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'sections': sections.map((section) => section.toJson()).toList(),
    };
  }

  /// Get sections with meaningful content (excluding empty sections)
  List<LearnSection> get meaningfulSections {
    return sections
        .where(
          (section) => section.content.isNotEmpty && section.heading.isNotEmpty,
        )
        .toList();
  }
}

/// Container for both educational and behavioral modules
class LearnContent {
  final EducationalModule educational;
  final BehavioralModule behavioral;

  const LearnContent({required this.educational, required this.behavioral});

  factory LearnContent.fromJsonData({
    required Map<String, dynamic> educationalJson,
    required Map<String, dynamic> behavioralJson,
  }) {
    return LearnContent(
      educational: EducationalModule.fromJson(educationalJson),
      behavioral: BehavioralModule.fromJson(behavioralJson),
    );
  }
}

/// Enum for learn module tab types
enum LearnTabType {
  educational('Allergen Education'),
  behavioral('Behaviour & Safety');

  const LearnTabType(this.displayName);
  final String displayName;
}

/// Helper class for allergen information with icons
class AllergenInfo {
  static const Map<String, String> allergenIcons = {
    'Peanut:': '🥜',
    'Milk:': '🥛',
    'Egg:': '🥚',
    'Wheat:': '🌾',
    'Soya:': '🌱',
    'Fish:': '🐟',
    'Crustaceans:': '🦐',
    'Molluscs:': '🦪',
    'Sesame:': '🌰',
    'Tree nuts:': '🌰',
    'Couscous, Semolina': '🌾',
    'Alcohol:': '🍷',
    'Skin Prick Tests:': '🩹',
    'Blood tests:': '🩸',
    'Food Challenges:': '🧪',
    'Co-factors:': '⚠️',
  };

  static String getIcon(String heading) {
    // Check for exact match first
    if (allergenIcons.containsKey(heading)) {
      return allergenIcons[heading]!;
    }

    // Check for partial matches for different allergen names
    for (String key in allergenIcons.keys) {
      if (heading.toLowerCase().contains(
        key.toLowerCase().replaceAll(':', ''),
      )) {
        return allergenIcons[key]!;
      }
    }

    // Default icon for unknown allergens
    return '📋';
  }

  /// Check if a section is allergen-specific
  static bool isAllergenSection(String heading) {
    // List of non-allergen headings
    const nonAllergenHeadings = [
      'Educational:',
      'Allergens:',
      'Tests:',
      'Skin Prick Tests:',
      'Blood tests:',
      'Food Challenges:',
      'Co-factors:',
      'Steps:',
    ];

    return !nonAllergenHeadings.contains(heading) && heading.isNotEmpty;
  }
}
