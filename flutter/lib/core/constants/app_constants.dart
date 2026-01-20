/// アプリ定数
class AppConstants {
  AppConstants._();

  // アプリ情報
  static const String appName = 'DARIAS';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  static const String appDescription = 'AI Partner App';

  // 連絡先
  static const String supportEmail = 'darias.app4@gmail.com';
  static const String websiteUrl = 'https://darias.app';
  static const String privacyPolicyUrl = 'https://darias.app/privacy';
  static const String termsOfServiceUrl = 'https://darias.app/terms';

  // Firebase
  static const String firebaseRegion = 'asia-northeast1';

  // チャット
  static const int maxChatMessagesPerDay = 50;
  static const int maxChatMessagesPerDayPremium = 999999;
  static const int chatMessageMaxLength = 1000;

  // BIG5診断
  static const int big5TotalQuestions = 100;
  static const int big5BasicLevel = 20;
  static const int big5DetailedLevel = 50;
  static const int big5CompleteLevel = 100;

  // 会議
  static const int meetingMaxParticipants = 6;
  static const int meetingMaxTopicLength = 200;

  // データ
  static const int todoMaxTitleLength = 100;
  static const int todoMaxDescriptionLength = 500;
  static const int memoMaxTitleLength = 100;
  static const int memoMaxContentLength = 10000;
  static const int scheduleMaxTitleLength = 100;
  static const int diaryMaxCommentLength = 500;

  // UI
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultBorderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double largeBorderRadius = 20.0;

  // アニメーション
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);
  static const Duration normalAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // キャッシュ
  static const Duration cacheExpiration = Duration(hours: 24);
  static const int maxCacheSize = 100;
}

/// 広告関連の定数
class AdConstants {
  AdConstants._();

  // テスト用広告ユニットID（本番環境では実際のIDに置き換え）
  static const String testBannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String testBannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const String testRewardedAdUnitIdAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const String testRewardedAdUnitIdIOS = 'ca-app-pub-3940256099942544/1712485313';

  // 本番用広告ユニットID（環境変数から取得推奨）
  static const String bannerAdUnitIdAndroid = '';
  static const String bannerAdUnitIdIOS = '';
  static const String rewardedAdUnitIdAndroid = '';
  static const String rewardedAdUnitIdIOS = '';

  // リワード広告で追加されるチャット回数
  static const int rewardedAdChatBonus = 10;
}

/// 課金関連の定数
class PurchaseConstants {
  PurchaseConstants._();

  // 商品ID
  static const String monthlySubscriptionId = 'darias_premium_monthly';
  static const String yearlySubscriptionId = 'darias_premium_yearly';

  // 価格表示用
  static const String monthlyPriceDefault = '¥480/月';
  static const String yearlyPriceDefault = '¥4,800/年';
}

/// ストレージキー
class StorageKeys {
  StorageKeys._();

  // 一般設定
  static const String themeMode = 'theme_mode';
  static const String colorSeed = 'color_seed';
  static const String hasCompletedOnboarding = 'has_completed_onboarding';
  static const String lastUsedCharacterId = 'last_used_character_id';

  // 通知設定
  static const String notificationsEnabled = 'notifications_enabled';
  static const String notificationSchedule = 'notification_schedule';
  static const String notificationDiary = 'notification_diary';
  static const String notificationTodo = 'notification_todo';

  // プライバシー設定
  static const String privacyAnalytics = 'privacy_analytics';
  static const String privacyCrashReporting = 'privacy_crash';
  static const String privacyPersonalizedAds = 'privacy_ads';
  static const String privacyDataCollection = 'privacy_data';

  // チャット
  static const String chatLimitDate = 'chat_limit_date';
  static const String chatLimitCount = 'chat_limit_count';

  // タグ
  static const String userTags = 'user_tags';
}

/// Firestore コレクション名
class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';
  static const String characters = 'characters';
  static const String chats = 'chats';
  static const String messages = 'messages';
  static const String diaries = 'diaries';
  static const String todos = 'todos';
  static const String memos = 'memos';
  static const String schedules = 'schedules';
  static const String meetings = 'meetings';
  static const String big5Progress = 'big5Progress';
  static const String big5Analysis = 'big5Analysis';
  static const String subscriptions = 'subscriptions';
}

/// Cloud Functions 名
class CloudFunctions {
  CloudFunctions._();

  static const String sendChatMessage = 'sendChatMessage';
  static const String startBig5Diagnosis = 'startBig5Diagnosis';
  static const String submitBig5Answer = 'submitBig5Answer';
  static const String startMeeting = 'startMeeting';
  static const String sendMeetingMessage = 'sendMeetingMessage';
  static const String generateDiary = 'generateDiary';
  static const String verifyPurchase = 'verifyPurchase';
}
