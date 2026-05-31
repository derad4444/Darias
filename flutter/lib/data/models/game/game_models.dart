import 'dart:math';
import 'package:darias/presentation/widgets/character/element_effect_widget.dart';

// ─────────────────── カード ───────────────────

enum CardRarity { common, uncommon, rare }

class GameCard {
  final String id;
  final String name;
  final ElementType element;
  final int power; // 1〜5
  final CardRarity rarity;

  const GameCard({
    required this.id,
    required this.name,
    required this.element,
    required this.power,
    this.rarity = CardRarity.common,
  });

  GameCard copyWithId(String newId) => GameCard(
        id: newId,
        name: name,
        element: element,
        power: power,
        rarity: rarity,
      );
}

// ─────────────────── カードカタログ ───────────────────

const _catalog = <ElementType, List<(String, int, CardRarity)>>{
  ElementType.fire: [
    ('小炎',   1, CardRarity.common),
    ('炎撃',   2, CardRarity.common),
    ('業火',   3, CardRarity.uncommon),
    ('爆炎',   4, CardRarity.rare),
    ('烈火',   3, CardRarity.uncommon),
  ],
  ElementType.water: [
    ('水滴',   1, CardRarity.common),
    ('水流',   2, CardRarity.common),
    ('大波',   3, CardRarity.uncommon),
    ('深流',   4, CardRarity.rare),
    ('氾濫',   2, CardRarity.uncommon),
  ],
  ElementType.wind: [
    ('微風',   1, CardRarity.common),
    ('疾風',   2, CardRarity.common),
    ('旋風',   3, CardRarity.uncommon),
    ('暴風',   4, CardRarity.rare),
    ('竜巻',   3, CardRarity.uncommon),
  ],
  ElementType.earth: [
    ('礫',     1, CardRarity.common),
    ('岩砕',   2, CardRarity.common),
    ('大地',   3, CardRarity.uncommon),
    ('崩石',   4, CardRarity.rare),
    ('地殻',   3, CardRarity.uncommon),
  ],
  ElementType.ice: [
    ('霜',     1, CardRarity.common),
    ('氷刃',   2, CardRarity.common),
    ('吹雪',   3, CardRarity.uncommon),
    ('極氷',   4, CardRarity.rare),
    ('凍波',   2, CardRarity.uncommon),
  ],
  ElementType.thunder: [
    ('静電',   1, CardRarity.common),
    ('電撃',   2, CardRarity.common),
    ('雷鳴',   3, CardRarity.uncommon),
    ('落雷',   4, CardRarity.rare),
    ('天雷',   3, CardRarity.uncommon),
  ],
  ElementType.light: [
    ('残光',   1, CardRarity.common),
    ('光輝',   2, CardRarity.common),
    ('閃光',   3, CardRarity.uncommon),
    ('神光',   4, CardRarity.rare),
    ('浄化',   2, CardRarity.uncommon),
  ],
  ElementType.dark: [
    ('影',     1, CardRarity.common),
    ('影刃',   2, CardRarity.common),
    ('暗黒',   3, CardRarity.uncommon),
    ('深淵',   4, CardRarity.rare),
    ('呪縛',   2, CardRarity.uncommon),
  ],
  ElementType.none: [
    ('弱撃',   1, CardRarity.common),
    ('普通撃', 2, CardRarity.common),
    ('強撃',   3, CardRarity.uncommon),
    ('必殺',   4, CardRarity.rare),
    ('特技',   2, CardRarity.uncommon),
  ],
};

/// 指定属性の15枚シャッフルデッキを生成（各5種×3枚）
List<GameCard> buildDeckForElement(ElementType element) {
  final templates = _catalog[element] ?? _catalog[ElementType.none]!;
  final deck = <GameCard>[];
  var copyIdx = 0;
  for (final (name, power, rarity) in templates) {
    for (var i = 0; i < 3; i++) {
      deck.add(GameCard(
        id: '${element.name}_${name}_$copyIdx',
        name: name,
        element: element,
        power: power,
        rarity: rarity,
      ));
      copyIdx++;
    }
  }
  deck.shuffle(Random());
  return deck;
}

// ─────────────────── 元素相性 ───────────────────

/// 攻撃側が有利な場合 +1 ボーナスを返す（有利なら 1、不利なら -1、中立なら 0）
int elementAdvantage(ElementType attacker, ElementType defender) {
  const beats = <ElementType, ElementType>{
    ElementType.fire:    ElementType.wind,
    ElementType.wind:    ElementType.earth,
    ElementType.earth:   ElementType.water,
    ElementType.water:   ElementType.fire,
    ElementType.thunder: ElementType.ice,
    ElementType.ice:     ElementType.thunder,
    ElementType.light:   ElementType.dark,
    ElementType.dark:    ElementType.light,
  };
  if (beats[attacker] == defender) return 1;
  if (beats[defender] == attacker) return -1;
  return 0;
}

// ─────────────────── ボードセル ───────────────────

