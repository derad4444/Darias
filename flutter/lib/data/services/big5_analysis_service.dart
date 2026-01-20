import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// BIG5分析レベル
enum Big5AnalysisLevel {
  basic, // 20問
  detailed, // 50問
  complete, // 100問
}

/// BIG5分析カテゴリ
enum Big5AnalysisCategory {
  career('career', 'キャリア・仕事'),
  romance('romance', '恋愛・パートナーシップ'),
  stress('stress', 'ストレス対処'),
  communication('communication', 'コミュニケーション'),
  growth('growth', '自己成長');

  final String rawValue;
  final String displayName;

  const Big5AnalysisCategory(this.rawValue, this.displayName);
}

/// BIG5スコア
class Big5Scores {
  final double openness;
  final double conscientiousness;
  final double extraversion;
  final double agreeableness;
  final double neuroticism;

  const Big5Scores({
    required this.openness,
    required this.conscientiousness,
    required this.extraversion,
    required this.agreeableness,
    required this.neuroticism,
  });

  factory Big5Scores.fromMap(Map<String, dynamic> map) {
    return Big5Scores(
      openness: (map['openness'] as num?)?.toDouble() ?? 0,
      conscientiousness: (map['conscientiousness'] as num?)?.toDouble() ?? 0,
      extraversion: (map['extraversion'] as num?)?.toDouble() ?? 0,
      agreeableness: (map['agreeableness'] as num?)?.toDouble() ?? 0,
      neuroticism: (map['neuroticism'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'openness': openness,
        'conscientiousness': conscientiousness,
        'extraversion': extraversion,
        'agreeableness': agreeableness,
        'neuroticism': neuroticism,
      };
}

/// 詳細分析
class Big5DetailedAnalysis {
  final Big5AnalysisCategory category;
  final String personalityType;
  final String detailedText;
  final List<String> keyPoints;
  final Big5AnalysisLevel analysisLevel;

  const Big5DetailedAnalysis({
    required this.category,
    required this.personalityType,
    required this.detailedText,
    required this.keyPoints,
    required this.analysisLevel,
  });

  factory Big5DetailedAnalysis.fromMap(
    Map<String, dynamic> map,
    Big5AnalysisCategory category,
    Big5AnalysisLevel level,
  ) {
    return Big5DetailedAnalysis(
      category: category,
      personalityType: map['personality_type'] as String? ?? '',
      detailedText: map['detailed_text'] as String? ?? '',
      keyPoints: (map['key_points'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      analysisLevel: level,
    );
  }
}

/// BIG5分析データ
class Big5AnalysisData {
  final String personalityKey;
  final DateTime lastUpdated;
  final Map<Big5AnalysisCategory, Big5DetailedAnalysis>? analysis20;
  final Map<Big5AnalysisCategory, Big5DetailedAnalysis>? analysis50;
  final Map<Big5AnalysisCategory, Big5DetailedAnalysis>? analysis100;

  const Big5AnalysisData({
    required this.personalityKey,
    required this.lastUpdated,
    this.analysis20,
    this.analysis50,
    this.analysis100,
  });

  /// 指定レベルの分析を取得
  Map<Big5AnalysisCategory, Big5DetailedAnalysis>? getAnalysis(
      Big5AnalysisLevel level) {
    switch (level) {
      case Big5AnalysisLevel.basic:
        return analysis20;
      case Big5AnalysisLevel.detailed:
        return analysis50;
      case Big5AnalysisLevel.complete:
        return analysis100;
    }
  }
}

/// BIG5分析キャッシュ
class Big5AnalysisCache {
  static final Big5AnalysisCache shared = Big5AnalysisCache._();
  Big5AnalysisCache._();

  final Map<String, Big5AnalysisData> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiration = Duration(hours: 24);

  Big5AnalysisData? getCachedAnalysis(String personalityKey) {
    final timestamp = _cacheTimestamps[personalityKey];
    if (timestamp != null) {
      if (DateTime.now().difference(timestamp) > _cacheExpiration) {
        _cache.remove(personalityKey);
        _cacheTimestamps.remove(personalityKey);
        return null;
      }
    }
    return _cache[personalityKey];
  }

  void cacheAnalysis(String key, Big5AnalysisData data) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }
}

/// BIG5分析サービス
class Big5AnalysisService {
  final FirebaseFirestore _db;
  final Big5AnalysisCache _cache = Big5AnalysisCache.shared;

  Big5AnalysisService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// パーソナリティキーを生成
  String generatePersonalityKey(Big5Scores scores, String gender) {
    final o = _roundToFiveScale(scores.openness);
    final c = _roundToFiveScale(scores.conscientiousness);
    final e = _roundToFiveScale(scores.extraversion);
    final a = _roundToFiveScale(scores.agreeableness);
    final n = _roundToFiveScale(scores.neuroticism);

    return 'O${o}_C${c}_E${e}_A${a}_N${n}_$gender';
  }

  int _roundToFiveScale(double score) {
    return (score.round()).clamp(1, 5);
  }

  /// 分析データを取得
  Future<Big5AnalysisData> fetchAnalysisData(String personalityKey) async {
    // キャッシュから取得を試行
    final cachedData = _cache.getCachedAnalysis(personalityKey);
    if (cachedData != null) {
      return cachedData;
    }

    final doc =
        await _db.collection('Big5Analysis').doc(personalityKey).get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('解析データがまだ生成されていません');
    }

    final data = doc.data()!;
    final analysisData = _parseAnalysisData(data, personalityKey);
    _cache.cacheAnalysis(personalityKey, analysisData);

    return analysisData;
  }

  /// キャラクターの分析データを取得
  Future<Big5AnalysisData> fetchCharacterAnalysis(
    String characterId,
    String userId,
  ) async {
    final detailsDoc = await _db
        .collection('users')
        .doc(userId)
        .collection('characters')
        .doc(characterId)
        .collection('details')
        .doc('current')
        .get();

    if (!detailsDoc.exists || detailsDoc.data() == null) {
      throw Exception('キャラクター詳細が見つかりませんでした');
    }

    final personalityKey = detailsDoc.data()!['personalityKey'] as String?;
    if (personalityKey == null) {
      throw Exception('personalityKeyが設定されていません');
    }

    return fetchAnalysisData(personalityKey);
  }

  /// 回答数から分析レベルを決定
  Big5AnalysisLevel? determineAnalysisLevel(int answeredCount) {
    if (answeredCount >= 100) {
      return Big5AnalysisLevel.complete;
    } else if (answeredCount >= 50) {
      return Big5AnalysisLevel.detailed;
    } else if (answeredCount >= 20) {
      return Big5AnalysisLevel.basic;
    }
    return null;
  }

  /// レベルで利用可能なカテゴリを取得
  List<Big5AnalysisCategory> getAvailableCategories(Big5AnalysisLevel level) {
    switch (level) {
      case Big5AnalysisLevel.basic:
        return [
          Big5AnalysisCategory.career,
          Big5AnalysisCategory.romance,
          Big5AnalysisCategory.stress,
        ];
      case Big5AnalysisLevel.detailed:
      case Big5AnalysisLevel.complete:
        return Big5AnalysisCategory.values.toList();
    }
  }

  Big5AnalysisData _parseAnalysisData(
    Map<String, dynamic> data,
    String personalityKey,
  ) {
    final lastUpdated =
        (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Big5AnalysisData(
      personalityKey: personalityKey,
      lastUpdated: lastUpdated,
      analysis20: _parseAnalysisLevel(data, 'analysis_20', Big5AnalysisLevel.basic),
      analysis50: _parseAnalysisLevel(data, 'analysis_50', Big5AnalysisLevel.detailed),
      analysis100: _parseAnalysisLevel(data, 'analysis_100', Big5AnalysisLevel.complete),
    );
  }

  Map<Big5AnalysisCategory, Big5DetailedAnalysis>? _parseAnalysisLevel(
    Map<String, dynamic> data,
    String levelKey,
    Big5AnalysisLevel level,
  ) {
    final levelData = data[levelKey] as Map<String, dynamic>?;
    if (levelData == null) return null;

    final result = <Big5AnalysisCategory, Big5DetailedAnalysis>{};

    for (final category in Big5AnalysisCategory.values) {
      final categoryData = levelData[category.rawValue] as Map<String, dynamic>?;
      if (categoryData != null) {
        result[category] = Big5DetailedAnalysis.fromMap(
          categoryData,
          category,
          level,
        );
      }
    }

    return result.isEmpty ? null : result;
  }

  /// AI分析データを生成（Cloud Functions呼び出し）
  Future<Big5AnalysisData> generateAnalysisData(
    String personalityKey, {
    bool isPremium = false,
  }) async {
    final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');
    final callable = functions.httpsCallable('generateBig5Analysis');

    final result = await callable.call({
      'personalityKey': personalityKey,
      'isPremium': isPremium,
    });

    final data = result.data as Map<String, dynamic>;
    final analysisData = _parseAnalysisData(data, personalityKey);
    _cache.cacheAnalysis(personalityKey, analysisData);

    return analysisData;
  }
}

/// プロバイダー
final big5AnalysisServiceProvider = Provider<Big5AnalysisService>((ref) {
  return Big5AnalysisService();
});

final big5AnalysisCacheProvider = Provider<Big5AnalysisCache>((ref) {
  return Big5AnalysisCache.shared;
});
