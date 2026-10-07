// バッジ質問への回答を、質問の軸の上で直接採点する（タグは使わない）
// 設計: shared/docs/functions/バッジ診断_設計書.md「採点」

const {safeOpenAICall} = require('../clients/openai');

// 軸ごとの採点基準。-側と+側の説明と、0（中間）と null（判定できない）の例
const AXIS_RUBRICS = {
  energy: {
    label: 'エネルギー（内向 ↔ 外向）',
    negative: '内向：一人の時間や静かな場で元気が回復する。少人数を好む。人と長くいると疲れる',
    positive: '外向：人と関わることで元気が出る。大勢やにぎやかな場を好む。自分から人に関わる',
    middle: '人と会うのも好きだけど一人の時間も同じくらい要る、など両方を同じくらい挙げた',
  },
  judgment: {
    label: '判断（感情 ↔ 論理）',
    negative: '感情：自分や相手の気持ち・共感・好き嫌いを決め手にする',
    positive: '論理：理屈・筋が通っているか・効率・正しさを決め手にする',
    middle: '気持ちと理屈を同じくらい大事にする、場面で使い分けていると具体的に答えた',
  },
  processing: {
    label: '処理（直感 ↔ 分析）',
    negative: '直感：ひらめき・なんとなくの感覚・全体のイメージ・可能性を頼りにする',
    positive: '分析：事実・手順・比較・細部を順に積み上げて考える',
    middle: '直感と分析の両方を同じくらい使う、と具体的に答えた',
  },
  relationship: {
    label: '関わり方（独立 ↔ 協調）',
    negative: '独立：自分のやり方やペースを守る。まず自力で何とかする。干渉されたくない',
    positive: '協調：周りに合わせる。協力する。人に頼る・助ける。和を大事にする',
    middle: '合わせるときと自分を通すときが同じくらいある、と具体的に答えた',
  },
  lifestyle: {
    label: '行動（自由 ↔ 計画）',
    negative: '自由：その場で決める。気分や流れに任せる。ギリギリで仕上げる。変化を好む',
    positive: '計画：前もって予定を立てる。準備する。習慣や整理を保つ。早めに終わらせる',
    middle: '計画するときとその場で決めるときが同じくらいある、と具体的に答えた',
  },
};

const MAX_USER_TEXT = 400;
const MAX_AI_TEXT = 200;

/**
 * 採点プロンプトを作る
 * @param {string} question 質問文
 * @param {string} axis 質問の軸
 * @param {Array<{u:string,a:string}>} turns これまでのやり取り（キャラの返答を含む）
 * @param {string} userMessage 今回のユーザー発言
 * @param {number} userTurn 今回が何回目のユーザー発言か（1始まり）
 * @return {string} プロンプト
 */
function buildScoringPrompt(question, axis, turns, userMessage, userTurn) {
  const r = AXIS_RUBRICS[axis];
  const others = Object.entries(AXIS_RUBRICS)
      .filter(([k]) => k !== axis)
      .map(([k, v]) => `- ${k}: ${v.label}（-:${v.negative} / +:${v.positive}）`)
      .join('\n');

  const lines = [`キャラ: ${question}`];
  for (const t of turns) {
    lines.push(`ユーザー: ${t.u}`);
    lines.push(`キャラ: ${t.a}`);
  }
  lines.push(`ユーザー: ${userMessage}`);

  return `あなたは性格診断の採点者です。キャラクターがユーザーに質問し、会話しています。
ユーザーの発言だけを根拠に、質問の軸でユーザーがどちら寄りかを採点してください。

【質問の軸】${r.label}
-2〜-1: ${r.negative}
+1〜+2: ${r.positive}
0（中間）: ${r.middle}

【会話】
${lines.join('\n')}

【判断の手順】
1. ユーザーは質問に答えているか。質問の場面についての本人の好み・行動・気持ちが書かれていなければ score は null。
   null の例:「うん」「わからん」「別に」、質問と関係のない話、冗談、答えたくないという返事、「場合による」「どっちも」だけで中身がない
2. 答えているなら、どちら寄りか。はっきり言い切っていれば ±2、傾向があれば ±1、両方を同じくらい挙げた・どちらにも強い好みがないと中身を添えて答えたなら 0
3. scoreReady: 具体的な場面や理由つきで傾向（中間を含む）を読み取れるなら true。読み取れないなら false。${userTurn <= 1 ? '今回はユーザーの1回目の返事なので必ず false。' : ''}
4. windingDown: ユーザーの最後の発言が相づちや締めの言葉（「そうだね」「そんな感じ」「ありがとう」など）で、新しい話を広げていなければ true。まだ話を広げている・質問している・語っているなら false
5. topicChanged: ユーザーの最後の発言が質問と関係のない別の話題を始めたなら true
6. sub: 質問の軸以外の軸も、ユーザーの発言からはっきり読み取れたときだけ -2〜+2 で入れる。読み取れなければ空。
${others}

キャラクターの発言は採点の根拠にしない。性格を推測で補わない。

JSONのみで出力:
{"score": -2〜2 または null, "sub": {}, "scoreReady": true/false, "windingDown": true/false, "topicChanged": true/false}`;
}

