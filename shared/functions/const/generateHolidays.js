// functions/const/generateHolidays.js

const {getFirestore} = require("../src/utils/firebaseInit");
const axios = require("axios");

/**
 * Nager.Date API から日本の祝日を取得して Firestore に登録
 * @param {number} year - 対象の年
 */
async function generateHolidays(year) {
  const url = `https://date.nager.at/api/v3/PublicHolidays/${year}/JP`;
  const db = getFirestore();

  try {
    const response = await axios.get(url);
    const holidays = response.data;

    const batch = db.batch();

    for (const holiday of holidays) {
      const id = holiday.date; // 例: "2025-01-01"
      const docRef = db.collection("holidays").doc(id);

      const data = {
        id: id,
        name: holiday.localName,
        dateString: holiday.date,
      };

      batch.set(docRef, data);
    }

    await batch.commit();
    console.log(`✅ ${year}年の祝日を登録しました`);
  } catch (error) {
    console.error(`❌ ${year}年の祝日登録失敗:`, error);
    throw error;
  }
}

/**
 * 指定された年の祝日が既に存在するかチェック
 * @param {number} year - チェックする年
 * @return {boolean} - 存在する場合true
 */
async function checkHolidaysExist(year) {
  const db = getFirestore();

  try {
    // その年の最初の日付をチェック
    const startDate = `${year}-01-01`;
    const endDate = `${year}-12-31`;

    const snapshot = await db.collection("holidays")
        .where("dateString", ">=", startDate)
        .where("dateString", "<=", endDate)
        .limit(1)
        .get();

    return !snapshot.empty;
  } catch (error) {
    console.error(`❌ ${year}年の祝日存在チェック失敗:`, error);
    return false; // エラー時は取得を試みる
  }
}

/**
 * 今年と来年の2年分の祝日を取得して Firestore に登録
 * 既に存在する年はスキップ
 */
async function generateHolidaysForTwoYears() {
  const currentYear = new Date().getFullYear();
  const nextYear = currentYear + 1;

  try {
    console.log(`📅 ${currentYear}年と${nextYear}年の祝日を確認中...`);

    const yearsToGenerate = [];

    // 今年の祝日が存在するかチェック
    const currentYearExists = await checkHolidaysExist(currentYear);
    if (!currentYearExists) {
      yearsToGenerate.push(currentYear);
      console.log(`📝 ${currentYear}年の祝日は未登録です`);
    } else {
      console.log(`✓ ${currentYear}年の祝日は既に存在します（スキップ）`);
    }

    // 来年の祝日が存在するかチェック
    const nextYearExists = await checkHolidaysExist(nextYear);
    if (!nextYearExists) {
      yearsToGenerate.push(nextYear);
      console.log(`📝 ${nextYear}年の祝日は未登録です`);
    } else {
      console.log(`✓ ${nextYear}年の祝日は既に存在します（スキップ）`);
    }

    // 未登録の年だけ取得
    if (yearsToGenerate.length === 0) {
      console.log(`✅ ${currentYear}年と${nextYear}年の祝日は既に登録済みです`);
      return;
    }

    for (const year of yearsToGenerate) {
      await generateHolidays(year);
    }

    console.log(`✅ 祝日登録が完了しました（登録: ${yearsToGenerate.join(", ")}年）`);
  } catch (error) {
    console.error("❌ 祝日登録に失敗しました:", error);
    throw error;
  }
}

module.exports = {generateHolidays, generateHolidaysForTwoYears};
