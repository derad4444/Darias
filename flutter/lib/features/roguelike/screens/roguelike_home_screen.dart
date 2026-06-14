// features/roguelike/screens/roguelike_home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/character_provider.dart';
import '../models/game_state.dart';
import '../providers/roguelike_provider.dart';

class RoguelikeHomeScreen extends ConsumerWidget {
  const RoguelikeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final characterDetailsAsync = ref.watch(userCharacterDetailsProvider(userId));
    final signalCount = ref.watch(signalCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inner Quest'),
        centerTitle: true,
      ),
      body: characterDetailsAsync.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('キャラクターデータが見つかりません'));
          }
          final stage = GrowthStageExt.fromSignalCount(signalCount);
          final element = detail.element ?? '無';
          final name = detail.typeName ?? 'キャラクター';
          return _HomeBody(stage: stage, element: element, characterName: name, ref: ref);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('データの読み込みに失敗しました')),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  final GrowthStage stage;
  final String element;
  final String characterName;
  final WidgetRef ref;

  const _HomeBody({
    required this.stage,
    required this.element,
    required this.characterName,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),

          // タイトル
          Text(
            '心の迷宮',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Inner Quest',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),

          const SizedBox(height: 32),

          // キャラクター情報カード
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('冒険者', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(characterName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatChip(label: '元素', value: element),
                      const SizedBox(width: 12),
                      _StatChip(label: '成長段階', value: stage.label),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 成長段階ごとの説明
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${stage.label}の冒険者として出発します', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_stageDescription(stage), style: const TextStyle(height: 1.6)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ゲーム説明
          const _RuleCard(),

          const SizedBox(height: 32),

          // 冒険開始ボタン
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                ref.read(roguelikeProvider.notifier).startGame(
                  stage: stage,
                  element: element,
                  characterName: characterName,
                );
                context.go('/roguelike/game');
              },
              child: const Text('冒険に出る ⚔️'),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _stageDescription(GrowthStage stage) {
    switch (stage) {
      case GrowthStage.baby:
        return 'HP・アイテムは少なめ。選択肢も限られていますが、それがあなたの今の力です。小さな一歩を踏み出しましょう。';
      case GrowthStage.young:
        return '基本的な探索が可能になりました。観察・回避など、判断の選択肢が増えています。';
      case GrowthStage.adult:
        return '多くの選択肢と豊富なリソースで冒険できます。仲間指示・交渉・特殊行動も使えます。';
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('冒険のルール', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...[
              ('🗺️', '4×4のマップを探索します'),
              ('👣', '行動回数10回以内にゴールを目指します'),
              ('🎯', '隣接するマスにしか移動できません'),
              ('⚔️', '敵と戦い、イベントを選択し進みます'),
              ('📊', '終了後、あなたの行動傾向を分析します'),
            ].map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text(item.$1, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.$2, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
