// features/roguelike/models/game_state.dart

import 'dart:math';
import 'map_cell.dart';
import 'game_event.dart';
import 'enemy.dart';
import 'dungeon.dart';
import 'action_log.dart';
import 'outcome.dart';
import 'equipment.dart';

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

/// 「今回の冒険で印象的だった行動」1件分（結果画面で上位を表示）。
/// その選択を選んだことで最も強く加算された特性とその量を記録する。
class NotableAction {
  final String label;   // 選んだ行動のラベル（例「崖道を進む」）
  final String trait;   // 最も強く出た特性名（例「挑戦性」）
  final int delta;      // その特性の加算量

  const NotableAction({required this.label, required this.trait, required this.delta});
}

/// 相棒（仲間）の出自。現状はゲーム内NPCのみ。
/// 将来フレンド/マルチ連動を入れる際は friend を使う想定（その時に拡張）。
enum CompanionSource { npc, friend }

/// 冒険中の相棒。絆（bond）はこの相棒との関係を表し、
/// 相棒がいない間は絆は意味を持たない（0固定・UI非表示）。
class Companion {
  final String name;
  final CompanionSource source;

  const Companion({required this.name, this.source = CompanionSource.npc});

  /// 途中再開（将来実装）用のシリアライズ。
  Map<String, dynamic> toMap() => {'name': name, 'source': source.name};

  factory Companion.fromMap(Map<String, dynamic> m) => Companion(
        name: (m['name'] as String?) ?? '相棒',
        source: CompanionSource.values.firstWhere(
          (s) => s.name == m['source'],
          orElse: () => CompanionSource.npc,
        ),
      );
}

/// 冒険の終了種別。phase（victory/gameOver）より細かく結果を表す。
enum GameResult {
  clear,    // ボス撃破（完全クリア）
  retreat,  // ボスから逃走（撤退・記録あり）
  timeUp,   // 旧: 行動回数切れ。現在は発生しないが過去ランの表示用に残す。
  failed,   // HP0 / 餓死（失敗）
}

extension GameResultExt on GameResult {
  String get label {
    switch (this) {
      case GameResult.clear:   return '心の迷宮を踏破！';
      case GameResult.retreat: return '迷宮から撤退';
      case GameResult.timeUp:  return '時間切れ帰還';
      case GameResult.failed:  return '冒険失敗';
    }
  }

  /// 完全クリア・撤退クリアなど「前向きな終わり」か。
  bool get isPositive => this == GameResult.clear || this == GameResult.retreat || this == GameResult.timeUp;
}

class GameState {
  final int hp;
  final int maxHp;
  final int food;
  final int money;
  final int itemCount;
  final int bond;
  final Companion? companion; // null＝相棒なし（絆は無効）
  final Equipment? weapon; // 装備中の武器（null＝素手）。ランごとリセット。
  final Equipment? armor;  // 装備中の防具（null＝防具なし）。ランごとリセット。
  final List<List<MapCell>> map;
  final int playerLayer; // 現在いる層（0＝スタート層）
  final int playerIndex; // 現在いる層内のノード位置
  final GamePhase phase;
  final GameEvent? currentEvent;
  final EventChoice? lastChoice;
  final Outcome? lastOutcome; // 直近の選択で実際に出た結果（イベント結果表示用）
  final Enemy? currentEnemy;
  final ActionLog actionLog;
  final List<String> battleMessages; // 現在のアクションで画面に順送り表示する文言（送り終えると空になる）
  final List<String> battleHistory; // ログボタン用：行った行動と成果（成功/失敗・主要な増減）の簡潔な履歴
  final GamePhase? pendingPhase; // メッセージを送り終えた後に移行する画面（null＝戦闘継続）
  final GameResult? pendingResult; // 同上の結果種別（死亡/撃破/撤退など）
  final int battleTurns; // 現在の戦闘の経過ターン数（敵の強化に使う）
  final int battleActionSeq; // 戦闘アクションの通し番号（成功/失敗演出のトリガ用）
  final OutcomeTier? lastBattleTier; // 直近の戦闘アクションの結果段階（演出用）
  final Set<String> sealedChoices; // 自己否定などで封じられた戦闘選択肢のラベル
  final Set<String> usedChoices; // この戦闘で使い切った「1回のみ」選択肢のラベル
  final GrowthStage growthStage;
  final String element;
  final String characterName;
  final String dungeonId; // 挑戦中のダンジョン（悩み）ID
  final GameResult? result; // 終了時のみセット
  final String? eventNotice; // 直近のイベントで相棒が加入/離脱した時の通知文（結果表示用）
  final int enemiesDefeated; // 倒した敵の数（結果画面用）
  final Set<String> seenEvents; // この冒険で出会ったイベントID（図鑑用）
  final Set<String> seenEnemies; // この冒険で出会った敵ID（図鑑用）
  final List<NotableAction> notableActions; // 印象的だった行動の記録

