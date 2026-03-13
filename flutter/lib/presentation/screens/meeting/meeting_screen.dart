import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/six_person_meeting_model.dart';
import '../../../data/models/todo_model.dart';
import '../../../data/datasources/remote/meeting_datasource.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/todo_provider.dart';
import '../../providers/chat_provider.dart';
import '../main/main_shell_screen.dart';
import '../../../core/theme/app_colors.dart';

/// 6人会議画面（iOS版SixPersonMeetingViewと同じフロー）
class MeetingScreen extends ConsumerStatefulWidget {
  const MeetingScreen({super.key});

  @override
  ConsumerState<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends ConsumerState<MeetingScreen> {
  final _topicController = TextEditingController();
  final _scrollController = ScrollController();

  // API レスポンス
  GenerateMeetingResponse? _meetingResponse;

  // メッセージアニメーション
  List<ConversationMessage> _displayedMessages = [];
  List<ConversationMessage> _allMessages = [];
  bool _isAnimating = false;
  int _animationVersion = 0;

  // UI状態
  bool _isLoading = false;
  bool _showConclusion = false;
  String _concern = '';
  int _userRating = 0;
  int _usageCount = 0;

  @override
  void initState() {
    super.initState();
    _topicController.addListener(_onTextChanged);
    _loadUsageCount();
  }

  void _onTextChanged() {
    setState(() {});
  }

  Future<void> _loadUsageCount() async {
    try {
      final count = await ref
          .read(meetingControllerProvider.notifier)
          .getMeetingUsageCount();
      if (mounted) {
        setState(() {
          _usageCount = count;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _animationVersion++; // cancel any running animation
    _topicController.removeListener(_onTextChanged);
    _topicController.dispose();
    _scrollController.dispose();
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
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
        title: const Text('自分会議'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showCharacterExplanation,
            tooltip: '参加者について',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: _isLoading
              ? _buildLoading()
              : _meetingResponse != null
                  ? _buildMeetingRoom(accentColor)
                  : _buildTopicInput(accentColor),
        ),
      ),
    );
  }

  // ============================================================
  // Phase 1: 入力画面
  // ============================================================

  Widget _buildTopicInput(Color accentColor) {
    final isPremium = ref.watch(effectiveIsPremiumProvider);

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 使用回数バナー（無料ユーザーのみ）
            if (!isPremium) _buildUsageBanner(),

            // ヘッダー
            const Icon(
              Icons.groups,
              size: 48,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            Text(
              '6人の自分があなたの悩みを\n多角的に議論します',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // 悩み入力
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '悩みを入力してください',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: _topicController,
                    decoration: InputDecoration(
                      hintText: '例: 転職すべきか迷っている...',
                      hintStyle: TextStyle(color: AppColors.textLight),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.9),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    maxLines: 6,
                    minLines: 4,
                    maxLength: 500,
                    buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) {
                      return Text(
                        '$currentLength / ${maxLength ?? 500}文字',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // 生成ボタン
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _topicController.text.trim().isEmpty
                    ? null
                    : _startMeeting,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('会議を開始'),
                style: FilledButton.styleFrom(
                  backgroundColor: _topicController.text.trim().isEmpty
                      ? Colors.grey.withValues(alpha: 0.5)
                      : Colors.blue.withValues(alpha: 0.85),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 使用回数バナー（無料ユーザー向け・iOS版と同じデザイン）
  Widget _buildUsageBanner() {
    final bool limitReached = _usageCount >= 1;
    final Color bannerColor = limitReached ? Colors.orange : Colors.blue;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerColor, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                limitReached ? Icons.warning_amber_rounded : Icons.info_outline,
                color: bannerColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      limitReached ? '利用制限に達しました' : '無料プランでは1回のみ利用可能',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      limitReached
                          ? '無料プランでは1回のみ利用可能です'
                          : 'プレミアムなら無制限に利用できます',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => context.push('/premium'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.orange, Colors.red],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'プレミアムで無制限に',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Phase 2: ローディング
  // ============================================================

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            '6人の自分が集まっています...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '会議を準備中です',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Phase 3: 会議室
  // ============================================================

  Widget _buildMeetingRoom(Color accentColor) {
    return Column(
      children: [
        // ヘッダー
        _buildHeader(),

        Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.5),
        ),

        // 会話 + 結論
        Expanded(
          child: ListView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // メッセージ
              ..._displayedMessages.map((message) {
                return _ConversationBubble(message: message);
              }),

              // 結論
              if (_showConclusion) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                _buildConclusion(),
              ],
            ],
          ),
        ),

        Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.5),
        ),

        // フッター
        _buildFooter(accentColor),
      ],
    );
  }

  /// ヘッダー（iOS版と同じ: タイトル、キャッシュバッジ、悩み、統計）
  Widget _buildHeader() {
    final response = _meetingResponse!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                '自分会議',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              // キャッシュヒットバッジ
              if (response.cacheHit)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        '再利用',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _concern,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            response.statsData.displayText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  /// 結論セクション（APIの動的データ）
  Widget _buildConclusion() {
    final conclusion = _meetingResponse!.conversation.conclusion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // サマリー
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.yellow.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '会議の結論',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                conclusion.summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                    ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // アドバイス
        if (conclusion.recommendations.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'アドバイス',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...conclusion.recommendations.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}.',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.value)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // 次のステップ
        if (conclusion.nextSteps.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '次のステップ',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...conclusion.nextSteps.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.value)),
                        // 案3: タスクに追加ボタン
                        GestureDetector(
                          onTap: () => _addNextStepAsTodo(entry.value),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text(
                              '+タスク',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // 案1: チャットで深掘りボタン
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              ref.read(meetingFollowupConclusionProvider.notifier).state =
                  _meetingResponse!.conversation.conclusion.summary;
              ref.read(selectedTabProvider.notifier).state = 0;
              context.go('/');
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('チャットで深掘りする'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue.withValues(alpha: 0.85),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 共有ボタン
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _shareMeeting,
            icon: const Icon(Icons.share, color: Colors.green),
            label:
                const Text('会議結果を共有', style: TextStyle(color: Colors.green)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.green),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 評価ボタン
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showRatingDialog,
            icon: Icon(
              _userRating > 0 ? Icons.star : Icons.star_border,
              color: _userRating > 0 ? Colors.amber : Colors.blue,
            ),
            label: Text(
              _userRating > 0 ? '評価済み ($_userRating)' : 'この会議を評価する',
              style: TextStyle(
                color: _userRating > 0 ? Colors.amber : Colors.blue,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: _userRating > 0 ? Colors.amber : Colors.blue,
              ),
              backgroundColor:
                  _userRating > 0 ? Colors.amber.withValues(alpha: 0.1) : null,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// フッター（iOS版と同じ: アニメーション中は「結論へ」、完了後は「完了」）
  Widget _buildFooter(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // アニメーション中のみ「結論へ」ボタンを表示
          if (_isAnimating && !_showConclusion)
            OutlinedButton.icon(
              onPressed: _skipToConclusion,
              icon: const Icon(Icons.fast_forward),
              label: const Text('結論へ'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          const Spacer(),
          // 完了ボタン
          FilledButton(
            onPressed: () => context.go('/'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue.withValues(alpha: 0.85),
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('完了'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // アクション
  // ============================================================

  /// 会議を開始（generateOrReuseMeeting APIを呼ぶ）
  Future<void> _startMeeting() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    setState(() {
      _isLoading = true;
      _concern = topic;
    });

    try {
      final response = await ref
          .read(meetingControllerProvider.notifier)
          .generateOrReuseMeeting(concern: topic);

      if (response != null && mounted) {
        final allMsgs = response.conversation.rounds
            .expand((round) => round.messages)
            .toList();

        setState(() {
          _meetingResponse = response;
          _allMessages = allMsgs;
          _displayedMessages = [];
          _isLoading = false;
          _isAnimating = true;
          _usageCount = response.usageCount;
        });

        _startAnimation();
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } on MeetingError catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (e.type == MeetingErrorType.premiumRequired) {
        _showUpgradeDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  /// メッセージアニメーション（iOS版と同じ文字数ベース遅延）
  Future<void> _startAnimation() async {
    _animationVersion++;
    final myVersion = _animationVersion;
    int index = 0;

    while (index < _allMessages.length && mounted && _animationVersion == myVersion) {
      final message = _allMessages[index];

      setState(() {
        _displayedMessages = List.from(_displayedMessages)..add(message);
      });

      // スクロールを下に
      _scrollToBottom();

      index++;

      // 文字数ベースの遅延（iOS版と同じ: 基本2.5秒 + min(文字数,150)×0.017秒、最大5秒）
      const baseDelay = 2500;
      final charCount = message.text.length;
      final additionalDelay = min(charCount, 150) * 17;
      final totalDelay = min(baseDelay + additionalDelay, 5000);

      await Future.delayed(Duration(milliseconds: totalDelay));
      if (_animationVersion != myVersion || !mounted) break;
    }

    // 全メッセージ表示完了後、結論を表示
    if (mounted && _animationVersion == myVersion && index >= _allMessages.length) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && _animationVersion == myVersion) {
        setState(() {
          _isAnimating = false;
          _showConclusion = true;
        });
        // 結論へスクロール
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    }
  }

  /// 結論へスキップ
  void _skipToConclusion() {
    _animationVersion++; // cancel running animation
    setState(() {
      _isAnimating = false;
      _displayedMessages = List.from(_allMessages);
      _showConclusion = true;
    });
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// 共有（iOS形式: ハッシュタグ付き動的テキスト）
  void _shareMeeting() {
    final conclusion = _meetingResponse!.conversation.conclusion;
    final recommendations = conclusion.recommendations
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    final nextSteps = conclusion.nextSteps
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');

    final shareText = '''
【自分会議の結論】

📋 相談内容:
$_concern

💡 会議の結論:
${conclusion.summary}

🎯 アドバイス:
$recommendations

📝 次のステップ:
$nextSteps

---
#DARIAS #自分会議 #セルフカウンセリング
DARIASアプリで自分会議を体験しよう！
''';
    Share.share(shareText.trim());
  }

  /// 案3: ネクストステップをタスクに追加
  Future<void> _addNextStepAsTodo(String stepText) async {
    final now = DateTime.now();
    final todo = TodoModel(
      id: '',
      title: stepText,
      description: '自分会議のネクストステップ',
      isCompleted: false,
      dueDate: null,
      priority: TodoPriority.medium,
      tag: '',
      createdAt: now,
      updatedAt: now,
    );

    try {
      await ref.read(todoControllerProvider.notifier).addTodo(todo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('タスクに追加しました'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('タスクの追加に失敗しました: $e')),
        );
      }
    }
  }

  /// 評価ダイアログ（API連携）
  void _showRatingDialog() {
    int tempRating = _userRating;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('この会議を評価'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('会議の満足度を5段階で評価してください'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < tempRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        tempRating = index + 1;
                      });
                    },
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: tempRating > 0
                  ? () async {
                      final meetingId = _meetingResponse?.meetingId;
                      if (meetingId != null) {
                        await ref
                            .read(meetingControllerProvider.notifier)
                            .rateMeeting(meetingId, tempRating);
                      }
                      if (mounted) {
                        setState(() {
                          _userRating = tempRating;
                        });
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('評価を保存しました')),
                        );
                      }
                    }
                  : null,
              child: const Text('送信'),
            ),
          ],
        ),
      ),
    );
  }

  /// プレミアムアップグレードダイアログ
  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('プレミアムプランが必要です'),
        content: const Text(
          '無料プランでは自分会議は1回のみ利用可能です。\nプレミアムにアップグレードすると無制限に利用できます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/premium');
            },
            child: const Text('アップグレード'),
          ),
        ],
      ),
    );
  }

