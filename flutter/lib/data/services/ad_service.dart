import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 広告設定（iOS版Config.swiftと対応）
class AdConfig {
  // ─── テスト用広告ユニットID ───────────────────────────────
  static const String _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';

  // テストモードかどうか（リリース時は false に変更）
  static const bool isTestMode = false;

  // ─── 内部ヘルパー ─────────────────────────────────────────
  /// iOS本番IDを返す。テストモード時はGoogle提供のテストIDを返す。
  /// Android本番IDは別途AdMobコンソールで取得してください。
  static String _banner({required String iosId, String? androidId}) {
    if (kIsWeb) return '';
    if (isTestMode) {
      return Platform.isAndroid ? _testBannerAndroid : _testBannerIos;
    }
    if (Platform.isAndroid) return androidId ?? 'YOUR_ANDROID_BANNER_AD_UNIT_ID';
    return iosId;
  }

  // ─── バナー広告ユニットID ─────────────────────────────────
  // iOS本番IDはConfig.swiftと同一値を使用

  /// ホーム画面バナー
  static String get homeScreenBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/8287132245');

  /// 設定画面上部バナー
  static String get settingsTopBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/5497209577');

  /// 設定画面下部バナー
  static String get settingsBottomBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/3362000823');

  /// カレンダー画面バナー
  static String get calendarScreenBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/2539873743');

  /// 予定詳細画面バナー
  static String get scheduleDetailBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/8127350145');

  /// 予定編集画面上部バナー
  static String get scheduleEditTopBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/1805376571');

  /// 予定編集画面下部バナー
  static String get scheduleEditBottomBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/2670191098');

  /// 予定追加画面上部バナー
  static String get scheduleAddTopBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/6566748666');

  /// 予定追加画面下部バナー
  static String get scheduleAddBottomBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/3034805563');

  /// チャット履歴画面バナー
  static String get chatHistoryBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/3683889865');

  /// キャラクター詳細画面上部バナー
  static String get characterDetailTopBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/2370808193');

  /// キャラクター詳細画面下部バナー
  static String get characterDetailBottomBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/5501186800');

  /// 日記詳細画面上部バナー
  static String get diaryDetailTopBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/1226792077');

  /// 日記詳細画面下部バナー
  static String get diaryDetailBottomBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/1046936476');

  /// メモ画面上部バナー
  static String get memoTopBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/8134270760');

  /// メモ画面下部バナー
  static String get memoBottomBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/6730400193');

  /// タスク画面上部バナー
  static String get taskTopBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/4442437769');

  /// タスク画面下部バナー
  static String get taskBottomBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/9412511653');

  /// メモ追加画面上部バナー
  static String get memoAddTopBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/5138116921');

  /// メモ追加画面下部バナー
  static String get memoAddBottomBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/6754558720');

  /// タスク追加画面上部バナー
  static String get taskAddTopBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/5441477059');

  /// タスク追加画面下部バナー
  static String get taskAddBottomBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/7106968080');

  /// 会議画面バナー
  static String get meetingScreenBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/4592485389');

  /// 予定一覧画面バナー
  static String get scheduleListBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/9018815555');

  /// 会議履歴画面バナー
  static String get meetingHistoryBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/1850771972');

  /// 日記履歴画面バナー
  static String get diaryHistoryBannerAdUnitId =>
      _banner(iosId: 'ca-app-pub-5851550594315289/6680293379');

  // ─── リワード広告ユニットID ───────────────────────────────
  /// リワード動画広告
  static String get rewardedAdUnitId {
    if (kIsWeb) return '';
    if (isTestMode) {
      return Platform.isAndroid ? _testRewardedAndroid : _testRewardedIos;
    }
    if (Platform.isAndroid) return 'YOUR_ANDROID_REWARDED_AD_UNIT_ID';
    return 'ca-app-pub-5851550594315289/8397160491';
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
