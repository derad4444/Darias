import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

/// リワード広告の状態
enum RewardedAdState {
  loading,
  ready,
  showing,
  error,
}

/// リワード広告マネージャー
class RewardedAdManager {
  RewardedAd? _rewardedAd;
  RewardedAdState _state = RewardedAdState.error;
  String? _adUnitId;

  // コールバック
  Function()? onAdLoaded;
  Function(String error)? onAdFailedToLoad;
  Function()? onAdShowed;
  Function()? onAdDismissed;
  Function(RewardItem reward)? onUserEarnedReward;

  RewardedAdManager({String? adUnitId}) {
    _adUnitId = adUnitId ?? AdConfig.rewardedAdUnitId;
  }

  /// 広告の状態
  RewardedAdState get state => _state;

  /// 広告が準備できているか
  bool get isReady => _state == RewardedAdState.ready;

  /// 広告を読み込む
  Future<void> loadAd() async {
    // Webプラットフォームでは読み込まない
    if (kIsWeb) {
      print('⚠️ RewardedAdManager: Not available on web');
      return;
    }

    if (_state == RewardedAdState.loading) return;

    _state = RewardedAdState.loading;
    print('🔄 RewardedAdManager: Loading ad...');

    await RewardedAd.load(
      adUnitId: _adUnitId!,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print('✅ RewardedAdManager: Ad loaded');
          _rewardedAd = ad;
          _state = RewardedAdState.ready;
          _setupFullScreenCallbacks();
          onAdLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          print('❌ RewardedAdManager: Failed to load - ${error.message}');
          _state = RewardedAdState.error;
          onAdFailedToLoad?.call(error.message);
        },
      ),
    );
  }

  /// フルスクリーンコールバックを設定
  void _setupFullScreenCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        print('📱 RewardedAdManager: Ad showed');
        _state = RewardedAdState.showing;
        onAdShowed?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        print('📱 RewardedAdManager: Ad dismissed');
        ad.dispose();
        _rewardedAd = null;
        _state = RewardedAdState.loading;
        onAdDismissed?.call();
        // 次の広告を事前に読み込み
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('❌ RewardedAdManager: Failed to show - ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        _state = RewardedAdState.error;
        // 再読み込み
        loadAd();
      },
    );
  }

  /// 広告を表示
  Future<bool> showAd() async {
    if (kIsWeb) {
      print('⚠️ RewardedAdManager: Not available on web');
      return false;
    }

    if (!isReady || _rewardedAd == null) {
      print('⚠️ RewardedAdManager: Ad not ready, loading...');
      loadAd();
      return false;
    }

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          print('🎁 RewardedAdManager: User earned reward - ${reward.amount} ${reward.type}');
          onUserEarnedReward?.call(reward);
        },
      );
      return true;
    } catch (e) {
      print('❌ RewardedAdManager: Error showing ad - $e');
      return false;
    }
  }

  /// 広告を表示し、リワード獲得またはアンフィル時にtrueを返す
  /// ユーザーが広告をスキップした場合のみfalseを返す
  Future<bool> showAndAwaitReward() async {
    if (kIsWeb) return true;

    // ロード済みでなければ読み込む（既にloading中なら待たずアンフィル扱い）
    if (!isReady && _state != RewardedAdState.loading) {
      await loadAd();
    }

    // アンフィル → 通す
    if (_rewardedAd == null) return true;

    final completer = Completer<bool>();
    bool rewarded = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _state = RewardedAdState.showing;
        onAdShowed?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _state = RewardedAdState.loading;
        onAdDismissed?.call();
        loadAd();
        if (!completer.isCompleted) completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _state = RewardedAdState.error;
        loadAd();
        if (!completer.isCompleted) completer.complete(true);
      },
    );

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          rewarded = true;
          onUserEarnedReward?.call(reward);
        },
      );
    } catch (e) {
      print('❌ RewardedAdManager: Error in showAndAwaitReward - $e');
      return true;
    }

    return completer.future;
  }

  /// リソースを解放
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
