// features/roguelike/widgets/roguelike_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/ad_service.dart';
import '../../../presentation/providers/ad_provider.dart';
import '../../../presentation/widgets/ads/banner_ad_widget.dart';

/// ローグライク各画面の上下に置くバナー広告。
/// プレミアムユーザー（`shouldShowBannerAdProvider` が false）や Web では非表示。
/// [bottom] で上部/下部の広告ユニットを切り替える（同一画面で別ユニットにする）。
class RoguelikeBanner extends ConsumerWidget {
  final bool bottom;
  const RoguelikeBanner({super.key, this.bottom = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(shouldShowBannerAdProvider)) return const SizedBox.shrink();
    return BannerAdContainer(
      adUnitId: bottom
          ? AdConfig.roguelikeBottomBannerAdUnitId
          : AdConfig.roguelikeTopBannerAdUnitId,
      padding: const EdgeInsets.symmetric(vertical: 6),
    );
  }
}
