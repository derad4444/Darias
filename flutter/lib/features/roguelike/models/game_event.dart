// features/roguelike/models/game_event.dart

import 'game_state.dart';
import 'action_log.dart';
import 'outcome.dart';
import 'map_cell.dart';

class EventChoice with WeightedChoice {
  final String label;

  /// 選ぶ前に表示する短いリスクヒント（例:「危険だが速い」）。
  final String riskHint;

  /// 選んだ瞬間に確定で消費する追加の食料（「安全だが遅い」のコスト表現、既定0）。
  final int extraFoodCost;

  /// 選んだ瞬間に確定で支払うコスト（例: {'items': -1}）。結果抽選の前に適用される。
  final Map<String, int> upfrontCost;

  /// この選択を「選んだ」こと自体が示す判断傾向。成功/失敗に関わらず加算される。
  /// （成功したか失敗したかではなく、何を選んだかを記録する思想）
  final ActionLog selectTrait;

  /// 重み付きで抽選される結果（大成功/成功/失敗）。結果ごとの追加traitは小さく。
  @override
  final List<Outcome> outcomes;

  final GrowthStage minStage;

  /// この選択肢は相棒（仲間）がいる時だけ出す。不在時は非表示。
  final bool requiresCompanion;

  /// この選択肢は回復薬を消費する。所持0の時は非表示。
  final bool requiresItem;

  /// 装備購入の選択肢（行商人）。`Equipments` の id を指定すると、
  /// 「今より強ければ price 分の金貨を払って装備」する特別処理になる。
  /// null＝通常の選択肢。指定時は `outcomes` は使われない（結果文は自動生成）。
  final String? buyEquipId;

  const EventChoice({
    required this.label,
    this.riskHint = '',
    this.extraFoodCost = 0,
    this.upfrontCost = const {},
    this.selectTrait = const ActionLog(),
    this.outcomes = const [Outcome(resultText: '')],
    this.minStage = GrowthStage.baby,
    this.requiresCompanion = false,
    this.requiresItem = false,
    this.buyEquipId,
  });
}

class GameEvent {
  final String id;
  final String title;
  final String description;
  final List<EventChoice> choices;

  /// このイベントは相棒（仲間）がいる時だけ抽選される。
  final bool requiresCompanion;

  /// このイベントは相棒（仲間）がいない時だけ抽選される（加入イベント等）。
  final bool excludeWithCompanion;

  /// **売買を繰り返せる店**として専用UIで表示する（行商人）。
  ///
  /// 通常のイベントは1回選ぶと結果表示 →「進む」で終了するが、
  /// 店は「立ち去る」を選ぶまで買う・売る・鞄を開くを繰り返せる。
  /// そのため `choices` は使わず、`MerchantShopView` が描画を担当する。
  final bool isShop;

  const GameEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.choices,
    this.requiresCompanion = false,
    this.excludeWithCompanion = false,
    this.isShop = false,
  });
}

// 全イベント定義
class GameEvents {
  static List<EventChoice> forStage(List<EventChoice> all, GrowthStage stage) =>
      all.where((c) => c.minStage.index <= stage.index).toList();

  static GameEvent byId(String id) => all.firstWhere((e) => e.id == id);

  /// ノード種別ごとのイベントプール。種別に合ったイベントだけを抽選する。
  /// （商人ノードで崖道が出るような体験上の違和感を防ぐ）
  /// 各イベントは1種別のみに割り当て、ノード種別をまたいで同じイベントが出ないようにする。
  /// 相棒フラグで全滅しないよう、各種別に常時出せるイベントを最低1つ含める。
  static const Map<CellType, List<String>> poolByCell = {
    CellType.chest:     ['chest_old', 'ruins'],
    CellType.rest:      ['rest_event', 'companion_tired'],
    CellType.merchant:  ['merchant_event'],
    CellType.companion: ['help_stranger', 'traveler'],
    // 謎＝「未知・内面の探究」ノード（好奇心/探究 ⇔ 回避/慎重）。報酬は最大HP増加・地図開示・小回復（物質報酬は宝箱の役割）。
    // 旧: 分かれ道（枝道マップと二重）・謎の扉（宝箱と重複）・険しい崖道（リスク志向で宝箱と軸重複）は廃止。
    CellType.mystery:   ['mystery_light', 'inner_voice', 'wall_inscription'],
  };

