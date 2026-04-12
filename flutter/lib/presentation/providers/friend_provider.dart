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

/// 受信したフレンド申請プロバイダー
final incomingFriendRequestsProvider = StreamProvider<List<FriendRequestModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return ref
      .watch(firestoreProvider)
      .collection('friendRequests')
      .where('toUserId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(FriendRequestModel.fromFirestore).toList());
});

/// 送信したフレンド申請プロバイダー
final outgoingFriendRequestsProvider = StreamProvider<List<FriendRequestModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return ref
      .watch(firestoreProvider)
      .collection('friendRequests')
      .where('fromUserId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
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

  /// ユーザー検索（名前 or メールアドレス）
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty || _userId == null) return [];

    final isEmail = query.contains('@');
    QuerySnapshot snap;

    if (isEmail) {
      snap = await _firestore
          .collection('users')
          .where('email', isEqualTo: query.trim())
          .limit(10)
          .get();
    } else {
      // 前方一致検索
      snap = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '${query}z')
          .limit(10)
          .get();
    }

    return snap.docs
        .where((doc) => doc.id != _userId)
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] as String? ?? '',
            'email': data['email'] as String? ?? '',
          };
        })
        .toList();
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
      // 既に申請済みか確認
      final existing = await _firestore
          .collection('friendRequests')
          .where('fromUserId', isEqualTo: _userId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existing.docs.isNotEmpty) {
        state = const AsyncValue.data(null);
        return;
      }

      // 既にフレンドか確認
      final friendDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('friends')
          .doc(toUserId)
          .get();

      if (friendDoc.exists) {
        state = const AsyncValue.data(null);
        return;
      }

      await _firestore.collection('friendRequests').add(
        FriendRequestModel(
          id: '',
          fromUserId: _userId,
          fromUserName: myName,
          fromUserEmail: myEmail,
          toUserId: toUserId,
          status: FriendRequestStatus.pending,
          createdAt: DateTime.now(),
        ).toMap(),
      );
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
      final batch = _firestore.batch();

      // 申請ステータスを更新
      batch.update(
        _firestore.collection('friendRequests').doc(request.id),
        {'status': 'accepted'},
      );

      // 自分のフレンドリストに追加
      batch.set(
        _firestore.collection('users').doc(_userId).collection('friends').doc(request.fromUserId),
        FriendModel(
          id: request.fromUserId,
          name: request.fromUserName,
          email: request.fromUserEmail,
          shareLevel: FriendShareLevel.none,
          createdAt: DateTime.now(),
        ).toMap(),
      );

      // 相手のフレンドリストにも追加（相手のname/emailを取得）
      final myDoc = await _firestore.collection('users').doc(_userId).get();
      final myData = myDoc.data() ?? {};
      batch.set(
        _firestore.collection('users').doc(request.fromUserId).collection('friends').doc(_userId),
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
  Future<void> rejectFriendRequest(String requestId) async {
    state = const AsyncValue.loading();
    try {
      await _firestore
          .collection('friendRequests')
          .doc(requestId)
          .update({'status': 'rejected'});
      state = const AsyncValue.data(null);
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
          .collection('users')
          .doc(_userId)
          .collection('friends')
          .doc(friendId)
          .update({'shareLevel': level.value});
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// フレンドのBIG5スコアを取得
  Future<Map<String, double>?> fetchFriendBig5(String friendId) async {
    try {
      // フレンドのキャラクターIDを取得
      final userDoc = await _firestore.collection('users').doc(friendId).get();
      final userData = userDoc.data();
      final characterId = userData?['character_id'] as String?;
      if (characterId == null) return null;

      // BIG5スコアを取得
      final detailDoc = await _firestore
          .collection('users')
          .doc(friendId)
          .collection('characters')
          .doc(characterId)
          .collection('details')
          .doc('current')
          .get();

      final detailData = detailDoc.data();
      final scoresMap = detailData?['confirmedBig5Scores'] as Map<String, dynamic>?;
      if (scoresMap == null) return null;

      return {
        'openness': (scoresMap['openness'] as num?)?.toDouble() ?? 3,
        'conscientiousness': (scoresMap['conscientiousness'] as num?)?.toDouble() ?? 3,
        'extraversion': (scoresMap['extraversion'] as num?)?.toDouble() ?? 3,
        'agreeableness': (scoresMap['agreeableness'] as num?)?.toDouble() ?? 3,
        'neuroticism': (scoresMap['neuroticism'] as num?)?.toDouble() ?? 3,
      };
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
