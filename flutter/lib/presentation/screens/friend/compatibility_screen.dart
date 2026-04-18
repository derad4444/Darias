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

  /// Firestoreリロードを待たず即時反映するローカルステート
  final Set<String> _localUnlocked = {};
  final Map<String, CategoryDiagnosis> _localCategories = {};

  final RewardedAdManager _rewardedAdManager = RewardedAdManager();

  @override
  void initState() {
    super.initState();
    _loadDocument();
    if (!kIsWeb) {
      _rewardedAdManager.loadAd();
    }
  }

  @override
  void dispose() {
    _rewardedAdManager.dispose();
    super.dispose();
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
      }
      _isInitialLoading = false;
    });
  }

  bool _isUnlocked(String key) => _localUnlocked.contains(key);
  CategoryDiagnosis? _getDiagnosis(String key) => _localCategories[key];

  // ─────────────────────────────────────────
  // カテゴリタップ処理
  // ─────────────────────────────────────────
  Future<void> _onCategoryTap(CompatibilityCategoryMeta cat) async {
    if (_processingCategoryKey != null) return;

    final isPremium = ref.read(effectiveIsPremiumProvider);

    // Web版: 無料ユーザーはブロック
    if (kIsWeb && !isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Web版の相性診断は有料プランのみご利用いただけます'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final existingDiagnosis = _getDiagnosis(cat.key);

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

    // 未解放 → AI診断 + 広告
    setState(() {
      _processingCategoryKey = cat.key;
      _errorMessage = null;
    });

    CategoryDiagnosis? diagnosis;

    if (!kIsWeb) {
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
    } else {
      // Web版プレミアム: 広告なしで診断
      diagnosis = await ref
          .read(friendControllerProvider.notifier)
          .runCategoryDiagnosis(
            friendId: widget.friend.id,
            category: cat.key,
          );
    }

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

    final myDetails = ref.watch(characterDetailsProvider).valueOrNull;
    final friendDetailsAsync = ref.watch(userCharacterDetailsProvider(widget.friend.id));

    final myBig5Done = (myDetails?.confirmedBig5Scores?.isNotEmpty ?? false);
    final friendBig5Done = friendDetailsAsync.valueOrNull?.confirmedBig5Scores?.isNotEmpty ?? false;
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
          '相性診断',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
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

                    // 相性診断ヒントバナー（初回のみ、アバターの下）
                    InlineHintBanner(
                      userId: myUserId,
                      feature: HintService.kCompatibility,
                      message: '無料ユーザーは各カテゴリを動画広告視聴で解放できます。診断には自分とフレンド双方のBIG5診断完了が必要です。',
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
                                    ? '診断には自分と${widget.friend.name}さん双方のBIG5診断完了が必要です'
                                    : !myBig5Done
                                        ? '診断にはあなたのBIG5診断完了が必要です。チャットで"性格診断して"と送ってください'
                                        : '診断には${widget.friend.name}さんのBIG5診断完了が必要です',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Web無料ユーザー向け案内
                    if (kIsWeb && !isPremium) ...[
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
                                'Web版の相性診断は有料プランのみご利用いただけます',
                                style: TextStyle(fontSize: 12),
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
                  ],
                ),
        ),
      ),
    );
  }

  bool get _isAllUnlocked =>
      kCompatibilityCategories.every((c) => _isUnlocked(c.key));

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
              ? _buildUnlockedTile(cat)
              : _buildLockedTile(cat, accentColor, isPremium, anyProcessing, big5Ready),
    );
  }

  /// 解放済みカード（スコアバッジ + 「結果を見る」）
  Widget _buildUnlockedTile(CompatibilityCategoryMeta cat) {
    final score = _document?.scores?.scoreFor(cat.key) ??
        _getDiagnosis(cat.key)?.score ??
        0;
    final hasScore = score > 0;

    return InkWell(
      onTap: () => _onCategoryTap(cat),
      borderRadius: BorderRadius.circular(14),
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
    );
  }

  /// 未解放カード（診断するボタン）
  Widget _buildLockedTile(CompatibilityCategoryMeta cat, Color accentColor,
      bool isPremium, bool anyProcessing, bool big5Ready) {
    final isWebFree = kIsWeb && !isPremium;
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
                    '有料のみ',
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
