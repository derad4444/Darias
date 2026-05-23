import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// BIG5診断関連のリモートデータソース（リセット機能のみ）
class Big5Datasource {
  final FirebaseFirestore _firestore;

  Big5Datasource({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// 性格診断結果を完全リセット
  Future<void> resetDiagnosis({
    required String userId,
    required String characterId,
  }) async {
    // big5Progress/current を削除
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('big5Progress')
        .doc('current')
        .delete();

    // details/current の診断・属性・性格解析フィールドをすべて削除
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('details')
        .doc('current')
        .update({
      'confirmedBig5Scores': FieldValue.delete(),
      'personalityKey': FieldValue.delete(),
      'analysis_level': FieldValue.delete(),
      'sixPersonalities': FieldValue.delete(),
      'favorite_color': FieldValue.delete(),
      'favorite_place': FieldValue.delete(),
      'favorite_word': FieldValue.delete(),
      'word_tendency': FieldValue.delete(),
      'strength': FieldValue.delete(),
      'weakness': FieldValue.delete(),
      'skill': FieldValue.delete(),
      'hobby': FieldValue.delete(),
      'aptitude': FieldValue.delete(),
      'dream': FieldValue.delete(),
      'favorite_entertainment_genre': FieldValue.delete(),
      'axisScores': FieldValue.delete(),
      'element': FieldValue.delete(),
      'typeName': FieldValue.delete(),
      'convertedBig5Scores': FieldValue.delete(),
      'axisUpdatedAt': FieldValue.delete(),
      'axisGeneratedAt': FieldValue.delete(),
      'personalityNarrative': FieldValue.delete(),
    });

    // generationStatus/current を削除
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('generationStatus')
        .doc('current')
        .delete();

    // personalityMeta/current を削除
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('personalityMeta')
        .doc('current')
        .delete();

    // personalitySignals サブコレクションを全削除
    final signalsQuery = await _firestore
        .collection('users')
        .doc(userId)
        .collection('personalitySignals')
        .get();
    final batch = _firestore.batch();
    for (final doc in signalsQuery.docs) {
      batch.delete(doc.reference);
    }
    if (signalsQuery.docs.isNotEmpty) {
      await batch.commit();
    }

    // growthStage を0にリセット
    await _firestore
        .collection('users')
        .doc(userId)
        .update({'growthStage': 0});
  }
}
