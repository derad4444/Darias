// features/roguelike/widgets/resource_bar_widget.dart

import 'package:flutter/material.dart';
import '../models/game_state.dart';

class ResourceBarWidget extends StatelessWidget {
  final GameState state;

  const ResourceBarWidget({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: Column(
        children: [
          // HP バー
          Row(
            children: [
              const Text('❤️', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.hp / state.maxHp,
                    minHeight: 10,
                    backgroundColor: Colors.red.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(
                      state.hp > state.maxHp * 0.5 ? Colors.green : state.hp > state.maxHp * 0.25 ? Colors.orange : Colors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${state.hp}/${state.maxHp}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          // その他リソース
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ResourceChip(emoji: '🍞', label: '食料', value: state.food),
              _ResourceChip(emoji: '💰', label: 'お金', value: state.money),
              _ResourceChip(emoji: '🎒', label: 'アイテム', value: state.itemCount),
              _ResourceChip(emoji: '🤝', label: '絆', value: state.bond),
              _ResourceChip(emoji: '👣', label: '行動', value: state.actionsLeft),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResourceChip extends StatelessWidget {
  final String emoji;
  final String label;
  final int value;

  const _ResourceChip({required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isLow = value <= 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isLow ? Colors.red : null,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }
}
