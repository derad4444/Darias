// features/roguelike/screens/roguelike_result_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/game_state.dart';
import '../providers/roguelike_provider.dart';

class RoguelikeResultScreen extends ConsumerWidget {
  const RoguelikeResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roguelikeProvider);

    if (state == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/roguelike'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isVictory = state.phase == GamePhase.victory;
    final topTraits = state.actionLog.topTraits();
    final inferredElement = state.actionLog.inferredElement();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // 結果タイトル
              Text(
                isVictory ? '冒険完了！' : '冒険終了',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isVictory ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isVictory ? '心の迷宮を踏破した！' : 'また挑戦しよう',
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 24),

              // リソース最終結果
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('最終ステータス', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(emoji: '❤️', label: 'HP', value: '${state.hp}/${state.maxHp}'),
                          _StatItem(emoji: '🍞', label: '食料', value: '${state.food}'),
                          _StatItem(emoji: '💰', label: 'お金', value: '${state.money}'),
                          _StatItem(emoji: '🎒', label: 'アイテム', value: '${state.itemCount}'),
                          _StatItem(emoji: '🤝', label: '絆', value: '${state.bond}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 行動特性グラフ
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('冒険で見えた行動傾向', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 16),
                      ...state.actionLog.toMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _TraitBar(label: entry.key, value: entry.value),
                      )),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 冒険者分析
              Card(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('冒険者としてのあなた', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 12),
                      Text(
                        _generateAnalysis(state, topTraits, inferredElement),
                        style: const TextStyle(height: 1.7, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      if (inferredElement != '無') ...[
                        Row(
                          children: [
                            const Text('冒険中の元素傾向: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(inferredElement, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _elementVsOriginal(state.element, inferredElement, state.characterName),
                          style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ボタン群
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    ref.read(roguelikeProvider.notifier).resetGame();
                    context.go('/roguelike');
                  },
                  child: const Text('もう一度冒険する'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    ref.read(roguelikeProvider.notifier).resetGame();
                    context.go('/');
                  },
                  child: const Text('ホームへ戻る'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _generateAnalysis(GameState state, List<MapEntry<String, int>> topTraits, String inferredElement) {
    final name = state.characterName;
    final hasTraits = topTraits.isNotEmpty && topTraits.first.value > 0;

    if (!hasTraits) {
      return '$nameの冒険が終わりました。今回はまだ多くの選択が行われていませんでした。次の冒険ではもっと多くのことが見えてくるかもしれません。';
    }

    final top1 = topTraits[0].key;
    final top2 = topTraits.length > 1 ? topTraits[1].key : null;

    final traits = top2 != null ? '$top1と$top2' : top1;

    final phaseText = state.phase == GamePhase.victory
        ? '今回の冒険では、最後まで諦めずに迷宮を踏破しました。'
        : '今回の冒険は途中で終わりましたが、その過程に多くのものが見えました。';

    return '$phaseText\n\n特に「$traits」が際立った冒険でした。どんな状況でも一貫した判断が見られます。\n\n数字が全てではありません。あなたがどの瞬間に何を選んだか、その積み重ねがここに表れています。';
  }

  String _elementVsOriginal(String original, String inferred, String name) {
    if (original == inferred) {
      return '$nameは普段の${original}としての傾向が、冒険の中でもそのまま表れていました。非日常の状況でも、自分らしさが出るタイプかもしれません。';
    }
    return '$nameは本編では${original}タイプですが、今回の冒険では${inferred}のような一面も見えました。これは診断が変わったのではなく、非日常の場で見えた別の使い方かもしれません。';
  }
}

class _StatItem extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  const _StatItem({required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _TraitBar extends StatelessWidget {
  final String label;
  final int value;
  const _TraitBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final max = 20; // 表示上の最大値
    final ratio = (value / max).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(width: 56, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 12,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 24, child: Text('$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
      ],
    );
  }
}
