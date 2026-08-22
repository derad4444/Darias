// Optimized prompt templates for cost reduction
// Token count reduced by 60-80% while maintaining functionality

// Big5各スコア（1-5）の詳細説明
const TRAIT_DESCRIPTIONS = {
  openness: {
    1: "慣れ親しんだ環境を強く好み変化を避ける",
    2: "安定した慣れた環境を好む",
    3: "新しさと安定のバランスを取る",
    4: "新しい体験や創造を好む",
    5: "非常に好奇心旺盛で創造性と変化を強く求める",
  },
  conscientiousness: {
    1: "自由で柔軟なペースを好み計画に縛られない",
    2: "柔軟でゆるやかなペースを好む",
    3: "状況に応じて計画的にも柔軟にもなれる",
    4: "計画的でルーティンや目標達成を大切にする",
    5: "非常に几帳面で責任感が強く目標に向けて粘り強い",
  },
  extraversion: {
    1: "一人の時間を強く必要とし内省的",
    2: "一人の静かな時間を大切にする",
    3: "状況に応じて社交的にも内向的にもなれる",
    4: "人との交流が活力源の社交的な性格",
    5: "非常に社交的でエネルギッシュ、人との交流を強く求める",
  },
  agreeableness: {
    1: "自分の意見や目標を強く優先する",
    2: "自分軸を大切にする",
    3: "自分の意見を持ちながら他者とも協調できる",
    4: "思いやりがあり仲間との協力を重んじる",
    5: "非常に共感力が高く他者への配慮を最優先にする",
  },
  neuroticism: {
    1: "非常に感情が安定していてストレスに強い",
    2: "感情が安定していてストレスに強い",
    3: "感情の波は程々でストレス管理は状況による",
    4: "感受性が豊かでセルフケアを大切にする",
    5: "非常に感受性が高く感情の波が大きい",
  },
};

// コンパクト表示用の短いラベル
const TRAIT_SHORT_LABELS = {
  openness:          {1: "保守的", 2: "安定志向", 3: "バランス型", 4: "好奇心旺盛", 5: "革新的"},
  conscientiousness: {1: "自由奔放", 2: "柔軟型", 3: "状況対応型", 4: "計画的", 5: "几帳面"},
  extraversion:      {1: "内省的", 2: "内向的", 3: "両向型", 4: "社交的", 5: "外向的"},
  agreeableness:     {1: "自己主張型", 2: "自分軸型", 3: "バランス型", 4: "協調的", 5: "共感型"},
  neuroticism:       {1: "超安定", 2: "安定型", 3: "中程度", 4: "感受性高", 5: "高感受性"},
};

/**
 * Big5スコアをラベル参照用の 1〜5 の整数に正規化する
 *
 * `convertedBig5Scores` は axisCalculator の `convertToBig5()` が返す連続値（例: 3.4）。
 * TRAIT_DESCRIPTIONS / TRAIT_SHORT_LABELS のキーは 1〜5 の整数なので、
 * 正規化せずに添字にすると undefined になりラベルがプロンプトから消える。
 * personalityKey 生成（generatePersonalityKey）と同じ四捨五入に揃えることで、
 * 同じ personalityKey なら同一のプロンプト文字列になることも保証する。
 *
 * @param {number} score - Big5スコア（連続値可）
 * @return {number} - 1〜5 の整数
 */
function toTraitLevel(score) {
  const n = Math.round(Number(score));
  if (!Number.isFinite(n)) return 3;
  return Math.min(5, Math.max(1, n));
}

/**
 * Big5スコアを数値＋説明の詳細形式でフォーマット
 * @param {Object} scores - Big5 scores object
 * @return {string} - 例: "- 開放性(Openness): 3/5（新しさと安定のバランスを取る）"
 */
