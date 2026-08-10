// features/roguelike/widgets/resource_bar_widget.dart

import 'package:flutter/material.dart';
import '../models/game_state.dart';
import 'dungeon_theme.dart';

/// 画面共有の上部ヘッダー。アバター＋成長段階バッジ＋リソースピル＋メニュー。
class ResourceBarWidget extends StatelessWidget {
  final GameState state;
  final String avatarPath;
  final VoidCallback onMenu;

  /// 鞄ピルのタップで鞄画面を開く。
  final VoidCallback onOpenBag;

  const ResourceBarWidget({
    super.key,
    required this.state,
    required this.avatarPath,
    required this.onMenu,
    required this.onOpenBag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: kRoguelikeCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // アバター＋段階バッジ
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 60, height: 60,
                  child: Image.asset(avatarPath, fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const Center(child: Text('🧑', style: TextStyle(fontSize: 34)))),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFF2C94C).withValues(alpha: 0.35), borderRadius: BorderRadius.circular(8)),
                child: Text(state.growthStage.label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // リソースピル（2段構成：1段目=HPバー、2段目=その他）
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HpPill(hp: state.hp, maxHp: state.maxHp),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: _Pill(emoji: '💰', label: '金貨', value: '${state.money}')),
                    // 食料・回復薬は鞄の中で管理するのでピルには出さない。
                    // （食料はスタック扱いで、鞄の枠は使わない別枠に置く）
                    if (state.hasCompanion) Expanded(child: _Pill(emoji: '🤝', label: '絆', value: '${state.bond}')),
                    Expanded(
                      child: _Pill(
                        emoji: '🎒',
                        label: 'カバン',
                        value: '${state.bagUsed}/${state.bagCapacity}',
                        onTap: onOpenBag,
                      ),
                    ),
                  ],
                ),
                // 装備中の武器・防具はヘッダーに出さない。
                // 持ち物はカバンの中で一元的に確認する。
              ],
            ),
          ),
          const SizedBox(width: 4),
          // メニュー
          Material(
            color: const Color(0xFF6E9BE6).withValues(alpha: 0.12),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onMenu,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.menu, size: 22, color: Color(0xFF6E9BE6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// HP（ハート＋数値＋ミニバー）のピル。
class _HpPill extends StatelessWidget {
  final int hp;
  final int maxHp;
  const _HpPill({required this.hp, required this.maxHp});

  @override
  Widget build(BuildContext context) {
    final ratio = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
    final color = ratio > 0.5 ? const Color(0xFF59C28A) : ratio > 0.25 ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFFFF1F4), borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('❤️', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              const Text('HP', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 6),
              Text('$hp/$maxHp', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio, minHeight: 6,
              backgroundColor: Colors.red.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// 汎用リソースピル（絵文字＋ラベル＋数値）。
class _Pill extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  /// タップで開くもの（鞄ピル・装備ピル）。null なら非タップ。
  final VoidCallback? onTap;

  const _Pill({
    required this.emoji,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 鞄は「3/5」でも残量が少ない訳ではないので、低下警告の対象から外す。
    final isLow = onTap == null && (int.tryParse(value.split('/').first) ?? 99) <= 2;
    final body = Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 2),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey))),
              // 押せるピル（鞄・装備）だけ矢印を出す。配色は他のピルと同じまま。
              if (onTap != null)
                const Icon(Icons.chevron_right, size: 13, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isLow ? Colors.red : null)),
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: body,
    );
  }
}
