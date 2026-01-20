import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../datasources/remote/subscription_datasource.dart';
import '../models/subscription_model.dart';

/// アプリ内課金を管理するサービス
class PurchaseService {
  final InAppPurchase _inAppPurchase;
  final SubscriptionDatasource _datasource;
  final FirebaseFunctions _functions;

  // 商品ID
  static const String monthlyProductId = 'com.character.premium.monthly';
  static const Set<String> productIds = {monthlyProductId};

  // 状態
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // コールバック
  Function(SubscriptionModel)? onSubscriptionUpdated;
  Function(String)? onError;
  Function()? onPurchaseSuccess;

  PurchaseService({
    InAppPurchase? inAppPurchase,
    SubscriptionDatasource? datasource,
    FirebaseFunctions? functions,
  })  : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance,
        _datasource = datasource ?? SubscriptionDatasource(),
        _functions = functions ?? FirebaseFunctions.instance;

  /// 利用可能かどうか
  bool get isAvailable => _isAvailable;

  /// 商品リスト
  List<ProductDetails> get products => _products;

  /// 購入履歴
  List<PurchaseDetails> get purchases => _purchases;

  /// 月額商品を取得
  ProductDetails? get monthlyProduct {
    try {
      return _products.firstWhere((p) => p.id == monthlyProductId);
    } catch (_) {
      return null;
    }
  }

  /// 初期化
  Future<void> initialize() async {
    print('🛒 PurchaseService: Initializing...');

    // 利用可能かチェック
    _isAvailable = await _inAppPurchase.isAvailable();
    if (!_isAvailable) {
      print('⚠️ PurchaseService: In-app purchases not available');
      return;
    }

    // 購入更新のリスニング開始
    _subscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        print('❌ PurchaseService: Stream error - $error');
        onError?.call('購入処理中にエラーが発生しました');
      },
    );

    // 商品情報を読み込み
    await loadProducts();

    print('✅ PurchaseService: Initialized');
  }

  /// 破棄
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// 商品情報を読み込む
  Future<void> loadProducts() async {
    print('🛒 PurchaseService: Loading products...');

    if (!_isAvailable) {
      print('⚠️ PurchaseService: Not available, skipping product load');
      return;
    }

    try {
      final response = await _inAppPurchase.queryProductDetails(productIds);

      if (response.notFoundIDs.isNotEmpty) {
        print('⚠️ PurchaseService: Products not found: ${response.notFoundIDs}');
      }

      if (response.error != null) {
        print('❌ PurchaseService: Error loading products - ${response.error}');
        onError?.call('商品の読み込みに失敗しました');
        return;
      }

      _products = response.productDetails;
      print('✅ PurchaseService: Loaded ${_products.length} product(s)');

      for (final product in _products) {
        print('  - ${product.id}: ${product.title} (${product.price})');
      }
    } catch (e) {
      print('❌ PurchaseService: Failed to load products - $e');
      onError?.call('商品の読み込みに失敗しました');
    }
  }

  /// 商品を購入
  Future<bool> purchase(ProductDetails product) async {
    print('🛒 PurchaseService: Starting purchase for ${product.id}...');

    if (!_isAvailable) {
      onError?.call('アプリ内課金が利用できません');
      return false;
    }

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      final success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!success) {
        print('❌ PurchaseService: Purchase initiation failed');
        onError?.call('購入の開始に失敗しました');
        return false;
      }

      print('✅ PurchaseService: Purchase initiated');
      return true;
    } catch (e) {
      print('❌ PurchaseService: Purchase failed - $e');
      onError?.call('購入に失敗しました: $e');
      return false;
    }
  }

  /// 月額商品を購入（ショートカット）
  Future<bool> purchaseMonthly() async {
    final product = monthlyProduct;
    if (product == null) {
      onError?.call('商品が見つかりません');
      return false;
    }
    return purchase(product);
  }

  /// 購入を復元
  Future<void> restorePurchases() async {
    print('🛒 PurchaseService: Restoring purchases...');

    if (!_isAvailable) {
      onError?.call('アプリ内課金が利用できません');
      return;
    }

    try {
      await _inAppPurchase.restorePurchases();
      print('✅ PurchaseService: Restore initiated');
    } catch (e) {
      print('❌ PurchaseService: Restore failed - $e');
      onError?.call('購入の復元に失敗しました');
    }
  }

  /// 購入更新のハンドリング
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    print('🛒 PurchaseService: Handling ${purchases.length} purchase updates...');

    for (final purchase in purchases) {
      print('  - ${purchase.productID}: ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          print('⏳ PurchaseService: Purchase pending');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          print('✅ PurchaseService: Purchase successful or restored');
          await _handleSuccessfulPurchase(purchase);
          break;

        case PurchaseStatus.error:
          print('❌ PurchaseService: Purchase error - ${purchase.error}');
          onError?.call(
            purchase.error?.message ?? '購入に失敗しました',
          );
          break;

        case PurchaseStatus.canceled:
          print('🚫 PurchaseService: Purchase canceled');
          onError?.call('購入がキャンセルされました');
          break;
      }

      // 保留中のトランザクションを完了
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
        print('✅ PurchaseService: Purchase completed');
      }
    }

    _purchases = purchases;
  }

  /// 購入成功時の処理
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    print('🛒 PurchaseService: Processing successful purchase...');

    try {
      // 支払い方法を判定
      final paymentMethod = Platform.isIOS
          ? PaymentMethod.appStore
          : PaymentMethod.googlePlay;

      // Firestoreを更新
      await _datasource.updateSubscription(
        isPremium: true,
        paymentMethod: paymentMethod,
        autoRenewal: true,
      );

      // レシート検証（Firebase Functions）
      await _validateReceipt(purchase);

      // コールバック
      onPurchaseSuccess?.call();

      print('✅ PurchaseService: Purchase processed successfully');
    } catch (e) {
      print('❌ PurchaseService: Failed to process purchase - $e');
      onError?.call('購入の処理に失敗しました');
    }
  }

  /// レシート検証
  Future<void> _validateReceipt(PurchaseDetails purchase) async {
    print('🛒 PurchaseService: Validating receipt...');

    try {
      final functionName = Platform.isIOS
          ? 'validateAppStoreReceipt'
          : 'validateGooglePlayReceipt';

      final callable = _functions.httpsCallable(functionName);
      final result = await callable.call({
        'receiptData': purchase.verificationData.serverVerificationData,
        'productId': purchase.productID,
      });

      final data = result.data as Map<String, dynamic>?;
      if (data?['success'] == true) {
        print('✅ PurchaseService: Receipt validated');
      } else {
        print('⚠️ PurchaseService: Receipt validation returned: $data');
      }
    } catch (e) {
      print('⚠️ PurchaseService: Receipt validation failed - $e');
      // レシート検証の失敗は購入自体には影響させない
    }
  }

  /// プレミアムかどうかをチェック（ローカル）
  bool get hasPurchases {
    return _purchases.any(
      (p) =>
          p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored,
    );
  }

  /// 商品情報をProductInfoに変換
  List<ProductInfo> get productInfoList {
    return _products.map((p) {
      return ProductInfo(
        id: p.id,
        title: p.title,
        description: p.description,
        price: p.price,
        rawPrice: p.rawPrice.toString(),
      );
    }).toList();
  }
}
