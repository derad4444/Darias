// lib/data/services/analytics_service.dart

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// 計測対象の機能。継続利用を1イベント（`feature_used`）で見るための区分。
///
/// 機能ごとに別イベント名を作らないのは、GA4 のカスタムイベント種別上限（500）を
/// 無駄に消費せず、`feature` パラメータで分解して比較できるようにするため。
enum AnalyticsFeature {
  diary('diary'),
  meeting('meeting'),
  friend('friend');

  const AnalyticsFeature(this.value);
  final String value;
}

/// Firebase Analytics への送信を一手に引き受けるサービス。
///
/// **なぜ画面から直接 FirebaseAnalytics を呼ばないのか**
/// 送信口をこの1クラスに閉じることで、「うっかりチャット本文や日記本文を
/// パラメータに渡してしまう」事故を構造的に防ぐ。
/// **ここに定義されたメソッド以外の送信経路を作らないこと。**
///
/// **送ってよいもの / 送ってはいけないもの**
/// - 送ってよい: 画面名・イベント種別・回数の区分（バケット）・元素などの区分値
/// - 送ってはいけない: uid・メールアドレス・氏名・チャット本文・日記本文・
///   自分会議のトピック文・タグ名・フレンドID など、個人または内容が判別できるもの。
///   本文の**文字数も送らない**（内容推定の手掛かりを残さないため）
///
/// この方針により `setUserId()` は意図的に呼ばない（Firebase Auth の UID を
/// Analytics 側に渡さない）。
class AnalyticsService {
  AnalyticsService._();

