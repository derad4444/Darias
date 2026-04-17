import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BGMプレーヤー
class BGMPlayer {
  static final BGMPlayer shared = BGMPlayer._();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  /// Web自動再生ポリシーによる再生待ちアセットパス
  String? _pendingAssetPath;

  BGMPlayer._();

  /// BGMを再生
  Future<void> playBGM(String assetPath) async {
    try {
      // アセットから音源をロード
      await _audioPlayer.setAsset(assetPath);

      // 無限ループ設定
      await _audioPlayer.setLoopMode(LoopMode.all);

      // ミュート状態と音量をSharedPreferencesから読み取って適用
      final prefs = await SharedPreferences.getInstance();
      final isMuted = prefs.getBool('bgmMuted') ?? false;

      if (isMuted) {
        // ミュート状態の場合は音量0
        await _audioPlayer.setVolume(0);
      } else {
        // ミュート解除の場合は保存された音量を使用
        final savedVolume = prefs.getDouble('bgmVolume') ?? 0.5;
        await _audioPlayer.setVolume(savedVolume);
      }

      await _audioPlayer.play();
      _isInitialized = true;
      _pendingAssetPath = null;
      debugPrint('🎵 BGM再生開始: $assetPath');
    } catch (e) {
      // Web自動再生ポリシーによるブロックの場合、ユーザー操作後に再試行するためパスを保持
      if (kIsWeb) {
        _pendingAssetPath = assetPath;
      }
      debugPrint('❌ BGM再生失敗: $e');
    }
  }

  /// ユーザー操作後にWeb自動再生ポリシーで保留中のBGMを再生する
  Future<void> resumeIfPending() async {
    if (!kIsWeb) return;
    final path = _pendingAssetPath;
    if (path == null) return;
    await playBGM(path);
  }

  /// URLからBGMを再生
  Future<void> playBGMFromUrl(String url) async {
    try {
      await _audioPlayer.setUrl(url);
      await _audioPlayer.setLoopMode(LoopMode.all);

      final prefs = await SharedPreferences.getInstance();
      final isMuted = prefs.getBool('bgmMuted') ?? false;

      if (isMuted) {
        await _audioPlayer.setVolume(0);
      } else {
        final savedVolume = prefs.getDouble('bgmVolume') ?? 0.5;
        await _audioPlayer.setVolume(savedVolume);
      }

      await _audioPlayer.play();
      _isInitialized = true;
      debugPrint('🎵 BGM再生開始（URL）: $url');
    } catch (e) {
      debugPrint('❌ BGM再生失敗: $e');
    }
  }

  /// 音量を更新
  Future<void> updateVolume(double volume) async {
    await _audioPlayer.setVolume(volume);
    debugPrint('🔊 BGM音量更新: $volume');
  }

  /// ミュート設定
  Future<void> setMuted(bool muted) async {
    if (muted) {
      await _audioPlayer.setVolume(0);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final savedVolume = prefs.getDouble('bgmVolume') ?? 0.5;
      await _audioPlayer.setVolume(savedVolume);
    }
    debugPrint('🔇 BGMミュート: $muted');
  }

  /// BGMを一時停止
  Future<void> pauseBGM() async {
    await _audioPlayer.pause();
    debugPrint('⏸️ BGM一時停止');
  }

  /// BGMを再開
  Future<void> resumeBGM() async {
    await _audioPlayer.play();
    debugPrint('▶️ BGM再開');
  }

  /// BGMを停止
  Future<void> stopBGM() async {
    await _audioPlayer.stop();
    debugPrint('⏹️ BGM停止');
  }

  /// 現在再生中かどうか
  bool get isPlaying => _audioPlayer.playing;

  /// 初期化済みかどうか
  bool get isInitialized => _isInitialized;

  /// 現在の音量
  double get volume => _audioPlayer.volume;

  /// リソースを解放
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
