import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/user_model.dart';
import '../../data/services/analytics_service.dart';
import '../../data/services/last_login_method.dart';
import '../../data/services/social_auth_service.dart';

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

/// Google / Apple のサインインを処理している間だけ true
///
/// サインインが成功した瞬間に認証状態が変わり、ルーターがホームへ飛ばしてしまう。
/// 初回サインインの性別選択を飛ばさないよう、この間だけ自動遷移を止めて、
/// どこへ進むかは画面側（[SocialSignInButtons]）が決める。
final socialSignInInProgressProvider = StateProvider<bool>((ref) => false);

/// Google / Apple でサインインした結果
enum SocialSignInStatus {
  /// そのままホームへ進める
  signedIn,

  /// 初回サインイン。キャラクターの性別を選んでもらってからデータを作る
  needsInitialSetup,

  /// ユーザーが途中でやめた
  canceled,

  /// 同じメールアドレスが既にメール／パスワードで登録済み。
  /// パスワードでサインインしてから連携する必要がある
  needsLink,
}

/// [SocialSignInStatus] と、連携に必要な情報をまとめたもの
class SocialSignInResult {
  const SocialSignInResult(
    this.status, {
    this.pendingCredential,
    this.email,
    this.method,
  });

  final SocialSignInStatus status;

  /// 連携待ちの資格情報（[SocialSignInStatus.needsLink] のときだけ入る）
  final AuthCredential? pendingCredential;

  /// 既に登録されているメールアドレス（[SocialSignInStatus.needsLink] のときだけ入る）
  final String? email;

  /// このとき使おうとしたログイン方法
  final LoginMethod? method;
}

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
        await createInitialUserData(
          userId: credential.user!.uid,
          email: email,
          name: name,
          characterGender: characterGender ?? '女性',
        );
      }

      await LastLoginMethodStore.save(LoginMethod.email);
      await AnalyticsService.instance.logSignUp(method: 'email');

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
      await LastLoginMethodStore.save(LoginMethod.email);
      await AnalyticsService.instance.logLogin(method: 'email');
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
      await SocialAuthService.signOutGoogle();
      await _auth.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Googleでサインインする
  Future<SocialSignInResult> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final credential = await SocialAuthService.googleCredential();
      if (credential == null) {
        state = const AsyncValue.data(null);
        return const SocialSignInResult(SocialSignInStatus.canceled);
      }
      final result = await _signInWithCredential(credential, LoginMethod.google);
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Appleでサインインする
  ///
  /// Appleは資格情報を先に取り出せないので、プロバイダー経由でサインインする。
  Future<SocialSignInResult> signInWithApple() async {
    state = const AsyncValue.loading();
    try {
      final userCredential =
          await _auth.signInWithProvider(SocialAuthService.appleProvider());
      final result = await _afterSocialSignIn(
        userCredential.user!,
        LoginMethod.apple,
      );
      state = const AsyncValue.data(null);
      return result;
    } on FirebaseAuthException catch (e, st) {
      state = const AsyncValue.data(null);
      if (_isCanceled(e.code)) {
        return const SocialSignInResult(SocialSignInStatus.canceled);
      }
      if (e.code == 'account-exists-with-different-credential') {
        return SocialSignInResult(
          SocialSignInStatus.needsLink,
          pendingCredential: e.credential,
          email: e.email,
          method: LoginMethod.apple,
        );
      }
      state = AsyncValue.error(e, st);
      rethrow;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// 既にメール／パスワードで登録済みのアカウントに、Google・Appleを紐づける
  ///
  /// 同じメールアドレスで別々のアカウントができると、キャラクターも購読状態も
  /// 分かれてしまうため、パスワードで本人確認してから1つのアカウントにまとめる。
  Future<SocialSignInResult> linkWithPassword({
    required String email,
    required String password,
    required AuthCredential credential,
    required LoginMethod method,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user!.linkWithCredential(credential);
      final result = await _afterSocialSignIn(userCredential.user!, method);
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// 初回サインインのユーザーに、選んでもらった性別でデータを作る
  Future<void> completeInitialSetup({required String characterGender}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'ログイン状態が確認できませんでした',
      );
    }
    state = const AsyncValue.loading();
    try {
      await createInitialUserData(
        userId: user.uid,
        email: user.email ?? '',
        name: user.displayName,
        characterGender: characterGender,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// ユーザードキュメントとキャラクター詳細を作る
  ///
  /// メール登録・Google・Apple のどの入口でも、ここを必ず通す。
  /// これを作らないと、ログインはできるのに中身が空のユーザーができてしまう。
  Future<void> createInitialUserData({
    required String userId,
    required String email,
    required String characterGender,
    String? name,
  }) async {
    final now = DateTime.now();
    final characterId = const Uuid().v4();

    final user = UserModel(
      id: userId,
      email: email,
      name: name,
      characterGender: characterGender,
      characterId: characterId,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.collection('users').doc(userId).set(user.toMap());

    // iOS版と同様にキャラクター詳細情報を作成
    final characterDetailData = {
      'gender': characterGender,
      'personalityKey': 'O5_C4_A2_E2_N2_$characterGender',
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

  /// 資格情報でサインインし、既存アカウントとの衝突を見分ける
  Future<SocialSignInResult> _signInWithCredential(
    AuthCredential credential,
    LoginMethod method,
  ) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      return _afterSocialSignIn(userCredential.user!, method);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        return SocialSignInResult(
          SocialSignInStatus.needsLink,
          pendingCredential: credential,
          email: e.email,
          method: method,
        );
      }
      rethrow;
    }
  }

  /// サインイン後の共通処理（初回かどうかの判定と計測）
  ///
  /// 初回かどうかは users ドキュメントの有無で見る。認証だけ済んでいて
  /// ドキュメントが無い状態（初回の途中でアプリを閉じた場合など）でも、
  /// もう一度性別選択から作り直せるようにするため。
  Future<SocialSignInResult> _afterSocialSignIn(
    User user,
    LoginMethod method,
  ) async {
    await LastLoginMethodStore.save(method);
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await AnalyticsService.instance.logSignUp(method: method.name);
      return SocialSignInResult(
        SocialSignInStatus.needsInitialSetup,
        method: method,
      );
    }
    await AnalyticsService.instance.logLogin(method: method.name);
    return SocialSignInResult(SocialSignInStatus.signedIn, method: method);
  }

  /// ユーザーが自分でやめたときのエラーコードか
  static bool _isCanceled(String code) {
    return code == 'canceled' ||
        code == 'web-context-canceled' ||
        code == 'user-canceled' ||
        code == 'ERROR_ABORTED_BY_USER';
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

/// ログイン状態が変わるたびに lastLoginAt をFirestoreへ同期
final lastLoginAtSyncProvider = Provider<void>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId != null) {
    Future.microtask(() => FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'lastLoginAt': FieldValue.serverTimestamp()}));
  }
});
