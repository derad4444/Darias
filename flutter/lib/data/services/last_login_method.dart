import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 前回のログイン方法（ログイン画面に「前回はこちら」と出すために保存する）
///
/// 未ログインの状態ではFirestoreを読めないため、端末に残すしかない。
/// アプリを入れ直したり別の端末で開いた初回は表示されない。
enum LoginMethod {
  email('password', 'メールアドレス'),
  google('google.com', 'Google'),
  apple('apple.com', 'Apple');

  const LoginMethod(this.providerId, this.label);

  /// Firebase Auth のプロバイダーID
  final String providerId;

  /// 画面に出す名前
  final String label;

  static LoginMethod? fromProviderId(String? providerId) {
    for (final method in LoginMethod.values) {
      if (method.providerId == providerId) return method;
    }
    return null;
  }
}

/// 前回のログイン方法を端末に保存する
class LastLoginMethodStore {
  static const _key = 'last_login_method';

  static Future<void> save(LoginMethod method) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, method.providerId);
    } catch (e) {
      // 表示のための補助情報なので、保存に失敗してもログインは続行する
      debugPrint('前回のログイン方法を保存できませんでした: $e');
    }
  }

  static Future<LoginMethod?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return LoginMethod.fromProviderId(prefs.getString(_key));
    } catch (e) {
      debugPrint('前回のログイン方法を読み込めませんでした: $e');
      return null;
    }
  }
}
