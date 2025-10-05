// Firebase Functions側での実装例
// このファイルはクライアントアプリには含まれず、Firebase Functions側で実装する内容です

const functions = require('firebase-functions');
const { Configuration, OpenAIApi } = require('openai');

const configuration = new Configuration({
  apiKey: functions.config().openai.key,
});
const openai = new OpenAIApi(configuration);

// キャラクター返答生成
exports.generateCharacterReply = functions
  .region('asia-northeast1')
  .https.onCall(async (data, context) => {
    const { characterId, userMessage, userId, isPremium } = data;

    // サブスクリプション状態に基づくモデル選択
    const model = isPremium ? 'gpt-4o' : 'gpt-3.5-turbo';

    try {
      const completion = await openai.createChatCompletion({
        model: model,
        messages: [
          { role: 'system', content: `あなたは${characterId}のキャラクターです...` },
          { role: 'user', content: userMessage }
        ],
        max_tokens: isPremium ? 800 : 400, // プレミアムは長い返答
        temperature: isPremium ? 0.8 : 0.7  // プレミアムはより創造的
      });

      return {
        reply: completion.data.choices[0].message.content,
        model: model // デバッグ用
      };
    } catch (error) {
      throw new functions.https.HttpsError('internal', 'AI応答生成に失敗しました');
    }
  });

// BIG5性格分析生成
exports.generateBig5Analysis = functions
  .region('asia-northeast1')
  .https.onCall(async (data, context) => {
    const { personalityKey, isPremium } = data;

    // サブスクリプション状態に基づくモデル選択
    const model = isPremium ? 'gpt-4o' : 'gpt-3.5-turbo';

    try {
      const completion = await openai.createChatCompletion({
        model: model,
        messages: [
          {
            role: 'system',
            content: `BIG5性格分析を生成してください。personalityKey: ${personalityKey}...`
          }
        ],
        max_tokens: isPremium ? 3000 : 1500, // プレミアムはより詳細
        temperature: isPremium ? 0.6 : 0.5
      });

      return {
        analysisData: JSON.parse(completion.data.choices[0].message.content),
        model: model
      };
    } catch (error) {
      throw new functions.https.HttpsError('internal', 'BIG5分析生成に失敗しました');
    }
  });

// 予定抽出（常にGPT-3.5-turbo）
exports.extractSchedule = functions
  .region('asia-northeast1')
  .https.onCall(async (data, context) => {
    const { userId, userMessage } = data;

    // 予定抽出は常にGPT-3.5-turbo（コスト効率重視）
    const model = 'gpt-3.5-turbo';

    try {
      const completion = await openai.createChatCompletion({
        model: model,
        messages: [
          {
            role: 'system',
            content: 'ユーザーのメッセージから予定情報を抽出してJSON形式で返答...'
          },
          { role: 'user', content: userMessage }
        ],
        max_tokens: 200,
        temperature: 0.1 // 予定抽出は正確性重視
      });

      return JSON.parse(completion.data.choices[0].message.content);
    } catch (error) {
      throw new functions.https.HttpsError('internal', '予定抽出に失敗しました');
    }
  });

// 実装のポイント：
// 1. isPremiumフラグに基づくモデル選択
// 2. プレミアムユーザーには高品質・長文の応答
// 3. 無料ユーザーには効率的・簡潔な応答
// 4. 予定抽出は常にGPT-3.5-turbo（コスト効率）
// 5. エラーハンドリングとログ記録