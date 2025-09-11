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
        case 1:
          // 20問完了: 固定のアンドロイド風キャラクター
          personalityKey = "stage1_android";
          characterDetails = getStage1AndroidDetails(gender);

          // 固定コンテンツなので失敗リスクは低いが、Firebase書き込みエラー対応
          await db.collection("users").doc(userId)
              .collection("characters").doc(characterId)
              .collection("details").doc("current").update({
                ...characterDetails,
                personalityKey,
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
              });

          result = {
            success: true,
            personalityKey,
            stage,
            details: characterDetails,
            method: "fixed_content",
          };
          break;

        case 2:
          // 50問完了: 固定のアンドロイド+人間性キャラクター
          personalityKey = "stage2_android_human";
          characterDetails = getStage2AndroidHumanDetails(gender);

          await db.collection("users").doc(userId)
              .collection("characters").doc(characterId)
              .collection("details").doc("current").update({
                ...characterDetails,
                personalityKey,
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
              });

          result = {
            success: true,
            personalityKey,
            stage,
            details: characterDetails,
            method: "fixed_content",
          };
          break;

        case 3: {
          // 100問完了: Big5ベースの人間的キャラクター (既存機能活用)
          if (!big5Scores) {
            throw new Error("Big5 scores are required for stage 3");
          }
          const {generatePersonalityKey} =
            require("./generatePersonalityKey");
          const {generateCharacterDetails} =
            require("../generateCharacterDetails");

          personalityKey = generatePersonalityKey(big5Scores);

          // 既存の generateCharacterDetails 関数を使用（内部でリトライ機能あり）
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
 * Stage 1: 20問完了時の固定アンドロイド風詳細
 */
function getStage1AndroidDetails(gender) {
  return {
    favorite_color: "青",
    favorite_place: "データセンター",
    favorite_word: "効率化",
    word_tendency: "論理的で簡潔な表現を好む",
    strength: "情報処理能力",
    weakness: "感情の理解が不十分",
    skill: "データ分析",
    hobby: "システム最適化",
    aptitude: "論理的思考",
    dream: "", // 夢は100問完了時に設定
    favorite_entertainment_genre: "SF・テクノロジー系",
  };
}

/**
 * Stage 2: 50問完了時の固定アンドロイド+人間性詳細
 */
function getStage2AndroidHumanDetails(gender) {
  return {
    favorite_color: "緑",
    favorite_place: "静かな図書館",
    favorite_word: "成長",
    word_tendency: "丁寧で思いやりのある表現",
    strength: "学習能力と適応性",
    weakness: "まだ完全には理解できない人間の複雑さ",
    skill: "パターン認識と感情分析",
    hobby: "人間の行動観察",
    aptitude: "コミュニケーション",
    dream: "", // 夢は100問完了時に設定
    favorite_entertainment_genre: "ヒューマンドラマ・ドキュメンタリー",
  };
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

