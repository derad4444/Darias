// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class PlatformStorage {
  static Future<Set<String>> loadStringSet(String key) async {
    final value = html.window.localStorage[key];
    if (value == null || value.isEmpty) return {};
    return value.split(',').where((s) => s.isNotEmpty).toSet();
  }

  static Future<void> saveStringSet(String key, Set<String> values) async {
    if (values.isEmpty) {
      html.window.localStorage.remove(key);
    } else {
      html.window.localStorage[key] = values.join(',');
    }
  }
}
