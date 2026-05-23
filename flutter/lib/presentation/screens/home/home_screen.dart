import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
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
import '../../widgets/character/element_effect_widget.dart';
import '../../widgets/inline_hint_banner.dart';
import 'chat_opener.dart';

/// iOS版HomeViewと同じデザインのホーム画面
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _chatController = TextEditingController();
  bool _isWaitingForReply = false;
  late String _displayedMessage;
  // ダイアログ表示中フラグ（多重表示防止）
  bool _isShowingDialog = false;
  bool _isShowingEvolutionDialog = false;
  bool _isPlayingVoice = false;
  bool _isCharacterReply = false;
  bool _showMeetingBanner = false;
  bool _openerLoaded = false;
  // オープナーをロードした日付（日付をまたいだ再ロード判定用）
  String _openerLoadedDate = '';


  /// 初期メッセージリスト
  static const List<String> _initialMessages = [
    // 機能案内
    'チャットを続けると性格タイプが解析されてキャラクターが変わるよ！',
    'キャラクター詳細画面でどんな性格か確認してみてね',
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
    WidgetsBinding.instance.addObserver(this);
    // 暫定メッセージ（オープナーがロードされるまで表示）
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
    // スマートオープナーをポストフレームで非同期ロード
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadChatOpener());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    // 日付が変わっていたらオープナーを再ロード
    if (_openerLoadedDate != today) {
      _openerLoaded = false;
      _loadChatOpener();
    }
  }

  Future<void> _loadChatOpener() async {
    if (!mounted || _openerLoaded) return;
    _openerLoaded = true;
    final now = DateTime.now();
    _openerLoadedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final schedules = ref.read(allSchedulesProvider).valueOrNull ?? [];
    final todos = ref.read(todosProvider).valueOrNull ?? [];
    final userId = ref.read(currentUserIdProvider) ?? '';
    final opener = await computeChatOpener(allSchedules: schedules, allTodos: todos, userId: userId);
    if (mounted) {
      setState(() {
        _displayedMessage = opener.text;
        _isCharacterReply = true;
      });
      await _saveOpenerIfNeeded(opener.text);
    }
  }

  Future<void> _saveOpenerIfNeeded(String openerText) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final savedDate = prefs.getString('chat_opener_saved_date') ?? '';
      if (savedDate == today) return;

      // userDocProvider がまだロード中の場合、最大3秒待つ
      String characterId = ref.read(userDocProvider).valueOrNull?.characterId ?? '';
      if (characterId.isEmpty) {
        for (int i = 0; i < 6 && mounted; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          characterId = ref.read(userDocProvider).valueOrNull?.characterId ?? '';
          if (characterId.isNotEmpty) break;
        }
      }
      if (characterId.isEmpty) return;

      await ref.read(chatControllerProvider.notifier).saveOpener(
        characterId: characterId,
        openerText: openerText,
      );
      await prefs.setString('chat_opener_saved_date', today);
    } catch (e) {
      debugPrint('⚠️ _saveOpenerIfNeeded error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatController.dispose();
    super.dispose();
  }

/// 会議後フォローアップ: 結論をAIに送信してレスポンスを表示
  void _triggerMeetingFollowup(String conclusion) async {
    if (!mounted) return;
    setState(() {
      _displayedMessage = '会議お疲れ様！結論を受け取ったよ…';
      _isCharacterReply = false;
      _isWaitingForReply = true;
    });

    try {
      final characterId = ref.read(userDocProvider).valueOrNull?.characterId ?? '';
      debugPrint('🔄 _triggerMeetingFollowup: characterId=$characterId, conclusion=${conclusion.length}chars');
      final result = await ref.read(chatControllerProvider.notifier).sendMessage(
        characterId: characterId,
        message: '【自分会議の結論】$conclusion',
      );
      debugPrint('✅ _triggerMeetingFollowup: reply=${result?.reply.substring(0, 20)}');
      if (mounted) {
        setState(() {
          _displayedMessage = result?.reply ?? '会議お疲れ様！続きがあれば話しかけてね';
          _isWaitingForReply = false;
          _isCharacterReply = true;
        });
        if (result != null) saveLastQuestion(result.reply, ref.read(currentUserIdProvider) ?? '');
      }
    } catch (e, st) {
      debugPrint('❌ _triggerMeetingFollowup error: $e\n$st');
      if (mounted) {
        setState(() {
          _displayedMessage = '会議お疲れ様！続きがあれば話しかけてね';
          _isWaitingForReply = false;
        });
      }
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

    // 性格タイプ変化の監視
    ref.listen<AsyncValue<TypeChangeData?>>(pendingTypeChangeProvider, (prev, next) {
      final data = next.valueOrNull;
      if (data != null && !_isShowingEvolutionDialog) {
        _isShowingEvolutionDialog = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showEvolutionDialog(data));
      }
    });

    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final userAsync = ref.watch(userDocProvider);
    final characterId = userAsync.valueOrNull?.characterId ?? '';
    final characterDetailsAsync = ref.watch(characterDetailsProvider);
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);
    final isPremium = ref.watch(effectiveIsPremiumProvider);
    final signalCount = ref.watch(signalCountProvider).valueOrNull ?? 0;
    final size = MediaQuery.of(context).size;

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
                      key: ValueKey('$signalCount-${details.element}-${details.gender}'),
                      width: charW,
                      height: charH,
                      signalCount: signalCount,
                      element: details.element,
                      gender: details.gender,
                    );
                  },
                  loading: () => SizedBox(width: charW, height: charH,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (err, stack) => _CharacterDisplay(
                    width: charW,
                    height: charH,
                    signalCount: 0,
                    gender: userAsync.valueOrNull?.characterGender,
                  ),
                ),
              ),

              // ホームヒントバナー（初回のみ・上部）
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: HomeHintBanner(userId: ref.watch(currentUserIdProvider) ?? ''),
              ),

              // 下部UI（操作エリア）
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 自分会議提案バナー
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: _showMeetingBanner
                          ? _MeetingSuggestionBanner(
                              accentColor: accentColor,
                              onOpen: () {
                                setState(() => _showMeetingBanner = false);
                                context.push('/meeting');
                              },
                              onDismiss: () => setState(() => _showMeetingBanner = false),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // 自分会議ボタンと履歴ボタン
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // 自分会議ボタン（signalCount >= 30 で解放）
                          _ActionButton(
                            icon: signalCount >= 30 ? Icons.groups : Icons.lock,
                            label: '自分会議',
                            accentColor: accentColor,
                            isEnabled: signalCount >= 30,
                            showNewBadge: signalCount >= 30,
                            onTap: () {
                              if (signalCount >= 30) {
                                context.push('/meeting');
                              } else {
                                _showMeetingLockedDialog(context, signalCount);
                              }
                            },
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

                    const SizedBox(height: 6),

                    // 成長ゲージ
                    _GrowthGauge(signalCount: signalCount, accentColor: accentColor),

                    const SizedBox(height: 6),

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

    if (message.contains('性格診断') || message.contains('性格解析')) {
      setState(() {
        _displayedMessage = '性格解析はチャットを通じて自動的に行われるよ！普通に話しかけてくれれば少しずつ性格タイプが分析されていくから、いつも通り話しかけてね！';
        _isCharacterReply = true;
        _chatController.clear();
      });
      return;
    }

    ref.read(sessionChatCountProvider.notifier).state += 1;
    final signalCount = ref.read(signalCountProvider).valueOrNull ?? 0;
    final phase = _calcPhase(signalCount, ref.read(sessionChatCountProvider));

    setState(() {
      _isWaitingForReply = true;
      _showMeetingBanner = false;
      _chatController.clear();
    });

    try {
      final characterId = ref.read(userDocProvider).valueOrNull?.characterId ?? '';
      final result = await ref.read(chatControllerProvider.notifier).sendMessage(
        characterId: characterId,
        message: message,
        phase: phase,
      );
      if (mounted) {
        setState(() {
          final reply = result?.reply ?? '';
          _displayedMessage = reply.isNotEmpty ? reply : 'お返事がありませんでした';
          _isWaitingForReply = false;
          _isCharacterReply = true;
          final isMeetingUnlocked = (ref.read(signalCountProvider).valueOrNull ?? 0) >= 30;
          _showMeetingBanner = (result?.meetingSuggested ?? false) && isMeetingUnlocked;
        });
        if (result != null) saveLastQuestion(result.reply, ref.read(currentUserIdProvider) ?? '');
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
        if (result.memoDetected) {
          final memos = result.detectedMemos.isNotEmpty
              ? result.detectedMemos
              : (result.detectedMemo != null ? [result.detectedMemo!] : <MemoModel>[]);
          if (memos.isNotEmpty) {
            return _ActionConfirmDialog(
              icon: Icons.notes,
              title: memos.length > 1 ? 'メモを${memos.length}件保存しますか？' : 'メモを保存しますか？',
              rows: memos
                  .map((m) => _DialogInfoRow(icon: Icons.text_snippet, label: 'メモ', content: m.title))
                  .toList(),
              accentColor: accentColor,
              showEditButton: memos.length == 1,
              onAdd: () async {
                Navigator.of(dialogContext).pop();
                for (final m in memos) {
                  await _saveMemoModel(m);
                }
              },
              onEdit: memos.length == 1
                  ? () {
                      Navigator.of(dialogContext).pop();
                      context.push('/memo/detail', extra: memos.first);
                    }
                  : null,
              onCancel: () => Navigator.of(dialogContext).pop(),
            );
          }
        }
        if (result.todoDetected) {
          final todos = result.detectedTodos.isNotEmpty
              ? result.detectedTodos
              : (result.detectedTodo != null ? [result.detectedTodo!] : <TodoModel>[]);
          if (todos.isNotEmpty) {
            return _ActionConfirmDialog(
              icon: Icons.check_circle_outline,
              title: todos.length > 1 ? 'タスクを${todos.length}件追加しますか？' : 'タスクを追加しますか？',
              rows: todos
                  .map((t) => _DialogInfoRow(icon: Icons.text_snippet, label: 'タスク', content: t.title))
                  .toList(),
              accentColor: accentColor,
              showEditButton: todos.length == 1,
              onAdd: () async {
                Navigator.of(dialogContext).pop();
                for (final t in todos) {
                  await _saveTodoModel(t);
                }
              },
              onEdit: todos.length == 1
                  ? () {
                      Navigator.of(dialogContext).pop();
                      context.push('/todo/detail', extra: todos.first);
                    }
                  : null,
              onCancel: () => Navigator.of(dialogContext).pop(),
            );
          }
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
          '動画広告を視聴すると、チャットが続けられます。',
          textAlign: TextAlign.center,
        ),
        actions: [
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

  /// signalCountとセッション内ターン数からフェーズを算出
  /// signalCount <  10: Phase 1固定（性格データ未確定）
  /// signalCount 10-29: Phase 2固定（初回解析済み・完全確定前）
  /// signalCount >= 30: turn1=P1, turn2-4=P2, turn5+=P3
  int _calcPhase(int signalCount, int sessionTurn) {
    if (signalCount < 10) return 1;
    if (signalCount < 30) return 2;
    if (sessionTurn <= 1) return 1;
    if (sessionTurn <= 4) return 2;
    return 3;
  }


  Future<void> _showEvolutionDialog(TypeChangeData data) async {
    final signalCount = ref.read(signalCountProvider).valueOrNull ?? 30;
    final details = ref.read(characterDetailsProvider).valueOrNull;
    final gender = details?.gender;
    final userId = ref.read(currentUserIdProvider);

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      pageBuilder: (ctx, anim, secAnim) => _TypeEvolutionDialog(
        newElement: data.newElement,
        newTypeName: data.newTypeName,
        signalCount: signalCount,
        gender: gender,
        onConfirm: () async {
          if (userId != null) {
            try {
              await ref.read(firestoreProvider)
                  .collection('users').doc(userId)
                  .collection('personalityMeta').doc('current')
                  .update({'pendingTypeChangeNotification': false});
            } catch (_) {}
          }
        },
      ),
    );
    if (mounted) setState(() => _isShowingEvolutionDialog = false);
  }

  void _showMeetingLockedDialog(BuildContext context, int signalCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, color: ref.read(accentColorProvider)),
            const SizedBox(width: 8),
            const Flexible(child: Text('機能がロックされています')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('「自分会議」機能を利用するには、チャットをもう少し続けて性格タイプを確定させる必要があります。'),
            const SizedBox(height: 16),
            Text('現在の進捗: $signalCount / 30'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: signalCount / 30,
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
        ],
      ),
    );
  }
}

/// キャラクター成長段階表示
class _CharacterDisplay extends StatelessWidget {
  final double width;
  final double height;
  final int signalCount;
  final String? element;
  final String? gender;

  const _CharacterDisplay({
    super.key,
    required this.width,
    required this.height,
    required this.signalCount,
    this.element,
    this.gender,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = characterGrowthAssetPath(
      signalCount: signalCount,
      element: element,
      gender: gender,
    );
    final elementType = signalCount >= 30 ? elementTypeFromString(element) : null;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (elementType != null)
            Positioned.fill(
              child: ElementEffectWidget(
                element: elementType,
                pattern: elementType.defaultPattern,
              ),
            ),
          Image.asset(
            assetPath,
            width: width * 1.5,
            height: height * 1.5,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.person_outline,
              size: width * 0.3,
              color: AppColors.textLight.withValues(alpha: 0.5),
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
                                hintText: widget.isWaitingForReply ? '返答を待っています...' : 'メッセージを入力...',
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

/// 成長ゲージ（参考画像スタイル: バッジ + ラベル + カウント + プログレスバー）
class _GrowthGauge extends StatelessWidget {
  final int signalCount;
  final Color accentColor;

  const _GrowthGauge({required this.signalCount, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final String badge;
    final String label;
    final double progress;
    final String countText;

    if (signalCount >= 100) {
      final cycle = signalCount % 10;
      badge = '大人';
      label = '性格解析';
      progress = cycle / 10.0;
      countText = '$cycle / 10';
    } else if (signalCount >= 30) {
      badge = '幼少期';
      label = '大人まで';
      progress = signalCount / 100.0;
      countText = '$signalCount / 100';
    } else {
      badge = '赤ちゃん';
      label = '幼少期まで';
      progress = signalCount / 30.0;
      countText = '$signalCount / 30';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF333333),
                  ),
                ),
                const Spacer(),
                Text(
                  countText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF555555),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: accentColor.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                minHeight: 7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 自分会議提案バナー
// ─────────────────────────────────────────────
class _MeetingSuggestionBanner extends StatelessWidget {
  final Color accentColor;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const _MeetingSuggestionBanner({
    required this.accentColor,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology_outlined, size: 18, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '自分会議で整理してみる？',
              style: TextStyle(
                fontSize: 13,
                color: accentColor,
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: onOpen,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '開く',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, size: 18, color: accentColor.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

/// 進化ダイアログ：元素/性格タイプが変化したときに表示
class _TypeEvolutionDialog extends StatefulWidget {
  final String newElement;
  final String newTypeName;
  final int signalCount;
  final String? gender;
  final Future<void> Function() onConfirm;

  const _TypeEvolutionDialog({
    required this.newElement,
    required this.newTypeName,
    required this.signalCount,
    required this.gender,
    required this.onConfirm,
  });

  @override
  State<_TypeEvolutionDialog> createState() => _TypeEvolutionDialogState();
}

class _TypeEvolutionDialogState extends State<_TypeEvolutionDialog>
    with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final AnimationController _contentController;
  final GlobalKey _shareButtonKey = GlobalKey();
  final GlobalKey _offscreenCardKey = GlobalKey();
  late final Animation<double> _glowAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  bool _isSharing = false;

  static const _elementColors = {
    '炎': Color(0xFFFF6B35),
    '風': Color(0xFF64B5F6),
    '雷': Color(0xFFFFD54F),
    '光': Color(0xFFFFF9C4),
    '水': Color(0xFF42A5F5),
    '土': Color(0xFF8D6E63),
    '氷': Color(0xFF80DEEA),
    '闇': Color(0xFFCE93D8),
    '無': Color(0xFFB0BEC5),
  };

  static const _elementEmojis = {
    '炎': '🔥',
    '風': '💨',
    '雷': '⚡',
    '光': '✨',
    '水': '💧',
    '土': '🌿',
    '氷': '❄️',
    '闇': '🌑',
    '無': '⭐',
  };

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// アニメーション外の静的シェアカードをキャプチャして共有
  Future<void> _captureAndShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    final shareText = 'DARIASで「${widget.newTypeName}」になりました！ #DARIAS #性格診断';
    try {
      final boundary = _offscreenCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('boundary not found');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('toByteData failed');

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/darias_evolution.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      debugPrint('Image capture failed ($e), falling back to text share');
      try {
        final box2 = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
        final origin2 = box2 != null ? box2.localToGlobal(Offset.zero) & box2.size : null;
        await Share.share(shareText, sharePositionOrigin: origin2);
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  /// アニメーションなしのシェアカード（画面外キャプチャ用）
  Widget _buildShareCard(Color elementColor, String elementEmoji) {
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: elementColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: elementColor.withValues(alpha: 0.5),
            blurRadius: 32,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '性格タイプが変わりました',
            style: TextStyle(
              color: elementColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: elementColor.withValues(alpha: 0.7),
                  blurRadius: 28,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: ClipOval(
              child: Container(
                color: elementColor.withValues(alpha: 0.15),
                child: Center(
                  child: Text(elementEmoji, style: const TextStyle(fontSize: 48)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(elementEmoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(
            '${widget.newElement}属性',
            style: TextStyle(color: elementColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.newTypeName} になりました！',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'あなたの性格がより深く分析されました',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
          const SizedBox(height: 16),
          Text(
            'DARIAS',
            style: TextStyle(
              color: elementColor.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final elementColor = _elementColors[widget.newElement] ?? const Color(0xFFB0BEC5);
    final elementEmoji = _elementEmojis[widget.newElement] ?? '⭐';

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 画面外に静的シェアカードを配置（アニメーションレイヤー外でキャプチャするため）
          Positioned(
            left: -9999,
            top: 100,
            child: RepaintBoundary(
              key: _offscreenCardKey,
              child: _buildShareCard(elementColor, elementEmoji),
            ),
          ),

          // 表示用アニメーションダイアログ
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: elementColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: elementColor.withValues(alpha: 0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '性格タイプが変わりました',
                        style: TextStyle(
                          color: elementColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedBuilder(
                        animation: _glowAnim,
                        builder: (_, __) => Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: elementColor.withValues(alpha: _glowAnim.value * 0.8),
                                blurRadius: 32 * _glowAnim.value,
                                spreadRadius: 8 * _glowAnim.value,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Container(
                              color: elementColor.withValues(alpha: 0.15),
                              child: Center(
                                child: Text(elementEmoji, style: const TextStyle(fontSize: 48)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(elementEmoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.newElement}属性',
                        style: TextStyle(color: elementColor, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.newTypeName} になりました！',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'あなたの性格がより深く分析されました',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        key: _shareButtonKey,
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSharing ? null : _captureAndShare,
                          icon: _isSharing
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: elementColor,
                                  ),
                                )
                              : const Icon(Icons.share, size: 18),
                          label: Text(_isSharing ? '準備中...' : 'シェアする'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: elementColor,
                            side: BorderSide(color: elementColor.withValues(alpha: 0.6)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await widget.onConfirm();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: elementColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '確認する',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
