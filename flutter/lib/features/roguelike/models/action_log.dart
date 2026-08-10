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

  // 冒険中の元素傾向を推定
  String inferredElement() {
    final totals = elementScores();
    final maxVal = totals.values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return '無';
    // 1位と2位が同点なら「無」。
    //
    // 8元素は特性を共有している（例: 炎と雷は挑戦性・直感性が共通で、
    // 差がつくのは執着性 vs 柔軟性だけ）ため、差は構造的に開きにくい。
    // かつて閾値が3だったときは「無」が26〜54%を占め、
    // 実際には強い傾向が3つあるのに「型なし」と診断されていた。
    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted[0].value - sorted[1].value < 1) return '無';
    return sorted.first.key;
  }

  /// 推定元素の「強さ傾向」ラベル（強い傾向／やや強い傾向）。「無」なら空。
  String elementStrengthLabel() {
    if (inferredElement() == '無') return '';
    final sorted = elementScores().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final margin = sorted[0].value - sorted[1].value;
    return margin >= 8 ? '強い傾向' : 'やや強い傾向';
  }
}
