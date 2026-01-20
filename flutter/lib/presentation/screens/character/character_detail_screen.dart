import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/character_model.dart';
import '../../providers/character_provider.dart';

/// キャラクター詳細画面
class CharacterDetailScreen extends ConsumerWidget {
  final String characterId;

  const CharacterDetailScreen({
    super.key,
    required this.characterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characterAsync = ref.watch(characterProvider(characterId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('キャラクター詳細'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: characterAsync.when(
        data: (character) => character != null
            ? _CharacterDetailBody(character: character)
            : const Center(child: Text('キャラクターが見つかりません')),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('エラー: $e')),
      ),
    );
  }
}

class _CharacterDetailBody extends StatelessWidget {
  final CharacterModel character;

  const _CharacterDetailBody({required this.character});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ヘッダー部分
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.surface,
                ],
              ),
            ),
            child: Column(
              children: [
                // アバター
                CircleAvatar(
                  radius: 60,
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    character.name.isNotEmpty ? character.name[0] : '?',
                    style: TextStyle(
                      fontSize: 48,
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 名前
                Text(
                  character.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // 性別バッジ
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: character.gender == CharacterGender.male
                        ? Colors.blue.shade100
                        : Colors.pink.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        character.gender == CharacterGender.male
                            ? Icons.male
                            : Icons.female,
                        size: 16,
                        color: character.gender == CharacterGender.male
                            ? Colors.blue
                            : Colors.pink,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        character.gender == CharacterGender.male ? '男性' : '女性',
                        style: TextStyle(
                          color: character.gender == CharacterGender.male
                              ? Colors.blue
                              : Colors.pink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // BIG5スコア
          if (character.big5Scores != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.psychology, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'BIG5性格特性',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // レーダーチャート
                      SizedBox(
                        height: 200,
                        child: CustomPaint(
                          size: const Size(200, 200),
                          painter: _Big5RadarPainter(
                            scores: character.big5Scores!,
                            primaryColor: colorScheme.primary,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            textColor: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 各特性スコア
                      _ScoreRow(
                        label: '経験への開放性 (O)',
                        score: character.big5Scores!.openness,
                        color: Colors.purple,
                      ),
                      _ScoreRow(
                        label: '誠実性 (C)',
                        score: character.big5Scores!.conscientiousness,
                        color: Colors.blue,
                      ),
                      _ScoreRow(
                        label: '外向性 (E)',
                        score: character.big5Scores!.extraversion,
                        color: Colors.orange,
                      ),
                      _ScoreRow(
                        label: '協調性 (A)',
                        score: character.big5Scores!.agreeableness,
                        color: Colors.green,
                      ),
                      _ScoreRow(
                        label: '情緒安定性 (N)',
                        score: character.big5Scores!.neuroticism,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // キャラクター情報
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'キャラクター情報',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      label: 'ID',
                      value: character.id,
                    ),
                    if (character.personalityKey != null)
                      _InfoRow(
                        label: 'パーソナリティキー',
                        value: character.personalityKey!,
                      ),
                    _InfoRow(
                      label: '作成日',
                      value: _formatDate(character.createdAt),
                    ),
                    _InfoRow(
                      label: '更新日',
                      value: _formatDate(character.updatedAt),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _Big5RadarPainter extends CustomPainter {
  final Big5Scores scores;
  final Color primaryColor;
  final Color backgroundColor;
  final Color textColor;

  _Big5RadarPainter({
    required this.scores,
    required this.primaryColor,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 30;

    // 背景のグリッド
    final gridPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i <= 5; i++) {
      final r = radius * (i / 5);
      final path = Path();
      for (var j = 0; j < 5; j++) {
        final angle = (j * 2 * math.pi / 5) - math.pi / 2;
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // データポイント
    final scoreValues = [
      scores.openness,
      scores.conscientiousness,
      scores.extraversion,
      scores.agreeableness,
      scores.neuroticism,
    ];

    final dataPath = Path();
    for (var i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - math.pi / 2;
      final r = radius * (scoreValues[i] / 5);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();

    // 塗りつぶし
    final fillPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dataPath, fillPaint);

    // 線
    final strokePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(dataPath, strokePaint);

    // ポイント
    final pointPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - math.pi / 2;
      final r = radius * (scoreValues[i] / 5);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final double score;
  final Color color;

  const _ScoreRow({
    required this.label,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                score.toStringAsFixed(1),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 5,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
