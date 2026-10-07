// バッジ診断の状態を扱う純粋な関数（Firestore には触らない）
// 状態は users/{uid}/personalityBadges/current に1文書で持つ。
// 設計: shared/docs/functions/バッジ診断_設計書.md

const {
  BADGES, AXES, SLOT_SUFFIXES,
  questionsOfBadge, badgeOfSlot, slotsOfRound,
} = require('./badgeQuestions');

// 最後に答えてからこの日数がたったバッジは、最初の話題で答え直しを提案する
const RETAKE_SUGGEST_DAYS = 180;
// 採点するのはユーザーの発言この回数まで
const MAX_SCORING_TURNS = 5;
// 最後のやり取りからこの時間がたった回答中の状態は、終わったものとして扱う
const ACTIVE_STALE_MS = 6 * 60 * 60 * 1000;

const PREFIX_REASK = 'この前の質問、もう一度聞いてもいい？';
const PREFIX_RETAKE_SUGGEST = '久しぶりに聞いてもいい？';
const PREFIX_CHAIN = 'ねえ、もう一つ聞いてみたいんだけど…';

/** 状態の初期値を補う */
function normalizeState(raw) {
  const s = raw || {};
  return {
    slots: s.slots || {},
    assigned: s.assigned || {},
    askedQuestionIds: Array.isArray(s.askedQuestionIds) ? s.askedQuestionIds : [],
    retake: s.retake || null,
    active: s.active || null,
    round1CompletedAt: s.round1CompletedAt || null,
    round2CompletedAt: s.round2CompletedAt || null,
  };
}

/** Timestamp / Date / ミリ秒をミリ秒にする */
function toMillis(v) {
  if (!v) return 0;
  if (typeof v === 'number') return v;
  if (typeof v.toMillis === 'function') return v.toMillis();
  if (v instanceof Date) return v.getTime();
  return 0;
}

function isRoundComplete(state, round) {
  return slotsOfRound(round).every((k) => state.slots[k]);
}

/** 回答中の状態が今も有効か */
function isActiveFresh(active, now) {
  if (!active) return false;
  return now - toMillis(active.updatedAt) < ACTIVE_STALE_MS;
}

/** 枠の「割り当て」のキー。答え直しは本来の枠と分けて持つ */
function assignKey(slotKey, isRetake) {
  return isRetake ? `retake_${slotKey}` : slotKey;
}

/**
 * 枠に出す質問を選ぶ
 * まだ出していない質問からランダムに選ぶ。同じバッジのもう一方の枠と同じ質問は避ける。
 * 出し切っていたら、一番前に出した質問から再利用する。
 */
function chooseQuestionId(state, slotKey, isRetake, random) {
  const badgeKey = badgeOfSlot(slotKey);
  const sibling = SLOT_SUFFIXES
      .map((s) => `${badgeKey}_${s}`)
      .filter((k) => k !== slotKey);
  const avoid = new Set();
  for (const k of sibling) {
    const a = state.assigned[assignKey(k, isRetake)];
    if (a) avoid.add(a.questionId);
    if (!isRetake && state.slots[k]) avoid.add(state.slots[k].questionId);
    if (isRetake && state.retake && state.retake.answers && state.retake.answers[k]) {
      avoid.add(state.retake.answers[k].questionId);
    }
  }
  // 答え直しでは、今の回答と同じ質問を避ける
  if (isRetake) {
    for (const s of SLOT_SUFFIXES) {
      const cur = state.slots[`${badgeKey}_${s}`];
      if (cur) avoid.add(cur.questionId);
    }
  }

  const pool = questionsOfBadge(badgeKey).filter((id) => !avoid.has(id));
  const asked = new Set(state.askedQuestionIds);
  const fresh = pool.filter((id) => !asked.has(id));
  if (fresh.length > 0) return fresh[Math.floor(random() * fresh.length)];
  // 出し切ったら、一番前に出した質問から
  const oldest = state.askedQuestionIds.find((id) => pool.includes(id));
  return oldest || pool[0];
}

/** 答え直しの状態で、まだ答えていない枠 */
function retakeOpenSlots(state) {
  if (!state.retake) return [];
  const answers = state.retake.answers || {};
  return SLOT_SUFFIXES
      .map((s) => `${state.retake.badge}_${s}`)
      .filter((k) => !answers[k]);
}

/** 未回答の枠（第1弾が終わるまで第2弾は出さない） */
function openSlots(state) {
  for (const round of [1, 2]) {
    const open = slotsOfRound(round).filter((k) => !state.slots[k]);
    if (open.length > 0) return open;
  }
  return [];
}