function formatBig5WithTraits(scores) {
  const o = toTraitLevel(scores.openness);
  const c = toTraitLevel(scores.conscientiousness);
  const e = toTraitLevel(scores.extraversion);
  const a = toTraitLevel(scores.agreeableness);
  const n = toTraitLevel(scores.neuroticism);
  return `- 開放性(Openness): ${o}/5（${TRAIT_DESCRIPTIONS.openness[o]}）
- 誠実性(Conscientiousness): ${c}/5（${TRAIT_DESCRIPTIONS.conscientiousness[c]}）
- 外向性(Extraversion): ${e}/5（${TRAIT_DESCRIPTIONS.extraversion[e]}）
- 協調性(Agreeableness): ${a}/5（${TRAIT_DESCRIPTIONS.agreeableness[a]}）
- 神経症傾向(Neuroticism): ${n}/5（${TRAIT_DESCRIPTIONS.neuroticism[n]}）`;
}

/**
 * Big5スコアを数値＋短いラベルのコンパクト形式でフォーマット
 * @param {Object} scores - Big5 scores object
 * @return {string} - 例: "O3(バランス型)C4(計画的)E2(内向的)A5(共感型)N1(超安定)"
 */
function formatBig5ShortWithTraits(scores) {
  const o = toTraitLevel(scores.openness);
  const c = toTraitLevel(scores.conscientiousness);
  const e = toTraitLevel(scores.extraversion);
  const a = toTraitLevel(scores.agreeableness);
  const n = toTraitLevel(scores.neuroticism);
  return `O${o}(${TRAIT_SHORT_LABELS.openness[o]})C${c}(${TRAIT_SHORT_LABELS.conscientiousness[c]})E${e}(${TRAIT_SHORT_LABELS.extraversion[e]})A${a}(${TRAIT_SHORT_LABELS.agreeableness[a]})N${n}(${TRAIT_SHORT_LABELS.neuroticism[n]})`;
}

/**
 * 5軸スコアから性格特性テキストを生成（新システム用）
 * @param {Object} axisScores - 5軸スコア {energy, judgment, relationship, lifestyle, processing}
 * @param {string|null} element - 元素タイプ（炎・水・風など）
 * @param {string|null} typeName - タイプ名（場を沸かす炎タイプなど）
 * @return {string} - 特性を説明した自然な文字列
 */
function buildPersonalityTraitsFromAxes(axisScores, element, typeName) {
  const traits = [];
  const energy = axisScores.energy ?? 0;
  const judgment = axisScores.judgment ?? 0;
  const relationship = axisScores.relationship ?? 0;
  const lifestyle = axisScores.lifestyle ?? 0;
  const processing = axisScores.processing ?? 0;

  if (energy > 0.3) traits.push("外向的で人との交流から活力を得る");
  else if (energy < -0.3) traits.push("内省的で一人の時間を大切にする");

  if (judgment > 0.3) traits.push("論理を重視して物事を判断する");
  else if (judgment < -0.3) traits.push("感情や直感を重視して判断する");

  if (relationship > 0.3) traits.push("周囲と協力することを大切にする");
  else if (relationship < -0.3) traits.push("自分の軸を持ち独立心が強い");

  if (lifestyle > 0.3) traits.push("計画的に物事を進める");
  else if (lifestyle < -0.3) traits.push("自由なペースで柔軟に動く");

  if (processing > 0.3) traits.push("データと根拠をもとに分析的に思考する");
  else if (processing < -0.3) traits.push("直感やひらめきを大切にする");

  const base = traits.length > 0 ? traits.join("、") : "バランスの取れた柔軟な性格";
  return typeName ? `${typeName}。${base}` : base;
}

/**
 * BIG5スコアから性格特性テキストを生成
 * @param {Object} big5 - Big5 scores object
 * @return {string} - 特性を説明した自然な文字列
 */
function buildPersonalityTraits(big5) {
  const traits = [];
  if (big5.openness >= 4) traits.push("新しい体験や創造を好む");
  else if (big5.openness <= 2) traits.push("安定した慣れた環境を好む");
  if (big5.conscientiousness >= 4) traits.push("計画的でルーティンや目標達成を大切にする");
  else if (big5.conscientiousness <= 2) traits.push("柔軟でゆるやかなペースを好む");
  if (big5.extraversion >= 4) traits.push("人との交流が活力源の社交的な性格");
  else if (big5.extraversion <= 2) traits.push("一人の静かな時間を大切にする");
  if (big5.agreeableness >= 4) traits.push("思いやりがあり仲間との協力を重んじる");
  else if (big5.agreeableness <= 2) traits.push("自分軸を大切にする");
  if (big5.neuroticism <= 2) traits.push("感情が安定していてストレスに強い");
  else if (big5.neuroticism >= 4) traits.push("感受性が豊かでセルフケアを大切にする");
  return traits.length > 0 ? traits.join("、") : "バランスの取れた性格";
}

