import 'package:cloud_firestore/cloud_firestore.dart';

class DailyMission {
  final String date; // YYYY-MM-DD
  final bool loginDone;
  final int chatCount; // 0〜6
  final bool diaryViewed;  // 今日のスケジュール確認
  final bool diaryRead;    // 日記確認
  final bool allCompleted;
  final DateTime? completedAt;

  const DailyMission({
    required this.date,
    this.loginDone = false,
    this.chatCount = 0,
    this.diaryViewed = false,
    this.diaryRead = false,
    this.allCompleted = false,
    this.completedAt,
  });

  bool get chat2Done => chatCount >= 2;
  bool get chat6Done => chatCount >= 6;

  int get completedCount =>
      (loginDone ? 1 : 0) + (chat2Done ? 1 : 0) + (chat6Done ? 1 : 0) + (diaryViewed ? 1 : 0) + (diaryRead ? 1 : 0);

  static const int total = 5;

  factory DailyMission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final loginDone = data['loginDone'] as bool? ?? false;
    final chatCount = (data['chatCount'] as num?)?.toInt() ?? 0;
    final diaryViewed = data['diaryViewed'] as bool? ?? false;
    final diaryRead = data['diaryRead'] as bool? ?? false;
    // Firestoreの古いallCompletedを信頼せず、現在のフィールドから再計算する
    final allCompleted = loginDone && chatCount >= 2 && chatCount >= 6 && diaryViewed && diaryRead;
    return DailyMission(
      date: doc.id,
      loginDone: loginDone,
      chatCount: chatCount,
      diaryViewed: diaryViewed,
      diaryRead: diaryRead,
      allCompleted: allCompleted,
      completedAt: allCompleted ? (data['completedAt'] as Timestamp?)?.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'loginDone': loginDone,
        'chatCount': chatCount,
        'diaryViewed': diaryViewed,
        'diaryRead': diaryRead,
        'allCompleted': allCompleted,
        if (completedAt != null)
          'completedAt': Timestamp.fromDate(completedAt!),
      };

  DailyMission copyWith({
    bool? loginDone,
    int? chatCount,
    bool? diaryViewed,
    bool? diaryRead,
    bool? allCompleted,
    DateTime? completedAt,
  }) =>
      DailyMission(
        date: date,
        loginDone: loginDone ?? this.loginDone,
        chatCount: chatCount ?? this.chatCount,
        diaryViewed: diaryViewed ?? this.diaryViewed,
        diaryRead: diaryRead ?? this.diaryRead,
        allCompleted: allCompleted ?? this.allCompleted,
        completedAt: completedAt ?? this.completedAt,
      );
}
