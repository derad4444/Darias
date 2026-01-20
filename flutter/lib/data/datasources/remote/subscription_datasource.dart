import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/subscription_model.dart';

/// サブスクリプション関連のFirestore操作を行うデータソース
class SubscriptionDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SubscriptionDatasource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// 現在のユーザーID
  String? get _userId => _auth.currentUser?.uid;

  /// サブスクリプションドキュメントへの参照
  DocumentReference<Map<String, dynamic>>? get _subscriptionRef {
    final userId = _userId;
    if (userId == null) return null;
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subscription')
        .doc('current');
  }

  /// サブスクリプション状態を取得
  Future<SubscriptionModel> getSubscription() async {
    final ref = _subscriptionRef;
    if (ref == null) {
      return SubscriptionModel.free();
    }

    try {
      final doc = await ref.get();
      if (!doc.exists || doc.data() == null) {
        return SubscriptionModel.free();
      }
      return SubscriptionModel.fromFirestore(doc.data()!);
    } catch (e) {
      print('❌ SubscriptionDatasource: Failed to get subscription - $e');
      return SubscriptionModel.free();
    }
  }

  /// サブスクリプション状態をリアルタイムで監視
  Stream<SubscriptionModel> watchSubscription() {
    final ref = _subscriptionRef;
    if (ref == null) {
      return Stream.value(SubscriptionModel.free());
    }

    return ref.snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return SubscriptionModel.free();
      }
      return SubscriptionModel.fromFirestore(doc.data()!);
    }).handleError((error) {
      print('❌ SubscriptionDatasource: Stream error - $error');
      return SubscriptionModel.free();
    });
  }

  /// サブスクリプション状態を更新（購入成功時に呼ばれる）
  Future<void> updateSubscription({
    required bool isPremium,
    required PaymentMethod paymentMethod,
    DateTime? endDate,
    bool autoRenewal = true,
  }) async {
    final ref = _subscriptionRef;
    if (ref == null) {
      print('⚠️ SubscriptionDatasource: No authenticated user');
      return;
    }

    try {
      final data = <String, dynamic>{
        'plan': isPremium ? 'premium' : 'free',
        'status': isPremium ? 'active' : 'free',
        'payment_method': paymentMethod.toFirestoreValue(),
        'auto_renewal': autoRenewal,
        'updated_at': Timestamp.now(),
      };

      if (endDate != null) {
        data['end_date'] = Timestamp.fromDate(endDate);
      } else {
        data['end_date'] = null;
      }

      await ref.set(data, SetOptions(merge: true));
      print('✅ SubscriptionDatasource: Updated subscription - isPremium: $isPremium');
    } catch (e) {
      print('❌ SubscriptionDatasource: Failed to update subscription - $e');
      rethrow;
    }
  }

  /// サブスクリプションをフリーに戻す（返金時など）
  Future<void> resetToFree() async {
    final ref = _subscriptionRef;
    if (ref == null) return;

    try {
      await ref.set({
        'plan': 'free',
        'status': 'free',
        'auto_renewal': false,
        'end_date': null,
        'updated_at': Timestamp.now(),
      }, SetOptions(merge: true));
      print('✅ SubscriptionDatasource: Reset to free');
    } catch (e) {
      print('❌ SubscriptionDatasource: Failed to reset to free - $e');
      rethrow;
    }
  }

  /// 手動オーバーライドフラグを確認（テスト用）
  Future<bool> hasManualOverride() async {
    final ref = _subscriptionRef;
    if (ref == null) return false;

    try {
      final doc = await ref.get();
      if (!doc.exists || doc.data() == null) return false;
      return doc.data()!['manual_override'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 広告インプレッションを記録（分析用）
  Future<void> trackAdImpression({
    required String type,
    required String screen,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore.collection('ad_analytics').add({
        'type': type,
        'timestamp': Timestamp.now(),
        'user_id': userId,
        'screen': screen,
      });
    } catch (e) {
      print('⚠️ SubscriptionDatasource: Failed to track ad impression - $e');
    }
  }
}
