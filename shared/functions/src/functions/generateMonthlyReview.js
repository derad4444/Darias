const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest} = require("firebase-functions/v2/https");
const {getFirestore, admin} = require("../utils/firebaseInit");

const db = getFirestore();

/**
 * 毎月1日に先月の予定を確認してコメントを作成する関数
 * BIG5性格特性を考慮したパーソナライズされたコメントを生成
 */
exports.generateMonthlyReview = onSchedule(
    {
      schedule: "0 9 1 * *",
      region: "asia-northeast1",
      timeZone: "Asia/Tokyo",
      memory: "1GiB",
      timeoutSeconds: 540,
    },
    async (event) => {
      console.log("🗓️ 月次レビュー開始");

      try {
        // 全ユーザーを取得
        const usersSnapshot = await db.collection("users").get();

        for (const userDoc of usersSnapshot.docs) {
          const userId = userDoc.id;
          console.log(`👤 ユーザー ${userId} の月次レビュー処理開始`);

          try {
            await processUserMonthlyReview(userId);
          } catch (error) {
            console.error(`❌ ユーザー ${userId} の処理エラー:`, error);
          }
        }

        console.log("✅ 月次レビュー完了");
      } catch (error) {
        console.error("❌ 月次レビュー処理エラー:", error);
      }
    },
);

/**
 * 個別ユーザーの月次レビュー処理
 */
async function processUserMonthlyReview(userId) {
  // キャラクター詳細を取得
  const characterDetail = await getCharacterDetail(userId);
  if (!characterDetail) {
    console.log(`⚠️ ユーザー ${userId} のキャラクター詳細が見つかりません`);
    return;
  }

  // 先月の予定を取得
  const lastMonthSchedules = await getLastMonthSchedules(userId);

  // コメントを生成
  const reviewComment = generatePersonalizedComment(
      characterDetail, lastMonthSchedules);

  // Firestoreに保存
  await saveMonthlyComment(
      userId, characterDetail.id, reviewComment, lastMonthSchedules);

  console.log(`✅ ユーザー ${userId} の月次コメント保存完了`);
}

/**
 * キャラクター詳細を取得
 */
async function getCharacterDetail(userId) {
  try {
    // 新しいコレクション構造に対応: ユーザーの最初のキャラクターを取得
    const charactersSnapshot = await db.collection("users").doc(userId)
        .collection("characters")
        .limit(1)
        .get();

    if (charactersSnapshot.empty) {
      return null;
    }

    const characterId = charactersSnapshot.docs[0].id;
    const detailsDoc = await db.collection("users").doc(userId)
        .collection("characters").doc(characterId)
        .collection("details").doc("current")
        .get();

    if (!detailsDoc.exists) {
      return null;
    }

    return {
      id: characterId,
      ...detailsDoc.data(),
    };
  } catch (error) {
    console.error("キャラクター詳細取得エラー:", error);
    return null;
  }
}

/**
 * 先月の予定を取得
 */
async function getLastMonthSchedules(userId) {
  try {
    const now = new Date();
    const lastMonth = new Date(
        now.getFullYear(), now.getMonth() - 1, 1);
    const lastMonthEnd = new Date(
        now.getFullYear(), now.getMonth(), 0, 23, 59, 59);

    const snapshot = await db.collection("users").doc(userId)
        .collection("schedules")
        .where("startDate", ">=",
            admin.firestore.Timestamp.fromDate(lastMonth))
        .where("startDate", "<=",
            admin.firestore.Timestamp.fromDate(lastMonthEnd))
        .orderBy("startDate")
        .get();

    return snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
  } catch (error) {
    console.error("先月予定取得エラー:", error);
    return [];
  }
}

/**
 * BIG5性格特性を考慮したパーソナライズコメント生成
 */
function generatePersonalizedComment(characterDetail, schedules) {
  const big5 = characterDetail.confirmedBig5Scores || characterDetail.big5Scores || {};
  const lastMonth = new Date();
  lastMonth.setMonth(lastMonth.getMonth() - 1);
  const monthName = `${lastMonth.getMonth() + 1}月`;

  // 予定の種類を分析
  const scheduleAnalysis = analyzeSchedules(schedules);

  // BIG5特性に基づくコメント生成
  const personality = analyzeBig5Personality(big5);

  let comment = generateLastMonthComment(
      personality, scheduleAnalysis, monthName);
  comment += "\n\n";
  comment += generateThisMonthEncouragement(personality, scheduleAnalysis);

  return comment;
}

/**
 * 予定を分析して傾向を把握
 */
