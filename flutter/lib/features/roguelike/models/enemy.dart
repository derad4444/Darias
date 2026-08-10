// features/roguelike/models/enemy.dart

import 'game_state.dart';
import 'action_log.dart';
import 'outcome.dart';

/// 敵（悩み）ごとの性質。HP以外の個性を表す。
enum EnemyTrait {
  interpersonal, // 対人関係の悩み: 反撃で絆を削る
  futureAnxiety, // 将来不安: 反撃で食料/金を奪い、長引くほど強くなる
  selfDenial,    // 自己否定: 反撃で選択肢を封じる。逃げると悪化
  boss,          // 最終ダンジョンの守護者: 強烈な反撃＋長期戦で強化
  generic,       // ザコ（もやもや等）: 個性の薄い小さな障害
}

class BattleChoice with WeightedChoice {
  final String label;

  /// 選ぶ前に表示する短いヒント。
  final String riskHint;

  /// 選んだ瞬間に確定で支払うコスト（例: {'items': -1}）。
  final Map<String, int> upfrontCost;

  /// この選択を「選んだ」こと自体が示す判断傾向。成功/失敗・逃走可否に関わらず加算される。
  final ActionLog selectTrait;

  /// 重み付きで抽選される結果。damageToEnemy / damageToPlayer / resourceChanges を持つ。
  @override
  final List<Outcome> outcomes;

  /// 逃走アクションか（成功で戦闘離脱、敵によっては悪化）。
  final bool isFlee;

  final GrowthStage minStage;

  /// この選択肢は相棒（仲間）がいる時だけ出す。不在時は非表示。
  final bool requiresCompanion;

  /// この選択肢は回復薬を消費する。所持0の時は非表示。
  final bool requiresItem;

  /// この選択肢は1回の戦闘で1度だけ使える（使うとその戦闘中は非表示）。
  /// ボス特効のような強力な一手向け。
  final bool oncePerBattle;

  const BattleChoice({
    required this.label,
    this.riskHint = '',
    this.upfrontCost = const {},
    this.selectTrait = const ActionLog(),
    this.outcomes = const [],
    this.isFlee = false,
    this.minStage = GrowthStage.baby,
    this.requiresCompanion = false,
    this.requiresItem = false,
    this.oncePerBattle = false,
  });

  /// この選択肢が与えうる最大ダメージ（封じ対象を選ぶのに使う）。
  int get maxDamage =>
      outcomes.fold(0, (m, o) => o.damageToEnemy > m ? o.damageToEnemy : m);
}

class Enemy {
  final String id;
  final String name;
  final String description;
  final String nextAction; // 敵が次にすること（表示用）
  final int maxHp;
  final int currentHp;
  final List<BattleChoice> choices;
  final EnemyTrait trait;

  /// 敵の元素（単漢字。'炎''水''風''土''氷''雷''光''闇''無'）。
  /// プレイヤー（本編キャラ）の元素との相性で戦闘の有利/不利が決まる。
  final String element;

  /// ダンジョンのボス（悩み本体）か。撃破＝そのダンジョンのクリア（悩みの克服）。
  final bool isBoss;

  /// 反撃の基礎HPダメージ。
  final int counterBaseDamage;

  /// 反撃時に削るリソース（例: {'bond': -1} / {'food': -1, 'money': -1}）。
  final Map<String, int> counterDrain;

  /// 長引くほど反撃が強くなるか（経過ターン分ダメージ加算）。
  final bool escalates;

  /// 逃げると悪化するか（敵が回復し戦闘継続）。
  final bool fleeWorsens;

  /// 撃破時に得られる報酬（悩みを乗り越えた見返り）。
  /// 例: {'money': 3, 'items': 1} / {'maxHp': 3}（maxHp はその分回復もする）。
  final Map<String, int> defeatReward;

  /// 撃破時に表示する一言（テーマに沿った描写）。
  final String defeatRewardText;

  const Enemy({
    required this.id,
    required this.name,
    required this.description,
    required this.nextAction,
    required this.maxHp,
    required this.currentHp,
    required this.choices,
    this.trait = EnemyTrait.generic,
    this.element = '無',
    this.isBoss = false,
    this.counterBaseDamage = 3,
    this.counterDrain = const {},
    this.escalates = false,
    this.fleeWorsens = false,
    this.defeatReward = const {},
    this.defeatRewardText = '',
  });

