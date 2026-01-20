import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/character_model.dart';

/// キャラクターデータソース
class CharacterDatasource {
  final FirebaseFirestore _firestore;

  CharacterDatasource({required FirebaseFirestore firestore}) : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _charactersCollection =>
      _firestore.collection('characters');

  /// 全キャラクターを取得（ストリーム）
  Stream<List<CharacterModel>> watchCharacters() {
    return _charactersCollection
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CharacterModel.fromFirestore(doc))
            .toList());
  }

  /// 特定のキャラクターを取得（ストリーム）
  Stream<CharacterModel?> watchCharacter(String characterId) {
    return _charactersCollection.doc(characterId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CharacterModel.fromFirestore(doc);
    });
  }

  /// 特定のキャラクターを取得（単発）
  Future<CharacterModel?> getCharacter(String characterId) async {
    final doc = await _charactersCollection.doc(characterId).get();
    if (!doc.exists) return null;
    return CharacterModel.fromFirestore(doc);
  }

  /// キャラクターを作成
  Future<String> createCharacter(CharacterModel character) async {
    final docRef = await _charactersCollection.add(character.toMap());
    return docRef.id;
  }

  /// キャラクターを更新
  Future<void> updateCharacter(CharacterModel character) async {
    await _charactersCollection.doc(character.id).update(character.toMap());
  }

  /// キャラクターを削除
  Future<void> deleteCharacter(String characterId) async {
    await _charactersCollection.doc(characterId).delete();
  }
}
