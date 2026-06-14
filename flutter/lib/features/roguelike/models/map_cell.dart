// features/roguelike/models/map_cell.dart

enum CellType {
  start,       // スタート
  enemy,       // 敵
  chest,       // 宝箱
  rest,        // 休憩
  merchant,    // 商人
  companion,   // 仲間イベント
  mystery,     // 謎イベント
  boss,        // ボス
  empty,       // 空白
}

extension CellTypeExt on CellType {
  String get label {
    switch (this) {
      case CellType.start:     return 'スタート';
      case CellType.enemy:     return '敵';
      case CellType.chest:     return '宝箱';
      case CellType.rest:      return '休憩';
      case CellType.merchant:  return '商人';
      case CellType.companion: return '仲間';
      case CellType.mystery:   return '？';
      case CellType.boss:      return 'ボス';
      case CellType.empty:     return '道';
    }
  }

  String get emoji {
    switch (this) {
      case CellType.start:     return '🏠';
      case CellType.enemy:     return '👾';
      case CellType.chest:     return '📦';
      case CellType.rest:      return '🏕️';
      case CellType.merchant:  return '🏪';
      case CellType.companion: return '👥';
      case CellType.mystery:   return '❓';
      case CellType.boss:      return '💀';
      case CellType.empty:     return '·';
    }
  }
}

class MapCell {
  final int row;
  final int col;
  final CellType type;
  final bool isVisited;
  final bool isCurrentPosition;

  const MapCell({
    required this.row,
    required this.col,
    required this.type,
    this.isVisited = false,
    this.isCurrentPosition = false,
  });

  MapCell copyWith({
    bool? isVisited,
    bool? isCurrentPosition,
  }) {
    return MapCell(
      row: row,
      col: col,
      type: type,
      isVisited: isVisited ?? this.isVisited,
      isCurrentPosition: isCurrentPosition ?? this.isCurrentPosition,
    );
  }

  // 隣接しているかチェック（上下左右のみ）
  bool isAdjacentTo(int r, int c) {
    return (row == r && (col - c).abs() == 1) ||
           (col == c && (row - r).abs() == 1);
  }
}
