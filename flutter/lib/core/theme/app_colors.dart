import 'package:flutter/material.dart';

/// iOS版と同じカラーテーマ
class AppColors {
  AppColors._();

  // メインカラー - ピンク系
  static const Color primaryPink = Color(0xFFFF6B9D); // コーラルピンク
  static const Color secondaryLavender = Color(0xFFC44AC0); // ラベンダー
  static const Color accentGold = Color(0xFFFFD93D); // ゴールド

  // サブカラー
  static const Color softPeach = Color(0xFFFFAAA7); // ピーチ
  static const Color mintGreen = Color(0xFF6BCF7F); // ミント
  static const Color dustyRose = Color(0xFFD4A5A5); // ダスティローズ
  static const Color creamWhite = Color(0xFFFFF8F3); // クリーム

  // グラデーション用背景色
  static const Color backgroundGradient1 = Color(0xFFFFE5F1); // ソフトピンク
  static const Color backgroundGradient2 = Color(0xFFE5F3FF); // ライトブルー
  static const Color backgroundGradient3 = Color(0xFFF0E5FF); // ライトラベンダー

  // テキスト色
  static const Color textPrimary = Color(0xFF2D2D2D); // 濃いグレー
  static const Color textSecondary = Color(0xFF6B6B6B); // ミディアムグレー
  static const Color textLight = Color(0xFFA0A0A0); // ライトグレー

  // カード背景
  static Color cardBackground = Colors.white.withValues(alpha: 0.9);
  static Color cardShadow = Colors.black.withValues(alpha: 0.05);

  /// メイングラデーション（背景用）
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [backgroundGradient1, backgroundGradient2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// ボタン用グラデーション
  static const LinearGradient primaryButtonGradient = LinearGradient(
    colors: [primaryPink, secondaryLavender],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// カードシャイングラデーション
  static LinearGradient cardShineGradient = LinearGradient(
    colors: [
      Colors.white.withValues(alpha: 0.3),
      Colors.white.withValues(alpha: 0.1),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// アクセントハイライトグラデーション
  static const LinearGradient accentHighlightGradient = LinearGradient(
    colors: [accentGold, softPeach],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// カラーテーマのプリセット
class ColorThemePreset {
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final LinearGradient backgroundGradient;

  const ColorThemePreset({
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundGradient,
  });

  /// デフォルト（ピンク系）
  static const pink = ColorThemePreset(
    name: 'ピンク',
    primaryColor: AppColors.primaryPink,
    secondaryColor: AppColors.secondaryLavender,
    backgroundGradient: LinearGradient(
      colors: [AppColors.backgroundGradient1, AppColors.backgroundGradient2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// ブルー系
  static const blue = ColorThemePreset(
    name: 'ブルー',
    primaryColor: Color(0xFF4A90D9),
    secondaryColor: Color(0xFF7B68EE),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFFE5F3FF), Color(0xFFF0E5FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// グリーン系
  static const green = ColorThemePreset(
    name: 'グリーン',
    primaryColor: Color(0xFF6BCF7F),
    secondaryColor: Color(0xFF4ECDC4),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFFE5FFE5), Color(0xFFE5FFFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// オレンジ系
  static const orange = ColorThemePreset(
    name: 'オレンジ',
    primaryColor: Color(0xFFFF8C42),
    secondaryColor: Color(0xFFFFD93D),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFFFFF5E5), Color(0xFFFFE5F1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// パープル系
  static const purple = ColorThemePreset(
    name: 'パープル',
    primaryColor: Color(0xFF9B59B6),
    secondaryColor: Color(0xFF8E44AD),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFFF0E5FF), Color(0xFFFFE5F1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// 利用可能なプリセット一覧
  static const List<ColorThemePreset> availablePresets = [
    pink,
    blue,
    green,
    orange,
    purple,
  ];
}
