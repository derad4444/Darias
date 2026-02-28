import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/diary_model.dart';
import '../../../data/models/meeting_history_model.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/six_person_meeting_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/diary_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../diary/diary_detail_screen.dart';

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
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('履歴', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          labelColor: accentColor,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: accentColor,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            physics: const BouncingScrollPhysics(),
            children: [
              _ChatHistoryTab(characterId: widget.characterId, accentColor: accentColor),
              _MeetingHistoryTab(characterId: widget.characterId, accentColor: accentColor),
              _DiaryHistoryTab(characterId: widget.characterId, accentColor: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// チャット履歴タブ（iOS版ChatHistoryViewと同じデザイン）
class _ChatHistoryTab extends ConsumerStatefulWidget {
  final String? characterId;
  final Color accentColor;

  const _ChatHistoryTab({this.characterId, required this.accentColor});

  @override
  ConsumerState<_ChatHistoryTab> createState() => _ChatHistoryTabState();
}

class _ChatHistoryTabState extends ConsumerState<_ChatHistoryTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('📜 _ChatHistoryTab - characterId: ${widget.characterId}');
    final messagesAsync = ref.watch(chatHistoryProvider(widget.characterId ?? ''));

    return Column(
      children: [
        // 検索バー（iOS版と同じ）
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'メッセージを検索',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.cancel,
                  color: _searchText.isEmpty ? Colors.grey.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.6),
                ),
                onPressed: _searchText.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _searchController.clear();
                          _searchText = '';
                        });
                        FocusScope.of(context).unfocus();
                      },
              ),
            ],
          ),
        ),

        // コンテンツ
        Expanded(
          child: messagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return _EmptyState(
                  icon: Icons.message_outlined,
                  title: 'チャット履歴がありません',
                  subtitle: 'キャラクターとの会話を始めましょう',
                  accentColor: widget.accentColor,
                );
              }

              // 検索フィルタリング
              final filteredMessages = _searchText.isEmpty
                  ? messages
                  : messages.where((m) =>
                      m.content.toLowerCase().contains(_searchText.toLowerCase()) ||
                      m.analysisResult.toLowerCase().contains(_searchText.toLowerCase())).toList();

              if (filteredMessages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search, size: 50, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('検索結果がありません', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(
                        '「$_searchText」に一致するメッセージが見つかりませんでした',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              // 日付でグループ化
              final groupedMessages = <String, List<PostModel>>{};
              for (final message in filteredMessages) {
                final dateKey = _formatDateKey(message.timestamp);
                groupedMessages.putIfAbsent(dateKey, () => []).add(message);
              }

              // 日付を新しい順にソート（reverse表示のため）
              final sortedKeys = groupedMessages.keys.toList()..sort((a, b) => b.compareTo(a));

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: sortedKeys.length,
                itemBuilder: (context, index) {
                  final dateKey = sortedKeys[index];
                  final dateMessages = groupedMessages[dateKey]!
                    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

                  return Column(
                    children: [
                      // 日付ヘッダー（Column先頭 = reverse表示で上に表示）
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: _ChatDateHeader(dateKey: dateKey),
                      ),
                      // メッセージバブル（古い順 → Column下部が最新 = 画面下部に最新）
                      ...dateMessages.expand((message) => [
                        _ChatBubble(
                          content: message.content,
                          isUser: true,
                          timestamp: message.timestamp,
                          accentColor: widget.accentColor,
                        ),
                        if (message.analysisResult.isNotEmpty)
                          _ChatBubble(
                            content: message.analysisResult,
                            isUser: false,
                            timestamp: message.timestamp,
                            accentColor: widget.accentColor,
                          ),
                      ]),
                    ],
                  );
                },
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: widget.accentColor)),
            error: (e, st) => Center(child: Text('エラー: $e', style: const TextStyle(color: AppColors.textPrimary))),
          ),
        ),
      ],
    );
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }
}

/// チャット日付ヘッダー（iOS版DateHeaderViewと同じデザイン）
class _ChatDateHeader extends StatelessWidget {
  final String dateKey;

  const _ChatDateHeader({required this.dateKey});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Text(
            dateKey,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}

/// チャットバブル（iOS版ChatMessageBubbleと同じデザイン）
class _ChatBubble extends StatelessWidget {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final Color accentColor;

  const _ChatBubble({
    required this.content,
    required this.isUser,
    required this.timestamp,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) const SizedBox(width: 0),
          Container(
            constraints: BoxConstraints(maxWidth: screenWidth * 0.7),
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFFA084CA) : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 0),
        ],
      ),
    );
  }
}

/// 会議履歴タブ（iOS版MeetingHistoryViewと同じデザイン）
class _MeetingHistoryTab extends ConsumerStatefulWidget {
  final String? characterId;
  final Color accentColor;

  const _MeetingHistoryTab({this.characterId, required this.accentColor});

  @override
  ConsumerState<_MeetingHistoryTab> createState() => _MeetingHistoryTabState();
}

