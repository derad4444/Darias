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
import '../screens/big5/big5_diagnosis_screen.dart';
import '../screens/todo/todo_detail_screen.dart';
import '../screens/calendar/schedule_detail_screen.dart';
import '../screens/diary/diary_list_screen.dart';
import '../screens/memo/memo_detail_screen.dart';
import '../screens/meeting/meeting_screen.dart';
import '../screens/premium/premium_upgrade_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/settings/theme_settings_screen.dart';
import '../screens/settings/data_export_screen.dart';
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

      // BIG5診断
      GoRoute(
        path: '/big5',
        name: 'big5',
        builder: (context, state) => const Big5DiagnosisScreen(),
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

      // 日記
      GoRoute(
        path: '/diary',
        name: 'diary',
        builder: (context, state) => const DiaryListScreen(),
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

      // データエクスポート
      GoRoute(
        path: '/data-export',
        name: 'data-export',
        builder: (context, state) => const DataExportScreen(),
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
          final characterId = state.extra as String?;
          return UnifiedHistoryScreen(characterId: characterId);
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

    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('ページが見つかりません: ${state.error}'),
      ),
    ),
  );
});
