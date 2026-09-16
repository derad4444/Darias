import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/analytics_service.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/character_gender_screen.dart';
import '../screens/main/main_shell_screen.dart';
import '../screens/character/character_select_screen.dart';
import '../screens/premium/premium_upgrade_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/settings/terms_of_service_screen.dart';
import '../screens/settings/privacy_policy_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';

/// 新規登録直後にオンボーディングへ誘導するフラグ
/// MainShellScreen が読み取り、ホームの上に /onboarding を push した時点でクリアされる
final needsOnboardingProvider = StateProvider<bool>((ref) => false);

/// Auth状態変化をGoRouterに通知するChangeNotifier
/// ルーターを再生成せずにredirectだけ再評価させるために使用
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    _subscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final _authChangeNotifierProvider = Provider<_AuthChangeNotifier>((ref) {
  final notifier = _AuthChangeNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// ルーター設定
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_authChangeNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    // 画面遷移を screen_view として自動送信する。
    // 各 GoRoute に name を付けているため、画面名は path ではなく name で記録される。
    observers: [AnalyticsService.instance.navigatorObserver],
    redirect: (context, state) {
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
      final isSplash = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // スプラッシュ・オンボーディング画面は常に通す
      if (isSplash) return null;
      if (state.matchedLocation == '/onboarding') return null;

      // 初回サインインの性別選択は、終わるまで他の画面へ行かせない
      // （ユーザードキュメントが無いままホームへ進むと、中身が空で表示が壊れる）
      if (state.matchedLocation == '/character-gender') {
        return isLoggedIn ? null : '/login';
      }

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      if (isLoggedIn && isAuthRoute) {
        // Google / Apple の処理中は画面側が行き先を決める
        // （初回なら性別選択へ、2回目以降はホームへ）
        if (ref.read(socialSignInInProgressProvider)) return null;

        // オンボーディングはホームの上に重ねるため、ここではホームへ送るだけにする。
        // フラグは MainShellScreen が読み取り、/onboarding を push する。
        return '/';
      }

      return null;
    },
    routes: [
      // スプラッシュ
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // メイン（5タブ構成）
      //
      // タブの中身（ホーム・自分会議・詳細・フレンド・設定）は単独ルートを持たせない。
      // 単独ルートとしても開けるようにすると、そこへ入った人はタブバーを失って
      // 他の画面へ移動できなくなる。
      GoRoute(
        path: '/',
        name: 'main',
        builder: (context, state) => const MainShellScreen(),
      ),

      // 認証
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // 初回サインイン時のキャラクター性別選択（Google / Apple で登録した人向け）
      GoRoute(
        path: '/character-gender',
        name: 'character-gender',
        builder: (context, state) => const CharacterGenderScreen(),
      ),

      // キャラクター選択
      GoRoute(
        path: '/character-select',
        name: 'character-select',
        builder: (context, state) => const CharacterSelectScreen(),
      ),




      // プレミアムアップグレード
      GoRoute(
        path: '/premium',
        name: 'premium',
        // source は「どの導線から課金画面に来たか」の計測用（個人情報ではない）
        builder: (context, state) => PremiumUpgradeScreen(
          source: state.uri.queryParameters['source'] ?? 'unknown',
        ),
      ),



      // パスワードリセット
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),




      // 利用規約
      GoRoute(
        path: '/terms',
        name: 'terms',
        builder: (context, state) => const TermsOfServiceScreen(),
      ),

      // プライバシーポリシー
      GoRoute(
        path: '/privacy',
        name: 'privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),

      // オンボーディング
      // ホーム画面の上にダイアログとして重ねるため、背景が透ける非不透明ページで開く。
      // 必ず push で開くこと（go だとホームが下に残らず、背景が黒くなる）。
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          opaque: false,
          barrierDismissible: false,
          transitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          child: const OnboardingScreen(),
        ),
      ),


    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('ページが見つかりません: ${state.error}'),
      ),
    ),
  );
});
