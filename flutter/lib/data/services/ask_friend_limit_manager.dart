import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「フレンドのことを聞く」機能の無料利用制限（1日1回）を管理
class AskFriendLimitManager {
  static const int freeUsagePerDay = 1;
  static const String _dateKey = 'ask_friend_date';
  static const String _countKey = 'ask_friend_count';

  String get _todayString => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<int> getTodayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_dateKey) ?? '';
    if (savedDate != _todayString) return 0;
    return prefs.getInt(_countKey) ?? 0;
  }

  Future<void> increment() async {
    final prefs = await SharedPreferences.getInstance();
    final count = await getTodayCount();
    await prefs.setString(_dateKey, _todayString);
    await prefs.setInt(_countKey, count + 1);
  }

  Future<bool> canUseFree() async {
    final count = await getTodayCount();
    return count < freeUsagePerDay;
  }
}