function analyzeSchedules(schedules) {
  const workCount = schedules.filter((s) =>
    s.title?.includes("仕事") || s.title?.includes("会議") ||
    s.title?.includes("打ち合わせ"),
  ).length;

  const personalCount = schedules.filter((s) =>
    s.title?.includes("友達") || s.title?.includes("デート") ||
    s.title?.includes("家族"),
  ).length;

  const hobbyCount = schedules.filter((s) =>
    s.title?.includes("趣味") || s.title?.includes("映画") ||
    s.title?.includes("本"),
  ).length;

  const healthCount = schedules.filter((s) =>
    s.title?.includes("運動") || s.title?.includes("ジム") ||
    s.title?.includes("病院"),
  ).length;

  return {
    total: schedules.length,
    work: workCount,
    personal: personalCount,
    hobby: hobbyCount,
    health: healthCount,
    busyLevel: schedules.length > 20 ? "high" :
      schedules.length > 10 ? "medium" : "low",
  };
}

/**
 * BIG5特性を分析して性格タイプを判定
 */
function analyzeBig5Personality(big5) {
  return {
    openness: big5.openness || 3,
    conscientiousness: big5.conscientiousness || 3,
    agreeableness: big5.agreeableness || 3,
    extraversion: big5.extraversion || 3,
    neuroticism: big5.neuroticism || 3,
  };
}

/**
 * 先月のコメント生成（100文字程度）
 */
function generateLastMonthComment(personality, analysis, monthName) {
  let comment = `${monthName}は`;

  // 忙しさレベルに応じたコメント
  if (analysis.busyLevel === "high") {
    if (personality.conscientiousness >= 4) {
      comment += "とても充実した月だったね！計画的に色々こなしていて素晴らしいよ。";
    } else if (personality.neuroticism >= 4) {
      comment += "忙しい月だったね。お疲れさま！少し疲れも溜まっているかも。";
    } else {
      comment += "たくさんの予定をこなした活動的な月だったね！";
    }
  } else if (analysis.busyLevel === "medium") {
    if (personality.extraversion >= 4) {
      comment += "程よく活動的な月だったね！バランス良く過ごせていたみたい。";
    } else {
      comment += "自分のペースで過ごせた落ち着いた月だったね。";
    }
  } else {
    if (personality.openness >= 4) {
      comment += "ゆったりした月だったね。新しいことを始める準備期間かも？";
    } else {
      comment += "穏やかでリラックスした月だったね。休息も大切だよ。";
    }
  }

  return comment;
}

/**
 * 今月への励ましコメント生成（100文字程度）
 */
function generateThisMonthEncouragement(personality, analysis) {
  let comment = "";

  if (personality.openness >= 4) {
    comment += "今月は新しいことにチャレンジしてみるのはどう？楽しい発見があるよ！";
  } else if (personality.conscientiousness >= 4) {
    comment += "今月も計画的に過ごして、目標に向かって進んでいこうね。";
  } else if (personality.extraversion >= 4) {
    comment += "今月はいろんな人と会って、楽しい時間を過ごしてね！";
  } else if (personality.agreeableness >= 4) {
    comment += "今月は大切な人との時間を大事にして、優しく過ごしてね。";
  } else if (personality.neuroticism >= 4) {
    comment += "今月は無理をしすぎず、自分のペースで過ごしてね。";
  } else {
    comment += "今月は自分らしく、マイペースに過ごしてね。";
  }

  return comment;
}

/**
 * 月次コメントをFirestoreに保存
 */
async function saveMonthlyComment(userId, characterId, comment, schedules) {
  try {
    const now = new Date();
    const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    
    // YYYY-MM形式のドキュメントIDを生成
    const year = lastMonth.getFullYear();
    const month = String(lastMonth.getMonth() + 1).padStart(2, '0');
    const monthId = `${year}-${month}`;

    await db.collection("users").doc(userId)
        .collection("characters").doc(characterId)
        .collection("monthlyComments").doc(monthId)
        .set({
          comment: comment,
          schedule_count: schedules.length,
          review_month: admin.firestore.Timestamp.fromDate(lastMonth),
          generated_at: admin.firestore.Timestamp.now(),
        });

    console.log(`💾 月次コメント保存完了: ${userId}/${characterId}/${monthId}`);
  } catch (error) {
    console.error("月次コメント保存エラー:", error);
    throw error;
  }
}

// HTTP関数版（テスト用）
exports.generateMonthlyReviewHttp = onRequest(
    {
      region: "asia-northeast1",
      memory: "1GiB",
      timeoutSeconds: 300,
    },
    async (req, res) => {
      try {
        const {userId} = req.body;

        if (!userId) {
          return res.status(400).json({error: "userIdが必要です"});
        }

        await processUserMonthlyReview(userId);

        res.json({
          success: true,
          message: "月次コメントが生成されました",
        });
      } catch (error) {
        console.error("月次コメント生成エラー:", error);
        res.status(500).json({
          error: "エラーが発生しました",
          details: error.message,
        });
      }
    },
);
