// 最適化されたプロンプト版 Firebase Functions実装例

const functions = require('firebase-functions');
const { Configuration, OpenAIApi } = require('openai');

// キャラクター返答生成（最適化版）
exports.generateCharacterReply = functions
  .region('asia-northeast1')
  .https.onCall(async (data, context) => {
    const { characterId, userMessage, userId, isPremium } = data;

    const model = isPremium ? 'gpt-4o' : 'gpt-3.5-turbo';

    // 最小限プロンプト（500文字 → 1,250トークン）
    const systemPrompt = `キャラクター: ${characterId}
性格: 親しみやすい
ユーザー: ${userMessage}

150文字以内で自然に返答。
JSON: {"reply": "返答内容"}`;

    try {
      const completion = await openai.createChatCompletion({
        model: model,
        messages: [
          { role: 'system', content: systemPrompt }
        ],
        max_tokens: 400, // 出力も削減
        temperature: 0.7
      });

      return JSON.parse(completion.data.choices[0].message.content);
    } catch (error) {
      throw new functions.https.HttpsError('internal', 'AI応答生成に失敗');
    }
  });

// 予定抽出（最適化版）
exports.extractSchedule = functions
  .region('asia-northeast1')
  .https.onCall(async (data, context) => {
    const { userMessage } = data;

    // 最小限プロンプト（100文字 → 250トークン）
    const systemPrompt = `予定抽出:
入力: ${userMessage}
出力: {"hasSchedule": bool, "date": "YYYY-MM-DD", "title": "予定名"}`;

    try {
      const completion = await openai.createChatCompletion({
        model: 'gpt-3.5-turbo', // 常に3.5
        messages: [
          { role: 'system', content: systemPrompt }
        ],
        max_tokens: 100,
        temperature: 0.1
      });

      return JSON.parse(completion.data.choices[0].message.content);
    } catch (error) {
      throw new functions.https.HttpsError('internal', '予定抽出に失敗');
    }
  });

// BIG5分析生成（最適化版）
exports.generateBig5Analysis = functions
  .region('asia-northeast1')
  .https.onCall(async (data, context) => {
    const { personalityKey, isPremium } = data;

    const model = isPremium ? 'gpt-4o' : 'gpt-3.5-turbo';

    // 最小限プロンプト（200文字 → 500トークン）
    const systemPrompt = `性格分析生成:
Key: ${personalityKey}
出力: {"career": "適職", "romance": "恋愛傾向", "stress": "ストレス"}
各項目50文字以内。`;

    try {
      const completion = await openai.createChatCompletion({
        model: model,
        messages: [
          { role: 'system', content: systemPrompt }
        ],
        max_tokens: isPremium ? 3000 : 1200, // プレミアムは詳細
        temperature: 0.6
      });

      return JSON.parse(completion.data.choices[0].message.content);
    } catch (error) {
      throw new functions.https.HttpsError('internal', 'BIG5分析生成に失敗');
    }
  });

// プロンプト最適化のポイント:
// 1. 冗長な説明を削除
// 2. 必要最小限の指示に集約
// 3. JSON出力形式を明確化
// 4. 文字数制限を厳格化
// 5. システム固有の複雑な条件を簡素化