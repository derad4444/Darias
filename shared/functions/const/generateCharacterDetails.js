const OpenAI = require("openai");
const admin = require("firebase-admin");
const {generatePersonalityKey} = require("./generatePersonalityKey");
const {generateBig5Analysis} = require("./generateBig5Analysis");
const {OPTIMIZED_PROMPTS, stripQuotes} = require("../src/prompts/templates");
const {normalizeDreamOptions, sanitizeDream, saveDreamOptions} = require("../src/utils/dreamStore");
const {TRAIT_KEYS, PLAIN_ATTRIBUTE_KEYS, ADDED_TRAIT_KEYS, reasonKey, oneLine} = require("../src/utils/characterTraits");

// Firebase Admin初期化（デフォルトアプリの存在を確認して初期化）
try { admin.app(); } catch (e) { admin.initializeApp(); }
const db = admin.firestore();

/**
 * 性格ごとの共有テンプレートコレクション
 * プロンプトの入力は「四捨五入したBig5 5値 + 性別」= personalityKey と1対1なので、
 * 同じ personalityKey なら生成結果を使い回してよい（Big5Analysis と同じ方針）。
 */
const TEMPLATE_COLLECTION = "CharacterDetailsTemplate";

/** 共有テンプレートの生成に使うモデル（ユーザーごとではなく性格ごとに1回なので上位モデルを使う） */
const TEMPLATE_MODEL = "gpt-4o-2024-11-20";

/**
 * details/current に保存するキャラクター属性（夢は本人限定の dream/current に置くため含めない）
 *
 * 理由を持つ属性（TRAIT_KEYS）は `<キー>_reason` に理由も保存する。
 */
const ATTRIBUTE_KEYS = [...TRAIT_KEYS, ...PLAIN_ATTRIBUTE_KEYS];

/** 理由の最大文字数（プロンプトでは30文字以内と指示。はみ出しても切り詰めて保存する） */
const REASON_MAX_LENGTH = 40;

/**
 * GPT出力の1項目から値と理由を取り出す
 *
 * 新形式は {"value","reason"}。旧形式（文字列だけ）も値として受け入れる。
 *
 * @param {*} item - GPT出力の1項目
 * @return {{value: string, reason: string}} - 値と理由
 */
function splitValueReason(item) {
  if (typeof item === "string") return {value: item.trim(), reason: ""};
  if (item && typeof item === "object") {
    const value = typeof item.value === "string" ? item.value.trim() : "";
    const reason = oneLine(item.reason, REASON_MAX_LENGTH);
    return {value, reason};
  }
  return {value: "", reason: ""};
}

/**
 * GPT出力から既知の属性だけを取り出す（想定外のキーをFirestoreに書かない）
 * @param {Object} parsed - パース済みのGPT出力
 * @return {Object} - 属性のマップ（理由は `<キー>_reason`）
 */
function pickAttributes(parsed) {
  const attributes = {};
  for (const key of ATTRIBUTE_KEYS) {
    const {value, reason} = splitValueReason(parsed[key]);
    if (!value) continue;
    // 口癖・モヤっとする言葉は鉤括弧込みで返ってくることがある（`「面白そう！」`）。
    // そのまま保存するとプロンプトで二重に囲われ、本文に括弧ごと引用される。
    const cleaned = (key === "favorite_word" || key === "trigger_word") ?
      stripQuotes(value) :
      value;
    if (!cleaned) continue;
    attributes[key] = cleaned;
    if (reason && TRAIT_KEYS.includes(key)) attributes[reasonKey(key)] = reason;
  }
  return attributes;
}

/**
 * GPT出力の夢の候補を、候補と理由の並びに分ける
 *
 * 重複・空の候補は除き、残った候補と同じ並びで理由を返す。
 *
 * @param {*} raw - GPT出力の dreams（{"value","reason"} の配列。旧形式の文字列配列も可）
 * @return {{dreams: string[], reasons: string[]}} - 候補と理由
 */
