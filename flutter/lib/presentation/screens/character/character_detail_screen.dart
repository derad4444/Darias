import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/character/element_effect_widget.dart';
import '../../providers/auth_provider.dart';
import '../../providers/character_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import '../../providers/ad_provider.dart';
import '../../../data/services/ad_service.dart';

/// Big5解析カテゴリー
enum Big5AnalysisCategory {
  career('career', '仕事・キャリアスタイル', '💼'),
  romance('romance', '恋愛・人間関係の特徴', '💕'),
  stress('stress', 'ストレス対処・感情管理', '🧘‍♀️'),
  learning('learning', '学習・成長アプローチ', '📚'),
  decision('decision', '意思決定・問題解決スタイル', '🎯');

  final String value;
  final String displayName;
  final String icon;

  const Big5AnalysisCategory(this.value, this.displayName, this.icon);
}

/// Big5詳細解析データ
class Big5DetailedAnalysis {
  final Big5AnalysisCategory category;
  final String personalityType;
  final String detailedText;
  final List<String> keyPoints;

  Big5DetailedAnalysis({
    required this.category,
    required this.personalityType,
    required this.detailedText,
    required this.keyPoints,
  });

  factory Big5DetailedAnalysis.fromMap(Map<String, dynamic> data, Big5AnalysisCategory category) {
    return Big5DetailedAnalysis(
      category: category,
      personalityType: data['personality_type'] as String? ?? '',
      detailedText: data['detailed_text'] as String? ?? '',
      keyPoints: (data['key_points'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

/// Big5解析データ
class Big5AnalysisData {
  final String personalityKey;
  final Map<Big5AnalysisCategory, Big5DetailedAnalysis>? analysis100;

  Big5AnalysisData({
    required this.personalityKey,
    this.analysis100,
  });
}

/// キャラクター詳細データ（iOS版と同じフィールド）
class CharacterDetailData {
  final String? favoriteColor;
  final String? favoritePlace;
  final String? favoriteWord;
  final String? wordTendency;
  final String? strength;
  final String? weakness;
  final String? skill;
  final String? hobby;
  final String? aptitude;
  final String? dream;
  final String? gender;
  final int analysisLevel;
  final Map<String, double>? confirmedBig5Scores;
  final Map<String, double>? convertedBig5Scores;
  final Map<String, double>? axisScores;
  final String? personalityKey;
  final String? element;
  final String? typeName;
  final String? personalityNarrative;

  CharacterDetailData({
    this.favoriteColor,
    this.favoritePlace,
    this.favoriteWord,
    this.wordTendency,
    this.strength,
    this.weakness,
    this.skill,
    this.hobby,
    this.aptitude,
    this.dream,
    this.gender,
    this.analysisLevel = 0,
    this.confirmedBig5Scores,
    this.convertedBig5Scores,
    this.axisScores,
    this.personalityKey,
    this.element,
    this.typeName,
    this.personalityNarrative,
  });

  factory CharacterDetailData.fromMap(Map<String, dynamic> data) {
    Map<String, double>? scores;
    final scoresMap = data['confirmedBig5Scores'] as Map<String, dynamic>?;
    if (scoresMap != null) {
      scores = {
        'openness': (scoresMap['openness'] as num?)?.toDouble() ?? 3.0,
        'conscientiousness': (scoresMap['conscientiousness'] as num?)?.toDouble() ?? 3.0,
        'extraversion': (scoresMap['extraversion'] as num?)?.toDouble() ?? 3.0,
        'agreeableness': (scoresMap['agreeableness'] as num?)?.toDouble() ?? 3.0,
        'neuroticism': (scoresMap['neuroticism'] as num?)?.toDouble() ?? 3.0,
      };
    }

    Map<String, double>? convertedScores;
    final convertedScoresMap = data['convertedBig5Scores'] as Map<String, dynamic>?;
    if (convertedScoresMap != null) {
      convertedScores = {
        'openness': (convertedScoresMap['openness'] as num?)?.toDouble() ?? 3.0,
        'conscientiousness': (convertedScoresMap['conscientiousness'] as num?)?.toDouble() ?? 3.0,
        'extraversion': (convertedScoresMap['extraversion'] as num?)?.toDouble() ?? 3.0,
        'agreeableness': (convertedScoresMap['agreeableness'] as num?)?.toDouble() ?? 3.0,
        'neuroticism': (convertedScoresMap['neuroticism'] as num?)?.toDouble() ?? 3.0,
      };
    }

    Map<String, double>? axisScores;
    final rawAxisScores = data['axisScores'] as Map<String, dynamic>?;
    if (rawAxisScores != null) {
      axisScores = rawAxisScores.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    return CharacterDetailData(
      favoriteColor: data['favorite_color'] as String?,
      favoritePlace: data['favorite_place'] as String?,
      favoriteWord: data['favorite_word'] as String?,
      wordTendency: data['word_tendency'] as String?,
      strength: data['strength'] as String?,
      weakness: data['weakness'] as String?,
      skill: data['skill'] as String?,
      hobby: data['hobby'] as String?,
      aptitude: data['aptitude'] as String?,
      dream: data['dream'] as String?,
      gender: data['gender'] as String?,
      analysisLevel: (data['analysis_level'] as num?)?.toInt() ?? 0,
      confirmedBig5Scores: scores,
      convertedBig5Scores: convertedScores,
      axisScores: axisScores,
      personalityKey: data['personalityKey'] as String?,
      element: data['element'] as String?,
      typeName: data['typeName'] as String?,
      personalityNarrative: data['personalityNarrative'] as String?,
    );
  }

  String _scoreToLevel(double score) {
    if (score <= 2.0) return 'L';
    if (score <= 3.0) return 'M';
    return 'H';
  }

  /// convertedBig5Scores（新システム）を優先し、なければ confirmedBig5Scores（旧システム）を使用
  String? get personalityImageFileName {
    final s = convertedBig5Scores ?? (analysisLevel > 0 ? confirmedBig5Scores : null);
    if (s == null) return null;

    final o = _scoreToLevel(s['openness'] ?? 3.0);
    final c = _scoreToLevel(s['conscientiousness'] ?? 3.0);
    final e = _scoreToLevel(s['extraversion'] ?? 3.0);
    final a = _scoreToLevel(s['agreeableness'] ?? 3.0);
    final n = _scoreToLevel(s['neuroticism'] ?? 3.0);

    final genderPrefix = gender == '男性' ? 'Male' : 'Female';
    return '${genderPrefix}_$o$c$e$a$n';
  }
}

/// 特定キャラクターの詳細プロバイダー
final characterDetailDataProvider = StreamProvider.family<CharacterDetailData?, String>((ref, characterId) {
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    return Stream.value(null);
  }

  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection('users')
      .doc(userId)
      .collection('characters')
      .doc(characterId)
      .collection('details')
      .doc('current')
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    return CharacterDetailData.fromMap(doc.data()!);
  });
});

/// Big5解析データプロバイダー（Firestoreをリアルタイム監視。生成完了時に自動更新）
final big5AnalysisDataProvider = StreamProvider.family<Big5AnalysisData?, String>((ref, personalityKey) {
  if (personalityKey.isEmpty) return Stream.value(null);

  final firestore = ref.watch(firestoreProvider);

  return firestore.collection('Big5Analysis').doc(personalityKey).snapshots().map((doc) {
    if (!doc.exists || doc.data() == null) return null;

    final data = doc.data()!;
    final analysis100Data = data['analysis_100'] as Map<String, dynamic>?;

    Map<Big5AnalysisCategory, Big5DetailedAnalysis>? analysis100;
    if (analysis100Data != null) {
      analysis100 = {};
      for (final category in Big5AnalysisCategory.values) {
        final categoryData = analysis100Data[category.value] as Map<String, dynamic>?;
        if (categoryData != null) {
          analysis100[category] = Big5DetailedAnalysis.fromMap(categoryData, category);
        }
      }
    }

    return Big5AnalysisData(
      personalityKey: personalityKey,
      analysis100: analysis100,
    );
  });
});

/// iOS版CharacterDetailViewと同じデザインのキャラクター詳細画面
class CharacterDetailScreen extends ConsumerWidget {
  final String characterId;

  const CharacterDetailScreen({
    super.key,
    required this.characterId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(characterDetailDataProvider(characterId));
    final backgroundGradient = ref.watch(backgroundGradientProvider);
    final colorSettings = ref.watch(colorSettingsProvider);
    final textColor = colorSettings.textColor;
    final accentColor = colorSettings.accentColor;
    final shouldShowBannerAd = ref.watch(shouldShowBannerAdProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.history, color: textColor),
          tooltip: '性格変動履歴',
          onPressed: () => context.push('/character/$characterId/personality-history'),
        ),
        title: Text('キャラ詳細', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: textColor),
            tooltip: '元素について',
            onPressed: () => showElementGuideDialog(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: detailAsync.when(
          data: (detail) => detail != null
              ? _CharacterDetailBody(
                  characterId: characterId,
                  detail: detail,
                  textColor: textColor,
                  accentColor: accentColor,
                  shouldShowBannerAd: shouldShowBannerAd,
                )
              : Center(
                  child: Text(
                    'キャラクターが見つかりません',
                    style: TextStyle(color: textColor),
                  ),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: Text(
              'エラー: $e',
              style: TextStyle(color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterDetailBody extends ConsumerWidget {
  final String characterId;
  final CharacterDetailData detail;
  final Color textColor;
  final Color accentColor;
  final bool shouldShowBannerAd;

  const _CharacterDetailBody({
    required this.characterId,
    required this.detail,
    required this.textColor,
    required this.accentColor,
    required this.shouldShowBannerAd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Big5解析データを取得
    final big5AnalysisAsync = detail.personalityKey != null
        ? ref.watch(big5AnalysisDataProvider(detail.personalityKey!))
        : const AsyncValue<Big5AnalysisData?>.data(null);
    final signalCount = ref.watch(signalCountProvider).valueOrNull ?? 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
              SizedBox(height: MediaQuery.of(context).padding.top),

              // 1つ目のバナー広告（キャラクター画像の上）
              if (shouldShowBannerAd)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: BannerAdWidget(adUnitId: AdConfig.characterDetailTopBannerAdUnitId),
                ),

              const SizedBox(height: 16),

              // 性格タイプカード（常に表示。データ収集中/確定済みで切り替わる）
              _PersonalityTypeCard(detail: detail, textColor: textColor),

              const SizedBox(height: 16),

              // キャラクター画像（成長段階）
              _CharacterImage(
                signalCount: signalCount,
                element: detail.element,
                gender: detail.gender,
              ),

              const SizedBox(height: 8),

              // 成長ゲージ
              _GrowthGaugeCard(
                signalCount: signalCount,
                textColor: textColor,
                accentColor: accentColor,
              ),

              const SizedBox(height: 16),

              // Big5解析セクション（30シグナル到達後に表示）
              if (signalCount >= 30 && detail.element != null)
                big5AnalysisAsync.when(
                  data: (analysisData) => _Big5AnalysisSection(
                    textColor: textColor,
                    accentColor: accentColor,
                    analysisData: analysisData,
                  ),
                  loading: () => _Big5AnalysisSection(
                    textColor: textColor,
                    accentColor: accentColor,
                    analysisData: null,
                    isLoading: true,
                  ),
                  error: (_, _s) => _Big5AnalysisSection(
                    textColor: textColor,
                    accentColor: accentColor,
                    analysisData: null,
                  ),
                ),

              // 情報エリア（値がある場合のみ表示）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _InfoRow(label: '好きな色', value: detail.favoriteColor, textColor: textColor),
                    _InfoRow(label: '好きな場所', value: detail.favoritePlace, textColor: textColor),
                    _InfoRow(label: '好きな言葉', value: detail.favoriteWord, textColor: textColor),
                    _InfoRow(label: '言葉の傾向', value: detail.wordTendency, textColor: textColor),
                    _InfoRow(label: '短所', value: detail.weakness, textColor: textColor),
                    _InfoRow(label: '長所', value: detail.strength, textColor: textColor),
                    _InfoRow(label: '特技', value: detail.skill, textColor: textColor),
                    _InfoRow(label: '趣味', value: detail.hobby, textColor: textColor),
                    _InfoRow(label: '適正', value: detail.aptitude, textColor: textColor),
                    _InfoRow(label: '夢', value: detail.dream, textColor: textColor),
                  ],
                ),
              ),

              // 2つ目のバナー広告（性格表示の一番下）
              if (shouldShowBannerAd)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: BannerAdWidget(adUnitId: AdConfig.characterDetailBottomBannerAdUnitId),
                ),

              const SizedBox(height: 16),
            ],
      ),
    );
  }
}

/// キャラクター画像ウィジェット
/// キャラクター成長段階画像ウィジェット
class _CharacterImage extends StatelessWidget {
  final int signalCount;
  final String? element;
  final String? gender;

  const _CharacterImage({
    required this.signalCount,
    required this.element,
    required this.gender,
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
      width: 220,
      height: 220,
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
            width: 180,
            height: 180,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Center(child: Icon(Icons.person, size: 80)),
          ),
        ],
      ),
    );
  }
}

