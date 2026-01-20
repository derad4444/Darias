import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// フォント設定プロバイダー
final fontSettingsProvider =
    StateNotifierProvider<FontSettingsNotifier, FontSettings>((ref) {
  return FontSettingsNotifier();
});

class FontSettings {
  final double fontSize;
  final String fontFamily;
  final double lineHeight;

  const FontSettings({
    this.fontSize = 1.0,
    this.fontFamily = 'system',
    this.lineHeight = 1.5,
  });

  FontSettings copyWith({
    double? fontSize,
    String? fontFamily,
    double? lineHeight,
  }) {
    return FontSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }

  /// フォントサイズの説明
  String get fontSizeLabel {
    if (fontSize <= 0.8) return '小';
    if (fontSize <= 0.9) return 'やや小';
    if (fontSize <= 1.1) return '標準';
    if (fontSize <= 1.2) return 'やや大';
    return '大';
  }
}

class FontSettingsNotifier extends StateNotifier<FontSettings> {
  FontSettingsNotifier() : super(const FontSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = FontSettings(
      fontSize: prefs.getDouble('fontSize') ?? 1.0,
      fontFamily: prefs.getString('fontFamily') ?? 'system',
      lineHeight: prefs.getDouble('lineHeight') ?? 1.5,
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', state.fontSize);
    await prefs.setString('fontFamily', state.fontFamily);
    await prefs.setDouble('lineHeight', state.lineHeight);
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size);
    _save();
  }

  void setFontFamily(String family) {
    state = state.copyWith(fontFamily: family);
    _save();
  }

  void setLineHeight(double height) {
    state = state.copyWith(lineHeight: height);
    _save();
  }

  void reset() {
    state = const FontSettings();
    _save();
  }
}

/// フォント設定画面
class FontSettingsScreen extends ConsumerWidget {
  const FontSettingsScreen({super.key});

  static const _fontFamilies = [
    ('system', 'システムフォント'),
    ('noto_sans_jp', 'Noto Sans JP'),
    ('rounded', '丸ゴシック'),
    ('mincho', '明朝体'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(fontSettingsProvider);
    final notifier = ref.read(fontSettingsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('フォント設定'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: () => notifier.reset(),
            child: const Text('リセット'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // フォントサイズ
          _SectionHeader(title: 'フォントサイズ'),
          _FontSizeSection(
            value: settings.fontSize,
            onChanged: notifier.setFontSize,
          ),
          const SizedBox(height: 24),

          // フォントファミリー
          _SectionHeader(title: 'フォントの種類'),
          _FontFamilySection(
            selectedFamily: settings.fontFamily,
            onChanged: notifier.setFontFamily,
            families: _fontFamilies,
          ),
          const SizedBox(height: 24),

          // 行間
          _SectionHeader(title: '行間'),
          _LineHeightSection(
            value: settings.lineHeight,
            onChanged: notifier.setLineHeight,
          ),
          const SizedBox(height: 24),

          // プレビュー
          _SectionHeader(title: 'プレビュー'),
          _PreviewSection(settings: settings),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _FontSizeSection extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _FontSizeSection({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('A', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Slider(
                  value: value,
                  min: 0.7,
                  max: 1.4,
                  divisions: 7,
                  onChanged: onChanged,
                ),
              ),
              const Text('A', style: TextStyle(fontSize: 24)),
            ],
          ),
          Text(
            _getSizeLabel(value),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  String _getSizeLabel(double value) {
    if (value <= 0.8) return '小';
    if (value <= 0.9) return 'やや小';
    if (value <= 1.1) return '標準';
    if (value <= 1.2) return 'やや大';
    return '大';
  }
}

class _FontFamilySection extends StatelessWidget {
  final String selectedFamily;
  final ValueChanged<String> onChanged;
  final List<(String, String)> families;

  const _FontFamilySection({
    required this.selectedFamily,
    required this.onChanged,
    required this.families,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: families.map((family) {
        final isSelected = selectedFamily == family.$1;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: ListTile(
            title: Text(family.$2),
            subtitle: Text(
              'これはサンプルテキストです',
              style: _getFontStyle(family.$1),
            ),
            trailing: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () => onChanged(family.$1),
          ),
        );
      }).toList(),
    );
  }

  TextStyle _getFontStyle(String family) {
    // フォントファミリーに応じたスタイルを返す
    // 実際のフォントファミリー設定は省略（システムに依存）
    return const TextStyle();
  }
}

class _LineHeightSection extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _LineHeightSection({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.format_line_spacing, size: 18),
              Expanded(
                child: Slider(
                  value: value,
                  min: 1.0,
                  max: 2.0,
                  divisions: 10,
                  onChanged: onChanged,
                ),
              ),
              const Icon(Icons.format_line_spacing, size: 28),
            ],
          ),
          Text(
            '${(value * 100).toInt()}%',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  final FontSettings settings;

  const _PreviewSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseFontSize = 14 * settings.fontSize;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '見出しテキスト',
            style: TextStyle(
              fontSize: baseFontSize * 1.5,
              fontWeight: FontWeight.bold,
              height: settings.lineHeight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'これはプレビュー用のサンプルテキストです。'
            'フォントサイズと行間の設定がここに反映されます。'
            '読みやすさを確認しながら調整してください。',
            style: TextStyle(
              fontSize: baseFontSize,
              height: settings.lineHeight,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '補足テキスト（小さめ）',
            style: TextStyle(
              fontSize: baseFontSize * 0.85,
              color: colorScheme.onSurfaceVariant,
              height: settings.lineHeight,
            ),
          ),
        ],
      ),
    );
  }
}
