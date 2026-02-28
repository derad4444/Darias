import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/big5_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/big5_provider.dart';
import '../../providers/theme_provider.dart';

/// BIG5診断結果画面
class Big5ResultsScreen extends ConsumerWidget {
  const Big5ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDocProvider).valueOrNull;
    final characterId = user?.characterId;
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);

    if (characterId == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('診断結果'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(gradient: backgroundGradient),
          child: const Center(
            child: Text('キャラクターが選択されていません'),
          ),
        ),
      );
    }

    final progressAsync = ref.watch(big5ProgressProvider(characterId));
    final analysisAsync = ref.watch(big5AnalysisDataProvider(characterId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('診断結果'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(big5ProgressProvider(characterId));
              ref.invalidate(big5AnalysisDataProvider(characterId));
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: progressAsync.when(
            data: (progress) => _ResultsBody(
              progress: progress,
              analysisAsync: analysisAsync,
              characterId: characterId,
              accentColor: accentColor,
            ),
            loading: () => Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(accentColor),
              ),
            ),
            error: (e, st) => Center(child: Text('エラー: $e')),
          ),
        ),
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  final Big5Progress progress;
  final AsyncValue<Big5AnalysisData?> analysisAsync;
  final String characterId;
  final Color accentColor;

  const _ResultsBody({
    required this.progress,
    required this.analysisAsync,
    required this.characterId,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (progress.answeredCount < 20) {
      return _NotEnoughDataView(
        progress: progress,
        accentColor: accentColor,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 診断レベル表示
          _LevelCard(
            progress: progress,
            accentColor: accentColor,
          ),
          const SizedBox(height: 16),

          // レーダーチャート
          _RadarChartCard(
            scores: progress.currentScores,
            accentColor: accentColor,
          ),
          const SizedBox(height: 16),

          // 各特性の詳細スコア
          _TraitScoresCard(scores: progress.currentScores),
          const SizedBox(height: 16),

          // 詳細解析（利用可能な場合）
          analysisAsync.when(
            data: (analysis) => analysis != null
                ? _AnalysisSection(
                    analysis: analysis,
                    level: progress.analysisLevel!,
                    accentColor: accentColor,
                  )
                : const SizedBox.shrink(),
            loading: () => Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(accentColor),
                  ),
                ),
              ),
            ),
            error: (e, st) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),

          // 診断を続けるボタン
          if (progress.answeredCount < 100)
            FilledButton.icon(
              onPressed: () => context.push('/big5'),
              icon: const Icon(Icons.psychology),
              label: Text(
                progress.answeredCount < 50
                    ? '50問まで続けて詳細解析を解放'
                    : '100問まで続けて完全解析を解放',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotEnoughDataView extends StatelessWidget {
  final Big5Progress progress;
  final Color accentColor;

  const _NotEnoughDataView({
    required this.progress,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology,
              size: 80,
              color: accentColor.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'データが不足しています',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '診断結果を表示するには\n最低20問の回答が必要です',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '現在: ${progress.answeredCount}問 / 20問',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/big5'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('診断を続ける'),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final Big5Progress progress;
  final Color accentColor;

  const _LevelCard({
    required this.progress,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final level = progress.analysisLevel;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  level?.icon ?? '',
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level?.displayName ?? '',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    Text(
                      '${progress.answeredCount}問回答済み',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.answeredCount / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(accentColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LevelMarker(
                  count: 20,
                  current: progress.answeredCount,
                  label: '基本',
                  accentColor: accentColor,
                ),
                _LevelMarker(
                  count: 50,
                  current: progress.answeredCount,
                  label: '詳細',
                  accentColor: accentColor,
                ),
                _LevelMarker(
                  count: 100,
                  current: progress.answeredCount,
                  label: '完全',
                  accentColor: accentColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelMarker extends StatelessWidget {
  final int count;
  final int current;
  final String label;
  final Color accentColor;

  const _LevelMarker({
    required this.count,
    required this.current,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isAchieved = current >= count;

    return Column(
      children: [
        Icon(
          isAchieved ? Icons.check_circle : Icons.circle_outlined,
          size: 20,
          color: isAchieved ? accentColor : AppColors.textLight,
        ),
        const SizedBox(height: 4),
        Text(
          '$count問',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isAchieved ? accentColor : AppColors.textSecondary,
                fontWeight: isAchieved ? FontWeight.bold : FontWeight.normal,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _RadarChartCard extends StatelessWidget {
  final Big5Scores scores;
  final Color accentColor;

  const _RadarChartCard({
    required this.scores,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '性格プロファイル',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: CustomPaint(
                size: const Size(250, 250),
                painter: _RadarChartPainter(
                  scores: scores,
                  primaryColor: accentColor,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  textColor: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final Big5Scores scores;
  final Color primaryColor;
  final Color backgroundColor;
  final Color textColor;

  _RadarChartPainter({
    required this.scores,
    required this.primaryColor,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 40;

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

    // ラベル
    final labels = ['O', 'C', 'E', 'A', 'N'];
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - math.pi / 2;
      final labelRadius = radius + 20;
      final x = center.dx + labelRadius * math.cos(angle);
      final y = center.dy + labelRadius * math.sin(angle);

      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TraitScoresCard extends StatelessWidget {
  final Big5Scores scores;

  const _TraitScoresCard({required this.scores});

  @override
  Widget build(BuildContext context) {
    final traits = [
      (Big5Trait.openness, scores.openness, Colors.purple),
      (Big5Trait.conscientiousness, scores.conscientiousness, Colors.blue),
      (Big5Trait.extraversion, scores.extraversion, Colors.orange),
      (Big5Trait.agreeableness, scores.agreeableness, Colors.green),
      (Big5Trait.neuroticism, scores.neuroticism, Colors.red),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '各特性スコア',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 16),
            ...traits.map((trait) => _TraitScoreRow(
                  trait: trait.$1,
                  score: trait.$2,
                  color: trait.$3,
                )),
          ],
        ),
      ),
    );
  }
}

class _TraitScoreRow extends StatelessWidget {
  final Big5Trait trait;
  final double score;
  final Color color;

  const _TraitScoreRow({
    required this.trait,
    required this.score,
    required this.color,
  });

  String _getScoreLabel(double score) {
    if (score >= 4.5) return 'とても高い';
    if (score >= 3.5) return '高い';
    if (score >= 2.5) return '普通';
    if (score >= 1.5) return '低い';
    return 'とても低い';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        trait.shortCode,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    trait.displayName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    score.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getScoreLabel(score),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: color,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 5,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisSection extends StatelessWidget {
  final Big5AnalysisData analysis;
  final Big5AnalysisLevel level;
  final Color accentColor;

  const _AnalysisSection({
    required this.analysis,
    required this.level,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final categoryAnalysis = analysis.getAvailableAnalysis(level);
    if (categoryAnalysis == null || categoryAnalysis.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '詳細解析',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
        ),
        ...Big5AnalysisCategory.values.map((category) {
          final detail = categoryAnalysis[category];
          if (detail == null) return const SizedBox.shrink();
          return _AnalysisCategoryCard(
            category: category,
            detail: detail,
            accentColor: accentColor,
          );
        }),
      ],
    );
  }
}

class _AnalysisCategoryCard extends StatelessWidget {
  final Big5AnalysisCategory category;
  final Big5DetailedAnalysis detail;
  final Color accentColor;

  const _AnalysisCategoryCard({
    required this.category,
    required this.detail,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Text(
            category.icon,
            style: const TextStyle(fontSize: 24),
          ),
          title: Text(
            category.displayName,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
          subtitle: Text(
            detail.personalityType,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: accentColor,
                ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.detailedText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (detail.keyPoints.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'ポイント',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...detail.keyPoints.map((point) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: accentColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  point,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
