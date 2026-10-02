// src/utils/characterTraits.js - キャラクター属性（得意・好き／苦手・注意）の定義と、プロンプトへの渡し方

/**
 * 理由を持つ属性のキーと表示名
 *
 * characterDetails プロンプトの出力・details/current の保存・Flutter の詳細画面で同じキーを使う。
 * 理由は `<キー>_reason` に保存する。
 */
const TRAIT_LABELS = {
  // 得意・好き
  favorite_color: "好きな色",
  favorite_place: "好きな場所",
  favorite_word: "口癖",
  word_tendency: "話し方の特徴",
  strength: "長所",
  skill: "特技",
  hobby: "趣味",
  aptitude: "適性",
  energizer: "元気が出ること",
  // 苦手・注意
  uneasy_place: "落ち着かない場所",
  trigger_word: "言われるとモヤっとする言葉",
  disliked_approach: "苦手な接し方",
  weakness: "短所",
  weak_task: "苦手な作業",
  uninterested: "興味が湧きにくいこと",
  unsuited_environment: "向いていない環境・役割",
  feared_self: "なりたくない自分",
  dislike: "嫌いなこと",
  stress_trigger: "ストレスを感じる瞬間",
};

/** 理由を持つ属性のキー（プロンプトの出力順） */
const TRAIT_KEYS = Object.keys(TRAIT_LABELS);

/** 理由を持たない属性（画面に出していない） */
const PLAIN_ATTRIBUTE_KEYS = ["favorite_entertainment_genre"];

/** 今回の拡張（2026-10-02）で足した属性。テンプレートが揃っているかの判定に使う */
const ADDED_TRAIT_KEYS = [
  "energizer",
  "uneasy_place",
  "trigger_word",
  "disliked_approach",
  "weak_task",
  "uninterested",
  "unsuited_environment",
  "feared_self",
  "dislike",
  "stress_trigger",
];

/**
 * 機能ごとにプロンプトへ渡す属性（値だけ。理由は渡さない）
 *
 * 得意・好きと苦手・注意の両方を渡して偏らないようにする（設計書「各機能への反映」）。
 * 夢は別経路（dream/current）で渡すためここには含めない。
 */
const CHAT_TRAIT_KEYS = ["hobby", "energizer", "dislike", "disliked_approach", "stress_trigger"];
/** 日記（口癖・話し方・長所は既存の書式で渡しているため除く） */
const DIARY_TRAIT_KEYS = ["energizer", "dislike", "disliked_approach", "stress_trigger"];
/** 自分会議（今の自分・本音の2人格と会議の前提にだけ渡す） */
const MEETING_TRAIT_KEYS = ["strength", "energizer", "weakness", "dislike", "stress_trigger", "feared_self"];
/** フレンドに聞く（相手の属性） */
const FRIEND_TRAIT_KEYS = [
  "hobby", "favorite_place", "energizer",
  "trigger_word", "disliked_approach", "dislike", "uninterested",
];

/**
 * 理由のフィールド名を返す
 * @param {string} key - 属性のキー
 * @return {string} - `<キー>_reason`
 */
function reasonKey(key) {
  return `${key}_reason`;
}

/** 改行・タブを含む制御文字 */
const CONTROL_CHARS = /[\u0000-\u001F\u007F]+/g;

/**
 * プロンプトに埋め込む値を1行に整える
 * @param {*} value - 値
 * @param {number} maxLength - 最大文字数（コードポイント単位）
 * @return {string} - 整えた値（不正な場合は空文字）
 */
function oneLine(value, maxLength = 40) {
  if (typeof value !== "string") return "";
  const collapsed = value.replace(CONTROL_CHARS, " ").replace(/\s+/g, " ").trim();
  return Array.from(collapsed).slice(0, maxLength).join("");
}

/**
 * 属性の値を「表示名: 値」の行にする（値が無い項目は飛ばす）
 * @param {Object} details - details/current のデータ
 * @param {string[]} keys - 使う属性のキー
 * @return {string[]} - 行の配列
 */
function traitLines(details, keys) {
  if (!details) return [];
  const lines = [];
  for (const key of keys) {
    const value = oneLine(details[key]);
    if (value && value !== "未設定") lines.push(`${TRAIT_LABELS[key]}: ${value}`);
  }
  return lines;
}

/**
 * 参考情報として渡す属性ブロックを作る
 *
 * AI が「渡された情報は必ず使うもの」と受け取って文脈に関係なく持ち出さないよう、
 * 使ってよい条件を同じブロックに書く（「覚えていること」と同じ書き方）。
 * 理由は渡さない（プロンプトを伸ばさず、理由を読み上げさせないため）。
 *
 * @param {Object} details - details/current のデータ
 * @param {string[]} keys - 使う属性のキー
 * @param {string} title - 見出し
 * @return {string} - ブロック（項目が1つも無ければ空文字）
 */
function buildTraitReferenceBlock(details, keys, title = "【性格の参考情報】") {
  const lines = traitLines(details, keys);
  if (lines.length === 0) return "";
  return `${title}\n${lines.join("\n")}\n（今の話題に直接関係するときだけ自然に踏まえる。関係なければ一切触れない。項目名や文言をそのまま言わない。苦手・嫌いなことを勧めない）`;
}

module.exports = {
  CHAT_TRAIT_KEYS,
  DIARY_TRAIT_KEYS,
  MEETING_TRAIT_KEYS,
  FRIEND_TRAIT_KEYS,
  TRAIT_LABELS,
  TRAIT_KEYS,
  PLAIN_ATTRIBUTE_KEYS,
  ADDED_TRAIT_KEYS,
  reasonKey,
  oneLine,
  traitLines,
  buildTraitReferenceBlock,
};
