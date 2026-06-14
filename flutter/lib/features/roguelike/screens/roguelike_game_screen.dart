// features/roguelike/screens/roguelike_game_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/game_state.dart';
import '../models/game_event.dart';
import '../models/enemy.dart';
import '../providers/roguelike_provider.dart';
import '../widgets/map_grid_widget.dart';
import '../widgets/resource_bar_widget.dart';

class RoguelikeGameScreen extends ConsumerWidget {
  const RoguelikeGameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(roguelikeProvider);

    if (gameState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/roguelike'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // フェーズ遷移
    if (gameState.phase == GamePhase.victory || gameState.phase == GamePhase.gameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/roguelike/result'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${gameState.characterName}の冒険'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmQuit(context, ref),
        ),
      ),
      body: Column(
        children: [
          ResourceBarWidget(state: gameState),
          Expanded(
            child: switch (gameState.phase) {
              GamePhase.exploring => _ExploringView(state: gameState, ref: ref),
              GamePhase.event     => _EventView(state: gameState, ref: ref),
              GamePhase.battle    => _BattleView(state: gameState, ref: ref),
              _                   => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }

  void _confirmQuit(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('冒険を中断しますか？'),
        content: const Text('中断すると結果が記録されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('続ける')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/roguelike/result');
            },
            child: const Text('中断する', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// --- 探索ビュー ---
class _ExploringView extends StatelessWidget {
  final GameState state;
  final WidgetRef ref;
  const _ExploringView({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ヒント
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.actionsLeft > 0
                        ? '隣のマスをタップして移動できます（残り${state.actionsLeft}回）'
                        : '行動回数がなくなりました',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // マップ
          Expanded(
            child: MapGridWidget(
              state: state,
              onCellTap: (row, col) => ref.read(roguelikeProvider.notifier).moveToCell(row, col),
            ),
          ),
        ],
      ),
    );
  }
}

// --- イベントビュー ---
class _EventView extends StatelessWidget {
  final GameState state;
  final WidgetRef ref;
  const _EventView({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final event = state.currentEvent;
    final lastChoice = state.lastChoice;
    if (event == null) return const SizedBox.shrink();

    // 選択後の結果表示
    if (lastChoice != null) {
      return _EventResultView(event: event, choice: lastChoice, ref: ref);
    }

    // 選択前
    final choices = GameEvents.forStage(event.choices, state.growthStage);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // イベントタイトル
          Text(event.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(event.description, style: const TextStyle(height: 1.6, fontSize: 14)),
          const SizedBox(height: 24),
          const Text('どうする？', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          ...choices.map((choice) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => ref.read(roguelikeProvider.notifier).chooseEvent(choice),
                child: Text(choice.label, style: const TextStyle(fontSize: 14)),
              ),
            ),
          )),
        ],
      ),
    );
  }
}

class _EventResultView extends StatelessWidget {
  final GameEvent event;
  final EventChoice choice;
  final WidgetRef ref;
  const _EventResultView({required this.event, required this.choice, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(event.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('「${choice.label}」を選んだ', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Text(choice.resultText, style: const TextStyle(height: 1.7, fontSize: 14)),
          const SizedBox(height: 24),
          // リソース変化の表示
          _ResourceDeltaRow(changes: choice.resourceChanges),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => ref.read(roguelikeProvider.notifier).closeEvent(),
              child: const Text('続ける'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceDeltaRow extends StatelessWidget {
  final Map<String, int> changes;
  const _ResourceDeltaRow({required this.changes});

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) return const SizedBox.shrink();

    final labels = {'hp': '❤️HP', 'food': '🍞食料', 'money': '💰お金', 'items': '🎒アイテム', 'bond': '🤝絆'};
    final chips = changes.entries
        .where((e) => e.value != 0)
        .map((e) => '${labels[e.key] ?? e.key} ${e.value > 0 ? '+' : ''}${e.value}')
        .toList();

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      children: chips.map((text) {
        final isPositive = text.contains('+');
        return Chip(
          label: Text(text, style: TextStyle(color: isPositive ? Colors.green : Colors.red, fontSize: 12)),
          backgroundColor: (isPositive ? Colors.green : Colors.red).withValues(alpha: 0.1),
        );
      }).toList(),
    );
  }
}

// --- 戦闘ビュー ---
class _BattleView extends StatelessWidget {
  final GameState state;
  final WidgetRef ref;
  const _BattleView({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final enemy = state.currentEnemy;
    if (enemy == null) return const SizedBox.shrink();

    final choices = Enemies.forStage(enemy.choices, state.growthStage);
    final isDefeated = enemy.isDefeated;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 敵情報
          Card(
            color: Colors.red.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(enemy.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${enemy.currentHp}/${enemy.maxHp}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: enemy.currentHp / enemy.maxHp,
                      minHeight: 8,
                      backgroundColor: Colors.red.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation(Colors.red),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(enemy.description, style: const TextStyle(fontSize: 13, height: 1.5)),
                  if (!isDefeated) ...[
                    const SizedBox(height: 8),
                    Text('次の行動: ${enemy.nextAction}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                  ],
                ],
              ),
            ),
          ),

          // バトルログ
          if (state.battleLog.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: state.battleLog.map((log) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $log', style: const TextStyle(fontSize: 12)),
                )).toList(),
              ),
            ),
          ],

          const SizedBox(height: 16),

          if (isDefeated) ...[
            // 撃破後
            Center(
              child: Column(
                children: [
                  Text('${enemy.name}を乗り越えた！', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => ref.read(roguelikeProvider.notifier).closeBattle(),
                      child: const Text('探索を続ける'),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // 戦闘選択肢
            const Text('どうする？', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            ...choices.map((choice) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () => ref.read(roguelikeProvider.notifier).performBattleAction(choice),
                  child: Text(choice.label, style: const TextStyle(fontSize: 14)),
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }
}
