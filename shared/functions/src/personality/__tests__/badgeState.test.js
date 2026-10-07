const {
  normalizeState, planQuestion, applyQuestionStart, applyScore,
  computeAxisScores, isRoundComplete, PREFIX_REASK, PREFIX_CHAIN, PREFIX_RETAKE_SUGGEST,
} = require('../badgeState');
const {slotsOfRound, badgeOfSlot, BADGES} = require('../badgeQuestions');
const {normalizeResult} = require('../badgeScoring');

const DAY = 24 * 60 * 60 * 1000;
const seq = () => {
  let i = 0;
  return () => ((i++ * 0.37) % 1);
};

/** 質問を出して、指定の点数で答えたことにする */
function answer(state, opts, score, now) {
  const plan = planQuestion(state, opts, now, seq());
  const started = applyQuestionStart(state, plan, now);
  const {state: next, diagnose} = applyScore(started, started.active, {score, sub: {}}, now);
  return {state: {...next, active: null}, diagnose, plan};
}

describe('出題', () => {
  test('第1弾が終わるまで第2弾は出ない', () => {
    let s = normalizeState(null);
    for (let i = 0; i < 10; i++) {
      const r = answer(s, {source: 'opener'}, 1, 1000);
      expect(r.plan.slotKey.startsWith('r1_')).toBe(true);
      s = r.state;
    }
    expect(isRoundComplete(s, 1)).toBe(true);
    const plan = planQuestion(s, {source: 'opener'}, 1000, seq());
    expect(plan.slotKey.startsWith('r2_')).toBe(true);
  });

  test('第1弾が終わっていなければ第2弾のバッジはタップしても出ない', () => {
    const s = normalizeState(null);
    expect(planQuestion(s, {source: 'badge', badgeKey: 'r2_energy'}, 0, seq())).toBeNull();
  });

  test('続けて出すときは直前と別のバッジ・前置きつき', () => {
    const s = normalizeState(null);
    const plan = planQuestion(s, {source: 'chain', excludeBadge: 'r1_energy'}, 0, seq());
    expect(badgeOfSlot(plan.slotKey)).not.toBe('r1_energy');
    expect(plan.prefix).toBe(PREFIX_CHAIN);
  });

  test('答えが確定しなかった質問は同じ質問を前置きつきで出し直す', () => {
    let s = normalizeState(null);
    const plan = planQuestion(s, {source: 'opener'}, 0, seq());
    s = applyQuestionStart(s, plan, 0);
    s = {...s, active: null}; // 確定しないまま終わった
    const again = planQuestion(s, {source: 'opener'}, DAY, seq());
    expect(again.questionId).toBe(plan.questionId);
    expect(again.prefix).toBe(PREFIX_REASK);
  });

  test('同じバッジの2枠には別の質問が出る', () => {
    let s = normalizeState(null);
    const r1 = answer(s, {source: 'badge', badgeKey: 'r1_energy'}, 1, 0);
    s = r1.state;
    const plan2 = planQuestion(s, {source: 'badge', badgeKey: 'r1_energy'}, 0, seq());
    expect(plan2.slotKey).not.toBe(r1.plan.slotKey);
    expect(plan2.questionId).not.toBe(r1.plan.questionId);
  });
});

describe('診断', () => {
  test('第1弾10枠がそろった時点で1回だけ診断する', () => {
    let s = normalizeState(null);
    const diagnoses = [];
    for (let i = 0; i < 10; i++) {
      const r = answer(s, {source: 'opener'}, 2, 1000);
      s = r.state;
      diagnoses.push(r.diagnose);
    }
    expect(diagnoses.filter(Boolean)).toEqual([1]);
    expect(diagnoses[9]).toBe(1);
  });

  test('0点は中間として有効で、軸スコアは平均÷2', () => {
    const s = normalizeState({slots: Object.fromEntries(slotsOfRound(1).map((k) => {
      const axis = BADGES[badgeOfSlot(k)].axis;
      const score = axis === 'energy' ? (k.endsWith('_a') ? 2 : 0) : 0;
      return [k, {questionId: 'x', axis, round: 1, score, answeredAt: 0}];
    }))});
    const scores = computeAxisScores(s, 1);
    expect(scores.energy).toBeCloseTo(0.5);
    expect(scores.judgment).toBe(0);
  });
});

describe('答え直し', () => {
  function fullRound1(score) {
    let s = normalizeState(null);
    for (let i = 0; i < 10; i++) s = answer(s, {source: 'opener'}, score, 0).state;
    return s;
  }

  test('2枠そろうまで今の回答は置き換わらない', () => {
    let s = fullRound1(-2);
    const r1 = answer(s, {source: 'badge', badgeKey: 'r1_energy'}, 2, DAY);
    expect(r1.plan.isRetake).toBe(true);
    expect(r1.diagnose).toBeNull();
    expect(computeAxisScores(r1.state, 1).energy).toBe(-1);
    s = r1.state;
    const r2 = answer(s, {source: 'chain', excludeBadge: 'r1_energy'}, 2, DAY);
    expect(badgeOfSlot(r2.plan.slotKey)).toBe('r1_energy'); // 答え直しを先に終わらせる
    expect(r2.diagnose).toBe(1);
    expect(computeAxisScores(r2.state, 1).energy).toBe(1);
    expect(r2.state.retake).toBeNull();
  });

  test('最後に答えてから180日たつと最初の話題で答え直しを提案する', () => {
    let s = fullRound1(1);
    for (let i = 0; i < 10; i++) s = answer(s, {source: 'opener'}, 1, 0).state;
    expect(planQuestion(s, {source: 'opener'}, 100 * DAY, seq())).toBeNull();
    const plan = planQuestion(s, {source: 'opener'}, 181 * DAY, seq());
    expect(plan.isRetake).toBe(true);
    expect(plan.prefix).toBe(PREFIX_RETAKE_SUGGEST);
    // 続けて出す・バッジ画面以外では提案しない
    expect(planQuestion(s, {source: 'chain'}, 181 * DAY, seq())).toBeNull();
  });
});

describe('採点結果の整形', () => {
  test('1回目の返事では確定させない', () => {
    expect(normalizeResult({score: 2, scoreReady: true}, 'energy', 1).scoreReady).toBe(false);
    expect(normalizeResult({score: 2, scoreReady: true}, 'energy', 2).scoreReady).toBe(true);
  });
  test('null は確定させない・範囲外は捨てる・自軸の sub は捨てる', () => {
    expect(normalizeResult({score: null, scoreReady: true}, 'energy', 3).scoreReady).toBe(false);
    expect(normalizeResult({score: 5}, 'energy', 3).score).toBeNull();
    const r = normalizeResult({score: 0, scoreReady: true, sub: {energy: 1, processing: -1, foo: 2}}, 'energy', 2);
    expect(r.score).toBe(0);
    expect(r.scoreReady).toBe(true);
    expect(r.sub).toEqual({processing: -1});
  });
});