class _MeetingHistoryTabState extends ConsumerState<_MeetingHistoryTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🗂️ _MeetingHistoryTab - characterId: ${widget.characterId}');
    final meetingsAsync = ref.watch(meetingHistoryProvider(widget.characterId ?? ''));

    return Column(
      children: [
        // 検索バー（iOS版と同じ）
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: '会議内容を検索',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.cancel,
                  color: _searchText.isEmpty ? Colors.grey.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.6),
                ),
                onPressed: _searchText.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _searchController.clear();
                          _searchText = '';
                        });
                        FocusScope.of(context).unfocus();
                      },
              ),
            ],
          ),
        ),

        // コンテンツ
        Expanded(
          child: meetingsAsync.when(
            data: (meetings) {
              if (meetings.isEmpty) {
                return _EmptyState(
                  icon: Icons.inbox_outlined,
                  title: '会議履歴がありません',
                  subtitle: '「自分会議」ボタンから\n最初の会議を始めてみましょう',
                  accentColor: widget.accentColor,
                );
              }

              // 検索フィルタリング
              final filteredMeetings = _searchText.isEmpty
                  ? meetings
                  : meetings.where((m) => m.userConcern.toLowerCase().contains(_searchText.toLowerCase())).toList();

              if (filteredMeetings.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 50, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('検索結果がありません', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(
                        '「$_searchText」に一致する会議が見つかりませんでした',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: filteredMeetings.length,
                itemBuilder: (context, index) {
                  final meeting = filteredMeetings[index];
                  return _MeetingHistoryCard(
                    meeting: meeting,
                    accentColor: widget.accentColor,
                    characterId: widget.characterId,
                  );
                },
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: widget.accentColor)),
            error: (e, st) => Center(child: Text('エラー: $e', style: const TextStyle(color: AppColors.textPrimary))),
          ),
        ),
      ],
    );
  }
}

/// 空の状態表示
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
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
              icon,
              size: 80,
              color: accentColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 会議履歴カード（iOS版HistoryRowと同じデザイン）
class _MeetingHistoryCard extends ConsumerWidget {
  final MeetingHistoryModel meeting;
  final Color accentColor;
  final String? characterId;

