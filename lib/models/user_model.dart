import 'package:cloud_firestore/cloud_firestore.dart';

/// User data model for AllerWise medical research app
class UserModel {
  final String id;
  final String name;
  final String email;
  final List<String> allergies;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? photoUrl;
  final bool isEmailVerified;
  final Map<String, dynamic>? medicalInfo;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.allergies,
    required this.createdAt,
    required this.updatedAt,
    this.photoUrl,
    this.isEmailVerified = false,
    this.medicalInfo,
  });

  /// Create a copy of this user with updated fields
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    List<String>? allergies,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? photoUrl,
    bool? isEmailVerified,
    Map<String, dynamic>? medicalInfo,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      allergies: allergies ?? this.allergies,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      medicalInfo: medicalInfo ?? this.medicalInfo,
    );
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'allergies': allergies,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'photoUrl': photoUrl,
      'isEmailVerified': isEmailVerified,
      'medicalInfo': medicalInfo,
    };
  }

  /// Create from JSON/Firestore document
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      allergies: List<String>.from(json['allergies'] as List? ?? []),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoUrl: json['photoUrl'] as String?,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      medicalInfo: json['medicalInfo'] as Map<String, dynamic>?,
    );
  }

  /// Create from Firestore document snapshot
  factory UserModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('Document data is null');
    }
    return UserModel.fromJson({...data, 'id': doc.id});
  }

  /// Create initial user model from Firebase Auth User
  factory UserModel.fromFirebaseUser({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
    bool isEmailVerified = false,
  }) {
    final now = DateTime.now();
    return UserModel(
      id: uid,
      name: displayName ?? email.split('@')[0],
      email: email,
      allergies: [],
      createdAt: now,
      updatedAt: now,
      photoUrl: photoUrl,
      isEmailVerified: isEmailVerified,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, allergiesCount: ${allergies.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
