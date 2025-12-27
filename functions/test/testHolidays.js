// test/testHolidays.js
// 祝日生成のテストスクリプト

const admin = require("firebase-admin");
const {generateHolidaysForTwoYears} = require("../const/generateHolidays");

// Firebase初期化
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

async function testHolidayGeneration() {
  console.log("🎌 祝日生成テストを開始します...\n");

  try {
    // 2年分の祝日を生成
    await generateHolidaysForTwoYears();

    console.log("\n✅ テスト完了！Firestoreを確認してください。");
    console.log("   コレクション: holidays");

    process.exit(0);
  } catch (error) {
    console.error("\n❌ テスト失敗:", error);
    process.exit(1);
  }
}

// テスト実行
testHolidayGeneration();
