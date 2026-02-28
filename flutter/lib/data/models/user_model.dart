import 'package:cloud_firestore/cloud_firestore.dart';

/// ユーザーモデル
class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? characterGender;
  final String? characterId;
  final bool hasCompletedOnboarding;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.characterGender,
    this.characterId,
    this.hasCompletedOnboarding = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    return UserModel(
      id: doc.id,
      email: data['email'] as String? ?? '',
      name: data['name'] as String?,
      characterGender: data['characterGender'] as String?,
      characterId: data['character_id'] as String?,
      hasCompletedOnboarding: data['hasCompletedOnboarding'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'characterGender': characterGender,
      'character_id': characterId,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? characterGender,
    String? characterId,
    bool? hasCompletedOnboarding,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      characterGender: characterGender ?? this.characterGender,
      characterId: characterId ?? this.characterId,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
