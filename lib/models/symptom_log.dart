import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a daily symptom log entry
class SymptomLog {
  final String id;
  final DateTime date;
  final List<String> symptoms;
  final String notes;
  final bool tookMedication;
  final String severity;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SymptomLog({
    required this.id,
    required this.date,
    required this.symptoms,
    required this.notes,
    required this.tookMedication,
    required this.severity,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create a new symptom log with current timestamp
  factory SymptomLog.create({
    required DateTime date,
    required List<String> symptoms,
    required String notes,
    required bool tookMedication,
    required String severity,
  }) {
    final now = DateTime.now();
    return SymptomLog(
      id: _generateId(date),
      date: date,
      symptoms: symptoms,
      notes: notes,
      tookMedication: tookMedication,
      severity: severity,
      createdAt: now,
    );
  }

  /// Generate a unique ID based on date
  static String _generateId(DateTime date) {
    return 'symptom_${date.year}_${date.month.toString().padLeft(2, '0')}_${date.day.toString().padLeft(2, '0')}';
  }

  /// Create from Firestore document
  factory SymptomLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SymptomLog(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      symptoms: List<String>.from(data['symptoms'] ?? []),
      notes: data['notes'] ?? '',
      tookMedication: data['tookMedication'] ?? false,
      severity: data['severity'] ?? 'mild',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'symptoms': symptoms,
      'notes': notes,
      'tookMedication': tookMedication,
      'severity': severity,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create a copy with updated values
  SymptomLog copyWith({
    String? id,
    DateTime? date,
    List<String>? symptoms,
    String? notes,
    bool? tookMedication,
    String? severity,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SymptomLog(
      id: id ?? this.id,
      date: date ?? this.date,
      symptoms: symptoms ?? this.symptoms,
      notes: notes ?? this.notes,
      tookMedication: tookMedication ?? this.tookMedication,
      severity: severity ?? this.severity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if log is for today
  bool get isToday {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  /// Get formatted date string
  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Get symptom count
  int get symptomCount => symptoms.length;

  /// Check if has symptoms
  bool get hasSymptoms => symptoms.isNotEmpty;

  /// Get severity level as index (for sorting/comparison)
  int get severityLevel {
    switch (severity.toLowerCase()) {
      case 'mild':
        return 1;
      case 'moderate':
        return 2;
      case 'severe':
        return 3;
      default:
        return 0;
    }
  }

  @override
  String toString() {
    return 'SymptomLog(id: $id, date: $formattedDate, symptoms: $symptoms, severity: $severity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SymptomLog &&
        other.id == id &&
        other.date == date &&
        other.symptoms.toString() == symptoms.toString() &&
        other.notes == notes &&
        other.tookMedication == tookMedication &&
        other.severity == severity;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        date.hashCode ^
        symptoms.hashCode ^
        notes.hashCode ^
        tookMedication.hashCode ^
        severity.hashCode;
  }
}

/// Common symptoms for food allergies
class CommonSymptoms {
  static const List<String> allSymptoms = [
    'Hives',
    'Itchy skin',
    'Swelling',
    'Runny nose',
    'Sneezing',
    'Watery eyes',
    'Cough',
    'Wheezing',
    'Shortness of breath',
    'Nausea',
    'Vomiting',
    'Diarrhea',
    'Stomach pain',
    'Headache',
    'Dizziness',
    'Fatigue',
    'Anxiety',
    'Difficulty swallowing',
    'Throat tightness',
    'Rapid heartbeat',
  ];

  static const List<String> mildSymptoms = [
    'Hives',
    'Itchy skin',
    'Runny nose',
    'Sneezing',
    'Watery eyes',
    'Mild stomach pain',
    'Headache',
    'Fatigue',
  ];

  static const List<String> moderateSymptoms = [
    'Swelling',
    'Cough',
    'Wheezing',
    'Nausea',
    'Vomiting',
    'Diarrhea',
    'Dizziness',
    'Anxiety',
  ];

  static const List<String> severeSymptoms = [
    'Shortness of breath',
    'Difficulty swallowing',
    'Throat tightness',
    'Rapid heartbeat',
    'Severe swelling',
    'Severe breathing difficulty',
  ];
}

/// Severity levels for symptoms
enum SeverityLevel { none, mild, moderate, severe }

extension SeverityLevelExtension on SeverityLevel {
  String get displayName {
    switch (this) {
      case SeverityLevel.none:
        return 'None';
      case SeverityLevel.mild:
        return 'Mild';
      case SeverityLevel.moderate:
        return 'Moderate';
      case SeverityLevel.severe:
        return 'Severe';
    }
  }

  String get value {
    switch (this) {
      case SeverityLevel.none:
        return 'none';
      case SeverityLevel.mild:
        return 'mild';
      case SeverityLevel.moderate:
        return 'moderate';
      case SeverityLevel.severe:
        return 'severe';
    }
  }

  static SeverityLevel fromString(String value) {
    switch (value.toLowerCase()) {
      case 'mild':
        return SeverityLevel.mild;
      case 'moderate':
        return SeverityLevel.moderate;
      case 'severe':
        return SeverityLevel.severe;
      default:
        return SeverityLevel.none;
    }
  }
}
