// features/roguelike/widgets/map_grid_widget.dart

import 'package:flutter/material.dart';
import '../models/map_cell.dart';
import '../models/game_state.dart';

class MapGridWidget extends StatelessWidget {
  final GameState state;
  final void Function(int row, int col) onCellTap;

  const MapGridWidget({super.key, required this.state, required this.onCellTap});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: 16,
        itemBuilder: (context, index) {
          final row = index ~/ 4;
          final col = index % 4;
          final cell = state.map[row][col];
          return _CellWidget(
            cell: cell,
            isReachable: cell.isAdjacentTo(state.playerRow, state.playerCol) && state.phase == GamePhase.exploring,
            onTap: () => onCellTap(row, col),
          );
        },
      ),
    );
  }
}

class _CellWidget extends StatelessWidget {
  final MapCell cell;
  final bool isReachable;
  final VoidCallback onTap;

  const _CellWidget({required this.cell, required this.isReachable, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    if (cell.isCurrentPosition) {
      bgColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.3);
    } else if (cell.isVisited) {
      bgColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    } else if (isReachable) {
      bgColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
    } else {
      bgColor = isDark ? Colors.grey[900]! : Colors.grey[100]!;
    }

    return GestureDetector(
      onTap: isReachable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: cell.isCurrentPosition
                ? Theme.of(context).colorScheme.primary
                : isReachable
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                    : Colors.grey.withValues(alpha: 0.3),
            width: cell.isCurrentPosition ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              cell.isVisited || isReachable ? cell.type.emoji : '🌫️',
              style: const TextStyle(fontSize: 20),
            ),
            if (cell.isCurrentPosition)
              const Text('▲', style: TextStyle(fontSize: 8, color: Colors.blue)),
          ],
        ),
      ),
    );
  }
}
