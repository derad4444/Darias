import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/diary_model.dart';
import '../../../data/models/meeting_model.dart';
import '../../../data/models/post_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/diary_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/notification_provider.dart';

/// 履歴タブ
enum HistoryTab { chat, meeting, diary }

/// 統合履歴画面
class UnifiedHistoryScreen extends ConsumerStatefulWidget {
  final String? characterId;

  const UnifiedHistoryScreen({
    super.key,
    this.characterId,
  });

  @override
  ConsumerState<UnifiedHistoryScreen> createState() =>
      _UnifiedHistoryScreenState();
}

class _UnifiedHistoryScreenState extends ConsumerState<UnifiedHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // 日記タブが選択されたらバッジをクリア
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // タブインデックス2（日記）が選択されたらバッジをクリア
    if (_tabController.index == 2 && !_tabController.indexIsChanging) {
      ref.read(notificationServiceProvider).clearBadge();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('履歴'),
        backgroundColor: colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.message),
              text: 'チャット',
            ),
            Tab(
              icon: Icon(Icons.groups),
              text: '会議',
            ),
            Tab(
              icon: Icon(Icons.book),
              text: '日記',
            ),
          ],
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ChatHistoryTab(characterId: widget.characterId),
          _MeetingHistoryTab(),
          _DiaryHistoryTab(characterId: widget.characterId),
        ],
      ),
    );
  }
}

/// チャット履歴タブ
class _ChatHistoryTab extends ConsumerWidget {
  final String? characterId;

  const _ChatHistoryTab({this.characterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(chatHistoryProvider(characterId ?? ''));

    return messagesAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return _EmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'チャット履歴がありません',
            subtitle: 'キャラクターとの会話を始めましょう',
          );
        }

        // 日付でグループ化
        final groupedMessages = <String, List<PostModel>>{};
        for (final message in messages) {
          final dateKey = _formatDateKey(message.timestamp);
          groupedMessages.putIfAbsent(dateKey, () => []).add(message);
        }

        final sortedKeys = groupedMessages.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedKeys.length,
          itemBuilder: (context, index) {
            final dateKey = sortedKeys[index];
            final dateMessages = groupedMessages[dateKey]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateHeader(dateKey: dateKey),
                ...dateMessages.map((message) => _ChatMessageCard(
                      message: message,
                    )),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('エラー: $e')),
    );
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return '今日';
    } else if (messageDate == yesterday) {
      return '昨日';
    } else if (messageDate.year == now.year) {
      return '${date.month}月${date.day}日';
    } else {
      return '${date.year}年${date.month}月${date.day}日';
    }
  }
}

/// 会議履歴タブ
class _MeetingHistoryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsAsync = ref.watch(meetingsProvider);

    return meetingsAsync.when(
      data: (meetings) {
        if (meetings.isEmpty) {
          return _EmptyState(
            icon: Icons.groups,
            title: '会議履歴がありません',
            subtitle: '6人会議を始めてみましょう',
          );
        }

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
                _DateHeader(dateKey: dateKey),
                ...dateMeetings.map((meeting) => _MeetingCard(meeting: meeting)),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('エラー: $e')),
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

/// 日付ヘッダー
class _DateHeader extends StatelessWidget {
  final String dateKey;

  const _DateHeader({required this.dateKey});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        dateKey,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

/// 空の状態表示
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
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
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// チャットメッセージカード
class _ChatMessageCard extends StatelessWidget {
  final PostModel message;

  const _ChatMessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ユーザーのメッセージ
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colorScheme.primary,
                  child: Icon(
                    Icons.person,
                    size: 16,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'あなた',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          Text(
                            _formatTime(message.timestamp),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.content,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // AIの返答（あれば）
            if (message.analysisResult.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.smart_toy,
                      size: 16,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'キャラクター',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message.analysisResult,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// 会議カード
class _MeetingCard extends StatelessWidget {
  final MeetingModel meeting;

  const _MeetingCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/meeting'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.groups,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      meeting.topic,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: meeting.isActive
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      meeting.isActive ? '進行中' : '完了',
                      style: TextStyle(
                        fontSize: 12,
                        color: meeting.isActive ? Colors.blue : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
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
                  const Spacer(),
                  Text(
                    _formatTime(meeting.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
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

/// 日記履歴タブ
class _DiaryHistoryTab extends ConsumerWidget {
  final String? characterId;

  const _DiaryHistoryTab({this.characterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diariesAsync = ref.watch(diariesProvider(characterId ?? ''));

    return diariesAsync.when(
      data: (diaries) {
        if (diaries.isEmpty) {
          return _EmptyState(
            icon: Icons.book_outlined,
            title: '日記がありません',
            subtitle: '毎日23:55に日記が届きます',
          );
        }

        // 日付でグループ化
        final groupedDiaries = <String, List<DiaryModel>>{};
        for (final diary in diaries) {
          final dateKey = _formatDateKey(diary.date);
          groupedDiaries.putIfAbsent(dateKey, () => []).add(diary);
        }

        final sortedKeys = groupedDiaries.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedKeys.length,
          itemBuilder: (context, index) {
            final dateKey = sortedKeys[index];
            final dateDiaries = groupedDiaries[dateKey]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateHeader(dateKey: dateKey),
                ...dateDiaries.map((diary) => _DiaryCard(
                      diary: diary,
                      characterId: characterId,
                    )),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('エラー: $e')),
    );
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final diaryDate = DateTime(date.year, date.month, date.day);

    if (diaryDate == today) {
      return '今日';
    } else if (diaryDate == yesterday) {
      return '昨日';
    } else if (diaryDate.year == now.year) {
      return '${date.month}月${date.day}日';
    } else {
      return '${date.year}年${date.month}月${date.day}日';
    }
  }
}

/// 日記カード
class _DiaryCard extends StatelessWidget {
  final DiaryModel diary;
  final String? characterId;

  const _DiaryCard({
    required this.diary,
    this.characterId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          if (characterId != null) {
            context.push('/diary/${diary.id}?characterId=$characterId');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー
              Row(
                children: [
                  Icon(
                    Icons.book,
                    color: Colors.brown[400],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    diary.dateString,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.brown[600],
                        ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${_getWeekdayString(diary.date)})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.brown[400],
                        ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 内容プレビュー
              Text(
                diary.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'serif',
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // コメントがある場合
              if (diary.userComment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.comment,
                      size: 14,
                      color: colorScheme.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'コメントあり',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary.withValues(alpha: 0.7),
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

  String _getWeekdayString(DateTime date) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return weekdays[date.weekday - 1];
  }
}
