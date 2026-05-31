import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:darias/data/models/game/game_models.dart';
import 'package:darias/presentation/providers/game_provider.dart';
import 'package:darias/presentation/widgets/game/game_board_widget.dart';
import 'package:darias/presentation/widgets/game/game_card_widget.dart';
import 'package:darias/presentation/widgets/game/capture_effect_overlay.dart';
import 'package:darias/presentation/widgets/character/element_effect_widget.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    if (game == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A18),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('ゲームが見つかりません',
                  style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/game'),
                child: const Text('ロビーへ戻る'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A18),
      body: SafeArea(
        child: switch (game.phase) {
          GamePhase.p1Selecting ||
          GamePhase.p1Confirming =>
            _SelectionView(game: game, playerIdx: 0),
          GamePhase.handover => _HandoverView(game: game),
          GamePhase.p2Selecting ||
          GamePhase.p2Confirming =>
            _SelectionView(game: game, playerIdx: 1),
          GamePhase.resolving => _ResolutionView(game: game),
          GamePhase.turnEnd   => _ResolutionView(game: game),
          GamePhase.gameOver  => _GameOverView(game: game),
        },
      ),
    );
  }
}

// ─────────────────── 選択フェーズ ───────────────────

class _SelectionView extends ConsumerWidget {
  final GameState game;
  final int playerIdx;

