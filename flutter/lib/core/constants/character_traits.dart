/// キャラクター属性（得意・好き／苦手・注意）の定義
///
/// Cloud Functions の `src/utils/characterTraits.js` の TRAIT_LABELS と同じキーを使う。
/// 値は `details/current.<key>`、理由は `details/current.<key>_reason` に保存される。
library;

/// 詳細画面のタブ
enum TraitTab {
  /// 得意・好き
  positive,

  /// 苦手・注意
  caution,
}

/// 1つの属性の定義
class TraitDefinition {
  /// Firestore のフィールド名
  final String key;

  /// 画面に出す名前
  final String label;

  /// 表示するタブ
  final TraitTab tab;

  const TraitDefinition(this.key, this.label, this.tab);

  /// 理由のフィールド名
  String get reasonKey => '${key}_reason';
}

/// 詳細画面に出す属性（表示順）。夢は `dream/current` から読むため含めない
const List<TraitDefinition> kCharacterTraits = [
  // 得意・好き
  TraitDefinition('favorite_color', '好きな色', TraitTab.positive),
  TraitDefinition('favorite_place', '好きな場所', TraitTab.positive),
  TraitDefinition('favorite_word', '口癖', TraitTab.positive),
  TraitDefinition('word_tendency', '話し方の特徴', TraitTab.positive),
  TraitDefinition('strength', '長所', TraitTab.positive),
  TraitDefinition('skill', '特技', TraitTab.positive),
  TraitDefinition('hobby', '趣味', TraitTab.positive),
  TraitDefinition('aptitude', '適性', TraitTab.positive),
  TraitDefinition('energizer', '元気が出ること', TraitTab.positive),
  // 苦手・注意
  TraitDefinition('uneasy_place', '落ち着かない場所', TraitTab.caution),
  TraitDefinition('trigger_word', '言われるとモヤっとする言葉', TraitTab.caution),
  TraitDefinition('disliked_approach', '苦手な接し方', TraitTab.caution),
  TraitDefinition('weakness', '短所', TraitTab.caution),
  TraitDefinition('weak_task', '苦手な作業', TraitTab.caution),
  TraitDefinition('uninterested', '興味が湧きにくいこと', TraitTab.caution),
  TraitDefinition('unsuited_environment', '向いていない環境・役割', TraitTab.caution),
  TraitDefinition('feared_self', 'なりたくない自分', TraitTab.caution),
  TraitDefinition('dislike', '嫌いなこと', TraitTab.caution),
  TraitDefinition('stress_trigger', 'ストレスを感じる瞬間', TraitTab.caution),
];

/// 夢を表すペアのキー（夢は `details/current` ではなく `dream/current` から読む）
const String kDreamPairKey = 'dream';

/// 詳細画面の行の並び（得意・好き ↔ 苦手・注意 の対）
///
/// タブを切り替えても対の項目が同じ高さに来るよう、この順で並べて各行の高さを揃える。
/// 好きな色には対がないため、嫌いなことを同じ行に置く。
const List<(String, String)> kTraitPairs = [
  ('favorite_color', 'dislike'),
  ('favorite_place', 'uneasy_place'),
  ('favorite_word', 'trigger_word'),
  ('word_tendency', 'disliked_approach'),
  ('strength', 'weakness'),
  ('skill', 'weak_task'),
  ('hobby', 'uninterested'),
  ('aptitude', 'unsuited_environment'),
  ('energizer', 'stress_trigger'),
  (kDreamPairKey, 'feared_self'),
];

/// キーから定義を引く
TraitDefinition? traitDefinitionOf(String key) {
  for (final t in kCharacterTraits) {
    if (t.key == key) return t;
  }
  return null;
}

/// 性格のリセットで消すフィールド（値と理由）
List<String> get kCharacterTraitFieldsToReset => [
      for (final t in kCharacterTraits) ...[t.key, t.reasonKey],
    ];
