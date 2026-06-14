// features/roguelike/models/enemy.dart

import 'game_state.dart';
import 'action_log.dart';

class BattleChoice {
  final String label;
  final String resultText;
  final int damageToEnemy;
  final int damageToPlayer;
  final Map<String, int> resourceChanges;
  final ActionLog traitDelta;
  final GrowthStage minStage;

  const BattleChoice({
    required this.label,
    required this.resultText,
    this.damageToEnemy = 0,
    this.damageToPlayer = 0,
    this.resourceChanges = const {},
    this.traitDelta = const ActionLog(),
    this.minStage = GrowthStage.baby,
  });
}

class Enemy {
  final String id;
  final String name;
  final String description;
  final String nextAction; // 敵が次にすること（表示用）
  final int maxHp;
  final int currentHp;
  final List<BattleChoice> choices;

  const Enemy({
    required this.id,
    required this.name,
    required this.description,
    required this.nextAction,
    required this.maxHp,
    required this.currentHp,
    required this.choices,
  });

  Enemy copyWith({int? currentHp}) => Enemy(
    id: id,
    name: name,
    description: description,
    nextAction: nextAction,
    maxHp: maxHp,
    currentHp: currentHp ?? this.currentHp,
    choices: choices,
  );

  bool get isDefeated => currentHp <= 0;
}

class Enemies {
  static List<BattleChoice> forStage(List<BattleChoice> all, GrowthStage stage) =>
      all.where((c) => c.minStage.index <= stage.index).toList();

