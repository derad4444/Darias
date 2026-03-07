import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'audio_service.dart';

/// キャラクター音声生成・再生サービス
class VoiceService {
  static final VoiceService shared = VoiceService._();
  VoiceService._();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  /// テキストを音声に変換して再生する
  /// [text] キャラクターの返答テキスト
  /// [gender] キャラクターの性別 ('男性' or '女性')
  /// [onError] エラー時のコールバック
  Future<void> generateAndPlay({
    required String text,
    required String gender,
    void Function(String)? onError,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateVoice');
      final result = await callable.call({
        'text': text,
        'gender': gender == '男性' ? 'male' : 'female',
      });

      final voiceUrl = result.data['voiceUrl'] as String?;
      if (voiceUrl == null || voiceUrl.isEmpty) {
        onError?.call('音声URLが取得できませんでした');
        return;
      }

      await AudioService.shared.playVoice(url: voiceUrl);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ VoiceService: ${e.code} - ${e.message}');
      onError?.call('音声生成に失敗しました');
    } catch (e) {
      debugPrint('❌ VoiceService: $e');
      onError?.call('音声生成に失敗しました');
    }
  }

  /// 再生を停止する
  Future<void> stop() => AudioService.shared.stopVoice();

  /// 再生中かどうか
  bool get isPlaying => AudioService.shared.isPlaying;
}