/** 最後に答えてから RETAKE_SUGGEST_DAYS 以上たったバッジのうち、一番古いもの */
function staleBadge(state, now) {
  let oldest = null;
  let oldestAt = Infinity;
  for (const badgeKey of Object.keys(BADGES)) {
    const times = SLOT_SUFFIXES.map((s) => state.slots[`${badgeKey}_${s}`])
        .filter(Boolean).map((e) => toMillis(e.answeredAt));
    if (times.length < SLOT_SUFFIXES.length) continue;
    const latest = Math.max(...times);
    if (now - latest >= RETAKE_SUGGEST_DAYS * 24 * 60 * 60 * 1000 && latest < oldestAt) {
      oldest = badgeKey;
      oldestAt = latest;
    }
  }
  return oldest;
}

/** 候補の枠から1つ選ぶ。出題済みで答えを待っている枠を優先し、直前と同じバッジは避ける */
function pickSlot(state, candidates, isRetake, excludeBadge, random) {
  let list = candidates;
  if (excludeBadge) {
    const others = list.filter((k) => badgeOfSlot(k) !== excludeBadge);
    if (others.length > 0) list = others;
  }
  const pending = list.filter((k) => state.assigned[assignKey(k, isRetake)]);
  if (pending.length > 0) return pending[0];
  return list[Math.floor(random() * list.length)];
}

/**
 * 次に出す質問を決める（状態は変えない）
 * @param {object} state normalizeState 済みの状態
 * @param {object} opts
 *   source: 'opener'（最初の話題） | 'chain'（回答のあと続けて） | 'badge'（バッジ画面から）
 *   badgeKey: source='badge' のときのバッジ
 *   excludeBadge: 直前に答えたバッジ（続けて同じ軸を聞かない）
 * @return {object|null} {slotKey, questionId, isRetake, startRetake, prefix}
 */
function planQuestion(state, opts, now, random = Math.random) {
  const {source, badgeKey, excludeBadge} = opts;

  const build = (slotKey, isRetake, prefixOverride, startRetake = null) => {
    const a = state.assigned[assignKey(slotKey, isRetake)];
    const questionId = a ? a.questionId : chooseQuestionId(state, slotKey, isRetake, random);
    let prefix = prefixOverride || '';
    // 前に出して答えが確定しなかった質問は、前置きを付けて聞き直す
    if (a && a.askCount >= 1 && source !== 'badge') prefix = PREFIX_REASK;
    return {slotKey, questionId, isRetake, startRetake, prefix};
  };

  if (source === 'badge') {
    const badge = BADGES[badgeKey];
    if (!badge) return null;
    if (badge.round === 2 && !isRoundComplete(state, 1)) return null;
    const open = SLOT_SUFFIXES.map((s) => `${badgeKey}_${s}`).filter((k) => !state.slots[k]);
    if (open.length > 0) return build(pickSlot(state, open, false, null, random), false);
    // 取得済みのバッジは答え直し
    if (state.retake && state.retake.badge === badgeKey) {
      const ro = retakeOpenSlots(state);
      if (ro.length > 0) return build(pickSlot(state, ro, true, null, random), true);
    }
    const slotKey = `${badgeKey}_${SLOT_SUFFIXES[0]}`;
    return build(slotKey, true, '', badgeKey);
  }

  const chainPrefix = source === 'chain' ? PREFIX_CHAIN : '';

  // 答え直しの途中なら、先にそれを終わらせる
  const ro = retakeOpenSlots(state);
  if (ro.length > 0) return build(pickSlot(state, ro, true, null, random), true, chainPrefix);

  const open = openSlots(state);
  if (open.length > 0) return build(pickSlot(state, open, false, excludeBadge, random), false, chainPrefix);

  // 全部答えた人には、半年たったバッジの答え直しを最初の話題でだけ提案する
  if (source === 'opener') {
    const stale = staleBadge(state, now);
    if (stale) {
      return build(`${stale}_${SLOT_SUFFIXES[0]}`, true, PREFIX_RETAKE_SUGGEST, stale);
    }
  }
  return null;
}

/**
 * planQuestion の結果を状態に反映する（質問を出したことにする）
 * @return {object} 新しい状態（引数は変えない）
 */
