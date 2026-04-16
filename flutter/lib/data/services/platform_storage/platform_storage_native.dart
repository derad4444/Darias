import 'package:shared_preferences/shared_preferences.dart';

class PlatformStorage {
  static Future<Set<String>> loadStringSet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(key) ?? [];
    return Set.from(ids);
  }

  static Future<void> saveStringSet(String key, Set<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    if (values.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setStringList(key, values.toList());
    }
  }
}
