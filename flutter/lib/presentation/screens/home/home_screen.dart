import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/firebase_image_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/big5_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/ad_provider.dart';
import '../../providers/character_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';

/// iOS版HomeViewと同じデザインのホーム画面
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _chatController = TextEditingController();
  bool _isWaitingForReply = false;
  late String _displayedMessage;

  /// iOS版と同じ初期メッセージリスト
  static const List<String> _initialMessages = [
    '性格解析は全部で100問あるよ。好きなタイミングで「性格診断して」と話しかけてくれれば質問するから答えてね！',
    '「何日に〇〇の予定あるよ」と教えてくれれば予定追加しておくね！',
    'アプリでわからないことや欲しい機能があれば設定画面の問い合わせから開発者に連絡してね！',
    '性格解析が終わったらキャラクター詳細画面でどんな性格か確認してみてね',
    '画面の背景の色は自由に変えられるから設定画面から好みの色に変えてね！',
    'BGMの大きさは設定画面で変えられるよ',
    'あなたに興味があるからあなたの性格が写っちゃいそうだよ。もう1人の自分だと思って接してね！',
    '私の夢はあなたの夢にもなるのかな？',
  ];

  @override
  void initState() {
    super.initState();
    // ランダムな初期メッセージを選択
    _displayedMessage = _initialMessages[Random().nextInt(_initialMessages.length)];
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final userAsync = ref.watch(userDocProvider);
    final characterId = userAsync.valueOrNull?.characterId ?? '';
    final big5ProgressAsync = ref.watch(big5ProgressProvider(characterId));
    final characterDetailsAsync = ref.watch(characterDetailsProvider);
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);
    final size = MediaQuery.of(context).size;

    // デバッグ用: characterIdと進捗状況を確認
    debugPrint('HomeScreen - characterId: $characterId');
    debugPrint('HomeScreen - big5Progress: ${big5ProgressAsync.valueOrNull?.answeredCount ?? "loading/error"}');

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Stack(
            children: [
              // 吹き出し（上部）
              if (_displayedMessage.isNotEmpty)
                Positioned(
                  left: 20,
                  right: 20,
                  top: size.height * 0.08,
                  child: _SpeechBubble(
                    message: _displayedMessage,
                    maxWidth: size.width * 0.8,
                  ),
                ),

              // 下部UI（キャラクター画像 + 操作エリア）
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // キャラクター画像（性格解析バーのすぐ上）
                    SizedBox(
                      width: size.width * 1.0,
                      height: size.height * 0.55,
                      child: characterDetailsAsync.when(
                        data: (details) {
                          if (details?.personalityImageFileName != null) {
                            return _CharacterDisplay(
                              key: ValueKey(details!.personalityImageFileName),
                              width: size.width * 1.0,
                              height: size.height * 0.55,
                              characterGender: details.gender ?? userAsync.valueOrNull?.characterGender,
                              personalityImageFileName: details.personalityImageFileName,
                            );
                          }
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (_, __) => _CharacterDisplay(
                          width: size.width * 1.0,
                          height: size.height * 0.55,
                          characterGender: userAsync.valueOrNull?.characterGender,
                        ),
                      ),
                    ),

                    // BIG5進捗バー
                    big5ProgressAsync.when(
                      data: (progress) => _BIG5ProgressBar(
                        answeredCount: progress?.answeredCount ?? 0,
                        accentColor: accentColor,
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 8),

                    // 自分会議ボタンと履歴ボタン
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // 自分会議ボタン
                          big5ProgressAsync.when(
                            data: (progress) {
                              final isUnlocked = (progress?.answeredCount ?? 0) >= 20;
                              return _ActionButton(
                                icon: isUnlocked ? Icons.groups : Icons.lock,
                                label: '自分会議',
                                accentColor: accentColor,
                                isEnabled: isUnlocked,
                                showNewBadge: isUnlocked,
                                onTap: () {
                                  if (isUnlocked) {
                                    context.push('/meeting');
                                  } else {
                                    _showMeetingLockedDialog(context, progress?.answeredCount ?? 0);
                                  }
                                },
                              );
                            },
                            loading: () => _ActionButton(
                              icon: Icons.lock,
                              label: '自分会議',
                              accentColor: accentColor,
                              isEnabled: false,
                              onTap: () {},
                            ),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          const Spacer(),
                          // 履歴ボタン
                          _ActionButton(
                            icon: Icons.history,
                            label: '履歴',
                            accentColor: accentColor,
                            isOutlined: true,
                            onTap: () => context.push('/history', extra: characterId),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // チャット入力
                    _ChatInputArea(
                      controller: _chatController,
                      isWaitingForReply: _isWaitingForReply,
                      accentColor: accentColor,
                      onSend: _sendMessage,
                    ),

                    // バナー広告（無料ユーザーのみ）
                    if (shouldShowBannerAd) ...[
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: BannerAdContainer(),
                      ),
                    ],

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty || _isWaitingForReply) return;

    setState(() {
      _isWaitingForReply = true;
      _chatController.clear();
    });

    // 性格診断トリガー
    if (message.contains('性格診断') || message.contains('性格解析')) {
      context.push('/big5');
      setState(() => _isWaitingForReply = false);
      return;
    }

    try {
      final characterId = ref.read(userDocProvider).valueOrNull?.characterId ?? '';
      final reply = await ref.read(chatControllerProvider.notifier).sendMessage(
        characterId: characterId,
        message: message,
      );
      setState(() {
        _displayedMessage = reply ?? 'お返事がありませんでした';
        _isWaitingForReply = false;
      });
    } catch (e) {
      setState(() {
        _displayedMessage = 'エラーが発生しました。もう一度試してください。';
        _isWaitingForReply = false;
      });
    }
  }

  void _showMeetingLockedDialog(BuildContext context, int currentProgress) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock, color: ref.read(accentColorProvider)),
            const SizedBox(width: 8),
            const Text('機能がロックされています'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('「自分会議」機能を利用するには、性格診断を20問以上完了する必要があります。'),
            const SizedBox(height: 16),
            Text('現在の進捗: $currentProgress / 20問'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: currentProgress / 20,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(ref.read(accentColorProvider)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/big5');
            },
            child: const Text('診断を続ける'),
          ),
        ],
      ),
    );
  }
}

