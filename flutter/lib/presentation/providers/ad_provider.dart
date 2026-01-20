import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/ad_service.dart';
import '../../data/services/chat_limit_manager.dart';
import '../../data/services/rewarded_ad_manager.dart';
import 'subscription_provider.dart';

/// AdServiceのプロバイダー
final adServiceProvider = Provider<AdService>((ref) {
  return AdService();
});

/// ChatLimitManagerのプロバイダー
final chatLimitManagerProvider = Provider<ChatLimitManager>((ref) {
  return ChatLimitManager();
});

/// RewardedAdManagerのプロバイダー
final rewardedAdManagerProvider = Provider<RewardedAdManager>((ref) {
  return RewardedAdManager();
});

/// 今日のチャット回数のプロバイダー
final chatCountTodayProvider = StateProvider<int>((ref) => 0);

/// バナー広告を表示すべきかのプロバイダー
/// プレミアムユーザーは広告非表示
final shouldShowBannerAdProvider = Provider<bool>((ref) {
  final isPremium = ref.watch(effectiveIsPremiumProvider);
  return !isPremium;
});

/// 動画広告を表示すべきかのプロバイダー
/// チャット回数が5の倍数かつ非プレミアムの場合にtrue
final shouldShowVideoAdProvider = Provider<bool>((ref) {
  final isPremium = ref.watch(effectiveIsPremiumProvider);
  if (isPremium) return false;

  final chatCount = ref.watch(chatCountTodayProvider);
  if (chatCount <= 0) return false;
  return chatCount % ChatLimitManager.adFrequency == 0;
});

/// リワード広告の状態プロバイダー
final rewardedAdStateProvider = StateProvider<RewardedAdState>((ref) {
  return RewardedAdState.loading;
});

/// 広告コントローラー
class AdController extends StateNotifier<AdState> {
  final AdService _adService;
  final ChatLimitManager _chatLimitManager;
  final RewardedAdManager _rewardedAdManager;
  final Ref _ref;

  AdController(
    this._adService,
    this._chatLimitManager,
    this._rewardedAdManager,
    this._ref,
  ) : super(AdState.initial()) {
    _initialize();
  }

  Future<void> _initialize() async {
    // 広告SDKを初期化
    await _adService.initialize();

    // チャット回数を取得
    await _chatLimitManager.fetchChatCount();
    _ref.read(chatCountTodayProvider.notifier).state =
        _chatLimitManager.totalChatsToday;

    // リワード広告のコールバックを設定
    _rewardedAdManager.onAdLoaded = () {
      _ref.read(rewardedAdStateProvider.notifier).state =
          RewardedAdState.ready;
    };

    _rewardedAdManager.onAdFailedToLoad = (error) {
      _ref.read(rewardedAdStateProvider.notifier).state =
          RewardedAdState.error;
    };

    _rewardedAdManager.onUserEarnedReward = (reward) {
      state = state.copyWith(lastRewardEarned: true);
      // リワードフラグをリセット
      Future.delayed(const Duration(seconds: 1), () {
        state = state.copyWith(lastRewardEarned: false);
      });
    };

    // リワード広告を事前に読み込み
    await _rewardedAdManager.loadAd();

    state = state.copyWith(isInitialized: true);
  }

  /// チャットを消費
  Future<void> consumeChat() async {
    await _chatLimitManager.consumeChat();
    _ref.read(chatCountTodayProvider.notifier).state =
        _chatLimitManager.totalChatsToday;
  }

  /// リワード広告を表示
  Future<bool> showRewardedAd() async {
    final success = await _rewardedAdManager.showAd();
    return success;
  }

  /// リワード広告を再読み込み
  Future<void> reloadRewardedAd() async {
    await _rewardedAdManager.loadAd();
  }

  /// リワード広告が準備できているか
  bool get isRewardedAdReady => _rewardedAdManager.isReady;

  @override
  void dispose() {
    _rewardedAdManager.dispose();
    super.dispose();
  }
}

/// 広告の状態
class AdState {
  final bool isInitialized;
  final bool lastRewardEarned;

  AdState({
    required this.isInitialized,
    required this.lastRewardEarned,
  });

  factory AdState.initial() {
    return AdState(
      isInitialized: false,
      lastRewardEarned: false,
    );
  }

  AdState copyWith({
    bool? isInitialized,
    bool? lastRewardEarned,
  }) {
    return AdState(
      isInitialized: isInitialized ?? this.isInitialized,
      lastRewardEarned: lastRewardEarned ?? this.lastRewardEarned,
    );
  }
}

/// 広告コントローラーのプロバイダー
final adControllerProvider =
    StateNotifierProvider<AdController, AdState>((ref) {
  final adService = ref.watch(adServiceProvider);
  final chatLimitManager = ref.watch(chatLimitManagerProvider);
  final rewardedAdManager = ref.watch(rewardedAdManagerProvider);
  return AdController(adService, chatLimitManager, rewardedAdManager, ref);
});
