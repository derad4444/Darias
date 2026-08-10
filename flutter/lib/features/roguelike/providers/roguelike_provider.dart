// features/roguelike/providers/roguelike_provider.dart

import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_state.dart';
import '../models/map_cell.dart';
import '../models/game_event.dart';
import '../models/enemy.dart';
import '../models/dungeon.dart';
import '../models/action_log.dart';
import '../models/outcome.dart';
import '../models/equipment.dart';
import '../models/bag_item.dart';
import '../models/element_affinity.dart';
import '../data/roguelike_datasource.dart';

final roguelikeProvider =
    StateNotifierProvider<RoguelikeNotifier, GameState?>((ref) => RoguelikeNotifier());

/// 冒険履歴のデータソース。
final roguelikeDatasourceProvider =
    Provider<RoguelikeDatasource>((ref) => RoguelikeDatasource());

/// 直近の冒険履歴（userId 別・最新5件）。
final recentRunsProvider =
    StreamProvider.family<List<RoguelikeRunSummary>, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(const []);
  return ref.watch(roguelikeDatasourceProvider).watchRecentRuns(userId: userId);
});

/// 冒険の記録一覧（履歴画面用・最新30件）。
final roguelikeHistoryProvider =
    StreamProvider.family<List<RoguelikeRunSummary>, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(const []);
  return ref.watch(roguelikeDatasourceProvider).watchRecentRuns(userId: userId, limit: 30);
});

/// 克服済みダンジョン（悩み）IDの集合（userId 別）。
final clearedDungeonsProvider =
    StreamProvider.family<Set<String>, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(const {});
  return ref.watch(roguelikeDatasourceProvider).watchClears(userId: userId);
});

/// 図鑑（出会ったイベント・敵・獲得称号の累積）（userId 別）。
final codexProvider =
    StreamProvider.family<RoguelikeCodex, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(const RoguelikeCodex());
  return ref.watch(roguelikeDatasourceProvider).watchCodex(userId: userId);
});

/// 全踏破の総合診断（保存済みのAI生成テキスト）（userId 別）。
final roguelikeDiagnosisProvider =
    StreamProvider.family<RoguelikeDiagnosis?, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(null);
  return ref.watch(roguelikeDatasourceProvider).watchDiagnosis(userId: userId);
});

/// 全ラン横断で合算した行動傾向（ActionLog）（userId 別）。
final aggregatedTraitsProvider =
    FutureProvider.family<ActionLog, String>((ref, userId) async {
  if (userId.isEmpty) return const ActionLog();
  return ref.watch(roguelikeDatasourceProvider).aggregateRunTraits(userId: userId);
});

/// これまでの冒険ラン数（userId 別）。総合診断の「更新」ボタン表示判定に使う。
final roguelikeRunCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  if (userId.isEmpty) return 0;
  return ref.watch(roguelikeDatasourceProvider).runCount(userId: userId);
});

/// ダンジョンのスタミナ状態（1日1回＋広告で+1回）（userId 別）。
final roguelikeStaminaProvider =
    StreamProvider.family<RoguelikeStamina, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(const RoguelikeStamina());
  return ref.watch(roguelikeDatasourceProvider).watchStamina(userId: userId);
});

/// 指定ダンジョンの最新の踏破ラン（敵図鑑のボス詳細で解析結果を見せる用）。
/// 引数は (userId, dungeonId)。
final latestClearRunProvider =
    StreamProvider.family<RoguelikeRunDetail?, (String, String)>((ref, key) {
  final (userId, dungeonId) = key;
  if (userId.isEmpty) return Stream.value(null);
  return ref
      .watch(roguelikeDatasourceProvider)
      .watchLatestClear(userId: userId, dungeonId: dungeonId);
});

class RoguelikeNotifier extends StateNotifier<GameState?> {
  RoguelikeNotifier() : super(null);

  final _rng = Random();

  void startGame({
    required GrowthStage stage,
    required String element,
    required String characterName,
    required Dungeon dungeon,
  }) {
    state = GameState.initial(
      stage: stage,
      element: element,
      characterName: characterName,
      dungeon: dungeon,
    );
  }

  void resetGame() => state = null;

  // 行動ログに traitDelta を加算する
  ActionLog _mergeTrait(ActionLog base, ActionLog d) => base.copyWith(
    challenge: d.challenge,
    caution: d.caution,
    curiosity: d.curiosity,
    planning: d.planning,
    intuition: d.intuition,
    logic: d.logic,
    cooperation: d.cooperation,
    altruism: d.altruism,
    persistence: d.persistence,
    flexibility: d.flexibility,
  );

  /// 選んだ行動の selectTrait から最も強く出た特性を抽出し、印象的な行動として追記する。
  /// 突出した特性（+2以上）が無ければ追記せず元のリストを返す。
  List<NotableAction> _appendNotable(List<NotableAction> existing, String label, ActionLog t) {
    String? bestKey;
    var best = 0;
    t.toMap().forEach((k, v) {
      if (v > best) {
        best = v;
        bestKey = k;
      }
    });
    if (bestKey == null || best < 2) return existing;
    return [...existing, NotableAction(label: label, trait: bestKey!, delta: best)];
  }

