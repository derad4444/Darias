import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/daily_mission_model.dart';

class DailyMissionDatasource {
  final FirebaseFirestore _firestore;
  final String userId;

  DailyMissionDatasource({required FirebaseFirestore firestore, required this.userId})
      : _firestore = firestore;

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  DocumentReference _docRef(String date) =>
      _firestore.collection('users').doc(userId).collection('dailyMissions').doc(date);

  Future<DailyMission> fetchToday() async {
    final date = _todayStr();
    final snap = await _docRef(date).get();
    if (!snap.exists) {
      return DailyMission(date: date);
    }
    return DailyMission.fromFirestore(snap);
  }

  // 完了済み日付セットをカレンダー表示用に取得（過去90日）
  Future<Set<String>> fetchCompletedDates() async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('dailyMissions')
        .where('allCompleted', isEqualTo: true)
        .get();
    return snap.docs.map((d) => d.id).toSet();
  }

  Future<void> save(DailyMission mission) async {
    await _docRef(mission.date).set(mission.toMap(), SetOptions(merge: true));
  }

  Future<DailyMission> markLogin() async {
    final mission = await fetchToday();
    if (mission.loginDone) return mission;
    final updated = _checkAllCompleted(mission.copyWith(loginDone: true));
    await save(updated);
    return updated;
  }

  Future<DailyMission> incrementChat() async {
    final mission = await fetchToday();
    if (mission.chat6Done) return mission;
    final updated = _checkAllCompleted(
      mission.copyWith(chatCount: mission.chatCount + 1),
    );
    await save(updated);
    return updated;
  }

  Future<DailyMission> markDiaryViewed() async {
    final mission = await fetchToday();
    if (mission.diaryViewed) return mission;
    final updated = _checkAllCompleted(mission.copyWith(diaryViewed: true));
    await save(updated);
    return updated;
  }

  Future<DailyMission> markDiaryRead() async {
    final mission = await fetchToday();
    if (mission.diaryRead) return mission;
    final updated = _checkAllCompleted(mission.copyWith(diaryRead: true));
    await save(updated);
    return updated;
  }

  DailyMission _checkAllCompleted(DailyMission m) {
    if (m.loginDone && m.chat2Done && m.chat6Done && m.diaryViewed && m.diaryRead && !m.allCompleted) {
      return m.copyWith(allCompleted: true, completedAt: DateTime.now());
    }
    return m;
  }
}