  static final List<Enemy> all = [
    Enemy(
      id: 'interpersonal',
      name: '対人関係の悩み',
      description: '人との関わりから生まれた複雑な感情のかたまり。\n次のターン、不安を増幅させようとしている。',
      nextAction: '「どうせ嫌われている」と囁く',
      maxHp: 20,
      currentHp: 20,
      choices: [
        BattleChoice(
          label: '正面から向き合う',
          resultText: '真剣に向き合うことで、悩みの核心が見えてきた。ダメージを与えた。',
          damageToEnemy: 8,
          damageToPlayer: 5,
          traitDelta: ActionLog(challenge: 2, persistence: 1),
        ),
        BattleChoice(
          label: '逃げる',
          resultText: '今は無理と判断して距離を置いた。',
          damageToEnemy: 0,
          damageToPlayer: 0,
          resourceChanges: {'food': -1},
          traitDelta: ActionLog(flexibility: 1),
        ),
        BattleChoice(
          label: '観察する',
          resultText: '悩みのパターンを観察した。次の行動に活かせそうだ。ダメージを与えた。',
          damageToEnemy: 6,
          damageToPlayer: 2,
          traitDelta: ActionLog(logic: 2, caution: 1),
          minStage: GrowthStage.young,
        ),
        BattleChoice(
          label: 'アイテムを使う',
          resultText: 'アイテムを使い、気持ちを整理した。大きなダメージを与えた。',
          damageToEnemy: 12,
          damageToPlayer: 0,
          resourceChanges: {'items': -1},
          traitDelta: ActionLog(planning: 2),
          minStage: GrowthStage.young,
        ),
        BattleChoice(
          label: '仲間に相談する',
          resultText: '仲間の視点でアドバイスをもらった。一緒に解決策を見つけた。',
          damageToEnemy: 10,
          damageToPlayer: 0,
          resourceChanges: {'bond': -1},
          traitDelta: ActionLog(cooperation: 3, altruism: 1),
          minStage: GrowthStage.adult,
        ),
        BattleChoice(
          label: '交渉して距離を縮める',
          resultText: '相手の立場を理解しようとした。悩みが少し和らいだ。',
          damageToEnemy: 15,
          damageToPlayer: 0,
          resourceChanges: {'money': -2},
          traitDelta: ActionLog(flexibility: 2, cooperation: 2),
          minStage: GrowthStage.adult,
        ),
      ],
    ),

    Enemy(
      id: 'future_anxiety',
      name: '将来不安',
      description: '見えない未来への漠然とした恐れ。\n次のターン、行動力を奪おうとしている。',
      nextAction: '「先が見えない」と霧を広げる',
      maxHp: 18,
      currentHp: 18,
      choices: [
        BattleChoice(
          label: '正面から向き合う',
          resultText: '不安を直視した。怖かったが、少し楽になった。',
          damageToEnemy: 7,
          damageToPlayer: 6,
          traitDelta: ActionLog(challenge: 3, persistence: 1),
        ),
        BattleChoice(
          label: '逃げる',
          resultText: '今は考えるのをやめた。',
          damageToEnemy: 0,
          damageToPlayer: 0,
          resourceChanges: {'food': -1},
          traitDelta: ActionLog(flexibility: 1),
        ),
        BattleChoice(
          label: '小さな目標を立てる',
          resultText: '遠い未来ではなく、今できることに集中した。不安が薄れた。',
          damageToEnemy: 10,
          damageToPlayer: 0,
          traitDelta: ActionLog(planning: 3, logic: 1),
          minStage: GrowthStage.young,
        ),
        BattleChoice(
          label: '仲間に話す',
          resultText: '話すと気持ちが整理された。仲間も同じ不安を持っていた。',
          damageToEnemy: 8,
          damageToPlayer: 0,
          resourceChanges: {'bond': 1},
          traitDelta: ActionLog(cooperation: 2, altruism: 1),
          minStage: GrowthStage.adult,
        ),
      ],
    ),

    Enemy(
      id: 'self_denial',
      name: '自己否定',
      description: '自分の中から湧き上がる否定の声。\n次のターン、自信を削ろうとしている。',
      nextAction: '「お前には無理だ」と囁く',
      maxHp: 22,
      currentHp: 22,
      choices: [
        BattleChoice(
          label: '自分を信じて攻撃する',
          resultText: '「できる」と自分に言い聞かせて立ち向かった。',
          damageToEnemy: 9,
          damageToPlayer: 7,
          traitDelta: ActionLog(challenge: 3, persistence: 2),
        ),
        BattleChoice(
          label: '逃げる',
          resultText: '今日は引く日と決めた。',
          damageToEnemy: 0,
          damageToPlayer: 0,
          resourceChanges: {'food': -1},
          traitDelta: ActionLog(flexibility: 1, caution: 1),
        ),
        BattleChoice(
          label: '客観的に分析する',
          resultText: '感情から離れて事実を見た。否定の声が少し静かになった。',
          damageToEnemy: 11,
          damageToPlayer: 2,
          traitDelta: ActionLog(logic: 3, caution: 1),
          minStage: GrowthStage.young,
        ),
        BattleChoice(
          label: '過去の成功を思い出す',
          resultText: 'できたことを振り返ると、否定の声が弱まった。',
          damageToEnemy: 14,
          damageToPlayer: 0,
          traitDelta: ActionLog(persistence: 2, planning: 1),
          minStage: GrowthStage.adult,
        ),
      ],
    ),

    // ボス専用
    Enemy(
      id: 'inner_labyrinth',
      name: '心の迷宮の守護者',
      description: 'この迷宮の最奥に住む存在。あなたの全ての迷いと恐れが結晶化した姿。\n次のターン、全力で攻撃してくる。',
      nextAction: '「ここから出ることはできない」と告げる',
      maxHp: 35,
      currentHp: 35,
      choices: [
        BattleChoice(
          label: '全力で立ち向かう',
          resultText: '全てをぶつけた。大きなダメージを与えたが、反撃も受けた。',
          damageToEnemy: 12,
          damageToPlayer: 10,
          traitDelta: ActionLog(challenge: 3, persistence: 2),
        ),
        BattleChoice(
          label: '逃げる',
          resultText: '迷宮から逃げ出した。冒険は終わった。',
          damageToEnemy: 0,
          damageToPlayer: 0,
          resourceChanges: {'food': -2},
          traitDelta: ActionLog(flexibility: 2),
        ),
        BattleChoice(
          label: '観察して弱点を探す',
          resultText: '冷静に観察すると、守護者の動きにパターンを見つけた。',
          damageToEnemy: 10,
          damageToPlayer: 5,
          traitDelta: ActionLog(logic: 3, caution: 2),
          minStage: GrowthStage.young,
        ),
        BattleChoice(
          label: 'アイテムで一気に攻める',
          resultText: '持てる全てのアイテムを使って大ダメージを与えた。',
          damageToEnemy: 18,
          damageToPlayer: 3,
          resourceChanges: {'items': -2},
          traitDelta: ActionLog(planning: 2, challenge: 1),
          minStage: GrowthStage.young,
        ),
        BattleChoice(
          label: '仲間と力を合わせる',
          resultText: '仲間と力を合わせ、守護者を追い詰めた。絆の力は強い。',
          damageToEnemy: 20,
          damageToPlayer: 0,
          resourceChanges: {'bond': -2},
          traitDelta: ActionLog(cooperation: 3, altruism: 2),
          minStage: GrowthStage.adult,
        ),
      ],
    ),
  ];

  static Enemy get boss => all.firstWhere((e) => e.id == 'inner_labyrinth');
  static List<Enemy> get regular => all.where((e) => e.id != 'inner_labyrinth').toList();
}
