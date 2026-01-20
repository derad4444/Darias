import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/meeting_model.dart';
import '../../providers/meeting_provider.dart';

/// 会議履歴画面
class MeetingHistoryScreen extends ConsumerWidget {
  const MeetingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(meetingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('会議履歴'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: meetingsAsync.when(
        data: (meetings) => meetings.isEmpty
            ? _EmptyMeetingHistory()
            : _MeetingList(meetings: meetings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('エラー: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/meeting'),
        icon: const Icon(Icons.add),
        label: const Text('新しい会議'),
      ),
    );
  }
}

class _EmptyMeetingHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.groups,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              '会議履歴がありません',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'AIキャラクターたちとの\n6人会議を始めてみましょう',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/meeting'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('会議を開始'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetingList extends StatelessWidget {
  final List<MeetingModel> meetings;

  const _MeetingList({required this.meetings});

  @override
  Widget build(BuildContext context) {
    // 日付でグループ化
    final groupedMeetings = <String, List<MeetingModel>>{};
    for (final meeting in meetings) {
      final dateKey = _formatDateKey(meeting.createdAt);
      groupedMeetings.putIfAbsent(dateKey, () => []).add(meeting);
    }

    final sortedKeys = groupedMeetings.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final dateMeetings = groupedMeetings[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日付ヘッダー
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateKey,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            // 会議カード
            ...dateMeetings.map((meeting) => _MeetingCard(meeting: meeting)),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final meetingDate = DateTime(date.year, date.month, date.day);

    if (meetingDate == today) {
      return '今日';
    } else if (meetingDate == yesterday) {
      return '昨日';
    } else if (meetingDate.year == now.year) {
      return '${date.month}月${date.day}日';
    } else {
      return '${date.year}年${date.month}月${date.day}日';
    }
  }
}

class _MeetingCard extends ConsumerWidget {
  final MeetingModel meeting;

  const _MeetingCard({required this.meeting});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/meeting'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // タイトルとステータス
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meeting.topic,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(isActive: meeting.isActive),
                ],
              ),
              const SizedBox(height: 12),

              // 参加者アバター
              Row(
                children: [
                  ...meeting.participants.take(5).map((p) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            p.name.isNotEmpty ? p.name[0] : '?',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      )),
                  if (meeting.participants.length > 5)
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      child: Text(
                        '+${meeting.participants.length - 5}',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    _formatTime(meeting.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),

              // メッセージ数
              if (meeting.messages.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${meeting.messages.length}件のメッセージ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.blue : Colors.green;
    final label = isActive ? '進行中' : '完了';
    final icon = isActive ? Icons.play_circle : Icons.check_circle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