  static final List<GameEvent> all = [
    // 宝箱イベント — 罠リスクの賭け
    GameEvent(
      id: 'chest_old',
      title: '古い宝箱',
      description: '苔むした宝箱を見つけた。罠が仕掛けられているかもしれない。',
      choices: [
        EventChoice(
          label: 'すぐ開ける',
          riskHint: '危険だが速い',
          selectTrait: ActionLog(challenge: 2, intuition: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.great, weight: 8,
              resultText: '勢いよく開けた！罠は不発で、金貨がたっぷり入っていた。',
              resourceChanges: {'money': 8},
              traitDelta: ActionLog(curiosity: 1),
            ),
            Outcome(
              tier: OutcomeTier.great, weight: 7,
              resultText: '勢いよく開けた！罠は不発。中には立派な武器が眠っていた。',
              equipRewardId: 'iron_sword',
              traitDelta: ActionLog(curiosity: 1),
            ),
            Outcome(
              tier: OutcomeTier.great, weight: 7,
              resultText: '勢いよく開けた！罠は不発。中には頑丈な防具が納められていた。',
              equipRewardId: 'iron_armor',
              traitDelta: ActionLog(curiosity: 1),
            ),
            Outcome(
              tier: OutcomeTier.success, weight: 38,
              resultText: '勢いよく開けた。金貨が入っていた。',
              resourceChanges: {'money': 5},
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 40,
              resultText: '蓋を開けた瞬間、仕掛けの針が手を刺した。痛みに金貨どころではなかった。',
              resourceChanges: {'hp': -8},
              traitDelta: ActionLog(persistence: 1),
            ),
          ],
        ),
        EventChoice(
          label: '周囲を調べてから開ける',
          riskHint: '安全だが遅い（🍞-1）',
          extraFoodCost: 1,
          minStage: GrowthStage.young,
          selectTrait: ActionLog(caution: 2, logic: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 85,
              resultText: '丁寧に調べて罠を発見。解除して安全に金貨を得た。',
              resourceChanges: {'money': 3},
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 15,
              resultText: '慎重に調べたが見落としがあった。幸い軽傷で済んだが収穫はなかった。',
              resourceChanges: {'hp': -3},
              traitDelta: ActionLog(caution: 1),
            ),
          ],
        ),
        EventChoice(
          label: '無視して進む',
          riskHint: 'リスクなし・体力温存',
          selectTrait: ActionLog(caution: 1, planning: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: 'リスクを避けて先へ進んだ。',
            ),
          ],
        ),
      ],
    ),

    // 旅人との出会い
    GameEvent(
      id: 'traveler',
      title: '旅人との出会い',
      description: '疲れた様子の旅人が道に座っている。あなたに話しかけてきた。',
      choices: [
        EventChoice(
          label: '話を聞く',
          riskHint: '当たり外れあり',
          selectTrait: ActionLog(altruism: 2, cooperation: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 75,
              resultText: '旅人が地図を見せてくれた。周辺の行き先がいくつか明らかになった。',
              resourceChanges: {'food': -1},
              traitDelta: ActionLog(curiosity: 1),
              revealCells: 3,
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 25,
              resultText: '長々と世間話に付き合わされただけだった。時間と食料を少し損した。',
              resourceChanges: {'food': -1},
              traitDelta: ActionLog(caution: 1),
            ),
          ],
        ),
        EventChoice(
          label: '食料を分ける',
          riskHint: '善意の投資',
          selectTrait: ActionLog(altruism: 2, cooperation: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.great, weight: 35,
              resultText: '食料を渡すと旅人は涙を流して感謝し、お礼に回復薬を譲ってくれた。',
              resourceChanges: {'food': -3, 'items': 1},
              traitDelta: ActionLog(flexibility: 1),
            ),
            Outcome(
              tier: OutcomeTier.success, weight: 65,
              resultText: '食料を渡すと、旅人は深く感謝し、わずかな路銀を分けてくれた。',
              resourceChanges: {'food': -3, 'money': 2},
            ),
          ],
        ),
        EventChoice(
          label: 'お金を渡す',
          riskHint: '相手次第（成人）',
          minStage: GrowthStage.young,
          selectTrait: ActionLog(altruism: 2, flexibility: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 70,
              resultText: '旅人は喜び、お礼に回復薬をくれた。',
              resourceChanges: {'money': -2, 'items': 1},
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 30,
              resultText: '旅人は金を受け取ると、礼もそこそこに去っていった。だまされたかもしれない。',
              resourceChanges: {'money': -2},
              traitDelta: ActionLog(caution: 1),
            ),
          ],
        ),
        EventChoice(
          label: '立ち去る',
          riskHint: 'リスクなし',
          selectTrait: ActionLog(planning: 1, persistence: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: '急ぎ足で通り過ぎた。',
            ),
          ],
        ),
      ],
    ),

    // 険しい崖道（リスク志向＝挑戦⇔慎重で宝箱と軸が重複＋道選択が枝道マップと二重 → 謎から廃止。コメントで残置）
    /*
    GameEvent(
      id: 'steep_road',
      title: '険しい崖道',
      description: '目の前に険しい崖道がある。安全な迂回路もあるが時間がかかる。',
      choices: [
        EventChoice(
          label: '崖道を進む',
          riskHint: '危険だが速い',
          selectTrait: ActionLog(challenge: 2, intuition: 2),
          outcomes: [
            Outcome(
              tier: OutcomeTier.great, weight: 20,
              resultText: '身軽に駆け抜けた。無傷で時間を大幅に短縮できた。',
              resourceChanges: {'food': -1},
              traitDelta: ActionLog(intuition: 1),
            ),
            Outcome(
              tier: OutcomeTier.success, weight: 40,
              resultText: '足を滑らせ少し傷ついたが、時間を節約できた。',
              resourceChanges: {'hp': -5, 'food': -1},
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 40,
              resultText: '崖から転落しかけ、岩に体を強く打ちつけた。',
              resourceChanges: {'hp': -12, 'food': -1},
              traitDelta: ActionLog(persistence: 1),
            ),
          ],
        ),
        EventChoice(
          label: '迂回路を行く',
          riskHint: '安全だが遅い（🍞-1）',
          extraFoodCost: 1,
          selectTrait: ActionLog(caution: 3, planning: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: '安全に迂回した。食料を余計に使ったが無事だった。',
              resourceChanges: {'food': -3},
            ),
          ],
        ),
        EventChoice(
          label: '仲間に先に行かせて観察する',
          riskHint: '安全寄り・絆を消費（成人・相棒）',
          minStage: GrowthStage.adult,
          requiresCompanion: true,
          selectTrait: ActionLog(logic: 1, caution: 1, cooperation: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 80,
              resultText: '仲間の様子から安全ルートを見極め、うまく渡りきった。',
              resourceChanges: {'bond': -1},
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 20,
              resultText: '先に行かせた仲間が足を滑らせた。慌てて助けたが二人とも傷を負い、信頼も揺らいだ。',
              resourceChanges: {'hp': -3, 'bond': -2},
            ),
          ],
        ),
      ],
    ),
    */

    // 廃墟の探索 — 高リターン/高リスクのトレードオフ
    GameEvent(
      id: 'ruins',
      title: '廃墟の発見',
      description: '古い廃墟がある。中に何かがあるかもしれないし、危険かもしれない。',
      choices: [
        EventChoice(
          label: '入って探索する',
          riskHint: '高リターンだが危険',
          selectTrait: ActionLog(curiosity: 1, challenge: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.great, weight: 20,
              resultText: '奥で壊れた宝箱を発見。古い回復薬と財宝が眠っていた。',
              resourceChanges: {'hp': 5, 'items': 1, 'money': 3},
              traitDelta: ActionLog(intuition: 1),
            ),
            Outcome(
              tier: OutcomeTier.great, weight: 5,
              resultText: '最奥の祭壇に、古の名工が鍛えた一振りが安置されていた…！',
              equipRewardId: 'master_sword',
              traitDelta: ActionLog(intuition: 1),
            ),
            Outcome(
              tier: OutcomeTier.great, weight: 5,
              resultText: '最奥の祭壇に、神聖な力を宿すローブが納められていた…！',
              equipRewardId: 'holy_robe',
              traitDelta: ActionLog(intuition: 1),
            ),
            Outcome(
              tier: OutcomeTier.success, weight: 35,
              resultText: '埃を払いながら探すと、使えそうな回復薬が見つかった。',
              resourceChanges: {'items': 1},
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 35,
              resultText: '奥に進んだ途端、天井が崩れ落ちた。瓦礫から這い出るのがやっとだった。',
              resourceChanges: {'hp': -10},
              traitDelta: ActionLog(caution: 1),
            ),
          ],
        ),
        EventChoice(
          label: '入口だけ確認して引き返す',
          riskHint: '低リターンだが安全（成人）',
          minStage: GrowthStage.young,
          selectTrait: ActionLog(caution: 2, curiosity: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.great, weight: 20,
              resultText: '入口の隅に落ちていた小銭を拾った。深入りはしなかった。',
              resourceChanges: {'money': 2},
            ),
            Outcome(
              tier: OutcomeTier.success, weight: 80,
              resultText: '危険はなかったが、特に収穫もなかった。安全第一だ。',
            ),
          ],
        ),
        EventChoice(
          label: '無視して進む',
          riskHint: 'リスクなし・体力温存',
          selectTrait: ActionLog(planning: 1, caution: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: '時間を無駄にせず先へ進んだ。',
            ),
          ],
        ),
      ],
    ),

    // 仲間の疲労（相棒がいる時だけ発生）
    GameEvent(
      id: 'companion_tired',
      title: '仲間の疲労',
      description: '仲間が「もう限界です…」とうずくまった。このまま進むか、休憩を取るか。',
      requiresCompanion: true,
      choices: [
        EventChoice(
          label: '休憩を取る',
          riskHint: '確定・食料を消費',
          selectTrait: ActionLog(altruism: 1, cooperation: 2),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: '少し休むと仲間が回復した。絆が深まった気がする。',
              resourceChanges: {'food': -2, 'bond': 3, 'hp': 5},
            ),
          ],
        ),
        EventChoice(
          label: '食料を渡して励ます',
          riskHint: '効果は相手次第（成人）',
          minStage: GrowthStage.young,
          selectTrait: ActionLog(altruism: 2, cooperation: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 75,
              resultText: '食料と言葉で仲間を元気づけた。なんとか続けられそうだ。',
              resourceChanges: {'food': -2, 'bond': 1, 'hp': 3},
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 25,
              resultText: '食料は渡したが、仲間の疲れは思ったより深かった。あまり回復しなかった。',
              resourceChanges: {'food': -2, 'bond': 1},
              traitDelta: ActionLog(caution: 1),
            ),
          ],
        ),
        EventChoice(
          label: '先を急ぐよう説得する',
          riskHint: '賭け・絆を損なう恐れ（成人）',
          minStage: GrowthStage.adult,
          selectTrait: ActionLog(planning: 2, persistence: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 60,
              resultText: '言葉を尽くすと、仲間はなんとか立ち上がった。少し距離はできたが前進できた。',
              resourceChanges: {'bond': -1},
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 40,
              resultText: '無理を強いたことで仲間が反発した。険悪な空気のまま、足取りも重い。',
              resourceChanges: {'bond': -3, 'hp': -3},
              traitDelta: ActionLog(persistence: 1),
            ),
          ],
        ),
      ],
    ),

    // 謎の扉（枝道マップ＋宝箱と重複のため廃止。コメントで残置。上位装備ドロップは宝箱へ移設）
    /*
    GameEvent(
      id: 'mysterious_door',
      title: '謎の扉',
      description: '岩壁に不思議な扉が埋まっている。鍵穴があるが、鍵は持っていない。',
      choices: [
        EventChoice(
          label: '体当たりで開けようとする',
          riskHint: '低確率・力ずく',
          selectTrait: ActionLog(challenge: 2, persistence: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 40,
              resultText: '渾身の体当たりで扉が砕けた！奥に金貨が転がっていた。',
              resourceChanges: {'money': 3, 'hp': -3},
              traitDelta: ActionLog(intuition: 1),
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 60,
              resultText: '扉はびくともしなかった。肩を強く打っただけだ。',
              resourceChanges: {'hp': -6},
              traitDelta: ActionLog(persistence: 1),
            ),
          ],
        ),
        EventChoice(
          label: '調べて手がかりを探す',
          riskHint: '安全だが遅い（🍞-1・幼少〜）',
          extraFoodCost: 1,
          minStage: GrowthStage.young,
          selectTrait: ActionLog(logic: 2, curiosity: 2),
          outcomes: [
            Outcome(
              tier: OutcomeTier.great, weight: 6,
              resultText: '扉の文字を読み解くと隠し部屋が現れた。古の名工が鍛えた一振りが眠っていた…！',
              equipRewardId: 'master_sword',
              traitDelta: ActionLog(curiosity: 1),
            ),
            Outcome(
              tier: OutcomeTier.great, weight: 6,
              resultText: '扉の文字を読み解くと隠し部屋が現れた。神聖な力を宿すローブが納められていた…！',
              equipRewardId: 'holy_robe',
              traitDelta: ActionLog(curiosity: 1),
            ),
            Outcome(
              tier: OutcomeTier.success, weight: 73,
              resultText: '扉の文字を読み解き、近くの隠し鍵を発見。扉の中の金貨を手にした。',
              resourceChanges: {'money': 4},
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 15,
              resultText: '文字は風化していて読み解けなかった。時間だけが過ぎた。',
              traitDelta: ActionLog(caution: 1),
            ),
          ],
        ),
        EventChoice(
          label: '無視する',
          riskHint: 'リスクなし',
          selectTrait: ActionLog(caution: 2, flexibility: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: '関わらないことにした。',
            ),
          ],
        ),
      ],
    ),
    */

    // 謎①：奇妙な光（環境の未知。好奇心/論理 ⇔ 回避/慎重。報酬＝最大HP増加・地図開示）
    GameEvent(
      id: 'mystery_light',
      title: '奇妙な光',
      description: '通路の奥に、脈打つように明滅する不思議な光が漂っている。',
      choices: [
        EventChoice(
          label: '近づいて調べる',
          riskHint: '未知に踏み込む（好奇心）',
          selectTrait: ActionLog(curiosity: 3, intuition: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.great, weight: 25,
              resultText: '光は忘れていた記憶に触れた。自分の芯を見つめ直し、心が強くなった。（最大HP+3）',
              resourceChanges: {'maxHp': 3},
              traitDelta: ActionLog(curiosity: 1),
            ),
            Outcome(
              tier: OutcomeTier.success, weight: 55,
              resultText: '光を観察するうち、この先の道の形が頭に浮かんだ。',
              revealCells: 3,
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 20,
              resultText: '光に触れた瞬間、鋭い頭痛が走った。',
              resourceChanges: {'hp': -4},
              traitDelta: ActionLog(caution: 1),
            ),
          ],
        ),
        EventChoice(
          label: 'そっと触れてみる',
          riskHint: '直感に賭ける（当たり外れ）',
          selectTrait: ActionLog(intuition: 2, curiosity: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.great, weight: 40,
              resultText: '温かい光が体を包んだ。心が少し強くなった。（最大HP+2）',
              resourceChanges: {'maxHp': 2},
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 60,
              resultText: '光は弾け、衝撃が全身を貫いた。',
              resourceChanges: {'hp': -5},
              traitDelta: ActionLog(persistence: 1),
            ),
          ],
        ),
        EventChoice(
          label: '関わらず進む',
          riskHint: 'リスクなし',
          selectTrait: ActionLog(caution: 1, planning: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: '得体の知れない光には近づかず、先へ進んだ。',
            ),
          ],
        ),
      ],
    ),

    // 謎②：もう一人の自分の声（内省。好奇心・論理 ⇔ 回避。心の迷宮テーマ。報酬＝最大HP・小回復）
    GameEvent(
      id: 'inner_voice',
      title: 'もう一人の自分の声',
      description: 'どこからともなく、自分によく似た声が問いかけてくる。「本当に、それでいいの？」',
      choices: [
        EventChoice(
          label: '耳を傾けて向き合う',
          riskHint: '自分と対話する（好奇心）',
          selectTrait: ActionLog(curiosity: 2, altruism: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.great, weight: 35,
              resultText: '声と対話するうち、隠れていた本音に気づいた。心が強くなった。（最大HP+4）',
              resourceChanges: {'maxHp': 4},
              traitDelta: ActionLog(curiosity: 1),
            ),
            Outcome(
              tier: OutcomeTier.success, weight: 45,
              resultText: '問いに正直に向き合うと、少し心が軽くなった。',
              resourceChanges: {'hp': 5},
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 20,
              resultText: '問いは胸の奥をえぐり、動揺が残った。',
              resourceChanges: {'hp': -3},
              traitDelta: ActionLog(caution: 1),
            ),
          ],
        ),
        EventChoice(
          label: '理屈で問い返す',
          riskHint: '冷静に考える（論理）',
          selectTrait: ActionLog(logic: 3, persistence: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 70,
              resultText: '冷静に問い返し、考えを整理できた。少し心が強くなった。（最大HP+2）',
              resourceChanges: {'maxHp': 2},
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 30,
              resultText: '理屈では割り切れず、もやもやだけが残った。',
              traitDelta: ActionLog(persistence: 1),
            ),
          ],
        ),
        EventChoice(
          label: '耳をふさいで先へ',
          riskHint: 'リスクなし・向き合わない',
          selectTrait: ActionLog(caution: 1, persistence: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: '声を振り切って先へ進んだ。',
            ),
          ],
        ),
      ],
    ),

    // 謎③：古い壁の記述（探究・知識。好奇心/論理・直感。報酬＝地図開示中心）
    GameEvent(
      id: 'wall_inscription',
      title: '古い壁の記述',
      description: '壁一面に、風化した文字と地図のような線が刻まれている。',
      choices: [
        EventChoice(
          label: 'じっくり読み解く',
          riskHint: '安全だが遅い（🍞-1・幼少〜）',
          extraFoodCost: 1,
          minStage: GrowthStage.young,
          selectTrait: ActionLog(curiosity: 2, logic: 2, persistence: 2),
          outcomes: [
            Outcome(
              tier: OutcomeTier.great, weight: 30,
              resultText: '記述はこの迷宮の構造を示していた。宝の在りかまで読み取れた。',
              revealTreasure: true,
            ),
            Outcome(
              tier: OutcomeTier.success, weight: 55,
              resultText: '記述を読み解き、この先の道が見えた。',
              revealCells: 3,
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 15,
              resultText: '文字は途中で崩れており、要領を得なかった。',
              traitDelta: ActionLog(caution: 1),
            ),
          ],
        ),
        EventChoice(
          label: '直感で意味を掴む',
          riskHint: 'ひらめきに賭ける（当たり外れ）',
          selectTrait: ActionLog(intuition: 3, flexibility: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.great, weight: 35,
              resultText: '直感が冴え、一気に先の道筋が見えた。',
              revealCells: 3,
            ),
            Outcome(
              tier: OutcomeTier.success, weight: 35,
              resultText: 'なんとなく進むべき方向を掴んだ。',
              revealCells: 1,
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 30,
              resultText: '直感は外れ、余計に混乱してしまった。',
              resourceChanges: {'hp': -2},
            ),
          ],
        ),
        EventChoice(
          label: '無視して進む',
          riskHint: 'リスクなし',
          selectTrait: ActionLog(caution: 1, flexibility: 2),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: '気に留めず先へ進んだ。',
            ),
          ],
        ),
      ],
    ),

    // 休憩所イベント
    GameEvent(
      id: 'rest_event',
      title: '焚き火の休憩所',
      description: '焚き火がある。疲れを癒せるが、時間と食料を使う。',
      choices: [
        EventChoice(
          label: 'ゆっくり休む',
          riskHint: '確定・食料を多く消費',
          selectTrait: ActionLog(planning: 1, caution: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.great, weight: 20,
              resultText: '十分に休んだ。焚き火のそばに残された回復薬まで見つけた。',
              resourceChanges: {'hp': 15, 'food': -3, 'items': 1},
              traitDelta: ActionLog(curiosity: 1),
            ),
            Outcome(
              tier: OutcomeTier.success, weight: 80,
              resultText: '十分に休んだ。体力が回復した。',
              resourceChanges: {'hp': 15, 'food': -3},
            ),
          ],
        ),
        EventChoice(
          label: '軽く休んで先へ進む',
          riskHint: '確定・食料を少し消費（成人）',
          minStage: GrowthStage.young,
          selectTrait: ActionLog(flexibility: 2, intuition: 2),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: '少し休んで体力を回復した。',
              resourceChanges: {'hp': 7, 'food': -1},
            ),
          ],
        ),
        EventChoice(
          label: '休まず進む',
          riskHint: 'リスクなし・体力温存',
          selectTrait: ActionLog(challenge: 1, persistence: 2),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: 'まだ余裕がある。先へ急いだ。',
            ),
          ],
        ),
      ],
    ),

    // 商人イベント（売買を繰り返せる店。描画は MerchantShopView が担当する）
    GameEvent(
      id: 'merchant_event',
      title: '行商人',
      description: '怪しげな行商人が荷車を引いている。「特別なものを売りますよ」と声をかけてきた。',
      isShop: true,
      choices: [],
    ),

    // 別れ道（枝道マップ自体が分岐のため二重で違和感 → 廃止。コメントで残置）
    /*
    GameEvent(
      id: 'crossroads',
      title: '別れ道',
      description: '道が三つに分かれている。右は明るい道、左は暗い道、まっすぐは霧の中。',
      choices: [
        EventChoice(
          label: '明るい右の道へ',
          riskHint: '安全・低リターン',
          selectTrait: ActionLog(caution: 1, planning: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: '安全な道だったが、特に何もなかった。',
              resourceChanges: {'food': -1},
            ),
          ],
        ),
        EventChoice(
          label: '暗い左の道へ',
          riskHint: '高リターンだが危険',
          selectTrait: ActionLog(curiosity: 2, intuition: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.great, weight: 25,
              resultText: '暗がりの奥に隠された宝の山を見つけた。無傷で持ち帰った。',
              resourceChanges: {'money': 6},
              traitDelta: ActionLog(intuition: 1),
            ),
            Outcome(
              tier: OutcomeTier.success, weight: 40,
              resultText: '暗い道の奥に隠れた宝を見つけた。しかし、少し傷ついた。',
              resourceChanges: {'money': 4, 'hp': -5},
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 35,
              resultText: '暗闇で何かにつまずき、転倒した。宝はなく、傷だけが残った。',
              resourceChanges: {'hp': -9},
              traitDelta: ActionLog(caution: 1),
            ),
          ],
        ),
        EventChoice(
          label: '霧の中のまっすぐな道へ',
          riskHint: '不確実（成人）',
          minStage: GrowthStage.young,
          selectTrait: ActionLog(curiosity: 2, intuition: 2),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 60,
              resultText: '霧の中に謎めいた場所があった。不思議な回復薬を入手。',
              resourceChanges: {'items': 1, 'hp': -3},
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 40,
              resultText: '霧の中で方向を見失い、ぐるぐると彷徨った。体力と食料を消耗しただけだった。',
              resourceChanges: {'hp': -3, 'food': -1},
              traitDelta: ActionLog(caution: 1),
            ),
          ],
        ),
      ],
    ),
    */

    // 仲間との出会い（相棒がいない時だけ発生する加入イベント）
    GameEvent(
      id: 'help_stranger',
      title: '助けを求める声',
      description: '茂みの中から弱々しい声が聞こえる。怪我をした冒険者・レオが倒れていた。',
      excludeWithCompanion: true,
      choices: [
        EventChoice(
          label: '回復薬で手当てする',
          riskHint: '回復薬消費・相手次第',
          upfrontCost: {'items': -1},
          requiresItem: true,
          selectTrait: ActionLog(altruism: 2, cooperation: 2),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 80,
              resultText: '回復薬で丁寧に手当てをした。レオは元気を取り戻し、共に行くことになった。',
              resourceChanges: {'bond': 2},
              recruitCompanion: 'レオ',
            ),
            Outcome(
              tier: OutcomeTier.failure, weight: 20,
              resultText: '手当てしたが傷は深く、レオは弱々しく礼を言って去っていった。',
              traitDelta: ActionLog(caution: 1),
            ),
          ],
        ),
        EventChoice(
          label: '食料を分ける',
          riskHint: '食料消費・相手次第',
          selectTrait: ActionLog(altruism: 2, cooperation: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.great, weight: 40,
              resultText: '食料を渡し励ますと、レオはすっかり元気を取り戻し、仲間になってくれた。',
              resourceChanges: {'food': -2, 'bond': 3},
              traitDelta: ActionLog(cooperation: 1),
              recruitCompanion: 'レオ',
            ),
            Outcome(
              tier: OutcomeTier.success, weight: 60,
              resultText: '食料を渡した。レオは感謝しつつ、まだ歩けるからと自分の道を行った。',
              resourceChanges: {'food': -2},
            ),
          ],
        ),
        EventChoice(
          label: '回復薬で確実に手当てする',
          riskHint: '安全・確実に仲間に（回復薬消費・🍞-1・幼少〜）',
          extraFoodCost: 1,
          upfrontCost: {'items': -1},
          minStage: GrowthStage.young,
          requiresItem: true,
          selectTrait: ActionLog(logic: 2, caution: 1, altruism: 2),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: '慎重に近づき、罠でないことを確認。回復薬で落ち着いて手当てし、レオは仲間になってくれた。',
              resourceChanges: {'bond': 1},
              recruitCompanion: 'レオ',
            ),
          ],
        ),
        EventChoice(
          label: '立ち去る',
          riskHint: 'リスクなし',
          selectTrait: ActionLog(persistence: 1, flexibility: 1),
          outcomes: [
            Outcome(
              tier: OutcomeTier.success, weight: 1,
              resultText: '余裕がなかった。自分のことで精一杯だ。',
            ),
          ],
        ),
      ],
    ),
  ];
}
