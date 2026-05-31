import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/friend_model.dart';
import '../../../data/services/rewarded_ad_manager.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/character_provider.dart';
import '../../widgets/character_avatar_widget.dart';
import '../../widgets/inline_hint_banner.dart';
import '../../../data/services/hint_service.dart';
import 'compatibility_category_screen.dart';
import 'friend_ask_screen.dart';
import '../../providers/calendar_provider.dart';

/// カテゴリ定義
class CompatibilityCategoryMeta {
  final String key;
  final String icon;
  final String label;
  final String description;
  final Color color;

  const CompatibilityCategoryMeta({
    required this.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
  });
}

const kCompatibilityCategories = [
  CompatibilityCategoryMeta(
    key: 'friendship',
    icon: '👫',
    label: '友情',
    description: '友人としての付き合い方・日常の相性',
    color: Colors.blue,
  ),
  CompatibilityCategoryMeta(
    key: 'romance',
    icon: '💫',
    label: '恋愛',
    description: '感情的な相性・コミュニケーションスタイル',
    color: Colors.pink,
  ),
  CompatibilityCategoryMeta(
    key: 'work',
    icon: '💼',
    label: '仕事',
    description: '協力・役割分担・強みの活かし方',
    color: Colors.orange,
  ),
  CompatibilityCategoryMeta(
    key: 'trust',
    icon: '🤝',
    label: '信頼',
    description: '誠実さ・長期的な信頼関係',
    color: Colors.green,
  ),
];

class CompatibilityScreen extends ConsumerStatefulWidget {
  final FriendModel friend;

  const CompatibilityScreen({
    super.key,
    required this.friend,
  });

  @override
  ConsumerState<CompatibilityScreen> createState() =>
      _CompatibilityScreenState();
}

class _CompatibilityScreenState extends ConsumerState<CompatibilityScreen> {
  CompatibilityDocument? _document;
  bool _isInitialLoading = true;
  String? _processingCategoryKey;
  String? _errorMessage;
  bool _isStale = false;

  /// Firestoreリロードを待たず即時反映するローカルステート
  final Set<String> _localUnlocked = {};
  final Map<String, CategoryDiagnosis> _localCategories = {};

  final RewardedAdManager _rewardedAdManager = RewardedAdManager();

  @override
  void initState() {
    super.initState();
    _loadDocument();
    _markCompatibilityNotificationRead();
    if (!kIsWeb) {
      _rewardedAdManager.loadAd();
    }
  }

