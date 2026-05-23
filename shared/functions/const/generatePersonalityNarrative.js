// 週次ナラティブ生成 - 毎週日曜日 2:00 AM JST に実行
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {getOpenAIClient, safeOpenAICall} = require('../src/clients/openai');
const {OPENAI_API_KEY} = require('../src/config/config');
const {getFirestore, admin} = require('../src/utils/firebaseInit');

const db = getFirestore();

const VALID_ELEMENTS = ['炎', '水', '風', '土', '雷', '光', '氷', '闇', '無'];

async function generateNarrativeText(openai, axisScores, typeName) {
  const fmt = (v) => (v >= 0 ? `+${v.toFixed(2)}` : v.toFixed(2));
  const prompt = `ユーザーの会話から分析した最近の性格傾向を100〜150文字で説明してください。

性格タイプ: ${typeName || '分析中'}
5軸スコア（-1.0〜+1.0、正が右端方向）:
- エネルギー（内向↔外向）: ${fmt(axisScores.energy ?? 0)}
- 判断基準（感情↔論理）: ${fmt(axisScores.judgment ?? 0)}
- 関わり方（独立↔協調）: ${fmt(axisScores.relationship ?? 0)}
- 行動スタイル（自由↔計画）: ${fmt(axisScores.lifestyle ?? 0)}
- 処理スタイル（直感↔分析）: ${fmt(axisScores.processing ?? 0)}

「最近〜な傾向があります」で始まる自然な日本語を1文だけ出力してください。数値や記号は含めないこと。`;

  const completion = await safeOpenAICall(
      openai.chat.completions.create.bind(openai.chat.completions),
      {
        model: 'gpt-4o-mini',
        messages: [{role: 'user', content: prompt}],
        max_completion_tokens: 200,
      },
  );

  return completion.choices[0].message.content.trim();
}

exports.generatePersonalityNarrative = onSchedule(
    {
      schedule: '0 2 * * 0',
      timeZone: 'Asia/Tokyo',
      region: 'asia-northeast1',
      memory: '512MiB',
      timeoutSeconds: 540,
    },
    async (event) => {
      console.log('🌙 週次ナラティブ生成開始');
      const openai = getOpenAIClient(OPENAI_API_KEY.value().trim());

      // element が有効値を持つ details/current を全ユーザーから収集
      // ※ コレクショングループクエリ（Firestoreコンソールでインデックス作成が必要）
      const detailsSnap = await db.collectionGroup('details')
          .where('element', 'in', VALID_ELEMENTS)
          .get();

      console.log(`📊 対象ドキュメント数: ${detailsSnap.size}`);

      let successCount = 0;
      let errorCount = 0;

      for (const detailDoc of detailsSnap.docs) {
        try {
          const data = detailDoc.data();
          const axisScores = data.axisScores;
          if (!axisScores) continue;

          // パス: users/{userId}/characters/{charId}/details/current
          const pathParts = detailDoc.ref.path.split('/');
          if (pathParts.length < 6 || pathParts[4] !== 'details') continue;
          const userId = pathParts[1];

          // ナラティブ生成
          const narrative = await generateNarrativeText(openai, axisScores, data.typeName || null);

          // 保存
          await detailDoc.ref.update({
            personalityNarrative: narrative,
            narrativeUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          console.log(`✅ ナラティブ生成完了 userId=${userId}`);
          successCount++;

          // 変化通知フラグのクリア（FCM送信は将来実装）
          const metaRef = db.collection('users').doc(userId)
              .collection('personalityMeta').doc('current');
          const metaSnap = await metaRef.get();

          if (metaSnap.exists && metaSnap.data()?.pendingTypeChangeNotification) {
            const newTypeName = metaSnap.data().newTypeName;
            console.log(`🔔 タイプ変化通知処理 userId=${userId}: ${newTypeName}`);
            await metaRef.update({
              pendingTypeChangeNotification: false,
              lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          console.error(`⚠️ ナラティブ生成エラー path=${detailDoc.ref.path}:`, e);
          errorCount++;
        }
      }

      console.log(`🌙 週次ナラティブ生成完了: 成功=${successCount} エラー=${errorCount}`);
    },
);
