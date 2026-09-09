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
import '../screens/meeting/meeting_screen.dart';
import '../screens/premium/premium_upgrade_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/settings/login_methods_screen.dart';
import '../screens/settings/theme_settings_screen.dart';
import '../screens/settings/feedback_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/history/unified_history_screen.dart';
import '../screens/settings/volume_settings_screen.dart';
import '../screens/settings/terms_of_service_screen.dart';
import '../screens/settings/privacy_policy_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/settings/help_guide_screen.dart';
import '../screens/character/personality_history_screen.dart';
// [ローグライク試作] 削除時はこのimport4行とルート4行を消す
import '../../features/roguelike/screens/roguelike_game_screen.dart';
import '../../features/roguelike/screens/roguelike_result_screen.dart';
import '../../features/roguelike/screens/roguelike_history_screen.dart';
import '../../features/roguelike/screens/roguelike_codex_screen.dart';
import '../../features/roguelike/screens/roguelike_enemy_detail_screen.dart';
import '../../features/roguelike/models/enemy.dart' show Enemy;

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

      // 6人会議
      GoRoute(
        path: '/meeting',
        name: 'meeting',
        builder: (context, state) => const MeetingScreen(),
      ),

      // 通知設定
      // ログイン方法の管理（連携・解除）
      GoRoute(
        path: '/login-methods',
        name: 'login-methods',
        builder: (context, state) => const LoginMethodsScreen(),
      ),

      GoRoute(
        path: '/notification-settings',
        name: 'notification-settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),

      // テーマ設定
      GoRoute(
        path: '/theme-settings',
        name: 'theme-settings',
        builder: (context, state) => const ThemeSettingsScreen(),
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

      // 性格変動履歴
      GoRoute(
        path: '/character/:id/personality-history',
        name: 'personality-history',
        builder: (context, state) {
          final characterId = state.pathParameters['id']!;
          return PersonalityHistoryScreen(characterId: characterId);
        },
      ),

      // フィードバック
      GoRoute(
        path: '/feedback',
        name: 'feedback',
        builder: (context, state) => const FeedbackScreen(),
      ),

      // パスワードリセット
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),


      // 統合履歴
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) {
          final extra = state.extra;
          final String? characterId;
          final int initialTab;
          if (extra is Map<String, dynamic>) {
            characterId = extra['characterId'] as String?;
            initialTab = extra['initialTab'] as int? ?? 0;
          } else {
            characterId = extra as String?;
            initialTab = 0;
          }
          return UnifiedHistoryScreen(characterId: characterId, initialTab: initialTab);
        },
      ),

      // 音量設定
      GoRoute(
        path: '/volume-settings',
        name: 'volume-settings',
        builder: (context, state) => const VolumeSettingsScreen(),
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

      // 使い方ガイド
      GoRoute(
        path: '/help-guide',
        name: 'help-guide',
        builder: (context, state) => const HelpGuideScreen(),
      ),


      // [ローグライク試作] 削除時はこのGoRouteを消す
      //
      // ダンジョン選択（RoguelikeHomeScreen）は冒険タブ（`/` のシェル内）だけに置く。
      // 単独ルートとしても開けるようにすると、そこへ入った人はタブバーを失って
      // 他の画面へ移動できなくなる。
      GoRoute(
        path: '/roguelike/game',
        name: 'roguelike-game',
        builder: (context, state) => const RoguelikeGameScreen(),
      ),
      GoRoute(
        path: '/roguelike/result',
        name: 'roguelike-result',
        builder: (context, state) => const RoguelikeResultScreen(),
      ),
      GoRoute(
        path: '/roguelike/history',
        name: 'roguelike-history',
        builder: (context, state) => const RoguelikeHistoryScreen(),
      ),
      GoRoute(
        path: '/roguelike/codex',
        name: 'roguelike-codex',
        builder: (context, state) => const RoguelikeCodexScreen(),
      ),
      GoRoute(
        path: '/roguelike/codex/enemy',
        name: 'roguelike-codex-enemy',
        builder: (context, state) {
          final enemy = state.extra as Enemy?;
          if (enemy == null) return const RoguelikeCodexScreen();
          return RoguelikeEnemyDetailScreen(enemy: enemy);
        },
      ),

    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('ページが見つかりません: ${state.error}'),
      ),
    ),
  );
});
