// features/roguelike/models/outcome.dart

import 'dart:math';
import 'action_log.dart';

/// 選択結果の段階。表示色・バッジに使う。
enum OutcomeTier { great, success, failure }

extension OutcomeTierExt on OutcomeTier {
  String get label {
    switch (this) {
      case OutcomeTier.great:   return '大成功！';
      case OutcomeTier.success: return '成功';
      case OutcomeTier.failure: return '失敗';
    }
  }
}

/// 1つの選択肢が取りうる結果（重み付き抽選の1要素）。
/// イベントでも戦闘でも共通で使う。戦闘では damageToEnemy / damageToPlayer を利用する。
class Outcome {
  final OutcomeTier tier;
  final int weight; // 抽選の相対的な重み（大きいほど出やすい）
  final String resultText;
  final Map<String, int> resourceChanges; // hp / food / money / items / bond
  final ActionLog traitDelta;
  final int damageToEnemy; // 戦闘専用
  final int damageToPlayer; // 戦闘専用（このアクション自体の反動。敵の反撃とは別）

  /// この結果で相棒（仲間）が加入する場合の相棒名。null＝加入しない。
  /// 相棒不在時のみ加入が成立し、その時の resourceChanges['bond'] が初期絆になる。
  final String? recruitCompanion;

  /// 地図イベント効果: ランダムな未判明ノードを n 個めくる（地図情報）。
  final int revealCells;

  /// 地図イベント効果: 宝箱ノードを全て判明させる（宝の地図）。
  final bool revealTreasure;

  /// 装備ドロップ: この結果で入手する武器/防具の ID（`Equipments` の id）。
  /// null＝ドロップなし。入手時は「今より強ければ乗り換え」で装備される。
  final String? equipRewardId;

  const Outcome({
    this.tier = OutcomeTier.success,
    this.weight = 1,
    required this.resultText,
    this.resourceChanges = const {},
    this.traitDelta = const ActionLog(),
    this.damageToEnemy = 0,
    this.damageToPlayer = 0,
    this.recruitCompanion,
    this.revealCells = 0,
    this.revealTreasure = false,
    this.equipRewardId,
  });
}

/// 重み付き抽選を行う選択肢が満たす共通インターフェース。
mixin WeightedChoice {
  List<Outcome> get outcomes;

  int get totalWeight => outcomes.fold(0, (sum, o) => sum + o.weight);

  /// 成功率（%）。大成功＋成功の重み割合。失敗結果が無ければ100。
  int get successRate {
    final total = totalWeight;
    if (total <= 0) return 100;
    final ok = outcomes
        .where((o) => o.tier != OutcomeTier.failure)
        .fold(0, (sum, o) => sum + o.weight);
    return (ok * 100 / total).round();
  }

  /// 結果が1通りに確定しているか（確定枠）。
  bool get isGuaranteed => outcomes.length == 1;

  /// 重みに従って結果を1つ抽選する。
  Outcome roll(Random rng) {
    final total = totalWeight;
    if (total <= 0) return outcomes.first;
    var r = rng.nextInt(total);
    for (final o in outcomes) {
      if (r < o.weight) return o;
      r -= o.weight;
    }
    return outcomes.last;
  }
}