function splitDreams(raw) {
  const list = Array.isArray(raw) ? raw : (raw ? [raw] : []);
  const pairs = list.map(splitValueReason);
  const dreams = normalizeDreamOptions(pairs.map((p) => p.value));
  const reasons = dreams.map((dream) => {
    const hit = pairs.find((p) => sanitizeDream(p.value) === dream);
    return hit ? hit.reason : "";
  });
  return {dreams, reasons};
}

/**
 * テンプレートが今の項目をすべて持っているか
 *
 * 拡張前（2026-10-02 より前）に作ったテンプレートは新しい項目と理由を持たないため、
 * 揃っていなければ作り直す。
 *
 * @param {Object} cached - CharacterDetailsTemplate のデータ
 * @return {boolean} - 揃っていれば true
 */
function isTemplateComplete(cached) {
  const attributes = cached.attributes || {};
  if (ADDED_TRAIT_KEYS.some((key) => !attributes[key])) return false;
  if (!attributes[reasonKey("strength")]) return false;
  return Array.isArray(cached.dream_reasons);
}

/**
 * 性格キーに対応する共有テンプレートを取得する。無ければ生成して保存する。
 * @param {string} personalityKey - 性格キー
 * @param {Object} big5Scores - Big5スコア
 * @param {string} gender - 性別
 * @param {string} apiKey - OpenAI APIキー
 * @return {Promise<{attributes: Object, dreams: string[]}>} - 属性と夢の候補
 */
async function fetchOrCreateTemplate(personalityKey, big5Scores, gender, apiKey) {
  const ref = db.collection(TEMPLATE_COLLECTION).doc(personalityKey);
  const snap = await ref.get();

  let existing = null;
  if (snap.exists) {
    const cached = snap.data();
    const dreams = normalizeDreamOptions(cached.dreams);
    if (dreams.length > 0 && cached.attributes && isTemplateComplete(cached)) {
      console.log(`♻️ CharacterDetailsTemplate ヒット（AI呼び出しなし）: ${personalityKey}`);
      return {attributes: cached.attributes, dreams, dreamReasons: cached.dream_reasons};
    }
    // 拡張前のテンプレートは、既存の値を変えずに新しい項目と理由だけを足す
    if (dreams.length > 0 && cached.attributes) existing = {attributes: cached.attributes, dreams};
    console.log(`⚠️ テンプレートが不完全なため再生成: ${personalityKey}（既存の値を維持: ${existing ? "あり" : "なし"}）`);
  }

  return createTemplate(ref, personalityKey, big5Scores, gender, apiKey, existing);
}

/**
 * テンプレートを生成して保存する
 * @param {FirebaseFirestore.DocumentReference} ref - テンプレートの参照
 * @param {string} personalityKey - 性格キー
 * @param {Object} big5Scores - Big5スコア
 * @param {string} gender - 性別
 * @param {string} apiKey - OpenAI APIキー
 * @param {Object|null} existing - 維持する既存の値（{attributes, dreams}）
 * @return {Promise<{attributes: Object, dreams: string[], dreamReasons: string[]}>} - 属性・夢の候補・夢の理由
 */
