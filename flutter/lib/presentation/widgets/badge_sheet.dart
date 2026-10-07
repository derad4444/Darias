import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/badges.dart';
import '../providers/badge_provider.dart';
import '../providers/theme_provider.dart';

/// 成長段階の表示名
String growthStageLabel(int stage) {
  if (stage >= 2) return '大人';
  if (stage >= 1) return '幼少期';
  return '赤ちゃん';
}

/// ホームとキャラクター詳細に置く、バッジの集まり具合のカード
///
/// 今集めている弾の5つのバッジと、それぞれ2問のうち何問答えたかを出す。
/// タップするとバッジ一覧（[showBadgeSheet]）を開く。
class BadgeProgressCard extends ConsumerWidget {
  final Color accentColor;
  final VoidCallback onTap;

  /// true のとき、ホーム用の白背景。false のとき、詳細画面用の半透明背景
  final bool solidBackground;
  final Color textColor;

  /// true のとき1行にまとめる（ホーム用。下のチャット欄と見分けやすくするため、
  /// 入力欄とは違う細長いバーにする）
  final bool compact;

  const BadgeProgressCard({
    super.key,
    required this.accentColor,
    required this.onTap,
    this.solidBackground = true,
    this.textColor = const Color(0xFF333333),
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(badgeStateProvider).valueOrNull ?? const BadgeState();
    final stage = ref.watch(growthStageProvider).valueOrNull ?? 0;
    final round = state.currentRound;
    final allDone = state.isRoundComplete(2);
    final answered = state.answeredCountOfRound(round);
    final total = kBadgeAxes.length * kQuestionsPerBadge;

    final String label;
    if (allDone) {
      label = 'バッジコンプリート';
    } else if (round == 1) {
      label = stage >= 1 ? '第1弾バッジ' : '第1弾バッジで元素が決まる';
    } else {
      label = '第2弾バッジで大人へ';
    }

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    growthStageLabel(stage),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final badge in badgesOfRound(round))
                        _BadgeMedal(
                          badge: badge,
                          progress: state.progressOf(badge.key),
                          accentColor: accentColor,
                          textColor: textColor,
                          size: 28,
                          showName: false,
                        ),
                    ],
                  ),
                ),
                if (!allDone)
                  Text(
                    '$answered/$total',
                    style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.75)),
                  ),
                Icon(Icons.chevron_right, size: 18, color: textColor.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: solidBackground
                ? Colors.white.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: solidBackground
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      growthStageLabel(stage),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: textColor),
                    ),
                  ),
                  if (!allDone)
                    Text(
                      '$answered / $total',
                      style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.8)),
                    ),
                  Icon(Icons.chevron_right, size: 20, color: textColor.withValues(alpha: 0.6)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final badge in badgesOfRound(round))
                    _BadgeMedal(
                      badge: badge,
                      progress: state.progressOf(badge.key),
                      accentColor: accentColor,
                      textColor: textColor,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// バッジ1つの丸いメダルと、2問の進み具合の点
class _BadgeMedal extends StatelessWidget {
  final BadgeDef badge;
  final int progress;
  final Color accentColor;
  final Color textColor;
  final double size;

  /// メダルの下に名前を出すか（一覧では横に名前があるので出さない）
  final bool showName;

  const _BadgeMedal({
    required this.badge,
    required this.progress,
    required this.accentColor,
    required this.textColor,
    this.size = 40,
    this.showName = true,
  });

  @override
  Widget build(BuildContext context) {
    final complete = progress >= kQuestionsPerBadge;
    // 第2弾は金の縁で、第1弾より格上に見せる
    final rimColor = badge.round == 2 ? const Color(0xFFFFB300) : accentColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: complete ? rimColor : Colors.grey.withValues(alpha: 0.18),
            border: Border.all(
              color: complete ? Colors.white : rimColor.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: complete
                ? [BoxShadow(color: rimColor.withValues(alpha: 0.45), blurRadius: 6)]
                : null,
          ),
          child: Icon(
            badge.icon,
            size: size * 0.5,
            color: complete ? Colors.white : rimColor.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < kQuestionsPerBadge; i++)
              Container(
                width: size < 32 ? 4 : 6,
                height: size < 32 ? 4 : 6,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < progress ? rimColor : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
          ],
        ),
        if (showName) ...[
          const SizedBox(height: 2),
          Text(
            badge.name,
            style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.85)),
          ),
        ],
      ],
    );
  }
}

