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
