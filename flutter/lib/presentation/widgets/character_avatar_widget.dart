import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';
import 'character/element_effect_widget.dart' show characterGrowthAssetPath;

/// キャラクターの成長段階画像を丸く切り抜いて表示するアバターウィジェット
class CharacterAvatarWidget extends ConsumerWidget {
  final String userId;
  final double size;
  final String fallbackText;
  final Color fallbackBackgroundColor;
  final Color fallbackTextColor;

  const CharacterAvatarWidget({
    super.key,
    required this.userId,
    required this.size,
    this.fallbackText = '?',
    this.fallbackBackgroundColor = const Color(0xFFE0E0E0),
    this.fallbackTextColor = const Color(0xFF757575),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);

    // 自分のアバター: signalCount をリアルタイム取得
    if (userId == currentUserId) {
      final signalCount = ref.watch(signalCountProvider).valueOrNull ?? 0;
      final detailsAsync = ref.watch(characterDetailsProvider);
      return detailsAsync.when(
        loading: () => _FallbackAvatar(
          size: size,
          text: fallbackText,
          backgroundColor: fallbackBackgroundColor,
          textColor: fallbackTextColor,
        ),
        error: (_, __) => _FallbackAvatar(
          size: size,
          text: fallbackText,
          backgroundColor: fallbackBackgroundColor,
          textColor: fallbackTextColor,
        ),
        data: (details) {
          final assetPath = characterGrowthAssetPath(
            signalCount: signalCount,
            element: details?.element,
            gender: details?.gender,
          );
          return _GrowthAvatarClip(assetPath: assetPath, size: size);
        },
      );
    }

    // フレンドなど他ユーザーのアバター: element の有無で赤ちゃん or 幼少期
    final detailsAsync = ref.watch(userCharacterDetailsProvider(userId));
    return detailsAsync.when(
      loading: () => _FallbackAvatar(
        size: size,
        text: fallbackText,
        backgroundColor: fallbackBackgroundColor,
        textColor: fallbackTextColor,
      ),
      error: (_, __) => _FallbackAvatar(
        size: size,
        text: fallbackText,
        backgroundColor: fallbackBackgroundColor,
        textColor: fallbackTextColor,
      ),
      data: (details) {
        // growthStage が未設定(0)でも element があれば幼少期以上として扱う
        int stage = details?.growthStage ?? 0;
        if (stage == 0 && details?.element != null) stage = 1;
        final stageSignalCount = stage >= 2 ? 100 : stage >= 1 ? 30 : 0;
        final assetPath = characterGrowthAssetPath(
          signalCount: stageSignalCount,
          element: details?.element,
          gender: details?.gender,
        );
        return _GrowthAvatarClip(assetPath: assetPath, size: size);
      },
    );
  }
}

/// 成長ステージ画像を顔中心で円形クリップして表示
/// 1.8倍ズーム＋上部中心で顔〜胸付近を表示
class _GrowthAvatarClip extends StatelessWidget {
  final String assetPath;
  final double size;

  const _GrowthAvatarClip({required this.assetPath, required this.size});

  @override
  Widget build(BuildContext context) {
    final zoomed = size * 1.8;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: OverflowBox(
          maxWidth: zoomed,
          maxHeight: zoomed,
          alignment: Alignment.topCenter,
          child: Image.asset(
            assetPath,
            width: zoomed,
            height: zoomed,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => CircleAvatar(
              radius: size / 2,
              backgroundColor: const Color(0xFFE0E0E0),
              child: Icon(Icons.person, size: size * 0.55, color: const Color(0xFF757575)),
            ),
          ),
        ),
      ),
    );
  }
}

/// フォールバック用シンプルなCircleAvatar
class _FallbackAvatar extends StatelessWidget {
  final double size;
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const _FallbackAvatar({
    required this.size,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor,
      child: text == '__icon_person__'
          ? Icon(Icons.person, color: textColor, size: size * 0.55)
          : Text(
              text,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
    );
  }
}
