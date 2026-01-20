import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/todo_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/memo_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diary_provider.dart';
import '../../providers/ad_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';

/// 統計ダッシュボード画面
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('統計'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 上部バナー広告
            if (shouldShowBannerAd) ...[
              const BannerAdContainer(),
              const SizedBox(height: 16),
            ],

            // 概要カード
            _OverviewCard(),
            const SizedBox(height: 16),

            // TODO統計
            _TodoStatsCard(),
            const SizedBox(height: 16),

            // スケジュール統計
            _ScheduleStatsCard(),
            const SizedBox(height: 16),

            // メモ統計
            _MemoStatsCard(),
            const SizedBox(height: 16),

            // 日記統計
            _DiaryStatsCard(),
            const SizedBox(height: 16),

            // 活動履歴（週間）
            _WeeklyActivityCard(),

            // 下部バナー広告
            if (shouldShowBannerAd) ...[
              const SizedBox(height: 24),
              const BannerAdContainer(),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(userDocProvider).valueOrNull;
    final daysSinceJoined = user != null
        ? DateTime.now().difference(user.createdAt).inDays
        : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '利用状況',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.calendar_month,
                    value: '$daysSinceJoined',
                    label: '利用日数',
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.chat,
                    value: '-',
                    label: '会話回数',
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.star,
                    value: '-',
                    label: '達成率',
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoStatsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(todoStatsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'TODO',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            statsAsync.when(
              data: (stats) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStatItem(
                          label: '合計',
                          value: '${stats.total}',
                          color: colorScheme.primary,
                        ),
                      ),
                      Expanded(
                        child: _MiniStatItem(
                          label: '完了',
                          value: '${stats.completed}',
                          color: Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _MiniStatItem(
                          label: '未完了',
                          value: '${stats.incomplete}',
                          color: Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _MiniStatItem(
                          label: '期限切れ',
                          value: '${stats.overdue}',
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 完了率プログレスバー
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '完了率',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '${stats.total > 0 ? (stats.completed / stats.total * 100).toStringAsFixed(0) : 0}%',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: stats.total > 0 ? stats.completed / stats.total : 0,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('エラー: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleStatsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(allSchedulesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'スケジュール',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            schedulesAsync.when(
              data: (schedules) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final thisWeekEnd = today.add(const Duration(days: 7));
                final thisMonthEnd = DateTime(now.year, now.month + 1, 0);

                final todaySchedules = schedules.where((s) {
                  final startDay = DateTime(s.startDate.year, s.startDate.month, s.startDate.day);
                  return startDay == today;
                }).length;

                final thisWeekSchedules = schedules.where((s) {
                  final startDay = DateTime(s.startDate.year, s.startDate.month, s.startDate.day);
                  return !startDay.isBefore(today) && startDay.isBefore(thisWeekEnd);
                }).length;

                final thisMonthSchedules = schedules.where((s) {
                  final startDay = DateTime(s.startDate.year, s.startDate.month, s.startDate.day);
                  return startDay.month == now.month && startDay.year == now.year;
                }).length;

                return Row(
                  children: [
                    Expanded(
                      child: _MiniStatItem(
                        label: '今日',
                        value: '$todaySchedules',
                        color: Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _MiniStatItem(
                        label: '今週',
                        value: '$thisWeekSchedules',
                        color: Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _MiniStatItem(
                        label: '今月',
                        value: '$thisMonthSchedules',
                        color: Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _MiniStatItem(
                        label: '全体',
                        value: '${schedules.length}',
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('エラー: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoStatsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memosAsync = ref.watch(memosProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'メモ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            memosAsync.when(
              data: (memos) {
                final pinnedCount = memos.where((m) => m.isPinned).length;
                final withTagCount = memos.where((m) => m.tag.isNotEmpty).length;

                return Row(
                  children: [
                    Expanded(
                      child: _MiniStatItem(
                        label: '合計',
                        value: '${memos.length}',
                        color: colorScheme.primary,
                      ),
                    ),
                    Expanded(
                      child: _MiniStatItem(
                        label: 'ピン留め',
                        value: '$pinnedCount',
                        color: Colors.red,
                      ),
                    ),
                    Expanded(
                      child: _MiniStatItem(
                        label: 'タグ付き',
                        value: '$withTagCount',
                        color: Colors.blue,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('エラー: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryStatsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDocProvider).valueOrNull;
    final characterId = user?.characterId;
    final colorScheme = Theme.of(context).colorScheme;

    if (characterId == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.book, color: Colors.pink),
                  const SizedBox(width: 8),
                  Text(
                    '日記',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('キャラクターを選択すると日記の統計が表示されます'),
            ],
          ),
        ),
      );
    }

    final diariesAsync = ref.watch(diariesProvider(characterId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.book, color: Colors.pink),
                const SizedBox(width: 8),
                Text(
                  '日記',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            diariesAsync.when(
              data: (diaries) {
                final withCommentCount = diaries.where((d) => d.userComment.isNotEmpty).length;

                return Row(
                  children: [
                    Expanded(
                      child: _MiniStatItem(
                        label: '合計',
                        value: '${diaries.length}',
                        color: colorScheme.primary,
                      ),
                    ),
                    Expanded(
                      child: _MiniStatItem(
                        label: 'コメント付き',
                        value: '$withCommentCount',
                        color: Colors.green,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('エラー: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyActivityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '今週の活動',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                final dayOfWeek = (now.weekday - 1 + index - 6) % 7;
                final isToday = index == 6;
                // TODO: 実際の活動データを反映
                final activityLevel = isToday ? 0.8 : (index / 10.0);

                return Column(
                  children: [
                    Text(
                      weekdays[dayOfWeek],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: isToday ? FontWeight.bold : null,
                            color: isToday ? colorScheme.primary : null,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: activityLevel.clamp(0.1, 1.0)),
                        borderRadius: BorderRadius.circular(6),
                        border: isToday
                            ? Border.all(color: colorScheme.primary, width: 2)
                            : null,
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '少',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 4),
                ...List.generate(5, (index) {
                  return Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: (index + 1) * 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                Text(
                  '多',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _MiniStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
