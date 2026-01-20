import 'package:cloud_firestore/cloud_firestore.dart';

/// 会議参加者（AIキャラクター）
class MeetingParticipant {
  final String id;
  final String name;
  final String role;
  final String personalityType;
  final String iconColor;

  const MeetingParticipant({
    required this.id,
    required this.name,
    required this.role,
    required this.personalityType,
    required this.iconColor,
  });

  factory MeetingParticipant.fromMap(Map<String, dynamic> map) {
    return MeetingParticipant(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? '',
      personalityType: map['personalityType'] as String? ?? '',
      iconColor: map['iconColor'] as String? ?? '0xFF2196F3',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'personalityType': personalityType,
      'iconColor': iconColor,
    };
  }
}

/// 会議メッセージ
class MeetingMessage {
  final String participantId;
  final String participantName;
  final String content;
  final DateTime timestamp;

  const MeetingMessage({
    required this.participantId,
    required this.participantName,
    required this.content,
    required this.timestamp,
  });

  factory MeetingMessage.fromMap(Map<String, dynamic> map) {
    return MeetingMessage(
      participantId: map['participantId'] as String? ?? '',
      participantName: map['participantName'] as String? ?? '',
      content: map['content'] as String? ?? '',
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participantId': participantId,
      'participantName': participantName,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

/// 会議モデル
class MeetingModel {
  final String id;
  final String topic;
  final List<MeetingParticipant> participants;
  final List<MeetingMessage> messages;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MeetingModel({
    required this.id,
    required this.topic,
    required this.participants,
    required this.messages,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MeetingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    final participantsList = (data['participants'] as List<dynamic>?)
            ?.map((e) => MeetingParticipant.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    final messagesList = (data['messages'] as List<dynamic>?)
            ?.map((e) => MeetingMessage.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    return MeetingModel(
      id: doc.id,
      topic: data['topic'] as String? ?? '',
      participants: participantsList,
      messages: messagesList,
      isActive: data['isActive'] as bool? ?? false,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'participants': participants.map((e) => e.toMap()).toList(),
      'messages': messages.map((e) => e.toMap()).toList(),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  MeetingModel copyWith({
    String? id,
    String? topic,
    List<MeetingParticipant>? participants,
    List<MeetingMessage>? messages,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MeetingModel(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// デフォルトの6人の参加者を生成
  static List<MeetingParticipant> defaultParticipants = const [
    MeetingParticipant(
      id: 'leader',
      name: 'リーダー田中',
      role: '議長・進行役',
      personalityType: '外向的・協調的',
      iconColor: '0xFF2196F3',
    ),
    MeetingParticipant(
      id: 'analyst',
      name: '分析家・鈴木',
      role: 'データ分析担当',
      personalityType: '論理的・慎重',
      iconColor: '0xFF4CAF50',
    ),
    MeetingParticipant(
      id: 'creative',
      name: 'クリエイター佐藤',
      role: 'アイデア創出担当',
      personalityType: '創造的・開放的',
      iconColor: '0xFFFF9800',
    ),
    MeetingParticipant(
      id: 'critic',
      name: '批評家・山田',
      role: 'リスク管理担当',
      personalityType: '批判的・現実的',
      iconColor: '0xFFF44336',
    ),
    MeetingParticipant(
      id: 'supporter',
      name: 'サポーター伊藤',
      role: 'チームケア担当',
      personalityType: '共感的・協調的',
      iconColor: '0xFF9C27B0',
    ),
    MeetingParticipant(
      id: 'executor',
      name: '実行者・渡辺',
      role: '実務・実行担当',
      personalityType: '行動的・効率重視',
      iconColor: '0xFF795548',
    ),
  ];

  /// 新しい会議を作成
  static MeetingModel create({
    required String topic,
  }) {
    final now = DateTime.now();
    return MeetingModel(
      id: '',
      topic: topic,
      participants: defaultParticipants,
      messages: [],
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }
}
