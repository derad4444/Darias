// 5軸スコアから元素・タイプ・BIG5を決めて保存する

const {admin} = require('../utils/firebaseInit');
const {generateCharacterDetails} = require('../../const/generateCharacterDetails');
const {hasDecisiveKeyChange} = require('../../const/generatePersonalityKey');
const {OPENAI_API_KEY} = require('../config/config');

// ── 元素判定 ──────────────────────────────────────────
function determineElement(scores) {
  const {energy, judgment, processing} = scores;

  if (energy >= -0.3 && energy <= 0.3) return '無';

  if (energy > 0.3) {
    if (judgment < -0.3) return '炎';
    if (judgment <= 0.3) return '風';
    return processing < 0 ? '雷' : '光';
  }

  // energy < -0.3
  if (judgment < -0.3) return '水';
  if (judgment <= 0.3) return '土';
  return processing < 0 ? '氷' : '闇';
}

// ── 役割判定 ──────────────────────────────────────────
const ROLE_MAP = {
  '炎': {axis: 'relationship', negative: '独り燃える炎タイプ',     positive: '場を沸かす炎タイプ'},
  '風': {axis: 'lifestyle',    negative: '自在に舞う風タイプ',     positive: '目的へ吹く風タイプ'},
  '雷': {axis: 'relationship', negative: '単独で閃く雷タイプ',     positive: '場を揺らす雷タイプ'},
  '光': {axis: 'lifestyle',    negative: '先を駆ける光タイプ',     positive: '道を照らす光タイプ'},
  '水': {axis: 'lifestyle',    negative: '形を変える水タイプ',     positive: '深く湛える水タイプ'},
  '土': {axis: 'relationship', negative: '独り立つ土タイプ',       positive: '静かに支える土タイプ'},
  '氷': {axis: 'relationship', negative: '研ぎ澄ます氷タイプ',     positive: '凛として守る氷タイプ'},
  '闇': {axis: 'lifestyle',    negative: '深く問い続ける闇タイプ', positive: '先を読む闇タイプ'},
  '無': {axis: 'relationship', negative: '何にも染まらぬ無タイプ', positive: '全てに溶け込む無タイプ'},
};

function determineTypeName(element, scores) {
  const role = ROLE_MAP[element];
  return scores[role.axis] >= 0 ? role.positive : role.negative;
}

// ── BIG5変換 ──────────────────────────────────────────
// 各軸スコア（-1〜+1）→ BIG5スコア（1.0〜5.0）
function convertToBig5(scores) {
  const toScore = (v) => (v + 1.0) / 2.0 * 4.0 + 1.0;
  return {
    extraversion:      toScore(scores.energy),
    conscientiousness: toScore(scores.lifestyle),
    agreeableness:     toScore(scores.relationship),
    openness:          toScore(-scores.processing), // 処理スタイルは反転
    neuroticism:       toScore(-scores.judgment),   // 判断基準は反転
  };
}

// ── フレンドの相性結果をstale化 ──────────────────────
async function markCompatibilityStale(db, userId) {
  try {
    const friendsSnap = await db.collection('users').doc(userId).collection('friends').get();
    if (friendsSnap.empty) return;
    const staleOps = [];
    for (const friendDoc of friendsSnap.docs) {
      const friendId = friendDoc.id;
      // 自分の診断結果をstale化
      staleOps.push(
        db.collection('users').doc(userId).collection('compatibilityResults').doc(friendId)
          .update({isStale: true, staleAt: new Date()})
          .catch(() => {}),
      );
      // 相手の診断結果もstale化（自分の性格が変わったため）
      staleOps.push(
        db.collection('users').doc(friendId).collection('compatibilityResults').doc(userId)
          .update({isStale: true, staleAt: new Date()})
          .catch(() => {}),
      );
    }
    await Promise.all(staleOps);
    console.log(`🔄 相性診断をstale化: userId=${userId} friends=${friendsSnap.size}件`);
  } catch (e) {
    console.warn('⚠️ markCompatibilityStale error:', e.message);
  }
}

// ── メイン処理 ────────────────────────────────────────
/**
 * 5軸スコアから元素・タイプ・BIG5を決めて保存し、キャラクター詳細の生成などにつなぐ
 *
 * スコアはバッジ質問の回答から計算したもの（badgeState.computeAxisScores）。
 * 過去の元素は計算に使わない（変化の検知と通知にだけ使う）。
 *
 * @param {string} userId ユーザーID
 * @param {object} axisScores 5軸スコア（-1.0〜+1.0）
 * @param {number} badgeGrowthStage バッジから決まる成長段階（第1弾=1・第2弾=2）
 */
