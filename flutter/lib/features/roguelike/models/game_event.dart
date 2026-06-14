// features/roguelike/models/game_event.dart

import 'game_state.dart';
import 'action_log.dart';

class EventChoice {
  final String label;
  final String resultText;
  final Map<String, int> resourceChanges; // hp / food / money / items / bond
  final ActionLog traitDelta;
  final GrowthStage minStage;

  const EventChoice({
    required this.label,
    required this.resultText,
    this.resourceChanges = const {},
    this.traitDelta = const ActionLog(),
    this.minStage = GrowthStage.baby,
  });
}

class GameEvent {
  final String id;
  final String title;
  final String description;
  final List<EventChoice> choices;

  const GameEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.choices,
  });
}

// 全イベント定義
class GameEvents {
  static List<EventChoice> forStage(List<EventChoice> all, GrowthStage stage) =>
      all.where((c) => c.minStage.index <= stage.index).toList();

  static final List<GameEvent> all = [
    // 宝箱イベント
    GameEvent(
      id: 'chest_old',
      title: '古い宝箱',
      description: '苔むした宝箱を見つけた。罠が仕掛けられているかもしれない。',
      choices: [
        EventChoice(
          label: 'すぐ開ける',
          resultText: '勢いよく開けた！金貨が入っていた。しかし、仕掛けられていた針が手を刺した。',
          resourceChanges: {'money': 5, 'hp': -5},
          traitDelta: ActionLog(challenge: 2, intuition: 1),
        ),
        EventChoice(
          label: '周囲を調べてから開ける',
          resultText: '丁寧に調べると罠を発見。解除して安全に金貨を得た。',
          resourceChanges: {'money': 3},
          traitDelta: ActionLog(caution: 2, logic: 1),
          minStage: GrowthStage.young,
        ),
        EventChoice(
          label: 'アイテムで罠を解除する',
          resultText: '道具を使い、完璧に罠を解除。中の宝を全部持ち出した。',
          resourceChanges: {'money': 6, 'items': -1},
          traitDelta: ActionLog(planning: 2, logic: 1),
          minStage: GrowthStage.young,
        ),
        EventChoice(
          label: '無視して進む',
          resultText: 'リスクを避けて先へ進んだ。',
          resourceChanges: {},
          traitDelta: ActionLog(caution: 1, planning: 1),
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
          resultText: '旅人は地図の情報を教えてくれた。道がひとつ明らかになった。',
          resourceChanges: {'food': -1},
          traitDelta: ActionLog(altruism: 2, cooperation: 1),
        ),
        EventChoice(
          label: '食料を分ける',
          resultText: '食料を渡すと、旅人は涙を流して感謝した。何か良いことをした気がする。',
          resourceChanges: {'food': -3, 'bond': 2},
          traitDelta: ActionLog(altruism: 3, cooperation: 2),
        ),
        EventChoice(
          label: 'お金を渡す',
          resultText: '旅人は喜び、お礼に貴重なアイテムをくれた。',
          resourceChanges: {'money': -2, 'items': 1, 'bond': 1},
          traitDelta: ActionLog(altruism: 2, flexibility: 1),
          minStage: GrowthStage.young,
        ),
        EventChoice(
          label: '立ち去る',
          resultText: '急ぎ足で通り過ぎた。',
          resourceChanges: {},
          traitDelta: ActionLog(planning: 1),
        ),
      ],
    ),

    // 険しい道
    GameEvent(
      id: 'steep_road',
      title: '険しい崖道',
      description: '目の前に険しい崖道がある。安全な迂回路もあるが時間がかかる。',
      choices: [
        EventChoice(
          label: '崖道を進む',
          resultText: '足を滑らせ少し傷ついたが、時間を節約できた。',
          resourceChanges: {'hp': -8, 'food': -1},
          traitDelta: ActionLog(challenge: 3, intuition: 1),
        ),
        EventChoice(
          label: '迂回路を行く',
          resultText: '安全に迂回した。食料を余計に使ったが無事だった。',
          resourceChanges: {'food': -3},
          traitDelta: ActionLog(caution: 2, planning: 1),
        ),
        EventChoice(
          label: '仲間に先に行かせて観察する',
          resultText: '仲間の様子から安全ルートを見つけた。うまく渡りきった。',
          resourceChanges: {'bond': -1},
          traitDelta: ActionLog(logic: 2, caution: 1, cooperation: 1),
          minStage: GrowthStage.adult,
        ),
      ],
    ),

    // 廃墟の探索
    GameEvent(
      id: 'ruins',
      title: '廃墟の発見',
      description: '古い廃墟がある。中に何かがあるかもしれないし、危険かもしれない。',
      choices: [
        EventChoice(
          label: '入って探索する',
          resultText: '奥に壊れた宝箱を発見。中に古い薬が残っていた。',
          resourceChanges: {'hp': 5, 'items': 1},
          traitDelta: ActionLog(curiosity: 3, challenge: 1),
        ),
        EventChoice(
          label: '入口だけ確認して引き返す',
          resultText: '危険はなかったが、特に収穫もなかった。',
          resourceChanges: {},
          traitDelta: ActionLog(caution: 2, curiosity: 1),
          minStage: GrowthStage.young,
        ),
        EventChoice(
          label: '無視して進む',
          resultText: '時間を無駄にせず先へ進んだ。',
          resourceChanges: {},
          traitDelta: ActionLog(planning: 1),
        ),
      ],
    ),

    // 仲間の疲労
    GameEvent(
      id: 'companion_tired',
      title: '仲間の疲労',
      description: '仲間が「もう限界です…」とうずくまった。このまま進むか、休憩を取るか。',
      choices: [
        EventChoice(
          label: '休憩を取る',
          resultText: '少し休むと仲間が回復した。絆が深まった気がする。',
          resourceChanges: {'food': -2, 'bond': 3, 'hp': 5},
          traitDelta: ActionLog(altruism: 3, cooperation: 2),
        ),
        EventChoice(
          label: '食料を渡して励ます',
          resultText: '食料と言葉で仲間を元気づけた。なんとか続けられそうだ。',
          resourceChanges: {'food': -2, 'bond': 1},
          traitDelta: ActionLog(altruism: 2, cooperation: 1),
          minStage: GrowthStage.young,
        ),
        EventChoice(
          label: '先を急ぐよう説得する',
          resultText: '仲間はなんとか立ち上がった。しかし少し距離ができた。',
          resourceChanges: {'bond': -1},
          traitDelta: ActionLog(planning: 2, persistence: 1),
          minStage: GrowthStage.adult,
        ),
      ],
    ),

    // 謎の扉
    GameEvent(
      id: 'mysterious_door',
      title: '謎の扉',
      description: '岩壁に不思議な扉が埋まっている。鍵穴があるが、鍵は持っていない。',
      choices: [
        EventChoice(
          label: '体当たりで開けようとする',
          resultText: '扉は動かなかった。肩が少し痛い。',
          resourceChanges: {'hp': -3},
          traitDelta: ActionLog(challenge: 2, persistence: 1),
        ),
        EventChoice(
          label: 'アイテムで鍵穴をこじ開ける',
          resultText: '巧みに鍵穴を操作して扉を開けた。中に回復薬があった。',
          resourceChanges: {'items': -1, 'hp': 10},
          traitDelta: ActionLog(curiosity: 2, logic: 2),
          minStage: GrowthStage.young,
        ),
        EventChoice(
          label: '調べて手がかりを探す',
          resultText: '扉の文字を読み解くと、近くに隠し鍵を発見した。扉の中に金貨が！',
          resourceChanges: {'money': 4},
          traitDelta: ActionLog(logic: 3, curiosity: 2),
          minStage: GrowthStage.adult,
        ),
        EventChoice(
          label: '無視する',
          resultText: '関わらないことにした。',
          resourceChanges: {},
          traitDelta: ActionLog(caution: 1),
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
          resultText: '十分に休んだ。体力が回復した。',
          resourceChanges: {'hp': 15, 'food': -3},
          traitDelta: ActionLog(planning: 1, caution: 1),
        ),
        EventChoice(
          label: '軽く休んで先へ進む',
          resultText: '少し休んで体力を回復した。',
          resourceChanges: {'hp': 7, 'food': -1},
          traitDelta: ActionLog(flexibility: 1),
          minStage: GrowthStage.young,
        ),
        EventChoice(
          label: '休まず進む',
          resultText: 'まだ余裕がある。先へ急いだ。',
          resourceChanges: {},
          traitDelta: ActionLog(challenge: 1, persistence: 1),
        ),
      ],
    ),

    // 商人イベント
    GameEvent(
      id: 'merchant_event',
      title: '行商人',
      description: '怪しげな行商人が荷車を引いている。「特別なものを売りますよ」と声をかけてきた。',
      choices: [
        EventChoice(
          label: '回復薬を買う（金貨3）',
          resultText: '回復薬を手に入れた。いざとなればこれで乗り切れる。',
          resourceChanges: {'money': -3, 'items': 1},
          traitDelta: ActionLog(planning: 2),
        ),
        EventChoice(
          label: '情報を買う（金貨2）',
          resultText: 'この先の地図情報を教えてもらった。',
          resourceChanges: {'money': -2},
          traitDelta: ActionLog(logic: 2, curiosity: 1),
          minStage: GrowthStage.young,
        ),
        EventChoice(
          label: '値切り交渉する',
          resultText: 'うまく値切って回復薬を安く手に入れた。',
          resourceChanges: {'money': -1, 'items': 1},
          traitDelta: ActionLog(flexibility: 2, logic: 1),
          minStage: GrowthStage.adult,
        ),
        EventChoice(
          label: '何も買わない',
          resultText: '今は不要と判断して立ち去った。',
          resourceChanges: {},
          traitDelta: ActionLog(caution: 1),
        ),
      ],
    ),

    // 別れ道
    GameEvent(
      id: 'crossroads',
      title: '別れ道',
      description: '道が三つに分かれている。右は明るい道、左は暗い道、まっすぐは霧の中。',
      choices: [
        EventChoice(
          label: '明るい右の道へ',
          resultText: '安全な道だったが、特に何もなかった。',
          resourceChanges: {'food': -1},
          traitDelta: ActionLog(caution: 1),
        ),
        EventChoice(
          label: '暗い左の道へ',
          resultText: '暗い道の奥に隠れた宝を見つけた。しかし、少し傷ついた。',
          resourceChanges: {'money': 4, 'hp': -5},
          traitDelta: ActionLog(curiosity: 3, challenge: 2),
        ),
        EventChoice(
          label: '霧の中のまっすぐな道へ',
          resultText: '霧の中に謎めいた場所があった。不思議なアイテムを入手。',
          resourceChanges: {'items': 1, 'hp': -3},
          traitDelta: ActionLog(curiosity: 2, intuition: 2),
          minStage: GrowthStage.young,
        ),
      ],
    ),

    // 仲間への助け
    GameEvent(
      id: 'help_stranger',
      title: '助けを求める声',
      description: '茂みの中から弱々しい声が聞こえる。怪我をした冒険者が倒れていた。',
      choices: [
        EventChoice(
          label: 'アイテムで手当てする',
          resultText: '丁寧に手当てをした。冒険者は感謝し、情報を教えてくれた。',
          resourceChanges: {'items': -1, 'bond': 2},
          traitDelta: ActionLog(altruism: 3, cooperation: 2),
        ),
        EventChoice(
          label: '食料を分ける',
          resultText: '食料を渡し、励ました。仲間になってくれた。',
          resourceChanges: {'food': -2, 'bond': 3},
          traitDelta: ActionLog(altruism: 3, cooperation: 1),
        ),
        EventChoice(
          label: '状況を確認してから判断する',
          resultText: '慎重に近づき、罠でないことを確認。安全に助けることができた。',
          resourceChanges: {'items': -1, 'bond': 1},
          traitDelta: ActionLog(logic: 2, caution: 2, altruism: 1),
          minStage: GrowthStage.young,
        ),
        EventChoice(
          label: '立ち去る',
          resultText: '余裕がなかった。自分のことで精一杯だ。',
          resourceChanges: {},
          traitDelta: ActionLog(persistence: 1),
        ),
      ],
    ),
  ];
}
