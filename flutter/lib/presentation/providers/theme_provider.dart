import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';

/// テーマモードの状態プロバイダー
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    // TODO: SharedPreferencesからテーマモードを読み込む
    // iOS版はライトモードがデフォルト
    state = ThemeMode.light;
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

/// カラーシードの状態プロバイダー（iOS版互換）
final colorSeedProvider = StateNotifierProvider<ColorSeedNotifier, Color>((ref) {
  return ColorSeedNotifier();
});

class ColorSeedNotifier extends StateNotifier<Color> {
  // iOS版と同じくピンクをデフォルトに
  ColorSeedNotifier() : super(AppColors.primaryPink) {
    _loadColorSeed();
  }

  Future<void> _loadColorSeed() async {
    // TODO: SharedPreferencesからカラーシードを読み込む
    state = AppColors.primaryPink;
  }

  Future<void> setColorSeed(Color color) async {
    state = color;
    // TODO: SharedPreferencesにカラーシードを保存
  }

  // iOS版と同じカラー選択肢
  static const List<Color> availableColors = [
    AppColors.primaryPink,      // ピンク（デフォルト）
    Color(0xFF4A90D9),          // ブルー
    AppColors.mintGreen,        // グリーン
    Color(0xFFFF8C42),          // オレンジ
    Color(0xFF9B59B6),          // パープル
    AppColors.accentGold,       // ゴールド
    Color(0xFF00CED1),          // ターコイズ
    Color(0xFFE91E63),          // マゼンタ
  ];
}

/// カラーテーマプリセットの状態プロバイダー
final colorThemePresetProvider = StateNotifierProvider<ColorThemePresetNotifier, ColorThemePreset>((ref) {
  return ColorThemePresetNotifier();
});

class ColorThemePresetNotifier extends StateNotifier<ColorThemePreset> {
  ColorThemePresetNotifier() : super(ColorThemePreset.pink) {
    _loadPreset();
  }

  Future<void> _loadPreset() async {
    // TODO: SharedPreferencesからプリセットを読み込む
    state = ColorThemePreset.pink;
  }

  Future<void> setPreset(ColorThemePreset preset) async {
    state = preset;
    // TODO: SharedPreferencesにプリセットを保存
  }
}

/// 現在の背景グラデーションを取得するプロバイダー
final backgroundGradientProvider = Provider<LinearGradient>((ref) {
  final colorSettings = ref.watch(colorSettingsProvider);
  return colorSettings.backgroundGradient;
});

/// 現在のアクセントカラーを取得するプロバイダー
final accentColorProvider = Provider<Color>((ref) {
  final colorSettings = ref.watch(colorSettingsProvider);
  return colorSettings.accentColor;
});

/// iOS版ColorSettingsManagerと同等のカラー設定プロバイダー
final colorSettingsProvider = StateNotifierProvider<ColorSettingsNotifier, ColorSettings>((ref) {
  return ColorSettingsNotifier();
});

/// カラー設定の状態
class ColorSettings {
  final bool useGradient;
  final Color backgroundStartColor;
  final Color backgroundEndColor;
  final Color textColor;
  final Color accentColor;

  const ColorSettings({
    this.useGradient = true,
    this.backgroundStartColor = const Color(0xFFFFE5F1), // ソフトピンク
    this.backgroundEndColor = const Color(0xFFE5F3FF), // ライトブルー
    this.textColor = const Color(0xFF2D2D2D), // 濃いグレー
    this.accentColor = const Color(0xFFFF6B9D), // コーラルピンク
  });

  ColorSettings copyWith({
    bool? useGradient,
    Color? backgroundStartColor,
    Color? backgroundEndColor,
    Color? textColor,
    Color? accentColor,
  }) {
    return ColorSettings(
      useGradient: useGradient ?? this.useGradient,
      backgroundStartColor: backgroundStartColor ?? this.backgroundStartColor,
      backgroundEndColor: backgroundEndColor ?? this.backgroundEndColor,
      textColor: textColor ?? this.textColor,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  /// 現在の背景グラデーションを取得
  LinearGradient get backgroundGradient {
    if (useGradient) {
      return LinearGradient(
        colors: [backgroundStartColor, backgroundEndColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return LinearGradient(
        colors: [backgroundStartColor, backgroundStartColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }
}

class ColorSettingsNotifier extends StateNotifier<ColorSettings> {
  ColorSettingsNotifier() : super(const ColorSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // TODO: SharedPreferencesから設定を読み込む
  }

  Future<void> _saveSettings() async {
    // TODO: SharedPreferencesに設定を保存する
  }

  void setUseGradient(bool value) {
    state = state.copyWith(useGradient: value);
    _saveSettings();
  }

  void setBackgroundStartColor(Color color) {
    state = state.copyWith(backgroundStartColor: color);
    _saveSettings();
  }

  void setBackgroundEndColor(Color color) {
    state = state.copyWith(backgroundEndColor: color);
    _saveSettings();
  }

  void setTextColor(Color color) {
    state = state.copyWith(textColor: color);
    _saveSettings();
  }

  void setAccentColor(Color color) {
    state = state.copyWith(accentColor: color);
    _saveSettings();
  }

  void resetToDefault() {
    state = const ColorSettings();
    _saveSettings();
  }
}
