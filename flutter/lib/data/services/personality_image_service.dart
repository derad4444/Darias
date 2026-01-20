import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/big5_model.dart';
import 'firebase_image_service.dart';

/// BIG5性格スコアから画像ファイル名を生成するサービス
class PersonalityImageService {
  PersonalityImageService._();

  /// BIG5スコアから画像ファイル名を生成
  /// - Parameters:
  ///   - scores: BIG5スコア（各1-5の範囲）
  ///   - gender: 性別（male/female）
  /// - Returns: 画像ファイル名（例: "Female_HLMHL" または "Male_HLMHL"）
  static String generateImageFileName({
    required Big5Scores scores,
    required CharacterGender gender,
  }) {
    // 1. 各スコアをL/M/Hに変換（OCEANの順番）
    final o = _convertScoreToLevel(scores.openness);
    final c = _convertScoreToLevel(scores.conscientiousness);
    final e = _convertScoreToLevel(scores.extraversion);
    final a = _convertScoreToLevel(scores.agreeableness);
    final n = _convertScoreToLevel(scores.neuroticism);

    // 2. 性別プレフィックスを追加
    final genderPrefix = gender == CharacterGender.female ? 'Female' : 'Male';

    // 3. OCEANの順番で結合してファイル名を生成
    final fileName = '${genderPrefix}_$o$c$e$a$n';

    debugPrint('📸 画像ファイル名生成:');
    debugPrint(
        '   スコア: O=${scores.openness}, C=${scores.conscientiousness}, E=${scores.extraversion}, A=${scores.agreeableness}, N=${scores.neuroticism}');
    debugPrint('   性別: ${gender.value}');
    debugPrint('   変換後: $fileName');

    return fileName;
  }

  /// スコア（1-5）をレベル（L/M/H）に変換
  /// - 1, 2 → L (LOW)
  /// - 3 → M (MID)
  /// - 4, 5 → H (HIGH)
  static String _convertScoreToLevel(double score) {
    if (score <= 2.0) {
      return 'L';
    } else if (score <= 3.0) {
      return 'M';
    } else {
      return 'H';
    }
  }

  /// デフォルト画像ファイル名を取得
  static String getDefaultImageName(CharacterGender gender) {
    return 'character_${gender.value}';
  }

  /// BIG5スコアからFirebase Storageのパスを生成
  static String generateStoragePath({
    required Big5Scores scores,
    required CharacterGender gender,
  }) {
    final fileName = generateImageFileName(scores: scores, gender: gender);
    return 'character-images/${gender.value}/$fileName.png';
  }

  /// ファイル名からFirebase Storageのパスを生成
  static String generateStoragePathFromFileName({
    required String fileName,
    required CharacterGender gender,
  }) {
    return 'character-images/${gender.value}/$fileName.png';
  }

  /// Firebase Storageから画像を取得（非同期）
  static Future<Uint8List> fetchImage({
    required Big5Scores scores,
    required CharacterGender gender,
  }) async {
    final fileName = generateImageFileName(scores: scores, gender: gender);
    return FirebaseImageService.shared.fetchImage(
      fileName: fileName,
      gender: gender,
    );
  }

  /// 画像URLを取得
  static Future<String> getImageUrl({
    required Big5Scores scores,
    required CharacterGender gender,
  }) async {
    final fileName = generateImageFileName(scores: scores, gender: gender);
    return FirebaseImageService.shared.getImageUrl(
      fileName: fileName,
      gender: gender,
    );
  }

  /// 画像を取得（Firebase優先、フォールバックでデフォルト）
  static Future<Uint8List?> fetchImageWithFallback({
    required Big5Scores scores,
    required CharacterGender gender,
  }) async {
    try {
      // Firebase Storageから取得を試みる
      return await fetchImage(scores: scores, gender: gender);
    } catch (e) {
      debugPrint('❌ 画像取得失敗、デフォルトを使用: $e');
      // フォールバック: nullを返してUIでデフォルト画像を表示
      return null;
    }
  }

  /// 画像をプリロード
  static Future<void> preloadImage({
    required Big5Scores scores,
    required CharacterGender gender,
  }) async {
    final fileName = generateImageFileName(scores: scores, gender: gender);
    await FirebaseImageService.shared.preloadImage(
      fileName: fileName,
      gender: gender,
    );
  }

  /// 全パターンの画像ファイル名リストを生成（プリロード用）
  static List<String> generateAllImageFileNames(CharacterGender gender) {
    final levels = ['L', 'M', 'H'];
    final fileNames = <String>[];
    final genderPrefix = gender == CharacterGender.female ? 'Female' : 'Male';

    // 3^5 = 243パターン
    for (final o in levels) {
      for (final c in levels) {
        for (final e in levels) {
          for (final a in levels) {
            for (final n in levels) {
              fileNames.add('${genderPrefix}_$o$c$e$a$n');
            }
          }
        }
      }
    }

    return fileNames;
  }
}
