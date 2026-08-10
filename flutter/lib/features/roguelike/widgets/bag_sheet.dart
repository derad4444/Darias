// features/roguelike/widgets/bag_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bag_item.dart';
import '../models/game_state.dart';
import '../providers/roguelike_provider.dart';
import 'dungeon_theme.dart';

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

class _BagSheet extends ConsumerWidget {
  const _BagSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roguelikeProvider);
    if (state == null) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: kRoguelikeCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Text('🎒', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                const Text('鞄', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(
                  '${state.bagUsed} / ${state.bagCapacity}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: state.bagIsFull ? Colors.red : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '装備している武器・防具も枠を使う。売れるのは行商人だけ。',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (state.bag.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('鞄は空っぽだ。', style: TextStyle(color: Colors.grey))),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: state.bag.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _BagRow(state: state, index: i),
                ),
              ),
            // 空き枠を点線で見せる（あと何個持てるかを直感的に）
            if (state.bagFree > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < state.bagFree; i++)
                    Container(
                      width: 26,
                      height: 26,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Text('空き${state.bagFree}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BagRow extends ConsumerWidget {
  final GameState state;
  final int index;

  const _BagRow({required this.state, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = state.bag[index];
    final notifier = ref.read(roguelikeProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: item.equipped
            ? const Color(0xFF6E9BE6).withValues(alpha: 0.10)
            : const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(14),
        border: item.equipped
            ? Border.all(color: const Color(0xFF6E9BE6).withValues(alpha: 0.45))
            : null,
      ),
      child: Row(
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    if (item.equipped) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6E9BE6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('装備中', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                Text(item.effectLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          // 装備 / 外す / 使う
          if (item.isEquipment)
            _SmallButton(
              label: item.equipped ? '外す' : '装備',
              onTap: () => item.equipped
                  ? notifier.unequipFromBag(index)
                  : notifier.equipFromBag(index),
            )
          else if (item.isPotion)
            _SmallButton(
              label: '使う',
              // 満タンで飲むと無駄になるだけなので押させない
              onTap: state.hp >= state.maxHp
                  ? null
                  : () => notifier.usePotionFromBag(index),
            )
          else if (item.isTreasureMap)
            _SmallButton(
              label: '使う',
              onTap: () => notifier.useTreasureMapFromBag(index),
            ),
          const SizedBox(width: 6),
          _SmallButton(
            label: '捨てる',
            danger: true,
            onTap: () => _confirmDiscard(context, ref, item),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref, BagItem item) async {
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
    if (ok == true) {
      ref.read(roguelikeProvider.notifier).discardFromBag(index);
    }
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  const _SmallButton({required this.label, this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : const Color(0xFF6E9BE6);
    final enabled = onTap != null;
    return Material(
      color: enabled ? color.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: enabled ? color : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
