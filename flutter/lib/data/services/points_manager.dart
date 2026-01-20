import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ポイント管理サービス
class PointsManager {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  static const int pointsPerMessage = 10;

  PointsManager({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// ポイントを読み込み
  Future<int> loadPoints(String characterId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw Exception('ユーザーが認証されていません');
    }

    if (characterId.isEmpty) {
      throw Exception('キャラクターIDが空です');
    }

    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('details')
        .doc('current')
        .get();

    if (doc.exists && doc.data() != null) {
      return doc.data()!['points'] as int? ?? 0;
    }
    return 0;
  }

  /// ポイントを付与（チャット送信時）
  Future<int> addPoints(String characterId, {int? currentPoints}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw Exception('ユーザーが認証されていません');
    }

    if (characterId.isEmpty) {
      throw Exception('キャラクターIDが空です');
    }

    final points = currentPoints ?? await loadPoints(characterId);
    final newPoints = points + pointsPerMessage;

    final detailsRef = _db
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('details')
        .doc('current');

    final doc = await detailsRef.get();

    if (doc.exists) {
      await detailsRef.update({
        'points': newPoints,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else {
      await detailsRef.set({
        'points': newPoints,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return newPoints;
  }

  /// ポイントを消費
  Future<int> consumePoints(
    String characterId,
    int amount, {
    int? currentPoints,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw Exception('ユーザーが認証されていません');
    }

    if (characterId.isEmpty) {
      throw Exception('キャラクターIDが空です');
    }

    final points = currentPoints ?? await loadPoints(characterId);
    if (points < amount) {
      throw Exception('ポイントが不足しています');
    }

    final newPoints = points - amount;

    final detailsRef = _db
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('details')
        .doc('current');

    await detailsRef.update({
      'points': newPoints,
      'updated_at': FieldValue.serverTimestamp(),
    });

    return newPoints;
  }

  /// ポイントを監視するストリーム
  Stream<int> watchPoints(String characterId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      return Stream.value(0);
    }

    if (characterId.isEmpty) {
      return Stream.value(0);
    }

    return _db
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('details')
        .doc('current')
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return doc.data()!['points'] as int? ?? 0;
      }
      return 0;
    });
  }
}

/// プロバイダー
final pointsManagerProvider = Provider<PointsManager>((ref) {
  return PointsManager();
});

/// キャラクターのポイントを監視するプロバイダー
final characterPointsProvider =
    StreamProvider.family<int, String>((ref, characterId) {
  final manager = ref.watch(pointsManagerProvider);
  return manager.watchPoints(characterId);
});
