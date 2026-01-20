import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/services/audio_service.dart';
import '../../../data/services/bgm_player.dart';

/// 音量設定プロバイダー
final volumeSettingsProvider =
    StateNotifierProvider<VolumeSettingsNotifier, VolumeSettings>((ref) {
  return VolumeSettingsNotifier();
});

class VolumeSettings {
  final double bgmVolume;
  final double characterVolume;
  final bool bgmMuted;
  final bool characterMuted;

  const VolumeSettings({
    this.bgmVolume = 0.5,
    this.characterVolume = 0.8,
    this.bgmMuted = false,
    this.characterMuted = false,
  });

  VolumeSettings copyWith({
    double? bgmVolume,
    double? characterVolume,
    bool? bgmMuted,
    bool? characterMuted,
  }) {
    return VolumeSettings(
      bgmVolume: bgmVolume ?? this.bgmVolume,
      characterVolume: characterVolume ?? this.characterVolume,
      bgmMuted: bgmMuted ?? this.bgmMuted,
      characterMuted: characterMuted ?? this.characterMuted,
    );
  }
}

class VolumeSettingsNotifier extends StateNotifier<VolumeSettings> {
  VolumeSettingsNotifier() : super(const VolumeSettings()) {
    _load();
  }

  double _bgmVolumeBeforeMute = 0.5;
  double _characterVolumeBeforeMute = 0.8;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = VolumeSettings(
      bgmVolume: prefs.getDouble('bgmVolume') ?? 0.5,
      characterVolume: prefs.getDouble('characterVolume') ?? 0.8,
      bgmMuted: prefs.getBool('bgmMuted') ?? false,
      characterMuted: prefs.getBool('characterMuted') ?? false,
    );
    _bgmVolumeBeforeMute = prefs.getDouble('bgmVolumeBeforeMute') ?? 0.5;
    _characterVolumeBeforeMute =
        prefs.getDouble('characterVolumeBeforeMute') ?? 0.8;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bgmVolume', state.bgmVolume);
    await prefs.setDouble('characterVolume', state.characterVolume);
    await prefs.setBool('bgmMuted', state.bgmMuted);
    await prefs.setBool('characterMuted', state.characterMuted);
    await prefs.setDouble('bgmVolumeBeforeMute', _bgmVolumeBeforeMute);
    await prefs.setDouble(
        'characterVolumeBeforeMute', _characterVolumeBeforeMute);
  }

  void setBgmVolume(double volume) {
    state = state.copyWith(bgmVolume: volume);
    if (!state.bgmMuted) {
      _bgmVolumeBeforeMute = volume;
    }
    // 実際のBGM音量を更新
    BGMPlayer.shared.updateVolume(volume);
    _save();
  }

  void setCharacterVolume(double volume) {
    state = state.copyWith(characterVolume: volume);
    if (!state.characterMuted) {
      _characterVolumeBeforeMute = volume;
    }
    // 実際のキャラクター音声音量を更新
    AudioService.shared.updateVolume(volume);
    _save();
  }

  void toggleBgmMute() {
    if (state.bgmMuted) {
      state = state.copyWith(
        bgmMuted: false,
        bgmVolume: _bgmVolumeBeforeMute,
      );
      BGMPlayer.shared.setMuted(false);
    } else {
      _bgmVolumeBeforeMute = state.bgmVolume;
      state = state.copyWith(
        bgmMuted: true,
        bgmVolume: 0,
      );
      BGMPlayer.shared.setMuted(true);
    }
    _save();
  }

  void toggleCharacterMute() {
    if (state.characterMuted) {
      state = state.copyWith(
        characterMuted: false,
        characterVolume: _characterVolumeBeforeMute,
      );
      AudioService.shared.setMuted(false);
    } else {
      _characterVolumeBeforeMute = state.characterVolume;
      state = state.copyWith(
        characterMuted: true,
        characterVolume: 0,
      );
      AudioService.shared.setMuted(true);
    }
    _save();
  }
}

/// 音量設定画面
class VolumeSettingsScreen extends ConsumerWidget {
  const VolumeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(volumeSettingsProvider);
    final notifier = ref.read(volumeSettingsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('音量設定'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // BGM音量
          _VolumeSection(
            icon: Icons.music_note,
            title: 'BGM音量',
            volume: settings.bgmVolume,
            isMuted: settings.bgmMuted,
            onVolumeChanged: (value) => notifier.setBgmVolume(value),
            onMuteToggle: () => notifier.toggleBgmMute(),
          ),
          const SizedBox(height: 20),

          // キャラクター音声
          _VolumeSection(
            icon: Icons.record_voice_over,
            title: 'キャラクター音声',
            volume: settings.characterVolume,
            isMuted: settings.characterMuted,
            onVolumeChanged: (value) => notifier.setCharacterVolume(value),
            onMuteToggle: () => notifier.toggleCharacterMute(),
          ),
          const SizedBox(height: 32),

          // 説明セクション
          _InfoSection(),
        ],
      ),
    );
  }
}

class _VolumeSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final double volume;
  final bool isMuted;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onMuteToggle;

  const _VolumeSection({
    required this.icon,
    required this.title,
    required this.volume,
    required this.isMuted,
    required this.onVolumeChanged,
    required this.onMuteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMuted
              ? Colors.red.withValues(alpha: 0.3)
              : colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              // ミュートボタン
              IconButton(
                onPressed: onMuteToggle,
                icon: Icon(
                  isMuted ? Icons.volume_off : Icons.volume_up,
                  color: isMuted ? Colors.red : colorScheme.primary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isMuted
                      ? Colors.red.withValues(alpha: 0.1)
                      : colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isMuted ? '0%' : '${(volume * 100).toInt()}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isMuted ? Colors.grey : colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.volume_mute, size: 18),
              Expanded(
                child: Slider(
                  value: volume,
                  onChanged: isMuted ? null : onVolumeChanged,
                  activeColor: colorScheme.primary,
                  inactiveColor: colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              const Icon(Icons.volume_up, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '音量について',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoText('BGM音量：アプリ内で流れる背景音楽の音量を調整します'),
          _InfoText('キャラクター音声：キャラクターの音声の音量を調整します'),
          _InfoText('音量は0%〜100%の範囲で設定できます'),
          _InfoText('ミュートボタンをタップすると、ワンタップで消音/解除できます'),
        ],
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  final String text;

  const _InfoText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