  const GameState({
    required this.hp,
    required this.maxHp,
    required this.food,
    required this.money,
    required this.itemCount,
    required this.bond,
    this.companion,
    this.weapon,
    this.armor,
    required this.map,
    required this.playerLayer,
    required this.playerIndex,
    required this.phase,
    this.currentEvent,
    this.lastChoice,
    this.lastOutcome,
    this.currentEnemy,
    required this.actionLog,
    this.battleMessages = const [],
    this.battleHistory = const [],
    this.pendingPhase,
    this.pendingResult,
    this.battleTurns = 0,
    this.battleActionSeq = 0,
    this.lastBattleTier,
    this.sealedChoices = const {},
    this.usedChoices = const {},
    required this.growthStage,
    required this.element,
    required this.characterName,
    required this.dungeonId,
    this.result,
    this.eventNotice,
    this.enemiesDefeated = 0,
    this.seenEvents = const {},
    this.seenEnemies = const {},
    this.notableActions = const [],
  });

  bool get isDead => hp <= 0;
  bool get isAtBoss => map[playerLayer][playerIndex].type == CellType.boss;
  bool get hasCompanion => companion != null;

  /// 武器による与ダメ加算（未装備＝0）。
  int get weaponAtk => weapon?.power ?? 0;

  /// 防具による被ダメ軽減（未装備＝0）。
  int get armorDef => armor?.power ?? 0;

  /// 到達した深さ（通過した層数。スタート層を1と数える）。
  int get reachedDepth => playerLayer + 1;

  /// マップの総層数（スタート層〜ボス層）。
  int get totalDepth => map.length;

  /// 現在ノードからつながっている「次の層」のノード index 集合。
  Set<int> get reachableIndices {
    if (playerLayer >= map.length - 1) return const {};
    return map[playerLayer][playerIndex].nextIndices.toSet();
  }

