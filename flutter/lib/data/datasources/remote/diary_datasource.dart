import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/diary_model.dart';

/// 日記関連のリモートデータソース
class DiaryDatasource {
  final FirebaseFirestore _firestore;

  DiaryDatasource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// 日記リストをリアルタイムで取得
  Stream<List<DiaryModel>> watchDiaries({
    required String userId,
    required String characterId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('diary')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => DiaryModel.fromFirestore(doc)).toList();
    });
  }

  /// 特定の日記を取得
  Future<DiaryModel?> getDiary({
    required String userId,
    required String characterId,
    required String diaryId,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('diary')
        .doc(diaryId)
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return DiaryModel.fromFirestore(doc);
  }

  /// ユーザーコメントを保存
  Future<void> saveUserComment({
    required String userId,
    required String characterId,
    required String diaryId,
    required String comment,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('diary')
        .doc(diaryId)
        .update({'user_comment': comment});
  }
}
