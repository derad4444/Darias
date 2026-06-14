import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/memo_model.dart';
import '../../data/models/schedule_model.dart';
import '../../data/models/todo_model.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/main/main_shell_screen.dart';
import '../screens/character/character_select_screen.dart';
import '../screens/todo/todo_detail_screen.dart';
import '../screens/calendar/schedule_detail_screen.dart';
import '../screens/memo/memo_detail_screen.dart';
import '../screens/meeting/meeting_screen.dart';
import '../screens/premium/premium_upgrade_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/settings/theme_settings_screen.dart';
import '../screens/character/character_detail_screen.dart';
import '../screens/settings/feedback_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/settings/tag_management_screen.dart';
import '../screens/history/unified_history_screen.dart';
import '../screens/settings/volume_settings_screen.dart';
import '../screens/settings/terms_of_service_screen.dart';
import '../screens/settings/privacy_policy_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/settings/help_guide_screen.dart';
import '../screens/character/character_animation_test_screen.dart';
import '../screens/character/personality_history_screen.dart';
// [ローグライク試作] 削除時はこのimport3行とルート3行を消す
import '../../features/roguelike/screens/roguelike_home_screen.dart';
import '../../features/roguelike/screens/roguelike_game_screen.dart';
import '../../features/roguelike/screens/roguelike_result_screen.dart';

/// 新規登録直後にオンボーディングへ誘導するフラグ
/// redirect内で読み取られ、/onboardingへのリダイレクト後にクリアされる
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
    redirect: (context, state) {
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
      final isSplash = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // スプラッシュ・オンボーディング画面は常に通す
      if (isSplash) return null;
      if (state.matchedLocation == '/onboarding') return null;

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      if (isLoggedIn && isAuthRoute) {
        if (ref.read(needsOnboardingProvider)) {
          Future.microtask(() => ref.read(needsOnboardingProvider.notifier).state = false);
          return '/onboarding';
        }
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

      // キャラクター選択
      GoRoute(
        path: '/character-select',
        name: 'character-select',
        builder: (context, state) => const CharacterSelectScreen(),
      ),

      // Todo詳細
      GoRoute(
        path: '/todo/detail',
        name: 'todo-detail',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is TodoModel) {
            return TodoDetailScreen(todo: extra);
          }
          final map = extra as Map<String, dynamic>?;
          return TodoDetailScreen(
            todo: null,
            initialTag: map?['initialTag'] as String? ?? '',
          );
        },
      ),

      // スケジュール詳細
      GoRoute(
        path: '/calendar/detail',
        name: 'schedule-detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final schedule = extra?['schedule'] as ScheduleModel?;
          final initialDate = extra?['initialDate'] as DateTime?;
          final recurringEditMode = extra?['recurringEditMode'] as RecurringEditMode? ?? RecurringEditMode.single;
          return ScheduleDetailScreen(
            schedule: schedule,
            initialDate: initialDate,
            recurringEditMode: recurringEditMode,
          );
        },
      ),

      // メモ詳細
      GoRoute(
        path: '/memo/detail',
        name: 'memo-detail',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is MemoModel) {
            return MemoDetailScreen(memo: extra);
          }
          final map = extra as Map<String, dynamic>?;
          return MemoDetailScreen(
            memo: null,
            initialTag: map?['initialTag'] as String? ?? '',
          );
        },
      ),

      // 6人会議
      GoRoute(
        path: '/meeting',
        name: 'meeting',
        builder: (context, state) => const MeetingScreen(),
      ),

      // 設定
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // 通知設定
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
        builder: (context, state) => const PremiumUpgradeScreen(),
      ),

      // キャラクター詳細
      GoRoute(
        path: '/character/:id',
        name: 'character-detail',
        builder: (context, state) {
          final characterId = state.pathParameters['id']!;
          return CharacterDetailScreen(characterId: characterId);
        },
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


      // タグ管理
      GoRoute(
        path: '/tag-management',
        name: 'tag-management',
        builder: (context, state) => const TagManagementScreen(),
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
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // 使い方ガイド
      GoRoute(
        path: '/help-guide',
        name: 'help-guide',
        builder: (context, state) => const HelpGuideScreen(),
      ),

      // キャラクターアニメーションテスト
      GoRoute(
        path: '/character-animation-test',
        name: 'character-animation-test',
        builder: (context, state) => const CharacterAnimationTestScreen(),
      ),

      // [ローグライク試作] 削除時はこのGoRoute3つを消す
      GoRoute(
        path: '/roguelike',
        name: 'roguelike',
        builder: (context, state) => const RoguelikeHomeScreen(),
      ),
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

    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('ページが見つかりません: ${state.error}'),
      ),
    ),
  );
});
