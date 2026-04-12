import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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

  /// フレンド申請を送る
  Future<void> sendFriendRequest({
    required String toUserId,
    required String toUserName,
    required String myName,
    required String myEmail,
  }) async {
    if (_userId == null) return;
    state = const AsyncValue.loading();
    try {
      // 既にフレンドか確認
      final friendDoc = await _firestore
          .collection('users').doc(_userId)
          .collection('friends').doc(toUserId)
          .get();
      if (friendDoc.exists) {
        state = const AsyncValue.data(null);
        return;
      }

      // 既に申請済みか確認（outgoingRequests）
      final existing = await _firestore
          .collection('users').doc(_userId)
          .collection('outgoingRequests').doc(toUserId)
          .get();
      if (existing.exists) {
        state = const AsyncValue.data(null);
        return;
      }

      final requestId = const Uuid().v4();
      final now = DateTime.now();
      final requestData = FriendRequestModel(
        id: requestId,
        fromUserId: _userId,
        fromUserName: myName,
        fromUserEmail: myEmail,
        toUserId: toUserId,
        toUserName: toUserName,
        status: FriendRequestStatus.pending,
        createdAt: now,
      ).toMap();

      final batch = _firestore.batch();

      // 相手の受信ボックスに書き込む
      batch.set(
        _firestore.collection('users').doc(toUserId)
            .collection('incomingRequests').doc(_userId),
        requestData,
      );

      // 自分の送信ボックスに書き込む
      batch.set(
        _firestore.collection('users').doc(_userId)
            .collection('outgoingRequests').doc(toUserId),
        requestData,
      );

      await batch.commit();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// フレンド申請を承認
  Future<void> acceptFriendRequest(FriendRequestModel request) async {
    if (_userId == null) return;
    state = const AsyncValue.loading();
    try {
      // 自分のfriendDocを取得
      final myDoc = await _firestore.collection('users').doc(_userId).get();
      final myData = myDoc.data() ?? {};

      final batch = _firestore.batch();

      // 申請ドキュメントを削除（両者）
      batch.delete(
        _firestore.collection('users').doc(_userId)
            .collection('incomingRequests').doc(request.fromUserId),
      );
      batch.delete(
        _firestore.collection('users').doc(request.fromUserId)
            .collection('outgoingRequests').doc(_userId),
      );

      // 自分のフレンドリストに追加
      batch.set(
        _firestore.collection('users').doc(_userId)
            .collection('friends').doc(request.fromUserId),
        FriendModel(
          id: request.fromUserId,
          name: request.fromUserName,
          email: request.fromUserEmail,
          shareLevel: FriendShareLevel.none,
          createdAt: DateTime.now(),
        ).toMap(),
      );

      // 相手のフレンドリストに追加
      batch.set(
        _firestore.collection('users').doc(request.fromUserId)
            .collection('friends').doc(_userId),
        FriendModel(
          id: _userId,
          name: myData['name'] as String? ?? '',
          email: myData['email'] as String? ?? '',
          shareLevel: FriendShareLevel.none,
          createdAt: DateTime.now(),
        ).toMap(),
      );

      await batch.commit();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// フレンド申請を拒否
  Future<void> rejectFriendRequest(FriendRequestModel request) async {
    if (_userId == null) return;
    try {
      final batch = _firestore.batch();
      // 自分の受信ボックスから削除
      batch.delete(
        _firestore.collection('users').doc(_userId)
            .collection('incomingRequests').doc(request.fromUserId),
      );
      // 相手の送信ボックスから削除
      batch.delete(
        _firestore.collection('users').doc(request.fromUserId)
            .collection('outgoingRequests').doc(_userId),
      );
      await batch.commit();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// フレンド申請を取消（送信側）
  Future<void> cancelFriendRequest(FriendRequestModel request) async {
    if (_userId == null) return;
    try {
      final batch = _firestore.batch();
      // 自分の送信ボックスから削除
      batch.delete(
        _firestore.collection('users').doc(_userId)
            .collection('outgoingRequests').doc(request.toUserId),
      );
      // 相手の受信ボックスから削除
      batch.delete(
        _firestore.collection('users').doc(request.toUserId)
            .collection('incomingRequests').doc(_userId),
      );
      await batch.commit();
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
