import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// キャラクター音声再生サービス
class AudioService {
  static final AudioService shared = AudioService._();

  final AudioPlayer _voicePlayer = AudioPlayer();
  bool _isPlaying = false;

  AudioService._();

  /// URLから音声を再生
  Future<void> playVoice({
    required String url,
    double? volume,
  }) async {
    try {
      // 既に再生中の場合は停止
      if (_isPlaying) {
        await _voicePlayer.stop();
      }

      await _voicePlayer.setUrl(url);

      // SharedPreferencesからキャラクター音量を読み取って適用
      final prefs = await SharedPreferences.getInstance();
      final isMuted = prefs.getBool('characterMuted') ?? false;

      if (isMuted) {
        await _voicePlayer.setVolume(0);
      } else {
        final savedVolume = prefs.getDouble('characterVolume') ?? 0.8;
        final finalVolume = volume ?? savedVolume;
        await _voicePlayer.setVolume(finalVolume);
      }

      _isPlaying = true;
      await _voicePlayer.play();

      // 再生完了を監視
      _voicePlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
        }
      });

      debugPrint('🔊 音声再生開始: $url');
    } catch (e) {
      _isPlaying = false;
      debugPrint('❌ 音声再生失敗: $e');
    }
  }

  /// アセットから音声を再生
  Future<void> playVoiceFromAsset({
    required String assetPath,
    double? volume,
  }) async {
    try {
      if (_isPlaying) {
        await _voicePlayer.stop();
      }

      await _voicePlayer.setAsset(assetPath);

      final prefs = await SharedPreferences.getInstance();
      final isMuted = prefs.getBool('characterMuted') ?? false;

      if (isMuted) {
        await _voicePlayer.setVolume(0);
      } else {
        final savedVolume = prefs.getDouble('characterVolume') ?? 0.8;
        final finalVolume = volume ?? savedVolume;
        await _voicePlayer.setVolume(finalVolume);
      }

      _isPlaying = true;
      await _voicePlayer.play();

      _voicePlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
        }
      });

      debugPrint('🔊 音声再生開始（アセット）: $assetPath');
    } catch (e) {
      _isPlaying = false;
      debugPrint('❌ 音声再生失敗: $e');
    }
  }

  /// 音量を更新
  Future<void> updateVolume(double volume) async {
    await _voicePlayer.setVolume(volume);
    debugPrint('🔊 音声音量更新: $volume');
  }

  /// ミュート設定
  Future<void> setMuted(bool muted) async {
    if (muted) {
      await _voicePlayer.setVolume(0);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final savedVolume = prefs.getDouble('characterVolume') ?? 0.8;
      await _voicePlayer.setVolume(savedVolume);
    }
    debugPrint('🔇 音声ミュート: $muted');
  }

  /// 音声を停止
  Future<void> stopVoice() async {
    await _voicePlayer.stop();
    _isPlaying = false;
    debugPrint('⏹️ 音声停止');
  }

  /// 現在再生中かどうか
  bool get isPlaying => _isPlaying;

  /// 現在の音量
  double get volume => _voicePlayer.volume;

  /// リソースを解放
  Future<void> dispose() async {
    await _voicePlayer.dispose();
  }
}
