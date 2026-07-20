// features/roguelike/widgets/map_grid_widget.dart

import 'package:flutter/material.dart';
import '../models/map_cell.dart';
import '../models/game_state.dart';

/// ノード種別ごとの色（ラベルチップ・枠に使用）。
Color cellTypeColor(CellType t) {
  switch (t) {
    case CellType.start:     return const Color(0xFFF2C94C);
    case CellType.enemy:     return const Color(0xFFE57373);
    case CellType.chest:     return const Color(0xFFD4A24E);
    case CellType.rest:      return const Color(0xFF7CC47F);
    case CellType.merchant:  return const Color(0xFFE9A05A);
    case CellType.companion: return const Color(0xFF5BB8B0);
    case CellType.mystery:   return const Color(0xFF9B8CCB);
    case CellType.boss:      return const Color(0xFFE08AAE);
    case CellType.empty:     return const Color(0xFFB0BEC5);
  }
}

/// 枝道式（層状分岐）マップ。
///
/// スタート層（下）からボス層（上）へ、つながった次の層のノードを
/// タップして一方向に進む。どのルートを選んでも必ずボスに合流する。
class MapGridWidget extends StatelessWidget {
  final GameState state;
  final void Function(int layer, int index) onCellTap;
  final String? characterAssetPath;

  /// 層間の縦の間隔。
  static const double layerGap = 92;

  /// ノード円の半径。
  static const double _nodeRadius = 26;

  const MapGridWidget({
    super.key,
    required this.state,
    required this.onCellTap,
    this.characterAssetPath,
  });

  /// レイアウト用のノード中心座標。start（layer0）を一番下、boss（最終層）を一番上に置く。
  Offset _center(int layer, int index, double width) {
    final n = state.map[layer].length;
    final x = width * (index + 1) / (n + 1);
    final y = (state.map.length - 1 - layer + 0.5) * layerGap;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final exploring = state.phase == GamePhase.exploring;
    final reachable = state.reachableIndices;
    final height = state.map.length * layerGap;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final nodes = <Widget>[];

        for (var l = 0; l < state.map.length; l++) {
          for (final cell in state.map[l]) {
            final center = _center(l, cell.index, width);
            final isReachable =
                exploring && l == state.playerLayer + 1 && reachable.contains(cell.index);
            nodes.add(Positioned(
              left: center.dx - _nodeRadius - 6,
              top: center.dy - _nodeRadius,
              width: (_nodeRadius + 6) * 2,
              child: _NodeWidget(
                cell: cell,
                radius: _nodeRadius,
                isReachable: isReachable,
                characterAssetPath: cell.isCurrentPosition ? characterAssetPath : null,
                onTap: isReachable ? () => onCellTap(l, cell.index) : null,
              ),
            ));
          }
        }

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 層間をつなぐ枝道（線）。
              Positioned.fill(
                child: CustomPaint(
                  painter: _EdgePainter(
                    state: state,
                    nodeRadius: _nodeRadius,
                    center: (l, i) => _center(l, i, width),
                  ),
                ),
              ),
              ...nodes,
            ],
          ),
        );
      },
    );
  }
}

/// 層間の接続線を描く。現在ノードから進める枝はアクセント色で強調する。
class _EdgePainter extends CustomPainter {
  final GameState state;
  final double nodeRadius;
  final Offset Function(int layer, int index) center;

  _EdgePainter({required this.state, required this.nodeRadius, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = const Color(0xFFB9C2CC).withValues(alpha: 0.55)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final active = Paint()
      ..color = const Color(0xFFF2A65A)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    for (var l = 0; l < state.map.length - 1; l++) {
      for (final cell in state.map[l]) {
        final from = center(l, cell.index);
        final isCurrent = l == state.playerLayer && cell.index == state.playerIndex;
        for (final t in cell.nextIndices) {
          final to = center(l + 1, t);
          canvas.drawLine(from, to, isCurrent ? active : base);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.state.playerLayer != state.playerLayer ||
      old.state.playerIndex != state.playerIndex ||
      old.state.map != state.map;
}

/// マップ上の1ノード（円アイコン＋ラベル）。
class _NodeWidget extends StatelessWidget {
  final MapCell cell;
  final double radius;
  final bool isReachable;
  final String? characterAssetPath;
  final VoidCallback? onTap;

  const _NodeWidget({
    required this.cell,
    required this.radius,
    required this.isReachable,
    required this.characterAssetPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = cellTypeColor(cell.type);
    // 判明条件: 訪問済み / 現在地 / 開示済み / これから進める / ボス（目的地は常に見せる）。
    final known = cell.isVisited ||
        cell.isCurrentPosition ||
        cell.isRevealed ||
        isReachable ||
        cell.type == CellType.boss;
    final passed = cell.isVisited && !cell.isCurrentPosition;

    Color bg;
    Color border;
    double borderW;
    if (cell.isCurrentPosition) {
      bg = const Color(0xFFFFF6D9);
      border = const Color(0xFFF2C94C);
      borderW = 3;
    } else if (isReachable) {
      bg = color.withValues(alpha: 0.14);
      border = color.withValues(alpha: 0.85);
      borderW = 2.5;
    } else if (cell.isVisited) {
      bg = const Color(0xFFF1F3F4);
      border = Colors.grey.withValues(alpha: 0.3);
      borderW = 1.5;
    } else {
      bg = const Color(0xFFEDF1EE);
      border = Colors.grey.withValues(alpha: 0.25);
      borderW = 1.5;
    }

    final circle = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: borderW),
          boxShadow: isReachable
              ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8)]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: (cell.isCurrentPosition && characterAssetPath != null)
            ? Padding(
                padding: const EdgeInsets.all(3),
                child: Image.asset(characterAssetPath!, fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const Center(child: Text('🧑', style: TextStyle(fontSize: 22)))),
              )
            : Center(child: Text(known ? cell.type.emoji : '🌫️', style: const TextStyle(fontSize: 22))),
      ),
    );

    return Opacity(
      opacity: passed ? 0.5 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          const SizedBox(height: 2),
          if (known && cell.type != CellType.start)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)),
              child: Text(cell.type.label, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }
}
