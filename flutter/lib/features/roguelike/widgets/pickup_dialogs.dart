// features/roguelike/widgets/pickup_dialogs.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bag_item.dart';
import '../models/equipment.dart';
import '../providers/roguelike_provider.dart';

/// アイテム入手時の分岐ダイアログ（設計書 §4）。
///
/// - 鞄に空きがある → 「そうびする／このまま」
/// - 鞄が満杯       → 「何を手放すか」＋「諦める」
///
/// **どちらも選択そのものが性格の測定になる**ため、自動処理にはしない。

/// 鞄が満杯で受け取れないときに「何を捨てるか」を選ばせる。
Future<void> showPickupFullDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PickupFullDialog(),
  );
}

/// 拾った装備を「装備するか」選ばせる。
Future<void> showEquipPromptDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _EquipPromptDialog(),
  );
}

class _PickupFullDialog extends ConsumerWidget {
  const _PickupFullDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roguelikeProvider);
    final pendingId = state?.pendingPickupId;
    if (state == null || pendingId == null) {
      // 解決済み（別経路で閉じられた）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    final incoming = BagItem(pendingId);
    final notifier = ref.read(roguelikeProvider.notifier);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Text(incoming.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${incoming.name}を見つけた',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'カバンがいっぱいだ。何かを手放さないと持てない。',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '手放したものは戻らない（行商人なら金貨に換えられた）。',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < state.bag.length; i++)
            _Row(
              item: state.bag[i],
              onTap: () {
                notifier.resolvePickupByDiscard(i);
                Navigator.pop(context);
              },
            ),
          const Divider(height: 20),
          // 「今あるものを守る」ことも一つの選択。強い執着のシグナルになる。
          TextButton(
            onPressed: () {
              notifier.abandonPickup();
              Navigator.pop(context);
            },
            child: Text('${incoming.name}を諦める',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final BagItem item;
  final VoidCallback onTap;

  const _Row({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: const Color(0xFFF5F0E6),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Text(item.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(item.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          if (item.equipped) ...[
                            const SizedBox(width: 5),
                            const Text('（装備中）',
                                style: TextStyle(fontSize: 10, color: Color(0xFF3F8F5E))),
                          ],
                        ],
                      ),
                      Text(item.effectLabel,
                          style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                    ],
                  ),
                ),
                const Text('手放す', style: TextStyle(fontSize: 11.5, color: Color(0xFFC0554A), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EquipPromptDialog extends ConsumerWidget {
  const _EquipPromptDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roguelikeProvider);
    final pendingId = state?.pendingEquipId;
    if (state == null || pendingId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    final incoming = BagItem(pendingId);
    final equipment = incoming.equipment;
    final current = equipment?.kind == EquipKind.weapon ? state.weapon : state.armor;
    final notifier = ref.read(roguelikeProvider.notifier);

    // 既に同種を装備しているかで「持ち替え」か「新規装備」かが変わる。
    final isSwap = current != null;
    final diff = equipment == null ? 0 : equipment.power - (current?.power ?? 0);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Text(incoming.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${incoming.name}を手に入れた',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(incoming.effectDetail,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFC2541E))),
          const SizedBox(height: 10),
          if (isSwap) ...[
            Text('いま装備しているのは ${current.emoji}${current.name}（${current.effectLabel}）。',
                style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 6),
            Text(
              diff > 0
                  ? '持ち替えれば $diff 上がる。外した装備はカバンに残る。'
                  : diff == 0
                      ? '性能は今と変わらない。'
                      : '持ち替えると ${-diff} 下がる。',
              style: TextStyle(
                fontSize: 12,
                color: diff > 0 ? const Color(0xFF3F8F5E) : Colors.grey.shade700,
              ),
            ),
          ] else
            const Text('まだ何も装備していない。', style: TextStyle(fontSize: 12.5)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            notifier.resolvePendingEquip(false);
            Navigator.pop(context);
          },
          child: Text(isSwap ? 'このまま' : 'カバンにしまう'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE0842C),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            notifier.resolvePendingEquip(true);
            Navigator.pop(context);
          },
          child: Text(isSwap ? '持ち替える' : 'そうびする'),
        ),
      ],
    );
  }
}
