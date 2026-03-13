import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/memo_model.dart';
import '../../data/models/schedule_model.dart';
import '../../data/models/todo_model.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/main/main_shell_screen.dart';
import '../screens/character/character_select_screen.dart';
import '../screens/big5/big5_diagnosis_screen.dart';
import '../screens/todo/todo_list_screen.dart';
import '../screens/todo/todo_detail_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/calendar/schedule_detail_screen.dart';
import '../screens/diary/diary_list_screen.dart';
import '../screens/memo/memo_list_screen.dart';
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
import '../screens/splash/splash_screen.dart';

/// ルーター設定
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isSplash = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // スプラッシュ画面は常に通す
      if (isSplash) return null;

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

      // Todo
      GoRoute(
        path: '/todo',
        name: 'todo',
        builder: (context, state) => const TodoListScreen(),
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

      // カレンダー
      GoRoute(
        path: '/calendar',
        name: 'calendar',
        builder: (context, state) => const CalendarScreen(),
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

      // メモ
      GoRoute(
        path: '/memo',
        name: 'memo',
        builder: (context, state) => const MemoListScreen(),
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

    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('ページが見つかりません: ${state.error}'),
      ),
    ),
  );
});
