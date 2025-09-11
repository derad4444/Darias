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
    console.error("❌ 祝日登録失敗:", error);
  }
}

module.exports = {generateHolidays};
