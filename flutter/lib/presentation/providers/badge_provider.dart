import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/badge_model.dart';
import 'auth_provider.dart';

export '../../data/models/badge_model.dart';

final badgeStateProvider = StreamProvider<BadgeState>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const BadgeState());
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(userId)
      .collection('personalityBadges')
      .doc('current')
      .snapshots()
      .map((doc) => BadgeState.fromMap(doc.data()));
});

/// ホーム以外（キャラクター詳細・自分会議）でバッジが選ばれたときに、
/// ホーム画面へ質問を出してもらうための受け渡し。ホームが読んだら null に戻す
final requestedBadgeKeyProvider = StateProvider<String?>((ref) => null);

/// 成長段階（0=赤ちゃん 1=幼少期 2=大人）。`users/{uid}.growthStage`
///
/// 第1弾のバッジがそろうと1、第2弾もそろうと2になる（Cloud Function が保存する）。
/// 元素の表示・自分会議の解放・返答の深さはこれで判定する。
final growthStageProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(0);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) => (doc.data()?['growthStage'] as num?)?.toInt() ?? 0);
});

/// バッジの質問を出してもらう（Cloud Function `startBadgeQuestion`）
class BadgeService {
  final FirebaseFunctions _functions;

  BadgeService(this._functions);

  /// [source] は 'opener'（ホームの最初の話題）か 'badge'（バッジ画面から）
  Future<BadgeQuestion?> startQuestion({required String source, String? badgeKey}) async {
    try {
      final result = await _functions.httpsCallable('startBadgeQuestion').call<Map<String, dynamic>>({
        'source': source,
        'badgeKey': ?badgeKey,
      });
      return BadgeQuestion.fromMap(result.data['question']);
    } catch (e) {
      debugPrint('⚠️ startBadgeQuestion error: $e');
      return null;
    }
  }
}

final badgeServiceProvider = Provider<BadgeService>((ref) {
  return BadgeService(FirebaseFunctions.instanceFor(region: 'asia-northeast1'));
});
