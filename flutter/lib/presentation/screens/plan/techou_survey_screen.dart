import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../providers/survey_provider.dart';
import '../../providers/theme_provider.dart';

/// 手帳タブを開いたときに、内容の上に浮かせて表示する「連絡＋アンケート」ポップアップ。
///
/// 回答は必須。送信すると [techouSurveyAnsweredProvider]（端末ローカル）が true になり、
/// 以降は表示されない。回答するまでは手帳の内容の上に出続ける。
/// 手帳の内容の上に半透明の背景＋中央のカードとして表示される（[PlanScreen] が Stack で重ねる）。
class TechouSurveyPopup extends ConsumerStatefulWidget {
  const TechouSurveyPopup({super.key});

  @override
  ConsumerState<TechouSurveyPopup> createState() => _TechouSurveyPopupState();
}

class _TechouSurveyPopupState extends ConsumerState<TechouSurveyPopup> {
  final _commentController = TextEditingController();
  SurveyChoice? _selected;
  bool _isSubmitting = false;
  static const int _maxCommentLength = 500;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final choice = _selected;
    if (choice == null || _isSubmitting) return;
    if (_commentController.text.length > _maxCommentLength) return;

    setState(() => _isSubmitting = true);

    try {
      String appVersion = '不明';
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version} (${info.buildNumber})';
      } catch (_) {}

      final platform = kIsWeb
          ? 'web'
          : (Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other'));

      await ref.read(surveyDatasourceProvider).submitTechouSurvey(
            choice: choice.name,
            choiceLabel: choice.label,
            comment: _commentController.text.trim(),
            appVersion: appVersion,
            platform: platform,
          );

      // ローカルに回答済みを記録 → ポップアップが閉じて手帳内容が見える
      await ref.read(techouSurveyAnsweredProvider.notifier).markAnswered();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ご回答ありがとうございました！')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('送信に失敗しました。時間をおいて再度お試しください。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 他画面と同じテーマ色（アクセント／文字色／背景グラデーション）に合わせる
    final accentColor = ref.watch(accentColorProvider);
    final textColor = ref.watch(colorSettingsProvider).textColor;
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final onCard = textColor;
    final onCardSoft = textColor.withValues(alpha: 0.6);
    final fieldBg = textColor.withValues(alpha: 0.08);

    final canSubmit = _selected != null &&
        !_isSubmitting &&
        _commentController.text.length <= _maxCommentLength;

    final maxH = MediaQuery.of(context).size.height * 0.8;

    return Stack(
      children: [
        // 背景（手帳内容を暗くする）。タップは吸収するが閉じない＝回答して初めて閉じる
        Positioned.fill(
          child: GestureDetector(
            onTap: () {},
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
          ),
        ),
        // 中央のポップアップカード
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 440, maxHeight: maxH),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: backgroundGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── 見出し（固定）──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Row(
                        children: [
                          Icon(Icons.campaign_outlined, color: accentColor, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '手帳タブについてご意見をください',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: onCard,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── スクロールする中身（連絡文・選択肢・コメント）──
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: fieldBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              '現在、手帳タブの削除を検討しています。\n'
                              '代わりに、性格診断を活かした新しいゲーム機能を開発中です。\n\n'
                              'ただ、まだ迷っている段階です。今後の開発の参考にしたいので、'
                              'みなさんのご意見をぜひ聞かせてください。',
                              style: TextStyle(fontSize: 14, height: 1.6, color: onCard.withValues(alpha: 0.9)),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'あなたのご意見に近いものを選んでください',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: onCard),
                          ),
                          const SizedBox(height: 10),
                          ...SurveyChoice.values.map((choice) => _ChoiceTile(
                                label: choice.label,
                                selected: _selected == choice,
                                onCard: onCard,
                                fieldBg: fieldBg,
                                accentColor: accentColor,
                                onTap: () => setState(() => _selected = choice),
                              )),
                          const SizedBox(height: 18),
                          Text(
                            '自由コメント（任意）',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: onCard),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: fieldBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                            ),
                            child: TextField(
                              controller: _commentController,
                              maxLines: 3,
                              style: TextStyle(color: onCard),
                              decoration: InputDecoration(
                                hintText: 'ご意見・ご要望があればお書きください',
                                hintStyle: TextStyle(color: onCardSoft),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(12),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${_commentController.text.length} / $_maxCommentLength',
                              style: TextStyle(
                                fontSize: 12,
                                color: _commentController.text.length > _maxCommentLength
                                    ? Colors.red
                                    : onCardSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── ボタン（固定）──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: canSubmit ? _submit : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: accentColor.withValues(alpha: 0.35),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('送信して手帳を見る',
                                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Color onCard;
  final Color fieldBg;
  final Color accentColor;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onCard,
    required this.fieldBg,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? accentColor.withValues(alpha: 0.14) : fieldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? accentColor : onCard.withValues(alpha: 0.15),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? accentColor : onCard.withValues(alpha: 0.4),
                size: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: onCard,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