  /// 撃破報酬などのリソース変化を日本語の短い文字列にする（バトルログ表示用）。
  String _formatReward(Map<String, int> r) {
    const labels = {
      'hp': 'HP', 'maxHp': '最大HP', 'food': '食料',
      'money': 'お金', 'items': '回復薬', 'bond': '絆',
    };
    final parts = <String>[];
    r.forEach((k, v) {
      if (v != 0) parts.add('${labels[k] ?? k}${v > 0 ? '+' : ''}$v');
    });
    return parts.join(' / ');
  }

  /// 絆が尽きた（0以下）相棒を離脱させる。離脱した場合は通知を残す。
  /// battle=true ならバトルログへ、false ならイベント通知へ追記する。
  GameState _checkCompanionLeave(GameState s, {required bool battle}) {
    if (s.companion == null || s.bond > 0) return s;
    final name = s.companion!.name;
    if (battle) {
      final msgs = List<String>.from(s.battleMessages)..add('絆が尽き、$nameは去っていった…');
      return s.copyWith(clearCompanion: true, bond: 0, battleMessages: msgs);
    }
    return s.copyWith(clearCompanion: true, bond: 0, eventNotice: '絆が尽き、$nameは去っていった…');
  }

  // 地図イベントの開示効果を適用したマップを返す（効果が無ければ null）。
  List<List<MapCell>>? _applyReveal(GameState s, Outcome o) {
    if (o.revealCells <= 0 && !o.revealTreasure) return null;
    var map = s.map;

    // 宝の地図: 宝箱ノードを判明させる
    if (o.revealTreasure) {
      map = map
          .map((layer) => layer.map((c) =>
              (c.type == CellType.chest && !c.isVisited && !c.isRevealed)
                  ? c.copyWith(isRevealed: true)
                  : c).toList())
          .toList();
    }

    // 地図情報: ランダムな未判明ノードを n 個めくる。
    // 現在ノードからつながる「次の層」ノードは元々判明しているので除外する。
    if (o.revealCells > 0) {
      final reachable = s.reachableIndices;
      final hidden = <MapCell>[];
      for (final layer in map) {
        for (final c in layer) {
          final isReachableNext = c.layer == s.playerLayer + 1 && reachable.contains(c.index);
          if (!c.isVisited && !c.isRevealed && !c.isCurrentPosition &&
              !isReachableNext && c.type != CellType.start) {
            hidden.add(c);
          }
        }
      }
      hidden.shuffle(_rng);
      final pick = hidden.take(o.revealCells).map((c) => (c.layer, c.index)).toSet();
      map = map
          .map((layer) => layer.map((c) =>
              pick.contains((c.layer, c.index)) ? c.copyWith(isRevealed: true) : c).toList())
          .toList();
    }
    return map;
  }

  // 次の層のノードへ進む（枝道式・一方向）。
  void moveToCell(int layer, int index) {
    final s = state;
    if (s == null || s.phase != GamePhase.exploring) return;
    // 進めるのは「次の層」かつ現在ノードからつながっているノードだけ。
    if (layer != s.playerLayer + 1) return;
    if (!s.reachableIndices.contains(index)) return;

    final cell = s.map[layer][index];

    // マップ更新（現在地と訪問済みフラグ）。一方向なので再訪は起きない。
    final newMap = s.map.map((layerList) => layerList.map((c) {
      if (c.layer == s.playerLayer && c.index == s.playerIndex) {
        return c.copyWith(isCurrentPosition: false);
      }
      if (c.layer == layer && c.index == index) {
        return c.copyWith(isVisited: true, isCurrentPosition: true);
      }
      return c;
    }).toList()).toList();

    // 前進で食料消費（2歩ごとに1）。到達層が偶数（L2,4,6）のときに1消費する。
    final newFood = layer % 2 == 0 ? s.food - 1 : s.food;

    var next = s.copyWith(
      map: newMap,
      playerLayer: layer,
      playerIndex: index,
      food: newFood,
    );

    // 餓死チェック
    if (next.food <= 0 && next.hp > 0) {
      next = next.copyWith(hp: next.hp - 5);
    }

    if (next.isDead) {
      state = next.copyWith(phase: GamePhase.gameOver, result: GameResult.failed);
      return;
    }

    // ノードのイベントを発生させる。
    state = _triggerCellEvent(next, cell.type);
  }