class BoardCell {
  final int row;
  final int col;
  final int? ownerId;         // null=空, 0=P1, 1=P2
  final ElementType? element;
  final int power;            // 空のとき 0

  const BoardCell({
    required this.row,
    required this.col,
    this.ownerId,
    this.element,
    this.power = 0,
  });

  bool get isEmpty => ownerId == null;
  bool get isP1 => ownerId == 0;
  bool get isP2 => ownerId == 1;

  BoardCell copyWith({
    int? ownerId,
    ElementType? element,
    int? power,
    bool clearOwner = false,
  }) =>
      BoardCell(
        row: row,
        col: col,
        ownerId: clearOwner ? null : (ownerId ?? this.ownerId),
        element: clearOwner ? null : (element ?? this.element),
        power: clearOwner ? 0 : (power ?? this.power),
      );
}

// ─────────────────── 確定プレイ ───────────────────

class PendingPlay {
  final int playerIdx; // 0 or 1
  final GameCard card;
  final int row;
  final int col;

  const PendingPlay({
    required this.playerIdx,
    required this.card,
    required this.row,
    required this.col,
  });
}

// ─────────────────── ゲームフェーズ ───────────────────

enum GamePhase {
  p1Selecting,  // P1 カード+マス選択中
  p1Confirming, // P1 確定直前（確認ボタン表示）
  handover,     // デバイス渡し
  p2Selecting,  // P2 カード+マス選択中
  p2Confirming,
  resolving,    // 解決アニメーション中
  turnEnd,      // ターン終了（次へ）
  gameOver,
}

// ─────────────────── プレイヤー状態 ───────────────────

class PlayerState {
  final String name;
  final ElementType element;
  final List<GameCard> deck;       // 残りデッキ（未公開）
  final List<GameCard> hand;       // 手札 5枚
  final int? selectedCardIdx;      // 手札中の選択インデックス
  final (int, int)? selectedCell;  // 選択したマス (row, col)

  const PlayerState({
    required this.name,
    required this.element,
    required this.deck,
    required this.hand,
    this.selectedCardIdx,
    this.selectedCell,
  });

  int get score => 0; // board から計算する

  PlayerState copyWith({
    List<GameCard>? deck,
    List<GameCard>? hand,
    int? selectedCardIdx,
    (int, int)? selectedCell,
    bool clearSelection = false,
  }) =>
      PlayerState(
        name: name,
        element: element,
        deck: deck ?? this.deck,
        hand: hand ?? this.hand,
        selectedCardIdx: clearSelection ? null : (selectedCardIdx ?? this.selectedCardIdx),
        selectedCell: clearSelection ? null : (selectedCell ?? this.selectedCell),
      );
}

// ─────────────────── ゲーム状態 ───────────────────

class GameState {
  final GamePhase phase;
  final List<List<BoardCell>> board; // [row][col] 5×5
  final PlayerState p1;
  final PlayerState p2;
  final int turnNumber;   // 1 始まり
  final int maxTurns;     // 15
  final PendingPlay? p1Play;
  final PendingPlay? p2Play;
  final String? resolveMessage;
  final List<(int, int)> lastCapturedCells; // エフェクト用

  const GameState({
    required this.phase,
    required this.board,
    required this.p1,
    required this.p2,
    required this.turnNumber,
    this.maxTurns = 15,
    this.p1Play,
    this.p2Play,
    this.resolveMessage,
    this.lastCapturedCells = const [],
  });

  /// P1 / P2 それぞれの獲得マス数
  int get p1Score => board.expand((r) => r).where((c) => c.isP1).length;
  int get p2Score => board.expand((r) => r).where((c) => c.isP2).length;
  int get emptyCount => board.expand((r) => r).where((c) => c.isEmpty).length;

  bool get isBoardFull => emptyCount == 0;

  GameState copyWith({
    GamePhase? phase,
    List<List<BoardCell>>? board,
    PlayerState? p1,
    PlayerState? p2,
    int? turnNumber,
    PendingPlay? p1Play,
    PendingPlay? p2Play,
    String? resolveMessage,
    List<(int, int)>? lastCapturedCells,
    bool clearP1Play = false,
    bool clearP2Play = false,
    bool clearMessage = false,
  }) =>
      GameState(
        phase: phase ?? this.phase,
        board: board ?? this.board,
        p1: p1 ?? this.p1,
        p2: p2 ?? this.p2,
        turnNumber: turnNumber ?? this.turnNumber,
        maxTurns: maxTurns,
        p1Play: clearP1Play ? null : (p1Play ?? this.p1Play),
        p2Play: clearP2Play ? null : (p2Play ?? this.p2Play),
        resolveMessage: clearMessage ? null : (resolveMessage ?? this.resolveMessage),
        lastCapturedCells: lastCapturedCells ?? this.lastCapturedCells,
      );

  /// 初期ボード（5×5 全空）
  static List<List<BoardCell>> emptyBoard() {
    return List.generate(
      5,
      (r) => List.generate(5, (c) => BoardCell(row: r, col: c)),
    );
  }
}
