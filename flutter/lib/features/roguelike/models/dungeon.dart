// features/roguelike/models/dungeon.dart
//
// 「悩み」ごとのダンジョン。最深部のボス＝その悩み本体で、踏破＝悩みの克服。
// ザコはハイブリッド方式: 各ダンジョン固有1体＋全共通の「もやもや/雑念」(Enemies.commonMobs)。

import 'enemy.dart';
import 'action_log.dart';
import 'outcome.dart';
import 'game_state.dart';

class Dungeon {
  final String id;
  final String worry;    // 悩みの名前（＝ボス名）
  final String emoji;
  final String tagline;  // 一言の説明（選択画面用）
  final Enemy boss;
  final List<Enemy> mobs; // このダンジョン固有のザコ（共通もやもやとは別）
  final bool isFinale;    // 最終ダンジョン（全悩み克服後に解禁）

  const Dungeon({
    required this.id,
    required this.worry,
    required this.emoji,
    required this.tagline,
    required this.boss,
    this.mobs = const [],
    this.isFinale = false,
  });

  /// このダンジョンで敵ノードに出る候補（固有ザコ＋共通もやもや）。
  List<Enemy> get mobPool => [...mobs, ...Enemies.commonMobs];
}

/// ボスの基本選択肢を組み立てる共通ヘルパー。
/// 正面から向き合う / 逃げる / 観察(幼少〜) / テーマ特効(成人) / 回復薬。
List<BattleChoice> _bossChoices({
  required String confrontText,
  required String confrontFailText,
  required String observeLabel,
  required String observeText,
  int observeDmg = 6,
  required BattleChoice special,
}) =>
    [
      BattleChoice(
        label: '正面から向き合う',
        riskHint: '当たり外れあり',
        selectTrait: const ActionLog(challenge: 1, persistence: 2),
        outcomes: [
          Outcome(
            tier: OutcomeTier.success, weight: 65,
            resultText: confrontText,
            damageToEnemy: 9, damageToPlayer: 6,
          ),
          Outcome(
            tier: OutcomeTier.failure, weight: 35,
            resultText: confrontFailText,
            damageToEnemy: 4, damageToPlayer: 9,
            traitDelta: const ActionLog(caution: 1),
          ),
        ],
      ),
      Enemies.fleeChoice,
      BattleChoice(
        label: observeLabel,
        riskHint: '安定・低リスク（幼少〜）',
        minStage: GrowthStage.young,
        selectTrait: const ActionLog(logic: 2, planning: 2),
        outcomes: [
          Outcome(
            tier: OutcomeTier.success, weight: 1,
            resultText: observeText,
            damageToEnemy: observeDmg, damageToPlayer: 2,
          ),
        ],
      ),
      special,
      Enemies.healChoice,
    ];

/// テーマ特効の大ダメージ選択肢を作る共通ヘルパー（成人）。
/// 高火力の見返りとして (1) 成功率制で外すことがある (2) 自傷を伴う
/// (3) 1回の戦闘で1度だけ、という3重の制約でノーリスクの一択にならないようにする。
BattleChoice _special(String label, String text,
        {int dmg = 14, int dmgSelf = 4, ActionLog trait = const ActionLog()}) =>
    BattleChoice(
      label: label,
      riskHint: '特効・自傷あり・1回のみ（成人）',
      minStage: GrowthStage.adult,
      selectTrait: trait,
      oncePerBattle: true,
      outcomes: [
        // 成功（60%）: 高ダメージ。失敗（40%）: 空振りで小ダメージ（自傷は変わらず）。
        Outcome(tier: OutcomeTier.great, weight: 60, resultText: text, damageToEnemy: dmg, damageToPlayer: dmgSelf),
        Outcome(tier: OutcomeTier.failure, weight: 40, resultText: '渾身の一手だったが、うまく決まらなかった。', damageToEnemy: (dmg / 4).round(), damageToPlayer: dmgSelf),
      ],
    );

/// 固有ザコを簡潔に作るヘルパー。element はダンジョンのテーマ元素を渡す。
Enemy _mob(String id, String name, String desc, {int hp = 10, Map<String, int> reward = const {'money': 1}, String element = '無'}) =>
    Enemy(
      id: id, name: name, description: desc,
      nextAction: 'すきを突いてくる',
      maxHp: hp, currentHp: hp,
      counterBaseDamage: 2,
      choices: Enemies.mobChoices(dmg: 7),
      defeatReward: reward,
      element: element,
    );