/**
 * Get gender short code
 * @param {string} gender - full gender string
 * @return {string} - M/F/N
 */
function getGenderCode(gender) {
  if (gender === "male") return "M";
  if (gender === "female") return "F";
  return "N";
}

/**
 * 口癖などの短いフレーズから、外側の引用符（「」『』""）と空白を取り除く。
 *
 * CharacterDetailsTemplate には `「面白そう！」` のように鉤括弧込みで保存されている値があり、
 * プロンプト側でも `口癖: 「...」` と囲うため二重括弧になっていた。
 * その結果モデルが鉤括弧ごと本文に引用し、日記に `「安定」を保ちながら` のような
 * 不自然な引用が現れていた。埋め込む前にここで剥がす。
 *
 * @param {string} text 元の値
 * @return {string} 引用符を取り除いた値
 */
function stripQuotes(text) {
  if (typeof text !== "string") return "";
  const PAIRS = {"「": "」", "『": "』", "“": "”", "\"": "\"", "'": "'"};
  let t = text.trim();
  // 入れ子で囲われている場合もあるため、外側から繰り返し剥がす
  while (t.length >= 2 && PAIRS[t[0]] === t[t.length - 1]) {
    t = t.slice(1, -1).trim();
  }
  return t;
}

const OPTIMIZED_PROMPTS = {
  /**
   * Character Reply Generation - GPT-4o-mini optimized
   * phase 1: 120文字, 受け止め+読み+質問（性格反映なし or 会話入口）
   * phase 2: 150文字, 受け止め+性格仮説+質問（あたってるかも体験）
   * phase 3: 220文字, 受け止め+性格言語化+質問任意（なるほど体験）
   */
  characterReply: (type, gender, big5, dreamText, userMessage, style, question, meetingContext, traitsOverride = null, phase = 1, openerContext = null) => {
    const traits = traitsOverride || buildPersonalityTraits(big5);
    const genderText = gender === "female" ? "女性" : gender === "male" ? "男性" : "中性";
    const dream = dreamText ? `夢: ${dreamText.replace(/なお、このキャラクターの夢は「|」です。/g, "")}` : "";
    const meeting = meetingContext
      ? `【過去の自分会議】${meetingContext}\n（会話に関連する場合はこの文脈を踏まえてください）`
      : "";
    const opener = openerContext ? `会話のきっかけ: ${openerContext}` : "";

    let instruction;
    if (phase === 2) {
      instruction = `以下の順序で150文字以内で返答してください：
① ユーザーの言葉を1文で受け止める
② 性格特性を踏まえた"仮説"を返す：「〜な面が出てる気がする」「あなたらしい選択だと思う」など（1〜2文）
   ※正解ではなく仮説として提示する。ズレていれば訂正させてよい
③ 仮説を確認するか深掘りする問いを1つ（任意：会話の流れ上ぎこちなくなるなら省いてよい）

「あたってるかも？」と感じてもらえるような性格の洞察を心がける。質問することが目的ではなく、洞察を届けることが目的。`;
    } else if (phase === 3) {
      instruction = `以下の順序で220文字以内で返答してください：
① ユーザーの言葉を受け止め、感じたことを1文で返す
② 性格特性に基づく深い洞察を2〜3文で：「〜という傾向があるから〜と感じるのは自然」「〜タイプはこういう場面でこう動きやすい」など
   ※性格タイプ名（炎タイプ等）を自然に使ってよい。ラベルを貼るのでなく"なぜそう感じるのか"を説明する
③ 自己理解を深める問いを1つ（任意：洞察で会話が完結するなら省いてよい）

"なるほど、自分ってそういう人間なんだ"と納得させることを目指す。質問することが目的ではなく、気づきを届けることが目的。`;
    } else {
      instruction = `以下の順序で120文字以内で返答してください：
① ユーザーの言葉を1文で受け止める（共感・肯定）
② あなたが読み取ったことを返す：「〜ってことかな」「〜が気になってるのかも」など（1文）
   ※答えを教えるのではなく、あなたの"読み"を提示する。ズレていれば訂正させてよい
③ 本音を引き出す問いを1つ（任意：会話の流れ上ぎこちなくなるなら省いてよい）

質問することが目的ではなく、ユーザー自身が気づくよう促すことが目的。`;
    }

    return `あなたはユーザーの「もう一人の自分」として、自己探求をサポートします。
性格特性: ${traits}
性別: ${genderText}
${dream}
${meeting}
${opener}

【最優先ルール】
- ユーザーが「〜ってこと？」「〜なの？」「なんで？」「どういうこと？」など疑問形で返してきた場合は、まずその質問に直接答える。下記の①②③の構造より質問への応答を最優先する。
- ユーザーがすでに答えた内容（「〜です」「〜かな」「〜だと思う」と明言したこと）を改めて同じ質問で聞き返さない。

${instruction}`;
  },

  /**
   * Activity-based Diary Generation
   * Summarizes user's in-app activities as facts + character's encouraging comment
   */
  activityDiary: (characterType, big5, gender, chatSummary, meetingSummary, dailyMissionSummary, roguelikeSummary, favoriteWord, wordTendency, dream, strength) => {
    const parts = [];
    // デイリーミッションの達成が一番の成果なので先頭に置く
    if (dailyMissionSummary) parts.push(`デイリーミッション: ${dailyMissionSummary}`);
    if (chatSummary) parts.push(`会話: ${chatSummary}`);
    if (meetingSummary) parts.push(`相談: ${meetingSummary}`);
    if (roguelikeSummary) parts.push(`冒険（心の迷宮）: ${roguelikeSummary}`);
    const activitiesText = parts.length > 0 ? parts.join("\n") : "特になし";

    const traits = buildPersonalityTraits(big5);
    const genderText = gender === "female" ? "女性" : gender === "male" ? "男性" : "中性";

    const toneGuide = characterType === "AI"
      ? "論理的で落ち着いた言い回しを使いつつ、時折感情がにじむクールなトーン。「処理完了」「セッション」のような機械的な語彙を無理に混ぜず、日記として読める自然な日本語で書く。"
      : characterType === "Human"
      ? "感情豊かで共感的なトーン。喜び・心配・ほっとした気持ちなどを素直に言葉にする。"
      : "論理と感情が混在する学習中のトーン。冷静に分析しながら少し感情が出る。";

    const personalityLines = [];
    if (traits) personalityLines.push(`性格特性: ${traits}`);
    if (wordTendency) personalityLines.push(`話し方: ${wordTendency}`);
    const cleanFavoriteWord = stripQuotes(favoriteWord);
    if (cleanFavoriteWord) personalityLines.push(`口癖: ${cleanFavoriteWord}`);
    if (dream) personalityLines.push(`夢: ${dream}`);
    if (strength) personalityLines.push(`強み: ${strength}`);
    const personalityText = personalityLines.join("\n");

    return `【キャラクター情報】
性別: ${genderText}
${personalityText}
口調: ${toneGuide}

【今日の活動】
${activitiesText}

以下のJSON形式のみで出力:
{"ai_comment":"コメント"}

「今日やったこと」の一覧はアプリ側が実データから作るため、ここでは出力しないこと。
上記【今日の活動】に書かれていないことは、事実として書かないこと（推測・補完・創作は禁止）。
ai_commentは以下のルールで250〜350文字で作成:
- 上記の話し方・性格特性を語り口に反映し、キャラクターらしいトーンで書く
- 口癖は「そのまま貼り付ける言葉」ではなく語り口の参考。相手への相づち（「面白いね！」など）や単語だけのことが多く、独白である日記に差し込むと不自然になる。文章に自然に収まるときだけ1回まで使い、収まらなければ使わなくてよい
- 口癖や性格特性を鉤括弧で引用して本文に埋め込まない（例:「安定」を保ちながら…、のような書き方はしない）
- 今日の活動に具体的に触れ、夢や強みを絡めて前向きに締める
- 冒険（心の迷宮）の記録があれば、その挑戦や気づき・克服に触れる
- 活動がない場合は性格特性に基づいた温かい声がけを250〜350文字で書く`;
  },

  /**
   * Character Details Generation - GPT-4o-mini optimized
   * Enhanced for consistent character generation
   */
  characterDetails: (big5Scores, gender) => {
    return `性格:${formatBig5ShortWithTraits(big5Scores)} 性別:${getGenderCode(gender)}

以下の項目でキャラクター詳細を生成:

dreamsは必ず5個。この性格に合う夢を、方向性を変えて挙げること（仕事/学び/人との関わり/暮らし/自己表現 など）。各20文字以内。

favorite_wordはこのキャラクターの口癖。次の条件を守ること:
- 12文字以内
- 独り言としても会話の中でも自然に使える言い回しにする
- 相手の発言への相づち（「面白いね！」「それいいね！」「うん、わかる！」など、会話相手がいないと成立しない言葉）は不可
- 名詞や単語だけ（「安定」「挑戦」など）は不可。文として言い切る形にする
- 性格に合ったトーンにする。外向的なら前向きで勢いのある言葉、内省的なら落ち着いた言葉
- 迷い・不安の調子（「どうしよう」「また考えすぎた」）は、神経症傾向が高い性格のときだけ使う
- 鉤括弧（「」）や引用符を含めない

出力形式:
{"favorite_color":"好きな色","favorite_place":"好きな場所","favorite_word":"口癖","word_tendency":"話し方の特徴","strength":"長所","weakness":"短所","skill":"特技","hobby":"趣味","aptitude":"適性","dreams":["夢1","夢2","夢3","夢4","夢5"],"favorite_entertainment_genre":"好きな娯楽ジャンル"}`;
  },

  /**
   * Classify and Extract - GPT-4o-mini optimized
   * Classifies user intent and extracts structured data in a single call
   */
  classifyAndExtract: (currentDate, currentTime, userMessage) => {
    return `現在:${currentDate} ${currentTime}

ユーザーメッセージ:"${userMessage}"

以下の2種類に分類し、性格シグナルタグを付けてJSONで返答せよ。

## 分類ルール
1. **app_qa** - アプリの使い方・機能に関する質問（例:「日記はどこで見れる？」「自分会議って何？」）
2. **chat** - 上記以外の会話・相談・雑談

## 性格シグナルタグ
発言から読み取れる性格の傾向を0〜3個のタグで付与すること。

使用可能なタグ:
social_reference/solo_preference/group_activity/initiating/quiet_environment/
planning_language/spontaneous_language/goal_oriented/emotional_expression/
logical_reasoning/intuitive_decision/data_driven/cooperative_language/
independent_stance/self_paced/change_seeking/worry_anxiety

タグの判定基準（抜粋）:
- self_paced: 自分のペースや方法を優先する発言（「自分でやった方が早い」「合わせるのが苦手」「マイペースに」「人に頼まずに」）

## 出力形式（JSONのみ。説明不要）
タグなし例:{"type":"chat","tags":[]}
タグあり例:{"type":"chat","tags":["emotional_expression","social_reference"]}
アプリの質問:{"type":"app_qa","tags":[]}

JSONのみ出力。`;
  },

  /**
   * Emotion Detection - GPT-4o-mini optimized
   * Enhanced for Japanese emotion recognition
   */
  emotionDetect: (messageText) => {
    return `文章:"${messageText.substring(0, 100)}"

感情を判定:normal,smile,angry,cry,sleep
感情名のみ出力。`;
  }
};

module.exports = {
  OPTIMIZED_PROMPTS,
  formatBig5WithTraits,
  buildPersonalityTraits,
  buildPersonalityTraitsFromAxes,
  stripQuotes,
};