import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:darias/data/models/game/game_models.dart';
import 'package:darias/presentation/widgets/character/element_effect_widget.dart';

// ─────────────────── Provider ───────────────────

final gameProvider = NotifierProvider<GameNotifier, GameState?>(GameNotifier.new);

// ─────────────────── Notifier ───────────────────

class GameNotifier extends Notifier<GameState?> {
  @override
  GameState? build() => null;

  /// ゲーム開始
  void startGame({
    required String p1Name,
    required ElementType p1Element,
    required String p2Name,
    required ElementType p2Element,
  }) {
    final p1Deck = buildDeckForElement(p1Element);
    final p2Deck = buildDeckForElement(p2Element);

    state = GameState(
      phase: GamePhase.p1Selecting,
      board: GameState.emptyBoard(),
      p1: PlayerState(
        name: p1Name,
        element: p1Element,
        deck: p1Deck.skip(5).toList(),
        hand: p1Deck.take(5).toList(),
      ),
      p2: PlayerState(
        name: p2Name,
        element: p2Element,
        deck: p2Deck.skip(5).toList(),
        hand: p2Deck.take(5).toList(),
      ),
      turnNumber: 1,
    );
  }

  // ─────────── P1 操作 ───────────

  void p1SelectCard(int idx) {
    final s = state;
    if (s == null || s.phase != GamePhase.p1Selecting) return;
    state = s.copyWith(p1: s.p1.copyWith(selectedCardIdx: idx));
  }

  void p1SelectCell(int row, int col) {
    final s = state;
    if (s == null || s.phase != GamePhase.p1Selecting) return;
    // 自分のマスは選択不可
    if (s.board[row][col].isP1) return;
    state = s.copyWith(
      p1: s.p1.copyWith(selectedCell: (row, col)),
      phase: _canConfirm(s.p1.copyWith(selectedCell: (row, col)))
          ? GamePhase.p1Confirming
          : GamePhase.p1Selecting,
    );
  }

  void p1Confirm() {
    final s = state;
    if (s == null || s.phase != GamePhase.p1Confirming) return;
    if (s.p1.selectedCardIdx == null || s.p1.selectedCell == null) return;

    final card = s.p1.hand[s.p1.selectedCardIdx!];
    final (row, col) = s.p1.selectedCell!;
    final play = PendingPlay(playerIdx: 0, card: card, row: row, col: col);

    state = s.copyWith(
      phase: GamePhase.handover,
      p1Play: play,
    );
  }

  // ─────────── デバイス渡し ───────────

  void handoverComplete() {
    final s = state;
    if (s == null || s.phase != GamePhase.handover) return;
    state = s.copyWith(phase: GamePhase.p2Selecting);
  }

  // ─────────── P2 操作 ───────────

  void p2SelectCard(int idx) {
    final s = state;
    if (s == null || s.phase != GamePhase.p2Selecting) return;
    state = s.copyWith(p2: s.p2.copyWith(selectedCardIdx: idx));
  }

  void p2SelectCell(int row, int col) {
    final s = state;
    if (s == null || s.phase != GamePhase.p2Selecting) return;
    if (s.board[row][col].isP2) return;
    state = s.copyWith(
      p2: s.p2.copyWith(selectedCell: (row, col)),
      phase: _canConfirm(s.p2.copyWith(selectedCell: (row, col)))
          ? GamePhase.p2Confirming
          : GamePhase.p2Selecting,
    );
  }

  void p2Confirm() {
    final s = state;
    if (s == null || s.phase != GamePhase.p2Confirming) return;
    if (s.p2.selectedCardIdx == null || s.p2.selectedCell == null) return;

    final card = s.p2.hand[s.p2.selectedCardIdx!];
    final (row, col) = s.p2.selectedCell!;
    final play = PendingPlay(playerIdx: 1, card: card, row: row, col: col);

    state = s.copyWith(
      phase: GamePhase.resolving,
      p2Play: play,
    );

    _resolveRound();
  }

  // ─────────── 解決 ───────────

