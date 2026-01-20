const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

/**
 * PersonalityStatsMetadata統計を更新する内部関数
 * @param {string} personalityKey - 性格キー (例: "O3_C4_E3_A4_N2_female")
 * @param {string} userId - ユーザーID (ログ用)
 * @return {Promise<Object>} - 更新結果
 */
async function updatePersonalityStats(personalityKey, userId) {
  try {
    if (!personalityKey) {
      throw new Error('personalityKey is required');
    }

    console.log(`🔄 Updating personality stats for ${personalityKey} (user: ${userId})`);
    
    const result = await updateStatsTransaction(personalityKey);
    
    console.log(`✅ Personality stats updated successfully for ${personalityKey}`);
    return result;
    
  } catch (error) {
    console.error('❌ updatePersonalityStats error:', error);
    throw error;
  }
}

/**
 * Transaction で安全に統計データを更新
 * @param {string} personalityKey - 性格キー
 * @return {Promise<Object>} - 更新後のデータ
 */
async function updateStatsTransaction(personalityKey) {
  const statsRef = db.collection("PersonalityStatsMetadata").doc("summary");
  
  return await db.runTransaction(async (transaction) => {
    const statsDoc = await transaction.get(statsRef);
    
    if (statsDoc.exists) {
      // 既存データの更新
      const data = statsDoc.data();
      
      // 総完了者数 +1
      const totalUsers = (data.total_completed_users || 0) + 1;
      
      // 性別分布更新
      const gender = extractGender(personalityKey);
      const genderDist = data.gender_distribution || {};
      genderDist[gender] = (genderDist[gender] || 0) + 1;
      
      // 性格パターン数更新
      const personalityCounts = data.personality_counts || {};
      personalityCounts[personalityKey] = (personalityCounts[personalityKey] || 0) + 1;
      
      const updatedData = {
        total_completed_users: totalUsers,
        unique_personality_types: Object.keys(personalityCounts).length,
        gender_distribution: genderDist,
        personality_counts: personalityCounts
      };
      
      transaction.update(statsRef, updatedData);
      
      console.log(`📊 Stats updated: Total users: ${totalUsers}, Unique types: ${updatedData.unique_personality_types}`);
      return updatedData;
      
    } else {
      // 初回作成
      const gender = extractGender(personalityKey);
      const initialData = {
        total_completed_users: 1,
        unique_personality_types: 1,
        gender_distribution: {
          [gender]: 1
        },
        personality_counts: {
          [personalityKey]: 1
        }
      };
      
      transaction.set(statsRef, initialData);
      
      console.log(`🆕 Initial stats created for ${personalityKey}`);
      return initialData;
    }
  });
}

/**
 * personalityKey から性別を抽出
 * @param {string} personalityKey - 性格キー
 * @return {string} - "female" or "male"
 */
function extractGender(personalityKey) {
  return personalityKey.endsWith('_female') ? 'female' : 'male';
}

module.exports = { updatePersonalityStats };