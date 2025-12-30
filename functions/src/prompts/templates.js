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
  characterReply: (type, gender, big5, dreamText, userMessage, style, question) => {
    const big5Detailed = formatBig5Detailed(big5);
    const genderText = gender === "female" ? "女性" : gender === "male" ? "男性" : "中性";
    const dream = dreamText ? `夢: ${dreamText.replace(/なお、このキャラクターの夢は「|」です。/g, "")}` : "";

    return `${big5Detailed}

性別: ${genderText}
${dream}

ユーザー発言:"${userMessage}"

上記のBIG5性格特性を忠実に反映した自然な会話を100文字以内で返答してください。`;
  },

  /**
   * Diary Generation - GPT-4o-mini optimized
   * Enhanced for stable JSON output
   */
  diary: (characterType, big5, gender, scheduleSummary, chatSummary, diaryStyle, tagStyle) => {
    return `キャラクター:${characterType} 性格:${formatBig5Short(big5)} 性別:${getGenderCode(gender)}
予定:${scheduleSummary || "なし"}
会話:${chatSummary || "なし"}

${diaryStyle}で日記を200-400文字で作成。${tagStyle}

出力形式:
{"content":"日記内容","summary_tags":["タグ1","タグ2","タグ3"]}`;
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
};