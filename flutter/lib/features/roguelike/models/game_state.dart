// features/roguelike/models/game_state.dart

import 'dart:math';
import 'map_cell.dart';
import 'game_event.dart';
import 'enemy.dart';
import 'action_log.dart';

enum GrowthStage { baby, young, adult }

extension GrowthStageExt on GrowthStage {
  String get label {
    switch (this) {
      case GrowthStage.baby:  return '赤ちゃん';
      case GrowthStage.young: return '幼少期';
      case GrowthStage.adult: return '大人';
    }
  }

  static GrowthStage fromSignalCount(int count) {
    if (count >= 30) return GrowthStage.adult;
    if (count >= 10) return GrowthStage.young;
    return GrowthStage.baby;
  }
}

enum GamePhase { exploring, event, battle, victory, gameOver }

class GameState {
  final int hp;
  final int maxHp;
  final int food;
  final int money;
  final int itemCount;
  final int bond;
  final int actionsLeft;
  final int maxActions;
  final List<List<MapCell>> map;
  final int playerRow;
  final int playerCol;
  final GamePhase phase;
  final GameEvent? currentEvent;
  final EventChoice? lastChoice;
  final Enemy? currentEnemy;
  final ActionLog actionLog;
  final List<String> battleLog;
  final GrowthStage growthStage;
  final String element;
  final String characterName;

  const GameState({
    required this.hp,
    required this.maxHp,
    required this.food,
    required this.money,
    required this.itemCount,
    required this.bond,
    required this.actionsLeft,
    required this.maxActions,
    required this.map,
    required this.playerRow,
    required this.playerCol,
    required this.phase,
    this.currentEvent,
    this.lastChoice,
    this.currentEnemy,
    required this.actionLog,
    required this.battleLog,
    required this.growthStage,
    required this.element,
    required this.characterName,
  });

  bool get isDead => hp <= 0;
  bool get isAtBoss => map[playerRow][playerCol].type == CellType.boss;

  GameState copyWith({
    int? hp,
    int? food,
    int? money,
    int? itemCount,
    int? bond,
    int? actionsLeft,
    List<List<MapCell>>? map,
    int? playerRow,
    int? playerCol,
    GamePhase? phase,
    GameEvent? currentEvent,
    bool clearEvent = false,
    EventChoice? lastChoice,
    bool clearLastChoice = false,
    Enemy? currentEnemy,
    bool clearEnemy = false,
    ActionLog? actionLog,
    List<String>? battleLog,
  }) {
    return GameState(
      hp: (hp ?? this.hp).clamp(0, maxHp),
      maxHp: maxHp,
      food: (food ?? this.food).clamp(0, 99),
      money: (money ?? this.money).clamp(0, 99),
      itemCount: (itemCount ?? this.itemCount).clamp(0, 9),
      bond: (bond ?? this.bond).clamp(0, 10),
      actionsLeft: (actionsLeft ?? this.actionsLeft).clamp(0, maxActions),
      maxActions: maxActions,
      map: map ?? this.map,
      playerRow: playerRow ?? this.playerRow,
      playerCol: playerCol ?? this.playerCol,
      phase: phase ?? this.phase,
      currentEvent: clearEvent ? null : (currentEvent ?? this.currentEvent),
      lastChoice: clearLastChoice ? null : (lastChoice ?? this.lastChoice),
      currentEnemy: clearEnemy ? null : (currentEnemy ?? this.currentEnemy),
      actionLog: actionLog ?? this.actionLog,
      battleLog: battleLog ?? this.battleLog,
      growthStage: growthStage,
      element: element,
      characterName: characterName,
    );
  }

  // 成長段階から初期リソースを生成
  static GameState initial({
    required GrowthStage stage,
    required String element,
    required String characterName,
  }) {
    final (hp, food, money, items, bond) = switch (stage) {
      GrowthStage.baby  => (20, 5, 3, 1, 0),
      GrowthStage.young => (30, 8, 5, 2, 1),
      GrowthStage.adult => (40, 10, 8, 3, 2),
    };
    return GameState(
      hp: hp,
      maxHp: hp,
      food: food,
      money: money,
      itemCount: items,
      bond: bond,
      actionsLeft: 10,
      maxActions: 10,
      map: _generateMap(),
      playerRow: 0,
      playerCol: 0,
      phase: GamePhase.exploring,
      actionLog: const ActionLog(),
      battleLog: const [],
      growthStage: stage,
      element: element,
      characterName: characterName,
    );
  }

  // 4×4マップをランダム生成
  static List<List<MapCell>> _generateMap() {
    final rng = Random();
    // マスの種類プール（スタートとボス除く14マス分）
    final pool = [
      CellType.enemy, CellType.enemy, CellType.enemy,
      CellType.chest, CellType.chest,
      CellType.rest,
      CellType.merchant,
      CellType.companion,
      CellType.mystery, CellType.mystery,
      CellType.empty, CellType.empty, CellType.empty, CellType.empty,
    ]..shuffle(rng);

    final map = List.generate(4, (r) =>
      List.generate(4, (c) {
        if (r == 0 && c == 0) return MapCell(row: r, col: c, type: CellType.start, isVisited: true, isCurrentPosition: true);
        if (r == 3 && c == 3) return MapCell(row: r, col: c, type: CellType.boss);
        final idx = r * 4 + c - 1; // スタートを除いたインデックス
        final adjustedIdx = idx > 14 ? idx - 1 : idx; // ボスのインデックスをスキップ
        return MapCell(row: r, col: c, type: pool[adjustedIdx < pool.length ? adjustedIdx : 0]);
      }),
    );
    return map;
  }
}