  /// キャラクター説明ダイアログ（iOS版CharacterExplanationViewと同じデザイン）
  void _showCharacterExplanation() {
    final characters = [
      (
        name: '今の自分',
        icon: Icons.person,
        color: Colors.blue,
        description: '現在のあなたの考え方や価値観',
        traits: [
          '現実的な視点で物事を考える',
          '今の状況を踏まえた判断',
          '実際の経験に基づく意見',
          'バランスの取れた視点',
        ],
      ),
      (
        name: '真逆の自分',
        icon: Icons.sync,
        color: Colors.orange,
        description: 'あなたとは正反対の性格を持つ自分',
        traits: [
          '普段とは異なる視点を提供',
          '意外な発見をもたらす',
          '固定観念を打ち破る',
          '新しい可能性を示す',
        ],
      ),
      (
        name: '理想の自分',
        icon: Icons.star,
        color: Colors.purple,
        description: 'なりたい姿、目指している理想の自分',
        traits: [
          '長期的な視点を持つ',
          '理想の価値観で判断',
          '目標達成を重視',
          '成長を促す視点',
        ],
      ),
      (
        name: '本音の自分',
        icon: Icons.account_circle,
        color: Colors.red,
        description: '普段は隠している本当の気持ち',
        traits: [
          '率直な感情を表現',
          '本心からの意見',
          '建前を排除した視点',
          '抑圧された欲求を代弁',
        ],
      ),
      (
        name: '子供の頃の自分',
        icon: Icons.child_care,
        color: Colors.green,
        description: '純粋で素直だった子供時代の自分',
        traits: [
          '純粋な感性で物事を見る',
          '素直な感情表現',
          '夢や希望を大切にする',
          'シンプルな幸せを追求',
        ],
      ),
      (
        name: '未来の自分(70歳)',
        icon: Icons.elderly,
        color: const Color(0xFF996633),
        description: '人生経験を積んだ未来の自分',
        traits: [
          '長い人生経験からの知恵',
          '俯瞰的な視点',
          '本当に大切なものを見抜く',
          '後悔しない選択を促す',
        ],
      ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            gradient: ref.read(backgroundGradientProvider),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.groups, size: 48, color: Colors.blue),
                        const SizedBox(height: 12),
                        Text(
                          '6人の自分について',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'あなたのBIG5性格診断データを基に、\n6つの異なる自分が多角的に議論します',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...characters.map((character) => _CharacterCard(
                        name: character.name,
                        icon: character.icon,
                        color: character.color,
                        description: character.description,
                        traits: character.traits,
                      )),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.yellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lightbulb,
                                color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '会議のポイント',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const _BulletPoint(text: '今の自分と真逆の自分が異なる視点で議論'),
                        const _BulletPoint(text: '理想の自分が目標達成の視点を提供'),
                        const _BulletPoint(text: '本音の自分が率直な感情を表現'),
                        const _BulletPoint(text: '子供の頃の自分が純粋な視点を追加'),
                        const _BulletPoint(text: '未来の自分が長期的な視野で結論'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 会話バブル（iOS版MessageBubbleと同じ: 左右配置・キャラクター別色分け）
// ============================================================

class _ConversationBubble extends StatelessWidget {
  final ConversationMessage message;

  const _ConversationBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isRight = message.position == MessagePosition.right;
    final color = _characterColor(message.characterColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRight) const Spacer(flex: 1),
          Flexible(
            flex: 4,
            child: Column(
              crossAxisAlignment:
                  isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // キャラクター名とアイコン
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isRight) const Spacer(),
                    Icon(
                      _characterIcon(message.characterId),
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      message.characterName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    if (!isRight) const Spacer(),
                  ],
                ),
                const SizedBox(height: 4),
                // メッセージ本文
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isRight
                        ? color.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message.text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          if (!isRight) const Spacer(flex: 1),
        ],
      ),
    );
  }

  static Color _characterColor(String colorName) {
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
        return const Color(0xFF996633);
      default:
        return Colors.grey;
    }
  }

  static IconData _characterIcon(String characterId) {
    switch (characterId) {
      case 'original':
        return Icons.person;
      case 'opposite':
        return Icons.sync;
      case 'ideal':
        return Icons.star;
      case 'shadow':
        return Icons.account_circle;
      case 'child':
        return Icons.child_care;
      case 'wise':
        return Icons.elderly;
      default:
        return Icons.person;
    }
  }
}

// ============================================================
// キャラクターカード（iOS版CharacterCardと同じデザイン）
// ============================================================

class _CharacterCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final List<String> traits;

  const _CharacterCard({
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.traits,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...traits.map((trait) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trait,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// 箇条書きポイント
class _BulletPoint extends StatelessWidget {
  final String text;

  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '•',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
