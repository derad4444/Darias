import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/user_model.dart';

/// Firebase Auth インスタンス
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Firestore インスタンス
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// 認証状態の監視
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// 現在のユーザーID
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});

/// ユーザードキュメントの監視
final userDocProvider = StreamProvider<UserModel?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);

  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  });
});

/// 認証コントローラー
class AuthController extends StateNotifier<AsyncValue<void>> {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthController(this._auth, this._firestore) : super(const AsyncValue.data(null));

  /// メールアドレスでサインアップ
  Future<void> signUp({
    required String email,
    required String password,
    String? name,
    String? characterGender,
  }) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ユーザードキュメントを作成
      if (credential.user != null) {
        final userId = credential.user!.uid;
        final now = DateTime.now();

        // iOS版と同様にcharacterIdを生成
        final characterId = const Uuid().v4();
        final gender = characterGender ?? '女性';

        final user = UserModel(
          id: userId,
          email: email,
          name: name,
          characterGender: gender,
          characterId: characterId,
          createdAt: now,
          updatedAt: now,
        );

        // ユーザードキュメントを保存
        await _firestore
            .collection('users')
            .doc(userId)
            .set(user.toMap());

        // iOS版と同様にキャラクター詳細情報を作成
        final characterDetailData = {
          'gender': gender,
          'personalityKey': 'O5_C4_A2_E2_N2_$gender',
          'confirmedBig5Scores': {
            'openness': 5,
            'conscientiousness': 4,
            'agreeableness': 2,
            'extraversion': 2,
            'neuroticism': 2,
          },
          'analysis_level': 0,
          'points': 0,
          'created_at': Timestamp.fromDate(now),
          'updated_at': Timestamp.fromDate(now),
        };

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('characters')
            .doc(characterId)
            .collection('details')
            .doc('current')
            .set(characterDetailData);
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// メールアドレスでサインイン
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// サインアウト
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _auth.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// パスワードリセットメール送信
  Future<void> sendPasswordResetEmail(String email) async {
    state = const AsyncValue.loading();
    try {
      await _auth.sendPasswordResetEmail(email: email);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// 認証コントローラーのプロバイダー
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});
