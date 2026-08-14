// functions/utils/generatePersonalityKey.js

/** Big5の各項目とキーの接頭辞の対応 */
const KEY_PREFIXES = {
  openness: "O",
  conscientiousness: "C",
  extraversion: "E",
  agreeableness: "A",
  neuroticism: "N",
};

/**
 * 丸め境界を越えたと認めるための余裕（ヒステリシス）
 *
 * スコアは10シグナルごとに更新されるため、3.49 と 3.51 を往復するだけで
 * 丸め値が 3↔4 と変わり、そのたびに詳細と夢の候補が作り直されてしまう。
 * 境界（x.5）から この値ぶん離れて初めてキーの変更を認める。
 */
const KEY_CHANGE_MARGIN = 0.15;

/**
 * Big5スコアと性別から一意のpersonalityKeyを生成する
 * @param {Object} big5 - Big5スコア（openness, conscientiousnessなど）
 * @param {string} gender - 性別（male/female）省略可能、後方互換性のため
 * @return {string} - personalityKey（例: O3_C3_E3_A3_N3_female）
 */
function generatePersonalityKey(big5, gender) {
  const baseKey = (
    `O${Math.round(big5.openness)}_C${Math.round(big5.conscientiousness)}_` +
    `E${Math.round(big5.extraversion)}_A${Math.round(big5.agreeableness)}_` +
    `N${Math.round(big5.neuroticism)}`
  );

  // genderが指定されている場合は末尾に追加
  return gender ? `${baseKey}_${gender}` : baseKey;
}

/**
 * personalityKey を項目ごとの値と性別に分解する
 *
 * 並び順が違う旧形式（例 `O3_C3_A3_E3_N3`）や、丸めていない小数を含む
 * 旧データ（例 `O4.77..._C2.46..._男性`）も読めるよう、位置ではなく
 * 接頭辞で解釈する。
 *
 * @param {string} key - personalityKey
 * @return {{values: Object, gender: string}|null} - 解釈できない場合は null
 */
function parsePersonalityKey(key) {
  if (typeof key !== "string" || !key) return null;

  const values = {};
  let gender = "";
  for (const part of key.split("_")) {
    const matched = /^([OCEAN])(-?\d+(?:\.\d+)?)$/.exec(part);
    if (matched) {
      values[matched[1]] = Number(matched[2]);
    } else if (part) {
      gender = part;
    }
  }

  // 5項目そろっていなければ解釈できなかったものとして扱う
  if (Object.keys(values).length !== 5) return null;
  return {values, gender};
}

/**
 * 性格キーが「はっきりと」変わったかどうかを判定する
 *
 * タイプ名や元素が変わらなくても Big5スコアは動き続けるため、これを見ないと
 * 属性・夢の候補が古い性格のまま残る。一方でスコアは丸め境界付近で往復する
 * ため、境界から KEY_CHANGE_MARGIN 以上離れたときだけ変更と認める。
 *
 * @param {string} prevKey - 保存されている personalityKey
 * @param {Object} big5 - 現在の Big5スコア（連続値）
 * @param {string} gender - 現在の性別
 * @return {boolean} - 詳細・夢の候補を作り直すべきなら true
 */
function hasDecisiveKeyChange(prevKey, big5, gender) {
  if (!big5) return false;

  const parsed = parsePersonalityKey(prevKey);
  // キーが無い・旧形式で読めない場合は作り直す（今のスコアに合わせ直すため）
  if (!parsed) return true;

  // 性別が変われば同じスコアでも別のキーになる
  if ((parsed.gender || "") !== (gender || "")) return true;

  for (const [field, prefix] of Object.entries(KEY_PREFIXES)) {
    const score = Number(big5[field]);
    if (!Number.isFinite(score)) continue;

    // 旧データは小数のまま保存されているため、比較前に丸める
    const prevValue = Math.round(parsed.values[prefix]);
    const nextValue = Math.round(score);
    if (prevValue === nextValue) continue;

    // 丸め境界（prevValue ± 0.5）から余裕ぶん離れているか
    // 3.65 - 3.5 が 0.1499999… になる浮動小数の誤差を吸収する
    const boundary = nextValue > prevValue ? prevValue + 0.5 : prevValue - 0.5;
    if (Math.abs(score - boundary) >= KEY_CHANGE_MARGIN - 1e-9) return true;
  }

  return false;
}

module.exports = {
  KEY_CHANGE_MARGIN,
  generatePersonalityKey,
  parsePersonalityKey,
  hasDecisiveKeyChange,
};
