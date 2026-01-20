/// BIG5特性
enum Big5Trait {
  openness('openness', '経験への開放性', 'O'),
  conscientiousness('conscientiousness', '誠実性', 'C'),
  extraversion('extraversion', '外向性', 'E'),
  agreeableness('agreeableness', '協調性', 'A'),
  neuroticism('neuroticism', '情緒安定性', 'N');

  const Big5Trait(this.value, this.displayName, this.shortCode);
  final String value;
  final String displayName;
  final String shortCode;
}

/// BIG5解析レベル
enum Big5AnalysisLevel {
  basic(20, '基本プログラム解析', '🤖'),
  detailed(50, '学習進化解析', '🧠'),
  complete(100, '人格解析', '👤');

  const Big5AnalysisLevel(this.value, this.displayName, this.icon);
  final int value;
  final String displayName;
  final String icon;

  static Big5AnalysisLevel? fromAnsweredCount(int count) {
    if (count >= 100) return Big5AnalysisLevel.complete;
    if (count >= 50) return Big5AnalysisLevel.detailed;
    if (count >= 20) return Big5AnalysisLevel.basic;
    return null;
  }
}

/// BIG5解析カテゴリー
enum Big5AnalysisCategory {
  career('career', '仕事・キャリアスタイル', '💼'),
  romance('romance', '恋愛・人間関係の特徴', '💕'),
  stress('stress', 'ストレス対処・感情管理', '🧘'),
  learning('learning', '学習・成長アプローチ', '📚'),
  decision('decision', '意思決定・問題解決スタイル', '🎯');

  const Big5AnalysisCategory(this.value, this.displayName, this.icon);
  final String value;
  final String displayName;
  final String icon;
}

/// BIG5質問
class Big5Question {
  final String id;
  final String question;
  final String trait;
  final String direction;

  Big5Question({
    required this.id,
    required this.question,
    this.trait = '',
    this.direction = '',
  });

  factory Big5Question.fromMap(Map<String, dynamic> map) {
    return Big5Question(
      id: map['id'] as String? ?? '',
      question: map['question'] as String? ?? '',
      trait: map['trait'] as String? ?? '',
      direction: map['direction'] as String? ?? '',
    );
  }
}

/// BIG5スコア
class Big5Scores {
  final double openness;
  final double conscientiousness;
  final double extraversion;
  final double agreeableness;
  final double neuroticism;

  Big5Scores({
    required this.openness,
    required this.conscientiousness,
    required this.extraversion,
    required this.agreeableness,
    required this.neuroticism,
  });

  factory Big5Scores.initial() {
    return Big5Scores(
      openness: 3,
      conscientiousness: 3,
      extraversion: 3,
      agreeableness: 3,
      neuroticism: 3,
    );
  }

  factory Big5Scores.fromMap(Map<String, dynamic> map) {
    return Big5Scores(
      openness: (map['openness'] as num?)?.toDouble() ?? 3,
      conscientiousness: (map['conscientiousness'] as num?)?.toDouble() ?? 3,
      extraversion: (map['extraversion'] as num?)?.toDouble() ?? 3,
      agreeableness: (map['agreeableness'] as num?)?.toDouble() ?? 3,
      neuroticism: (map['neuroticism'] as num?)?.toDouble() ?? 3,
    );
  }

  Map<String, double> toMap() {
    return {
      'openness': openness,
      'conscientiousness': conscientiousness,
      'extraversion': extraversion,
      'agreeableness': agreeableness,
      'neuroticism': neuroticism,
    };
  }

  /// パーソナリティキーを生成
  String generatePersonalityKey(String gender) {
    int roundToFiveScale(double score) {
      return score.round().clamp(1, 5);
    }

    final o = roundToFiveScale(openness);
    final c = roundToFiveScale(conscientiousness);
    final e = roundToFiveScale(extraversion);
    final a = roundToFiveScale(agreeableness);
    final n = roundToFiveScale(neuroticism);

    return 'O${o}_C${c}_E${e}_A${a}_N${n}_$gender';
  }
}

/// BIG5詳細解析データ
class Big5DetailedAnalysis {
  final Big5AnalysisCategory category;
  final String personalityType;
  final String detailedText;
  final List<String> keyPoints;
  final Big5AnalysisLevel analysisLevel;

  Big5DetailedAnalysis({
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
              ?.map((e) => e as String)
              .toList() ??
          [],
      analysisLevel: level,
    );
  }
}

/// BIG5解析結果データ
class Big5AnalysisData {
  final String personalityKey;
  final DateTime lastUpdated;
  final Map<Big5AnalysisCategory, Big5DetailedAnalysis>? analysis20;
  final Map<Big5AnalysisCategory, Big5DetailedAnalysis>? analysis50;
  final Map<Big5AnalysisCategory, Big5DetailedAnalysis>? analysis100;

  Big5AnalysisData({
    required this.personalityKey,
    required this.lastUpdated,
    this.analysis20,
    this.analysis50,
    this.analysis100,
  });

  Map<Big5AnalysisCategory, Big5DetailedAnalysis>? getAvailableAnalysis(
    Big5AnalysisLevel level,
  ) {
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

/// BIG5進捗状態
class Big5Progress {
  final int answeredCount;
  final Big5Scores currentScores;
  final Big5Question? currentQuestion;

  Big5Progress({
    required this.answeredCount,
    required this.currentScores,
    this.currentQuestion,
  });

  factory Big5Progress.initial() {
    return Big5Progress(
      answeredCount: 0,
      currentScores: Big5Scores.initial(),
    );
  }

  factory Big5Progress.fromMap(Map<String, dynamic> map) {
    final answeredQuestions = map['answeredQuestions'] as List<dynamic>? ?? [];
    final currentScoresMap = map['currentScores'] as Map<String, dynamic>?;
    final currentQuestionMap = map['currentQuestion'] as Map<String, dynamic>?;

    return Big5Progress(
      answeredCount: answeredQuestions.length,
      currentScores: currentScoresMap != null
          ? Big5Scores.fromMap(currentScoresMap)
          : Big5Scores.initial(),
      currentQuestion: currentQuestionMap != null
          ? Big5Question.fromMap(currentQuestionMap)
          : null,
    );
  }

  Big5AnalysisLevel? get analysisLevel =>
      Big5AnalysisLevel.fromAnsweredCount(answeredCount);
}