function applyQuestionStart(state, plan, now) {
  const next = JSON.parse(JSON.stringify(state));
  if (plan.startRetake) {
    // 別のバッジの答え直しが途中なら、それは捨てて新しく始める
    if (next.retake && next.retake.badge !== plan.startRetake) {
      for (const s of SLOT_SUFFIXES) delete next.assigned[assignKey(`${next.retake.badge}_${s}`, true)];
    }
    if (!next.retake || next.retake.badge !== plan.startRetake) {
      next.retake = {badge: plan.startRetake, answers: {}};
    }
  }
  const key = assignKey(plan.slotKey, plan.isRetake);
  const prev = next.assigned[key];
  next.assigned[key] = {
    questionId: plan.questionId,
    askedAt: now,
    askCount: prev ? (prev.askCount || 0) + 1 : 1,
  };
  next.askedQuestionIds = next.askedQuestionIds.filter((id) => id !== plan.questionId);
  next.askedQuestionIds.push(plan.questionId);
  next.active = {
    slotKey: plan.slotKey,
    questionId: plan.questionId,
    isRetake: plan.isRetake,
    startedAt: now,
    updatedAt: now,
    turns: [],
    scored: false,
  };
  return next;
}

/**
 * 採点できた回答を状態に保存する
 * @return {{state: object, diagnose: number|null}} diagnose は診断に使う弾の数（1 or 2）。診断しないなら null
 */
function applyScore(state, active, result, now) {
  const next = JSON.parse(JSON.stringify(state));
  const axis = BADGES[badgeOfSlot(active.slotKey)].axis;
  const round = BADGES[badgeOfSlot(active.slotKey)].round;
  const entry = {
    questionId: active.questionId,
    axis,
    round,
    score: result.score,
    sub: result.sub || {},
    answeredAt: now,
  };
  delete next.assigned[assignKey(active.slotKey, active.isRetake)];

  let diagnose = null;
  if (active.isRetake) {
    if (!next.retake || next.retake.badge !== badgeOfSlot(active.slotKey)) {
      next.retake = {badge: badgeOfSlot(active.slotKey), answers: {}};
    }
    next.retake.answers[active.slotKey] = entry;
    // 2枠そろったら置き換える（片方だけ新しい状態で診断を動かさない）
    if (retakeOpenSlots(next).length === 0) {
      for (const [k, v] of Object.entries(next.retake.answers)) next.slots[k] = v;
      next.retake = null;
      if (isRoundComplete(next, 1)) diagnose = isRoundComplete(next, 2) ? 2 : 1;
    }
  } else {
    next.slots[active.slotKey] = entry;
    if (round === 1 && !next.round1CompletedAt && isRoundComplete(next, 1)) {
      next.round1CompletedAt = now;
      diagnose = 1;
    }
    if (round === 2 && !next.round2CompletedAt && isRoundComplete(next, 2)) {
      next.round2CompletedAt = now;
      diagnose = 2;
    }
  }
  return {state: next, diagnose};
}

/**
 * バッジの回答から5軸スコアを計算する（-1.0〜+1.0）
 * 軸スコア = その軸の回答の score の平均 ÷ 2
 * @param {object} state 状態
 * @param {number} rounds 使う弾の数（1 なら第1弾の10枠、2 なら20枠）
 */
function computeAxisScores(state, rounds) {
  const sums = Object.fromEntries(AXES.map((a) => [a, 0]));
  const counts = Object.fromEntries(AXES.map((a) => [a, 0]));
  for (let round = 1; round <= rounds; round++) {
    for (const k of slotsOfRound(round)) {
      const e = state.slots[k];
      if (!e || typeof e.score !== 'number') continue;
      sums[e.axis] += e.score;
      counts[e.axis] += 1;
    }
  }
  const scores = {};
  for (const a of AXES) scores[a] = counts[a] > 0 ? (sums[a] / counts[a]) / 2 : 0;
  return scores;
}

/** バッジの進み具合（そのバッジで何枠答えたか） */
function badgeProgress(state, badgeKey) {
  return SLOT_SUFFIXES.filter((s) => state.slots[`${badgeKey}_${s}`]).length;
}

module.exports = {
  RETAKE_SUGGEST_DAYS,
  MAX_SCORING_TURNS,
  ACTIVE_STALE_MS,
  PREFIX_REASK,
  PREFIX_RETAKE_SUGGEST,
  PREFIX_CHAIN,
  normalizeState,
  toMillis,
  isRoundComplete,
  isActiveFresh,
  planQuestion,
  applyQuestionStart,
  applyScore,
  computeAxisScores,
  badgeProgress,
};