  const _MeetingHistoryCard({required this.meeting, required this.accentColor, this.characterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showMeetingDetail(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // カテゴリバッジとキャッシュバッジ
              Row(
                children: [
                  // カテゴリバッジ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getCategoryIcon(meeting.concernCategory),
                          size: 12,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          meeting.categoryDisplayName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // キャッシュヒットバッジ
                  if (meeting.cacheHit)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history,
                            size: 10,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '再利用',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // 相談内容
              Text(
                meeting.userConcern,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // 日時
              Text(
                _formatRelativeDate(meeting.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'career':
        return Icons.work;
      case 'romance':
        return Icons.favorite;
      case 'money':
        return Icons.attach_money;
      case 'health':
        return Icons.health_and_safety;
      case 'family':
        return Icons.home;
      case 'future':
        return Icons.calendar_today;
      case 'hobby':
        return Icons.brush;
      case 'study':
        return Icons.book;
      case 'moving':
        return Icons.apartment;
      default:
        return Icons.more_horiz;
    }
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'たった今';
        }
        return '${difference.inMinutes}分前';
      }
      return '${difference.inHours}時間前';
    } else if (difference.inDays == 1) {
      return '昨日';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks週間前';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$monthsヶ月前';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years年前';
    }
  }

  void _showMeetingDetail(BuildContext context, WidgetRef ref) {
    final backgroundGradient = ref.read(backgroundGradientProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MeetingDetailSheet(
        meeting: meeting,
        accentColor: accentColor,
        backgroundGradient: backgroundGradient,
        characterId: characterId,
      ),
    );
  }
}

/// 会議詳細シート
class _MeetingDetailSheet extends ConsumerStatefulWidget {
  final MeetingHistoryModel meeting;
  final Color accentColor;
  final Gradient backgroundGradient;
  final String? characterId;

  const _MeetingDetailSheet({
    required this.meeting,
    required this.accentColor,
    required this.backgroundGradient,
    this.characterId,
  });

  @override
  ConsumerState<_MeetingDetailSheet> createState() => _MeetingDetailSheetState();
}

class _MeetingDetailSheetState extends ConsumerState<_MeetingDetailSheet> {
  SixPersonMeetingModel? _meetingData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMeetingDetail();
  }

  Future<void> _loadMeetingDetail() async {
    try {
      final meetingData = await ref
          .read(meetingControllerProvider.notifier)
          .fetchMeetingById(widget.meeting.sharedMeetingId);
      if (mounted) {
        setState(() {
          _meetingData = meetingData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            gradient: widget.backgroundGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ハンドル
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ヘッダー
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      '会議の詳細',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // コンテンツ
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('会議データを読み込み中...'),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                const SizedBox(height: 16),
                                Text('エラー: $_errorMessage'),
                              ],
                            ),
                          )
                        : _meetingData != null
                            ? _buildMeetingContent(scrollController)
                            : const Center(child: Text('会議データが見つかりません')),
              ),

              // 削除ボタン（固定フッター）
              if (!_isLoading && _meetingData != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _confirmDelete(context),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('この会議を削除'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.withValues(alpha: 0.7),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMeetingContent(ScrollController scrollController) {
    final meeting = _meetingData!;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // 相談内容
        _buildSection(
          title: '相談内容',
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.meeting.userConcern,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 参考データ
        _buildSection(
          title: '参考データ',
          child: Text(
            meeting.statsData.displayText,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 会議の内容
        _buildSection(
          title: '会議の内容',
          child: Column(
            children: meeting.conversation.rounds.map((round) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ラウンド ${round.roundNumber}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...round.messages.map((message) => _buildMessageBubble(message)),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),

        // 結論
        _buildConclusionSection(meeting.conversation.conclusion),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会議を削除'),
        content: const Text('この会議を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final charId = widget.characterId;
      // 履歴コレクションから削除（StreamProviderでリアルタイム反映）
      if (charId != null && charId.isNotEmpty) {
        await ref
            .read(meetingControllerProvider.notifier)
            .deleteMeetingHistory(
              characterId: charId,
              historyId: widget.meeting.id,
            );
      }
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildMessageBubble(ConversationMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.person,
            size: 16,
            color: _getCharacterColor(message.characterColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.characterName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.text,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCharacterColor(String colorName) {
    switch (colorName) {
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'brown':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  Widget _buildConclusionSection(MeetingConclusion conclusion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // サマリー
        _buildSection(
          title: '結論',
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.yellow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              conclusion.summary,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // レコメンデーション
        if (conclusion.recommendations.isNotEmpty) ...[
          _buildSection(
            title: 'アドバイス',
            child: Column(
              children: conclusion.recommendations.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key + 1}.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // 次のステップ
        if (conclusion.nextSteps.isNotEmpty)
          _buildSection(
            title: '次のステップ',
            child: Column(
              children: conclusion.nextSteps.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

/// 日記履歴タブ（iOS版DiaryHistoryViewと同じデザイン）
class _DiaryHistoryTab extends ConsumerStatefulWidget {
  final String? characterId;
  final Color accentColor;

  const _DiaryHistoryTab({this.characterId, required this.accentColor});

  @override
  ConsumerState<_DiaryHistoryTab> createState() => _DiaryHistoryTabState();
}

class _DiaryHistoryTabState extends ConsumerState<_DiaryHistoryTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diariesAsync = ref.watch(diariesProvider(widget.characterId ?? ''));

    return Column(
      children: [
        // 検索バー（iOS版と同じ）
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: '日記を検索',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.cancel,
                  color: _searchText.isEmpty ? Colors.grey.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.6),
                ),
                onPressed: _searchText.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _searchController.clear();
                          _searchText = '';
                        });
                        FocusScope.of(context).unfocus();
                      },
              ),
            ],
          ),
        ),

        // コンテンツ
        Expanded(
          child: diariesAsync.when(
            data: (diaries) {
              if (diaries.isEmpty) {
                return _EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: '日記がありません',
                  subtitle: '毎日23:55に日記が届きます',
                  accentColor: widget.accentColor,
                );
              }

              // 検索フィルタリング
              final filteredDiaries = _searchText.isEmpty
                  ? diaries
                  : diaries.where((d) => d.content.toLowerCase().contains(_searchText.toLowerCase())).toList();

              if (filteredDiaries.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search, size: 50, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('検索結果がありません', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(
                        '「$_searchText」に一致する日記が見つかりませんでした',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              // 日付でソート（新しい順）
              final sortedDiaries = List<DiaryModel>.from(filteredDiaries)
                ..sort((a, b) => b.date.compareTo(a.date));

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                physics: const BouncingScrollPhysics(),
                itemCount: sortedDiaries.length,
                itemBuilder: (context, index) {
                  final diary = sortedDiaries[index];
                  return _DiaryCardNew(
                    diary: diary,
                    characterId: widget.characterId,
                    accentColor: widget.accentColor,
                  );
                },
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: widget.accentColor)),
            error: (e, st) => Center(child: Text('エラー: $e', style: const TextStyle(color: AppColors.textPrimary))),
          ),
        ),
      ],
    );
  }
}

/// 日記カード（iOS版DiaryCardViewと同じデザイン）
class _DiaryCardNew extends StatelessWidget {
  final DiaryModel diary;
  final String? characterId;
  final Color accentColor;

  const _DiaryCardNew({
    required this.diary,
    this.characterId,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (characterId != null) {
            showDiaryDetailSheet(
              context: context,
              diary: diary,
              characterId: characterId!,
              accentColor: accentColor,
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日付ヘッダー
              Row(
                children: [
                  Icon(
                    Icons.menu_book,
                    color: Colors.brown.withValues(alpha: 0.7),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${diary.date.year}年${diary.date.month}月${diary.date.day}日',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.brown,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${_getWeekdayString(diary.date)})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.brown.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 日記の内容プレビュー（セリフ体）
              Text(
                diary.content,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'serif',
                  color: Colors.black.withValues(alpha: 0.8),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // コメントがある場合
              if (diary.userComment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.message,
                      size: 10,
                      color: accentColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'コメントあり',
                      style: TextStyle(
                        fontSize: 11,
                        color: accentColor.withValues(alpha: 0.7),
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
