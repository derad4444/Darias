import 'package:cloud_firestore/cloud_firestore.dart';

/// フレンドとの共有レベル
enum FriendShareLevel {
  none('none', '非公開'),
  public('public', '公開'),
  full('full', '全公開');

  const FriendShareLevel(this.value, this.label);
  final String value;
  final String label;

  static FriendShareLevel fromString(String value) {
    return FriendShareLevel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FriendShareLevel.none,
    );
  }
}

/// フレンド申請ステータス
enum FriendRequestStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected');

  const FriendRequestStatus(this.value);
  final String value;

  static FriendRequestStatus fromString(String value) {
    return FriendRequestStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FriendRequestStatus.pending,
    );
  }
}

/// フレンド申請モデル
class FriendRequestModel {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String fromUserEmail;
  final String toUserId;
  final String toUserName;
  final FriendRequestStatus status;
  final DateTime createdAt;

  const FriendRequestModel({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.fromUserEmail,
    required this.toUserId,
    this.toUserName = '',
    required this.status,
    required this.createdAt,
  });

  factory FriendRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendRequestModel(
      id: doc.id,
      fromUserId: data['fromUserId'] as String? ?? '',
      fromUserName: data['fromUserName'] as String? ?? '',
      fromUserEmail: data['fromUserEmail'] as String? ?? '',
      toUserId: data['toUserId'] as String? ?? '',
      toUserName: data['toUserName'] as String? ?? '',
      status: FriendRequestStatus.fromString(data['status'] as String? ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserEmail': fromUserEmail,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// フレンドモデル（承認済みのフレンド関係）
class FriendModel {
  final String id; // friendUserId
  final String name;
  final String email;
  final FriendShareLevel shareLevel;
  final DateTime createdAt;

  // Firestore外から取得する追加情報（省略可）
  final Map<String, double>? big5Scores;

  const FriendModel({
    required this.id,
    required this.name,
    required this.email,
    required this.shareLevel,
    required this.createdAt,
    this.big5Scores,
  });

  factory FriendModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      shareLevel: FriendShareLevel.fromString(data['shareLevel'] as String? ?? 'none'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'shareLevel': shareLevel.value,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  FriendModel copyWith({
    String? id,
    String? name,
    String? email,
    FriendShareLevel? shareLevel,
    DateTime? createdAt,
    Map<String, double>? big5Scores,
  }) {
    return FriendModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      shareLevel: shareLevel ?? this.shareLevel,
      createdAt: createdAt ?? this.createdAt,
      big5Scores: big5Scores ?? this.big5Scores,
    );
  }
}

/// 相性診断結果モデル
class CompatibilityResult {
  final int friendshipScore;
  final int romanceScore;
  final int workScore;
  final int trustScore;
  final int overallScore;
  final String friendshipComment;
  final String romanceComment;
  final String workComment;
  final String trustComment;
  final String overallComment;
  final String friendshipAdvice;
  final String romanceAdvice;
  final String workAdvice;
  final String trustAdvice;
  final List<CompatibilityMessage> conversation;
  final DateTime? createdAt;
  final String? big5Key;
  /// 解放済みカテゴリ（例: ["friendship", "romance"]）
  final List<String> unlockedCategories;

  const CompatibilityResult({
    required this.friendshipScore,
    required this.romanceScore,
    required this.workScore,
    required this.trustScore,
    required this.overallScore,
    required this.friendshipComment,
    required this.romanceComment,
    required this.workComment,
    required this.trustComment,
    required this.overallComment,
    this.friendshipAdvice = '',
    this.romanceAdvice = '',
    this.workAdvice = '',
    this.trustAdvice = '',
    required this.conversation,
    this.createdAt,
    this.big5Key,
    this.unlockedCategories = const [],
  });

  factory CompatibilityResult.fromMap(Map<String, dynamic> map) {
    final conv = (map['conversation'] as List<dynamic>? ?? [])
        .map((e) => CompatibilityMessage.fromMap(e as Map<String, dynamic>))
        .toList();
    DateTime? createdAt;
    final raw = map['createdAt'];
    if (raw is Timestamp) {
      createdAt = raw.toDate();
    } else if (raw is DateTime) {
      createdAt = raw;
    }
    return CompatibilityResult(
      friendshipScore: (map['friendshipScore'] as num?)?.toInt() ?? 0,
      romanceScore: (map['romanceScore'] as num?)?.toInt() ?? 0,
      workScore: (map['workScore'] as num?)?.toInt() ?? 0,
      trustScore: (map['trustScore'] as num?)?.toInt() ?? 0,
      overallScore: (map['overallScore'] as num?)?.toInt() ?? 0,
      friendshipComment: map['friendshipComment'] as String? ?? '',
      romanceComment: map['romanceComment'] as String? ?? '',
      workComment: map['workComment'] as String? ?? '',
      trustComment: map['trustComment'] as String? ?? '',
      overallComment: map['overallComment'] as String? ?? '',
      friendshipAdvice: map['friendshipAdvice'] as String? ?? '',
      romanceAdvice: map['romanceAdvice'] as String? ?? '',
      workAdvice: map['workAdvice'] as String? ?? '',
      trustAdvice: map['trustAdvice'] as String? ?? '',
      conversation: conv,
      createdAt: createdAt,
      big5Key: map['big5Key'] as String?,
      unlockedCategories: List<String>.from(map['unlockedCategories'] as List? ?? []),
    );
  }
}

/// キャラクター会話メッセージ
class CompatibilityMessage {
  final bool isMyCharacter; // true=自分のキャラ, false=相手のキャラ
  final String text;

  const CompatibilityMessage({
    required this.isMyCharacter,
    required this.text,
  });

  factory CompatibilityMessage.fromMap(Map<String, dynamic> map) {
    return CompatibilityMessage(
      isMyCharacter: map['isMyCharacter'] as bool? ?? true,
      text: map['text'] as String? ?? '',
    );
  }
}

// ============================================================
// カテゴリ別相性診断（新設計）
// ============================================================

/// 全カテゴリのスコア（BIG5から決定論的に算出）
class CompatibilityScores {
  final int friendship;
  final int romance;
  final int work;
  final int trust;
  final int overall;

  const CompatibilityScores({
    required this.friendship,
    required this.romance,
    required this.work,
    required this.trust,
    required this.overall,
  });

  factory CompatibilityScores.fromMap(Map<String, dynamic> map) {
    return CompatibilityScores(
      friendship: (map['friendship'] as num?)?.toInt() ?? 0,
      romance: (map['romance'] as num?)?.toInt() ?? 0,
      work: (map['work'] as num?)?.toInt() ?? 0,
      trust: (map['trust'] as num?)?.toInt() ?? 0,
      overall: (map['overall'] as num?)?.toInt() ?? 0,
    );
  }

  int scoreFor(String key) {
    switch (key) {
      case 'friendship': return friendship;
      case 'romance': return romance;
      case 'work': return work;
      case 'trust': return trust;
      default: return overall;
    }
  }
}

/// 1カテゴリの診断結果（会話 + コメント + アドバイス）
class CategoryDiagnosis {
  final int score;
  final String comment;
  final String advice;
  final List<CompatibilityMessage> conversation;
  final String? big5Key;
  final DateTime? createdAt;

  const CategoryDiagnosis({
    required this.score,
    required this.comment,
    required this.advice,
    required this.conversation,
    this.big5Key,
    this.createdAt,
  });

  /// Cloud Function レスポンス（category + scores 付き）から生成
  factory CategoryDiagnosis.fromFunctionResult(
      Map<String, dynamic> data, String categoryKey) {
    final conv = (data['conversation'] as List<dynamic>? ?? [])
        .map((e) => CompatibilityMessage.fromMap(e as Map<String, dynamic>))
        .toList();
    final scores = CompatibilityScores.fromMap(
        (data['scores'] as Map<dynamic, dynamic>?)
                ?.map((k, v) => MapEntry(k.toString(), v)) ??
            {});
    return CategoryDiagnosis(
      score: scores.scoreFor(categoryKey),
      comment: data['comment'] as String? ?? '',
      advice: data['advice'] as String? ?? '',
      conversation: conv,
      big5Key: data['big5Key'] as String?,
    );
  }

  /// Firestoreドキュメントのカテゴリフィールドから生成
  factory CategoryDiagnosis.fromDocField(
      Map<String, dynamic> catMap, int score) {
    final conv = (catMap['conversation'] as List<dynamic>? ?? [])
        .map((e) => CompatibilityMessage.fromMap(e as Map<String, dynamic>))
        .toList();
    DateTime? createdAt;
    final raw = catMap['createdAt'];
    if (raw is Timestamp) createdAt = raw.toDate();
    return CategoryDiagnosis(
      score: score,
      comment: catMap['comment'] as String? ?? '',
      advice: catMap['advice'] as String? ?? '',
      conversation: conv,
      big5Key: catMap['big5Key'] as String?,
      createdAt: createdAt,
    );
  }
}

/// 相性診断ドキュメント（Firestore全体）
class CompatibilityDocument {
  final List<String> unlockedCategories;
  final CompatibilityScores? scores;
  final CategoryDiagnosis? friendship;
  final CategoryDiagnosis? romance;
  final CategoryDiagnosis? work;
  final CategoryDiagnosis? trust;

  const CompatibilityDocument({
    required this.unlockedCategories,
    this.scores,
    this.friendship,
    this.romance,
    this.work,
    this.trust,
  });

  factory CompatibilityDocument.fromMap(Map<String, dynamic> map) {
    CompatibilityScores? scores;
    if (map['scores'] is Map) {
      scores = CompatibilityScores.fromMap(
          (map['scores'] as Map<dynamic, dynamic>)
              .map((k, v) => MapEntry(k.toString(), v)));
    }

    CategoryDiagnosis? parseCat(String key) {
      if (map[key] is! Map) return null;
      final catMap = (map[key] as Map<dynamic, dynamic>)
          .map((k, v) => MapEntry(k.toString(), v));
      return CategoryDiagnosis.fromDocField(catMap, scores?.scoreFor(key) ?? 0);
    }

    return CompatibilityDocument(
      unlockedCategories:
          List<String>.from(map['unlockedCategories'] as List? ?? []),
      scores: scores,
      friendship: parseCat('friendship'),
      romance: parseCat('romance'),
      work: parseCat('work'),
      trust: parseCat('trust'),
    );
  }

  CategoryDiagnosis? categoryFor(String key) {
    switch (key) {
      case 'friendship': return friendship;
      case 'romance': return romance;
      case 'work': return work;
      case 'trust': return trust;
      default: return null;
    }
  }
}
