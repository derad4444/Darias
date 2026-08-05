const OpenAI = require("openai");
const admin = require("firebase-admin");
const {generatePersonalityKey} = require("./generatePersonalityKey");
const {generateBig5Analysis} = require("./generateBig5Analysis");
const {OPTIMIZED_PROMPTS} = require("../src/prompts/templates");
const {normalizeDreamOptions, saveDreamOptions} = require("../src/utils/dreamStore");

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

/** details/current に保存するキャラクター属性（夢は本人限定の dream/current に置くため含めない） */
const ATTRIBUTE_KEYS = [
  "favorite_color",
  "favorite_place",
  "favorite_word",
  "word_tendency",
  "strength",
  "weakness",
  "skill",
  "hobby",
  "aptitude",
  "favorite_entertainment_genre",
];

/**
 * GPT出力から既知の属性だけを取り出す（想定外のキーをFirestoreに書かない）
 * @param {Object} parsed - パース済みのGPT出力
 * @return {Object} - 属性のマップ
 */
function pickAttributes(parsed) {
  const attributes = {};
  for (const key of ATTRIBUTE_KEYS) {
    const value = parsed[key];
    if (typeof value === "string" && value.trim()) {
      attributes[key] = value.trim();
    }
  }
  return attributes;
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

  if (snap.exists) {
    const cached = snap.data();
    const dreams = normalizeDreamOptions(cached.dreams);
    if (dreams.length > 0 && cached.attributes) {
      console.log(`♻️ CharacterDetailsTemplate ヒット（AI呼び出しなし）: ${personalityKey}`);
      return {attributes: cached.attributes, dreams};
    }
    console.log(`⚠️ テンプレートが不完全なため再生成: ${personalityKey}`);
  }

  console.log(`🔄 CharacterDetailsTemplate 生成: ${personalityKey}`);
  const openai = new OpenAI({apiKey});
  const prompt = OPTIMIZED_PROMPTS.characterDetails(big5Scores, gender);

  const res = await openai.chat.completions.create({
    model: TEMPLATE_MODEL,
    messages: [{role: "user", content: prompt}],
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
  const dreams = normalizeDreamOptions(parsed.dreams || parsed.dream);
  if (dreams.length === 0) {
    throw new Error("夢の候補が1つも生成されませんでした");
  }

  await ref.set({
    personality_key: personalityKey,
    attributes,
    dreams,
    model: TEMPLATE_MODEL,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {attributes, dreams};
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

    const {attributes, dreams} = await fetchOrCreateTemplate(
        personalityKey, big5Scores, gender, apiKey);

    // 属性をユーザーのドキュメントへ反映（夢は含めない）
    await detailsRef.update({
      ...attributes,
      personalityKey: personalityKey,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 夢の候補は本人限定のサブコレクションへ。選択済みの夢は維持する
    await saveDreamOptions(userId, characterId, dreams, data.dream);

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

module.exports = {generateCharacterDetails};
