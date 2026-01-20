import 'package:cloud_firestore/cloud_firestore.dart';

/// サブスクリプションの状態
enum SubscriptionStatus {
  free,
  premium,
  unknown;

  String get displayName {
    switch (this) {
      case SubscriptionStatus.free:
        return '無料ユーザー';
      case SubscriptionStatus.premium:
        return '有料ユーザー';
      case SubscriptionStatus.unknown:
        return '状態不明';
    }
  }
}

/// サブスクリプションのプラン
enum SubscriptionPlan {
  free,
  premium;

  static SubscriptionPlan fromString(String? value) {
    switch (value) {
      case 'premium':
        return SubscriptionPlan.premium;
      default:
        return SubscriptionPlan.free;
    }
  }

  String toFirestoreValue() {
    switch (this) {
      case SubscriptionPlan.free:
        return 'free';
      case SubscriptionPlan.premium:
        return 'premium';
    }
  }
}

/// 支払い方法
enum PaymentMethod {
  appStore,
  googlePlay,
  unknown;

  static PaymentMethod fromString(String? value) {
    switch (value) {
      case 'app_store':
        return PaymentMethod.appStore;
      case 'google_play':
        return PaymentMethod.googlePlay;
      default:
        return PaymentMethod.unknown;
    }
  }

  String toFirestoreValue() {
    switch (this) {
      case PaymentMethod.appStore:
        return 'app_store';
      case PaymentMethod.googlePlay:
        return 'google_play';
      case PaymentMethod.unknown:
        return 'unknown';
    }
  }
}

/// サブスクリプションモデル
class SubscriptionModel {
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final PaymentMethod paymentMethod;
  final DateTime? endDate;
  final bool autoRenewal;
  final DateTime? updatedAt;

  SubscriptionModel({
    required this.plan,
    required this.status,
    required this.paymentMethod,
    this.endDate,
    required this.autoRenewal,
    this.updatedAt,
  });

  /// デフォルト（無料）のサブスクリプション
  factory SubscriptionModel.free() {
    return SubscriptionModel(
      plan: SubscriptionPlan.free,
      status: SubscriptionStatus.free,
      paymentMethod: PaymentMethod.unknown,
      endDate: null,
      autoRenewal: false,
      updatedAt: DateTime.now(),
    );
  }

  /// Firestoreからの変換
  factory SubscriptionModel.fromFirestore(Map<String, dynamic> data) {
    final planStr = data['plan'] as String?;
    final statusStr = data['status'] as String?;
    final paymentMethodStr = data['payment_method'] as String?;
    final endDateTimestamp = data['end_date'] as Timestamp?;
    final autoRenewal = data['auto_renewal'] as bool? ?? false;
    final updatedAtTimestamp = data['updated_at'] as Timestamp?;

    // プランとステータスから実際の状態を判定
    SubscriptionStatus computedStatus;
    if (statusStr == 'active' || planStr == 'premium') {
      // 有効期限をチェック
      if (endDateTimestamp != null) {
        final endDate = endDateTimestamp.toDate();
        computedStatus =
            DateTime.now().isBefore(endDate)
                ? SubscriptionStatus.premium
                : SubscriptionStatus.free;
      } else {
        // end_dateがnullの場合は無期限premium
        computedStatus = SubscriptionStatus.premium;
      }
    } else {
      computedStatus = SubscriptionStatus.free;
    }

    return SubscriptionModel(
      plan: SubscriptionPlan.fromString(planStr),
      status: computedStatus,
      paymentMethod: PaymentMethod.fromString(paymentMethodStr),
      endDate: endDateTimestamp?.toDate(),
      autoRenewal: autoRenewal,
      updatedAt: updatedAtTimestamp?.toDate(),
    );
  }

  /// Firestoreへの変換
  Map<String, dynamic> toFirestore() {
    return {
      'plan': plan.toFirestoreValue(),
      'status': status == SubscriptionStatus.premium ? 'active' : 'free',
      'payment_method': paymentMethod.toFirestoreValue(),
      'end_date': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'auto_renewal': autoRenewal,
      'updated_at': Timestamp.now(),
    };
  }

  /// プレミアムかどうか
  bool get isPremium => status == SubscriptionStatus.premium;

  /// 無料かどうか
  bool get isFree => status == SubscriptionStatus.free;

  /// 有効期限が切れているかどうか
  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  /// コピーを作成
  SubscriptionModel copyWith({
    SubscriptionPlan? plan,
    SubscriptionStatus? status,
    PaymentMethod? paymentMethod,
    DateTime? endDate,
    bool? autoRenewal,
    DateTime? updatedAt,
  }) {
    return SubscriptionModel(
      plan: plan ?? this.plan,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      endDate: endDate ?? this.endDate,
      autoRenewal: autoRenewal ?? this.autoRenewal,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'SubscriptionModel(plan: $plan, status: $status, endDate: $endDate, autoRenewal: $autoRenewal)';
  }
}

/// 商品情報モデル
class ProductInfo {
  final String id;
  final String title;
  final String description;
  final String price;
  final String rawPrice;

  ProductInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.rawPrice,
  });

  @override
  String toString() {
    return 'ProductInfo(id: $id, title: $title, price: $price)';
  }
}

/// アップグレード推奨情報
class UpgradeRecommendation {
  final String title;
  final String message;
  final List<String> benefits;

  UpgradeRecommendation({
    required this.title,
    required this.message,
    required this.benefits,
  });

  /// デフォルトの推奨情報
  factory UpgradeRecommendation.defaultRecommendation() {
    return UpgradeRecommendation(
      title: 'プレミアムにアップグレード',
      message: '最新AIで高品質なキャラクター体験',
      benefits: [
        '広告完全非表示',
        '最新AIモデル (GPT-4o-2024-11-20)',
        '無制限チャット履歴',
        'より高度な解析',
        '音声生成機能',
      ],
    );
  }
}

/// 購入エラー
enum PurchaseError {
  failedVerification,
  invalidProductId,
  purchaseFailed,
  cancelled,
  pending,
  unknown;

  String get message {
    switch (this) {
      case PurchaseError.failedVerification:
        return '購入の検証に失敗しました';
      case PurchaseError.invalidProductId:
        return '無効な商品IDです';
      case PurchaseError.purchaseFailed:
        return '購入に失敗しました';
      case PurchaseError.cancelled:
        return '購入がキャンセルされました';
      case PurchaseError.pending:
        return '購入が保留中です。承認後に自動的に処理されます。';
      case PurchaseError.unknown:
        return '不明なエラーが発生しました';
    }
  }
}
