import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dream_provider.dart';
import '../providers/theme_provider.dart';

/// 夢を選ぶシート
///
/// AIが性格から生成した候補と、ユーザー自身の言葉での自由入力を同じ画面に置く。
/// 既に叶えたい夢がある人はそれを入力でき、候補を見て思いついた人も書き換えられる。
///
/// 保存に成功したら選ばれた夢を返す。キャンセル時は null を返す。
class DreamSelectSheet extends ConsumerStatefulWidget {
  /// 選択肢として表示する候補
  final List<String> options;

  /// 現在採用中の夢（初期選択に使う）
  final String currentDream;

  /// 見出し
  final String title;

  /// 見出しの下の補足文
  final String? subtitle;

  const DreamSelectSheet({
    super.key,
    required this.options,
    this.currentDream = '',
    this.title = '夢を選ぶ',
    this.subtitle,
  });

  /// ボトムシートとして表示する
  static Future<String?> show(
    BuildContext context, {
    required List<String> options,
    String currentDream = '',
    String title = '夢を選ぶ',
    String? subtitle,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DreamSelectSheet(
        options: options,
        currentDream: currentDream,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  ConsumerState<DreamSelectSheet> createState() => _DreamSelectSheetState();
}

class _DreamSelectSheetState extends ConsumerState<DreamSelectSheet> {
  /// 選択中の候補。null は「自分で入力する」を選んでいる状態
  String? _selected;
  bool _isCustom = false;
  bool _isSaving = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final current = widget.currentDream.trim();
    // 「自分で入力する」を選んだときに今の夢から書き直せるよう、候補にあるかに
    // かかわらず入力欄の初期値にしておく
    _controller = TextEditingController(text: current);

    if (current.isNotEmpty && !widget.options.contains(current)) {
      // 現在の夢が候補に無い＝過去に自由入力したものなので入力状態で開く
      _isCustom = true;
    } else {
      _selected = current.isNotEmpty
          ? current
          : (widget.options.isNotEmpty ? widget.options.first : null);
      // 候補が1つも無いときは自由入力しか手段がないので最初から開いておく
      _isCustom = widget.options.isEmpty;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _resolvedDream =>
      _isCustom ? DreamService.sanitize(_controller.text) : (_selected ?? '');

  bool get _canSave => _resolvedDream.isNotEmpty && !_isSaving;

  Future<void> _save() async {
    final dream = _resolvedDream;
    if (dream.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(dreamServiceProvider).selectDream(dream);
      if (mounted) Navigator.pop(context, dream);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('夢の保存に失敗しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    // ホーム画面と同じ背景にして、開いたときの色の落差をなくす
    final gradient = ref.watch(backgroundGradientProvider);
    // ユーザーが濃い色を設定している場合に文字が読めなくなるのを防ぐ
    final isDarkBackground = gradient.colors
            .map((c) => c.computeLuminance())
            .reduce((a, b) => a + b) /
        gradient.colors.length <
        0.4;
    final textColor = isDarkBackground ? Colors.white : theme.colorScheme.onSurface;
    final subTextColor = textColor.withValues(alpha: 0.7);

    return SafeArea(
      top: false,
      child: Padding(
        // キーボードに隠されないようにする
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  // 閉じる手段が下スワイプしかないと「やめたい」ときに迷うため、
                  // 明示的な戻るボタンを左に置く。呼び出し元は null を受け取る。
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      color: textColor,
                      iconSize: 22,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      tooltip: '戻る',
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  // タイトルを中央に保つため、戻るボタンと同じ幅を右にも取る
                  const SizedBox(width: 40),
                ],
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: subTextColor),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final option in widget.options)
                        _OptionRow(
                          label: option,
                          selected: !_isCustom && _selected == option,
                          accent: accent,
                          textColor: textColor,
                          onTap: _isSaving
                              ? null
                              : () => setState(() {
                                    _selected = option;
                                    _isCustom = false;
                                    FocusScope.of(context).unfocus();
                                  }),
                        ),
                      _OptionRow(
                        label: '自分で入力する',
                        selected: _isCustom,
                        accent: accent,
                        textColor: textColor,
                        onTap: _isSaving
                            ? null
                            : () => setState(() => _isCustom = true),
                      ),
                      if (_isCustom)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 8),
                          child: TextField(
                            controller: _controller,
                            autofocus: true,
                            enabled: !_isSaving,
                            maxLength: kDreamMaxLength,
                            inputFormatters: [
                              // 改行を含めるとプロンプトの行構造を壊すため1行に制限
                              FilteringTextInputFormatter.deny(RegExp(r'\n')),
                            ],
                            decoration: const InputDecoration(
                              hintText: '例: 世界中を旅して回ること',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _canSave ? _save : null,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('この夢にする'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 夢の候補1行（RadioListTile の非推奨APIを避けた自前実装）
class _OptionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final Color textColor;
  final VoidCallback? onTap;

  const _OptionRow({
    required this.label,
    required this.selected,
    required this.accent,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? accent : textColor.withValues(alpha: 0.45),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
