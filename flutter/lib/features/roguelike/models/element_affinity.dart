// features/roguelike/models/element_affinity.dart
//
// 本編キャラの元素をローグライク戦闘に絡めるための相性ロジック。
// プレイヤー（本編）の元素と敵の元素の相性で、与ダメ/被ダメに倍率がかかる。
// 元素はすべて単漢字（'炎''水''風''土''氷''雷''光''闇''無'）で扱う
// （本編 CharacterDetails.element・推定元素と語彙が一致している）。

/// 本編の鏡構造（対極ペア）。炎↔水・風↔土・雷↔氷・光↔闇。
/// 各元素の気質は「対極の悩み」を乗り越える解毒剤を持つ＝得意。
const Map<String, String> _mirror = {
  '炎': '水', '水': '炎',
  '風': '土', '土': '風',
  '雷': '氷', '氷': '雷',
  '光': '闇', '闇': '光',
};

/// プレイヤー元素 vs 敵元素 の相性。
enum ElementMatch { advantage, disadvantage, neutral }

/// プレイヤー（本編）の元素 [player] が敵の元素 [enemy] に対して有利か。
/// - 対極（鏡）の悩み＝得意（有利）: 自分の気質が乗り越える術を持つ相手。
/// - 同じ元素の悩み＝苦手（不利）: 自分の気質そのものの影なので手強い。
/// - それ以外、またはどちらかが '無' なら互角。
ElementMatch elementMatch(String player, String enemy) {
  if (player == '無' || enemy == '無') return ElementMatch.neutral;
  if (_mirror[player] == enemy) return ElementMatch.advantage;
  if (player == enemy) return ElementMatch.disadvantage;
  return ElementMatch.neutral;
}

/// 与ダメ倍率（有利なら増える）。
double playerDamageMultiplier(ElementMatch m) => switch (m) {
      ElementMatch.advantage => 1.4,
      ElementMatch.disadvantage => 0.7,
      ElementMatch.neutral => 1.0,
    };

/// 敵反撃ダメージ倍率（有利なら減る）。
double enemyCounterMultiplier(ElementMatch m) => switch (m) {
      ElementMatch.advantage => 0.75,
      ElementMatch.disadvantage => 1.3,
      ElementMatch.neutral => 1.0,
    };

/// プレイヤーの元素ごとの攻撃技名（戦闘メッセージ用）。
const Map<String, String> elementSkillName = {
  '炎': '火炎の一撃',
  '水': '清流の一打',
  '風': '疾風の斬撃',
  '土': '大地の重撃',
  '氷': '氷結の刃',
  '雷': '雷光の貫き',
  '光': '光輝の裁き',
  '闇': '深淵の一撃',
  '無': '渾身の一撃',
};

String skillNameOf(String? element) => elementSkillName[element] ?? elementSkillName['無']!;

/// 相性バッジ用の短いラベル。
String matchLabel(ElementMatch m) => switch (m) {
      ElementMatch.advantage => '有利',
      ElementMatch.disadvantage => '不利',
      ElementMatch.neutral => '互角',
    };
