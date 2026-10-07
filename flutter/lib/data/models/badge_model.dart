import '../../core/constants/badges.dart';

/// バッジ診断の状態（`users/{uid}/personalityBadges/current`）
///
/// 書き込みは Cloud Function だけ。アプリは読むだけ（性格のリセット時の削除を除く）。
class BadgeState {
  /// 答えた枠（キーは `r1_energy_a` の形）
  final Set<String> answeredSlots;

  /// 答え直し中のバッジと、答え直しで答えた枠
  final String? retakeBadge;
  final Set<String> retakeAnsweredSlots;

  const BadgeState({
    this.answeredSlots = const {},
    this.retakeBadge,
    this.retakeAnsweredSlots = const {},
  });

  factory BadgeState.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const BadgeState();
    final slots = (data['slots'] as Map<String, dynamic>?) ?? {};
    final retake = data['retake'] as Map<String, dynamic>?;
    final retakeAnswers = (retake?['answers'] as Map<String, dynamic>?) ?? {};
    return BadgeState(
      answeredSlots: slots.keys.toSet(),
      retakeBadge: retake?['badge'] as String?,
      retakeAnsweredSlots: retakeAnswers.keys.toSet(),
    );
  }

  /// そのバッジで答えた質問の数（0〜2）
  int progressOf(String badgeKey) =>
      ['a', 'b'].where((s) => answeredSlots.contains('${badgeKey}_$s')).length;

  bool isBadgeComplete(String badgeKey) => progressOf(badgeKey) >= kQuestionsPerBadge;

  /// その弾で答えた質問の数（0〜10）
  int answeredCountOfRound(int round) =>
      badgesOfRound(round).fold(0, (sum, b) => sum + progressOf(b.key));

  bool isRoundComplete(int round) =>
      answeredCountOfRound(round) >= kBadgeAxes.length * kQuestionsPerBadge;

  /// 答え直し中なら、答え直しで答えた数（0〜1）
  int retakeProgressOf(String badgeKey) => retakeBadge == badgeKey
      ? ['a', 'b'].where((s) => retakeAnsweredSlots.contains('${badgeKey}_$s')).length
      : 0;

  /// 今集めている弾（第1弾が終わったら第2弾）
  int get currentRound => isRoundComplete(1) ? 2 : 1;
}

/// 出す質問
class BadgeQuestion {
  final String questionId;
  final String text;

  /// 「この前の質問、もう一度聞いてもいい？」などの前置き（無ければ空）
  final String prefix;
  final String badgeKey;
  final String badgeName;
  final bool isRetake;

  const BadgeQuestion({
    required this.questionId,
    required this.text,
    required this.prefix,
    required this.badgeKey,
    required this.badgeName,
    required this.isRetake,
  });

  static BadgeQuestion? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final text = m['text'] as String?;
    if (text == null || text.isEmpty) return null;
    return BadgeQuestion(
      questionId: m['questionId'] as String? ?? '',
      text: text,
      prefix: m['prefix'] as String? ?? '',
      badgeKey: m['badgeKey'] as String? ?? '',
      badgeName: m['badgeName'] as String? ?? '',
      isRetake: m['isRetake'] as bool? ?? false,
    );
  }

  /// 吹き出しに出す文
  String get displayText => prefix.isEmpty ? text : '$prefix\n$text';
}

/// 返答と一緒に返ってくるバッジの結果
class BadgeTurnResult {
  /// 今回の発言で採点が確定したバッジ（無ければ null）
  final String? earnedBadgeKey;
  final int earnedProgress;
  final bool earnedIsRetake;

  /// 続けて出す次の質問
  final BadgeQuestion? nextQuestion;

  /// 今回の発言で診断が走ったか
  final bool diagnosed;

  const BadgeTurnResult({
    this.earnedBadgeKey,
    this.earnedProgress = 0,
    this.earnedIsRetake = false,
    this.nextQuestion,
    this.diagnosed = false,
  });

  static BadgeTurnResult? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final earned = m['earned'] is Map ? Map<String, dynamic>.from(m['earned'] as Map) : null;
    return BadgeTurnResult(
      earnedBadgeKey: earned?['badgeKey'] as String?,
      earnedProgress: (earned?['progress'] as num?)?.toInt() ?? 0,
      earnedIsRetake: earned?['isRetake'] as bool? ?? false,
      nextQuestion: BadgeQuestion.fromMap(m['nextQuestion']),
      diagnosed: m['diagnosed'] as bool? ?? false,
    );
  }
}
