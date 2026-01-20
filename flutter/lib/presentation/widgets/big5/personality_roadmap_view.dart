import 'package:flutter/material.dart';

import '../../../data/services/big5_analysis_service.dart';

/// パーソナリティロードマップビュー
class PersonalityRoadmapView extends StatelessWidget {
  final int answeredCount;
  final int totalQuestions;
  final Big5AnalysisLevel? currentLevel;
  final VoidCallback? onContinue;

  const PersonalityRoadmapView({
    super.key,
    required this.answeredCount,
    this.totalQuestions = 100,
    this.currentLevel,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = answeredCount / totalQuestions;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.3),
            colorScheme.secondaryContainer.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BIG5性格診断',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '$answeredCount / $totalQuestions 問回答済み',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (onContinue != null)
                FilledButton.tonal(
                  onPressed: onContinue,
                  child: const Text('続ける'),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // プログレスバー
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 20),

          // ロードマップ
          _RoadmapSteps(
            answeredCount: answeredCount,
            currentLevel: currentLevel,
          ),
        ],
      ),
    );
  }
}

class _RoadmapSteps extends StatelessWidget {
  final int answeredCount;
  final Big5AnalysisLevel? currentLevel;

  const _RoadmapSteps({
    required this.answeredCount,
    this.currentLevel,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StepData(
        level: Big5AnalysisLevel.basic,
        questionsRequired: 20,
        title: '基本分析',
        description: 'キャリア・恋愛・ストレス対処',
        icon: Icons.star_border,
      ),
      _StepData(
        level: Big5AnalysisLevel.detailed,
        questionsRequired: 50,
        title: '詳細分析',
        description: 'コミュニケーション・自己成長',
        icon: Icons.star_half,
      ),
      _StepData(
        level: Big5AnalysisLevel.complete,
        questionsRequired: 100,
        title: '完全分析',
        description: '全カテゴリの詳細な分析',
        icon: Icons.star,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _StepItem(
            step: steps[i],
            isCompleted: answeredCount >= steps[i].questionsRequired,
            isCurrent: currentLevel == steps[i].level,
            isFirst: i == 0,
            isLast: i == steps.length - 1,
          ),
          if (i < steps.length - 1)
            _StepConnector(
              isCompleted: answeredCount >= steps[i + 1].questionsRequired,
            ),
        ],
      ],
    );
  }
}

class _StepData {
  final Big5AnalysisLevel level;
  final int questionsRequired;
  final String title;
  final String description;
  final IconData icon;

  const _StepData({
    required this.level,
    required this.questionsRequired,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _StepItem extends StatelessWidget {
  final _StepData step;
  final bool isCompleted;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;

  const _StepItem({
    required this.step,
    required this.isCompleted,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isCompleted
        ? Colors.green
        : isCurrent
            ? colorScheme.primary
            : colorScheme.outline;

    return Row(
      children: [
        // アイコン
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.green.withValues(alpha: 0.15)
                : isCurrent
                    ? colorScheme.primary.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
          child: Icon(
            isCompleted ? Icons.check : step.icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),

        // テキスト
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    step.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isCompleted || isCurrent
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${step.questionsRequired}問',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                step.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),

        // ステータスバッジ
        if (isCompleted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '完了',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else if (isCurrent)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '進行中',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  final bool isCompleted;

  const _StepConnector({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(left: 23),
      width: 2,
      height: 24,
      color: isCompleted ? Colors.green : colorScheme.outline.withValues(alpha: 0.3),
    );
  }
}

/// BIG5進捗ビュー（コンパクト版）
class Big5ProgressView extends StatelessWidget {
  final int answeredCount;
  final int totalQuestions;
  final VoidCallback? onTap;

  const Big5ProgressView({
    super.key,
    required this.answeredCount,
    this.totalQuestions = 100,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = answeredCount / totalQuestions;
    final nextMilestone = _getNextMilestone(answeredCount);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 進捗円
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // テキスト
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BIG5性格診断',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextMilestone != null
                          ? 'あと${nextMilestone - answeredCount}問で次のレベル'
                          : '診断完了！',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  int? _getNextMilestone(int current) {
    const milestones = [20, 50, 100];
    for (final m in milestones) {
      if (current < m) return m;
    }
    return null;
  }
}