  GameState _triggerCellEvent(GameState s, CellType type) {
    switch (type) {
      case CellType.enemy:
        final pool = Dungeons.byId(s.dungeonId).mobPool;
        final enemy = pool[_rng.nextInt(pool.length)];
        return s.copyWith(
          phase: GamePhase.battle,
          currentEnemy: enemy,
          battleMessages: ['${enemy.name}が現れた！'],
          battleHistory: const [],
          battleTurns: 0,
          sealedChoices: const {},
          usedChoices: const {},
          seenEnemies: {...s.seenEnemies, enemy.id},
        );
      case CellType.chest:
      case CellType.rest:
      case CellType.merchant:
      case CellType.companion:
      case CellType.mystery:
        // ノード種別ごとのイベントプールから抽選（種別に合ったイベントのみ）
        final pool = GameEvents.poolByCell[type];
        final basePool = (pool != null && pool.isNotEmpty)
            ? pool
            : GameEvents.all.map((e) => e.id).toList();
        // 相棒の有無でイベントを絞る:
        //  - requiresCompanion: 相棒がいる時だけ（仲間の疲労など）
        //  - excludeWithCompanion: 相棒がいない時だけ（仲間との出会いなど）
        final hasComp = s.hasCompanion;
        final ids = basePool.where((id) {
          final e = GameEvents.byId(id);
          if (e.requiresCompanion && !hasComp) return false;
          if (e.excludeWithCompanion && hasComp) return false;
          return true;
        }).toList();
        if (ids.isEmpty) return s; // 出せるイベントが無ければ素通り
        final event = GameEvents.byId(ids[_rng.nextInt(ids.length)]);
        return s.copyWith(
          phase: GamePhase.event,
          currentEvent: event,
          seenEvents: {...s.seenEvents, event.id},
        );
      case CellType.boss:
        final boss = Dungeons.byId(s.dungeonId).boss;
        return s.copyWith(
          phase: GamePhase.battle,
          currentEnemy: boss,
          battleMessages: ['${boss.name}が立ちはだかった！'],
          battleHistory: const [],
          battleTurns: 0,
          sealedChoices: const {},
          usedChoices: const {},
          seenEnemies: {...s.seenEnemies, boss.id},
        );
      case CellType.start:
      case CellType.empty:
        // 何も起きない（そのまま探索継続）。
        return s;
    }
  }

  // イベント選択肢を選ぶ（確率抽選）
  void chooseEvent(EventChoice choice) {
    final s = state;
    if (s == null || s.phase != GamePhase.event) return;
    if (s.lastChoice != null) return; // 既に選択済み（結果表示中）

    // 装備購入（行商人）は専用処理。今より強ければ金貨を払って装備する。
    if (choice.buyEquipId != null) {
      _handleBuyEquip(s, choice);
      return;
    }

    // 確定コストを先払い（追加食料コスト＝「安全だが遅い」のトレードオフ）
    final up = choice.upfrontCost;
    var hp = s.hp + (up['hp'] ?? 0);
    var food = s.food + (up['food'] ?? 0) - choice.extraFoodCost;
    var money = s.money + (up['money'] ?? 0);
    var items = s.itemCount + (up['items'] ?? 0);

    // 結果を抽選
    final outcome = choice.roll(_rng);
    final ch = outcome.resourceChanges;
    hp += ch['hp'] ?? 0;
    food += ch['food'] ?? 0;
    money += ch['money'] ?? 0;
    items += ch['items'] ?? 0;

    // 食料が足りない分はHPで払う（🍞不足＝餓死的ペナルティ。食料1につき❤️-3）。
    // これで「安全だが遅い（食料コスト）」のトレードオフが食料0でも効く。
    int foodPenaltyHp = 0;
    if (food < 0) {
      foodPenaltyHp = -food * 3;
      hp -= foodPenaltyHp;
      food = 0;
    }

    // 最大HP増加（謎の「気づき＝心が強くなる」等）。増えた分はその場で回復もする。
    final addMaxHp = (up['maxHp'] ?? 0) + (ch['maxHp'] ?? 0);
    final maxHp = s.maxHp + addMaxHp;
    hp += addMaxHp;

    // 相棒・絆の処理。絆が動くのは相棒がいる時、または今この結果で加入する時のみ。
    final hadCompanion = s.hasCompanion;
    final willRecruit = outcome.recruitCompanion != null && !hadCompanion;
    final bondActive = hadCompanion || willRecruit;
    var bond = s.bond;
    if (bondActive) {
      bond += (up['bond'] ?? 0) + (ch['bond'] ?? 0);
    }
    Companion? newCompanion;
    String? notice;
    if (willRecruit) {
      newCompanion = Companion(name: outcome.recruitCompanion!);
      notice = '${newCompanion.name}が仲間に加わった！';
    }

    // 選択時の判断傾向 ＋ 結果による追加傾向 を加算
    final newLog = _mergeTrait(_mergeTrait(s.actionLog, choice.selectTrait), outcome.traitDelta);

    // 地図イベントの開示効果（あればマップ更新）
    final revealedMap = _applyReveal(s, outcome);

    var next = s.copyWith(
      hp: hp,
      maxHp: maxHp,
      food: food,
      money: money,
      bag: s.bagWithPotionCount(items),
      // 鞄に入りきらない回復薬は装備と同じく「捨てるか諦めるか」を選ばせる
      pendingPickupId: s.potionOverflow(items) > 0 ? kPotionId : null,
      bond: bond,
      companion: newCompanion,
      map: revealedMap,
      actionLog: newLog,
      lastChoice: choice,
      lastOutcome: outcome,
      eventNotice: notice,
      clearEventNotice: notice == null,
      phase: GamePhase.event, // 結果表示のため維持
      notableActions: _appendNotable(s.notableActions, choice.label, choice.selectTrait),
    );

    // 結果文への追記（食料不足でHPを削った旨・装備ドロップ）。
    var extraText = '';
    if (foodPenaltyHp > 0) {
      extraText += ' 食料が尽き、体力を削って切り抜けた（❤️-$foodPenaltyHp）。';
    }
    // 装備ドロップ（宝箱・謎など）。今より強ければ乗り換え。
    if (outcome.equipRewardId != null) {
      final item = Equipments.byId(outcome.equipRewardId!);
      if (item != null) {
        final (equipped, msg) = _applyEquip(next, item);
        next = equipped;
        extraText += ' $msg';
      }
    }
    if (extraText.isNotEmpty) {
      next = next.copyWith(
        lastOutcome: Outcome(resultText: '${outcome.resultText}$extraText', tier: outcome.tier),
      );
    }

    if (next.isDead) {
      state = next.copyWith(phase: GamePhase.gameOver, result: GameResult.failed, clearEvent: true, clearLastChoice: true);
      return;
    }

    // 絆が尽きたら相棒離脱（離脱通知で eventNotice を上書き）
    next = _checkCompanionLeave(next, battle: false);

    state = next;
  }

