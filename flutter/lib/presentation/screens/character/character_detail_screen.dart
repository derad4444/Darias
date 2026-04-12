import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/firebase_image_service.dart';
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
  final String? personalityKey;

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
    this.personalityKey,
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
      personalityKey: data['personalityKey'] as String?,
    );
  }

  /// スコアをL/M/Hに変換
  String _scoreToLevel(double score) {
    if (score <= 2.0) return 'L';
    if (score <= 3.0) return 'M';
    return 'H';
  }

  /// 性格に基づいた画像ファイル名を生成
  /// 未診断（analysisLevel == 0）の場合はnullを返す（iOS版と同じ挙動）
  String? get personalityImageFileName {
    if (analysisLevel == 0 || confirmedBig5Scores == null) return null;

    final o = _scoreToLevel(confirmedBig5Scores!['openness'] ?? 3.0);
    final c = _scoreToLevel(confirmedBig5Scores!['conscientiousness'] ?? 3.0);
    final e = _scoreToLevel(confirmedBig5Scores!['extraversion'] ?? 3.0);
    final a = _scoreToLevel(confirmedBig5Scores!['agreeableness'] ?? 3.0);
    final n = _scoreToLevel(confirmedBig5Scores!['neuroticism'] ?? 3.0);

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

/// Big5解析データプロバイダー
final big5AnalysisDataProvider = FutureProvider.family<Big5AnalysisData?, String>((ref, personalityKey) async {
  if (personalityKey.isEmpty) return null;

  final firestore = ref.watch(firestoreProvider);

  try {
    final doc = await firestore.collection('Big5Analysis').doc(personalityKey).get();

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
  } catch (e) {
    debugPrint('Failed to fetch Big5 analysis data: $e');
    return null;
  }
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text('キャラ詳細', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: IntrinsicHeight(
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top),

              // 1つ目のバナー広告（キャラクター画像の上）
              if (shouldShowBannerAd)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: BannerAdWidget(adUnitId: AdConfig.characterDetailTopBannerAdUnitId),
                ),

              const SizedBox(height: 16),

              // キャラクター画像
              _CharacterImage(
                imageFileName: detail.personalityImageFileName,
                gender: detail.gender,
              ),

              const SizedBox(height: 16),

              // Big5解析セクション（analysisLevel >= 100の場合のみ）
              if (detail.analysisLevel >= 100)
                big5AnalysisAsync.when(
                  data: (analysisData) => _Big5AnalysisSection(
                    textColor: textColor,
                    accentColor: accentColor,
                    analysisLevel: detail.analysisLevel,
                    analysisData: analysisData,
                  ),
                  loading: () => _Big5AnalysisSection(
                    textColor: textColor,
                    accentColor: accentColor,
                    analysisLevel: detail.analysisLevel,
                    analysisData: null,
                    isLoading: true,
                  ),
                  error: (_, __) => _Big5AnalysisSection(
                    textColor: textColor,
                    accentColor: accentColor,
                    analysisLevel: detail.analysisLevel,
                    analysisData: null,
                  ),
                )
              else if (detail.analysisLevel < 20)
                _AnalysisNotAvailableSection(textColor: textColor),

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

              // コンテンツが少ない場合にバナーを画面下部に押し下げる
              const Spacer(),

              // 2つ目のバナー広告（性格表示の一番下）
              if (shouldShowBannerAd)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: BannerAdWidget(adUnitId: AdConfig.characterDetailBottomBannerAdUnitId),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// キャラクター画像ウィジェット
class _CharacterImage extends StatefulWidget {
  final String? imageFileName;
  final String? gender;

  const _CharacterImage({
    required this.imageFileName,
    required this.gender,
  });

  @override
  State<_CharacterImage> createState() => _CharacterImageState();
}

class _CharacterImageState extends State<_CharacterImage> {
  MemoryImage? _imageProvider;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_CharacterImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageFileName != widget.imageFileName) {
      _loadImage();
    }
  }

  String get _defaultImagePath {
    return widget.gender == '男性'
        ? 'assets/images/android_male.png'
        : 'assets/images/android_female.png';  // genderがnullの場合も女性画像をデフォルト
  }

  Future<void> _loadImage() async {
    // 未診断（imageFileName == null）の場合はローカルのデフォルト画像を表示（iOS版と同じ挙動）
    if (widget.imageFileName == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ファイル名から性別を抽出
      final isMale = widget.imageFileName!.startsWith('Male');
      final gender = isMale
          ? CharacterGender.male
          : CharacterGender.female;

      final imageData = await FirebaseImageService.shared.fetchImage(
        fileName: widget.imageFileName!,
        gender: gender,
      );

      if (mounted) {
        setState(() {
          _imageProvider = MemoryImage(imageData);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load character image: $e');
      if (mounted) {
        setState(() {
          _imageProvider = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 200,
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_imageProvider == null) {
      // 未診断またはFirebase取得失敗時はデフォルト画像を表示（iOS版と同じ挙動）
      return SizedBox(
        width: 200,
        height: 200,
        child: Image.asset(
          _defaultImagePath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const Center(child: Icon(Icons.person, size: 80)),
        ),
      );
    }

    return Image(
      image: _imageProvider!,
      width: 200,
      height: 200,
      fit: BoxFit.contain,
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

/// Big5解析セクション（analysisLevel >= 100の場合）
class _Big5AnalysisSection extends StatelessWidget {
  final Color textColor;
  final Color accentColor;
  final int analysisLevel;
  final Big5AnalysisData? analysisData;
  final bool isLoading;

  const _Big5AnalysisSection({
    required this.textColor,
    required this.accentColor,
    required this.analysisLevel,
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
            child: Row(
              children: [
                Text(
                  '✨ 人格解析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '($analysisLevel/100)',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // 解析カテゴリー一覧
          for (final category in Big5AnalysisCategory.values)
            _AnalysisRow(
              category: category,
              analysis: analysisData?.analysis100?[category],
              textColor: textColor,
              accentColor: accentColor,
              isLoading: isLoading,
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

/// 解析レベルに達していない場合のセクション
class _AnalysisNotAvailableSection extends StatelessWidget {
  final Color textColor;

  const _AnalysisNotAvailableSection({
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🤖 性格解析',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '性格解析を行うには、最低20問のBig5質問に回答してください。\nチャットでキャラクターと会話を続けると、時々性格質問が表示されます。',
              style: TextStyle(
                fontSize: 14,
                color: textColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
