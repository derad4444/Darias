import 'package:flutter/material.dart';
import 'package:darias/data/models/game/game_models.dart';

class GameBoardWidget extends StatelessWidget {
  final List<List<BoardCell>> board;
  final (int, int)? selectedCell;
  final (int, int)? p1PendingCell;   // handover/resolveフェーズで表示
  final (int, int)? p2PendingCell;
  final List<(int, int)> highlightedCells;
  final bool interactive;
  final bool showPending;
  final Function(int row, int col)? onCellTap;

  const GameBoardWidget({
    super.key,
    required this.board,
    this.selectedCell,
    this.p1PendingCell,
    this.p2PendingCell,
    this.highlightedCells = const [],
    this.interactive = true,
    this.showPending = false,
    this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 32;
        final cellSize = (available / 5).clamp(0.0, 72.0);
        return _buildBoard(cellSize);
      },
    );
  }

  Widget _buildBoard(double cellSize) {
    return Container(
      width: cellSize * 5 + 2,
      height: cellSize * 5 + 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 1),
        color: const Color(0xFF111122),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: List.generate(5, (row) {
            return Row(
              children: List.generate(5, (col) {
                return _buildCell(row, col, cellSize);
              }),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col, double size) {
    final cell = board[row][col];
    final isSelected = selectedCell == (row, col);
    final isP1Pending = showPending && p1PendingCell == (row, col);
    final isP2Pending = showPending && p2PendingCell == (row, col);
    final isHighlighted = highlightedCells.contains((row, col));

    Color bgColor;
    if (cell.isP1) {
      bgColor = (cell.element?.color ?? Colors.blue).withOpacity(0.55);
    } else if (cell.isP2) {
      bgColor = (cell.element?.color ?? Colors.red).withOpacity(0.55);
    } else {
      bgColor = const Color(0xFF1A1A2E);
    }

    return GestureDetector(
      onTap: interactive ? () => onCellTap?.call(row, col) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: isSelected
                ? Colors.white
                : isP1Pending
                    ? Colors.blue.shade300
                    : isP2Pending
                        ? Colors.red.shade300
                        : isHighlighted
                            ? Colors.yellow.withOpacity(0.6)
                            : Colors.white10,
            width: isSelected || isP1Pending || isP2Pending ? 2 : 0.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // オーナーの属性アイコン
            if (!cell.isEmpty)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _ownerIcon(cell.ownerId!),
                    style: const TextStyle(fontSize: 9),
                  ),
                  Text(
                    '${cell.power}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cell.element?.color ?? Colors.white,
                    ),
                  ),
                ],
              ),

            // 選択中マーク
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

            // P1 pending indicator
            if (isP1Pending && !isSelected)
              Positioned(
                bottom: 2,
                left: 2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.shade300,
                  ),
                ),
              ),

            // P2 pending indicator
            if (isP2Pending && !isSelected)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.shade300,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _ownerIcon(int ownerId) => ownerId == 0 ? '🔵' : '🔴';
