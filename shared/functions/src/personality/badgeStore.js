// バッジ診断の状態の読み書き（users/{uid}/personalityBadges/current）
// 書き込みはサーバーだけ。本人は読み取りのみ（firestore.rules）
// 設計: shared/docs/functions/バッジ診断_設計書.md

const {admin} = require('../utils/firebaseInit');
const {BADGE_QUESTIONS, BADGES, badgeOfSlot} = require('./badgeQuestions');
const {scoreBadgeConversation, MAX_USER_TEXT, MAX_AI_TEXT} = require('./badgeScoring');
const {
  MAX_SCORING_TURNS,
  normalizeState, isActiveFresh, planQuestion, applyQuestionStart,
  applyScore, computeAxisScores, badgeProgress,
} = require('./badgeState');
const {diagnoseFromAxisScores} = require('./axisCalculator');

// キャラクターからの深掘りはこの往復まで。以降は普通に会話する
const MAX_DEEPEN_TURNS = 3;

function stateRef(userId) {
  return admin.firestore()
      .collection('users').doc(userId)
      .collection('personalityBadges').doc('current');
}

/** クライアントに返す質問の形 */
function toQuestionPayload(plan) {
  const badgeKey = badgeOfSlot(plan.slotKey);
  return {
    questionId: plan.questionId,
    text: BADGE_QUESTIONS[plan.questionId],
    prefix: plan.prefix || '',
    badgeKey,
    badgeName: BADGES[badgeKey].name,
    round: BADGES[badgeKey].round,
    isRetake: plan.isRetake,
  };
}

/**
 * 質問を出す（回答中の状態にする）
 * @param {string} userId ユーザーID
 * @param {object} opts {source: 'opener'|'badge', badgeKey}
 * @return {Promise<object|null>} 出す質問。出す質問がなければ null
 */
async function startQuestion(userId, opts) {
  const ref = stateRef(userId);
  const now = Date.now();
  return admin.firestore().runTransaction(async (t) => {
    const state = normalizeState((await t.get(ref)).data());

    // 同じ日にアプリを開き直したときは、答えを待っている質問をそのまま出す
    if (opts.source === 'opener' && isActiveFresh(state.active, now)) {
      const a = state.active;
      return toQuestionPayload({slotKey: a.slotKey, questionId: a.questionId, isRetake: a.isRetake, prefix: ''});
    }

    const plan = planQuestion(state, opts, now);
    if (!plan) return null;
    t.set(ref, applyQuestionStart(state, plan, now));
    return toQuestionPayload(plan);
  });
}

/**
 * 返答を作る前に、回答中の質問への発言を採点する
 *
 * 採点を先にして、その結果（深掘りする・会話を続ける・締める）を返答の生成に渡す。
 * 状態の保存は返答ができてから commit() で行う（返答の文もやり取りに残すため）。
 *
 * @param {string} userId ユーザーID
 * @param {string} userMessage 今回の発言
 * @param {object} openai OpenAIクライアント
 * @return {Promise<object|null>} 回答中でなければ null。
 *   {badgeContext, commit(reply) => Promise<{earned, nextQuestion, diagnosed}>}
 */
async function handleAnswer(userId, userMessage, openai) {
  const ref = stateRef(userId);
  const now = Date.now();
  const snap = await ref.get();
  if (!snap.exists) return null;
  let state = normalizeState(snap.data());
  const active = state.active;
  if (!active) return null;

  // 長く間が空いた回答中の状態は終わりにする（質問は回答待ちのまま残る）
  if (!isActiveFresh(active, now)) {
    await ref.set({...state, active: null});
    return null;
  }

  const questionText = BADGE_QUESTIONS[active.questionId];
  const badgeKey = badgeOfSlot(active.slotKey);
  const badge = BADGES[badgeKey];
  const userTurn = (active.turns || []).length + 1;

  const result = await scoreBadgeConversation(openai, {
    question: questionText,
    axis: badge.axis,
    turns: active.turns || [],
    userMessage,
    userTurn,
  });
  console.log(`🏅 バッジ採点 user=${userId} q=${active.questionId} turn=${userTurn} ` +
      `score=${result.score} ready=${result.scoreReady} winding=${result.windingDown} topic=${result.topicChanged}`);

  let earned = null;
  let diagnoseRounds = null;
  let scored = active.scored === true;
  if (!scored && result.scoreReady) {
    const applied = applyScore(state, active, result, now);
    state = applied.state;
    diagnoseRounds = applied.diagnose;
    scored = true;
    earned = {
      badgeKey,
      badgeName: badge.name,
      round: badge.round,
      isRetake: active.isRetake === true,
      progress: badgeProgress(state, badgeKey),
    };
  }

  // 回答中を終えるか
  const closing = scored && result.windingDown && !result.topicChanged;
  const ended = result.topicChanged || closing || userTurn >= MAX_SCORING_TURNS;

  // 返答への指示
  let mode = null;
  if (!result.topicChanged) {
    if (closing) mode = 'closing';
    else if (!scored && userTurn <= MAX_DEEPEN_TURNS) mode = 'deepen';
    else mode = 'continue';
  }
  const badgeContext = mode ? {question: questionText, userTurn, mode} : null;

  // 締めたら、続けて次の質問を出す（なるべく別のバッジ）
  let nextPlan = null;
  if (closing) {
    const base = {...state, active: null};
    nextPlan = planQuestion(base, {source: 'chain', excludeBadge: badgeKey}, now);
  }

  // 診断は返答の生成と並行して進める（キャラクター詳細の生成に時間がかかるため）
  let diagnosis = Promise.resolve(false);
  if (diagnoseRounds) {
    const scores = computeAxisScores(state, diagnoseRounds);
    console.log(`🧮 バッジ診断 user=${userId} rounds=${diagnoseRounds} scores=${JSON.stringify(scores)}`);
    diagnosis = diagnoseFromAxisScores(userId, scores, diagnoseRounds)
        .then(() => true)
        .catch((e) => {
          console.error('⚠️ バッジ診断エラー:', e);
          return false;
        });
  }

  const commit = async (reply) => {
    let next = {...state};
    if (ended) {
      next.active = null;
    } else {
      next.active = {
        ...active,
        scored,
        updatedAt: now,
        turns: [...(active.turns || []), {
          u: userMessage.slice(0, MAX_USER_TEXT),
          a: (reply || '').slice(0, MAX_AI_TEXT),
        }],
      };
    }
    if (nextPlan) next = applyQuestionStart({...next, active: null}, nextPlan, now);
    // 回答中のやり取り（本文）は回答中だけ持ち、終わったら消える
    await ref.set(next);
    const diagnosed = await diagnosis;
    return {
      earned,
      nextQuestion: nextPlan ? toQuestionPayload(nextPlan) : null,
      diagnosed,
    };
  };

  return {badgeContext, commit};
}

module.exports = {startQuestion, handleAnswer, MAX_DEEPEN_TURNS};