async function createTemplate(ref, personalityKey, big5Scores, gender, apiKey, existing) {
  console.log(`🔄 CharacterDetailsTemplate 生成: ${personalityKey}`);
  const openai = new OpenAI({apiKey});
  const prompt = OPTIMIZED_PROMPTS.characterDetails(big5Scores, gender, existing);

  const res = await openai.chat.completions.create({
    model: TEMPLATE_MODEL,
    messages: [{role: "user", content: prompt}],
    response_format: {type: "json_object"},
  });

  // もしマークダウン記法が付いていたら除去する
  let content = res.choices[0].message.content.trim();
  if (content.startsWith("```json")) {
    content = content.replace(/^```json\s*/, "").replace(/```$/, "").trim();
  }

  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (err) {
    throw new Error("GPT出力のパースに失敗しました: " + err.message);
  }

  const attributes = pickAttributes(parsed);
  // 旧形式（dream が単一文字列）で返ってきた場合も候補1個として受け入れる
  let {dreams, reasons: dreamReasons} = splitDreams(parsed.dreams || parsed.dream);

  if (existing) {
    // 既存の値はAIの出力に関わらず必ず維持する（言い換えられても元に戻す）
    for (const key of ATTRIBUTE_KEYS) {
      if (existing.attributes[key]) attributes[key] = existing.attributes[key];
    }
    const keptReasons = existing.dreams.map((dream, i) => {
      const hit = dreams.indexOf(dream);
      return hit >= 0 ? dreamReasons[hit] : (dreamReasons[i] || "");
    });
    dreams = existing.dreams;
    dreamReasons = keptReasons;
  }

  if (dreams.length === 0) {
    throw new Error("夢の候補が1つも生成されませんでした");
  }

  await ref.set({
    personality_key: personalityKey,
    attributes,
    dreams,
    dream_reasons: dreamReasons,
    model: TEMPLATE_MODEL,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {attributes, dreams, dreamReasons};
}

/**
 * Big5スコアからキャラクターの性格詳細を生成し、ユーザーのドキュメントへ反映する
 *
 * 属性（口癖・長所など）は personalityKey ごとの共有テンプレートから取得し、
 * ユーザーの details/current にコピーする（チャット・日記の参照先を変えないため）。
 * 夢は候補5個を本人限定の dream/current に保存し、選択済みの夢は上書きしない。
 *
 * @param {string} characterId - キャラクターID
 * @param {string} userId - ユーザーID
 * @param {string} apiKey - OpenAI APIキー
 * @return {Promise<Object|null>} - 反映した属性と夢の候補
 */
async function generateCharacterDetails(characterId, userId, apiKey) {
  try {
    const detailsRef = db.collection("users").doc(userId)
        .collection("characters").doc(characterId)
        .collection("details").doc("current");

    const charSnap = await detailsRef.get();

    if (!charSnap.exists) {
      console.log("❌ Character not found:", characterId);
      return null;
    }

    const data = charSnap.data();
    // convertedBig5Scores（新軸スコアから変換）を優先、なければ旧システムのスコアを使用
    const big5Scores = data.convertedBig5Scores || data.confirmedBig5Scores || data.big5Scores;
    const gender = data.gender || "neutral";

    // personalityKey生成（genderを含める）
    const personalityKey = generatePersonalityKey(big5Scores, gender);

    const {attributes, dreams, dreamReasons} = await fetchOrCreateTemplate(
        personalityKey, big5Scores, gender, apiKey);

    // 属性をユーザーのドキュメントへ反映（夢は含めない）
    await detailsRef.update({
      ...attributes,
      personalityKey: personalityKey,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 夢の候補は本人限定のサブコレクションへ。選択済みの夢は維持する
    await saveDreamOptions(userId, characterId, dreams, data.dream, dreamReasons);

    console.log(`✅ キャラクター詳細生成成功: ${characterId}, personalityKey: ${personalityKey}, 夢候補: ${dreams.length}個`);

    // Big5解析データを生成（バックグラウンドで実行、エラーでも続行）
    try {
      console.log(`🔄 Big5解析データ生成開始: ${personalityKey}`);
      await generateBig5Analysis(big5Scores, gender, apiKey);
      console.log(`✅ Big5解析データ生成成功: ${personalityKey}`);
    } catch (error) {
      console.error(`⚠️ Big5解析データ生成失敗（キャラクター詳細は保存済み）: ${personalityKey}`, error);
      // エラーが発生してもキャラクター詳細生成は成功として扱う
    }

    return {...attributes, dreams};
  } catch (err) {
    console.error(`❌ 詳細生成失敗: ${characterId}`, err);
  }
}

module.exports = {
  generateCharacterDetails,
  // 既存テンプレートの作り直し・プロンプト検証用
  createTemplate,
  pickAttributes,
  splitDreams,
  isTemplateComplete,
  ATTRIBUTE_KEYS,
  TEMPLATE_COLLECTION,
};
