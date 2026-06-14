const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

try { admin.app(); } catch (e) { admin.initializeApp(); }
const db = admin.firestore();

// axisScores から元素を判定（axisCalculator.js と同一ロジック）
const ROLE_MAP = {
  "炎": {axis: "relationship", negative: "独り燃える炎タイプ", positive: "場を沸かす炎タイプ"},
  "風": {axis: "lifestyle", negative: "自在に舞う風タイプ", positive: "目的へ吹く風タイプ"},
  "雷": {axis: "relationship", negative: "単独で閃く雷タイプ", positive: "場を揺らす雷タイプ"},
  "光": {axis: "lifestyle", negative: "先を駆ける光タイプ", positive: "道を照らす光タイプ"},
  "水": {axis: "lifestyle", negative: "形を変える水タイプ", positive: "深く湛える水タイプ"},
  "土": {axis: "relationship", negative: "独り立つ土タイプ", positive: "静かに支える土タイプ"},
  "氷": {axis: "relationship", negative: "研ぎ澄ます氷タイプ", positive: "凛として守る氷タイプ"},
  "闇": {axis: "lifestyle", negative: "深く問い続ける闇タイプ", positive: "先を読む闇タイプ"},
  "無": {axis: "relationship", negative: "何にも染まらぬ無タイプ", positive: "全てに溶け込む無タイプ"},
};

function determineElement(scores) {
  const {energy, judgment, processing} = scores;
  if (energy >= -0.3 && energy <= 0.3) return "無";
  if (energy > 0.3) {
    if (judgment < -0.3) return "炎";
    if (judgment <= 0.3) return "風";
    return processing < 0 ? "雷" : "光";
  }
  if (judgment < -0.3) return "水";
  if (judgment <= 0.3) return "土";
  return processing < 0 ? "氷" : "闇";
}

function determineTypeName(element, scores) {
  const role = ROLE_MAP[element];
  if (!role) return "不明";
  return scores[role.axis] >= 0 ? role.positive : role.negative;
}

/**
 * PersonalityStatsMetadata を全ユーザーデータから再集計するHTTPエンドポイント
 * ?dryRun=true を付けると書き込まずに集計結果だけ返す
 */
const recalculatePersonalityStats = onRequest(
    {
      region: "asia-northeast1",
      memory: "1GiB",
      timeoutSeconds: 300,
    },
    async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      const dryRun = req.query.dryRun === "true";

      try {
        console.log("🔄 recalculatePersonalityStats: 集計開始");

        const stats = {
          total_completed_users: 0,
          unique_personality_types: 0,
          gender_distribution: {},
          personality_counts: {},
          element_counts: {},
          type_name_counts: {},
          personality_details: {},
        };

        // コレクショングループで全キャラクターの details/current を一括取得
        // （characters/{charId} ドキュメント自体は存在しないため親コレクション経由では取得不可）
        const allDetailsSnap = await db.collectionGroup("details").get();
        console.log(`📄 details ドキュメント総数: ${allDetailsSnap.size}`);
        stats._debug_details_count = allDetailsSnap.size;

        for (const detailDoc of allDetailsSnap.docs) {
          // users/{uid}/characters/{charId}/details/current のみ対象
          const path = detailDoc.ref.path;
          if (!path.includes("/characters/") || detailDoc.id !== "current") continue;

          const data = detailDoc.data();
          const personalityKey = data.personalityKey;
          if (!personalityKey) continue;

          stats.total_completed_users++;

          const gender = extractGender(personalityKey);
          stats.gender_distribution[gender] =
            (stats.gender_distribution[gender] || 0) + 1;

          stats.personality_counts[personalityKey] =
            (stats.personality_counts[personalityKey] || 0) + 1;

          // element・typeName: Firestoreに保存済みならそのまま使用、
          // なければ axisScores から計算して補完
          let element = data.element || "";
          let typeName = data.typeName || "";

          if (!element && data.axisScores) {
            element = determineElement(data.axisScores);
          }
          if (!typeName && element && data.axisScores) {
            typeName = determineTypeName(element, data.axisScores);
          }

          element = element || "不明";
          typeName = typeName || "不明";

          stats.element_counts[element] =
            (stats.element_counts[element] || 0) + 1;

          stats.type_name_counts[typeName] =
            (stats.type_name_counts[typeName] || 0) + 1;

          // 性格詳細リスト（personalityKey ごとに element・typeName を記録）
          if (!stats.personality_details[personalityKey]) {
            stats.personality_details[personalityKey] = {
              element,
              typeName,
              count: 0,
            };
          }
          stats.personality_details[personalityKey].count++;
        }

        stats.unique_personality_types =
          Object.keys(stats.personality_counts).length;

        console.log(`📊 集計完了: ${JSON.stringify({
          total_personalities: stats.total_completed_users,
          unique: stats.unique_personality_types,
          gender: stats.gender_distribution,
          elements: stats.element_counts,
        })}`);

        if (!dryRun) {
          await db.collection("PersonalityStatsMetadata")
              .doc("summary").set(stats);
          console.log("✅ PersonalityStatsMetadata/summary を更新しました");
        } else {
          console.log("ℹ️ dryRun=true のため書き込みをスキップ");
        }

        res.json({
          success: true,
          dryRun,
          debug: {
            details_count: stats._debug_details_count,
          },
          stats: {
            total_completed_users: stats.total_completed_users,
            unique_personality_types: stats.unique_personality_types,
            gender_distribution: stats.gender_distribution,
            element_counts: stats.element_counts,
            type_name_counts: stats.type_name_counts,
            personality_details: stats.personality_details,
          },
        });
      } catch (error) {
        console.error("❌ recalculatePersonalityStats error:", error);
        res.status(500).json({error: error.message});
      }
    },
);

/**
 * personalityKey から性別を抽出
 * @param {string} personalityKey
 * @return {string} - "female" / "male" / "neutral"
 */
function extractGender(personalityKey) {
  if (personalityKey.endsWith("_female") ||
      personalityKey.endsWith("_女性")) return "female";
  if (personalityKey.endsWith("_male") ||
      personalityKey.endsWith("_男性")) return "male";
  return "neutral";
}

module.exports = {recalculatePersonalityStats};
