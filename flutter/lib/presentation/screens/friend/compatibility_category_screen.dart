import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/friend_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/character_avatar_widget.dart';
import 'compatibility_screen.dart' show CompatibilityCategoryMeta;

/// カテゴリ別相性診断 詳細画面
class CompatibilityCategoryScreen extends ConsumerStatefulWidget {
  final FriendModel friend;
  final CompatibilityCategoryMeta category;
  final CategoryDiagnosis diagnosis;
  /// true: 初回診断直後 → 会話アニメーションあり
  /// false: 再訪問 → 静的表示
  final bool animateOnEntry;

  const CompatibilityCategoryScreen({
    super.key,
    required this.friend,
    required this.category,
    required this.diagnosis,
    required this.animateOnEntry,
  });

  @override
  ConsumerState<CompatibilityCategoryScreen> createState() =>
      _CompatibilityCategoryScreenState();
}

class _CompatibilityCategoryScreenState
    extends ConsumerState<CompatibilityCategoryScreen> {
  final List<CompatibilityMessage> _displayedMessages = [];
  bool _showResult = false;
  Timer? _messageTimer;
  int _messageIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.animateOnEntry) {
      // 少し遅らせてから会話アニメーション開始
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _startMessageAnimation();
      });
    } else {
      // 静的表示
      setState(() {
        _displayedMessages.addAll(widget.diagnosis.conversation);
        _showResult = true;
      });
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startMessageAnimation() {
    final messages = widget.diagnosis.conversation;
    if (messages.isEmpty) {
      setState(() => _showResult = true);
      return;
    }

    _messageTimer =
        Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (_messageIndex >= messages.length) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() => _showResult = true);
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _scrollToBottom());
          }
        });
        return;
      }
      setState(() {
        _displayedMessages.add(messages[_messageIndex]);
        _messageIndex++;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });
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

  @override
  Widget build(BuildContext context) {
    final gradient = ref.watch(backgroundGradientProvider);
    final userAsync = ref.watch(userDocProvider);
    final myUserId = ref.watch(currentUserIdProvider) ?? '';
    final myName = userAsync.valueOrNull?.name ?? '自分';
    final cat = widget.category;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios, color: cat.color),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cat.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              '${cat.label}の相性',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cat.color,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: ListView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // チャット会話（最初に表示）
              if (_displayedMessages.isNotEmpty) ...[
                _buildChatSection(cat.color, myUserId, myName),
                const SizedBox(height: 20),
              ] else if (widget.animateOnEntry) ...[
                // アニメーション開始前
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: cat.color),
                  ),
                ),
              ],

              // チャット後にスコア + コメント + アドバイスを表示
              if (_showResult) ...[
                _buildScoreBadge(cat),
                const SizedBox(height: 16),
                _buildResultDetail(cat),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // スコアバッジ
  // ─────────────────────────────────────────
  Widget _buildScoreBadge(CompatibilityCategoryMeta cat) {
    final score = widget.diagnosis.score;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cat.color.withValues(alpha: 0.15),
            cat.color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cat.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: cat.color,
                ),
              ),
              Text(
                '%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: cat.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _AnimatedScoreBar(score: score, color: cat.color),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // チャット会話セクション
  // ─────────────────────────────────────────
  Widget _buildChatSection(Color catColor, String myUserId, String myName) {
    final accentColor = ref.watch(accentColorProvider);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 16, color: catColor),
              const SizedBox(width: 6),
              Text(
                'キャラクターの会話',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: catColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._displayedMessages.map((msg) => _ChatBubble(
                message: msg,
                myUserId: myUserId,
                friendUserId: widget.friend.id,
                myName: myName,
                friendName: widget.friend.name,
                accentColor: accentColor,
              )),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // 診断結果詳細（コメント + アドバイス）
  // ─────────────────────────────────────────
  Widget _buildResultDetail(CompatibilityCategoryMeta cat) {
    final d = widget.diagnosis;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // コメント
          Text(
            d.comment,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),

          // アドバイス
          if (d.advice.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 15, color: cat.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.advice,
                      style: TextStyle(
                        fontSize: 13,
                        color: cat.color.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// スコアバー（アニメーション付き）
// ─────────────────────────────────────────
class _AnimatedScoreBar extends StatefulWidget {
  final int score;
  final Color color;
  const _AnimatedScoreBar({required this.score, required this.color});

  @override
  State<_AnimatedScoreBar> createState() => _AnimatedScoreBarState();
}

class _AnimatedScoreBarState extends State<_AnimatedScoreBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _bar;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _bar = Tween<double>(begin: 0, end: widget.score / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bar,
      builder: (context, child) => LinearProgressIndicator(
        value: _bar.value,
        backgroundColor: widget.color.withValues(alpha: 0.12),
        valueColor: AlwaysStoppedAnimation<Color>(widget.color),
        minHeight: 8,
      ),
    );
  }
}

// ─────────────────────────────────────────
// チャット吹き出し
// ─────────────────────────────────────────
class _ChatBubble extends StatefulWidget {
  final CompatibilityMessage message;
  final String myUserId;
  final String friendUserId;
  final String myName;
  final String friendName;
  final Color accentColor;

  const _ChatBubble({
    required this.message,
    required this.myUserId,
    required this.friendUserId,
    required this.myName,
    required this.friendName,
    required this.accentColor,
  });

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _slide = Tween<Offset>(
      begin: widget.message.isMyCharacter
          ? const Offset(-0.15, 0)
          : const Offset(0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.message.isMyCharacter;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (isMe) ...[
                Column(
                  children: [
                    CharacterAvatarWidget(
                      userId: widget.myUserId,
                      size: 32,
                      fallbackText: '',
                      fallbackBackgroundColor:
                          widget.accentColor.withValues(alpha: 0.2),
                      fallbackTextColor: widget.accentColor,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.myName,
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: isMe
                        ? widget.accentColor.withValues(alpha: 0.15)
                        : Colors.indigo.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 4 : 14),
                      topRight: Radius.circular(isMe ? 14 : 4),
                      bottomLeft: const Radius.circular(14),
                      bottomRight: const Radius.circular(14),
                    ),
                    border: Border.all(
                      color: isMe
                          ? widget.accentColor.withValues(alpha: 0.3)
                          : Colors.indigo.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    widget.message.text,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ),
              if (!isMe) ...[
                const SizedBox(width: 8),
                Column(
                  children: [
                    CharacterAvatarWidget(
                      userId: widget.friendUserId,
                      size: 32,
                      fallbackText: '',
                      fallbackBackgroundColor:
                          Colors.indigo.withValues(alpha: 0.2),
                      fallbackTextColor: Colors.indigo,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.friendName,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.indigo,
                        fontWeight: FontWeight.bold,
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
}
