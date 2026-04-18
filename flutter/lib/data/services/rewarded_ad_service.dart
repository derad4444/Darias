import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

class RewardedAdService {
  RewardedAd? _ad;

  /// 広告をプリロード
  Future<void> load() async {
    if (kIsWeb) return;
    final completer = Completer<void>();
    await RewardedAd.load(
      adUnitId: AdConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          debugPrint('RewardedAd: failed to load: $error');
          completer.complete(); // アンフィルでも続行
        },
      ),
    );
    return completer.future;
  }

  /// 広告を表示し、リワード獲得またはアンフィル時に true を返す
  /// ユーザーが広告を途中でスキップした場合のみ false を返す
  Future<bool> showAndAwaitReward() async {
    if (kIsWeb) return true;

    // アンフィル時はそのまま通す
    if (_ad == null) return true;

    final completer = Completer<bool>();
    bool rewarded = false;

    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        if (!completer.isCompleted) completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        if (!completer.isCompleted) completer.complete(true); // 表示失敗 → 通す
      },
    );

    await _ad!.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;
      },
    );

    return completer.future;
  }
}
