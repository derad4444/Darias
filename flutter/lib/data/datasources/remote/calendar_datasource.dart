import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/schedule_model.dart';

/// カレンダー関連のリモートデータソース
class CalendarDatasource {
  final FirebaseFirestore _firestore;

  CalendarDatasource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// 月のスケジュールをリアルタイムで取得
  Stream<List<ScheduleModel>> watchSchedules({
    required String userId,
    required DateTime month,
  }) {
    // 月の最初と最後の日を計算
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('schedules')
        .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
        .orderBy('startDate')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ScheduleModel.fromFirestore(doc)).toList();
    });
  }

  /// 全スケジュールをリアルタイムで取得（キャッシュ用）
  Stream<List<ScheduleModel>> watchAllSchedules({
    required String userId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('schedules')
        .orderBy('startDate')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ScheduleModel.fromFirestore(doc)).toList();
    });
  }

  /// スケジュールを追加
  Future<String> addSchedule({
    required String userId,
    required ScheduleModel schedule,
  }) async {
    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('schedules')
        .add(schedule.toMap());
    return docRef.id;
  }

  /// スケジュールを更新
  Future<void> updateSchedule({
    required String userId,
    required ScheduleModel schedule,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('schedules')
        .doc(schedule.id)
        .update(schedule.toMap());
  }

  /// スケジュールを削除
  Future<void> deleteSchedule({
    required String userId,
    required String scheduleId,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('schedules')
        .doc(scheduleId)
        .delete();
  }

  /// 特定の日のスケジュールを取得
  Future<List<ScheduleModel>> getSchedulesForDay({
    required String userId,
    required DateTime day,
  }) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('schedules')
        .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('startDate')
        .get();

    return snapshot.docs.map((doc) => ScheduleModel.fromFirestore(doc)).toList();
  }
}