  const _SelectionView({required this.game, required this.playerIdx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gameProvider.notifier);
    final isP1 = playerIdx == 0;
    final player = isP1 ? game.p1 : game.p2;
    final accentColor = isP1 ? Colors.blue.shade400 : Colors.red.shade400;
    final isConfirming = game.phase == (isP1 ? GamePhase.p1Confirming : GamePhase.p2Confirming);

    return Column(
      children: [
        // ヘッダー
        _GameHeader(game: game, playerName: player.name, accentColor: accentColor),

        const SizedBox(height: 12),

        // ボード
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // スコア
                  _ScoreBar(game: game),
                  const SizedBox(height: 12),

                  // ターゲット選択ヒント
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      player.selectedCardIdx == null
                          ? '下の手札からカードを選択してください'
                          : player.selectedCell == null
                              ? 'マスをタップして配置先を選択'
                              : isConfirming
                                  ? '「プレイ確定」を押してください'
                                  : 'マスをタップして配置先を選択',
                      style:
                          TextStyle(color: accentColor, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ボード
                  Center(
                    child: GameBoardWidget(
                      board: game.board,
                      selectedCell: player.selectedCell,
                      interactive: player.selectedCardIdx != null,
                      onCellTap: (row, col) {
                        if (isP1) {
                          notifier.p1SelectCell(row, col);
                        } else {
                          notifier.p2SelectCell(row, col);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 確定ボタン
                  if (isConfirming) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (isP1) {
                            notifier.p1Confirm();
                          } else {
                            notifier.p2Confirm();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          '${player.name} のプレイを確定',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        // 選択リセット
                        if (isP1) {
                          notifier.p1SelectCard(-1);
                        } else {
                          notifier.p2SelectCard(-1);
                        }
                      },
                      child: const Text('選択をやり直す',
                          style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // 手札
                  _HandWidget(
                    hand: player.hand,
                    selectedIdx: player.selectedCardIdx,
                    accentColor: accentColor,
                    onCardTap: (idx) {
                      if (isP1) {
                        notifier.p1SelectCard(idx);
                      } else {
                        notifier.p2SelectCard(idx);
                      }
                    },
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────── デバイス渡し ───────────────────

class _HandoverView extends ConsumerWidget {
  final GameState game;
  const _HandoverView({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: const Color(0xFF0A0A18),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.15),
                  border: Border.all(color: Colors.green.shade400, width: 2),
                ),
                child: const Text('✓', style: TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 24),
              Text(
                '${game.p1.name} のプレイが確定しました',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '（選択内容は相手には見えません）',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 40),
              Text(
                '${game.p2.name} さん、準備ができたらタップしてください',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      ref.read(gameProvider.notifier).handoverComplete(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    '${game.p2.name} の番を開始',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────── 解決フェーズ ───────────────────

class _ResolutionView extends ConsumerStatefulWidget {
  final GameState game;
  const _ResolutionView({required this.game});

  @override
  ConsumerState<_ResolutionView> createState() => _ResolutionViewState();
}

class _ResolutionViewState extends ConsumerState<_ResolutionView> {
  bool _effectDone = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final notifier = ref.read(gameProvider.notifier);
    final p1Play = game.p1Play;
    final p2Play = game.p2Play;

    // ボードのサイズ計算（エフェクト位置合わせ用）
    final screenW = MediaQuery.of(context).size.width;
    final boardSize = (screenW - 32).clamp(0.0, 360.0);
    final cellSize = boardSize / 5;
    const boardTop = 200.0; // 大体の位置（GameBoardWidget が描画される Y座標）
    const boardLeft = 16.0;

    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ターンヘッダー
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      Color(0xFF2D1B69),
                      Color(0xFF1A1A2E),
                    ]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Turn ${game.turnNumber} / ${game.maxTurns}  —  解決！',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 両者のプレイ表示
                Row(
                  children: [
                    Expanded(
                        child: _PlayRevealCard(
                      play: p1Play,
                      playerName: game.p1.name,
                      accentColor: Colors.blue.shade400,
                    )),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('⚔️',
                          style: TextStyle(fontSize: 24)),
                    ),
                    Expanded(
                        child: _PlayRevealCard(
                      play: p2Play,
                      playerName: game.p2.name,
                      accentColor: Colors.red.shade400,
                    )),
                  ],
                ),

                const SizedBox(height: 12),

                // メッセージ
                if (game.resolveMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      game.resolveMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                  ),

                const SizedBox(height: 12),

                // スコア
                _ScoreBar(game: game),
                const SizedBox(height: 12),

                // ボード
                Center(
                  child: GameBoardWidget(
                    board: game.board,
                    interactive: false,
                    showPending: true,
                    p1PendingCell: p1Play != null
                        ? (p1Play.row, p1Play.col)
                        : null,
                    p2PendingCell: p2Play != null
                        ? (p2Play.row, p2Play.col)
                        : null,
                  ),
                ),

                const SizedBox(height: 20),

                // 次へボタン
                if (_effectDone || game.lastCapturedCells.isEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => notifier.advanceAfterResolve(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C3FC7),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        game.turnNumber >= game.maxTurns || game.isBoardFull
                            ? '結果を見る'
                            : 'ターン ${game.turnNumber + 1} へ',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Flame パーティクルエフェクト
        if (game.lastCapturedCells.isNotEmpty && !_effectDone)
          Positioned.fill(
            child: CaptureEffectOverlay(
              capturedCells: game.lastCapturedCells,
              captureElement: p1Play?.card.element ??
                  p2Play?.card.element ??
                  ElementType.none,
              boardLeft: boardLeft,
              boardTop: boardTop,
              cellSize: cellSize,
              onComplete: () {
                if (mounted) setState(() => _effectDone = true);
              },
            ),
          ),
      ],
    );
  }
}

// ─────────────────── ゲームオーバー ───────────────────

class _GameOverView extends ConsumerWidget {
  final GameState game;
  const _GameOverView({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p1Score = game.p1Score;
    final p2Score = game.p2Score;
    final isDraw = p1Score == p2Score;
    final winnerName = p1Score > p2Score ? game.p1.name : game.p2.name;
    final winnerColor =
        p1Score > p2Score ? Colors.blue.shade400 : Colors.red.shade400;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // 勝者発表
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDraw
                      ? [const Color(0xFF2D2D2D), const Color(0xFF1A1A2E)]
                      : [
                          winnerColor.withOpacity(0.4),
                          const Color(0xFF1A1A2E),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isDraw ? Colors.white24 : winnerColor,
                    width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    isDraw ? '🤝' : '🏆',
                    style: const TextStyle(fontSize: 56),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isDraw ? '引き分け！' : '$winnerName の勝利！',
                    style: TextStyle(
                      color: isDraw ? Colors.white : winnerColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // スコア詳細
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  const Text('最終スコア',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ScoreBlock(
                          name: game.p1.name,
                          score: p1Score,
                          color: Colors.blue.shade400,
                          isWinner: p1Score > p2Score),
                      Text(
                        'vs',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 18),
                      ),
                      _ScoreBlock(
                          name: game.p2.name,
                          score: p2Score,
                          color: Colors.red.shade400,
                          isWinner: p2Score > p1Score),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '空きマス: ${game.emptyCount}  /  全25マス',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 最終ボード
            Center(child: GameBoardWidget(board: game.board, interactive: false)),

            const SizedBox(height: 24),

            // ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(gameProvider.notifier).resetGame();
                  context.go('/game');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C3FC7),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('もう一度プレイ',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                ref.read(gameProvider.notifier).resetGame();
                context.go('/');
              },
              child: const Text('ホームへ戻る',
                  style: TextStyle(color: Colors.white38)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────── 共通ウィジェット ───────────────────

class _GameHeader extends StatelessWidget {
  final GameState game;
  final String playerName;
  final Color accentColor;

  const _GameHeader({
    required this.game,
    required this.playerName,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor.withOpacity(0.3), const Color(0xFF0A0A18)],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: accentColor, size: 20),
          const SizedBox(width: 8),
          Text(
            '$playerName のターン',
            style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
          const Spacer(),
          Text(
            'Turn ${game.turnNumber} / ${game.maxTurns}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final GameState game;
  const _ScoreBar({required this.game});

  @override
  Widget build(BuildContext context) {
    final p1 = game.p1Score;
    final p2 = game.p2Score;
    final total = p1 + p2;
    final p1Ratio = total == 0 ? 0.5 : p1 / 25.0;

    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            '$p1',
            style: TextStyle(
                color: Colors.blue.shade400,
                fontWeight: FontWeight.bold,
                fontSize: 16),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 8, color: Colors.red.shade800.withOpacity(0.6)),
                FractionallySizedBox(
                  widthFactor: p1Ratio,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade500,
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '$p2',
            style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class _HandWidget extends StatelessWidget {
  final List<GameCard> hand;
  final int? selectedIdx;
  final Color accentColor;
  final void Function(int) onCardTap;

  const _HandWidget({
    required this.hand,
    required this.selectedIdx,
    required this.accentColor,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '手札 (${hand.length}枚)',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: hand.asMap().entries.map((entry) {
              final idx = entry.key;
              final card = entry.value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GameCardWidget(
                  card: card,
                  isSelected: selectedIdx == idx,
                  onTap: () => onCardTap(idx),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PlayRevealCard extends StatelessWidget {
  final PendingPlay? play;
  final String playerName;
  final Color accentColor;

  const _PlayRevealCard({
    required this.play,
    required this.playerName,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = play;
    if (p == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: const Text('?', textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 24)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(playerName,
              style: TextStyle(
                  color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          GameCardWidget(card: p.card, isSelected: false),
          const SizedBox(height: 6),
          Text(
            '(${p.row + 1}, ${p.col + 1})',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  final String name;
  final int score;
  final Color color;
  final bool isWinner;

  const _ScoreBlock({
    required this.name,
    required this.score,
    required this.color,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isWinner)
          Text('👑', style: const TextStyle(fontSize: 20)),
        Text(
          '$score',
          style: TextStyle(
              color: color,
              fontSize: 36,
              fontWeight: FontWeight.w900),
        ),
        Text(
          name,
          style: TextStyle(
              color: isWinner ? color : Colors.white54,
              fontSize: 13,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.normal),
        ),
        Text('マス', style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}
