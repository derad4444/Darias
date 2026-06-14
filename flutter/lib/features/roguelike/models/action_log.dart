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

  // 上位3特性を返す
  List<MapEntry<String, int>> topTraits() {
    final entries = toMap().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).toList();
  }

  // 冒険中の元素傾向を推定
  String inferredElement() {
    final totals = {
      '炎': challenge + intuition + persistence,
      '水': cooperation + altruism + flexibility,
      '光': logic + planning + caution,
      '闇': caution + curiosity + logic,
      '風': curiosity + flexibility + intuition,
      '土': caution + planning + persistence,
      '雷': challenge + intuition + flexibility,
      '氷': caution + logic + planning,
    };
    final maxVal = totals.values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return '無';
    // 最大値との差が小さい場合は「無」
    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted[0].value - sorted[1].value < 3) return '無';
    return sorted.first.key;
  }
}