/// キャラクター表示
class _CharacterDisplay extends StatefulWidget {
  final double width;
  final double height;
  final String? characterGender;
  final String? personalityImageFileName;

  const _CharacterDisplay({
    super.key,
    required this.width,
    required this.height,
    this.characterGender,
    this.personalityImageFileName,
  });

  @override
  State<_CharacterDisplay> createState() => _CharacterDisplayState();
}

class _CharacterDisplayState extends State<_CharacterDisplay> {
  String? _imageUrl;
  bool _isLoading = true;
  bool _hasError = false;

  String get _fallbackImagePath {
    if (widget.characterGender == '男性') {
      return 'assets/images/android_male.png';
    } else {
      return 'assets/images/android_female.png';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadImageUrl();
  }

  @override
  void didUpdateWidget(covariant _CharacterDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.personalityImageFileName != widget.personalityImageFileName ||
        oldWidget.characterGender != widget.characterGender) {
      _loadImageUrl();
    }
  }

  Future<void> _loadImageUrl() async {
    // このウィジェットは personalityImageFileName がある場合のみ作成されるため
    // null チェックは念のため
    if (widget.personalityImageFileName == null || widget.characterGender == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final gender = widget.characterGender == '男性'
          ? CharacterGender.male
          : CharacterGender.female;

      debugPrint('Loading image URL: ${widget.personalityImageFileName} for gender: ${gender.value}');

      final url = await FirebaseImageService.shared.getImageUrl(
        fileName: widget.personalityImageFileName!,
        gender: gender,
      );

      debugPrint('Got image URL: $url');

      if (mounted) {
        setState(() {
          _imageUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to get image URL: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    // URLが取得できた場合はImage.networkで表示
    if (_imageUrl != null && !_hasError) {
      return Image.network(
        _imageUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          // 性格画像のロード中はローディングインジケーターを表示
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // CORSエラーなどでFirebase Storageから取得できない場合はフォールバック
          // Web版ではCORS設定が必要
          return _buildFallbackImage();
        },
      );
    }

    // ローディング中（性格画像のURLを取得中）
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // エラー時はフォールバック画像
    return _buildFallbackImage();
  }

  Widget _buildFallbackImage() {
    return Image.asset(
      _fallbackImagePath,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 100,
            color: AppColors.textLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'キャラクター',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textLight.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// 吹き出し
class _SpeechBubble extends StatelessWidget {
  final String message;
  final double maxWidth;

  const _SpeechBubble({required this.message, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// BIG5進捗バー（タップで性格解析ロードマップを表示）
class _BIG5ProgressBar extends StatelessWidget {
  final int answeredCount;
  final Color accentColor;

  const _BIG5ProgressBar({
    required this.answeredCount,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = answeredCount / 100;
    final level = answeredCount >= 100
        ? '完了'
        : answeredCount >= 50
            ? 'Lv.3'
            : answeredCount >= 20
                ? 'Lv.2'
                : 'Lv.1';

    return GestureDetector(
      onTap: () => _showPersonalityRoadmap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // レベル表示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                level,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 進捗バー
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '性格診断',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '$answeredCount / 100問',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation(accentColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            // タップヒント
            const SizedBox(width: 8),
            Icon(
              Icons.info_outline,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  /// 性格解析ロードマップを表示（iOS版PersonalityRoadmapViewと同じ）
  void _showPersonalityRoadmap(BuildContext context) {
    final stages = [
      _StageInfo(
        number: 1,
        title: '基本分析',
        description: '基本的な性格特性を分析します',
        questionRange: '1-20問',
        totalQuestions: 20,
        features: ['外向性の基本測定', '協調性の基本測定', '神経症傾向の基本測定'],
      ),
      _StageInfo(
        number: 2,
        title: '詳細分析',
        description: 'より詳細な性格パターンを解析します',
        questionRange: '21-50問',
        totalQuestions: 30,
        features: ['誠実性の詳細分析', '開放性の詳細分析', '複合的な性格傾向'],
      ),
      _StageInfo(
        number: 3,
        title: '総合分析',
        description: '多角的にあなたの個性を理解します',
        questionRange: '51-100問',
        totalQuestions: 50,
        features: ['全特性の統合分析', '詳細な性格レポート', '個性の深い理解'],
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
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // 閉じるボタン
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // ヘッダー
                Icon(
                  Icons.psychology,
                  size: 48,
                  color: accentColor,
                ),
                const SizedBox(height: 12),
                Text(
                  '性格解析ロードマップ',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '全100問の性格診断を3段階で進めて、\nあなたの個性を詳しく分析します',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // 現在の進捗
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        '現在の進捗',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$answeredCount',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                          ),
                          Text(
                            ' / 100 問完了',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: answeredCount / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(accentColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 段階別情報
                ...stages.map((stage) => _StageCard(
                      stage: stage,
                      answeredCount: answeredCount,
                      accentColor: accentColor,
                    )),

                const SizedBox(height: 16),

                // 診断の進め方
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
                          const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '診断の進め方',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'チャット画面でこのメッセージを送信すると質問が始まります：',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      _HowToItem(text: '「性格診断して」', accentColor: accentColor),
                      _HowToItem(text: '「性格解析して」', accentColor: accentColor),
                      const SizedBox(height: 8),
                      Text(
                        '好きなタイミングで質問を受けられます。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 閉じるボタン
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('閉じる'),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

/// ステージ情報
class _StageInfo {
  final int number;
  final String title;
  final String description;
  final String questionRange;
  final int totalQuestions;
  final List<String> features;

  const _StageInfo({
    required this.number,
    required this.title,
    required this.description,
    required this.questionRange,
    required this.totalQuestions,
    required this.features,
  });
}

/// ステージカード（iOS版StageCardViewと同じ）
class _StageCard extends StatelessWidget {
  final _StageInfo stage;
  final int answeredCount;
  final Color accentColor;

  const _StageCard({
    required this.stage,
    required this.answeredCount,
    required this.accentColor,
  });

  _StageStatus get _status {
    switch (stage.number) {
      case 1:
        if (answeredCount >= 20) return _StageStatus.completed;
        if (answeredCount > 0) return _StageStatus.inProgress;
        return _StageStatus.notStarted;
      case 2:
        if (answeredCount >= 50) return _StageStatus.completed;
        if (answeredCount > 20) return _StageStatus.inProgress;
        return _StageStatus.notStarted;
      case 3:
        if (answeredCount >= 100) return _StageStatus.completed;
        if (answeredCount > 50) return _StageStatus.inProgress;
        return _StageStatus.notStarted;
      default:
        return _StageStatus.notStarted;
    }
  }

  double get _progressInStage {
    switch (stage.number) {
      case 1:
        return (answeredCount / 20.0).clamp(0.0, 1.0);
      case 2:
        return answeredCount <= 20 ? 0 : ((answeredCount - 20) / 30.0).clamp(0.0, 1.0);
      case 3:
        return answeredCount <= 50 ? 0 : ((answeredCount - 50) / 50.0).clamp(0.0, 1.0);
      default:
        return 0;
    }
  }

  Color get _stageColor {
    switch (_status) {
      case _StageStatus.completed:
        return accentColor;
      case _StageStatus.inProgress:
        return accentColor.withValues(alpha: 0.7);
      case _StageStatus.notStarted:
        return Colors.grey.withValues(alpha: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _status == _StageStatus.notStarted
              ? Colors.grey.withValues(alpha: 0.2)
              : accentColor.withValues(alpha: _status == _StageStatus.completed ? 0.5 : 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              // ステージ番号
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _stageColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _status == _StageStatus.completed
                      ? const Icon(Icons.check, color: Colors.white, size: 24)
                      : Text(
                          '${stage.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          stage.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            stage.questionRange,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stage.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 進捗バー（開始済みの場合）
          if (_status != _StageStatus.notStarted) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '進捗',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                Text(
                  '${(_progressInStage * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _progressInStage,
                minHeight: 6,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(_stageColor),
              ),
            ),
          ],

          // 特徴リスト
          const SizedBox(height: 16),
          Text(
            '分析内容',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          ...stage.features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: _status == _StageStatus.completed
                          ? accentColor
                          : Colors.grey.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      feature,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
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

enum _StageStatus { notStarted, inProgress, completed }

/// 診断の進め方アイテム
class _HowToItem extends StatelessWidget {
  final String text;
  final Color accentColor;

  const _HowToItem({required this.text, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 14, color: accentColor),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

/// アクションボタン（自分会議・履歴）
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final bool isEnabled;
  final bool isOutlined;
  final bool showNewBadge;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.accentColor,
    this.isEnabled = true,
    this.isOutlined = false,
    this.showNewBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isOutlined
              ? Colors.white.withValues(alpha: 0.3)
              : accentColor.withValues(alpha: isEnabled ? 0.85 : 0.5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isOutlined ? accentColor : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isOutlined ? accentColor : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showNewBadge) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'New',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// チャット入力エリア
class _ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isWaitingForReply;
  final Color accentColor;
  final VoidCallback onSend;

  const _ChatInputArea({
    required this.controller,
    required this.isWaitingForReply,
    required this.accentColor,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // テキスト入力
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isWaitingForReply ? 0.1 : 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          enabled: !isWaitingForReply,
                          maxLines: 3,
                          minLines: 1,
                          maxLength: 100,
                          decoration: InputDecoration(
                            hintText: isWaitingForReply ? '返答を待っています...' : '性格診断して',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            counterText: '',
                          ),
                          onSubmitted: (_) => onSend(),
                        ),
                      ),
                      if (controller.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.grey.withValues(alpha: 0.6),
                            size: 20,
                          ),
                          onPressed: () => controller.clear(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 送信ボタン
              GestureDetector(
                onTap: isWaitingForReply ? null : onSend,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: !isWaitingForReply && controller.text.isNotEmpty
                        ? accentColor.withValues(alpha: 0.85)
                        : Colors.grey.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    boxShadow: !isWaitingForReply && controller.text.isNotEmpty
                        ? [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    isWaitingForReply ? Icons.hourglass_empty : Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 文字数カウント
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${controller.text.length}/100文字',
              style: TextStyle(
                fontSize: 11,
                color: controller.text.length >= 100
                    ? Colors.red
                    : AppColors.textLight.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
