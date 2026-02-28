import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/theme_provider.dart';

/// iOS版ColorSettingsViewと同じデザインのカラー設定画面
class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final colorSettings = ref.watch(colorSettingsProvider);
    final textColor = colorSettings.textColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text('カラー設定', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              '完了',
              style: TextStyle(
                color: colorSettings.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // 背景タイプ選択
              _SettingsSection(
                title: '背景タイプ',
                textColor: textColor,
                child: _BackgroundTypePicker(
                  useGradient: colorSettings.useGradient,
                  onChanged: (value) {
                    ref.read(colorSettingsProvider.notifier).setUseGradient(value);
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 背景色設定
              _SettingsSection(
                title: '背景色',
                textColor: textColor,
                child: Column(
                  children: [
                    _ColorPickerRow(
                      label: colorSettings.useGradient ? '開始色' : '背景色',
                      color: colorSettings.backgroundStartColor,
                      textColor: textColor,
                      onColorChanged: (color) {
                        ref.read(colorSettingsProvider.notifier).setBackgroundStartColor(color);
                      },
                    ),
                    if (colorSettings.useGradient) ...[
                      const SizedBox(height: 12),
                      _ColorPickerRow(
                        label: '終了色',
                        color: colorSettings.backgroundEndColor,
                        textColor: textColor,
                        onColorChanged: (color) {
                          ref.read(colorSettingsProvider.notifier).setBackgroundEndColor(color);
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 文字色設定
              _SettingsSection(
                title: '',
                textColor: textColor,
                child: _ColorPickerRow(
                  label: '文字色',
                  color: colorSettings.textColor,
                  textColor: textColor,
                  onColorChanged: (color) {
                    ref.read(colorSettingsProvider.notifier).setTextColor(color);
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ボタン色設定
              _SettingsSection(
                title: '',
                textColor: textColor,
                child: _ColorPickerRow(
                  label: 'ボタン色',
                  color: colorSettings.accentColor,
                  textColor: textColor,
                  onColorChanged: (color) {
                    ref.read(colorSettingsProvider.notifier).setAccentColor(color);
                  },
                ),
              ),

              const SizedBox(height: 24),

              // デフォルトに戻すボタン
              GestureDetector(
                onTap: () {
                  ref.read(colorSettingsProvider.notifier).resetToDefault();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'デフォルトに戻す',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// 設定セクション
class _SettingsSection extends StatelessWidget {
  final String title;
  final Color textColor;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.textColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// 背景タイプピッカー（グラデーション/一色）
class _BackgroundTypePicker extends StatelessWidget {
  final bool useGradient;
  final ValueChanged<bool> onChanged;

  const _BackgroundTypePicker({
    required this.useGradient,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: useGradient ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'グラデーション',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: useGradient ? FontWeight.w600 : FontWeight.normal,
                    color: useGradient ? Colors.black : Colors.black54,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !useGradient ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '一色',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: !useGradient ? FontWeight.w600 : FontWeight.normal,
                    color: !useGradient ? Colors.black : Colors.black54,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// カラーピッカー行
class _ColorPickerRow extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final ValueChanged<Color> onColorChanged;

  const _ColorPickerRow({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: textColor,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _showColorPicker(context),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ColorPickerSheet(
        initialColor: color,
        onColorSelected: onColorChanged,
      ),
    );
  }
}

/// カラーピッカーシート
class _ColorPickerSheet extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const _ColorPickerSheet({
    required this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late Color _selectedColor;

  // プリセットカラー
  static const List<Color> _presetColors = [
    Color(0xFFFFE5F1), // ソフトピンク
    Color(0xFFE5F3FF), // ライトブルー
    Color(0xFFF0E5FF), // ライトラベンダー
    Color(0xFFE5FFE5), // ライトグリーン
    Color(0xFFFFF5E5), // ライトオレンジ
    Color(0xFFFFFFFF), // ホワイト
    Color(0xFFFF6B9D), // コーラルピンク
    Color(0xFF4A90D9), // ブルー
    Color(0xFF9B59B6), // パープル
    Color(0xFF6BCF7F), // グリーン
    Color(0xFFFF8C42), // オレンジ
    Color(0xFFFFD93D), // ゴールド
    Color(0xFF2D2D2D), // ダークグレー
    Color(0xFF6B6B6B), // ミディアムグレー
    Color(0xFFA0A0A0), // ライトグレー
    Color(0xFF000000), // ブラック
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ハンドル
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // タイトル
          const Text(
            'カラーを選択',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // カラーグリッド
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _presetColors.map((color) {
              final isSelected = _selectedColor.value == color.value;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedColor = color);
                  widget.onColorSelected(color);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: color.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
