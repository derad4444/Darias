import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/memo_model.dart';

/// メモ関連のリモートデータソース
class MemoDatasource {
  final FirebaseFirestore _firestore;

  MemoDatasource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// メモリストをリアルタイムで取得
  Stream<List<MemoModel>> watchMemos({
    required String userId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('memos')
        .orderBy('isPinned', descending: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MemoModel.fromFirestore(doc)).toList();
    });
  }

  /// メモを追加
  Future<String> addMemo({
    required String userId,
    required MemoModel memo,
  }) async {
    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('memos')
        .add(memo.toMap());
    return docRef.id;
  }

  /// メモを更新
  Future<void> updateMemo({
    required String userId,
    required MemoModel memo,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('memos')
        .doc(memo.id)
        .update(memo.copyWith(updatedAt: DateTime.now()).toMap());
  }

  /// メモを削除
  Future<void> deleteMemo({
    required String userId,
    required String memoId,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('memos')
        .doc(memoId)
        .delete();
  }

  /// ピン留めを切り替え
  Future<void> togglePin({
    required String userId,
    required String memoId,
    required bool isPinned,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('memos')
        .doc(memoId)
        .update({
      'isPinned': isPinned,
      'updatedAt': Timestamp.now(),
    });
  }
}
