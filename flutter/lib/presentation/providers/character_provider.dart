import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/remote/character_datasource.dart';
import '../../data/models/character_model.dart';
import '../../data/services/firebase_image_service.dart' as firebase_image;
import 'auth_provider.dart';

/// CharacterDatasourceのプロバイダー
final characterDatasourceProvider = Provider<CharacterDatasource>((ref) {
  return CharacterDatasource(firestore: ref.watch(firestoreProvider));
});

/// 全キャラクターリストのプロバイダー
final charactersProvider = StreamProvider<List<CharacterModel>>((ref) {
  final datasource = ref.watch(characterDatasourceProvider);
  return datasource.watchCharacters();
});

/// 特定のキャラクターのプロバイダー
final characterProvider = StreamProvider.family<CharacterModel?, String>((ref, characterId) {
  final datasource = ref.watch(characterDatasourceProvider);
  return datasource.watchCharacter(characterId);
});

/// 現在選択中のキャラクターのプロバイダー
final currentCharacterProvider = StreamProvider<CharacterModel?>((ref) {
  final user = ref.watch(userDocProvider).valueOrNull;
  final characterId = user?.characterId;

  if (characterId == null) {
    return Stream.value(null);
  }

  final datasource = ref.watch(characterDatasourceProvider);
  return datasource.watchCharacter(characterId);
});

/// キャラクター選択コントローラー
class CharacterController extends StateNotifier<AsyncValue<void>> {
  final CharacterDatasource _datasource;
  final Ref _ref;

  CharacterController(this._datasource, this._ref) : super(const AsyncValue.data(null));

  /// キャラクターを選択
  Future<void> selectCharacter(String characterId) async {
    state = const AsyncValue.loading();
    try {
      final userId = _ref.read(currentUserIdProvider);
      if (userId == null) throw Exception('User not logged in');

      // ユーザードキュメントのcharacterIdを更新
      await _ref.read(firestoreProvider)
          .collection('users')
          .doc(userId)
          .update({'characterId': characterId});

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// キャラクターコントローラーのプロバイダー
final characterControllerProvider =
    StateNotifierProvider<CharacterController, AsyncValue<void>>((ref) {
  return CharacterController(
    ref.watch(characterDatasourceProvider),
    ref,
  );
});

/// 現在のキャラクターIDのプロバイダー
final currentCharacterIdProvider = Provider<String?>((ref) {
  final user = ref.watch(userDocProvider).valueOrNull;
  return user?.characterId;
});

/// キャラクター詳細データ
class CharacterDetails {
  final String gender;
  final Map<String, double>? confirmedBig5Scores;
  final String? personalityKey;
  final int analysisLevel;
  final int points;

  CharacterDetails({
    required this.gender,
    this.confirmedBig5Scores,
    this.personalityKey,
    this.analysisLevel = 0,
    this.points = 0,
  });

  factory CharacterDetails.fromMap(Map<String, dynamic> data) {
    Map<String, double>? scores;
    final scoresMap = data['confirmedBig5Scores'] as Map<String, dynamic>?;
    if (scoresMap != null) {
      scores = {
        'openness': (scoresMap['openness'] as num?)?.toDouble() ?? 3.0,
        'conscientiousness': (scoresMap['conscientiousness'] as num?)?.toDouble() ?? 3.0,
        'extraversion': (scoresMap['extraversion'] as num?)?.toDouble() ?? 3.0,
        'agreeableness': (scoresMap['agreeableness'] as num?)?.toDouble() ?? 3.0,
        'neuroticism': (scoresMap['neuroticism'] as num?)?.toDouble() ?? 3.0,
      };
    }

    return CharacterDetails(
      gender: data['gender'] as String? ?? '女性',
      confirmedBig5Scores: scores,
      personalityKey: data['personalityKey'] as String?,
      analysisLevel: (data['analysis_level'] as num?)?.toInt() ?? 0,
      points: (data['points'] as num?)?.toInt() ?? 0,
    );
  }

  /// スコアをL/M/Hに変換（iOS版PersonalityImageServiceと同じロジック）
  String _scoreToLevel(double score) {
    if (score <= 2.0) return 'L';
    if (score <= 3.0) return 'M';
    return 'H';
  }

  /// 性格に基づいた画像ファイル名を生成（性別プレフィックス付き）
  /// 未診断（analysisLevel == 0）の場合はnullを返す（iOS版と同じ挙動）
  String? get personalityImageFileName {
    if (analysisLevel == 0 || confirmedBig5Scores == null) return null;

    final o = _scoreToLevel(confirmedBig5Scores!['openness'] ?? 3.0);
    final c = _scoreToLevel(confirmedBig5Scores!['conscientiousness'] ?? 3.0);
    final e = _scoreToLevel(confirmedBig5Scores!['extraversion'] ?? 3.0);
    final a = _scoreToLevel(confirmedBig5Scores!['agreeableness'] ?? 3.0);
    final n = _scoreToLevel(confirmedBig5Scores!['neuroticism'] ?? 3.0);

    final genderPrefix = gender == '男性' ? 'Male' : 'Female';
    return '${genderPrefix}_$o$c$e$a$n';
  }

  /// FirebaseImageService用のファイル名を取得（OCAENパターンのみ）
  /// 未診断の場合はnullを返す
  String? getPersonalityImageFileName() {
    if (analysisLevel == 0 || confirmedBig5Scores == null) return null;

    final o = _scoreToLevel(confirmedBig5Scores!['openness'] ?? 3.0);
    final c = _scoreToLevel(confirmedBig5Scores!['conscientiousness'] ?? 3.0);
    final e = _scoreToLevel(confirmedBig5Scores!['extraversion'] ?? 3.0);
    final a = _scoreToLevel(confirmedBig5Scores!['agreeableness'] ?? 3.0);
    final n = _scoreToLevel(confirmedBig5Scores!['neuroticism'] ?? 3.0);

    return '$o$c$e$a$n';
  }
}

/// キャラクター詳細のストリームプロバイダー
final characterDetailsProvider = StreamProvider<CharacterDetails?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final characterId = ref.watch(currentCharacterIdProvider);

  if (userId == null || characterId == null) {
    return Stream.value(null);
  }

  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection('users')
      .doc(userId)
      .collection('characters')
      .doc(characterId)
      .collection('details')
      .doc('current')
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    return CharacterDetails.fromMap(doc.data()!);
  });
});

