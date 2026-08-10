// features/roguelike/models/action_log.dart

class ActionLog {
  final int challenge;    // 挑戦性
  final int caution;      // 慎重性
  final int curiosity;    // 好奇心
  final int planning;     // 計画性
  final int intuition;    // 直感性
  final int logic;        // 論理性
  final int cooperation;  // 協調性
  final int altruism;     // 利他性
  final int persistence;  // 執着性
  final int flexibility;  // 柔軟性

  const ActionLog({
    this.challenge = 0,
    this.caution = 0,
    this.curiosity = 0,
    this.planning = 0,
    this.intuition = 0,
    this.logic = 0,
    this.cooperation = 0,
    this.altruism = 0,
    this.persistence = 0,
    this.flexibility = 0,
  });

  ActionLog copyWith({
    int? challenge,
    int? caution,
    int? curiosity,
    int? planning,
    int? intuition,
    int? logic,
    int? cooperation,
    int? altruism,
    int? persistence,
    int? flexibility,
  }) {
    return ActionLog(
      challenge: (this.challenge + (challenge ?? 0)).clamp(0, 999),
      caution: (this.caution + (caution ?? 0)).clamp(0, 999),
      curiosity: (this.curiosity + (curiosity ?? 0)).clamp(0, 999),
      planning: (this.planning + (planning ?? 0)).clamp(0, 999),
      intuition: (this.intuition + (intuition ?? 0)).clamp(0, 999),
      logic: (this.logic + (logic ?? 0)).clamp(0, 999),
      cooperation: (this.cooperation + (cooperation ?? 0)).clamp(0, 999),
      altruism: (this.altruism + (altruism ?? 0)).clamp(0, 999),
      persistence: (this.persistence + (persistence ?? 0)).clamp(0, 999),
      flexibility: (this.flexibility + (flexibility ?? 0)).clamp(0, 999),
    );
  }

  Map<String, int> toMap() => {
    '挑戦性': challenge,
    '慎重性': caution,
    '好奇心': curiosity,
    '計画性': planning,
    '直感性': intuition,
    '論理性': logic,
    '協調性': cooperation,
    '利他性': altruism,
    '執着性': persistence,
    '柔軟性': flexibility,
  };

  /// toMap() のキー（日本語特性名）から ActionLog を復元する。
  /// 保存済み run の `traits` マップの合算などに使う。
  factory ActionLog.fromMap(Map<String, int> m) => ActionLog(
        challenge: m['挑戦性'] ?? 0,
        caution: m['慎重性'] ?? 0,
        curiosity: m['好奇心'] ?? 0,
        planning: m['計画性'] ?? 0,
        intuition: m['直感性'] ?? 0,
        logic: m['論理性'] ?? 0,
        cooperation: m['協調性'] ?? 0,
        altruism: m['利他性'] ?? 0,
        persistence: m['執着性'] ?? 0,
        flexibility: m['柔軟性'] ?? 0,
      );

  // 上位3特性を返す
  List<MapEntry<String, int>> topTraits() {
    final entries = toMap().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).toList();
  }

  // 8元素のスコア（それぞれ異なる3特性の組み合わせ）。
  // 光⇔闇・雷⇔氷は外向/内向の鏡として差別化する。
  Map<String, int> elementScores() => {
    '炎': challenge + intuition + persistence,   // 衝動・前進
    '水': altruism + cooperation + flexibility,  // 受容・つながり
    '風': curiosity + flexibility + intuition,   // 自由・変化
    '土': caution + planning + persistence,      // 堅実・継続
    '雷': challenge + intuition + flexibility,   // 外向の瞬発（直感を外へ放つ）
    // 氷は本編（axisCalculator.js）で「内向・論理重視・直感」と定義されている。
    // 執着性だと炎・土と全特性が重なって埋もれるため、本編に合わせて論理性を持たせる。
    '氷': caution + intuition + logic,           // 内向の瞬発（直感を内に止める）
    '光': logic + planning + cooperation,        // 外向の理性（理性を他者へ向ける）
    '闇': logic + curiosity + caution,           // 内向の理性（理性を内へ向ける）
  };

  /// 特性の合計値（元素スコアを冒険の長さで正規化するために使う）。
  int get totalPoints =>
      challenge + caution + curiosity + planning + intuition +
      logic + cooperation + altruism + persistence + flexibility;

  /// 平均的な冒険での「元素スコア ÷ 特性合計」。
  ///
  /// 素点をそのまま比べると、**イベントで付きやすい特性を持つ元素が有利**になる
  /// （論理性・慎重性の供給が多く、闇が独走していた）。プレイヤーの選択と無関係な
  /// この偏りを打ち消すため、期待比率で割って「平均よりどれだけ突出したか」で比べる。
  static const Map<String, double> _elementBaseline = {
    '炎': 0.2713, '水': 0.2798, '風': 0.3338, '土': 0.2887,
    '雷': 0.3399, '氷': 0.3315, '光': 0.3132, '闇': 0.3357,
  };

  /// 元素ごとの出やすさの補正係数。
  ///
  /// 期待比率で割ってもまだ偏る。**元素どうしの相関**が理由で、
  /// 水は利他性を独占するため他と競合せず勝ちやすく、逆に雷は炎・風と
  /// 特性を食い合って勝ちにくい。この構造的な有利不利を打ち消す係数。
  ///
  /// **イベントの `selectTrait` 配分を変えたら再計算が必要**
  /// （算出方法はローグライク冒険ゲーム仕様書 §7.2 を参照）。
  static const Map<String, double> _elementCalibration = {
    '炎': 0.9413, '水': 0.8993, '風': 1.0339, '土': 0.9433,
    '雷': 1.0426, '氷': 1.0947, '光': 1.0198, '闇': 1.0251,
  };

  /// 正規化した元素スコア（値が大きいほど、平均的な冒険より突出している）。
  Map<String, double> normalizedElementScores() {
    final total = totalPoints;
    if (total == 0) return {for (final e in _elementBaseline.keys) e: 0.0};
    return {
      for (final entry in elementScores().entries)
        entry.key: (entry.value / total / _elementBaseline[entry.key]!) *
            _elementCalibration[entry.key]!,
    };
  }

  // 冒険中の元素傾向を推定
  String inferredElement() {
    if (totalPoints == 0) return '無';
    final sorted = normalizedElementScores().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // 1位と2位が拮抗していれば「無」（傾向が割れている）。
    if (sorted[0].value - sorted[1].value < 0.04) return '無';
    return sorted.first.key;
  }

  /// 推定元素の「強さ傾向」ラベル（強い傾向／やや強い傾向）。「無」なら空。
  String elementStrengthLabel() {
    if (inferredElement() == '無') return '';
    final sorted = normalizedElementScores().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted[0].value - sorted[1].value >= 0.15 ? '強い傾向' : 'やや強い傾向';
  }
}
