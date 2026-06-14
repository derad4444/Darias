// features/roguelike/providers/roguelike_provider.dart

import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_state.dart';
import '../models/map_cell.dart';
import '../models/game_event.dart';
import '../models/enemy.dart';

final roguelikeProvider =
    StateNotifierProvider<RoguelikeNotifier, GameState?>((ref) => RoguelikeNotifier());

class RoguelikeNotifier extends StateNotifier<GameState?> {
  RoguelikeNotifier() : super(null);

  final _rng = Random();

  void startGame({
    required GrowthStage stage,
    required String element,
    required String characterName,
  }) {
    state = GameState.initial(stage: stage, element: element, characterName: characterName);
  }

  void resetGame() => state = null;

  // マスへ移動
  void moveToCell(int row, int col) {
    final s = state;
    if (s == null || s.phase != GamePhase.exploring) return;
    final cell = s.map[row][col];
    if (!cell.isAdjacentTo(s.playerRow, s.playerCol)) return;
    if (s.actionsLeft <= 0) return;

    // マップ更新（現在地と訪問済みフラグ）
    final newMap = s.map.map((rowList) => rowList.map((c) {
      if (c.row == s.playerRow && c.col == s.playerCol) {
        return c.copyWith(isCurrentPosition: false);
      }
      if (c.row == row && c.col == col) {
        return c.copyWith(isVisited: true, isCurrentPosition: true);
      }
      return c;
    }).toList()).toList();

    // 移動で食料消費（2マスに1回）
    final newFood = s.actionsLeft % 2 == 0 ? s.food - 1 : s.food;
    final newActions = s.actionsLeft - 1;

    var next = s.copyWith(
      map: newMap,
      playerRow: row,
      playerCol: col,
      food: newFood,
      actionsLeft: newActions,
    );

    // 餓死チェック
    if (next.food <= 0 && next.hp > 0) {
      next = next.copyWith(hp: next.hp - 5);
    }

    if (next.isDead) {
      state = next.copyWith(phase: GamePhase.gameOver);
      return;
    }

    // マスイベントを発生させる
    state = _triggerCellEvent(next, cell.type);
  }

  GameState _triggerCellEvent(GameState s, CellType type) {
    switch (type) {
      case CellType.enemy:
        final enemies = Enemies.regular;
        final enemy = enemies[_rng.nextInt(enemies.length)];
        return s.copyWith(
          phase: GamePhase.battle,
          currentEnemy: enemy,
          battleLog: ['${enemy.name}が現れた！'],
        );
      case CellType.chest:
      case CellType.rest:
      case CellType.merchant:
      case CellType.companion:
      case CellType.mystery:
        final events = GameEvents.all;
        final event = events[_rng.nextInt(events.length)];
        return s.copyWith(phase: GamePhase.event, currentEvent: event);
      case CellType.boss:
        return s.copyWith(
          phase: GamePhase.battle,
          currentEnemy: Enemies.boss,
          battleLog: ['心の迷宮の守護者が立ちはだかった！'],
        );
      case CellType.start:
      case CellType.empty:
        // 行動残り0 or ボス撃破済みなら終了
        if (s.actionsLeft <= 0) return s.copyWith(phase: GamePhase.victory);
        return s;
    }
  }

  // イベント選択肢を選ぶ
  void chooseEvent(EventChoice choice) {
    final s = state;
    if (s == null || s.phase != GamePhase.event) return;

    var changes = choice.resourceChanges;
    var next = s.copyWith(
      hp: s.hp + (changes['hp'] ?? 0),
      food: s.food + (changes['food'] ?? 0),
      money: s.money + (changes['money'] ?? 0),
      itemCount: s.itemCount + (changes['items'] ?? 0),
      bond: s.bond + (changes['bond'] ?? 0),
      actionLog: s.actionLog.copyWith(
        challenge: choice.traitDelta.challenge,
        caution: choice.traitDelta.caution,
        curiosity: choice.traitDelta.curiosity,
        planning: choice.traitDelta.planning,
        intuition: choice.traitDelta.intuition,
        logic: choice.traitDelta.logic,
        cooperation: choice.traitDelta.cooperation,
        altruism: choice.traitDelta.altruism,
        persistence: choice.traitDelta.persistence,
        flexibility: choice.traitDelta.flexibility,
      ),
      lastChoice: choice,
      phase: GamePhase.event, // 結果表示のため維持
    );

    if (next.isDead) {
      state = next.copyWith(phase: GamePhase.gameOver, clearEvent: true);
      return;
    }

    state = next;
  }

