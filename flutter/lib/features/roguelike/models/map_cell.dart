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
      case CellType.mystery:   return '謎';
      case CellType.boss:      return 'ボス';
      case CellType.empty:     return '空き地';
    }
  }

  String get emoji {
    switch (this) {
      case CellType.start:     return '🚩';
      case CellType.enemy:     return '👾';
      case CellType.chest:     return '🎁';
      case CellType.rest:      return '🔥';
      case CellType.merchant:  return '🛒';
      case CellType.companion: return '👫';
      case CellType.mystery:   return '❓';
      case CellType.boss:      return '👑';
      case CellType.empty:     return '👣';
    }
  }
}

/// 分岐マップ（枝道式）の1ノード。
///
/// マップは層（layer）の並びで構成され、スタート層(layer 0)から
/// ボス層(最終層)まで一方向に進む。各ノードは次の層の [nextIndices] の
/// ノードだけへつながり、どのルートを選んでも最後は必ずボスに合流する。
class MapCell {
  /// 層番号。0＝スタート層、最終層＝ボス層。
  final int layer;

  /// 層内での位置（0始まり）。描画時の横位置にも使う。
  final int index;

  final CellType type;

  /// つながっている「次の層」のノード index の一覧。
  /// 最終層（ボス）は空。
  final List<int> nextIndices;

  final bool isVisited;
  final bool isCurrentPosition;

  /// 未訪問でも地図イベントで種別が判明したノード。
  final bool isRevealed;

  const MapCell({
    required this.layer,
    required this.index,
    required this.type,
    this.nextIndices = const [],
    this.isVisited = false,
    this.isCurrentPosition = false,
    this.isRevealed = false,
  });

  MapCell copyWith({
    bool? isVisited,
    bool? isCurrentPosition,
    bool? isRevealed,
  }) {
    return MapCell(
      layer: layer,
      index: index,
      type: type,
      nextIndices: nextIndices,
      isVisited: isVisited ?? this.isVisited,
      isCurrentPosition: isCurrentPosition ?? this.isCurrentPosition,
      isRevealed: isRevealed ?? this.isRevealed,
    );
  }
}