class Dungeons {
  static Dungeon byId(String id) => all.firstWhere((d) => d.id == id);

  /// 図鑑用: 登場する全敵（ボス・固有ザコ・共通ザコ）を重複なく列挙。
  static List<Enemy> get allEnemies {
    final seen = <String>{};
    final list = <Enemy>[];
    for (final d in all) {
      for (final e in [d.boss, ...d.mobs]) {
        if (seen.add(e.id)) list.add(e);
      }
    }
    for (final e in Enemies.commonMobs) {
      if (seen.add(e.id)) list.add(e);
    }
    return list;
  }

  /// 通常の悩みダンジョン（最終を除く）。
  static List<Dungeon> get worries => all.where((d) => !d.isFinale).toList();

  /// 最終ダンジョンを解禁できるか（全ての悩みを克服済みか）。
  static bool finaleUnlocked(Set<String> clearedIds) =>
      worries.every((d) => clearedIds.contains(d.id));

  static final List<Dungeon> all = [
    // 1. 対人関係の悩み
    Dungeon(
      id: 'interpersonal',
      worry: '対人関係の悩み',
      emoji: '🫧',
      tagline: '人との関わりから生まれたわだかまり',
      mobs: [_mob('awkward_silence', '気まずい沈黙', '会話が途切れた時の、あの居心地の悪さ。', element: '水')],
      boss: Enemy(
        id: 'interpersonal',
        name: '対人関係の悩み',
        description: '人との関わりから生まれた複雑な感情のかたまり。\n反撃のたびに、あなたと仲間の絆を蝕んでくる。',
        nextAction: '「どうせ嫌われている」と囁き、絆を削る',
        maxHp: 24, currentHp: 24, isBoss: true,
        trait: EnemyTrait.interpersonal,
        element: '水',
        counterBaseDamage: 3,
        counterDrain: {'bond': -1},
        defeatRewardText: '対人関係の悩みが晴れた。人との縁が、めぐって力になって返ってきた。',
        choices: [
          BattleChoice(
            label: '正面から向き合う',
            riskHint: '当たり外れあり',
            selectTrait: const ActionLog(challenge: 1, persistence: 2),
            outcomes: [
              Outcome(tier: OutcomeTier.success, weight: 65, resultText: '真剣に向き合うと、悩みの核心が見えてきた。', damageToEnemy: 9, damageToPlayer: 6),
              Outcome(tier: OutcomeTier.failure, weight: 35, resultText: '感情が先走り、うまく向き合えなかった。深く傷ついた。', damageToEnemy: 4, damageToPlayer: 9, traitDelta: ActionLog(caution: 1)),
            ],
          ),
          Enemies.fleeChoice,
          BattleChoice(
            label: '観察する',
            riskHint: '安定・低リスク（幼少〜）',
            minStage: GrowthStage.young,
            selectTrait: const ActionLog(logic: 1, planning: 2),
            outcomes: [Outcome(tier: OutcomeTier.success, weight: 1, resultText: '悩みのパターンを冷静に観察した。次の一手が見えた。', damageToEnemy: 5, damageToPlayer: 2)],
          ),
          BattleChoice(
            label: '仲間に相談する',
            riskHint: '絆を消費・特効（成人・相棒）',
            upfrontCost: {'bond': -1},
            minStage: GrowthStage.adult,
            requiresCompanion: true,
            selectTrait: const ActionLog(cooperation: 2, altruism: 1),
            outcomes: [Outcome(tier: OutcomeTier.great, weight: 1, resultText: '仲間の視点で見つめ直すと、悩みは驚くほど小さくなった。', damageToEnemy: 13)],
          ),
          BattleChoice(
            label: '交渉して距離を縮める',
            riskHint: '当たれば特効（成人）',
            minStage: GrowthStage.adult,
            selectTrait: const ActionLog(flexibility: 1, cooperation: 2),
            outcomes: [
              Outcome(tier: OutcomeTier.great, weight: 65, resultText: '相手の立場を理解しようと歩み寄った。わだかまりが大きく解けた。', damageToEnemy: 15),
              Outcome(tier: OutcomeTier.failure, weight: 35, resultText: '歩み寄ろうとしたが、空回りした。少し気まずくなっただけだ。', damageToEnemy: 4, traitDelta: ActionLog(caution: 1)),
            ],
          ),
          Enemies.healChoice,
        ],
      ),
    ),

    // 2. 将来不安
    Dungeon(
      id: 'future_anxiety',
      worry: '将来不安',
      emoji: '🌫️',
      tagline: '見えない未来への漠然とした恐れ',
      mobs: [_mob('vague_worry', '漠然とした心配', 'はっきりしないのに、ずっと付きまとう先の心配。', element: '風')],
      boss: Enemy(
        id: 'future_anxiety',
        name: '将来不安',
        description: '見えない未来への漠然とした恐れ。\n長引くほど大きくなり、食料や蓄えをじわじわ奪っていく。',
        nextAction: '「先が見えない」と霧を広げ、蓄えを奪う',
        maxHp: 24, currentHp: 24, isBoss: true,
        trait: EnemyTrait.futureAnxiety,
        element: '風',
        counterBaseDamage: 2,
        counterDrain: {'food': -1},
        escalates: true,
        defeatRewardText: '将来不安が和らいだ。見通しが立ち、奪われた蓄えを取り戻せた。',
        choices: [
          BattleChoice(
            label: '正面から向き合う',
            riskHint: '当たり外れあり',
            selectTrait: const ActionLog(challenge: 1, persistence: 2),
            outcomes: [
              Outcome(tier: OutcomeTier.success, weight: 65, resultText: '不安を直視した。怖かったが、少し楽になった。', damageToEnemy: 8, damageToPlayer: 6),
              Outcome(tier: OutcomeTier.failure, weight: 35, resultText: '考えるほど不安が膨らみ、飲み込まれそうになった。', damageToEnemy: 3, damageToPlayer: 8, traitDelta: ActionLog(caution: 1)),
            ],
          ),
          Enemies.fleeChoice,
          BattleChoice(
            label: '情報を集めて見通す',
            riskHint: '安定・低リスク（幼少〜）',
            minStage: GrowthStage.young,
            selectTrait: const ActionLog(logic: 2, planning: 2),
            outcomes: [Outcome(tier: OutcomeTier.success, weight: 1, resultText: '分からないことを一つずつ調べると、霧が少し晴れた。', damageToEnemy: 6, damageToPlayer: 2)],
          ),
          _special('小さな目標を立てる', '遠い未来ではなく、今できることに集中した。不安が一気に薄れた。', dmg: 14, trait: const ActionLog(planning: 3, logic: 1)),
          Enemies.healChoice,
        ],
      ),
    ),

    // 3. 自己否定
    Dungeon(
      id: 'self_denial',
      worry: '自己否定',
      emoji: '🪞',
      tagline: '自分の中から湧き上がる否定の声',
      mobs: [_mob('self_nagging', '自分への小言', '「またダメだった」と自分を責める小さな声。', element: '闇')],
      boss: Enemy(
        id: 'self_denial',
        name: '自己否定',
        description: '自分の中から湧き上がる否定の声。\n力みは封じられる。逃げれば声はかえって大きくなる。',
        nextAction: '「お前には無理だ」と囁き、次の一手を縛る',
        maxHp: 26, currentHp: 26, isBoss: true,
        trait: EnemyTrait.selfDenial,
        element: '闇',
        counterBaseDamage: 4,
        fleeWorsens: true,
        defeatRewardText: '自己否定を乗り越えた。自分を信じられるようになり、心の器が少し広がった。',
        choices: [
          BattleChoice(
            label: '自分を信じて攻撃する',
            riskHint: '当たり外れあり・封じられやすい',
            selectTrait: const ActionLog(challenge: 2, persistence: 1),
            outcomes: [
              Outcome(tier: OutcomeTier.success, weight: 60, resultText: '「できる」と言い聞かせて立ち向かった。', damageToEnemy: 9, damageToPlayer: 7),
              Outcome(tier: OutcomeTier.failure, weight: 40, resultText: '勢いだけで挑んだが、否定の声に呑まれた。', damageToEnemy: 4, damageToPlayer: 9, traitDelta: ActionLog(caution: 1)),
            ],
          ),
          Enemies.fleeChoice,
          BattleChoice(
            label: '客観的に分析する',
            riskHint: '安定・低リスク（幼少〜）',
            minStage: GrowthStage.young,
            selectTrait: const ActionLog(logic: 2, planning: 2),
            outcomes: [Outcome(tier: OutcomeTier.success, weight: 1, resultText: '感情から離れて事実を見た。否定の声が静かになった。', damageToEnemy: 7, damageToPlayer: 2)],
          ),
          _special('過去の成功を思い出す', 'できたことを振り返ると、否定の声が大きく弱まった。', dmg: 14, trait: const ActionLog(persistence: 2, planning: 1)),
          Enemies.healChoice,
        ],
      ),
    ),

    // 4. 評価への恐怖
    Dungeon(
      id: 'fear_of_judgment',
      worry: '評価への恐怖',
      emoji: '👁️',
      tagline: '他人にどう見られるかという怖さ',
      mobs: [_mob('eyes', '人目', 'どこからか見られている気がする、という落ち着かなさ。', element: '光')],
      boss: Enemy(
        id: 'fear_of_judgment',
        name: '評価への恐怖',
        description: '他人からの評価に怯える心。\n反撃のたびに、自分の価値を見失わせ蓄えを奪う。',
        nextAction: '「下に見られている」と囁き、自信と蓄えを削る',
        maxHp: 24, currentHp: 24, isBoss: true,
        element: '光',
        counterBaseDamage: 3,
        counterDrain: {'money': -1},
        defeatRewardText: '評価への恐怖が薄れた。他人の物差しから自由になれた。',
        choices: _bossChoices(
          confrontText: '怖さを認めつつ、自分の言葉で向き合った。',
          confrontFailText: '人目が気になりすぎて、言葉に詰まってしまった。',
          observeLabel: '相手をよく観察する',
          observeText: '相手も完璧ではないと気づくと、怖さが和らいだ。',
          special: _special('自分の物差しで測る', '他人ではなく自分の基準で考えると、評価の鎖がほどけた。', trait: const ActionLog(logic: 2, flexibility: 2)),
        ),
      ),
    ),

    // 5. 孤独
    Dungeon(
      id: 'loneliness',
      worry: '孤独',
      emoji: '🌙',
      tagline: '誰ともつながっていない気がする心細さ',
      mobs: [_mob('emptiness', 'ぽつんとした寂しさ', 'ふとした瞬間に胸に広がる、ひとりぼっちの感覚。', hp: 9, element: '闇')],
      boss: Enemy(
        id: 'loneliness',
        name: '孤独',
        description: '誰にも理解されない、という深い心細さ。\n反撃のたびに、人とのつながりを断とうとしてくる。',
        nextAction: '「ひとりだ」と囁き、絆を断とうとする',
        maxHp: 22, currentHp: 22, isBoss: true,
        trait: EnemyTrait.interpersonal,
        element: '闇',
        counterBaseDamage: 3,
        counterDrain: {'bond': -1},
        defeatRewardText: '孤独が和らいだ。ひとりでも、つながりは確かにあると思えた。',
        choices: _bossChoices(
          confrontText: '寂しさを否定せず、そのまま受け止めた。',
          confrontFailText: '寂しさに飲まれ、心を閉ざしてしまった。',
          observeLabel: '今あるつながりを思い出す',
          observeText: '支えてくれた人を思い出すと、心細さが薄れた。',
          special: _special('誰かに声をかける', '勇気を出して頼ると、孤独は思ったより小さかった。', trait: const ActionLog(cooperation: 2, altruism: 1)),
        ),
      ),
    ),

    // 6. 焦り
    Dungeon(
      id: 'impatience',
      worry: '焦り',
      emoji: '⏱️',
      tagline: '間に合わない気がして急いてしまう心',
      mobs: [_mob('rushing_voice', '急かす声', '「早くしなきゃ」と背中を押してくる落ち着かない声。', hp: 9, element: '雷')],
      boss: Enemy(
        id: 'impatience',
        name: '焦り',
        description: '間に合わない、遅れている、という切迫感。\n焦るほど大きくなり、攻め急ぐと痛い目を見る。',
        nextAction: '「もう間に合わない」と急かし、勢いを増す',
        maxHp: 20, currentHp: 20, isBoss: true,
        element: '雷',
        counterBaseDamage: 2,
        escalates: true,
        defeatRewardText: '焦りが鎮まった。一つずつで良いと思えると、足取りが軽くなった。',
        choices: _bossChoices(
          confrontText: '焦りを認めつつ、勢いだけで動かないようにした。',
          confrontFailText: '急ぎすぎて空回りし、かえって消耗した。',
          observeLabel: '深呼吸して落ち着く',
          observeText: 'ひと呼吸おくと、焦りの渦が静まった。',
          special: _special('一つずつ片付ける', '全部ではなく、今やる一つに集中すると焦りが消えた。', trait: const ActionLog(planning: 3, caution: 1)),
        ),
      ),
    ),

    // 7. 怒り
    Dungeon(
      id: 'anger',
      worry: '怒り',
      emoji: '🔥',
      tagline: '抑えきれずに噴き出す激しい感情',
      mobs: [_mob('irritation', '小さな苛立ち', 'ささいなことで、つい眉間にしわが寄る感覚。', element: '炎')],
      boss: Enemy(
        id: 'anger',
        name: '怒り',
        description: '抑えきれずに噴き出す激しい感情。\n真っ向からぶつかると、強烈に反撃してくる。',
        nextAction: '感情を爆発させ、激しく反撃する',
        maxHp: 24, currentHp: 24, isBoss: true,
        element: '炎',
        counterBaseDamage: 5,
        defeatRewardText: '怒りの奥にあった本音に気づけた。感情に振り回されにくくなった。',
        choices: _bossChoices(
          confrontText: '怒りを真正面から受け止め、力でねじ伏せた。',
          confrontFailText: '怒りに怒りで返し、互いに激しく傷ついた。',
          observeLabel: 'ひと呼吸おいて距離を取る',
          observeText: '一歩引いて眺めると、炎の勢いが弱まった。',
          special: _special('怒りの奥の本音を見る', '本当は何が悲しかったのかに気づくと、怒りがほどけた。', trait: const ActionLog(logic: 2, altruism: 2)),
        ),
      ),
    ),

    // 8. 迷い
    Dungeon(
      id: 'hesitation',
      worry: '迷い',
      emoji: '🧭',
      tagline: '決めきれず立ち止まってしまう心',
      mobs: [_mob('two_paths', 'ふたつの選択肢', 'どちらも選べず、その場で足が止まってしまう感覚。', hp: 9, element: '風')],
      boss: Enemy(
        id: 'hesitation',
        name: '迷い',
        description: '決めきれずに立ち止まってしまう心。\n考えすぎるほど、堂々巡りに引き込まれる。',
        nextAction: '「本当にそれでいいのか」と問い、足を止めさせる',
        maxHp: 20, currentHp: 20, isBoss: true,
        element: '風',
        counterBaseDamage: 3,
        defeatRewardText: '迷いが晴れた。完璧な正解より、自分で選ぶことの大切さに気づけた。',
        choices: _bossChoices(
          confrontText: 'えいやと踏み込み、迷いを断ち切った。',
          confrontFailText: 'やはり決めきれず、堂々巡りに戻ってしまった。',
          observeLabel: '選択肢を書き出して比べる',
          observeText: '紙に並べて見ると、本当に大事な軸が見えてきた。',
          special: _special('直感で決める', '考え尽くした先で、最後は直感を信じて決めた。', trait: const ActionLog(intuition: 3, challenge: 1)),
        ),
      ),
    ),

    // 9. 完璧主義
    Dungeon(
      id: 'perfectionism',
      worry: '完璧主義',
      emoji: '💯',
      tagline: '完璧でないと許せず、自分を追い込む心',
      mobs: [_mob('nitpicking', '粗探し', '少しの欠点が気になって、先に進めなくなる感覚。', element: '氷')],
      boss: Enemy(
        id: 'perfectionism',
        name: '完璧主義',
        description: '完璧でなければ意味がない、と自分を追い込む心。\nこだわるほど長引き、時間と気力をすり減らす。',
        nextAction: '「まだ足りない」と囁き、こだわらせて消耗させる',
        maxHp: 26, currentHp: 26, isBoss: true,
        element: '氷',
        counterBaseDamage: 3,
        counterDrain: {'food': -1},
        escalates: true,
        defeatRewardText: '完璧主義がほどけた。「これで十分」と思えると、肩の力が抜けた。',
        choices: _bossChoices(
          confrontText: '細部まで詰め切り、力ずくで仕上げた。',
          confrontFailText: 'こだわりすぎて終わらず、気力をすり減らした。',
          observeLabel: '全体のバランスを見る',
          observeText: '一歩引いて全体を見ると、十分に良い出来だと分かった。',
          special: _special('60点で良しとする', '「完璧」より「完了」を選ぶと、呪縛がほどけた。', trait: const ActionLog(flexibility: 3, planning: 1)),
        ),
      ),
    ),

    // 10. 先延ばし
    Dungeon(
      id: 'procrastination',
      worry: '先延ばし',
      emoji: '🐢',
      tagline: '分かっているのに動き出せない心',
      mobs: [_mob('later', 'あとでいいや', '「今やらなくても」と先送りにしてしまう誘惑。', hp: 9, element: '土')],
      boss: Enemy(
        id: 'procrastination',
        name: '先延ばし',
        description: 'やるべきと分かっていても動き出せない重さ。\n逃げて先送りするほど、重くのしかかってくる。',
        nextAction: '「明日でいい」と囁き、動き出しを鈍らせる',
        maxHp: 18, currentHp: 18, isBoss: true,
        element: '土',
        counterBaseDamage: 3,
        fleeWorsens: true,
        defeatRewardText: '先延ばしを乗り越えた。動き出してしまえば、案外なんとかなると分かった。',
        choices: _bossChoices(
          confrontText: 'とにかく手をつけると、重さが少し軽くなった。',
          confrontFailText: '腰が上がらず、先送りの重さが増した。',
          observeLabel: 'やることを小さく分ける',
          observeText: '大きな塊を小さく刻むと、最初の一歩が踏み出せた。',
          special: _special('とりあえず5分だけ動く', '5分だけのつもりが、動き出すと勢いがついた。', trait: const ActionLog(challenge: 2, flexibility: 2)),
        ),
      ),
    ),

    // 最終: 心の迷宮の守護者（全悩み克服後に解禁）
    Dungeon(
      id: 'inner_labyrinth',
      worry: '心の迷宮の守護者',
      emoji: '🌀',
      tagline: '全ての迷いと恐れが結晶化した最奥の存在',
      isFinale: true,
      mobs: [_mob('lingering_doubt', '残り火の迷い', '乗り越えたはずの悩みが、ふと顔を出す残り火。', hp: 12, element: '無')],
      boss: Enemy(
        id: 'inner_labyrinth',
        name: '心の迷宮の守護者',
        description: 'この迷宮の最奥に住む存在。あなたの全ての迷いと恐れが結晶化した姿。\n長引くほど力を増していく。',
        nextAction: '「ここから出ることはできない」と全力で迫る',
        maxHp: 35, currentHp: 35, isBoss: true,
        trait: EnemyTrait.boss,
        element: '無',
        counterBaseDamage: 5,
        escalates: true,
        defeatRewardText: '全ての悩みを束ねる存在を乗り越えた。あなたは一回り大きくなった。',
        choices: [
          BattleChoice(
            label: '全力で立ち向かう',
            riskHint: '当たり外れあり',
            selectTrait: const ActionLog(challenge: 2, persistence: 1),
            outcomes: [
              Outcome(tier: OutcomeTier.success, weight: 70, resultText: '全てをぶつけた。大きなダメージを与えたが、反撃も受けた。', damageToEnemy: 12, damageToPlayer: 10),
              Outcome(tier: OutcomeTier.failure, weight: 30, resultText: '勢い任せの一撃は受け止められ、手痛い反撃を浴びた。', damageToEnemy: 6, damageToPlayer: 14, traitDelta: ActionLog(caution: 1)),
            ],
          ),
          Enemies.fleeChoice,
          BattleChoice(
            label: '観察して弱点を探す',
            riskHint: '安定・低リスク（幼少〜）',
            minStage: GrowthStage.young,
            selectTrait: const ActionLog(logic: 1, curiosity: 1),
            outcomes: [Outcome(tier: OutcomeTier.success, weight: 1, resultText: '冷静に観察すると、守護者の動きにパターンを見つけた。', damageToEnemy: 7, damageToPlayer: 5)],
          ),
          BattleChoice(
            label: '仲間と力を合わせる',
            riskHint: '絆-2・自傷あり・1回のみ・最大火力（成人・相棒）',
            upfrontCost: {'bond': -2},
            minStage: GrowthStage.adult,
            requiresCompanion: true,
            oncePerBattle: true,
            selectTrait: const ActionLog(cooperation: 2, altruism: 2),
            outcomes: [
              // 成功（60%）: 最大火力。失敗（40%）: かみ合わず小ダメージ（絆・自傷は消費）。
              Outcome(tier: OutcomeTier.great, weight: 60, resultText: '仲間と力を合わせ、守護者を追い詰めた。絆の力は強い。ただし無理を通した反動もある。', damageToEnemy: 20, damageToPlayer: 6),
              Outcome(tier: OutcomeTier.failure, weight: 40, resultText: '息を合わせようとしたが、かみ合わなかった。それでも一矢は報いた。', damageToEnemy: 6, damageToPlayer: 6),
            ],
          ),
          Enemies.healChoice,
        ],
      ),
    ),
  ];
}
