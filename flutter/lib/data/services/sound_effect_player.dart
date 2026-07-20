import 'package:just_audio/just_audio.dart';

/// 短い効果音（SE）を鳴らす専用プレーヤー。
///
/// BGM（[BGMPlayer]）やキャラクター音声（[AudioService]）とは別インスタンスなので、
/// BGMを止めずに効果音を一度だけ重ねて再生できる。ミュート判定は呼び出し側が
/// [play] に渡す `volume`（0以下なら鳴らさない）で制御する。
class SoundEffectPlayer {
  static final SoundEffectPlayer shared = SoundEffectPlayer._();
  SoundEffectPlayer._();

  final AudioPlayer _player = AudioPlayer();
  String? _loadedAsset;

  Future<void> _ensureLoaded(String assetPath) async {
    if (_loadedAsset == assetPath) return;
    await _player.setAsset(assetPath);
    _loadedAsset = assetPath;
  }

  /// アセットの効果音を先読みしておく（初回再生の遅延を防ぐ）。失敗しても無視。
  Future<void> preload(String assetPath) async {
    try {
      await _ensureLoaded(assetPath);
    } catch (_) {
      // 先読み失敗は致命的でないため握りつぶす
    }
  }

  /// 効果音を頭から一度だけ再生する。`volume` が0以下なら鳴らさない（ミュート相当）。
  Future<void> play(String assetPath, {double volume = 1.0}) async {
    if (volume <= 0) return;
    try {
      await _ensureLoaded(assetPath);
      await _player.setVolume(volume.clamp(0.0, 1.0));
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (_) {
      // 再生失敗は無視（演出の主役は視覚のため）
    }
  }
}