async function diagnoseFromAxisScores(userId, axisScores, badgeGrowthStage) {
  const db = admin.firestore();

  const element = determineElement(axisScores);
  const typeName = determineTypeName(element, axisScores);
  const convertedBig5Scores = convertToBig5(axisScores);

  console.log(`🧮 軸スコア: ${JSON.stringify(axisScores)}`);
  console.log(`🌟 元素=${element} タイプ=${typeName}`);

  // ユーザードキュメントからcharacter_idを取得
  const userDoc = await db.collection('users').doc(userId).get();
  const charId = userDoc.data()?.character_id || userDoc.data()?.characterId;

  if (!charId) {
    console.log(`ℹ️ キャラクター未作成 user=${userId}`);
    return;
  }

  // 変化検知（通知用）
  const detailsRef = db
      .collection('users').doc(userId)
      .collection('characters').doc(charId)
      .collection('details').doc('current');

  const prevSnap = await detailsRef.get();
  const prevElement = prevSnap.data()?.element;
  const prevTypeName = prevSnap.data()?.typeName;
  const gender = prevSnap.data()?.gender || 'neutral';
  const typeChanged = prevElement !== element || prevTypeName !== typeName;

  // details/current を更新
  await detailsRef.set({
    axisScores,
    element,
    typeName,
    convertedBig5Scores,
    axisUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  // 成長ステージを users/{userId} に保存（フレンドが参照できるよう上位ドキュメントに保存）
  // 0=赤ちゃん 1=幼少期（第1弾のバッジがそろった） 2=大人（第2弾もそろった）
  // 回数制の頃に進んだ段階は下げない
  const prevStage = (await db.collection('users').doc(userId).get()).data()?.growthStage || 0;
  const growthStage = Math.max(prevStage, badgeGrowthStage);
  await db.collection('users').doc(userId).set({growthStage}, {merge: true});

  console.log(`✅ 軸スコア保存完了 charId=${charId} user=${userId} growthStage=${growthStage}`);

  // 初回元素決定時（元素が初めてセットされた瞬間）の履歴記録
  if (prevElement === undefined) {
    await db
        .collection('users').doc(userId)
        .collection('characters').doc(charId)
        .collection('personalityHistory')
        .add({
          element,
          typeName,
          gender,
          growthStage,
          recordedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    console.log(`📖 初回性格履歴記録: ${typeName} growthStage=${growthStage}`);
  }

  // 初めて診断したときにキャラクター詳細を生成（axisGeneratedAt がなければ1回だけ実行）
  {
    const prevAxisGeneratedAt = prevSnap.data()?.axisGeneratedAt;
    if (!prevAxisGeneratedAt) {
      console.log(`🎭 初回キャラクター詳細生成トリガー: user=${userId}`);
      try {
        await generateCharacterDetails(charId, userId, OPENAI_API_KEY.value().trim());
        await detailsRef.set({
          axisGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
        console.log(`✅ axisGeneratedAt保存完了 user=${userId}`);

        // 初回は夢が未選択のため、ホーム画面で候補から選んでもらう
        await db
            .collection('users').doc(userId)
            .collection('personalityMeta').doc('current')
            .set({
              pendingFirstDreamSelection: true,
              firstDreamReadyAt: admin.firestore.FieldValue.serverTimestamp(),
            }, {merge: true});
        console.log(`🌠 初回の夢選択フラグをセット user=${userId}`);
      } catch (e) {
        console.error('⚠️ キャラクター詳細生成エラー:', e);
      }
    }
  }

  // 性格タイプ（元素 or タイプ名）が変化した場合
  if (typeChanged && prevElement !== undefined) {
    // personalityMetaに変化フラグを記録（通知はPhase後続で実装）
    await db
        .collection('users').doc(userId)
        .collection('personalityMeta').doc('current')
        .set({
          pendingTypeChangeNotification: true,
          newElement: element,
          newTypeName: typeName,
          typeChangedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
    console.log(`🔔 タイプ変化検知: ${prevTypeName} → ${typeName}`);

    // 性格変動履歴に記録
    await db
        .collection('users').doc(userId)
        .collection('characters').doc(charId)
        .collection('personalityHistory')
        .add({
          element,
          typeName,
          gender,
          growthStage,
          recordedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    console.log(`📖 性格履歴記録: ${typeName} growthStage=${growthStage}`);

    // フレンドの相性診断をstale化
    await markCompatibilityStale(db, userId);

    // 初回生成済みの場合はスコア変化に合わせてキャラクター詳細を再生成
    const prevAxisGeneratedAt = prevSnap.data()?.axisGeneratedAt;
    if (prevAxisGeneratedAt) {
      console.log(`🔄 タイプ変化によりキャラクター詳細を再生成: ${prevTypeName} → ${typeName} user=${userId}`);
      try {
        await generateCharacterDetails(charId, userId, OPENAI_API_KEY.value().trim());
      } catch (e) {
        console.error('⚠️ キャラクター詳細再生成エラー:', e);
      }
    }
    return;
  }

  // タイプ名も元素も変わらないまま Big5スコアだけが動くケースの救済。
  //
  // 属性・夢の候補はタイプ変化時にしか作り直されないため、
  // 放置すると古い性格の口癖・長所・夢がそのまま残る
  // （2026-08-14 に既存10ユーザーで実際に発生していたのを確認しバックフィル済み）。
  // 丸め境界での往復による無駄な再生成を避けるため、判定にはヒステリシスを入れている。
  const prevAxisGeneratedAt = prevSnap.data()?.axisGeneratedAt;
  if (prevAxisGeneratedAt &&
      hasDecisiveKeyChange(prevSnap.data()?.personalityKey, convertedBig5Scores, gender)) {
    console.log(`🔄 性格キー変化によりキャラクター詳細を再生成: ${prevSnap.data()?.personalityKey} user=${userId}`);
    try {
      await generateCharacterDetails(charId, userId, OPENAI_API_KEY.value().trim());
      // フレンドとの相性はBig5スコアから出しているため作り直しが必要
      await markCompatibilityStale(db, userId);
    } catch (e) {
      console.error('⚠️ キャラクター詳細再生成エラー（性格キー変化）:', e);
    }
  }
}

module.exports = {diagnoseFromAxisScores, determineElement, determineTypeName, convertToBig5};