/// 情報行ウィジェット（iOS版infoRowと同じデザイン）
class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Color textColor;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    // 空の値の場合は非表示
    if (value == null || value!.isEmpty || value == '未設定' || value!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Big5解析セクション（element != null の場合）
class _Big5AnalysisSection extends StatelessWidget {
  final Color textColor;
  final Color accentColor;
  final Big5AnalysisData? analysisData;
  final bool isLoading;

  const _Big5AnalysisSection({
    required this.textColor,
    required this.accentColor,
    required this.analysisData,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '✨ 人格解析',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          // 解析カテゴリー一覧
          for (final category in Big5AnalysisCategory.values)
            _AnalysisRow(
              category: category,
              analysis: analysisData?.analysis100?[category],
              textColor: textColor,
              accentColor: accentColor,
              isLoading: isLoading || analysisData?.analysis100?[category] == null,
              onTap: () => _showAnalysisDetail(context, category),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showAnalysisDetail(BuildContext context, Big5AnalysisCategory category) {
    final analysis = analysisData?.analysis100?[category];
    if (analysis == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AnalysisDetailSheet(
        analysis: analysis,
        textColor: textColor,
        accentColor: accentColor,
      ),
    );
  }
}

/// 解析行ウィジェット
class _AnalysisRow extends StatelessWidget {
  final Big5AnalysisCategory category;
  final Big5DetailedAnalysis? analysis;
  final Color textColor;
  final Color accentColor;
  final bool isLoading;
  final VoidCallback onTap;

  const _AnalysisRow({
    required this.category,
    required this.analysis,
    required this.textColor,
    required this.accentColor,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: analysis != null ? onTap : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Text(
              category.icon,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (analysis != null && analysis!.personalityType.isNotEmpty)
                    Text(
                      analysis!.personalityType,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    )
                  else if (isLoading)
                    Text(
                      'AI解析データ生成中...',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.chevron_right,
                size: 16,
                color: textColor.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }
}

/// 解析詳細シート（iOS版Big5AnalysisDetailViewと同じデザイン）
class _AnalysisDetailSheet extends ConsumerWidget {
  final Big5DetailedAnalysis analysis;
  final Color textColor;
  final Color accentColor;

  const _AnalysisDetailSheet({
    required this.analysis,
    required this.textColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundGradient = ref.watch(backgroundGradientProvider);

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          gradient: backgroundGradient,
        ),
        child: SafeArea(
          minimum: const EdgeInsets.only(top: 24),
          child: Column(
          children: [
            // ヘッダー
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '✨ 人格解析',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            // コンテンツ
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // カテゴリーヘッダー
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          analysis.category.icon,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                analysis.category.displayName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                analysis.personalityType,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 詳細解析
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📝 詳細解析',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          analysis.detailedText,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 特徴ポイント
                  if (analysis.keyPoints.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⭐ 特徴ポイント',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...analysis.keyPoints.asMap().entries.map((entry) {
                            final index = entry.key;
                            final point = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      point,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: textColor,
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

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// 成長ゲージカード（0→30: 幼少期まで / 30→100: 大人まで / 100+: 10サイクル）
class _GrowthGaugeCard extends StatelessWidget {
  final int signalCount;
  final Color textColor;
  final Color accentColor;

  const _GrowthGaugeCard({
    required this.signalCount,
    required this.textColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final String label;
    final double progress;
    final String countText;
    final String description;

    if (signalCount >= 100) {
      final cycle = signalCount % 10;
      progress = cycle / 10.0;
      label = '性格解析';
      countText = '$cycle / 10';
      description = 'チャットを続けると性格解析が深まります';
    } else if (signalCount >= 30) {
      progress = signalCount / 100.0;
      label = '大人まで';
      countText = '$signalCount / 100';
      description = 'チャットを続けるとキャラが大人へ成長します';
    } else {
      progress = signalCount / 30.0;
      label = '幼少期まで';
      countText = '$signalCount / 30';
      description = 'チャットを続けると属性が決まり幼少期へ成長します';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Text(
                  countText,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                minHeight: 7,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 性格タイプカード（signalCount >= 30 でタイプ表示、未満でプログレスバー）
class _PersonalityTypeCard extends ConsumerWidget {
  final CharacterDetailData detail;
  final Color textColor;

  const _PersonalityTypeCard({
    required this.detail,
    required this.textColor,
  });

  static const Map<String, Color> _elementColors = {
    '炎': Color(0xFFE53935),
    '水': Color(0xFF1E88E5),
    '風': Color(0xFF43A047),
    '土': Color(0xFF8D6E63),
    '氷': Color(0xFF4FC3F7),
    '雷': Color(0xFFFDD835),
    '光': Color(0xFFFFB300),
    '闇': Color(0xFF6A1B9A),
    '無': Color(0xFF9E9E9E),
  };

  static String _generateDescription(Map<String, double> axisScores, String element) {
    final phrases = <String>[];
    final energy = axisScores['energy'] ?? 0;
    final judgment = axisScores['judgment'] ?? 0;
    final relationship = axisScores['relationship'] ?? 0;
    final lifestyle = axisScores['lifestyle'] ?? 0;
    final processing = axisScores['processing'] ?? 0;

    if (energy > 0.3) {
      phrases.add('外向的で');
    } else if (energy < -0.3) {
      phrases.add('内省的で');
    }

    if (judgment < -0.3) {
      phrases.add('感情豊かな');
    } else if (judgment > 0.3) {
      phrases.add('論理的な');
    }

    if (relationship > 0.3) {
      phrases.add('協調を大切にする');
    } else if (relationship < -0.3) {
      phrases.add('自分軸の強い');
    }

    if (lifestyle > 0.3) {
      phrases.add('計画的な');
    } else if (lifestyle < -0.3) {
      phrases.add('自由奔放な');
    }

    if (processing > 0.3) {
      phrases.add('分析的な');
    } else if (processing < -0.3) {
      phrases.add('直感的な');
    }

    final selected = phrases.take(3).toList();
    if (selected.isEmpty) return '$elementタイプ';
    return '${selected.join('')}$elementタイプ';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalCount = ref.watch(signalCountProvider).valueOrNull ?? 0;
    final hasType = signalCount >= 30 && detail.element != null && detail.typeName != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: hasType ? _buildTypeCard() : _buildProgressCard(signalCount),
    );
  }

  Widget _buildTypeCard() {
    final element = detail.element!;
    final typeName = detail.typeName!;
    final elementColor = _elementColors[element] ?? const Color(0xFF9E9E9E);
    final description = detail.axisScores != null
        ? _generateDescription(detail.axisScores!, element)
        : '$elementタイプ';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: elementColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      typeName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withValues(alpha: 0.8),
                      ),
                    ),
                    if (detail.personalityNarrative != null) ...[
                      Divider(color: textColor.withValues(alpha: 0.2), height: 20),
                      Text(
                        detail.personalityNarrative!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: textColor),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(int signalCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '🔍 性格タイプを解析中',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: signalCount / 30,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9E9E9E)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$signalCount / 30',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'チャットや会議を続けると、あなたの性格タイプが判定されます',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

