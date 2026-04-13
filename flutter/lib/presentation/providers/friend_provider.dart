import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/friend_model.dart';
import 'auth_provider.dart';

/// フレンド一覧プロバイダー
final friendsProvider = StreamProvider<List<FriendModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(userId)
      .collection('friends')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(FriendModel.fromFirestore).toList());
});

/// 受信したフレンド申請プロバイダー（自分のサブコレクション）
final incomingFriendRequestsProvider = StreamProvider<List<FriendRequestModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(userId)
      .collection('incomingRequests')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(FriendRequestModel.fromFirestore).toList());
});

/// 送信したフレンド申請プロバイダー（自分のサブコレクション）
final outgoingFriendRequestsProvider = StreamProvider<List<FriendRequestModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(userId)
      .collection('outgoingRequests')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(FriendRequestModel.fromFirestore).toList());
});

/// フレンド操作コントローラー
class FriendController extends StateNotifier<AsyncValue<void>> {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final String? _userId;

  FriendController(this._firestore, this._functions, this._userId)
      : super(const AsyncValue.data(null));

  /// ユーザー検索（Cloud Function経由）
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty || _userId == null) return [];
    try {
      final callable = _functions.httpsCallable('searchUsers');
      final result = await callable.call({'query': query.trim()});
      final data = result.data as Map<String, dynamic>;
      final users = data['users'] as List<dynamic>? ?? [];
      return users.map((u) => Map<String, dynamic>.from(u as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  /// フレンド申請を送る（Cloud Function経由）
  Future<String> sendFriendRequest({
    required String toUserId,
    required String toUserName,
    required String myName,
    required String myEmail,
  }) async {
    if (_userId == null) return 'error';
    state = const AsyncValue.loading();
    try {
      final callable = _functions.httpsCallable('sendFriendRequest');
      final result = await callable.call({
        'toUserId': toUserId,
        'toUserName': toUserName,
        'myName': myName,
        'myEmail': myEmail,
      });
      final data = result.data as Map<String, dynamic>;
      state = const AsyncValue.data(null);
      return data['result'] as String? ?? 'error';
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 'error';
    }
  }

  /// フレンド申請を承認（Cloud Function経由）
  Future<void> acceptFriendRequest(FriendRequestModel request) async {
    state = const AsyncValue.loading();
    try {
      final callable = _functions.httpsCallable('acceptFriendRequest');
      await callable.call({'fromUserId': request.fromUserId});
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// フレンド申請を拒否（Cloud Function経由）
  Future<void> rejectFriendRequest(FriendRequestModel request) async {
    try {
      final callable = _functions.httpsCallable('rejectFriendRequest');
      await callable.call({'fromUserId': request.fromUserId});
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// フレンド申請を取消（Cloud Function経由）
  Future<void> cancelFriendRequest(FriendRequestModel request) async {
    try {
      final callable = _functions.httpsCallable('cancelFriendRequest');
      await callable.call({'toUserId': request.toUserId});
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// フレンドを削除
  Future<void> removeFriend(String friendId) async {
    if (_userId == null) return;
    state = const AsyncValue.loading();
    try {
      final batch = _firestore.batch();
      batch.delete(
        _firestore.collection('users').doc(_userId).collection('friends').doc(friendId),
      );
      batch.delete(
        _firestore.collection('users').doc(friendId).collection('friends').doc(_userId),
      );
      await batch.commit();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// フレンドの共有レベルを更新
  Future<void> updateShareLevel(String friendId, FriendShareLevel level) async {
    if (_userId == null) return;
    try {
      await _firestore
          .collection('users').doc(_userId)
          .collection('friends').doc(friendId)
          .update({'shareLevel': level.value});
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 保存済み相性診断結果を取得
  Future<CompatibilityResult?> fetchCompatibilityResult({
    required String friendId,
  }) async {
    if (_userId == null) return null;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('compatibilityResults')
          .doc(friendId)
          .get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return CompatibilityResult.fromMap(data);
    } catch (e) {
      return null;
    }
  }

  /// 相性診断を実行
  Future<CompatibilityResult?> runCompatibilityDiagnosis({
    required String friendId,
    required String myCharacterId,
  }) async {
    if (_userId == null) return null;
    try {
      final callable = _functions.httpsCallable('diagnoseCompatibility');
      final result = await callable.call({
        'userId': _userId,
        'friendId': friendId,
        'myCharacterId': myCharacterId,
      });
      final data = result.data as Map<String, dynamic>;
      return CompatibilityResult.fromMap(data);
    } catch (e) {
      return null;
    }
  }
}

/// フレンドコントローラープロバイダー
final friendControllerProvider =
    StateNotifierProvider<FriendController, AsyncValue<void>>((ref) {
  return FriendController(
    ref.watch(firestoreProvider),
    FirebaseFunctions.instanceFor(region: 'asia-northeast1'),
    ref.watch(currentUserIdProvider),
  );
});