  Future<void> _markCompatibilityNotificationRead() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final notifRef = ref.read(firestoreProvider)
          .collection('users')
          .doc(userId)
          .collection('friendNotifications')
          .doc(widget.friend.id);
      final snap = await notifRef.get();
      if (snap.exists && snap.data()?['isRead'] == false) {
        await notifRef.update({'isRead': true});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _rewardedAdManager.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // フレンド削除確認ダイアログ
  // ─────────────────────────────────────────
  Future<void> _confirmRemoveFriend(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('フレンドを削除'),
        content: Text(
          '${widget.friend.name.isNotEmpty ? widget.friend.name : 'このフレンド'}をフレンドから削除しますか？\n\n相手のフレンド一覧からも削除され、予定の共有も解除されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(friendControllerProvider.notifier).removeFriend(widget.friend.id);
    if (!context.mounted) return;
    Navigator.pop(context);
  }

  // ─────────────────────────────────────────
  // Firestoreからドキュメント読み込み
  // ─────────────────────────────────────────
  Future<void> _loadDocument() async {
    final doc = await ref
        .read(friendControllerProvider.notifier)
        .fetchCompatibilityDocument(friendId: widget.friend.id);
    if (!mounted) return;
    setState(() {
      _document = doc;
      if (doc != null) {
        // Firestoreの解放済みリストをローカルにマージ
        _localUnlocked.addAll(doc.unlockedCategories);
        // Firestoreのカテゴリデータをローカルにマージ
        for (final cat in kCompatibilityCategories) {
          if (!_localCategories.containsKey(cat.key)) {
            final catDiag = doc.categoryFor(cat.key);
            if (catDiag != null) _localCategories[cat.key] = catDiag;
          }
        }
        // stale状態を反映（毎回画面を開くたびにポップアップを表示）
        _isStale = doc.isStale;
      }
      _isInitialLoading = false;
    });

    // staleの場合はフレーム描画後にポップアップを表示
    if (_isStale) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showStaleDialog();
      });
    }
  }

  void _showStaleDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.refresh, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text('診断内容が古くなっています'),
            ),
          ],
        ),
        content: const Text(
          'あなたまたはフレンドの性格が更新されたため、この相性診断の内容が最新ではありません。\n\n再診断ボタンから最新の診断を実行してください。\n\n最新の診断を実行するまで、このお知らせは毎回表示されます。',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  bool _isUnlocked(String key) => _localUnlocked.contains(key);
  CategoryDiagnosis? _getDiagnosis(String key) => _localCategories[key];

  // ─────────────────────────────────────────
  // カテゴリタップ処理
  // ─────────────────────────────────────────
  Future<void> _onCategoryTap(CompatibilityCategoryMeta cat) async {
    if (_processingCategoryKey != null) return;

    final existingDiagnosis = _getDiagnosis(cat.key);

    // 既存結果がある場合はWeb・無料ユーザーでも閲覧可能
    if (existingDiagnosis != null) {
      // 解放済み → 広告なしで詳細画面へ
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompatibilityCategoryScreen(
            friend: widget.friend,
            category: cat,
            diagnosis: existingDiagnosis,
            animateOnEntry: false,
          ),
        ),
      );
      // 戻ってきたらFirestoreを再読み込み（スコア等の更新のため）
      await _loadDocument();
      return;
    }

    // 未解放 → Web版は新規診断不可（プレミアム含む）
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('相性診断はアプリ版でご利用いただけます'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // 未解放 → AI診断 + 広告
    setState(() {
      _processingCategoryKey = cat.key;
      _errorMessage = null;
    });

    CategoryDiagnosis? diagnosis;

    final diagnosisFuture = ref
        .read(friendControllerProvider.notifier)
        .runCategoryDiagnosis(
          friendId: widget.friend.id,
          category: cat.key,
        );

    final adCompleter = Completer<void>();
    _rewardedAdManager.onAdDismissed = () {
      if (!adCompleter.isCompleted) adCompleter.complete();
    };
    final showed = await _rewardedAdManager.showAd();
    if (!showed) adCompleter.complete();

    await Future.wait([
      adCompleter.future,
      diagnosisFuture.then((r) => diagnosis = r),
    ]);
    _rewardedAdManager.loadAd();

    if (!mounted) return;
    setState(() => _processingCategoryKey = null);

    if (diagnosis == null) {
      setState(() => _errorMessage = '診断に失敗しました。もう一度お試しください。');
      return;
    }

    // ローカルステートを即時更新（Firestoreのリロードを待たない）
    setState(() {
      _localUnlocked.add(cat.key);
      _localCategories[cat.key] = diagnosis!;
      // 再診断完了でstaleフラグをローカルでクリア（_loadDocumentで最終確定）
      _isStale = false;
    });

    // カテゴリ詳細画面へ（初回なのでアニメーションあり）
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompatibilityCategoryScreen(
          friend: widget.friend,
          category: cat,
          diagnosis: diagnosis!,
          animateOnEntry: true,
        ),
      ),
    );

    // 戻ってきたらFirestoreを再読み込み（スコア等の更新のため）
    await _loadDocument();
  }

  /// stale時の強制再診断（既存結果を無視してAI診断を走らせる）
  Future<void> _onRediagnoseTap(CompatibilityCategoryMeta cat) async {
    if (_processingCategoryKey != null) return;

    // Web版は再診断不可（プレミアム含む）
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('相性診断はアプリ版でご利用いただけます'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _processingCategoryKey = cat.key;
      _errorMessage = null;
    });

    CategoryDiagnosis? diagnosis;

    final diagnosisFuture = ref
        .read(friendControllerProvider.notifier)
        .runCategoryDiagnosis(
          friendId: widget.friend.id,
          category: cat.key,
        );
    final adCompleter = Completer<void>();
    _rewardedAdManager.onAdDismissed = () {
      if (!adCompleter.isCompleted) adCompleter.complete();
    };
    final showed = await _rewardedAdManager.showAd();
    if (!showed) adCompleter.complete();
    await Future.wait([
      adCompleter.future,
      diagnosisFuture.then((r) => diagnosis = r),
    ]);
    _rewardedAdManager.loadAd();

    if (!mounted) return;
    setState(() => _processingCategoryKey = null);

    if (diagnosis == null) {
      setState(() => _errorMessage = '再診断に失敗しました。もう一度お試しください。');
      return;
    }

    setState(() {
      _localCategories[cat.key] = diagnosis!;
      _localUnlocked.add(cat.key);
      _isStale = false;
    });

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompatibilityCategoryScreen(
          friend: widget.friend,
          category: cat,
          diagnosis: diagnosis!,
          animateOnEntry: true,
        ),
      ),
    );
    await _loadDocument();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = ref.watch(backgroundGradientProvider);
    final accentColor = ref.watch(accentColorProvider);
    final userAsync = ref.watch(userDocProvider);
    final myUser = userAsync.valueOrNull;
    final myUserId = ref.watch(currentUserIdProvider) ?? '';
    final isPremium = ref.watch(effectiveIsPremiumProvider);

    final myName = myUser?.name ?? '自分';
    final myInitial = myName.isNotEmpty ? myName[0] : 'M';
    final friendInitial =
        widget.friend.name.isNotEmpty ? widget.friend.name[0] : 'F';

    final friends = ref.watch(friendsProvider).valueOrNull ?? [];
    final currentFriend = friends.firstWhere(
      (f) => f.id == widget.friend.id,
      orElse: () => widget.friend,
    );

    final myDetails = ref.watch(characterDetailsProvider).valueOrNull;
    final friendDetailsAsync = ref.watch(userCharacterDetailsProvider(widget.friend.id));

    // confirmedBig5Scores は analysis_level > 0 の場合のみ有効（signup時のデフォルト値と区別）
    // convertedBig5Scores はチャットシグナル10件以上で生成される
    final myBig5Done = ((myDetails?.analysisLevel ?? 0) > 0 && (myDetails?.confirmedBig5Scores?.isNotEmpty ?? false)) ||
        (myDetails?.convertedBig5Scores?.isNotEmpty ?? false);
    final friendDetails = friendDetailsAsync.valueOrNull;
    final friendBig5Done =
        ((friendDetails?.analysisLevel ?? 0) > 0 && (friendDetails?.confirmedBig5Scores?.isNotEmpty ?? false)) ||
        (friendDetails?.convertedBig5Scores?.isNotEmpty ?? false);
    // どちらかまだロード中の場合はボタンを活性にしておく（false alertを避ける）
    final big5DataLoaded = !ref.watch(characterDetailsProvider).isLoading &&
        !friendDetailsAsync.isLoading;
    final big5Ready = !big5DataLoaded || (myBig5Done && friendBig5Done);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios, color: accentColor),
        ),
        title: Text(
          'フレンド詳細',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmRemoveFriend(context, ref),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: _isInitialLoading
              ? Center(child: CircularProgressIndicator(color: accentColor))
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _buildAvatarRow(
                        accentColor, myUserId, myName, myInitial, friendInitial),
                    const SizedBox(height: 12),

                    // 予定の共有設定
                    _buildShareLevelSection(accentColor, currentFriend, ref),
                    const SizedBox(height: 4),

                    // 相性診断ヒントバナー（初回のみ、アバターの下）
                    InlineHintBanner(
                      userId: myUserId,
                      feature: HintService.kCompatibility,
                      message: '無料ユーザーは各カテゴリを動画広告視聴で解放できます。診断には自分とフレンド双方の性格解析（30回以上チャット）が必要です。',
                      icon: Icons.favorite_border,
                    ),
                    const SizedBox(height: 12),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // BIG5未完了の場合の案内（データロード完了後のみ表示）
                    if (big5DataLoaded && !big5Ready) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (!myBig5Done && !friendBig5Done)
                                    ? '診断には自分と${widget.friend.name}さん双方の性格解析が必要です。チャットを30回以上続けてください'
                                    : !myBig5Done
                                        ? '診断にはあなたの性格解析が必要です。チャットを30回以上続けてください'
                                        : '診断には${widget.friend.name}さんの性格解析完了が必要です',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Web無料ユーザー向け案内
                    if (kIsWeb) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '相性診断はアプリ版でご利用いただけます。フレンドが診断済みの結果は閲覧できます',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 性格更新によるstaleバナー
                    if (_isStale) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.refresh, color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '性格が更新されました。再診断で最新の結果に更新できます',
                                style: TextStyle(fontSize: 12, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    ...kCompatibilityCategories.map((cat) => _buildCategoryCard(
                          cat,
                          accentColor,
                          isPremium,
                          big5Ready,
                        )),

                    if (!isPremium && !kIsWeb) ...[
                      const SizedBox(height: 4),
                      Text(
                        '無料ユーザーは広告視聴で各カテゴリを診断できます',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    // 全カテゴリ解放時の総合スコア
                    if (_isAllUnlocked) ...[
                      const SizedBox(height: 20),
                      _buildOverallCard(accentColor),
                    ],

                    // フレンドに聞くボタン
                    const SizedBox(height: 20),
                    _buildAskButton(accentColor),
                  ],
                ),
        ),
      ),
    );
  }

  bool get _isAllUnlocked =>
      kCompatibilityCategories.every((c) => _isUnlocked(c.key));

  // ─────────────────────────────────────────
  // フレンドに聞くボタン
  // ─────────────────────────────────────────
  Widget _buildAskButton(Color accentColor) {
    final friendName = widget.friend.name.isNotEmpty ? widget.friend.name : 'フレンド';
    return OutlinedButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FriendAskScreen(friend: widget.friend),
        ),
      ),
      icon: const Text('💬', style: TextStyle(fontSize: 16)),
      label: Text(
        '$friendNameのことを聞いてみる',
        style: TextStyle(fontSize: 14, color: accentColor),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }

  // ─────────────────────────────────────────
  // 予定の共有設定セクション
  // ─────────────────────────────────────────
  Widget _buildShareLevelSection(Color accentColor, FriendModel currentFriend, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 15, color: accentColor),
              const SizedBox(width: 6),
              Text(
                '予定の共有設定',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Align(
              key: ValueKey(currentFriend.shareLevel),
              alignment: Alignment.centerLeft,
              child: Text(
                _shareLevelDescription(currentFriend.shareLevel),
                style: TextStyle(
                  fontSize: 12,
                  color: _shareLevelColor(currentFriend.shareLevel),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: FriendShareLevel.values.map((level) {
              final isSelected = currentFriend.shareLevel == level;
              final color = _shareLevelColor(level);
              final icon = _shareLevelIcon(level);
              return Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await ref
                        .read(friendControllerProvider.notifier)
                        .updateShareLevel(currentFriend.id, level);
                    ref.read(friendScheduleRefreshProvider.notifier).state++;
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(icon,
                            size: 18,
                            color: isSelected ? color : Colors.grey[400]),
                        const SizedBox(height: 4),
                        Text(
                          level.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? color : Colors.grey[400],
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _shareLevelColor(FriendShareLevel level) {
    switch (level) {
      case FriendShareLevel.none:   return AppColors.textLight;
      case FriendShareLevel.public: return Colors.blue;
      case FriendShareLevel.full:   return Colors.green;
    }
  }

  IconData _shareLevelIcon(FriendShareLevel level) {
    switch (level) {
      case FriendShareLevel.none:   return Icons.visibility_off_outlined;
      case FriendShareLevel.public: return Icons.visibility_outlined;
      case FriendShareLevel.full:   return Icons.public;
    }
  }

  String _shareLevelDescription(FriendShareLevel level) {
    switch (level) {
      case FriendShareLevel.none:
        return '予定を一切共有しません';
      case FriendShareLevel.public:
        return '非公開設定・非公開タグでない予定を共有します';
      case FriendShareLevel.full:
        return '非公開設定の予定・非公開タグの予定も含めてすべて共有します';
    }
  }

  // ─────────────────────────────────────────
  // アバター行
  // ─────────────────────────────────────────
  Widget _buildAvatarRow(Color accentColor, String myUserId, String myName,
      String myInitial, String friendInitial) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LabeledAvatar(
          avatar: CharacterAvatarWidget(
            userId: myUserId,
            size: 60,
            fallbackText: myInitial,
            fallbackBackgroundColor: accentColor.withValues(alpha: 0.2),
            fallbackTextColor: accentColor,
          ),
          label: myName,
          color: accentColor,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Icon(
            Icons.compare_arrows,
            color: accentColor.withValues(alpha: 0.5),
            size: 28,
          ),
        ),
        _LabeledAvatar(
          avatar: CharacterAvatarWidget(
            userId: widget.friend.id,
            size: 60,
            fallbackText: friendInitial,
            fallbackBackgroundColor: Colors.indigo.withValues(alpha: 0.2),
            fallbackTextColor: Colors.indigo,
          ),
          label: widget.friend.name,
          color: Colors.indigo,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // カテゴリカード（処理中 / 解放済み / 未解放）
  // ─────────────────────────────────────────
  Widget _buildCategoryCard(
      CompatibilityCategoryMeta cat, Color accentColor, bool isPremium, bool big5Ready) {
    final isProcessing = _processingCategoryKey == cat.key;
    final isUnlocked = _isUnlocked(cat.key);
    final anyProcessing = _processingCategoryKey != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cat.color.withValues(alpha: 0.2)),
      ),
      child: isProcessing
          ? Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  Text(cat.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${cat.label}を診断中...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cat.color,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cat.color),
                  ),
                ],
              ),
            )
          : isUnlocked
              ? _buildUnlockedTile(cat, accentColor, isPremium, anyProcessing, big5Ready)
              : _buildLockedTile(cat, accentColor, isPremium, anyProcessing, big5Ready),
    );
  }

  /// 解放済みカード（スコアバッジ + 「結果を見る」 / stale時は「再診断」ボタン追加）
  Widget _buildUnlockedTile(CompatibilityCategoryMeta cat, Color accentColor,
      bool isPremium, bool anyProcessing, bool big5Ready) {
    final score = _document?.scores?.scoreFor(cat.key) ??
        _getDiagnosis(cat.key)?.score ??
        0;
    final hasScore = score > 0;

    return Column(
      children: [
        InkWell(
          onTap: () => _onCategoryTap(cat),
          borderRadius: _isStale
              ? const BorderRadius.vertical(top: Radius.circular(14))
              : BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(cat.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: cat.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (hasScore) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: score / 100,
                            backgroundColor: cat.color.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(cat.color),
                            minHeight: 5,
                          ),
                        ),
                      ] else ...[
                        Text(
                          '結果を見る',
                          style: TextStyle(
                            fontSize: 11,
                            color: cat.color.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (hasScore) ...[
                  Text(
                    '$score%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cat.color,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(Icons.chevron_right,
                    color: cat.color.withValues(alpha: 0.6), size: 20),
              ],
            ),
          ),
        ),
        // stale時: 再診断ボタン
        if (_isStale) ...[
          const Divider(height: 1),
          InkWell(
            onTap: anyProcessing || !big5Ready
                ? null
                : () => _onRediagnoseTap(cat),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh, size: 15, color: cat.color.withValues(alpha: 0.8)),
                  const SizedBox(width: 6),
                  Text(
                    '再診断する',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cat.color.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 未解放カード（診断するボタン）
  Widget _buildLockedTile(CompatibilityCategoryMeta cat, Color accentColor,
      bool isPremium, bool anyProcessing, bool big5Ready) {
    final isWebFree = kIsWeb;
    final isDisabled = !big5Ready || anyProcessing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(cat.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isWebFree ? cat.color.withValues(alpha: 0.4) : cat.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cat.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary
                        .withValues(alpha: isWebFree ? 0.4 : 1.0),
                  ),
                ),
              ],
            ),
          ),
          if (isWebFree)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 12,
                      color: Colors.grey.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Text(
                    'アプリ版で',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: isDisabled ? null : () => _onCategoryTap(cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? accentColor.withValues(alpha: 0.3)
                      : accentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!big5Ready) ...[
                      const Icon(Icons.lock_outline, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                    ] else if (!isPremium) ...[
                      const Icon(Icons.play_circle_outline,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    const Text(
                      '診断する',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // 総合スコアカード（全カテゴリ解放後）
  // ─────────────────────────────────────────
  Widget _buildOverallCard(Color accentColor) {
    final overall = _document?.scores?.overall ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.15),
            accentColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '総合相性スコア',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$overall',
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              Text(
                '%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// ラベル付きアバター
// ─────────────────────────────────────────
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
