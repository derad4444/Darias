import 'package:shared_preferences/shared_preferences.dart';

/// インラインヒントとオンボーディングの表示済みフラグをuserIdごとに管理
class HintService {
  static const _prefix = 'hint_v1';
  static const _onboardingKey = 'onboarding_v1_completed';

  // ── キー定義 ──────────────────────────────────────────
  static const kHome = 'home';
  static const kMemo = 'memo';
  static const kMeeting = 'meeting';
  static const kFriend = 'friend';
  static const kCompatibility = 'compatibility';
  static const kCalendarDiary = 'calendar_diary';

  final String userId;

  HintService(this.userId);

  String _key(String feature) => '${_prefix}_${feature}_$userId';
  String get _onboardingFullKey => '${_onboardingKey}_$userId';

  // ── 汎用 ──────────────────────────────────────────────

  Future<bool> isShown(String feature) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(feature)) ?? false;
  }

  Future<void> markShown(String feature) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(feature), true);
  }

  // ── ホームのステップ管理 ──────────────────────────────

  /// 現在のホームヒントのステップ（0 = 未表示）
  Future<int> getHomeStep() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${_prefix}_home_step_$userId') ?? 0;
  }

  Future<void> setHomeStep(int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_prefix}_home_step_$userId', step);
  }

  // ── オンボーディング ──────────────────────────────────

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingFullKey) ?? false;
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingFullKey, true);
  }

  // ── 日記バッジ管理 ────────────────────────────────────

  /// 最後に確認した日記の日付（YYYY-MM-DD形式）
  Future<DateTime?> getLastSeenDiaryDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('diary_last_seen_$userId');
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  Future<void> setLastSeenDiaryDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'diary_last_seen_$userId',
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    );
  }

  // ── アカウント削除時のクリーンアップ ─────────────────

  static Future<void> clearAllForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final keysToRemove = prefs.getKeys()
        .where((k) => k.endsWith('_$userId'))
        .toList();
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }
}
