// features/roguelike/widgets/bag_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bag_item.dart';
import '../models/game_state.dart';
import '../providers/roguelike_provider.dart';

// 鞄の中＝革のカバンの内側をイメージした、オレンジ→茶のグラデーション。
// 上を明るいオレンジ、下を深い茶にして、口から奥へ向かって暗くなる立体感を出す。
// 2色が近いとベタ塗りに見えるため、明度差を大きく取り中間色も挟む。
const Color _kBagBgTop = Color(0xFFE8A661);
const Color _kBagBgMid = Color(0xFFC07C42);
const Color _kBagBgBottom = Color(0xFF6E4020);
const Color _kBagCard = Color(0xFFFDF4E6); // 生成りのカード
const Color _kBagAccent = Color(0xFFE0842C);
const Color _kBagText = Color(0xFF4A3520);

/// 鞄（インベントリ）のボトムシート。
///
/// **探索中・戦闘中を問わずいつでも開ける。** 装備は元素を持たない（`power` のみ）ため、
/// 敵を見てから持ち替えても有利にならず、戦闘中の変更を制限する必要がない。
///
/// 「捨てる」はここからいつでもできる。「売る」は行商人でのみ可能（半額）。
/// 商人ノードは10分の2しか出ないため、「行商人まで持ち堪えるか、今ここで捨てるか」
/// という判断が生まれる。
Future<void> showBagSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _BagSheet(),
  );
}

class _BagSheet extends ConsumerStatefulWidget {
  const _BagSheet();

  @override
  ConsumerState<_BagSheet> createState() => _BagSheetState();
}