  void _resolveRound() {
    final s = state;
    if (s == null || s.p1Play == null || s.p2Play == null) return;

    final p1 = s.p1Play!;
    final p2 = s.p2Play!;

    var board = _deepCopyBoard(s.board);
    var p1Hand = List<GameCard>.from(s.p1.hand);
    var p2Hand = List<GameCard>.from(s.p2.hand);
    final captured = <(int, int)>[];
    String message;

    if (p1.row == p2.row && p1.col == p2.col) {
      // ─── 同じマスで激突 ───
      final result = _battle(p1.card, p2.card);
      if (result > 0) {
        board[p1.row][p1.col] = BoardCell(
          row: p1.row, col: p1.col,
          ownerId: 0, element: p1.card.element, power: p1.card.power,
        );
        captured.add((p1.row, p1.col));
        message = '⚔️ ${s.p1.name}の${p1.card.name}が勝利！';
      } else if (result < 0) {
        board[p2.row][p2.col] = BoardCell(
          row: p2.row, col: p2.col,
          ownerId: 1, element: p2.card.element, power: p2.card.power,
        );
        captured.add((p2.row, p2.col));
        message = '⚔️ ${s.p2.name}の${p2.card.name}が勝利！';
      } else {
        message = '⚔️ 引き分け！マスは変化なし';
      }
    } else {
      // ─── 異なるマスに配置 ───
      board = _applyPlay(board, p1, 0, captured);
      board = _applyPlay(board, p2, 1, captured);
      message = '${s.p1.name}: ${p1.card.name} → (${p1.row + 1},${p1.col + 1})  '
          '${s.p2.name}: ${p2.card.name} → (${p2.row + 1},${p2.col + 1})';
    }

    // 手札からプレイしたカードを除く
    p1Hand.removeAt(p1Hand.indexWhere((c) => c.id == p1.card.id));
    p2Hand.removeAt(p2Hand.indexWhere((c) => c.id == p2.card.id));

    state = s.copyWith(
      phase: GamePhase.resolving,
      board: board,
      p1: s.p1.copyWith(hand: p1Hand, clearSelection: true),
      p2: s.p2.copyWith(hand: p2Hand, clearSelection: true),
      resolveMessage: message,
      lastCapturedCells: captured,
    );
  }

  void advanceAfterResolve() {
    final s = state;
    if (s == null || s.phase != GamePhase.resolving) return;

    final isOver = s.turnNumber >= s.maxTurns || s.isBoardFull;
    if (isOver) {
      state = s.copyWith(phase: GamePhase.gameOver, clearP1Play: true, clearP2Play: true);
      return;
    }

    // ドロー
    var p1Deck = List<GameCard>.from(s.p1.deck);
    var p1Hand = List<GameCard>.from(s.p1.hand);
    if (p1Deck.isNotEmpty) {
      p1Hand.add(p1Deck.removeAt(0));
    }

    var p2Deck = List<GameCard>.from(s.p2.deck);
    var p2Hand = List<GameCard>.from(s.p2.hand);
    if (p2Deck.isNotEmpty) {
      p2Hand.add(p2Deck.removeAt(0));
    }

    state = s.copyWith(
      phase: GamePhase.p1Selecting,
      p1: s.p1.copyWith(deck: p1Deck, hand: p1Hand, clearSelection: true),
      p2: s.p2.copyWith(deck: p2Deck, hand: p2Hand, clearSelection: true),
      turnNumber: s.turnNumber + 1,
      clearP1Play: true,
      clearP2Play: true,
      clearMessage: true,
      lastCapturedCells: const [],
    );
  }

  // ─────────── ヘルパー ───────────

  bool _canConfirm(PlayerState p) =>
      p.selectedCardIdx != null && p.selectedCell != null;

  /// 勝者を返す: +1=P1勝, -1=P2勝, 0=引き分け
  int _battle(GameCard c1, GameCard c2) {
    final adv = elementAdvantage(c1.element, c2.element);
    final p1eff = c1.power + (adv > 0 ? 1 : 0);
    final p2eff = c2.power + (adv < 0 ? 1 : 0);
    if (p1eff > p2eff) return 1;
    if (p2eff > p1eff) return -1;
    return 0; // 引き分け: 後から来た攻撃者が負け（守備側優先）
  }

  List<List<BoardCell>> _applyPlay(
    List<List<BoardCell>> board,
    PendingPlay play,
    int ownerId,
    List<(int, int)> captured,
  ) {
    final cell = board[play.row][play.col];
    if (cell.isEmpty) {
      board[play.row][play.col] = BoardCell(
        row: play.row, col: play.col,
        ownerId: ownerId, element: play.card.element, power: play.card.power,
      );
      captured.add((play.row, play.col));
    } else if (cell.ownerId != ownerId) {
      // 相手マスへの侵攻
      final defCard = GameCard(
        id: 'def', name: '', element: cell.element!, power: cell.power,
      );
      final result = ownerId == 0
          ? _battle(play.card, defCard)
          : _battle(defCard, play.card);
      final attackerWon = ownerId == 0 ? result > 0 : result < 0;
      if (attackerWon) {
        board[play.row][play.col] = BoardCell(
          row: play.row, col: play.col,
          ownerId: ownerId, element: play.card.element, power: play.card.power,
        );
        captured.add((play.row, play.col));
      }
    }
    return board;
  }

  List<List<BoardCell>> _deepCopyBoard(List<List<BoardCell>> src) {
    return src.map((row) => row.map((c) => c).toList()).toList();
  }

  void resetGame() => state = null;
}
