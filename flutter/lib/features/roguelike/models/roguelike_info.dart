// features/roguelike/models/roguelike_info.dart
//
// 結果画面の表示用メタ情報（特性の説明・アイコン、元素の説明・アイコン）。

/// 10行動特性のアイコン（絵文字）と説明。
class TraitInfo {
  final String emoji;
  final String description;
  const TraitInfo(this.emoji, this.description);

  static const Map<String, TraitInfo> all = {
    '挑戦性': TraitInfo('⚔️', '危険や困難に立ち向かう力'),
    '慎重性': TraitInfo('🛡️', 'リスクを見極め慎重に進む力'),
    '好奇心': TraitInfo('🔍', '新しいものに興味を持つ力'),
    '計画性': TraitInfo('📋', '先を見据えて段取りする力'),
    '直感性': TraitInfo('💡', '理屈より直感で動く力'),
    '論理性': TraitInfo('🧠', '物事を筋道立てて考える力'),
    '協調性': TraitInfo('👥', '周囲と歩調を合わせる力'),
    '利他性': TraitInfo('💗', '他者を思いやる優しさ'),
    '執着性': TraitInfo('🎯', '諦めずやり遂げる粘り強さ'),
    '柔軟性': TraitInfo('🌿', '状況に応じて切り替える力'),
  };

  static TraitInfo of(String trait) => all[trait] ?? const TraitInfo('✨', '');
}

/// 特性を**日常でどう活かすか**の橋渡し。
///
/// 「◯◯が光る冒険でした」で終わると「そうですか」で流されてしまう。
/// 冒険での振る舞いを現実の場面に翻訳し、次の一歩まで示すためのテキスト。
class TraitAdvice {
  /// 冒険中に何をしていたか（事実の言い換え）。
  final String inGame;

  /// それが日常のどんな場面で効くか。
  final String inLife;

  /// 次に試すと良い具体的な一歩。
  final String tryNext;

  const TraitAdvice({
    required this.inGame,
    required this.inLife,
    required this.tryNext,
  });

  static const Map<String, TraitAdvice> all = {
    '挑戦性': TraitAdvice(
      inGame: '危ない道でも自分から踏み込んでいました',
      inLife: '迷ったときに動ける人です。周りが様子見をしている場面で最初の一歩を出せます',
      tryNext: '「やってみたいけど迷っている」ことを一つ、今週中に始めてみましょう',
    ),
    '慎重性': TraitAdvice(
      inGame: '危険を見極めてから動いていました',
      inLife: '失敗の芽を先に潰せる人です。あなたが確認するから防げていることが必ずあります',
      tryNext: '慎重さは強みです。ただ「調べる時間」に上限を決めると、決断が軽くなります',
    ),
    '好奇心': TraitAdvice(
      inGame: '未知のものを見ると近づかずにいられませんでした',
      inLife: '情報を自分から取りに行ける人です。新しい分野への入り口を見つけるのが得意です',
      tryNext: '気になって調べたことを誰かに話してみましょう。人に話すと知識が定着します',
    ),
    '計画性': TraitAdvice(
      inGame: '先を見越して備えてから動いていました',
      inLife: '段取りで物事を前に進められる人です。締切に追われにくいのが強みです',
      tryNext: '計画が崩れた日の予備プランも用意しておくと、さらに強くなります',
    ),
    '直感性': TraitAdvice(
      inGame: '理屈より「なんとなくこっち」で選んでいました',
      inLife: '判断が速い人です。情報が足りない場面でも止まらずに進めます',
      tryNext: '直感で決めたあと、理由を一行だけ書き残すと、勘が言葉になって人にも伝わります',
    ),
    '論理性': TraitAdvice(
      inGame: '状況を分析してから手を選んでいました',
      inLife: '筋道を立てて考えられる人です。こじれた話を整理する役割に向いています',
      tryNext: '正しさだけでなく「相手がどう感じるか」を一つ足すと、その力がもっと通ります',
    ),
    '協調性': TraitAdvice(
      inGame: '一人で抱えず、仲間と足並みを揃えていました',
      inLife: '場の空気を保てる人です。あなたがいるとチームが動きやすくなります',
      tryNext: '合わせるだけでなく、自分の希望も一つ言葉にしてみましょう。遠慮は伝わりません',
    ),
    '利他性': TraitAdvice(
      inGame: '自分の余裕を削ってでも他者を助けていました',
      inLife: '人の困りごとに気づける人です。頼られることが多いのではないでしょうか',
      tryNext: '人を助ける前に、自分の余力を確認する習慣を。あなたが倒れると誰も助けられません',
    ),
    '執着性': TraitAdvice(
      inGame: '一度決めたものを手放さずやり切っていました',
      inLife: '続けられる人です。成果が出るまで時間がかかることほど、あなたに向いています',
      tryNext: '「もう手放していいもの」を一つ探してみましょう。空いた分だけ次が入ります',
    ),
    '柔軟性': TraitAdvice(
      inGame: '状況が変わると、こだわらずやり方を変えていました',
      inLife: '想定外に強い人です。計画が崩れても立て直せます',
      tryNext: '切り替えが早いぶん、続けると効くことは意識して残しましょう',
    ),
  };

  static TraitAdvice? of(String trait) => all[trait];

  /// **最も高い特性1つ**から、日常への橋渡し文を組み立てる。
  ///
  /// 「冒険で何をしていたか → それは日常のどこで効くか → 次に何を試すか」を
  /// 一続きの文章にする。箇条書きにすると読み飛ばされ、特性名だけだと
  /// 他人事になるため、冒険での具体的な振る舞いから入る。
  ///
  /// 結果画面・シェアカード・図鑑のボス詳細で同じ文を使う。
  /// [compact] が true のときは1段落に詰める（シェアカード用）。
  static String messageFor(String trait, {bool compact = false}) {
    final a = all[trait];
    if (a == null) return '';
    if (compact) {
      return '${a.inGame}。それが$traitです。\n${a.tryNext}。';
    }
    return '今回の冒険で、あなたは${a.inGame}。'
        'そこに出ていたのが$traitです。\n\n'
        'これは冒険の中だけの話ではありません。${a.inLife}。\n\n'
        '${a.tryNext}。';
  }
}

/// 元素のアイコン（絵文字）と一言。
class ElementInfo {
  final String emoji;
  final String description;
  const ElementInfo(this.emoji, this.description);

  static const Map<String, ElementInfo> all = {
    '炎': ElementInfo('🔥', '直感的に行動し、困難にも立ち向かう情熱を持っています。'),
    '水': ElementInfo('💧', '周囲を受け入れ、つながりを大切にする穏やかさがあります。'),
    '風': ElementInfo('🍃', '好奇心旺盛で、変化を楽しむ自由さがあります。'),
    '土': ElementInfo('⛰️', '堅実に物事を積み上げる安定感があります。'),
    '雷': ElementInfo('⚡', '直感を瞬時に行動へ変える瞬発力があります。'),
    '氷': ElementInfo('❄️', '冷静に内へ意識を向ける、研ぎ澄まされた感覚があります。'),
    '光': ElementInfo('☀️', '理性的に他者と関わり、場を照らす明るさがあります。'),
    '闇': ElementInfo('🌑', '物事を深く内省する思慮深さがあります。'),
    '無': ElementInfo('🌫️', '特定の型に偏らず、状況に応じて行動を変えます。'),
  };

  static ElementInfo of(String element) => all[element] ?? all['無']!;
}