/** -2〜+2 の整数に丸める。範囲外・数値でなければ null */
function toScore(v) {
  if (typeof v !== 'number' || !Number.isFinite(v)) return null;
  const n = Math.round(v);
  if (n < -2 || n > 2) return null;
  return n;
}

/**
 * AIの出力をアプリで使える形に整える
 * @param {object} raw AIの出力（JSONをパースしたもの）
 * @param {string} axis 質問の軸
 * @param {number} userTurn 何回目のユーザー発言か
 * @return {{score:number|null, sub:object, scoreReady:boolean, windingDown:boolean, topicChanged:boolean}}
 */
function normalizeResult(raw, axis, userTurn) {
  const score = toScore(raw && raw.score);
  const sub = {};
  if (raw && raw.sub && typeof raw.sub === 'object') {
    for (const [k, v] of Object.entries(raw.sub)) {
      if (k === axis || !AXIS_RUBRICS[k]) continue;
      const s = toScore(v);
      if (s !== null) sub[k] = s;
    }
  }
  return {
    score,
    sub,
    // 1回目の返事では確定させない（最低1回は反応して深掘りするため）
    scoreReady: userTurn >= 2 && score !== null && raw.scoreReady === true,
    windingDown: raw.windingDown === true,
    topicChanged: raw.topicChanged === true,
  };
}

/**
 * やり取りを採点する
 * @param {object} openai OpenAIクライアント
 * @param {object} p {question, axis, turns, userMessage, userTurn}
 * @return {Promise<object>} normalizeResult の戻り値。失敗時は何も確定しない結果
 */
async function scoreBadgeConversation(openai, {question, axis, turns, userMessage, userTurn}) {
  const prompt = buildScoringPrompt(
      question, axis,
      turns.map((t) => ({u: (t.u || '').slice(0, MAX_USER_TEXT), a: (t.a || '').slice(0, MAX_AI_TEXT)})),
      userMessage.slice(0, MAX_USER_TEXT), userTurn);
  try {
    const completion = await safeOpenAICall(
        openai.chat.completions.create.bind(openai.chat.completions),
        {
          model: 'gpt-4o-mini',
          messages: [{role: 'user', content: prompt}],
          response_format: {type: 'json_object'},
          max_completion_tokens: 120,
        },
    );
    const usage = completion.usage || {};
    console.log(`📊 badge scoring tokens: input=${usage.prompt_tokens} output=${usage.completion_tokens}`);
    const raw = JSON.parse(completion.choices[0].message.content);
    return normalizeResult(raw, axis, userTurn);
  } catch (e) {
    console.error('⚠️ バッジ採点エラー:', e.message);
    return {score: null, sub: {}, scoreReady: false, windingDown: false, topicChanged: false};
  }
}

module.exports = {
  AXIS_RUBRICS,
  MAX_USER_TEXT,
  MAX_AI_TEXT,
  buildScoringPrompt,
  normalizeResult,
  scoreBadgeConversation,
};
