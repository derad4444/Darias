import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 広告設定
class AdConfig {
  // テスト用広告ユニットID
  static const String testBannerAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testBannerAdUnitIdIos =
      'ca-app-pub-3940256099942544/2934735716';
  static const String testRewardedAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String testRewardedAdUnitIdIos =
      'ca-app-pub-3940256099942544/1712485313';

  // 本番用広告ユニットID（実際のIDに置き換えてください）
  static const String prodBannerAdUnitIdAndroid = 'YOUR_ANDROID_BANNER_AD_UNIT_ID';
  static const String prodBannerAdUnitIdIos = 'YOUR_IOS_BANNER_AD_UNIT_ID';
  static const String prodRewardedAdUnitIdAndroid =
      'YOUR_ANDROID_REWARDED_AD_UNIT_ID';
  static const String prodRewardedAdUnitIdIos = 'YOUR_IOS_REWARDED_AD_UNIT_ID';

  // テストモードかどうか
  static const bool isTestMode = true;

  /// バナー広告ユニットIDを取得
  static String get bannerAdUnitId {
    if (isTestMode) {
      return Platform.isAndroid
          ? testBannerAdUnitIdAndroid
          : testBannerAdUnitIdIos;
    }
    return Platform.isAndroid
        ? prodBannerAdUnitIdAndroid
        : prodBannerAdUnitIdIos;
  }

  /// リワード広告ユニットIDを取得
  static String get rewardedAdUnitId {
    if (isTestMode) {
      return Platform.isAndroid
          ? testRewardedAdUnitIdAndroid
          : testRewardedAdUnitIdIos;
    }
    return Platform.isAndroid
        ? prodRewardedAdUnitIdAndroid
        : prodRewardedAdUnitIdIos;
  }
}

/// 広告サービス
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _isInitialized = false;

  /// 広告SDKを初期化
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      print('✅ AdService: Initialized successfully');
    } catch (e) {
      print('❌ AdService: Failed to initialize - $e');
    }
  }

  /// 初期化済みかどうか
  bool get isInitialized => _isInitialized;

  /// テストデバイスIDを設定（開発時に使用）
  Future<void> setTestDeviceIds(List<String> deviceIds) async {
    final config = RequestConfiguration(testDeviceIds: deviceIds);
    await MobileAds.instance.updateRequestConfiguration(config);
  }
}
