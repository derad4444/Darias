import 'package:cloud_firestore/cloud_firestore.dart';

/// キャラクターの性別
enum CharacterGender {
  male('male'),
  female('female');

  final String value;
  const CharacterGender(this.value);

  static CharacterGender fromString(String value) {
    return CharacterGender.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CharacterGender.male,
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

  const Big5Scores({
    required this.openness,
    required this.conscientiousness,
    required this.extraversion,
    required this.agreeableness,
    required this.neuroticism,
  });

  factory Big5Scores.fromMap(Map<String, dynamic> map) {
    return Big5Scores(
      openness: (map['openness'] as num?)?.toDouble() ?? 0.0,
      conscientiousness: (map['conscientiousness'] as num?)?.toDouble() ?? 0.0,
      extraversion: (map['extraversion'] as num?)?.toDouble() ?? 0.0,
      agreeableness: (map['agreeableness'] as num?)?.toDouble() ?? 0.0,
      neuroticism: (map['neuroticism'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'openness': openness,
      'conscientiousness': conscientiousness,
      'extraversion': extraversion,
      'agreeableness': agreeableness,
      'neuroticism': neuroticism,
    };
  }

  /// personalityKeyを生成（例: "32143"）
  String generatePersonalityKey() {
    int getLevel(double score) {
      if (score >= 4.5) return 5;
      if (score >= 3.5) return 4;
      if (score >= 2.5) return 3;
      if (score >= 1.5) return 2;
      return 1;
    }

    return '${getLevel(openness)}${getLevel(conscientiousness)}${getLevel(extraversion)}${getLevel(agreeableness)}${getLevel(neuroticism)}';
  }
}

/// BIG5特性
enum Big5Trait {
  openness('openness', '経験への開放性', 'O'),
  conscientiousness('conscientiousness', '誠実性', 'C'),
  extraversion('extraversion', '外向性', 'E'),
  agreeableness('agreeableness', '協調性', 'A'),
  neuroticism('neuroticism', '情緒安定性', 'N');

  final String value;
  final String displayName;
  final String shortCode;

  const Big5Trait(this.value, this.displayName, this.shortCode);
}

/// BIG5解析レベル
enum Big5AnalysisLevel {
  basic(20, '基本プログラム解析'),
  detailed(50, '学習進化解析'),
  complete(100, '人格解析');

  final int questionCount;
  final String displayName;

  const Big5AnalysisLevel(this.questionCount, this.displayName);
}

/// BIG5解析カテゴリー
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

/// キャラクターモデル
class CharacterModel {
  final String id;
  final String name;
  final CharacterGender gender;
  final Big5Scores? big5Scores;
  final String? personalityKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CharacterModel({
    required this.id,
    required this.name,
    required this.gender,
    this.big5Scores,
    this.personalityKey,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CharacterModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null');
    }

    return CharacterModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      gender: CharacterGender.fromString(data['gender'] as String? ?? 'male'),
      big5Scores: data['big5Scores'] != null
          ? Big5Scores.fromMap(data['big5Scores'] as Map<String, dynamic>)
          : null,
      personalityKey: data['personalityKey'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'gender': gender.value,
      'big5Scores': big5Scores?.toMap(),
      'personalityKey': personalityKey,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CharacterModel copyWith({
    String? id,
    String? name,
    CharacterGender? gender,
    Big5Scores? big5Scores,
    String? personalityKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CharacterModel(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      big5Scores: big5Scores ?? this.big5Scores,
      personalityKey: personalityKey ?? this.personalityKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