  /// アプリ全体で共有するインスタンス。
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  /// GoRouter に渡して `screen_view` を自動送信させるオブザーバー。
  FirebaseAnalyticsObserver get navigatorObserver =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// 収集を明示的に有効化する。アプリ起動時に1度だけ呼ぶ。
  ///
  /// 既定でも有効だが、「意図して収集している」ことをコード上に残すため明示する。
  Future<void> initialize() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
    } catch (e) {
      // 計測の失敗でアプリを止めない
      debugPrint('⚠️ Analytics: 初期化に失敗 - $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ファネル（どこで離脱しているか）
  // ---------------------------------------------------------------------------

  /// 新規登録の完了。[method] は email / google / apple。
  Future<void> logSignUp({required String method}) =>
      _guard(() => _analytics.logSignUp(signUpMethod: method));

  /// ログインの完了。[method] は email / google / apple。
  Future<void> logLogin({required String method}) =>
      _guard(() => _analytics.logLogin(loginMethod: method));

  /// オンボーディングスライドの表示開始。
  Future<void> logTutorialBegin() =>
      _guard(() => _analytics.logTutorialBegin());

  /// オンボーディングスライドの何枚目を見たか。[slideIndex] は 0 始まり。
  ///
  /// 6枚のどこで離脱しているかを特定するための唯一の手掛かりになる。
  Future<void> logOnboardingSlideView({required int slideIndex}) => _guard(
        () => _analytics.logEvent(
          name: 'onboarding_slide_view',
          parameters: {'slide_index': slideIndex},
        ),
      );

  /// オンボーディングの終了。[skipped] が true ならスキップによる終了。
  Future<void> logTutorialComplete({required bool skipped}) => _guard(
        () => _analytics.logEvent(
          name: 'tutorial_complete',
          parameters: {'skipped': skipped ? 'true' : 'false'},
        ),
      );

  /// チャット送信の成功。
  ///
  /// [badgeAnswered] は送信時点でバッジ診断の質問に答えた数（0〜20。答え直しは数えない）。
  /// 生の数値ではなく区分に丸めて送る（元素が決まる前後・大人になる前後を
  /// 比較できれば足りるため）。
  ///
  /// ユーザープロパティ `badge_bucket` は「現在値」を表すのに対し、
  /// こちらは「そのイベントが起きた時点の値」を表す。用途が違うため両方持つ。
  Future<void> logChatMessageSent({
    required int badgeAnswered,
    required int phase,
  }) =>
      _guard(
        () => _analytics.logEvent(
          name: 'chat_message_sent',
          parameters: {
            'progress_bucket': badgeBucket(badgeAnswered),
            'phase': phase,
          },
        ),
      );

  /// 課金画面の表示。[source] はどこから来たか（settings / limit / home など）。
  Future<void> logPaywallView({required String source}) => _guard(
        () => _analytics.logEvent(
          name: 'paywall_view',
          parameters: {'source': source},
        ),
      );

  /// 購入ボタンの押下（＝購入手続きの開始）。
  ///
  /// 課金画面の表示から実際の購入完了までの間で、どこで落ちているかを分けて見るため、
  /// 「押した」時点を [logPurchase] とは別に記録する。
  Future<void> logBeginCheckout({
    required String itemId,
    double? value,
    String? currency,
  }) =>
      _guard(
        () => _analytics.logBeginCheckout(
          value: value,
          currency: currency,
          items: [AnalyticsEventItem(itemId: itemId, itemName: itemId)],
        ),
      );

  /// 購入の完了。復元（restore）では呼ばない（新規の課金だけを数えるため）。
  Future<void> logPurchase({
    required String itemId,
    double? value,
    String? currency,
  }) =>
      _guard(
        () => _analytics.logPurchase(
          value: value,
          currency: currency,
          items: [AnalyticsEventItem(itemId: itemId, itemName: itemId)],
        ),
      );

  // ---------------------------------------------------------------------------
  // 継続利用（どの機能が使われ続けているか）
  // ---------------------------------------------------------------------------

  /// 機能を1回使い切ったときに送る（作成・保存・完了などの確定操作の直後）。
  Future<void> logFeatureUsed(AnalyticsFeature feature) => _guard(
        () => _analytics.logEvent(
          name: 'feature_used',
          parameters: {'feature': feature.value},
        ),
      );

  // ---------------------------------------------------------------------------
  // ユーザープロパティ（セグメント比較用・いずれも個人を特定しない区分値）
  // ---------------------------------------------------------------------------

  /// 元素・成長段階・課金状態のセグメントを更新する。
  ///
  /// [element] は「炎」「水」などの元素名。未確定なら null を渡す。
  /// [growthStage] は成長段階（0=赤ちゃん 1=幼少期 2=大人）。
  /// [badgeAnswered] はバッジ診断の質問に答えた数（0〜20）。
  Future<void> setUserSegment({
    String? element,
    int? growthStage,
    int? badgeAnswered,
    bool? isPremium,
  }) async {
    await _guard(() async {
      if (element != null || growthStage != null) {
        // 元素は赤ちゃんのうちは未確定なので unknown 扱いにする
        final decided = (growthStage == null || growthStage >= 1);
        await _analytics.setUserProperty(
          name: 'element',
          value: (decided && element != null && element.isNotEmpty)
              ? element
              : 'unknown',
        );
      }
      if (growthStage != null) {
        await _analytics.setUserProperty(
          name: 'growth_stage',
          value: growthStageName(growthStage),
        );
      }
      if (badgeAnswered != null) {
        await _analytics.setUserProperty(
          name: 'badge_bucket',
          value: badgeBucket(badgeAnswered),
        );
      }
      if (isPremium != null) {
        await _analytics.setUserProperty(
          name: 'is_premium',
          value: isPremium ? 'true' : 'false',
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 区分（バケット）の定義
  // ---------------------------------------------------------------------------

  /// バッジ診断で答えた数の区分。第1弾（10問）・第2弾（20問）の境界と揃えている。
  @visibleForTesting
  static String badgeBucket(int count) {
    if (count <= 0) return '0';
    if (count < 10) return '1-9';
    if (count < 20) return '10-19';
    return '20';
  }

  /// 成長段階の名前。`users/{uid}.growthStage` の 0 / 1 / 2 に対応する。
  @visibleForTesting
  static String growthStageName(int growthStage) {
    if (growthStage < 1) return 'baby';
    if (growthStage < 2) return 'child';
    return 'adult';
  }

  /// 計測の失敗でアプリの動作を壊さないための共通ガード。
  Future<void> _guard(Future<void> Function() send) async {
    try {
      await send();
    } catch (e) {
      debugPrint('⚠️ Analytics: 送信に失敗 - $e');
    }
  }
}
