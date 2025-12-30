const {getFirestore, admin} = require("../../src/utils/firebaseInit");

const db = getFirestore();

/**
 * 段階的キャラクター詳細生成（リトライ機能付き）
 * @param {string} characterId - キャラクターID
 * @param {string} userId - ユーザーID
 * @param {number} stage - 段階 (1: 20問完了, 2: 50問完了, 3: 100問完了)
 * @param {string} gender - 性別
 * @param {Object} big5Scores - Big5スコア (stage 3の場合)
 * @param {string} apiKey - OpenAI APIキー
 * @param {number} maxRetries - 最大リトライ回数 (デフォルト: 3)
 * @return {Promise<Object>} - 生成結果
 */
async function generateStagedCharacterDetails(
    characterId, userId, stage, gender, big5Scores = null, apiKey, maxRetries = 3) {
  const startTime = Date.now();
  console.log(
      `🔄 Generating staged character details: ${characterId}, stage ${stage}`);

  // プレミアムユーザーかどうかを確認
  let isPremium = false;
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    isPremium = userDoc.data()?.isPremium || false;
  } catch (error) {
    console.warn(`Failed to check premium status, defaulting to free: ${error.message}`);
  }

  // 生成状態を開始に設定
  await updateGenerationStatus(
      characterId, userId, stage, "generating",
      "性格生成中です。画面を閉じずに少々お待ちください。");

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(
          `Attempt ${attempt}/${maxRetries} for character ${characterId}, ` +
          `stage ${stage}`);

      let personalityKey;
      let characterDetails;
      let result;

      switch (stage) {
        case 1: {
          // 20問完了: BIG5スコアを更新 + キャラクター属性を生成
          if (!big5Scores) {
            throw new Error("Big5 scores are required for stage 1");
          }
          const {generatePersonalityKey} =
            require("../generatePersonalityKey");
          const {generateCharacterAttributes} =
            require("../generateCharacterAttributes");

          personalityKey = generatePersonalityKey(big5Scores, gender);

          // キャラクター属性を生成
          const attributes = await generateCharacterAttributes(
              big5Scores, gender, 1, apiKey, isPremium);

          // details/currentのBIG5スコアと属性を上書き
          await db.collection("users").doc(userId)
              .collection("characters").doc(characterId)
              .collection("details").doc("current").update({
                confirmedBig5Scores: big5Scores,
                personalityKey,
                analysis_level: 20,
                ...attributes, // キャラクター属性を追加
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
              });

          result = {
            success: true,
            personalityKey,
            stage,
            attributes,
            method: "attributes_generated",
          };
          break;
        }

        case 2: {
          // 50問完了: BIG5スコアを更新 + キャラクター属性を再生成
          if (!big5Scores) {
            throw new Error("Big5 scores are required for stage 2");
          }
          const {generatePersonalityKey} =
            require("../generatePersonalityKey");
          const {generateCharacterAttributes} =
            require("../generateCharacterAttributes");

          personalityKey = generatePersonalityKey(big5Scores, gender);

          // キャラクター属性を再生成（50問の精度で）
          const attributes = await generateCharacterAttributes(
              big5Scores, gender, 2, apiKey, isPremium);

          // details/currentのBIG5スコアと属性を上書き
          await db.collection("users").doc(userId)
              .collection("characters").doc(characterId)
              .collection("details").doc("current").update({
                confirmedBig5Scores: big5Scores,
                personalityKey,
                analysis_level: 50,
                ...attributes, // キャラクター属性を更新
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
              });

          result = {
            success: true,
            personalityKey,
            stage,
            attributes,
            method: "attributes_generated",
          };
          break;
        }

        case 3: {
          // 100問完了: Big5ベースの人間的キャラクター (既存機能活用)
          if (!big5Scores) {
            throw new Error("Big5 scores are required for stage 3");
          }
          const {generatePersonalityKey} =
            require("../generatePersonalityKey");
          const {generateCharacterDetails} =
            require("../generateCharacterDetails");

          personalityKey = generatePersonalityKey(big5Scores, gender);

          // 既存の generateCharacterDetails 関数を使用（内部でリトライ機能あり）
          // この関数内でBig5解析データも生成される
          const detailsResult =
            await generateCharacterDetails(characterId, userId, apiKey);

          result = {
            success: true,
            personalityKey,
            stage,
            details: detailsResult,
            method: "ai_generated",
          };
          break;
        }

        default:
          throw new Error(`Invalid stage: ${stage}`);
      }

      const duration = Date.now() - startTime;
      console.log(
          `✅ Staged character details generated successfully: ` +
          `${characterId}, stage ${stage} (${duration}ms, attempt ${attempt})`);

      // 生成状態を完了に設定
      await updateGenerationStatus(characterId, userId, stage, "completed", null);

      return result;
    } catch (error) {
      const duration = Date.now() - startTime;
      console.error(
          `❌ Attempt ${attempt}/${maxRetries} failed for ` +
          `character ${characterId}, stage ${stage} (${duration}ms):`,
          error.message);

      // 最後の試行でも失敗した場合はエラーを投げる
      if (attempt === maxRetries) {
        console.error(
            `❌ All ${maxRetries} attempts failed for ` +
            `character ${characterId}, stage ${stage}. Final error:`, error);

        // 生成状態を失敗に設定
        await updateGenerationStatus(
            characterId, userId, stage, "failed",
            `生成に失敗しました: ${error.message}`);

        // 部分的失敗の場合は登録しない（要件通り）
        throw new Error(
            `Staged character details generation failed after ` +
            `${maxRetries} attempts: ${error.message}`);
      }

      // 指数バックオフで待機してリトライ
      const waitTime = Math.min(1000 * Math.pow(2, attempt), 10000); // 最大10秒
      console.log(`⏳ Waiting ${waitTime}ms before retry...`);
      await new Promise((resolve) => setTimeout(resolve, waitTime));
    }
  }
}

/**
 * キャラクター生成状態を更新
 * @param {string} characterId - キャラクターID
 * @param {number} stage - 段階
 * @param {string} status - 状態 (generating, completed, failed)
 * @param {string|null} message - メッセージ
 */
async function updateGenerationStatus(characterId, userId, stage, status, message) {
  try {
    const statusDoc = {
      stage,
      status,
      message,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (status === "generating") {
      statusDoc.startedAt = admin.firestore.FieldValue.serverTimestamp();
    } else if (status === "completed") {
      statusDoc.completedAt = admin.firestore.FieldValue.serverTimestamp();
    } else if (status === "failed") {
      statusDoc.failedAt = admin.firestore.FieldValue.serverTimestamp();
    }

    await db.collection("users").doc(userId)
        .collection("characters").doc(characterId)
        .collection("generationStatus").doc("current")
        .set(statusDoc, {merge: true});

    console.log(
        `🔔 Generation status updated: ${characterId}, ` +
        `stage ${stage}, status: ${status}`);
  } catch (error) {
    console.error(`❌ Failed to update generation status:`, error);
    // 状態更新の失敗は処理を止めない
  }
}

module.exports = {generateStagedCharacterDetails};