  Enemy copyWith({int? currentHp}) => Enemy(
    id: id,
    name: name,
    description: description,
    nextAction: nextAction,
    maxHp: maxHp,
    currentHp: currentHp ?? this.currentHp,
    choices: choices,
    trait: trait,
    element: element,
    isBoss: isBoss,
    counterBaseDamage: counterBaseDamage,
    counterDrain: counterDrain,
    escalates: escalates,
    fleeWorsens: fleeWorsens,
    defeatReward: defeatReward,
    defeatRewardText: defeatRewardText,
  );

  bool get isDefeated => currentHp <= 0;

  /// 経過ターンを踏まえた反撃ダメージ。
  int counterDamage(int battleTurns) =>
      counterBaseDamage + (escalates ? battleTurns : 0);
}

class Enemies {
  static List<BattleChoice> forStage(List<BattleChoice> all, GrowthStage stage) =>
      all.where((c) => c.minStage.index <= stage.index).toList();

  // --- 共通の選択肢部品（ボス・ザコで再利用） ---

  /// 回復薬を使う（全戦闘共通・所持時のみ表示）。
  static BattleChoice get healChoice => const BattleChoice(
        label: '回復薬を使う',
        riskHint: '確定・HP回復',
        upfrontCost: {'items': -1},
        requiresItem: true,
        selectTrait: ActionLog(caution: 1, planning: 1),
        outcomes: [
          Outcome(
            tier: OutcomeTier.success,
            weight: 1,
            resultText: '回復薬を飲み、傷を癒した。落ち着いて立て直せた。',
            resourceChanges: {'hp': 12},
          ),
        ],
      );

  /// 逃げる。
  static BattleChoice get fleeChoice => const BattleChoice(
        label: '逃げる',
        riskHint: '離脱を試みる',
        isFlee: true,
        // 引くのも判断。柔軟性は供給が少なく水・風・雷が伸びないため厚くする。
        selectTrait: ActionLog(flexibility: 2),
      );

  /// ザコ（もやもや・断片）共通の選択肢。dmg で強さを調整。
  static List<BattleChoice> mobChoices({int dmg = 6}) => [
        BattleChoice(
          label: '立ち向かう',
          riskHint: '当たり外れあり',
          // 挑戦性だけだと炎と雷が区別できないため直感性を足す。
          selectTrait: const ActionLog(challenge: 1, intuition: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 70,
              resultText: '正面から向き合い、振り払った。',
              damageToEnemy: dmg, damageToPlayer: 3,
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 30,
              resultText: 'うまく振り払えず、少し消耗した。',
              damageToEnemy: (dmg / 2).round(), damageToPlayer: 5,
              traitDelta: const ActionLog(caution: 1),
            ),
          ],
        ),
        fleeChoice,
        BattleChoice(
          label: '観察していなす',
          riskHint: '安定・低リスク（幼少〜）',
          minStage: GrowthStage.young,
          // 論理性＋慎重性は闇に二重で入り独走の主因だったため好奇心へ。
          selectTrait: const ActionLog(logic: 1, curiosity: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: '落ち着いて見極め、うまくいなした。',
              damageToEnemy: dmg - 3, damageToPlayer: 2,
            ),
          ],
        ),
        healChoice,
      ];

  /// 全ダンジョン共通の「もやもや／雑念」ザコ。
  static final List<Enemy> commonMobs = [
    Enemy(
      id: 'haze',
      name: 'もやもや',
      description: '名前のつかない、とりとめのない心のざわつき。',
      nextAction: 'まとわりついて気を散らす',
      maxHp: 9, currentHp: 9,
      counterBaseDamage: 2,
      choices: mobChoices(dmg: 6),
      defeatReward: {'money': 1},
      defeatRewardText: 'もやもやが晴れ、少し頭が軽くなった。',
    ),
    Enemy(
      id: 'small_unease',
      name: 'ささいな不安',
      description: '気にするほどではないのに、ふと胸をよぎる小さな不安。',
      nextAction: 'ちくちくと胸を刺す',
      maxHp: 8, currentHp: 8,
      counterBaseDamage: 2,
      choices: mobChoices(dmg: 6),
      defeatReward: {'money': 1},
      defeatRewardText: '小さな不安をやり過ごせた。',
    ),
    Enemy(
      id: 'idle_thoughts',
      name: 'とりとめのない雑念',
      description: '次から次へと湧いては消える、まとまらない考えの群れ。',
      nextAction: '思考をかき乱す',
      maxHp: 10, currentHp: 10,
      counterBaseDamage: 2,
      choices: mobChoices(dmg: 7),
      defeatReward: {'items': 1},
      defeatRewardText: '雑念が静まり、頭の中が整理された。',
    ),
  ];
}
