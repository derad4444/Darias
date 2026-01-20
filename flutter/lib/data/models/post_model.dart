import 'package:cloud_firestore/cloud_firestore.dart';

/// チャットメッセージ（Firestore保存用）
class PostModel {
  final String id;
  final String userId;
  final String characterId;
  final String content;
  final DateTime timestamp;
  final String analysisResult;

  const PostModel({
    required this.id,
    required this.userId,
    required this.characterId,
    required this.content,
    required this.timestamp,
    required this.analysisResult,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    return PostModel(
      id: doc.id,
      userId: data['user_id'] as String? ?? '',
      characterId: data['character_id'] as String? ?? '',
      content: data['content'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      analysisResult: data['analysis_result'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'character_id': characterId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'analysis_result': analysisResult,
    };
  }

  PostModel copyWith({
    String? id,
    String? userId,
    String? characterId,
    String? content,
    DateTime? timestamp,
    String? analysisResult,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      characterId: characterId ?? this.characterId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      analysisResult: analysisResult ?? this.analysisResult,
    );
  }
}

/// チャットメッセージ（UI表示用）
class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  factory ChatMessage.fromPost(PostModel post, {required bool isUser}) {
    return ChatMessage(
      id: post.id,
      content: isUser ? post.content : post.analysisResult,
      isUser: isUser,
      timestamp: post.timestamp,
    );
  }
}
