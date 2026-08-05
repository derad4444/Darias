// src/utils/dreamStore.js - キャラクターの夢の保存・取得

const {getFirestore, admin} = require("./firebaseInit");

/** 夢の最大文字数（自由入力・AI生成候補の両方に適用） */
const DREAM_MAX_LENGTH = 40;

/** 生成する夢の候補数 */
const DREAM_OPTION_COUNT = 5;

/** 改行・タブを含む制御文字 */
const CONTROL_CHARS = /[\u0000-\u001F\u007F]+/g;

/**
 * 夢ドキュメントの参照を返す
 *
 * `details/current` は firestore.rules で認証済みユーザー全員に読み取り許可
 * されている（フレンドのアバター表示のため）。夢はユーザーが自由入力でき、
 * かつ他ユーザーが参照する必要がないため、本人限定のサブコレクションに置く。
 *
 * @param {string} userId - ユーザーID
 * @param {string} characterId - キャラクターID
 * @return {FirebaseFirestore.DocumentReference} - 夢ドキュメントの参照
 */
function dreamRef(userId, characterId) {
  return getFirestore()
      .collection("users").doc(userId)
      .collection("characters").doc(characterId)
      .collection("dream").doc("current");
}

/**
 * 夢のテキストを安全な形に整える
 *
 * 夢はチャット・日記のシステムプロンプトに埋め込まれるため、改行や制御文字で
 * プロンプトの行構造を壊されないようにし、長さも制限する。
 *
 * @param {*} value - 入力値（文字列以外も許容）
 * @return {string} - 正規化された夢（不正な場合は空文字）
 */
function sanitizeDream(value) {
  if (typeof value !== "string") return "";
  const collapsed = value
      .replace(CONTROL_CHARS, " ")
      .replace(/\s+/g, " ")
      .trim();
  // サロゲートペア（絵文字など）を途中で割らないようコードポイント単位で切る
  // （クライアント側 DreamService.sanitize と同じ規則）
  const points = Array.from(collapsed);
  if (points.length <= DREAM_MAX_LENGTH) return collapsed;
  return points.slice(0, DREAM_MAX_LENGTH).join("");
}

/**
 * AIが生成した夢の候補リストを正規化する
 * @param {*} raw - GPT出力の dreams（配列でない場合も許容）
 * @return {string[]} - 重複と空文字を除いた最大5個の候補
 */
function normalizeDreamOptions(raw) {
  const list = Array.isArray(raw) ? raw : (raw ? [raw] : []);
  const seen = new Set();
  const result = [];
  for (const item of list) {
    const dream = sanitizeDream(item);
    if (!dream || seen.has(dream)) continue;
    seen.add(dream);
    result.push(dream);
    if (result.length >= DREAM_OPTION_COUNT) break;
  }
  return result;
}

/**
 * キャラクターの現在の夢を取得する
 *
 * 夢ドキュメントが未作成の既存ユーザーのために、`details/current.dream`
 * （旧保存先）へフォールバックする。
 *
 * @param {string} userId - ユーザーID
 * @param {string} characterId - キャラクターID
 * @param {Object|null} detailsData - 取得済みの details/current データ（省略可）
 * @return {Promise<string>} - 現在の夢（未設定なら空文字）
 */
async function getDream(userId, characterId, detailsData = null) {
  try {
    const snap = await dreamRef(userId, characterId).get();
    if (snap.exists) {
      const dream = sanitizeDream(snap.data().dream);
      if (dream) return dream;
    }
  } catch (e) {
    console.warn("⚠️ 夢の取得に失敗（旧保存先へフォールバック）:", e.message);
  }
  return sanitizeDream(detailsData ? detailsData.dream : "");
}

/**
 * 夢の候補を保存する（ユーザーが選択済みの夢は上書きしない）
 *
 * 性格タイプが変わって候補が作り直された場合でも、ユーザーが自分で選んだ・
 * 入力した夢は維持する。新しい候補が出たことは `dreamOptionsUpdatedAt` で
 * クライアントに伝わる。
 *
 * @param {string} userId - ユーザーID
 * @param {string} characterId - キャラクターID
 * @param {string[]} options - 夢の候補（正規化済み）
 * @param {string} legacyDream - 旧保存先 details/current.dream の値（移行用）
 * @return {Promise<void>}
 */
async function saveDreamOptions(userId, characterId, options, legacyDream = "") {
  const ref = dreamRef(userId, characterId);
  const snap = await ref.get();
  const current = snap.exists ? snap.data() : null;

  const payload = {
    dreamOptions: options,
    dreamOptionsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  // 選択済みの夢がまだ無い場合のみ、旧保存先の値を引き継ぐ（既存ユーザーの移行）
  const existingDream = sanitizeDream(current ? current.dream : "");
  let effectiveDream = existingDream;
  if (!existingDream) {
    const migrated = sanitizeDream(legacyDream);
    if (migrated) {
      payload.dream = migrated;
      payload.dreamSource = "ai";
      effectiveDream = migrated;
    }
  }

  // 既に夢が決まっている場合は「新しい候補ができた」ことを提案する。
  // まだ決まっていない場合は初回選択フロー（pendingFirstDreamSelection）に任せる。
  if (effectiveDream) {
    payload.pendingDreamProposal = true;
  }

  await ref.set(payload, {merge: true});
}

module.exports = {
  DREAM_MAX_LENGTH,
  DREAM_OPTION_COUNT,
  dreamRef,
  sanitizeDream,
  normalizeDreamOptions,
  getDream,
  saveDreamOptions,
};
