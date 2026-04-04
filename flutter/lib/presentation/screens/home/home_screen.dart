import 'dart:math';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/firebase_image_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/big5_provider.dart';
import '../../../data/models/memo_model.dart';
import '../../../data/models/schedule_model.dart';
import '../../../data/models/todo_model.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/chat_provider.dart';
import '../../../data/datasources/remote/chat_datasource.dart';
import '../../providers/memo_provider.dart';
import '../../providers/todo_provider.dart';
import '../../../data/services/ad_service.dart';
import '../../providers/ad_provider.dart';
import '../../providers/character_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import '../../../data/services/voice_service.dart';
import '../../providers/subscription_provider.dart';

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
  // ダイアログ表示中フラグ（多重表示防止）
  bool _isShowingDialog = false;
  bool _isPlayingVoice = false;
  bool _isCharacterReply = false;


  /// 初期メッセージリスト
  static const List<String> _initialMessages = [
    // 機能案内
    '性格解析は全部で100問あるよ。好きなタイミングで「性格診断して」と話しかけてくれれば質問するから答えてね！',
    '性格解析が終わったらキャラクター詳細画面でどんな性格か確認してみてね',
    '「〇月〇日に〇〇の予定あるよ」と教えてくれれば予定追加しておくね！',
    '「〇〇をメモしておいて」って話しかけるとノートにメモを残しておくよ！',
    '「〇〇をタスクに追加して」って言ってくれればタスクとして登録しておくね！',
    'アプリの使い方がわからないことがあったら何でも話しかけてみて！できる限り答えるよ',
    '日記は毎日自動で書かれるよ。履歴ボタンから確認してみてね！',
    '自分会議では6人の私があなたの悩みを多角的に議論するよ。悩みがあったら試してみてね！',
    'アプリでわからないことや欲しい機能があれば設定画面の問い合わせから開発者に連絡してね！',
    '画面の背景の色は自由に変えられるから設定画面から好みの色に変えてね！',
    'BGMの大きさは設定画面で変えられるよ',
    // キャラクターの感情・雑談
    'あなたに興味があるからあなたの性格が写っちゃいそうだよ。もう1人の自分だと思って接してね！',
    '私の夢はあなたの夢にもなるのかな？',
    'あなたのこと、もっと知りたいな',
    '毎日ここに来てくれると嬉しいな',
    '悩みがあったらいつでも話しかけてね',
  ];

  @override
  void initState() {
    super.initState();
    // 時間帯挨拶 or ランダムメッセージを選択（1/3の確率で挨拶）
    final hour = DateTime.now().hour;
    final useGreeting = Random().nextInt(3) == 0;
    if (useGreeting) {
      if (hour >= 5 && hour < 12) {
        _displayedMessage = 'おはよう！今日も一緒に頑張ろうね';
      } else if (hour >= 12 && hour < 18) {
        _displayedMessage = 'お昼ごはんちゃんと食べた？';
      } else {
        _displayedMessage = '今日もお疲れさま！ゆっくり休んでね';
      }
    } else {
      _displayedMessage = _initialMessages[Random().nextInt(_initialMessages.length)];
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  /// 会議後フォローアップ: 固定メッセージを吹き出しに表示
  void _triggerMeetingFollowup(String conclusion) {
    if (mounted) {
      setState(() {
        _displayedMessage = '会議お疲れ様！続きがあれば話しかけてね';
        _isCharacterReply = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 会議後フォローアップの監視
    ref.listen<String?>(meetingFollowupConclusionProvider, (prev, next) {
      if (next != null) {
        ref.read(meetingFollowupConclusionProvider.notifier).state = null;
        _triggerMeetingFollowup(next);
      }
    });

    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final userAsync = ref.watch(userDocProvider);
    final characterId = userAsync.valueOrNull?.characterId ?? '';
    final big5ProgressAsync = ref.watch(big5ProgressProvider(characterId));
    final characterDetailsAsync = ref.watch(characterDetailsProvider);
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);
    final isPremium = ref.watch(effectiveIsPremiumProvider);
    final size = MediaQuery.of(context).size;

    // デバッグ用: characterIdと進捗状況を確認
    debugPrint('HomeScreen - characterId: $characterId');
    debugPrint('HomeScreen - big5Progress: ${big5ProgressAsync.valueOrNull?.answeredCount ?? "loading/error"}');

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availH = constraints.maxHeight;
              final availW = constraints.maxWidth;
              final charW = availW * 1.3;
              final charH = availH * 0.8;
              // iOS版に合わせてキャラクター中心をY=60%に配置
              final charTop = availH * 0.6 - charH / 2;

              return Stack(
            clipBehavior: Clip.none,
            children: [
              // キャラクター画像（背景レイヤー、iOSと同じ位置・サイズ）
              Positioned(
                left: -(charW - availW) / 2,
                top: charTop,
                child: characterDetailsAsync.when(
                  data: (details) {
                    if (details == null) {
                      return SizedBox(
                        width: charW,
                        height: charH,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    return _CharacterDisplay(
                      key: ValueKey(details.personalityImageFileName),
                      width: charW,
                      height: charH,
                      characterGender: details.gender,
                      personalityImageFileName: details.personalityImageFileName,
                    );
                  },
                  loading: () => SizedBox(width: charW, height: charH,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (_, __) => _CharacterDisplay(
                    width: charW,
                    height: charH,
                    characterGender: userAsync.valueOrNull?.characterGender,
                  ),
                ),
              ),

              // 下部UI（操作エリア）
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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

                    // BIG5進捗バー
                    big5ProgressAsync.when(
                      data: (progress) => _BIG5ProgressBar(
                        answeredCount: progress?.answeredCount ?? 0,
                        accentColor: accentColor,
                        backgroundGradient: backgroundGradient,
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: BannerAdContainer(adUnitId: AdConfig.homeScreenBannerAdUnitId),
                      ),
                    ],

                    const SizedBox(height: 12),
                  ],
                ),
              ),

              // 吹き出し（キャラクター画像の前面に表示）
              if (_displayedMessage.isNotEmpty)
                Positioned(
                  left: 20,
                  right: 20,
                  top: size.height * 0.08,
                  child: Column(
                    children: [
                      _SpeechBubble(
                        message: _displayedMessage,
                        maxWidth: size.width * 0.8,
                      ),
                      if (_isCharacterReply) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _isPlayingVoice ? null : () {
                            if (isPremium) {
                              _playVoice();
                            } else {
                              context.push('/premium');
                            }
                          },
                          child: _isPlayingVoice
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white70,
                                  ),
                                )
                              : const Icon(
                                  Icons.volume_up_outlined,
                                  size: 22,
                                  color: Colors.white70,
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
        ),
      ),
    );
  }

  Future<void> _playVoice() async {
    if (_isPlayingVoice || _displayedMessage.isEmpty) return;
    final gender = ref.read(characterDetailsProvider).valueOrNull?.gender ?? '女性';
    setState(() => _isPlayingVoice = true);
    await VoiceService.shared.generateAndPlay(
      text: _displayedMessage,
      gender: gender,
      onError: (_) {
        if (mounted) setState(() => _isPlayingVoice = false);
      },
    );
    if (mounted) setState(() => _isPlayingVoice = false);
  }

  void _showWebPremiumDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('プレミアム機能'),
        content: const Text('チャット機能はアプリ版またはプレミアムプランでご利用いただけます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/premium');
            },
            child: const Text('プレミアムへ'),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty || _isWaitingForReply) return;

    if (kIsWeb && !ref.read(effectiveIsPremiumProvider)) {
      _showWebPremiumDialog();
      return;
    }

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
      final result = await ref.read(chatControllerProvider.notifier).sendMessage(
        characterId: characterId,
        message: message,
      );
      if (mounted) {
        setState(() {
          _displayedMessage = result?.reply ?? 'お返事がありませんでした';
          _isWaitingForReply = false;
          _isCharacterReply = true;
        });
      }
      if (mounted && result != null && !_isShowingDialog) {
        if (result.scheduleDetected || result.memoDetected || result.todoDetected) {
          _showActionConfirmDialog(result);
        }
      }
      // チャット消費 & リワード広告チェック（5回ごと、非プレミアムのみ）
      await ref.read(adControllerProvider.notifier).consumeChat();
      if (mounted && ref.read(shouldShowVideoAdProvider) && !_isShowingDialog) {
        _showRewardedAdDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _displayedMessage = 'エラーが発生しました。もう一度試してください。';
          _isWaitingForReply = false;
        });
      }
    }
  }

  /// iOS版スタイルの確認ダイアログを表示
  void _showActionConfirmDialog(SendMessageResult result) {
    _isShowingDialog = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogContext) {
        final accentColor = ref.read(accentColorProvider);
        final backgroundGradient = ref.read(backgroundGradientProvider);
        if (result.scheduleDetected) {
          return _ScheduleListConfirmDialog(
            initialSchedules: result.detectedSchedules,
            accentColor: accentColor,
            backgroundGradient: backgroundGradient,
            onAdd: (schedules) async {
              Navigator.of(dialogContext).pop();
              await _saveScheduleModels(schedules);
            },
            onEdit: (schedule) async {
              // ダイアログはpopしない。保存時にpop(true)が返るのでカードを削除する
              return await context.push<bool>('/calendar/detail', extra: {
                'schedule': schedule,
                'initialDate': schedule.startDate,
              });
            },
            onCancel: () => Navigator.of(dialogContext).pop(),
          );
        }
        if (result.memoDetected && result.detectedMemo != null) {
          final m = result.detectedMemo!;
          return _ActionConfirmDialog(
            icon: Icons.notes,
            title: 'メモを保存しますか？',
            rows: [
              _DialogInfoRow(icon: Icons.text_snippet, label: 'メモ', content: m.title),
            ],
            accentColor: accentColor,
            showEditButton: true,
            onAdd: () async {
              Navigator.of(dialogContext).pop();
              await _saveMemoModel(m);
            },
            onEdit: () {
              Navigator.of(dialogContext).pop();
              context.push('/memo/detail', extra: m);
            },
            onCancel: () => Navigator.of(dialogContext).pop(),
          );
        }
        if (result.todoDetected && result.detectedTodo != null) {
          final t = result.detectedTodo!;
          return _ActionConfirmDialog(
            icon: Icons.check_circle_outline,
            title: 'タスクを追加しますか？',
            rows: [
              _DialogInfoRow(icon: Icons.text_snippet, label: 'タスク', content: t.title),
            ],
            accentColor: accentColor,
            showEditButton: true,
            onAdd: () async {
              Navigator.of(dialogContext).pop();
              await _saveTodoModel(t);
            },
            onEdit: () {
              Navigator.of(dialogContext).pop();
              context.push('/todo/detail', extra: t);
            },
            onCancel: () => Navigator.of(dialogContext).pop(),
          );
        }
        // フォールバック（通常は到達しない）
        return const SizedBox.shrink();
      },
    ).whenComplete(() => _isShowingDialog = false);
  }

  /// リワード広告ダイアログを表示（5チャットごと）
  void _showRewardedAdDialog() {
    _isShowingDialog = true;
    final accentColor = ref.read(accentColorProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('📺 動画を見て続けよう', textAlign: TextAlign.center),
        content: const Text(
          '動画広告を視聴すると、チャットが続けられます。\nスキップして後で視聴することもできます。',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('スキップ'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final success = await ref.read(adControllerProvider.notifier).showRewardedAd();
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🎁 ありがとう！チャットを続けられます')),
                );
              }
            },
            icon: const Icon(Icons.play_circle, color: Colors.white),
            label: const Text('動画を見る', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
          ),
        ],
      ),
    ).whenComplete(() => _isShowingDialog = false);
  }

  Future<void> _saveScheduleModels(List<ScheduleModel> schedules) async {
    int successCount = 0;
    for (final schedule in schedules) {
      try {
        await ref.read(calendarControllerProvider.notifier).addSchedule(schedule);
        successCount++;
      } catch (e) {
        debugPrint('⚠️ 予定の追加に失敗: $e');
      }
    }
    if (mounted) {
      final message = successCount == schedules.length
          ? '$successCount件の予定を追加しました'
          : '$successCount/${schedules.length}件の予定を追加しました';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _saveMemoModel(MemoModel memo) async {
    try {
      await ref.read(memoControllerProvider.notifier).addMemo(memo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メモに保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メモの保存に失敗しました')),
        );
      }
    }
  }

  Future<void> _saveTodoModel(TodoModel todo) async {
    try {
      await ref.read(todoControllerProvider.notifier).addTodo(todo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('タスクに追加しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('タスクの追加に失敗しました')),
        );
      }
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
    if (widget.characterGender == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    // 未診断（personalityImageFileName == null）の場合はローカルのデフォルト画像を表示（iOS版と同じ挙動）
    if (widget.personalityImageFileName == null) {
      setState(() {
        _isLoading = false;
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
    // URLが取得できた場合はCachedNetworkImageで表示（2回目以降はキャッシュから即時表示）
    if (_imageUrl != null && !_hasError) {
      return CachedNetworkImage(
        imageUrl: _imageUrl!,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => _buildFallbackImage(),
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

/// 予定リスト確認ダイアログ（1件・複数件共通）
class _ScheduleListConfirmDialog extends StatefulWidget {
  final List<ScheduleModel> initialSchedules;
  final Color accentColor;
  final LinearGradient backgroundGradient;
  final void Function(List<ScheduleModel>) onAdd;
  final Future<bool?> Function(ScheduleModel) onEdit;
  final VoidCallback onCancel;

  const _ScheduleListConfirmDialog({
    required this.initialSchedules,
    required this.accentColor,
    required this.backgroundGradient,
    required this.onAdd,
    required this.onEdit,
    required this.onCancel,
  });

  @override
  State<_ScheduleListConfirmDialog> createState() =>
      _ScheduleListConfirmDialogState();
}

class _ScheduleListConfirmDialogState
    extends State<_ScheduleListConfirmDialog> {
  late List<ScheduleModel> _schedules;

  @override
  void initState() {
    super.initState();
    _schedules = List.from(widget.initialSchedules);
  }

  String _formatDate(ScheduleModel s) {
    if (s.isAllDay) {
      return '${s.startDate.year}年${s.startDate.month}月${s.startDate.day}日（終日）';
    }
    return '${s.startDate.year}年${s.startDate.month}月${s.startDate.day}日 '
        '${s.startDate.hour.toString().padLeft(2, '0')}:'
        '${s.startDate.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
    Color? textColor,
    bool isFullWidth = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: textColor ?? Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(ScheduleModel s, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 13, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(s),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
                if (s.location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 13, color: Colors.blue),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          s.location,
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSmallButton(
                label: '編集',
                color: Colors.orange,
                onPressed: () async {
                  final saved = await widget.onEdit(s);
                  if (saved == true && mounted) {
                    setState(() => _schedules.removeAt(index));
                  }
                },
              ),
              const SizedBox(height: 8),
              _buildSmallButton(
                label: '除外',
                color: Colors.red,
                onPressed: () => setState(() => _schedules.removeAt(index)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _schedules.length;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: widget.backgroundGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 32, color: widget.accentColor),
            const SizedBox(height: 8),
            Text(
              count == 0 ? '全て除外されました' : '$count件の予定を追加しますか？',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (count > 0) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (int i = 0; i < _schedules.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _buildScheduleCard(_schedules[i], i),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildButton(
                label: '$count件追加する',
                color: Colors.blue,
                onPressed: () => widget.onAdd(_schedules),
                isFullWidth: true,
              ),
            ],
            const SizedBox(height: 12),
            _buildButton(
              label: count == 0 ? '閉じる' : 'キャンセル',
              color: const Color(0xFFDDDDDD),
              textColor: Colors.black87,
              onPressed: widget.onCancel,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS版ScheduleConfirmationPopupと同じスタイルのアクション確認ダイアログ
class _DialogInfoRow {
  final IconData icon;
  final String label;
  final String content;
  const _DialogInfoRow({required this.icon, required this.label, required this.content});
}

class _ActionConfirmDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_DialogInfoRow> rows;
  final Color accentColor;
  final bool showEditButton;
  final VoidCallback onAdd;
  final VoidCallback? onEdit;
  final VoidCallback onCancel;

  const _ActionConfirmDialog({
    required this.icon,
    required this.title,
    required this.rows,
    required this.accentColor,
    required this.showEditButton,
    required this.onAdd,
    this.onEdit,
    required this.onCancel,
  });

  Widget _buildButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
    Color? textColor,
    bool isFullWidth = false,
  }) {
    final btn = GestureDetector(
      onTap: onPressed,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: textColor ?? Colors.white,
          ),
        ),
      ),
    );
    return btn;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Icon(icon, size: 32, color: accentColor),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // 情報セクション（iOS版ScheduleInfoRowと同じ縦積みレイアウト）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // アイコン（左固定）
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(rows[i].icon, size: 14, color: Colors.blue),
                        ),
                        const SizedBox(width: 12),
                        // ラベル（上）+ 内容（下）縦積み
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rows[i].label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rows[i].content,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
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
            const SizedBox(height: 20),

            // アクションボタン行（編集＋追加する）
            Row(
              children: [
                if (showEditButton) ...[
                  Expanded(
                    child: _buildButton(
                      label: '編集',
                      color: Colors.orange,
                      onPressed: onEdit ?? () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _buildButton(
                    label: '追加する',
                    color: Colors.blue,
                    onPressed: onAdd,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // キャンセルボタン（全幅・グレー）
            _buildButton(
              label: 'キャンセル',
              color: const Color(0xFFDDDDDD),
              textColor: Colors.black87,
              onPressed: onCancel,
              isFullWidth: true,
            ),
          ],
        ),
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
        child: SelectableText(
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
  final Gradient? backgroundGradient;

  const _BIG5ProgressBar({
    required this.answeredCount,
    required this.accentColor,
    this.backgroundGradient,
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
        ),
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

  /// 性格解析ロードマップを表示
  void _showPersonalityRoadmap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PersonalityRoadmapPage(
          answeredCount: answeredCount,
          accentColor: accentColor,
          backgroundGradient: backgroundGradient,
        ),
      ),
    );
  }
}

/// 性格解析ロードマップ ページ
class _PersonalityRoadmapPage extends StatefulWidget {
  final int answeredCount;
  final Color accentColor;
  final Gradient? backgroundGradient;

  const _PersonalityRoadmapPage({
    required this.answeredCount,
    required this.accentColor,
    this.backgroundGradient,
  });

  @override
  State<_PersonalityRoadmapPage> createState() => _PersonalityRoadmapPageState();
}

class _PersonalityRoadmapPageState extends State<_PersonalityRoadmapPage> {
  final _scrollController = ScrollController();
  double _dragAccum = 0;
  bool _dismissing = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final answeredCount = widget.answeredCount;
    final accentColor = widget.accentColor;
    final backgroundGradient = widget.backgroundGradient;
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Listener(
            onPointerMove: (event) {
              if (_scrollController.hasClients &&
                  _scrollController.offset <= 0 &&
                  event.delta.dy > 0) {
                _dragAccum += event.delta.dy;
                if (_dragAccum > 80 && !_dismissing) {
                  _dismissing = true;
                  Navigator.pop(context);
                }
              } else {
                _dragAccum = 0;
              }
            },
            onPointerUp: (_) => _dragAccum = 0,
            onPointerCancel: (_) => _dragAccum = 0,
            child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // タイトル行（スクロールと一体）
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48),
                    Text(
                      '性格解析ロードマップ',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
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
class _ChatInputArea extends StatefulWidget {
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
  State<_ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<_ChatInputArea> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            // Shift+Enter: 送信
            if (!widget.isWaitingForReply && widget.controller.text.trim().isNotEmpty) {
              widget.onSend();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  FocusScope.of(context).requestFocus(_focusNode);
                  widget.controller.clear();
                }
              });
            }
            return KeyEventResult.handled;
          } else {
            // Enter: 改行（デフォルト動作）
            return KeyEventResult.ignored;
          }
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, textValue, _) {
        final hasText = textValue.text.isNotEmpty;
        final length = textValue.text.length;
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
                        color: Colors.white.withValues(alpha: widget.isWaitingForReply ? 0.5 : 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widget.controller,
                              focusNode: _focusNode,
                              enabled: !widget.isWaitingForReply,
                              maxLines: 3,
                              minLines: 1,
                              maxLength: 100,
                              decoration: InputDecoration(
                                hintText: widget.isWaitingForReply ? '返答を待っています...' : '性格診断して',
                                hintStyle: const TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                counterText: '',
                              ),
                            ),
                          ),
                          if (hasText)
                            GestureDetector(
                              onTap: () => widget.controller.clear(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  Icons.cancel,
                                  color: Colors.grey.withValues(alpha: 0.6),
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 送信ボタン
                  GestureDetector(
                    onTap: widget.isWaitingForReply ? null : () {
                      widget.onSend();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          FocusScope.of(context).requestFocus(_focusNode);
                          widget.controller.clear();
                        }
                      });
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: !widget.isWaitingForReply && hasText
                            ? widget.accentColor.withValues(alpha: 0.85)
                            : Colors.grey.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        boxShadow: !widget.isWaitingForReply && hasText
                            ? [
                                BoxShadow(
                                  color: widget.accentColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        widget.isWaitingForReply ? Icons.hourglass_empty : Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Shift+Enter/Enter ヒント
                  Text(
                    'Shift+Enterで送信 / Enterで改行',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textLight.withValues(alpha: 0.5),
                    ),
                  ),
                  // 文字数カウント
                  Text(
                    '$length/100文字',
                    style: TextStyle(
                      fontSize: 11,
                      color: length >= 100
                          ? Colors.red
                          : AppColors.textLight.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
