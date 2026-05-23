import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/friend_model.dart';
import '../../../data/services/ask_friend_limit_manager.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/ad_provider.dart';
import '../../widgets/character_avatar_widget.dart';
import 'compatibility_category_screen.dart' show CompatibilityChatBubble;
import 'friend_ask_history_screen.dart';

/// フレンドについてキャラクター会話形式で質問する画面
class FriendAskScreen extends ConsumerStatefulWidget {
  final FriendModel friend;

  const FriendAskScreen({super.key, required this.friend});

  @override
  ConsumerState<FriendAskScreen> createState() => _FriendAskScreenState();
}

class _FriendAskScreenState extends ConsumerState<FriendAskScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  FriendAskResult? _result;
  String? _errorMessage;
  final List<CompatibilityMessage> _displayedMessages = [];
  bool _showRecommendation = false;
  Timer? _messageTimer;

  final _limitManager = AskFriendLimitManager();

  static const _examples = [
    '誕生日プレゼントに何が合いそう？',
    '一緒に旅行するならどこがいい？',
    '好きな食べ物・料理は？',
    '休日の過ごし方は？',
    'どんな映画・本が好き？',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  Future<void> _onAsk() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    FocusScope.of(context).unfocus();

    // プレミアム判定と無料利用制限チェック
    final isPremium = ref.read(effectiveIsPremiumProvider);

    // Web版の無料ユーザーは利用不可（広告非対応）
    if (kIsWeb && !isPremium) {
      _showWebFreeDialog();
      return;
    }

    // アプリ版（iOS/Android）の無料ユーザーは1日1回制限
    if (!isPremium && !kIsWeb) {
      final canFree = await _limitManager.canUseFree();
      if (!canFree) {
        final watched = await _showAdDialog();
        if (!watched) return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
      _displayedMessages.clear();
      _showRecommendation = false;
    });
    _messageTimer?.cancel();

    final friendName =
        widget.friend.name.isNotEmpty ? widget.friend.name : 'フレンド';

    final result = await ref
        .read(friendControllerProvider.notifier)
        .askAboutFriend(
          friendId: widget.friend.id,
          friendName: friendName,
          question: question,
        );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '取得に失敗しました。もう一度お試しください。';
      });
      return;
    }

    // 成功したら回数消費
    if (!isPremium && !kIsWeb) {
      await _limitManager.increment();
    }

    setState(() {
      _isLoading = false;
      _result = result;
    });

    _startMessageAnimation(result.conversation);
  }

  /// Web版無料ユーザー向けブロックダイアログ
  void _showWebFreeDialog() {
    if (!mounted) return;
    final accentColor = ref.read(accentColorProvider);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('📱 アプリ版限定機能', textAlign: TextAlign.center),
        content: const Text(
          'この機能はアプリ版の無料プランではご利用いただけません。\n\n'
          'iOSアプリをダウンロードして使うか、プレミアムプランに\n'
          'アップグレードしてご利用ください。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // プレミアム画面へ遷移
              context.push('/premium');
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
            child: const Text(
              'プレミアムへ',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// リワード広告ダイアログを表示し、視聴成功なら true を返す
  Future<bool> _showAdDialog() async {
    if (!mounted) return false;
    final accentColor = ref.read(accentColorProvider);

    final watched = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('📺 動画を見てもう1回聞こう', textAlign: TextAlign.center),
        content: const Text(
          '無料でご利用いただける回数を使い切りました。\n動画広告を視聴するともう1回聞けます。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop(true);
            },
            icon: const Icon(Icons.play_circle, color: Colors.white),
            label: const Text('動画を見る', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
          ),
        ],
      ),
    );

    if (watched != true) return false;

    // 実際に広告を再生
    final success =
        await ref.read(adControllerProvider.notifier).showRewardedAd();
    return success;
  }

  void _startMessageAnimation(List<CompatibilityMessage> messages) {
    if (messages.isEmpty) {
      setState(() => _showRecommendation = true);
      return;
    }
    int index = 0;
    _messageTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (index >= messages.length) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _showRecommendation = true);
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _scrollToBottom());
          }
        });
        return;
      }
      setState(() => _displayedMessages.add(messages[index++]));
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
    final accentColor = ref.watch(accentColorProvider);
    final myUserId = ref.watch(currentUserIdProvider) ?? '';
    final myName = ref.watch(userDocProvider).valueOrNull?.name ?? '自分';
    final friendName =
        widget.friend.name.isNotEmpty ? widget.friend.name : 'フレンド';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios, color: accentColor),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CharacterAvatarWidget(
              userId: widget.friend.id,
              size: 28,
              fallbackText: friendName.isNotEmpty ? friendName[0] : '?',
              fallbackBackgroundColor: Colors.indigo.withValues(alpha: 0.2),
              fallbackTextColor: Colors.indigo,
            ),
            const SizedBox(width: 8),
            Text(
              '$friendNameのことを聞く',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FriendAskHistoryScreen(friend: widget.friend),
                ),
              );
            },
            icon: Icon(Icons.history, color: accentColor),
            tooltip: '過去の質問',
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── 入力エリア ──
              _buildInputSection(accentColor, friendName),

              // ── 結果エリア ──
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    if (_isLoading) ...[
                      const SizedBox(height: 40),
                      Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: accentColor),
                            const SizedBox(height: 12),
                            Text(
                              'キャラクターに聞いています…',
                              style: TextStyle(
                                  fontSize: 13, color: accentColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.redAccent),
                        ),
                      ),
                    ],
                    if (_displayedMessages.isNotEmpty) ...[
                      _buildConversationSection(
                          accentColor, myUserId, myName, friendName),
                      const SizedBox(height: 16),
                    ],
                    if (_showRecommendation && _result != null) ...[
                      _buildRecommendationCard(accentColor),
                      const SizedBox(height: 12),
                      _buildDisclaimer(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // 入力セクション
  // ─────────────────────────────────────────
  Widget _buildInputSection(Color accentColor, String friendName) {
    return Container(
      color: Colors.white.withValues(alpha: 0.85),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$friendNameのことを何でも聞いてみよう',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
          // 例チップ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _examples
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            _controller.text = e;
                            _controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: e.length),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: accentColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              e,
                              style: TextStyle(
                                  fontSize: 11, color: accentColor),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: 100,
                  decoration: InputDecoration(
                    hintText: '例：誕生日プレゼントに何が合いそう？',
                    hintStyle:
                        TextStyle(fontSize: 13, color: Colors.grey[400]),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: accentColor.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: accentColor.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accentColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: (_) => _isLoading ? null : _onAsk(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isLoading ? null : _onAsk,
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('聞く', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // 会話セクション
  // ─────────────────────────────────────────
  Widget _buildConversationSection(
      Color accentColor, String myUserId, String myName, String friendName) {
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
              Icon(Icons.chat_bubble_outline, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Text(
                'キャラクターの会話',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._displayedMessages.map((msg) => CompatibilityChatBubble(
                message: msg,
                myUserId: myUserId,
                friendUserId: widget.friend.id,
                myName: myName,
                friendName: friendName,
                accentColor: accentColor,
              )),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // おすすめカード
  // ─────────────────────────────────────────
  Widget _buildRecommendationCard(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _result!.recommendation,
              style: TextStyle(
                fontSize: 14,
                color: accentColor.withValues(alpha: 0.9),
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // 免責表示
  // ─────────────────────────────────────────
  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 13, color: Colors.grey[500]),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'あくまでキャラクターの性格データをもとにした参考情報です。実際の好みとは異なる場合があります。',
              style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
