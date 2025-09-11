const functions = require("firebase-functions");
const admin = require("firebase-admin");
const OpenAI = require("openai");

// OpenAI設定 (最新SDK対応)
const openai = new OpenAI({
  apiKey: functions.config().openai.key, // firebase functions:config:set openai.key="YOUR_KEY"
});

exports.generateBig5Analysis = functions
  .region('asia-northeast1')
  .https
  .onCall(async (data, context) => {
    try {
      const { personalityKey } = data;
      
      if (!personalityKey) {
        throw new functions.https.HttpsError('invalid-argument', 'personalityKey is required');
      }

      // 重複チェック: 既に存在するか確認
      const existingDoc = await admin.firestore()
        .collection('Big5Analysis')
        .doc(personalityKey)
        .get();

      if (existingDoc.exists) {
        const docData = existingDoc.data();
        
        // 生成中フラグがある場合は少し待ってから再チェック
        if (docData.generating) {
          console.log(`Analysis is being generated for ${personalityKey}, waiting...`);
          await new Promise(resolve => setTimeout(resolve, 2000)); // 2秒待機
          
          // 再度確認
          const recheckDoc = await admin.firestore()
            .collection('Big5Analysis')
            .doc(personalityKey)
            .get();
          
          if (recheckDoc.exists && !recheckDoc.data().generating) {
            return recheckDoc.data();
          }
        } else {
          console.log(`Analysis already exists for ${personalityKey}, returning existing data`);
          return docData;
        }
      }

      // 生成中フラグを設定（他のリクエストをブロック）
      await admin.firestore()
        .collection('Big5Analysis')
        .doc(personalityKey)
        .set({
          generating: true,
          started_at: admin.firestore.FieldValue.serverTimestamp()
        });

      // personalityKeyからスコアを解析
      const scores = parsePersonalityKey(personalityKey);
      if (!scores) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid personalityKey format');
      }

      // GPT用プロンプト生成
      const prompt = generatePromptForPersonality(scores);

      // OpenAI API呼び出し（GPT-4o使用・最新SDK対応）
      const response = await openai.chat.completions.create({
        model: "gpt-4o",  // GPT-4からGPT-4oに変更
        messages: [
          {
            role: "system",
            content: "あなたは心理学の専門家です。Big5性格特性に基づいた正確で建設的な性格解析を行ってください。日本人女性の文化的背景を考慮し、500文字程度の詳細で実用的な解析文を作成してください。"
          },
          {
            role: "user", 
            content: prompt
          }
        ],
        max_tokens: 3500,  // GPT-4oは効率的なので少し削減
        temperature: 0.6   // より一貫性のある出力のため少し下げる
      });

      const aiResponse = response.choices[0].message.content;
      
      // JSONを抽出・パース
      const analysisJson = extractJsonFromResponse(aiResponse);
      
      if (!analysisJson) {
        throw new functions.https.HttpsError('internal', 'Failed to parse AI response');
      }

      // Firestoreに保存するデータ構造を作成
      const firestoreData = {
        personality_key: personalityKey,
        last_updated: admin.firestore.FieldValue.serverTimestamp(),
        analysis_20: createAnalysisLevel(analysisJson, 20),
        analysis_50: createAnalysisLevel(analysisJson, 50), 
        analysis_100: createAnalysisLevel(analysisJson, 100),
        generating: false // 生成完了フラグ
      };

      // Firestoreに保存（生成中フラグを削除して完成データで置換）
      await admin.firestore()
        .collection('Big5Analysis')
        .doc(personalityKey)
        .set(firestoreData);

      console.log(`Generated analysis for ${personalityKey}`);
      
      // アプリに返却
      return firestoreData;

    } catch (error) {
      console.error('generateBig5Analysis error:', error);
      
      // エラーが発生した場合は生成中フラグを削除
      try {
        await admin.firestore()
          .collection('Big5Analysis')
          .doc(data.personalityKey)
          .delete();
      } catch (deleteError) {
        console.error('Failed to cleanup generating flag:', deleteError);
      }
      
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

// personalityKeyからスコアを解析
function parsePersonalityKey(key) {
  const match = key.match(/^O(\d+)_C(\d+)_E(\d+)_A(\d+)_N(\d+)_(.+)$/);
  if (!match) return null;
  
  return {
    openness: parseInt(match[1]),
    conscientiousness: parseInt(match[2]),
    extraversion: parseInt(match[3]),
    agreeableness: parseInt(match[4]),
    neuroticism: parseInt(match[5]),
    gender: match[6]
  };
}

// GPT用プロンプト生成
function generatePromptForPersonality(scores) {
  const traits = [
    `経験への開放性: ${scores.openness}/5 (${getTraitDescription('openness', scores.openness)})`,
    `誠実性: ${scores.conscientiousness}/5 (${getTraitDescription('conscientiousness', scores.conscientiousness)})`,
    `外向性: ${scores.extraversion}/5 (${getTraitDescription('extraversion', scores.extraversion)})`,
    `協調性: ${scores.agreeableness}/5 (${getTraitDescription('agreeableness', scores.agreeableness)})`,
    `情緒安定性: ${scores.neuroticism}/5 (${getTraitDescription('neuroticism', scores.neuroticism)})`
  ];

  return `以下のBig5性格特性を持つ${scores.gender === 'female' ? '女性' : '男性'}の詳細な性格解析を、5つのカテゴリー別に作成してください。

【Big5スコア】
${traits.join('\n')}

【出力形式】
以下のJSON形式で出力してください：

\`\`\`json
{
  "career": {
    "personality_type": "○○タイプ（15文字程度）",
    "detailed_text": "500文字の詳細解析文",
    "key_points": ["特徴1", "特徴2", "特徴3", "特徴4"]
  },
  "romance": {
    "personality_type": "○○タイプ（15文字程度）", 
    "detailed_text": "500文字の詳細解析文",
    "key_points": ["特徴1", "特徴2", "特徴3", "特徴4"]
  },
  "stress": {
    "personality_type": "○○タイプ（15文字程度）",
    "detailed_text": "500文字の詳細解析文", 
    "key_points": ["特徴1", "特徴2", "特徴3", "特徴4"]
  },
  "learning": {
    "personality_type": "○○タイプ（15文字程度）",
    "detailed_text": "500文字の詳細解析文",
    "key_points": ["特徴1", "特徴2", "特徴3", "特徴4"]
  },
  "decision": {
    "personality_type": "○○タイプ（15文字程度）",
    "detailed_text": "500文字の詳細解析文",
    "key_points": ["特徴1", "特徴2", "特徴3", "特徴4"]
  }
}
\`\`\`

【重要な条件】
1. detailed_textは必ず500文字程度にしてください
2. 心理学的に正確で、このスコア組み合わせに特有の特徴を反映させてください  
3. 前向きで建設的な表現を使用してください
4. 具体的で実用的な内容にしてください
5. 日本人の文化的背景を考慮してください`;
}

// 特性の説明文を生成
function getTraitDescription(trait, score) {
  const descriptions = {
    openness: ['伝統重視・現実的', 'やや保守的', 'バランス型', '新しいもの好き', '創造性重視・冒険的'],
    conscientiousness: ['自由奔放・柔軟', 'やや自由', 'バランス型', '計画的・責任感', '完璧主義・規律重視'],
    extraversion: ['内向的・一人好み', 'やや内向的', 'バランス型', '社交的・活動的', '非常に外向的・エネルギッシュ'],
    agreeableness: ['競争的・批判的', 'やや競争的', 'バランス型', '協力的・思いやり', '非常に協調的・利他的'],
    neuroticism: ['非常に情緒安定', '情緒安定', 'バランス型', 'やや敏感', '情緒不安定・敏感']
  };
  
  return descriptions[trait] ? descriptions[trait][score - 1] : 'バランス型';
}

// AI応答からJSONを抽出
function extractJsonFromResponse(response) {
  try {
    const jsonMatch = response.match(/```json\s*([\s\S]*?)\s*```/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[1]);
    }
    
    // ```なしの場合も試行
    const cleanResponse = response.replace(/^[^{]*/, '').replace(/[^}]*$/, '');
    return JSON.parse(cleanResponse);
  } catch (error) {
    console.error('JSON parse error:', error);
    return null;
  }
}

// 解析レベル別データ作成
function createAnalysisLevel(analysisJson, level) {
  const categories = level === 20 
    ? ['career', 'romance', 'stress']  // 基本解析
    : ['career', 'romance', 'stress', 'learning', 'decision']; // 詳細・完全解析
  
  const result = {};
  categories.forEach(category => {
    if (analysisJson[category]) {
      result[category] = analysisJson[category];
    }
  });
  
  return result;
}