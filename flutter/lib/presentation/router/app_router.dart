import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/diary_model.dart';
import '../../data/models/memo_model.dart';
import '../../data/models/schedule_model.dart';
import '../../data/models/todo_model.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/character/character_select_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/big5/big5_diagnosis_screen.dart';
import '../screens/todo/todo_list_screen.dart';
import '../screens/todo/todo_detail_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/calendar/schedule_detail_screen.dart';
import '../screens/diary/diary_list_screen.dart';
import '../screens/diary/diary_detail_screen.dart';
import '../screens/memo/memo_list_screen.dart';
import '../screens/memo/memo_detail_screen.dart';
import '../screens/meeting/meeting_screen.dart';
import '../screens/premium/premium_upgrade_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/profile_edit_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/settings/theme_settings_screen.dart';
import '../screens/settings/help_screen.dart';
import '../screens/settings/data_export_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/statistics/statistics_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/big5/big5_results_screen.dart';
import '../screens/settings/data_import_screen.dart';
import '../screens/character/character_detail_screen.dart';
import '../screens/settings/feedback_screen.dart';
import '../screens/settings/privacy_settings_screen.dart';
import '../screens/settings/about_screen.dart';
import '../screens/auth/change_password_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/meeting/meeting_history_screen.dart';
import '../screens/settings/tag_management_screen.dart';
import '../screens/history/unified_history_screen.dart';
import '../screens/meeting/character_explanation_screen.dart';
import '../screens/settings/volume_settings_screen.dart';
import '../screens/settings/font_settings_screen.dart';

/// ルーター設定
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      if (isLoggedIn && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      // ホーム
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
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

      // チャット
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) => const ChatScreen(),
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
          final todo = state.extra as TodoModel?;
          return TodoDetailScreen(todo: todo);
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
          return ScheduleDetailScreen(
            schedule: schedule,
            initialDate: initialDate,
          );
        },
      ),

      // 日記
      GoRoute(
        path: '/diary',
        name: 'diary',
        builder: (context, state) => const DiaryListScreen(),
      ),

      // 日記詳細
      GoRoute(
        path: '/diary/detail',
        name: 'diary-detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final diary = extra['diary'] as DiaryModel;
          final characterId = extra['characterId'] as String;
          return DiaryDetailScreen(
            diary: diary,
            characterId: characterId,
          );
        },
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
          final memo = state.extra as MemoModel?;
          return MemoDetailScreen(memo: memo);
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

      // プロフィール編集
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileEditScreen(),
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

      // ヘルプ
      GoRoute(
        path: '/help',
        name: 'help',
        builder: (context, state) => const HelpScreen(),
      ),

      // プレミアムアップグレード
      GoRoute(
        path: '/premium',
        name: 'premium',
        builder: (context, state) => const PremiumUpgradeScreen(),
      ),

      // オンボーディング
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // 統計
      GoRoute(
        path: '/statistics',
        name: 'statistics',
        builder: (context, state) => const StatisticsScreen(),
      ),

      // 検索
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),

      // データエクスポート
      GoRoute(
        path: '/data-export',
        name: 'data-export',
        builder: (context, state) => const DataExportScreen(),
      ),

      // BIG5診断結果
      GoRoute(
        path: '/big5/results',
        name: 'big5-results',
        builder: (context, state) => const Big5ResultsScreen(),
      ),

      // データインポート
      GoRoute(
        path: '/data-import',
        name: 'data-import',
        builder: (context, state) => const DataImportScreen(),
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

      // プライバシー設定
      GoRoute(
        path: '/privacy-settings',
        name: 'privacy-settings',
        builder: (context, state) => const PrivacySettingsScreen(),
      ),

      // アバウト
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutScreen(),
      ),

      // パスワード変更
      GoRoute(
        path: '/change-password',
        name: 'change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),

      // パスワードリセット
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // 会議履歴
      GoRoute(
        path: '/meeting-history',
        name: 'meeting-history',
        builder: (context, state) => const MeetingHistoryScreen(),
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

      // キャラクター説明
      GoRoute(
        path: '/character-explanation',
        name: 'character-explanation',
        builder: (context, state) => const CharacterExplanationScreen(),
      ),

      // 音量設定
      GoRoute(
        path: '/volume-settings',
        name: 'volume-settings',
        builder: (context, state) => const VolumeSettingsScreen(),
      ),

      // フォント設定
      GoRoute(
        path: '/font-settings',
        name: 'font-settings',
        builder: (context, state) => const FontSettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('ページが見つかりません: ${state.error}'),
      ),
    ),
  );
});
