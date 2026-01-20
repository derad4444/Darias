import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/big5_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/big5_provider.dart';

class Big5DiagnosisScreen extends ConsumerStatefulWidget {
  const Big5DiagnosisScreen({super.key});

  @override
  ConsumerState<Big5DiagnosisScreen> createState() => _Big5DiagnosisScreenState();
}

class _Big5DiagnosisScreenState extends ConsumerState<Big5DiagnosisScreen> {
  @override
  void initState() {
    super.initState();
    // 画面表示時に診断を開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDiagnosis();
    });
  }

  void _startDiagnosis() {
    final user = ref.read(userDocProvider).valueOrNull;
    if (user?.characterId != null) {
      ref.read(big5DiagnosisControllerProvider.notifier).startDiagnosis(
        user!.characterId!,
      );
    }
  }

  void _submitAnswer(int value) {
    final user = ref.read(userDocProvider).valueOrNull;
    if (user?.characterId != null) {
      ref.read(big5DiagnosisControllerProvider.notifier).submitAnswer(
        characterId: user!.characterId!,
        answerValue: value,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDocProvider).valueOrNull;
    final diagnosisState = ref.watch(big5DiagnosisControllerProvider);
    final progressAsync = user?.characterId != null
        ? ref.watch(big5ProgressProvider(user!.characterId!))
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('性格診断'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 進捗バー
          if (progressAsync != null)
            progressAsync.when(
              data: (progress) => _ProgressSection(progress: progress),
              loading: () => const LinearProgressIndicator(),
              error: (e, st) => const SizedBox.shrink(),
            ),

          // メインコンテンツ
          Expanded(
            child: diagnosisState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : diagnosisState.currentQuestion != null
                    ? _QuestionSection(
                        question: diagnosisState.currentQuestion!,
                        onAnswer: _submitAnswer,
                        lastReply: diagnosisState.lastReply,
                      )
                    : _StartSection(
                        onStart: _startDiagnosis,
                        lastReply: diagnosisState.lastReply,
                        progress: progressAsync?.valueOrNull,
                      ),
          ),
        ],
      ),
    );
  }
}

/// 進捗表示セクション
class _ProgressSection extends StatelessWidget {
  final Big5Progress progress;

  const _ProgressSection({required this.progress});

  @override
  Widget build(BuildContext context) {
    final percentage = progress.answeredCount / 100;
    final level = progress.analysisLevel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '回答数: ${progress.answeredCount} / 100',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (level != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${level.icon} ${level.displayName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
            ),
          ),
        ],
      ),
    );
  }
}

/// 質問表示セクション
class _QuestionSection extends StatelessWidget {
  final Big5Question question;
  final Function(int) onAnswer;
  final String? lastReply;

  const _QuestionSection({
    required this.question,
    required this.onAnswer,
    this.lastReply,
  });

  static const _answerOptions = [
    (value: 1, text: '全く当てはまらない', emoji: '😔'),
    (value: 2, text: 'あまり当てはまらない', emoji: '🤔'),
    (value: 3, text: 'どちらでもない', emoji: '😐'),
    (value: 4, text: 'やや当てはまる', emoji: '🙂'),
    (value: 5, text: '非常に当てはまる', emoji: '😊'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 前回の返答（あれば）
          if (lastReply != null && lastReply!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                lastReply!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 質問カード
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '性格診断',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    question.question,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 回答ボタン
          ..._answerOptions.map((option) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AnswerButton(
              value: option.value,
              text: option.text,
              emoji: option.emoji,
              onPressed: () => onAnswer(option.value),
            ),
          )),
        ],
      ),
    );
  }
}

/// 回答ボタン
class _AnswerButton extends StatelessWidget {
  final int value;
  final String text;
  final String emoji;
  final VoidCallback onPressed;

  const _AnswerButton({
    required this.value,
    required this.text,
    required this.emoji,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 12),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$value',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 開始セクション
class _StartSection extends StatelessWidget {
  final VoidCallback onStart;
  final String? lastReply;
  final Big5Progress? progress;

  const _StartSection({
    required this.onStart,
    this.lastReply,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final level = progress?.analysisLevel;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 前回の返答（あれば）
          if (lastReply != null && lastReply!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                lastReply!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
          ],

          // アイコン
          Icon(
            Icons.psychology,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),

          Text(
            'BIG5性格診断',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          if (level != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${level.icon} ${level.displayName}達成',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Text(
            progress?.answeredCount == 0
                ? '100問の質問に答えて、\nあなたの性格を分析しましょう'
                : '${progress?.answeredCount ?? 0}問回答済み\n続きから診断を再開できます',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              progress?.answeredCount == 0 ? '診断を開始' : '診断を続ける',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 説明
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '診断について',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(context, '20問', '基本プログラム解析'),
                  _buildInfoRow(context, '50問', '学習進化解析'),
                  _buildInfoRow(context, '100問', '人格解析（完全版）'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String count, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              count,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