  GameState copyWith({
    int? hp,
    int? maxHp,
    int? food,
    int? money,
    int? itemCount,
    int? bond,
    Companion? companion,
    bool clearCompanion = false,
    Equipment? weapon,
    Equipment? armor,
    List<List<MapCell>>? map,
    int? playerLayer,
    int? playerIndex,
    GamePhase? phase,
    GameEvent? currentEvent,
    bool clearEvent = false,
    EventChoice? lastChoice,
    Outcome? lastOutcome,
    bool clearLastChoice = false,
    Enemy? currentEnemy,
    bool clearEnemy = false,
    ActionLog? actionLog,
    List<String>? battleMessages,
    List<String>? battleHistory,
    GamePhase? pendingPhase,
    GameResult? pendingResult,
    bool clearPending = false,
    int? battleTurns,
    int? battleActionSeq,
    OutcomeTier? lastBattleTier,
    Set<String>? sealedChoices,
    Set<String>? usedChoices,
    GameResult? result,
    String? eventNotice,
    bool clearEventNotice = false,
    int? enemiesDefeated,
    Set<String>? seenEvents,
    Set<String>? seenEnemies,
    List<NotableAction>? notableActions,
  }) {
    final newMaxHp = maxHp ?? this.maxHp;
    return GameState(
      hp: (hp ?? this.hp).clamp(0, newMaxHp),
      maxHp: newMaxHp,
      food: (food ?? this.food).clamp(0, 99),
      money: (money ?? this.money).clamp(0, 99),
      itemCount: (itemCount ?? this.itemCount).clamp(0, 9),
      bond: (bond ?? this.bond).clamp(0, 10),
      companion: clearCompanion ? null : (companion ?? this.companion),
      weapon: weapon ?? this.weapon,
      armor: armor ?? this.armor,
      map: map ?? this.map,
      playerLayer: playerLayer ?? this.playerLayer,
      playerIndex: playerIndex ?? this.playerIndex,
      phase: phase ?? this.phase,
      currentEvent: clearEvent ? null : (currentEvent ?? this.currentEvent),
      lastChoice: clearLastChoice ? null : (lastChoice ?? this.lastChoice),
      lastOutcome: clearLastChoice ? null : (lastOutcome ?? this.lastOutcome),
      currentEnemy: clearEnemy ? null : (currentEnemy ?? this.currentEnemy),
      actionLog: actionLog ?? this.actionLog,
      // 戦闘終了（clearEnemy）でメッセージ・履歴はリセットする
      battleMessages: clearEnemy ? const [] : (battleMessages ?? this.battleMessages),
      battleHistory: clearEnemy ? const [] : (battleHistory ?? this.battleHistory),
      pendingPhase: clearPending ? null : (pendingPhase ?? this.pendingPhase),
      pendingResult: clearPending ? null : (pendingResult ?? this.pendingResult),
      battleTurns: clearEnemy ? 0 : (battleTurns ?? this.battleTurns),
      battleActionSeq: battleActionSeq ?? this.battleActionSeq,
      lastBattleTier: lastBattleTier ?? this.lastBattleTier,
      sealedChoices: clearEnemy ? const {} : (sealedChoices ?? this.sealedChoices),
      usedChoices: clearEnemy ? const {} : (usedChoices ?? this.usedChoices),
      growthStage: growthStage,
      element: element,
      characterName: characterName,
      dungeonId: dungeonId,
      result: result ?? this.result,
      eventNotice: clearEventNotice ? null : (eventNotice ?? this.eventNotice),
      enemiesDefeated: enemiesDefeated ?? this.enemiesDefeated,
      seenEvents: seenEvents ?? this.seenEvents,
      seenEnemies: seenEnemies ?? this.seenEnemies,
      notableActions: notableActions ?? this.notableActions,
    );
  }

  /// 訪れたノード数（記録保存・到達表示用）。
  int get visitedCount =>
      map.expand((row) => row).where((c) => c.isVisited).length;

  // 成長段階から初期リソースを生成
  static GameState initial({
    required GrowthStage stage,
    required String element,
    required String characterName,
    required Dungeon dungeon,
  }) {
    // HP・食料・金貨・回復薬は成長段階で増える（大人ほど多く始められる）。
    // 絆は全段階0スタート。相棒（仲間）が加入して初めて意味を持つ。
    final (hp, food, money, items) = switch (stage) {
      GrowthStage.baby  => (20, 1, 1, 0),
      GrowthStage.young => (30, 3, 3, 0),
      GrowthStage.adult => (40, 5, 5, 1),
    };
    return GameState(
      hp: hp,
      maxHp: hp,
      food: food,
      money: money,
      itemCount: items,
      bond: 0,
      map: _generateMap(),
      playerLayer: 0,
      playerIndex: 0,
      phase: GamePhase.exploring,
      actionLog: const ActionLog(),
      growthStage: stage,
      element: element,
      characterName: characterName,
      dungeonId: dungeon.id,
    );
  }

  // ===== 分岐マップ（枝道式）の生成 =====

  /// 総層数（スタート層 + 中間層 + ボス層）。
  static const int mapLayerCount = 7;

  /// 敵専用層（この層はどのノードも必ず敵＝どのルートでも確定戦闘）。
  /// 中間層 1..5 のうち 2 層を敵層にし、確定2回の戦闘＋ボスを保証する。
  static const Set<int> _enemyLayers = {2, 4};