/// バッジ一覧を開き、選んだバッジのキーを返す（閉じたら null）
///
/// 背後の画面が見えるボトムシートで出す。第1弾がそろうまで第2弾は選べない。
/// 取得済みのバッジを選ぶと答え直しになる。
Future<String?> showBadgeSheet(BuildContext context, {required Color accentColor}) {
  return showModalBottomSheet<String>(
    context: context,
    // タブバーより前面に出す（タブの中のナビゲーターだと下端がタブバーに隠れる）
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BadgeSheet(accentColor: accentColor),
  );
}

class _BadgeSheet extends ConsumerWidget {
  final Color accentColor;

  const _BadgeSheet({required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(badgeStateProvider).valueOrNull ?? const BadgeState();
    final round1Done = state.isRoundComplete(1);
    // ほかの画面と同じ背景グラデーションと文字色にする
    final gradient = ref.watch(backgroundGradientProvider);
    final textColor = ref.watch(colorSettingsProvider).textColor;

    // 中途半端な高さで止まらないよう、最初から画面上部まで開く
    return DraggableScrollableSheet(
      initialChildSize: 0.93,
      minChildSize: 0.5,
      maxChildSize: 0.93,
      snap: true,
      expand: false,
      builder: (ctx, scroll) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'バッジ',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 6),
            Text(
              'キャラクターの質問に答えるとバッジが集まります。\n'
              '第1弾がそろうとあなたの元素が決まり、第2弾がそろうと大人に成長します。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7), height: 1.5),
            ),
            const SizedBox(height: 16),
            _RoundHeader(title: '第1弾', done: state.answeredCountOfRound(1), textColor: textColor),
            for (final b in badgesOfRound(1))
              _BadgeRow(badge: b, state: state, accentColor: accentColor, enabled: true, textColor: textColor),
            const SizedBox(height: 16),
            _RoundHeader(
              title: '第2弾',
              done: state.answeredCountOfRound(2),
              note: round1Done ? null : '第1弾がそろうと挑戦できます',
              textColor: textColor,
            ),
            for (final b in badgesOfRound(2))
              _BadgeRow(badge: b, state: state, accentColor: accentColor, enabled: round1Done, textColor: textColor),
          ],
        ),
      ),
    );
  }
}

class _RoundHeader extends StatelessWidget {
  final String title;
  final int done;
  final String? note;
  final Color textColor;

  const _RoundHeader({required this.title, required this.done, this.note, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final total = kBadgeAxes.length * kQuestionsPerBadge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(width: 8),
          Text('$done / $total', style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.6))),
          const Spacer(),
          if (note != null)
            Text(note!, style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  final BadgeDef badge;
  final BadgeState state;
  final Color accentColor;
  final bool enabled;
  final Color textColor;

  const _BadgeRow({
    required this.badge,
    required this.state,
    required this.accentColor,
    required this.enabled,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = state.progressOf(badge.key);
    final complete = progress >= kQuestionsPerBadge;
    final retaking = state.retakeBadge == badge.key;

    final String status;
    if (!enabled) {
      status = '';
    } else if (retaking) {
      status = '答え直し中 ${state.retakeProgressOf(badge.key)} / $kQuestionsPerBadge';
    } else if (complete) {
      status = '答え直す';
    } else {
      status = '$progress / $kQuestionsPerBadge';
    }

    // 背景のグラデーションの上でも読めるよう、1行ずつ半透明の白いカードに載せる
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? () => Navigator.pop(context, badge.key) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Row(
                children: [
                  _BadgeMedal(
                    badge: badge,
                    progress: progress,
                    accentColor: accentColor,
                    textColor: textColor,
                    size: 44,
                    showName: false,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(badge.label,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                        const SizedBox(height: 2),
                        Text(badge.description,
                            style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                  if (status.isNotEmpty)
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 13,
                        color: complete && !retaking ? accentColor : textColor.withValues(alpha: 0.75),
                        fontWeight: complete && !retaking ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  if (enabled) Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.4)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 質問に移る前の確認。背後の画面が見えるダイアログで出す
Future<bool> confirmBadgeTopicChange(BuildContext context, BadgeDef badge, {required bool isRetake}) async {
  final iconColor = badge.round == 2 ? const Color(0xFFFFB300) : Theme.of(context).colorScheme.primary;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Icon(badge.icon, size: 36, color: iconColor),
      content: Text(
        isRetake
            ? '${badge.label}の質問に答え直します。\n話題を変えてもいい？'
            : '${badge.label}の質問に話題を変えます。\nいい？',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('話題を変える')),
      ],
    ),
  );
  return result == true;
}