class _BagSheetState extends ConsumerState<_BagSheet> {
  /// 詳細パネルに出しているスロット。中身が減ったら自動で補正する。
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roguelikeProvider);
    if (state == null) return const SizedBox.shrink();

    final hasSelection = _selected < state.bag.length;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBagBgTop, _kBagBgMid, _kBagBgBottom],
          stops: [0.0, 0.45, 1.0],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _header(context, state),
              const SizedBox(height: 12),
              _slots(state),
              const SizedBox(height: 10),
              _capacityHint(state),
              const SizedBox(height: 12),
              _foodSection(state),
              const SizedBox(height: 12),
              if (hasSelection)
                _detail(context, state, _selected)
              else
                _emptyDetail(),
            ],
          ),
        ),
      ),
    );
  }

  // ── ヘッダー（タイトル・所持数・閉じる） ──────────────────
  Widget _header(BuildContext context, GameState state) {
    return Row(
      children: [
        const SizedBox(width: 40),
        Expanded(
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🎒', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 8),
                  Text(
                    'カバン',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '所持数  ${state.bagUsed} / ${state.bagCapacity}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: state.bagIsFull ? Colors.red : _kBagText,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 40,
          child: Align(
            alignment: Alignment.topRight,
            child: Material(
              color: Colors.white.withValues(alpha: 0.9),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.close, size: 20, color: _kBagText),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── スロット一覧（容量ぶん並べ、空きは点線＋） ──────────────
  Widget _slots(GameState state) {
    return Row(
      children: [
        for (var i = 0; i < state.bagCapacity; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: i < state.bag.length
                  ? _FilledSlot(
                      item: state.bag[i],
                      selected: i == _selected,
                      onTap: () => setState(() => _selected = i),
                    )
                  : const _EmptySlot(),
            ),
          ),
      ],
    );
  }

  Widget _capacityHint(GameState state) {
    final free = state.bagFree;
    return Text(
      free > 0 ? 'あと $free 個まで持てます' : 'いっぱいです。何かを手放そう',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: free > 0 ? Colors.white : const Color(0xFFFFD9D9),
      ),
    );
  }

  // ── 食料（スタック・枠を使わない別枠） ──────────────────
  //
  // 食料は個数で持つ消耗品で、イベントで自動的に減る（選んで使うものではない）。
  // アイテム枠を奪うと鞄が食料で埋まってしまうため、**容量には数えない**別枠に置く。
  Widget _foodSection(GameState state) {
    final food = state.food;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kBagCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBagAccent.withValues(alpha: 0.3)),
            ),
            child: const Center(child: Text('🍞', style: TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('食料',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kBagText)),
                    const SizedBox(width: 8),
                    Text('$food',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: food <= 1 ? Colors.red : _kBagText,
                        )),
                    const SizedBox(width: 2),
                    const Text('個', style: TextStyle(fontSize: 11, color: _kBagText)),
                  ],
                ),
                Text(
                  food <= 0
                      ? '食料が尽きている。足りない分は体力で払うことになる。'
                      : '道中で自動的に消費される。カバンの枠は使わない。',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: food <= 0 ? const Color(0xFFC0554A) : _kBagText.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const _Badge(text: 'まとめて所持', color: Color(0xFF7A6A55)),
        ],
      ),
    );
  }

  Widget _emptyDetail() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: _kBagCard.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: Text('カバンは空っぽだ。', style: TextStyle(color: _kBagText)),
      ),
    );
  }

  // ── 詳細パネル ──────────────────────────────────────
  Widget _detail(BuildContext context, GameState state, int index) {
    final item = state.bag[index];
    final notifier = ref.read(roguelikeProvider.notifier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBagCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBagAccent.withValues(alpha: 0.35)),
                ),
                child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 36))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kBagText),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _Badge(text: item.categoryLabel, color: _kBagAccent),
                        if (item.equipped) ...[
                          const SizedBox(width: 5),
                          const _Badge(text: '装備中', color: Color(0xFF3F8F5E)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.description,
                      style: const TextStyle(fontSize: 12, height: 1.5, color: _kBagText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.effectDetail,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFC2541E)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (item.isEquipment)
                _ActionButton(
                  label: item.equipped ? 'はずす' : 'そうびする',
                  onTap: () => item.equipped
                      ? notifier.unequipFromBag(index)
                      : notifier.equipFromBag(index),
                )
              else if (item.isPotion)
                _ActionButton(
                  label: 'つかう',
                  // 満タンで飲んでも無駄になるだけなので押させない
                  onTap: state.hp >= state.maxHp ? null : () => notifier.usePotionFromBag(index),
                )
              else if (item.isTreasureMap)
                _ActionButton(
                  label: 'つかう',
                  onTap: () => notifier.useTreasureMapFromBag(index),
                ),
              const Spacer(),
              _ActionButton(
                label: 'すてる',
                danger: true,
                onTap: () => _confirmDiscard(context, item, index),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '行商人に会えれば 金貨${item.sellPrice} で売れる',
            style: TextStyle(fontSize: 10.5, color: _kBagText.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context, BagItem item, int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('${item.name}を捨てる'),
        content: Text(
          '${item.name}を手放しますか？\n\n'
          '捨てたものは戻ってきません。行商人がいれば金貨${item.sellPrice}で売れます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('やめる'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('捨てる', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      ref.read(roguelikeProvider.notifier).discardFromBag(index);
      // 末尾を捨てると選択位置が範囲外になるので手前に寄せる
      setState(() => _selected = _selected.clamp(0, 99));
    }
  }
}

// ── スロット ────────────────────────────────────────────

class _FilledSlot extends StatelessWidget {
  final BagItem item;
  final bool selected;
  final VoidCallback onTap;

  const _FilledSlot({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.82,
      child: Material(
        color: _kBagCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? _kBagAccent : Colors.brown.withValues(alpha: 0.18),
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Stack(
              children: [
                Center(child: Text(item.emoji, style: const TextStyle(fontSize: 26))),
                if (item.equipped)
                  Positioned(
                    right: 3,
                    top: 3,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF3F8F5E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 9, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.82,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Icon(Icons.add, color: Colors.white.withValues(alpha: 0.55), size: 22),
      ),
    );
  }
}

// ── 部品 ────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  const _ActionButton({required this.label, this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFC0554A) : _kBagAccent;
    final enabled = onTap != null;
    return Material(
      color: enabled ? color.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: enabled ? color : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
