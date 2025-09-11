// テスト用のシンプルなスクリプト
const {generateBig5Analysis} = require("../const/generateBig5Analysis");

async function testBig5Analysis() {
  console.log("🧪 Big5Analysis テスト開始");

  // テスト用のBig5スコア
  const testBig5Scores = {
    openness: 5,
    conscientiousness: 4,
    agreeableness: 2,
    extraversion: 2,
    neuroticism: 2,
  };

  const testGender = "female";

  try {
    console.log("📊 テストデータ:");
    console.log("Big5:", testBig5Scores);
    console.log("Gender:", testGender);
    console.log("Expected PersonalityKey: O5_C4_A2_E2_N2");
    console.log("");

    const result = await generateBig5Analysis(
        testBig5Scores,
        testGender,
        process.env.OPENAI_API_KEY,
    );

    console.log("✅ テスト成功！");
    console.log("Generated PersonalityKey:", result.personality_key);
    console.log("Character Count:", result.character_count);
    console.log("Fields generated:", Object.keys(result));
    console.log("");
    console.log("Sample Analysis:");
    console.log("Career (length):", result.career_analysis?.length || 0);
    console.log("Romance (length):", result.romance_analysis?.length || 0);

    // 2回目実行（キャッシュテスト）
    console.log("\n🔄 キャッシュテスト（2回目実行）");
    const cachedResult = await generateBig5Analysis(
        testBig5Scores,
        testGender,
        process.env.OPENAI_API_KEY,
    );
    console.log("✅ キャッシュ動作確認:", cachedResult.personality_key);
  } catch (error) {
    console.error("❌ テスト失敗:", error.message);
    console.error(error);
  }
}

// 実行
testBig5Analysis();
