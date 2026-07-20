import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ad_provider.dart';
import 'banner_ad_widget.dart';

/// 画面の上下に置く、ゲート付きバナー広告。
/// プレミアムユーザー（`shouldShowBannerAdProvider` が false）や Web では非表示。
/// [adUnitId] に画面ごとの上部/下部ユニットを渡す（同一画面で上下は別ユニットにする）。
class ScreenBanner extends ConsumerWidget {
  final String adUnitId;
  const ScreenBanner({super.key, required this.adUnitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(shouldShowBannerAdProvider)) return const SizedBox.shrink();
    return BannerAdContainer(
      adUnitId: adUnitId,
      padding: const EdgeInsets.symmetric(vertical: 6),
    );
  }
}
