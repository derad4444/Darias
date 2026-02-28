import 'package:cloud_firestore/cloud_firestore.dart';

/// 6人会議モデル（iOS版SixPersonMeetingと同じ構造）
class SixPersonMeetingModel {
  final String id;
  final MeetingConversation conversation;
  final MeetingStatsData statsData;
  final DateTime createdAt;
  final String? personalityKey;
  final String? concernCategory;
  final int? usageCount;
  final DateTime? lastUsedAt;

  const SixPersonMeetingModel({
    required this.id,
    required this.conversation,
    required this.statsData,
    required this.createdAt,
    this.personalityKey,
    this.concernCategory,
    this.usageCount,
    this.lastUsedAt,
  });

  factory SixPersonMeetingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    return SixPersonMeetingModel(
      id: doc.id,
      conversation: MeetingConversation.fromMap(
          data['conversation'] as Map<String, dynamic>? ?? {}),
      statsData: MeetingStatsData.fromMap(
          data['statsData'] as Map<String, dynamic>? ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      personalityKey: data['personalityKey'] as String?,
      concernCategory: data['concernCategory'] as String?,
      usageCount: data['usageCount'] as int?,
      lastUsedAt: (data['lastUsedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory SixPersonMeetingModel.fromMap(Map<String, dynamic> data, String id) {
    return SixPersonMeetingModel(
      id: id,
      conversation: MeetingConversation.fromMap(
          data['conversation'] as Map<String, dynamic>? ?? {}),
      statsData: MeetingStatsData.fromMap(
          data['statsData'] as Map<String, dynamic>? ?? {}),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      personalityKey: data['personalityKey'] as String?,
      concernCategory: data['concernCategory'] as String?,
      usageCount: data['usageCount'] as int?,
      lastUsedAt: data['lastUsedAt'] is Timestamp
          ? (data['lastUsedAt'] as Timestamp).toDate()
          : null,
    );
  }
}

/// 会話データ
class MeetingConversation {
  final List<ConversationRound> rounds;
  final MeetingConclusion conclusion;

  const MeetingConversation({
    required this.rounds,
    required this.conclusion,
  });

  factory MeetingConversation.fromMap(Map<String, dynamic> map) {
    final roundsList = (map['rounds'] as List<dynamic>?)
            ?.map((e) => ConversationRound.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    return MeetingConversation(
      rounds: roundsList,
      conclusion: MeetingConclusion.fromMap(
          map['conclusion'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// 会話ラウンド
class ConversationRound {
  final int roundNumber;
  final List<ConversationMessage> messages;

  const ConversationRound({
    required this.roundNumber,
    required this.messages,
  });

  factory ConversationRound.fromMap(Map<String, dynamic> map) {
    final messagesList = (map['messages'] as List<dynamic>?)
            ?.map((e) => ConversationMessage.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ConversationRound(
      roundNumber: map['roundNumber'] as int? ?? 0,
      messages: messagesList,
    );
  }
}

/// 会話メッセージ
class ConversationMessage {
  final String characterId;
  final String characterName;
  final String text;
  final String timestamp;

  const ConversationMessage({
    required this.characterId,
    required this.characterName,
    required this.text,
    required this.timestamp,
  });

  factory ConversationMessage.fromMap(Map<String, dynamic> map) {
    return ConversationMessage(
      characterId: map['characterId'] as String? ?? '',
      characterName: map['characterName'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: map['timestamp'] as String? ?? '',
    );
  }

  /// メッセージの表示位置（左右）
  MessagePosition get position {
    // 左側（慎重派グループ）: original, ideal, wise
    // 右側（行動派グループ）: opposite, shadow, child
    switch (characterId) {
      case 'original':
      case 'ideal':
      case 'wise':
        return MessagePosition.left;
      case 'opposite':
      case 'shadow':
      case 'child':
        return MessagePosition.right;
      default:
        return MessagePosition.left;
    }
  }

  /// キャラクターの色
  String get characterColor {
    switch (characterId) {
      case 'original':
        return 'blue'; // 今の自分 - 冷静な青
      case 'opposite':
        return 'orange'; // 真逆の自分 - 活発なオレンジ
      case 'ideal':
        return 'purple'; // 理想の自分 - 高貴な紫
      case 'shadow':
        return 'red'; // 本音の自分 - 率直な赤
      case 'child':
        return 'green'; // 子供の頃の自分 - 新鮮な緑
      case 'wise':
        return 'brown'; // 未来の自分 - 落ち着いた茶色
      default:
        return 'gray';
    }
  }
}

/// メッセージの表示位置
enum MessagePosition { left, right }

/// 会議の結論
class MeetingConclusion {
  final String summary;
  final List<String> recommendations;
  final List<String> nextSteps;

  const MeetingConclusion({
    required this.summary,
    required this.recommendations,
    required this.nextSteps,
  });

  factory MeetingConclusion.fromMap(Map<String, dynamic> map) {
    return MeetingConclusion(
      summary: map['summary'] as String? ?? '',
      recommendations: (map['recommendations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      nextSteps: (map['nextSteps'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// 統計データ
class MeetingStatsData {
  final int similarCount;
  final int totalUsers;
  final int avgAge;
  final int percentile;
  final String personalityKey;

  const MeetingStatsData({
    required this.similarCount,
    required this.totalUsers,
    required this.avgAge,
    required this.percentile,
    required this.personalityKey,
  });

  factory MeetingStatsData.fromMap(Map<String, dynamic> map) {
    return MeetingStatsData(
      similarCount: map['similarCount'] as int? ?? 0,
      totalUsers: map['totalUsers'] as int? ?? 0,
      avgAge: map['avgAge'] as int? ?? 0,
      percentile: map['percentile'] as int? ?? 0,
      personalityKey: map['personalityKey'] as String? ?? '',
    );
  }

  String get displayText {
    if (similarCount > 0) {
      return '$similarCount人の似た性格の方のデータを参考にしています';
    } else {
      return 'あなた専用の分析を生成しました';
    }
  }
}

/// 会議生成レスポンス
class GenerateMeetingResponse {
  final bool success;
  final String meetingId;
  final MeetingConversation conversation;
  final MeetingStatsData statsData;
  final bool cacheHit;
  final int usageCount;
  final int duration;

  const GenerateMeetingResponse({
    required this.success,
    required this.meetingId,
    required this.conversation,
    required this.statsData,
    required this.cacheHit,
    required this.usageCount,
    required this.duration,
  });

  factory GenerateMeetingResponse.fromMap(Map<String, dynamic> map) {
    return GenerateMeetingResponse(
      success: map['success'] as bool? ?? false,
      meetingId: map['meetingId'] as String? ?? '',
      conversation: MeetingConversation.fromMap(
          map['conversation'] as Map<String, dynamic>? ?? {}),
      statsData: MeetingStatsData.fromMap(
          map['statsData'] as Map<String, dynamic>? ?? {}),
      cacheHit: map['cacheHit'] as bool? ?? false,
      usageCount: map['usageCount'] as int? ?? 0,
      duration: map['duration'] as int? ?? 0,
    );
  }
}

/// 悩みカテゴリ
enum ConcernCategory {
  career('career', 'キャリア・仕事', 'briefcase'),
  romance('romance', '恋愛・人間関係', 'heart'),
  money('money', 'お金・経済', 'attach_money'),
  health('health', '健康・ライフスタイル', 'favorite'),
  family('family', '家族・子育て', 'home'),
  future('future', '将来・人生設計', 'calendar_today'),
  hobby('hobby', '趣味・自己実現', 'brush'),
  study('study', '学習・スキル', 'book'),
  moving('moving', '引っ越し・住居', 'apartment'),
  other('other', 'その他', 'more_horiz');

  final String value;
  final String displayName;
  final String icon;

  const ConcernCategory(this.value, this.displayName, this.icon);

  static ConcernCategory fromString(String value) {
    return ConcernCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ConcernCategory.other,
    );
  }
}