  // イベント結果を閉じて探索へ
  void closeEvent() {
    final s = state;
    if (s == null) return;
    if (s.actionsLeft <= 0) {
      state = s.copyWith(phase: GamePhase.victory, clearEvent: true, clearLastChoice: true);
      return;
    }
    state = s.copyWith(phase: GamePhase.exploring, clearEvent: true, clearLastChoice: true);
  }

  // 戦闘アクションを実行
  void performBattleAction(BattleChoice choice) {
    final s = state;
    if (s == null || s.phase != GamePhase.battle || s.currentEnemy == null) return;

    final enemy = s.currentEnemy!;
    final newEnemyHp = (enemy.currentHp - choice.damageToEnemy).clamp(0, enemy.maxHp);
    final updatedEnemy = enemy.copyWith(currentHp: newEnemyHp);

    final log = List<String>.from(s.battleLog)
      ..add(choice.resultText);

    var changes = choice.resourceChanges;
    var next = s.copyWith(
      hp: s.hp - choice.damageToPlayer + (changes['hp'] ?? 0),
      food: s.food + (changes['food'] ?? 0),
      money: s.money + (changes['money'] ?? 0),
      itemCount: s.itemCount + (changes['items'] ?? 0),
      bond: s.bond + (changes['bond'] ?? 0),
      currentEnemy: updatedEnemy,
      battleLog: log,
      actionLog: s.actionLog.copyWith(
        challenge: choice.traitDelta.challenge,
        caution: choice.traitDelta.caution,
        curiosity: choice.traitDelta.curiosity,
        planning: choice.traitDelta.planning,
        intuition: choice.traitDelta.intuition,
        logic: choice.traitDelta.logic,
        cooperation: choice.traitDelta.cooperation,
        altruism: choice.traitDelta.altruism,
        persistence: choice.traitDelta.persistence,
        flexibility: choice.traitDelta.flexibility,
      ),
    );

    if (next.isDead) {
      state = next.copyWith(phase: GamePhase.gameOver, clearEnemy: true);
      return;
    }

    if (updatedEnemy.isDefeated) {
      final victoryLog = List<String>.from(next.battleLog)
        ..add('${enemy.name}を乗り越えた！');
      // ボス撃破なら勝利
      if (enemy.id == 'inner_labyrinth') {
        state = next.copyWith(
          phase: GamePhase.victory,
          battleLog: victoryLog,
          clearEnemy: true,
        );
      } else {
        state = next.copyWith(
          phase: GamePhase.battle,
          battleLog: victoryLog,
          currentEnemy: updatedEnemy,
        );
      }
      return;
    }

    // 敵の反撃（簡易AI: 固定ダメージ）
    final enemyDamage = _rng.nextInt(5) + 3;
    final afterEnemyLog = List<String>.from(next.battleLog)
      ..add('${enemy.name}の攻撃！ ${enemyDamage}のダメージ');
    next = next.copyWith(hp: next.hp - enemyDamage, battleLog: afterEnemyLog);

    if (next.isDead) {
      state = next.copyWith(phase: GamePhase.gameOver, clearEnemy: true);
      return;
    }

    state = next;
  }

  // 戦闘勝利後に探索へ
  void closeBattle() {
    final s = state;
    if (s == null) return;
    if (s.actionsLeft <= 0) {
      state = s.copyWith(phase: GamePhase.victory, clearEnemy: true);
      return;
    }
    state = s.copyWith(phase: GamePhase.exploring, clearEnemy: true, battleLog: []);
  }
}
