import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// テーマモードの状態プロバイダー
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    // TODO: SharedPreferencesからテーマモードを読み込む
    // 現在はシステム設定を使用
    state = ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    // TODO: SharedPreferencesにテーマモードを保存
  }

  String get themeModeLabel {
    switch (state) {
      case ThemeMode.system:
        return 'システム設定に従う';
      case ThemeMode.light:
        return 'ライトモード';
      case ThemeMode.dark:
        return 'ダークモード';
    }
  }
}

/// カラーシードの状態プロバイダー
final colorSeedProvider = StateNotifierProvider<ColorSeedNotifier, Color>((ref) {
  return ColorSeedNotifier();
});

class ColorSeedNotifier extends StateNotifier<Color> {
  ColorSeedNotifier() : super(Colors.deepPurple) {
    _loadColorSeed();
  }

  Future<void> _loadColorSeed() async {
    // TODO: SharedPreferencesからカラーシードを読み込む
    state = Colors.deepPurple;
  }

  Future<void> setColorSeed(Color color) async {
    state = color;
    // TODO: SharedPreferencesにカラーシードを保存
  }

  static const List<Color> availableColors = [
    Colors.deepPurple,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.indigo,
  ];
}