  /// 分岐マップをランダム生成する。
  ///
  /// - スタート層(1ノード) → 中間5層(各2〜3ノード) → ボス層(1ノード)
  /// - 各ノードは次の層の 1〜2 ノードへつながり、全ノードがスタートから
  ///   到達可能／全ノードからボスへ到達可能になるよう連結する。
  /// - 敵層 {2,4} はどのノードも敵なので、どのルートでも確定2回戦闘する。
  static List<List<MapCell>> _generateMap() {
    final rng = Random();
    const layerCount = mapLayerCount;

    // 各層のノード数（スタート/ボスは1、中間は2〜3）。
    final sizes = List.generate(layerCount, (l) {
      if (l == 0 || l == layerCount - 1) return 1;
      return 2 + rng.nextInt(2);
    });

    // 中間ノード（敵専用層以外）に割り当てる種別プール（重み付き・合計10枠）。
    // 宝箱2/謎2/商人2/休憩1/敵1/仲間1/空き地1 ＝ 各20%×3 + 10%×4。
    // 敵をプールに入れると、確定敵層{2,4}に加えてイベント層でも敵に遭遇しうる（分岐で避けられる）。
    const eventPool = [
      CellType.chest, CellType.chest,
      CellType.mystery, CellType.mystery,
      CellType.merchant, CellType.merchant,
      CellType.rest,
      CellType.enemy,
      CellType.companion,
      CellType.empty,
    ];

    // 種別を決める。
    final types = <List<CellType>>[];
    for (var l = 0; l < layerCount; l++) {
      if (l == 0) {
        types.add(const [CellType.start]);
      } else if (l == layerCount - 1) {
        types.add(const [CellType.boss]);
      } else if (_enemyLayers.contains(l)) {
        types.add(List.filled(sizes[l], CellType.enemy));
      } else {
        types.add(List.generate(sizes[l], (_) => eventPool[rng.nextInt(eventPool.length)]));
      }
    }

    // 層間の接続（各ノードの nextIndices）を決める。
    final nextOf = <List<List<int>>>[];
    for (var l = 0; l < layerCount - 1; l++) {
      nextOf.add(_connectLayers(sizes[l], sizes[l + 1], rng));
    }

    // ノードを組み立てる。
    return List.generate(layerCount, (l) {
      return List.generate(sizes[l], (i) {
        final isStart = l == 0;
        return MapCell(
          layer: l,
          index: i,
          type: types[l][i],
          nextIndices: l < layerCount - 1 ? nextOf[l][i] : const [],
          isVisited: isStart,
          isCurrentPosition: isStart,
        );
      });
    });
  }

  /// 層 a（[from] ノード）から層 b（[to] ノード）への接続を作る。
  /// 返り値は from の各ノードごとの、接続先 to インデックス一覧。
  /// 全 from ノードに出口が1つ以上、全 to ノードに入口が1つ以上できることを保証する
  /// （＝行き止まり無し・到達不能ノード無し）。
  static List<List<int>> _connectLayers(int from, int to, Random rng) {
    final edges = List.generate(from, (_) => <int>{});
    final hasIncoming = List.filled(to, false);

    // 位置の比率で「まっすぐ前」のノードへつなぎ、たまに隣へも枝分かれさせる。
    for (var i = 0; i < from; i++) {
      final straight =
          (from == 1) ? 0 : ((i * (to - 1)) / (from - 1)).round().clamp(0, to - 1);
      edges[i].add(straight);
      hasIncoming[straight] = true;
      // 50%で隣のノードへも分岐（枝道を作る）。
      if (to > 1 && rng.nextBool()) {
        final alt = (straight + (rng.nextBool() ? 1 : -1)).clamp(0, to - 1);
        edges[i].add(alt);
        hasIncoming[alt] = true;
      }
    }

    // 入口の無い to ノードを、最寄りの from ノードから拾う。
    for (var j = 0; j < to; j++) {
      if (hasIncoming[j]) continue;
      final src =
          (from == 1) ? 0 : ((j * (from - 1)) / (to - 1)).round().clamp(0, from - 1);
      edges[src].add(j);
      hasIncoming[j] = true;
    }

    return edges.map((s) => s.toList()..sort()).toList();
  }
}
