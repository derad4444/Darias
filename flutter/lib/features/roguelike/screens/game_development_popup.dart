import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/providers/theme_provider.dart';

/// 冒険（ゲーム）タブに重ねて表示する「開発中」ポップアップ。
///
/// 手帳タブのアンケートポップアップと同じ様式（半透明の背景＋中央カード、テーマ色）。
/// 背景がすべてのポインタ操作を吸収するため、ゲームはプレイできない（他タブへは移動可）。
/// 公開時はこのウィジェットの表示（[MainShellScreen] のタブ3の Stack 重ね）を外すだけでよい。
class GameDevelopmentPopup extends ConsumerWidget {
  const GameDevelopmentPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = ref.watch(accentColorProvider);
    final textColor = ref.watch(colorSettingsProvider).textColor;
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final textSoft = textColor.withValues(alpha: 0.7);

    return Stack(
      children: [
        // 背景（ゲームを暗くし、すべての操作を吸収してプレイ不可にする）
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
          ),
        ),
        // 中央のポップアップカード
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.fromLTRB(32, 44, 32, 40),
                decoration: BoxDecoration(
                  gradient: backgroundGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.videogame_asset_outlined, color: accentColor, size: 52),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      '冒険モードは開発中です',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: textColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '性格診断を活かした新しいゲーム機能を開発中です。\n'
                      '公開まで、いましばらくお待ちください。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16.5, height: 1.7, color: textColor.withValues(alpha: 0.9)),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'ホーム・手帳など他のタブはご利用いただけます',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: textSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
