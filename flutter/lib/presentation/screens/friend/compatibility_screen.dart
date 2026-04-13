import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/friend_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/friend_provider.dart';
import '../../widgets/character_avatar_widget.dart';

class CompatibilityScreen extends ConsumerStatefulWidget {
  final FriendModel friend;
  final String myCharacterId;

  const CompatibilityScreen({
    super.key,
    required this.friend,
    required this.myCharacterId,
  });

  @override
  ConsumerState<CompatibilityScreen> createState() => _CompatibilityScreenState();
}

class _CompatibilityScreenState extends ConsumerState<CompatibilityScreen> {
  CompatibilityResult? _result;
  bool _isLoading = false;
  bool _isInitialLoading = true; // 保存済み結果の読み込み中
  String? _errorMessage;

  // アニメーション用
  final List<CompatibilityMessage> _displayedMessages = [];
  bool _showScores = false;
  Timer? _messageTimer;
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedResult();
  }

  /// 保存済み結果をFirestoreから取得
  Future<void> _loadSavedResult() async {
    final saved = await ref.read(friendControllerProvider.notifier)
        .fetchCompatibilityResult(friendId: widget.friend.id);
    if (!mounted) return;
    if (saved != null) {
      setState(() {
        _result = saved;
        _displayedMessages.addAll(saved.conversation);
        _showScores = true;
        _isInitialLoading = false;
      });
    } else {
      setState(() => _isInitialLoading = false);
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  Future<void> _runDiagnosis() async {
    _messageTimer?.cancel();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _displayedMessages.clear();
      _showScores = false;
      _messageIndex = 0;
    });

    final result = await ref.read(friendControllerProvider.notifier)
        .runCompatibilityDiagnosis(
          friendId: widget.friend.id,
          myCharacterId: widget.myCharacterId,
        );

    setState(() => _isLoading = false);

    if (result == null) {
      setState(() => _errorMessage = '診断に失敗しました。もう一度お試しください。');
      return;
    }

    setState(() => _result = result);
    _startMessageAnimation(result.conversation);
  }

  void _startMessageAnimation(List<CompatibilityMessage> messages) {
    if (messages.isEmpty) {
      setState(() => _showScores = true);
      return;
    }

    _messageTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (_messageIndex >= messages.length) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _showScores = true);
        });
        return;
      }
      setState(() {
        _displayedMessages.add(messages[_messageIndex]);
        _messageIndex++;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final gradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final userAsync = ref.watch(userDocProvider);
    final myUser = userAsync.valueOrNull;

    final myUserId = ref.watch(currentUserIdProvider) ?? '';
    final myInitial = (myUser?.name ?? '自分').isNotEmpty
        ? (myUser?.name ?? '自分')[0]
        : 'M';
    final friendInitial = widget.friend.name.isNotEmpty
        ? widget.friend.name[0]
        : 'F';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
            children: [
              // ヘッダー
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios, color: accentColor),
                    ),
                    Text(
                      '相性診断',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),

              // キャラクターアイコン行
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LabeledAvatar(
                      avatar: CharacterAvatarWidget(
                        userId: myUserId,
                        size: 64,
                        fallbackText: myInitial,
                        fallbackBackgroundColor: accentColor.withValues(alpha: 0.2),
                        fallbackTextColor: accentColor,
                      ),
                      label: myUser?.name ?? '自分',
                      color: accentColor,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(Icons.favorite, color: accentColor.withValues(alpha: 0.6), size: 28),
                    ),
                    _LabeledAvatar(
                      avatar: CharacterAvatarWidget(
                        userId: widget.friend.id,
                        size: 64,
                        fallbackText: friendInitial,
                        fallbackBackgroundColor: Colors.purple.withValues(alpha: 0.2),
                        fallbackTextColor: Colors.purple,
                      ),
                      label: widget.friend.name,
                      color: Colors.purple,
                    ),
                  ],
                ),
              ),

              // メインコンテンツ
              Expanded(
                child: _isInitialLoading
                    ? Center(child: CircularProgressIndicator(color: accentColor))
                    : _isLoading
                        ? _buildLoadingView(accentColor)
                        : _result == null
                            ? _buildStartView(accentColor, myInitial, friendInitial)
                            : _buildConversationAndScores(accentColor, myInitial, friendInitial),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView(Color accentColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: accentColor),
          const SizedBox(height: 20),
          Text(
            'キャラクターが話し合っています...',
            style: TextStyle(color: accentColor, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildStartView(Color accentColor, String myInitial, String friendInitial) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
            Text(
              '${widget.friend.name}との相性を診断します',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'BIG5性格診断をもとに\nキャラクターが相性を語り合います',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _runDiagnosis,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('診断スタート', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationAndScores(
    Color accentColor,
    String myInitial,
    String friendInitial,
  ) {
    final myUserId = ref.read(currentUserIdProvider) ?? '';
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // 会話
        ..._displayedMessages.asMap().entries.map((entry) {
          final msg = entry.value;
          return _MessageBubble(
            message: msg,
            myUserId: myUserId,
            friendUserId: widget.friend.id,
            myInitial: myInitial,
            friendInitial: friendInitial,
            accentColor: accentColor,
          );
        }),

        // スコアカード（会話終了後に表示）
        if (_showScores && _result != null) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'ジャンル別相性',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _ScoreCard(
            icon: '👫',
            label: '友情',
            score: _result!.friendshipScore,
            comment: _result!.friendshipComment,
            color: Colors.blue,
          ),
          _ScoreCard(
            icon: '💕',
            label: '恋愛',
            score: _result!.romanceScore,
            comment: _result!.romanceComment,
            color: Colors.pink,
          ),
          _ScoreCard(
            icon: '💼',
            label: '仕事',
            score: _result!.workScore,
            comment: _result!.workComment,
            color: Colors.orange,
          ),
          _ScoreCard(
            icon: '🤝',
            label: '信頼',
            score: _result!.trustScore,
            comment: _result!.trustComment,
            color: Colors.green,
          ),

          // 総合スコア
          const SizedBox(height: 8),
          _OverallScoreCard(
            score: _result!.overallScore,
            comment: _result!.overallComment,
            accentColor: accentColor,
          ),
          const SizedBox(height: 32),

          // 診断日時と再診断ボタン
          if (_result?.createdAt != null) ...[
            Center(
              child: Text(
                '前回の診断: ${DateFormat('M月d日 HH:mm').format(_result!.createdAt!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Center(
            child: TextButton.icon(
              onPressed: _runDiagnosis,
              icon: Icon(Icons.refresh, color: accentColor),
              label: Text('再診断する', style: TextStyle(color: accentColor)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ],
    );
  }
}

/// ラベル付きアバター
class _LabeledAvatar extends StatelessWidget {
  final Widget avatar;
  final String label;
  final Color color;

  const _LabeledAvatar({
    required this.avatar,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// 会話吹き出し
class _MessageBubble extends StatefulWidget {
  final CompatibilityMessage message;
  final String myUserId;
  final String friendUserId;
  final String myInitial;
  final String friendInitial;
  final Color accentColor;

  const _MessageBubble({
    required this.message,
    required this.myUserId,
    required this.friendUserId,
    required this.myInitial,
    required this.friendInitial,
    required this.accentColor,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(_controller);
    _slideAnim = Tween<Offset>(
      begin: widget.message.isMyCharacter
          ? const Offset(-0.3, 0)
          : const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.message.isMyCharacter;
    final bubbleColor = isMe
        ? widget.accentColor.withValues(alpha: 0.15)
        : Colors.purple.withValues(alpha: 0.1);
    final borderColor = isMe
        ? widget.accentColor.withValues(alpha: 0.4)
        : Colors.purple.withValues(alpha: 0.3);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (isMe) ...[
                CharacterAvatarWidget(
                  userId: widget.myUserId,
                  size: 32,
                  fallbackText: widget.myInitial,
                  fallbackBackgroundColor: widget.accentColor.withValues(alpha: 0.2),
                  fallbackTextColor: widget.accentColor,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 4 : 16),
                      topRight: Radius.circular(isMe ? 16 : 4),
                      bottomLeft: const Radius.circular(16),
                      bottomRight: const Radius.circular(16),
                    ),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    widget.message.text,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ),
              if (!isMe) ...[
                const SizedBox(width: 8),
                CharacterAvatarWidget(
                  userId: widget.friendUserId,
                  size: 32,
                  fallbackText: widget.friendInitial,
                  fallbackBackgroundColor: Colors.purple.withValues(alpha: 0.2),
                  fallbackTextColor: Colors.purple,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ジャンル別スコアカード
class _ScoreCard extends StatefulWidget {
  final String icon;
  final String label;
  final int score;
  final String comment;
  final Color color;

  const _ScoreCard({
    required this.icon,
    required this.label,
    required this.score,
    required this.comment,
    required this.color,
  });

  @override
  State<_ScoreCard> createState() => _ScoreCardState();
}

class _ScoreCardState extends State<_ScoreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _widthAnim = Tween<double>(begin: 0, end: widget.score / 100)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.score}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // スコアバー
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedBuilder(
              animation: _widthAnim,
              builder: (context, _) {
                return LinearProgressIndicator(
                  value: _widthAnim.value,
                  backgroundColor: widget.color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                  minHeight: 8,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.comment,
            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// 総合スコアカード
class _OverallScoreCard extends StatefulWidget {
  final int score;
  final String comment;
  final Color accentColor;

  const _OverallScoreCard({
    required this.score,
    required this.comment,
    required this.accentColor,
  });

  @override
  State<_OverallScoreCard> createState() => _OverallScoreCardState();
}

class _OverallScoreCardState extends State<_OverallScoreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              widget.accentColor.withValues(alpha: 0.2),
              widget.accentColor.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '総合相性',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.accentColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${widget.score}',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: widget.accentColor,
                  ),
                ),
                Text(
                  '%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: widget.accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.comment,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
