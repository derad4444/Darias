import 'package:cloud_firestore/cloud_firestore.dart';

import 'subscription_model.dart' show SubscriptionStatus;

/// ユーザーモデル
class UserModel {
  final String id;
  final String email;
  final String? characterId;
  final SubscriptionStatus subscriptionStatus;
  final bool hasCompletedOnboarding;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    this.characterId,
    this.subscriptionStatus = SubscriptionStatus.free,
    this.hasCompletedOnboarding = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPremium => subscriptionStatus == SubscriptionStatus.premium;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    final statusStr = data['subscriptionStatus'] as String? ?? 'free';
    final status = statusStr == 'premium'
        ? SubscriptionStatus.premium
        : SubscriptionStatus.free;

    return UserModel(
      id: doc.id,
      email: data['email'] as String? ?? '',
      characterId: data['characterId'] as String?,
      subscriptionStatus: status,
      hasCompletedOnboarding: data['hasCompletedOnboarding'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'characterId': characterId,
      'subscriptionStatus': subscriptionStatus == SubscriptionStatus.premium
          ? 'premium'
          : 'free',
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? characterId,
    SubscriptionStatus? subscriptionStatus,
    bool? hasCompletedOnboarding,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      characterId: characterId ?? this.characterId,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