/// 任意のユーザーのキャラクター詳細をFirestoreから取得するプロバイダー
/// keepAlive: true でアプリ起動中はキャッシュを保持し、再取得を防ぐ
final userCharacterDetailsProvider =
    FutureProvider.family<CharacterDetails?, String>((ref, userId) async {
  ref.keepAlive();

  if (userId.isEmpty) {
    debugPrint('🎭 userCharacterDetailsProvider: userId is empty, skip');
    return null;
  }
  debugPrint('🎭 userCharacterDetailsProvider: fetching for userId=$userId');

  final firestore = ref.read(firestoreProvider);

  try {
    // ユーザードキュメントからcharacterIdを取得
    final userDoc = await firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      debugPrint('🎭 userCharacterDetailsProvider: userDoc not found for $userId');
      return null;
    }
    final characterId = userDoc.data()?['character_id'] as String?;
    debugPrint('🎭 userCharacterDetailsProvider: characterId=$characterId');
    if (characterId == null || characterId.isEmpty) return null;

    // キャラクター詳細を取得
    final detailsDoc = await firestore
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('details')
        .doc('current')
        .get();

    if (!detailsDoc.exists || detailsDoc.data() == null) {
      debugPrint('🎭 userCharacterDetailsProvider: detailsDoc not found');
      return null;
    }
    final details = CharacterDetails.fromMap(detailsDoc.data()!);
    debugPrint('🎭 userCharacterDetailsProvider: analysisLevel=${details.analysisLevel}, fileName=${details.personalityImageFileName}');
    return details;
  } catch (e) {
    debugPrint('🎭 userCharacterDetailsProvider: error - $e');
    return null;
  }
});

/// キャラクター画像URLのプロバイダー
final characterImageProvider = FutureProvider<String?>((ref) async {
  final details = ref.watch(characterDetailsProvider).valueOrNull;
  if (details == null) return null;

  // 性別を取得
  final gender = details.gender == '男性'
      ? firebase_image.CharacterGender.male
      : firebase_image.CharacterGender.female;

  // 未診断の場合はnullを返す（呼び出し元でローカルアセットを使用）
  final pattern = details.getPersonalityImageFileName();
  if (pattern == null) return null;

  // iOS版と同じ形式でファイル名を生成（性別プレフィックス付き）
  // 例: "Female_HLMHL"
  final genderPrefix = details.gender == '男性' ? 'Male' : 'Female';
  final fileName = '${genderPrefix}_$pattern';

  debugPrint('📸 キャラクター画像取得: fileName=$fileName, gender=${gender.value}');

  try {
    final url = await firebase_image.FirebaseImageService.shared.getImageUrl(
      fileName: fileName,
      gender: gender,
    );
    debugPrint('✅ 画像URL取得成功: $url');
    return url;
  } catch (e) {
    debugPrint('❌ 画像URL取得失敗: $e');
    return null;
  }
});
