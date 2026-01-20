import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../data/datasources/remote/subscription_datasource.dart';
import '../../data/models/subscription_model.dart';
import '../../data/services/purchase_service.dart';
import 'auth_provider.dart';

/// SubscriptionDatasourceのプロバイダー
final subscriptionDatasourceProvider = Provider<SubscriptionDatasource>((ref) {
  return SubscriptionDatasource();
});

/// PurchaseServiceのプロバイダー
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final datasource = ref.watch(subscriptionDatasourceProvider);
  return PurchaseService(datasource: datasource);
});

/// サブスクリプション状態のストリームプロバイダー
final subscriptionStreamProvider = StreamProvider<SubscriptionModel>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(SubscriptionModel.free());
  }

  final datasource = ref.watch(subscriptionDatasourceProvider);
  return datasource.watchSubscription();
});

/// 現在のサブスクリプション状態
final currentSubscriptionProvider = Provider<SubscriptionModel>((ref) {
  return ref.watch(subscriptionStreamProvider).when(
        data: (subscription) => subscription,
        loading: () => SubscriptionModel.free(),
        error: (_, __) => SubscriptionModel.free(),
      );
});

/// プレミアムかどうか
final isPremiumProvider = Provider<bool>((ref) {
  final subscription = ref.watch(currentSubscriptionProvider);
  return subscription.isPremium;
});

/// 商品リストのプロバイダー
final productsProvider = StateProvider<List<ProductDetails>>((ref) {
  return [];
});

/// サブスクリプション管理コントローラー
class SubscriptionController extends StateNotifier<SubscriptionState> {
  final PurchaseService _purchaseService;
  // ignore: unused_field - reserved for future use
  final SubscriptionDatasource _datasource;
  final Ref _ref;

  SubscriptionController(
    this._purchaseService,
    this._datasource,
    this._ref,
  ) : super(SubscriptionState.initial()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);

    // PurchaseServiceのコールバックを設定
    _purchaseService.onSubscriptionUpdated = (subscription) {
      // Riverpodの状態を更新
      _ref.invalidate(subscriptionStreamProvider);
    };

    _purchaseService.onError = (error) {
      state = state.copyWith(
        error: error,
        isLoading: false,
      );
    };

    _purchaseService.onPurchaseSuccess = () {
      state = state.copyWith(
        purchaseSuccess: true,
        isLoading: false,
        error: null,
      );
      // 成功フラグをリセット
      Future.delayed(const Duration(seconds: 1), () {
        state = state.copyWith(purchaseSuccess: false);
      });
    };

    // 初期化
    await _purchaseService.initialize();

    // 商品リストを更新
    _ref.read(productsProvider.notifier).state = _purchaseService.products;

    state = state.copyWith(
      isLoading: false,
      isAvailable: _purchaseService.isAvailable,
    );
  }

  /// 商品を再読み込み
  Future<void> reloadProducts() async {
    state = state.copyWith(isLoading: true, error: null);

    await _purchaseService.loadProducts();
    _ref.read(productsProvider.notifier).state = _purchaseService.products;

    state = state.copyWith(isLoading: false);
  }

  /// 月額プランを購入
  Future<bool> purchaseMonthly() async {
    state = state.copyWith(isLoading: true, error: null);

    final success = await _purchaseService.purchaseMonthly();

    if (!success) {
      state = state.copyWith(isLoading: false);
    }
    // 成功時はonPurchaseSuccessコールバックで処理

    return success;
  }

  /// 購入を復元
  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, error: null);

    await _purchaseService.restorePurchases();

    state = state.copyWith(isLoading: false);
  }

  /// エラーをクリア
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _purchaseService.dispose();
    super.dispose();
  }
}

/// サブスクリプションの状態
class SubscriptionState {
  final bool isLoading;
  final bool isAvailable;
  final String? error;
  final bool purchaseSuccess;

  SubscriptionState({
    required this.isLoading,
    required this.isAvailable,
    this.error,
    required this.purchaseSuccess,
  });

  factory SubscriptionState.initial() {
    return SubscriptionState(
      isLoading: true,
      isAvailable: false,
      error: null,
      purchaseSuccess: false,
    );
  }

  SubscriptionState copyWith({
    bool? isLoading,
    bool? isAvailable,
    String? error,
    bool? purchaseSuccess,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      isAvailable: isAvailable ?? this.isAvailable,
      error: error,
      purchaseSuccess: purchaseSuccess ?? this.purchaseSuccess,
    );
  }
}

/// サブスクリプションコントローラーのプロバイダー
final subscriptionControllerProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>((ref) {
  final purchaseService = ref.watch(purchaseServiceProvider);
  final datasource = ref.watch(subscriptionDatasourceProvider);
  return SubscriptionController(purchaseService, datasource, ref);
});

/// アップグレード推奨情報のプロバイダー
final upgradeRecommendationProvider = Provider<UpgradeRecommendation?>((ref) {
  final subscription = ref.watch(currentSubscriptionProvider);
  if (subscription.isPremium) return null;
  return UpgradeRecommendation.defaultRecommendation();
});

/// 月額商品のプロバイダー
final monthlyProductProvider = Provider<ProductDetails?>((ref) {
  final products = ref.watch(productsProvider);
  try {
    return products.firstWhere(
      (p) => p.id == PurchaseService.monthlyProductId,
    );
  } catch (_) {
    return null;
  }
});

/// テストモードのプロバイダー（開発用）
final testModeProvider = StateProvider<bool>((ref) => false);

/// テスト用サブスクリプション状態のプロバイダー（開発用）
final testSubscriptionStatusProvider = StateProvider<SubscriptionStatus>(
  (ref) => SubscriptionStatus.free,
);

/// 実効サブスクリプション状態のプロバイダー
/// テストモードが有効な場合はテスト用の状態を返す
final effectiveSubscriptionProvider = Provider<SubscriptionModel>((ref) {
  final isTestMode = ref.watch(testModeProvider);
  if (isTestMode) {
    final testStatus = ref.watch(testSubscriptionStatusProvider);
    return SubscriptionModel(
      plan: testStatus == SubscriptionStatus.premium
          ? SubscriptionPlan.premium
          : SubscriptionPlan.free,
      status: testStatus,
      paymentMethod: PaymentMethod.unknown,
      autoRenewal: false,
    );
  }
  return ref.watch(currentSubscriptionProvider);
});

/// 実効プレミアム状態のプロバイダー
final effectiveIsPremiumProvider = Provider<bool>((ref) {
  final subscription = ref.watch(effectiveSubscriptionProvider);
  return subscription.isPremium;
});
