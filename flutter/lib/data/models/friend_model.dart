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
  final int friendshipScore;   // 友情
  final int romanceScore;      // 恋愛
  final int workScore;         // 仕事
  final int trustScore;        // 信頼
  final int overallScore;      // 総合
  final String friendshipComment;
  final String romanceComment;
  final String workComment;
  final String trustComment;
  final String overallComment;
  final List<CompatibilityMessage> conversation;

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
    required this.conversation,
  });

  factory CompatibilityResult.fromMap(Map<String, dynamic> map) {
    final conv = (map['conversation'] as List<dynamic>? ?? [])
        .map((e) => CompatibilityMessage.fromMap(e as Map<String, dynamic>))
        .toList();
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
      conversation: conv,
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