  // イベント結果を閉じて探索へ
  void closeEvent() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(phase: GamePhase.exploring, clearEvent: true, clearLastChoice: true, clearEventNotice: true);
  }

  /// 装備を「今より強ければ乗り換え」で適用する。戻り値は (適用後state, 結果メッセージ)。
  /// 弱い装備なら乗り換えず現状維持（＝ドロップは常に損しない）。
  // ===== 鞄の操作（鞄画面から呼ぶ。探索中・戦闘中いつでも可） =====

  /// 鞄の [index] 番目を装備する。同種の装備は自動的に外れる。
  /// 装備の持ち替えは柔軟性、状況に応じた判断として記録する。
  void equipFromBag(int index) {
    final s = state;
    if (s == null) return;
    final item = s.bag[index].equipment;
    if (item == null) return;
    final before = item.kind == EquipKind.weapon ? s.weapon : s.armor;
    // 何も装備していない所への装備は「持ち替え」ではないので特性を動かさない。
    final isSwap = before != null && before.id != item.id;
    state = s.copyWith(
      bag: s.bagEquipped(index),
      actionLog: isSwap
          ? _mergeTrait(s.actionLog, const ActionLog(flexibility: 1, challenge: 1))
          : s.actionLog,
    );
  }

  /// 鞄の [index] 番目の装備を外す。
  void unequipFromBag(int index) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(bag: s.bagUnequipped(index));
  }

  /// 鞄の [index] 番目を捨てる。**行商人がいなくても、いつでもできる。**
  /// 捨てた対象で特性が分かれる（回復薬＝守りを手放す／装備＝攻めを手放す）。
  void discardFromBag(int index) {
    final s = state;
    if (s == null || index < 0 || index >= s.bag.length) return;
    final item = s.bag[index];
    state = s.copyWith(
      bag: s.bagRemovedAt(index),
      actionLog: _mergeTrait(
        s.actionLog,
        item.isPotion
            ? const ActionLog(challenge: 1)
            : const ActionLog(caution: 1),
      ),
    );
  }

  /// 鞄の回復薬を1つ使ってHPを回復する。
  void usePotionFromBag(int index) {
    final s = state;
    if (s == null || index < 0 || index >= s.bag.length) return;
    if (!s.bag[index].isPotion) return;
    state = s.copyWith(
      hp: s.hp + kPotionHealAmount,
      bag: s.bagRemovedAt(index),
    );
  }

  /// 鞄の宝の地図を使って宝箱の位置を明かす。
  void useTreasureMapFromBag(int index) {
    final s = state;
    if (s == null || index < 0 || index >= s.bag.length) return;
    if (!s.bag[index].isTreasureMap) return;
    final revealed = [
      for (final row in s.map)
        [
          for (final c in row)
            c.type == CellType.chest ? c.copyWith(isRevealed: true) : c,
        ],
    ];
    state = s.copyWith(
      bag: s.bagRemovedAt(index),
      map: revealed,
      actionLog: _mergeTrait(s.actionLog, const ActionLog(planning: 1)),
    );
  }

  /// 装備を拾ったときの処理。
  ///
  /// - **鞄が満杯**なら `pendingPickupId` を立てて「何を捨てるか／諦めるか」を選ばせる
  /// - **空きがある**なら鞄に入れ、`pendingEquipId` を立てて「装備するか」を選ばせる
  ///
  /// 拾った装備を自動装備しないのは、**持ち替えるかどうか自体が
  /// 執着性⇔柔軟性の判断材料**になるため（設計書 §4）。
  (GameState, String) _applyEquip(GameState s, Equipment item) {
    if (s.bagIsFull) {
      return (
        s.copyWith(pendingPickupId: item.id),
        '${item.emoji}${item.name}を見つけた。だが鞄はいっぱいだ…',
      );
    }
    return (
      s.copyWith(bag: s.bagAdded(item.id), pendingEquipId: item.id),
      '${item.emoji}${item.name}を手に入れた！（${item.effectLabel}）',
    );
  }

  // ===== 行商人での売買（設計書 §3 §7.2） =====

  /// 行商人から [id] を買う。金貨が足りない／鞄が満杯なら何も起きない
  /// （買えるかどうかはUI側でも判定してボタンを無効化する）。
  ///
  /// 買った装備は**自動装備しない**。鞄に入れるだけで、装備は鞄画面で選ぶ。
  void buyFromMerchant(String id) {
    final s = state;
    if (s == null) return;
    final price = BagItem.priceOf(id);
    if (s.money < price || s.bagIsFull) return;

    state = s.copyWith(
      money: s.money - price,
      bag: s.bagAdded(id),
      // 地図の購入は先を見通そうとする行動。
      actionLog: id == kTreasureMapId
          ? _mergeTrait(s.actionLog, const ActionLog(planning: 1, curiosity: 1))
          : s.actionLog,
    );
  }

  /// 鞄の [index] を行商人に売る。**売値は買値の半分（端数切り捨て）。**
  ///
  /// 買値 > 売値が全アイテムで成立するため、売買を繰り返して金貨を増やす
  /// 抜け穴は生じない。
  void sellToMerchant(int index) {
    final s = state;
    if (s == null || index < 0 || index >= s.bag.length) return;
    final item = s.bag[index];
    state = s.copyWith(
      money: s.money + item.sellPrice,
      bag: s.bagRemovedAt(index),
      // 損得を計算して手放す判断。
      actionLog: _mergeTrait(s.actionLog, const ActionLog(logic: 1, planning: 1)),
    );
  }

  // ===== 入手時の分岐（設計書 §4） =====

  /// 満杯時に鞄の [index] を捨てて、待機中のアイテムを受け取る。
  void resolvePickupByDiscard(int index) {
    final s = state;
    final pending = s?.pendingPickupId;
    if (s == null || pending == null) return;
    if (index < 0 || index >= s.bag.length) return;

    final dropped = s.bag[index];
    final afterDrop = s.bagRemovedAt(index);
    state = s.copyWith(
      bag: [...afterDrop, BagItem(pending)],
      clearPendingPickup: true,
      // 手放した対象で分かれる。回復薬＝守りを捨てる／装備＝攻めを捨てる。
      actionLog: _mergeTrait(
        s.actionLog,
        dropped.isPotion
            ? const ActionLog(challenge: 1)
            : const ActionLog(caution: 1),
      ),
    );
  }

  /// 満杯時に新しいアイテムのほうを諦める。
  /// **今持っているものを守るという強い執着のシグナル。**
  void abandonPickup() {
    final s = state;
    if (s == null || s.pendingPickupId == null) return;
    state = s.copyWith(
      clearPendingPickup: true,
      actionLog: _mergeTrait(s.actionLog, const ActionLog(persistence: 2)),
    );
  }

  /// 拾った装備を装備するか決める。
  ///
  /// [equip] が true なら装備する。既に同種を装備していた場合は**持ち替え**になり、
  /// 断った場合は今の装備に固執したとみなす。
  void resolvePendingEquip(bool equip) {
    final s = state;
    final pending = s?.pendingEquipId;
    if (s == null || pending == null) return;

    final item = Equipments.byId(pending);
    if (item == null) {
      state = s.copyWith(clearPendingEquip: true);
      return;
    }
    // 直前に鞄へ入れたもの＝同じIDで未装備の最後の1つ
    final index = s.bag.lastIndexWhere((b) => b.id == pending && !b.equipped);
    final hadSame = (item.kind == EquipKind.weapon ? s.weapon : s.armor) != null;

    if (!equip) {
      state = s.copyWith(
        clearPendingEquip: true,
        // 何も装備していない状態で見送るのは「持ち物を増やしただけ」なので
        // 執着とは言えない。既に装備がある時だけ執着性を加算する。
        actionLog: hadSame
            ? _mergeTrait(s.actionLog, const ActionLog(persistence: 2))
            : s.actionLog,
      );
      return;
    }
    state = s.copyWith(
      bag: index >= 0 ? s.bagEquipped(index) : s.bag,
      clearPendingEquip: true,
      actionLog: hadSame
          ? _mergeTrait(s.actionLog, const ActionLog(flexibility: 1, challenge: 1))
          : s.actionLog,
    );
  }

  /// 行商人での装備購入。今より強く、金貨が足りる時だけ購入・装備する。
  void _handleBuyEquip(GameState s, EventChoice choice) {
    final item = Equipments.byId(choice.buyEquipId!);
    if (item == null) return;
    GameState ns = s;
    String msg;
    if (s.money < item.price) {
      msg = '金貨が足りない…${item.name}（金貨${item.price}）は買えなかった。';
    } else if (s.bagIsFull) {
      msg = '鞄がいっぱいで${item.name}を持てない。何かを手放す必要がある。';
    } else {
      ns = s.copyWith(money: s.money - item.price, bag: s.bagAdded(item.id));
      msg = '${item.emoji}${item.name}を購入！ 鞄に入れた（${item.effectLabel}）。';
    }

    state = ns.copyWith(
      actionLog: _mergeTrait(ns.actionLog, choice.selectTrait),
      lastChoice: choice,
      lastOutcome: Outcome(resultText: msg),
      phase: GamePhase.event,
      notableActions: _appendNotable(ns.notableActions, choice.label, choice.selectTrait),
    );
  }

  // 戦闘アクションを実行
  void performBattleAction(BattleChoice choice) {
    final s = state;
    if (s == null || s.phase != GamePhase.battle || s.currentEnemy == null) return;
    if (s.sealedChoices.contains(choice.label)) return; // 封じられている
    if (s.battleMessages.isNotEmpty) return; // メッセージ送り中は新たな行動を受け付けない

    final enemy = s.currentEnemy!;

    // 逃走は専用処理
    if (choice.isFlee) {
      _handleFlee(s, enemy, choice);
      return;
    }

    // 確定コストを先払い
    final up = choice.upfrontCost;
    var hp = s.hp + (up['hp'] ?? 0);
    var food = s.food + (up['food'] ?? 0);
    var money = s.money + (up['money'] ?? 0);
    var items = s.itemCount + (up['items'] ?? 0);

    // 結果を抽選
    final outcome = choice.roll(_rng);
    final ch = outcome.resourceChanges;
    // 敵から受けるダメージ（このアクションの反動）は防具で軽減（下限1）。自傷コスト（ch['hp']）は対象外。
    final takenDamage = outcome.damageToPlayer > 0
        ? (outcome.damageToPlayer - s.armorDef).clamp(1, 999)
        : 0;
    hp += (ch['hp'] ?? 0) - takenDamage;
    food += ch['food'] ?? 0;
    money += ch['money'] ?? 0;
    items += ch['items'] ?? 0;

    // 絆は相棒がいる時だけ動く（相棒前提の選択肢のみ絆を扱う）
    var bond = s.bond;
    if (s.hasCompanion) {
      bond += (up['bond'] ?? 0) + (ch['bond'] ?? 0);
    }

    // 与ダメ ＝（選択肢の与ダメ ＋ 武器攻撃）× 元素相性倍率。
    final match = elementMatch(s.element, enemy.element);
    final dealtDamage = outcome.damageToEnemy > 0
        ? ((outcome.damageToEnemy + s.weaponAtk) * playerDamageMultiplier(match)).round()
        : 0;
    final newEnemyHp = (enemy.currentHp - dealtDamage).clamp(0, enemy.maxHp);
    final updatedEnemy = enemy.copyWith(currentHp: newEnemyHp);

    final mark = switch (outcome.tier) {
      OutcomeTier.great   => '【大成功】',
      OutcomeTier.failure => '【失敗】',
      OutcomeTier.success => '',
    };
    // 攻撃（与ダメあり）には本編元素の技名＋相性のひとことを付ける。
    final skillPrefix = outcome.damageToEnemy > 0 ? _skillPrefix(s.element, match) : '';
    // 画面に順送りするメッセージ（このアクション分）。先頭は結果テキスト。
    final messages = <String>['$mark$skillPrefix${outcome.resultText}'];
    // ログ用の簡潔な履歴（行動 → 成果）。
    final history = List<String>.from(s.battleHistory)
      ..add(_battleHistoryEntry(choice.label, outcome, defeated: updatedEnemy.isDefeated));

    var next = s.copyWith(
      hp: hp,
      food: food,
      money: money,
      bag: s.bagWithPotionCount(items),
      bond: bond,
      currentEnemy: updatedEnemy,
      battleMessages: messages,
      battleHistory: history,
      // 成功/失敗演出のトリガ（通し番号を進めて結果段階を渡す）
      battleActionSeq: s.battleActionSeq + 1,
      lastBattleTier: outcome.tier,
      // 選択時の判断傾向 ＋ 結果による追加傾向
      actionLog: _mergeTrait(_mergeTrait(s.actionLog, choice.selectTrait), outcome.traitDelta),
      sealedChoices: const {}, // 自分の手番が来たので封じ解除
      // 「1回のみ」の選択肢はこの戦闘中もう出さないよう使用済みに記録する。
      usedChoices: choice.oncePerBattle ? {...s.usedChoices, choice.label} : s.usedChoices,
      notableActions: _appendNotable(s.notableActions, choice.label, choice.selectTrait),
    );

    // 絆を使い切って相棒が離脱した場合の処理（メッセージに追記）
    next = _checkCompanionLeave(next, battle: true);

    if (next.isDead) {
      // メッセージを送り終えてからゲームオーバーへ遷移する（保留）。
      state = next.copyWith(pendingPhase: GamePhase.gameOver, pendingResult: GameResult.failed);
      return;
    }

    if (updatedEnemy.isDefeated) {
      final msgs = List<String>.from(next.battleMessages)..add('${enemy.name}を乗り越えた！');
      if (enemy.isBoss) {
        // ボス（悩み本体）撃破＝そのダンジョンのクリア＝悩みの克服。
        // 物質報酬は付けない（撃破＝即クリア終了のため道中で使えず意味を持たないため）。
        // 「克服」そのもの（心の図鑑への記録・最終ダンジョン解禁）と結果画面の演出が報酬。
        // ここでは victory へ自動遷移せず、撃破状態のまま battle に留める。
        // UI が「結果を見る（広告→結果画面）／見ない（記録せず選択へ）」を提示し、
        // confirmBossVictory() で結果画面へ進める（見ない＝克服も記録しない）。
        state = next.copyWith(
          phase: GamePhase.battle,
          battleMessages: msgs,
          currentEnemy: updatedEnemy,
          enemiesDefeated: next.enemiesDefeated + 1,
        );
      } else {
        // 撃破報酬（悩みを乗り越えた見返り）。HPを削られるだけだった通常戦闘に意味を持たせる。
        final reward = enemy.defeatReward;
        final addMaxHp = reward['maxHp'] ?? 0;
        if (enemy.defeatRewardText.isNotEmpty) msgs.add(enemy.defeatRewardText);
        final desc = _formatReward(reward);
        // 報酬は画面メッセージとログ履歴の両方に出す。
        final hist = next.battleHistory;
        if (desc.isNotEmpty) {
          msgs.add('報酬: $desc');
        }
        state = next.copyWith(
          phase: GamePhase.battle,
          maxHp: next.maxHp + addMaxHp,
          hp: next.hp + (reward['hp'] ?? 0) + addMaxHp, // 最大HP増加分はその場で回復もする
          food: next.food + (reward['food'] ?? 0),
          money: next.money + (reward['money'] ?? 0),
          bag: next.bagWithPotionCount(next.itemCount + (reward['items'] ?? 0)),
          battleMessages: msgs,
          battleHistory: desc.isNotEmpty ? (List<String>.from(hist)..add('報酬: $desc')) : hist,
          currentEnemy: updatedEnemy,
          enemiesDefeated: next.enemiesDefeated + 1,
        );
      }
      return;
    }

    // 敵の反撃（敵ごとの個性）。相性が有利なら被ダメ減・不利なら増。
    next = _enemyCounter(next, updatedEnemy, match);
    next = _checkCompanionLeave(next, battle: true); // 反撃で絆を削られて離脱する場合
    if (next.isDead) {
      state = next.copyWith(pendingPhase: GamePhase.gameOver, pendingResult: GameResult.failed);
      return;
    }

    state = next;
  }

  // 攻撃メッセージの先頭に付ける、本編元素の技名＋相性ひとこと。
  String _skillPrefix(String element, ElementMatch match) {
    final name = skillNameOf(element);
    return switch (match) {
      ElementMatch.advantage => '$name！ 弱点を突いた！ ',
      ElementMatch.disadvantage => '$name…手応えが薄い。 ',
      ElementMatch.neutral => '$name！ ',
    };
  }

  // ログ履歴の1行（行動 → 成果）を組み立てる。装飾的な描写は含めない。
  String _battleHistoryEntry(String label, Outcome o, {required bool defeated}) {
    final tier = switch (o.tier) {
      OutcomeTier.great   => '大成功',
      OutcomeTier.success => '成功',
      OutcomeTier.failure => '失敗',
    };
    final parts = <String>[];
    if (o.damageToEnemy > 0) parts.add('敵に${o.damageToEnemy}');
    if (o.damageToPlayer > 0) parts.add('自分${o.damageToPlayer}');
    const labels = {'hp': '❤️', 'food': '🍞', 'money': '💰', 'items': '🧪', 'bond': '🤝'};
    o.resourceChanges.forEach((k, v) {
      if (v != 0) parts.add('${labels[k] ?? k}${v > 0 ? '+' : ''}$v');
    });
    if (defeated) parts.add('撃破');
    return parts.isEmpty ? '$label → $tier' : '$label → $tier（${parts.join(' / ')}）';
  }

  // 敵の反撃。trait に応じて挙動が変わる。
  GameState _enemyCounter(GameState s, Enemy enemy, ElementMatch match) {
    final turns = s.battleTurns + 1;
    final baseDmg = enemy.counterDamage(turns) + _rng.nextInt(3); // 0〜2の揺らぎ
    // 相性が有利なら反撃ダメージ減、不利なら増。防具で更に軽減。最低1。
    final dmg = ((baseDmg * enemyCounterMultiplier(match)).round() - s.armorDef).clamp(1, 999);

    var hp = s.hp - dmg;
    var food = s.food, money = s.money, bond = s.bond, items = s.itemCount;

    final drain = enemy.counterDrain;
    food += drain['food'] ?? 0;
    money += drain['money'] ?? 0;
    // 絆を削るのは相棒がいる時だけ（相棒不在なら絆は無効）
    final bondDrain = s.hasCompanion ? (drain['bond'] ?? 0) : 0;
    bond += bondDrain;
    items += drain['items'] ?? 0;

    final msgs = List<String>.from(s.battleMessages)
      ..add('${enemy.name}の反撃！ $dmgのダメージ');

    // リソースを奪う敵の描写
    final drainDesc = <String>[];
    if ((drain['food'] ?? 0) < 0) drainDesc.add('食料${drain['food']}');
    if ((drain['money'] ?? 0) < 0) drainDesc.add('金貨${drain['money']}');
    if (bondDrain < 0) drainDesc.add('絆$bondDrain');
    if ((drain['items'] ?? 0) < 0) drainDesc.add('回復薬${drain['items']}');
    if (drainDesc.isNotEmpty) {
      msgs.add('じわじわと蝕まれた（${drainDesc.join(' / ')}）');
    }
    if (enemy.escalates) {
      msgs.add('長引くほど${enemy.name}は力を増していく…');
    }

    // 自己否定: 次のターン、最も強い攻撃手段を封じる
    var sealed = const <String>{};
    if (enemy.trait == EnemyTrait.selfDenial && _rng.nextDouble() < 0.6) {
      final attacks = Enemies.forStage(enemy.choices, s.growthStage)
          .where((c) => !c.isFlee && c.maxDamage > 0)
          .toList()
        ..sort((a, b) => b.maxDamage.compareTo(a.maxDamage));
      if (attacks.isNotEmpty) {
        sealed = {attacks.first.label};
        msgs.add('「${attacks.first.label}」が否定の声に封じられた…次は選べない。');
      }
    }

    return s.copyWith(
      hp: hp,
      food: food,
      money: money,
      bond: bond,
      bag: s.bagWithPotionCount(items),
      battleMessages: msgs,
      battleTurns: turns,
      sealedChoices: sealed,
    );
  }

  // 逃走処理
  void _handleFlee(GameState s, Enemy enemy, BattleChoice choice) {
    // 「逃げる」という判断自体の傾向を加算
    final fleeLog = _mergeTrait(s.actionLog, choice.selectTrait);

    // ボスから逃げると冒険終了（撤退クリア）。メッセージ送り後に遷移。
    if (enemy.isBoss) {
      state = s.copyWith(
        battleMessages: ['迷宮から逃げ出した。冒険はここで終わった。'],
        battleHistory: List<String>.from(s.battleHistory)..add('逃げる → 撤退'),
        battleActionSeq: s.battleActionSeq + 1,
        lastBattleTier: OutcomeTier.failure,
        actionLog: fleeLog,
        pendingPhase: GamePhase.victory,
        pendingResult: GameResult.retreat,
      );
      return;
    }

    // 逃げると悪化する敵（自己否定）
    if (enemy.fleeWorsens) {
      final healed = (enemy.currentHp + 4).clamp(0, enemy.maxHp);
      final dmg = enemy.counterDamage(s.battleTurns + 1) + _rng.nextInt(3);
      var next = s.copyWith(
        hp: s.hp - dmg,
        currentEnemy: enemy.copyWith(currentHp: healed),
        battleMessages: ['背を向けた瞬間、否定の声が大きくなった。逃げきれず、かえって深く傷ついた。'],
        battleHistory: List<String>.from(s.battleHistory)..add('逃げる → 失敗（自分$dmg）'),
        battleTurns: s.battleTurns + 1,
        battleActionSeq: s.battleActionSeq + 1,
        lastBattleTier: OutcomeTier.failure,
        sealedChoices: const {},
        actionLog: fleeLog,
      );
      if (next.isDead) {
        state = next.copyWith(pendingPhase: GamePhase.gameOver, pendingResult: GameResult.failed);
        return;
      }
      state = next;
      return;
    }

    // 通常の逃走（70%で成功）。メッセージ送り後に探索へ戻る。
    if (_rng.nextDouble() < 0.7) {
      state = s.copyWith(
        food: s.food - 1,
        battleMessages: ['うまく逃げ切った。'],
        battleHistory: List<String>.from(s.battleHistory)..add('逃げる → 成功'),
        battleActionSeq: s.battleActionSeq + 1,
        lastBattleTier: OutcomeTier.success,
        actionLog: fleeLog,
        pendingPhase: GamePhase.exploring,
      );
      return;
    }

    // 逃走失敗: 反撃を受けて戦闘継続
    final dmg = enemy.counterDamage(s.battleTurns + 1) + _rng.nextInt(3);
    var next = s.copyWith(
      hp: s.hp - dmg,
      food: s.food - 1,
      battleMessages: ['逃げようとしたが回り込まれた！ $dmgのダメージ'],
      battleHistory: List<String>.from(s.battleHistory)..add('逃げる → 失敗（自分$dmg）'),
      battleTurns: s.battleTurns + 1,
      battleActionSeq: s.battleActionSeq + 1,
      lastBattleTier: OutcomeTier.failure,
      sealedChoices: const {},
      actionLog: fleeLog,
    );
    if (next.isDead) {
      state = next.copyWith(pendingPhase: GamePhase.gameOver, pendingResult: GameResult.failed);
      return;
    }
    state = next;
  }

  // メッセージの順送りを終え、保留中の画面遷移があれば適用する。
  // 戦闘継続中（pendingPhase==null）はメッセージだけ消費する。
  void finishBattleMessages() {
    final s = state;
    if (s == null) return;
    if (s.pendingPhase != null) {
      state = s.copyWith(
        phase: s.pendingPhase,
        result: s.pendingResult,
        clearEnemy: true,   // 戦闘終了：敵・メッセージ・履歴・ターンをリセット
        clearPending: true,
      );
    } else {
      state = s.copyWith(battleMessages: const []);
    }
  }

  // 戦闘勝利後に探索へ
  void closeBattle() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(phase: GamePhase.exploring, clearEnemy: true);
  }

  // ボス撃破を確定してクリア（結果画面へ）。「結果を見る」を選んだ時に呼ぶ。
  void confirmBossVictory() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(phase: GamePhase.victory, result: GameResult.clear, clearEnemy: true);
  }
}
