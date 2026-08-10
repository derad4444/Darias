// features/roguelike/widgets/merchant_shop_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bag_item.dart';
import '../models/equipment.dart';
import '../models/game_event.dart';
import '../models/game_state.dart';
import '../providers/roguelike_provider.dart';
import 'bag_sheet.dart';

/// 行商人の店（設計書 §7.2）。
///
/// 通常のイベントは1回選ぶと終わるが、店は**「立ち去る」を選ぶまで**
/// 買う・売る・鞄を開くを繰り返せる。
///
/// **「売る」は行商人でしかできない。**「捨てる」は鞄からいつでもできるので、
/// 「行商人まで持ち堪えるか、今ここで捨てるか」という駆け引きが生まれる。
class MerchantShopView extends ConsumerStatefulWidget {
  final GameEvent event;
  const MerchantShopView({super.key, required this.event});

  @override
  ConsumerState<MerchantShopView> createState() => _MerchantShopViewState();
}

/// 店で開いている画面。
enum _ShopPane { top, weapons, armors, sell }

class _MerchantShopViewState extends ConsumerState<MerchantShopView> {
  _ShopPane _pane = _ShopPane.top;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roguelikeProvider);
    if (state == null) return const SizedBox.shrink();
    final notifier = ref.read(roguelikeProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.event.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                Text(widget.event.description,
                    style: const TextStyle(height: 1.6, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stat('💰 金貨', '${state.money}'),
                    const SizedBox(width: 10),
                    _stat('🎒 カバン', '${state.bagUsed}/${state.bagCapacity}',
                        warn: state.bagIsFull),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              switch (_pane) {
                _ShopPane.top => 'どうする？　（立ち去るまで何度でも取引できる）',
                _ShopPane.weapons => 'どの武器を買う？',
                _ShopPane.armors => 'どの防具を買う？',
                _ShopPane.sell => '何を売る？　（買値の半分で買い取る）',
              },
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
            ),
          ),
          ...switch (_pane) {
            _ShopPane.top => _topPane(state, notifier),
            _ShopPane.weapons => _buyPane(state, notifier, Equipments.weapons),
            _ShopPane.armors => _buyPane(state, notifier, Equipments.armors),
            _ShopPane.sell => _sellPane(state, notifier),
          },
        ],
      ),
    );
  }

  // ── トップ ───────────────────────────────────────────
  List<Widget> _topPane(GameState state, RoguelikeNotifier notifier) {
    final canBuyPotion = state.money >= BagItem.priceOf(kPotionId) && !state.bagIsFull;
    final canBuyMap = state.money >= BagItem.priceOf(kTreasureMapId) && !state.bagIsFull;
    return [
      _row(
        emoji: '⚔️',
        title: '武器を買う',
        sub: '木の枝💰2 ／ 鉄の剣💰5 ／ 名刀💰9',
        onTap: () => setState(() => _pane = _ShopPane.weapons),
      ),
      _row(
        emoji: '🛡️',
        title: '防具を買う',
        sub: '布の服💰2 ／ 鉄の鎧💰5 ／ 聖なるローブ💰9',
        onTap: () => setState(() => _pane = _ShopPane.armors),
      ),
      _row(
        emoji: '🧪',
        title: '回復薬を買う（💰3）',
        sub: state.bagIsFull ? 'カバンがいっぱい' : 'HPを回復する。カバンを1枠使う',
        onTap: canBuyPotion ? () => notifier.buyFromMerchant(kPotionId) : null,
      ),
      _row(
        emoji: '🗺️',
        title: '宝の地図を買う（💰2）',
        sub: state.bagIsFull ? 'カバンがいっぱい' : '使うと宝箱の位置が分かる。カバンを1枠使う',
        onTap: canBuyMap ? () => notifier.buyFromMerchant(kTreasureMapId) : null,
      ),
      _row(
        emoji: '💰',
        title: '売る',
        sub: state.bag.isEmpty ? '売れるものがない' : '買値の半分で買い取ってもらえる',
        onTap: state.bag.isEmpty ? null : () => setState(() => _pane = _ShopPane.sell),
      ),
      _row(
        emoji: '🎒',
        title: 'カバンを開く',
        sub: '装備を変える・使う・捨てる',
        onTap: () => showBagSheet(context),
      ),
      const SizedBox(height: 4),
      _row(
        emoji: '👋',
        title: '立ち去る',
        sub: '取引を終えて先へ進む',
        onTap: () => notifier.closeEvent(),
      ),
    ];
  }

  // ── 武器・防具の種類選択 ────────────────────────────
  List<Widget> _buyPane(GameState state, RoguelikeNotifier notifier, List<Equipment> items) {
    return [
      for (final e in items)
        _row(
          emoji: e.emoji,
          title: '${e.name}（💰${e.price}）',
          sub: _buySubText(state, e),
          onTap: (state.money >= e.price && !state.bagIsFull)
              ? () {
                  notifier.buyFromMerchant(e.id);
                  setState(() => _pane = _ShopPane.top);
                }
              : null,
        ),
      const SizedBox(height: 4),
      _row(emoji: '↩️', title: '戻る', sub: '', onTap: () => setState(() => _pane = _ShopPane.top)),
    ];
  }

  String _buySubText(GameState state, Equipment e) {
    if (state.bagIsFull) return 'カバンがいっぱいで買えない';
    if (state.money < e.price) return '金貨が足りない';
    final current = e.kind == EquipKind.weapon ? state.weapon : state.armor;
    final base = e.effectLabel;
    if (current == null) return base;
    final diff = e.power - current.power;
    if (diff > 0) return '$base（今より $diff 強い）';
    if (diff == 0) return '$base（今と同じ強さ）';
    return '$base（今より ${-diff} 弱い）';
  }

  // ── 売る ─────────────────────────────────────────────
  List<Widget> _sellPane(GameState state, RoguelikeNotifier notifier) {
    return [
      for (var i = 0; i < state.bag.length; i++)
        _row(
          emoji: state.bag[i].emoji,
          title: '${state.bag[i].name} を売る（+💰${state.bag[i].sellPrice}）',
          sub: state.bag[i].equipped
              ? '装備中。売ると外れる'
              : state.bag[i].effectLabel,
          onTap: () {
            notifier.sellToMerchant(i);
            // 最後の1つを売ったらトップへ戻す
            if (state.bag.length <= 1) setState(() => _pane = _ShopPane.top);
          },
        ),
      const SizedBox(height: 4),
      _row(emoji: '↩️', title: '戻る', sub: '', onTap: () => setState(() => _pane = _ShopPane.top)),
    ];
  }

  // ── 部品 ─────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      );

  Widget _stat(String label, String value, {bool warn = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(width: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: warn ? const Color(0xFFC0554A) : null)),
          ],
        ),
      );

  Widget _row({
    required String emoji,
    required String title,
    required String sub,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: enabled ? 0.92 : 0.55),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: enabled ? null : Colors.grey,
                          )),
                      if (sub.isNotEmpty)
                        Text(sub,
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
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
