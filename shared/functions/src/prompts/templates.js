// Optimized prompt templates for cost reduction
// Token count reduced by 60-80% while maintaining functionality

/**
 * Format Big5 scores in short format
 * @param {Object} scores - Big5 scores object
 * @return {string} - Compressed format O1C2E3A4N5
 */
function formatBig5Short(scores) {
  return `O${scores.openness}C${scores.conscientiousness}E${scores.extraversion}A${scores.agreeableness}N${scores.neuroticism}`;
}

/**
 * Format Big5 scores with trait names for better AI understanding
 * @param {Object} scores - Big5 scores object
 * @return {string} - Formatted Big5 with trait names
 */
function formatBig5Detailed(scores) {
  return `BIG5性格モデル:
- 開放性(Openness): ${scores.openness}/5
- 誠実性(Conscientiousness): ${scores.conscientiousness}/5
- 外向性(Extraversion): ${scores.extraversion}/5
- 協調性(Agreeableness): ${scores.agreeableness}/5
- 神経症傾向(Neuroticism): ${scores.neuroticism}/5`;
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

const OPTIMIZED_PROMPTS = {
  /**
   * Big5 Analysis Generation - GPT-4o-mini optimized
   * Enhanced for better JSON output and Japanese processing
   */
  big5Analysis: (big5Scores, gender) => {
    return `Big5:${formatBig5Short(big5Scores)} 性別:${getGenderCode(gender)}

以下の性格分析を300-500文字で生成。数値は出力に含めない。
1.適職分析 2.恋愛傾向 3.ストレス対処 4.学習スタイル 5.意思決定

出力形式:
{"career_analysis":"適職について","romance_analysis":"恋愛について","stress_analysis":"ストレスについて","learning_analysis":"学習について","decision_analysis":"意思決定について"}`;
  },

  /**
   * Character Reply Generation - GPT-4o-mini optimized
   * Enhanced for better Japanese conversation flow with detailed Big5
   */
  characterReply: (type, gender, big5, dreamText, userMessage, style, question, meetingContext) => {
    const traits = buildPersonalityTraits(big5);
    const genderText = gender === "female" ? "女性" : gender === "male" ? "男性" : "中性";
    const dream = dreamText ? `夢: ${dreamText.replace(/なお、このキャラクターの夢は「|」です。/g, "")}` : "";
    const meeting = meetingContext
      ? `【会議コンテキスト】${meetingContext}\n（ユーザーが会議について話している場合はこの内容を踏まえて返答してください）`
      : "";

    return `性格特性: ${traits}
性別: ${genderText}
${dream}
${meeting}
上記の性格特性を自然に反映し、キャラクターとして100文字以内で返答してください。`;
  },

  /**
   * Diary Generation - GPT-4o-mini optimized
   * Enhanced with todo and meeting data
   */
  diary: (characterType, big5, gender, scheduleSummary, chatSummary, todoSummary, meetingSummary, diaryStyle) => {
    return `キャラクター:${characterType} 性格:${formatBig5Short(big5)} 性別:${getGenderCode(gender)}
予定:${scheduleSummary || "なし"}
会話:${chatSummary || "なし"}
達成:${todoSummary || "なし"}
相談:${meetingSummary || "なし"}

${diaryStyle}で日記を200-400文字で作成。日記本文のみ出力。`;
  },

  /**
   * Activity-based Diary Generation
   * Summarizes user's in-app activities as facts + character's encouraging comment
   */
  activityDiary: (characterType, big5, gender, scheduleSummary, chatSummary, completedTodoSummary, createdTodoSummary, memoSummary, meetingSummary, big5ProgressSummary) => {
    const parts = [];
    if (scheduleSummary) parts.push(`予定: ${scheduleSummary}`);
    if (chatSummary) parts.push(`会話: ${chatSummary}`);
    if (completedTodoSummary) parts.push(`完了タスク: ${completedTodoSummary}`);
    if (createdTodoSummary) parts.push(`作成タスク: ${createdTodoSummary}`);
    if (memoSummary) parts.push(`メモ: ${memoSummary}`);
    if (meetingSummary) parts.push(`相談: ${meetingSummary}`);
    if (big5ProgressSummary) parts.push(`性格診断: ${big5ProgressSummary}`);
    const activitiesText = parts.length > 0 ? parts.join("\n") : "特になし";

    return `今日ユーザーがアプリ内で行ったこと:
${activitiesText}

キャラクター:${characterType} 性格:${formatBig5Short(big5)} 性別:${getGenderCode(gender)}

以下のJSON形式のみで出力:
{"facts":["事実1","事実2"],"ai_comment":"コメント"}

factsは今日の活動を事実ベースで2〜5件（例:「タスク『報告書』を完了した」「メモ『アイデア』を記録した」）。
ai_commentは上記の事実に具体的に触れ、キャラクターらしいトーンで前向きに50〜100文字。
活動がない場合はfactsを空配列にし、ai_commentで一言声がけ。`;
  },

  /**
   * Schedule Extraction - GPT-4o-mini optimized
   * Enhanced for better Japanese date/time understanding
   */
  scheduleExtract: (currentDate, currentTime, userMessage) => {
    const now = new Date();
    const tomorrow = new Date(now.getTime() + 24*60*60*1000).toLocaleDateString('ja-JP', {timeZone: 'Asia/Tokyo'});
    const today = now.toLocaleDateString('ja-JP', {timeZone: 'Asia/Tokyo'});

    return `現在:${currentDate} ${currentTime}
入力:"${userMessage}"

日時+行動の組合せのみ予定あり。挨拶/感嘆/質問のみは予定なし。

今日=${today} 明日=${tomorrow}
時間なし→00:00-23:59,isAllDay:true
時間あり→1h継続,isAllDay:false

抽出ルール:
・title: 行動内容(例:「お昼寝」「会議」「買い物」)。必ず入力から抽出すること
・startDate/endDate: 必ずタイムゾーン+09:00を付けること(例:2025-10-13T05:00:00+09:00)
・location: 場所が明記されていれば抽出

出力:
予定なし:{"hasSchedule":false}
予定あり:{"hasSchedule":true,"title":"行動内容","isAllDay":bool,"startDate":"ISO+09:00","endDate":"ISO+09:00","location":"","tag":"","memo":"","repeatOption":"none","remindValue":0,"remindUnit":"none"}

JSONのみ出力。`;
  },

  /**
   * Character Details Generation - GPT-4o-mini optimized
   * Enhanced for consistent character generation
   */
  characterDetails: (big5Scores, gender) => {
    return `性格:${formatBig5Short(big5Scores)} 性別:${getGenderCode(gender)}

以下の項目でキャラクター詳細を生成:

出力形式:
{"favorite_color":"好きな色","favorite_place":"好きな場所","favorite_word":"口癖","word_tendency":"話し方の特徴","strength":"長所","weakness":"短所","skill":"特技","hobby":"趣味","aptitude":"適性","dream":"夢","favorite_entertainment_genre":"好きな娯楽ジャンル"}`;
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
  formatBig5Short,
  formatBig5Detailed,
  getGenderCode,
  buildPersonalityTraits,
};