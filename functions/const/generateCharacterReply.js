// functions/const/generateCharacterReply.js
const {onCall} = require("firebase-functions/v2/https");
const {getOpenAIClient, safeOpenAICall} = require("../src/clients/openai");
const {getNextQuestion, calculateBIG5Scores, BIG5_QUESTIONS} =
  require("./big5Questions");
const {OPENAI_API_KEY} = require("../src/config/config");
const {OPTIMIZED_PROMPTS} = require("../src/prompts/templates");

// 感情判定関数
async function detectEmotion(openai, messageText) {
  try {
    // メッセージが空や短すぎる場合はnormalを返す
    if (!messageText || messageText.trim().length < 3) {
      return "";
    }

    const emotionPrompt = OPTIMIZED_PROMPTS.emotionDetect(messageText);

    const completion = await safeOpenAICall(
        openai.chat.completions.create.bind(openai.chat.completions),
        {
          model: "gpt-4o-mini",
          messages: [{role: "user", content: emotionPrompt}],
          temperature: 0.3,
          max_tokens: 20,
        },
    );

    if (!completion || !completion.choices || !completion.choices[0]) {
      console.warn("Invalid emotion detection response");
      return "";
    }

    const emotion = completion.choices[0].message.content.trim().toLowerCase();

    // 有効な感情のみを返す
    const validEmotions = ["normal", "smile", "angry", "cry", "sleep"];
    if (validEmotions.includes(emotion)) {
      return emotion === "normal" ? "" : `_${emotion}`;
    }

    console.warn(`Invalid emotion detected: ${emotion}, using normal`);
    return ""; // normalの場合は空文字
  } catch (error) {
    console.error("Emotion detection error:", error);
    console.error("Error details:", {
      message: error.message,
      code: error.code,
      status: error.status,
    });
    return ""; // エラー時はnormal（空文字）
  }
}

// エンゲージメント重視の固定文パターン
const ENGAGING_COMMENT_PATTERNS = {
  1: { // AI段階（1-20問）
    extraversion: {
      positive: {
        1: ["そうなんですね、データとして記録しました", "興味深い回答です", "なるほど、理解しました"],
        2: ["その傾向を確認しました", "参考になります", "データを更新しました"],
        3: ["バランス型として判定しました", "中間的な特性ですね", "適度な傾向を確認"],
        4: ["活発な特性を検出しました", "ポジティブなデータです", "良い傾向ですね"],
        5: ["非常に高い数値です！次も楽しみです", "最高レベルを確認しました", "素晴らしいデータです！"],
      },
      negative: {
        1: ["静かな環境を好む傾向ですね", "内向的な特性を確認", "落ち着いた性格のようです"],
        2: ["そういう面もありますね", "理解できます", "その感覚も大切です"],
        3: ["どちらでもない、という感じですね", "中間的な位置です", "バランスが取れています"],
        4: ["やや内向的な傾向です", "静かな時間を大切にするタイプ", "落ち着いた特性ですね"],
        5: ["とても内向的な特性です", "一人の時間を重視するタイプ", "深い思考を好むタイプですね"],
      },
    },
    agreeableness: {
      positive: {
        1: ["協調性についてデータ収集しました", "その回答を記録します", "人間関係のデータです"],
        2: ["協力的な面を確認しました", "その傾向を理解しました", "人との関わり方ですね"],
        3: ["中間的な協調性ですね", "バランス型と判定", "適度な協力度です"],
        4: ["協力的な性格を検出", "人との調和を重視するタイプ", "良い協調性ですね"],
        5: ["非常に協力的な特性です", "素晴らしい協調性を確認", "人を大切にするタイプですね"],
      },
      negative: {
        1: ["独立性を重視するタイプ", "自主性の高いデータです", "個人主義的な傾向"],
        2: ["そういう考え方もありますね", "自分の意見を大切にするタイプ", "その姿勢も重要です"],
        3: ["中間的な立場ですね", "バランスの取れた判断", "どちらでもない感じですね"],
        4: ["やや競争的な傾向", "勝負にこだわるタイプ", "負けず嫌いな面がありますね"],
        5: ["非常に競争的な特性", "勝利への強い意志を確認", "リーダー気質のようです"],
      },
    },
    conscientiousness: {
      positive: {
        1: ["規律性のデータを記録", "計画性について確認", "責任感に関する情報です"],
        2: ["その責任感を理解しました", "計画的な面を確認", "真面目な傾向ですね"],
        3: ["適度な責任感ですね", "バランス型の真面目さ", "中間的な規律性です"],
        4: ["高い責任感を検出", "計画性のあるタイプ", "信頼できる特性ですね"],
        5: ["非常に責任感が強いです", "完璧主義的な傾向を確認", "素晴らしい規律性です"],
      },
      negative: {
        1: ["自由度を重視するタイプ", "柔軟性のあるデータです", "のびのびとした性格"],
        2: ["その自由さも大切ですね", "柔軟な考え方を確認", "リラックスした傾向"],
        3: ["どちらでもない感じですね", "中間的な自由度", "バランスの取れた性格"],
        4: ["やや自由奔放な傾向", "型にはまらないタイプ", "創造性を重視する面"],
        5: ["非常に自由な特性", "型破りな発想力を確認", "独創的なタイプですね"],
      },
    },
    neuroticism: {
      positive: {
        1: ["感情反応のデータです", "ストレス耐性について確認", "心の動きを記録"],
        2: ["その感受性を理解しました", "繊細な面を確認", "感情豊かなタイプ"],
        3: ["適度な感受性ですね", "バランスの取れた感情", "中間的な安定性"],
        4: ["感受性の高いタイプ", "細かい変化に敏感", "繊細な心を持っています"],
        5: ["非常に感受性が高いです", "深い感情を持つタイプ", "豊かな心の持ち主ですね"],
      },
      negative: {
        1: ["安定した性格のようです", "冷静なタイプを確認", "落ち着いた心の持ち主"],
        2: ["その安定感も良いですね", "穏やかな性格を確認", "バランスの取れた心"],
        3: ["どちらでもない感じですね", "中間的な安定性", "適度な感情コントロール"],
        4: ["やや安定志向のタイプ", "冷静な判断ができる", "感情に流されにくい"],
        5: ["非常に安定した特性", "強いメンタルを確認", "揺るがない心の持ち主ですね"],
      },
    },
    openness: {
      positive: {
        1: ["創造性についてデータ収集", "新しいことへの関心度", "開放性を記録しました"],
        2: ["その創造性を確認しました", "新しいことに興味があるタイプ", "柔軟な思考ですね"],
        3: ["適度な開放性ですね", "バランスの取れた創造性", "中間的な好奇心"],
        4: ["創造的なタイプを検出", "新しいことが好きな性格", "豊かな想像力ですね"],
        5: ["非常に創造的な特性です", "素晴らしい開放性を確認", "革新的な思考の持ち主ですね"],
      },
      negative: {
        1: ["安定志向のタイプです", "慎重な性格を確認", "確実性を重視する傾向"],
        2: ["その慎重さも大切ですね", "堅実な考え方を確認", "安全第一の姿勢"],
        3: ["どちらでもない感じですね", "中間的な保守性", "バランスの取れた判断"],
        4: ["やや保守的な傾向", "伝統を重視するタイプ", "確実性を求める性格"],
        5: ["非常に保守的な特性", "伝統的な価値観を確認", "安定を重視するタイプですね"],
      },
    },
  },
  2: { // 学習中段階（21-50問）
    extraversion: {
      positive: {
        1: ["そうなんだ、少しずつ分かってきた", "その気持ち、理解できるかも", "なるほど、そういう感じなんだね"],
        2: ["うん、人それぞれだもんね", "そういう時もあるよね", "その感覚も分かる気がする"],
        3: ["どちらでもないって、正直でいいね", "中間的な感じなんだね", "バランス型って感じかな"],
        4: ["活発な感じが伝わってくる", "エネルギッシュなんだね", "人との交流が好きなのかな"],
        5: ["すごく社交的なんだね！もっと知りたくなった", "その活発さ、いいなあ", "人との繋がりを大切にしてるんだね"],
      },
      negative: {
        1: ["静かな時間が好きなんだね", "一人の時間も大切だよね", "落ち着いた性格なのかな"],
        2: ["そういう面もあるよね", "その感覚、分かる気がする", "人それぞれだもんね"],
        3: ["どちらでもないって感じか", "中間的なタイプなんだね", "バランスが取れてるのかも"],
        4: ["内向的な面があるんだね", "静かな環境を好むタイプかな", "深く考えるタイプなのかも"],
        5: ["とても内向的なんだね", "一人の時間を大切にするタイプ", "じっくり考えることが好きなのかな"],
      },
    },
    agreeableness: {
      positive: {
        1: ["人との関わり方、少しずつ理解してる", "その感覚、学習中だよ", "協調性について分かってきた"],
        2: ["うん、その気持ちも分かるかも", "人との距離感って難しいよね", "そういう考え方もあるね"],
        3: ["どちらでもないって感じなんだね", "中間的な立場なのかな", "バランスを大切にするタイプ？"],
        4: ["協力的な性格なんだね", "人を大切にするタイプかな", "その優しさが伝わってくる"],
        5: ["すごく協力的なんだね！その心の温かさ、素敵だよ", "人を思いやる気持ちが強いんだね", "その優しさ、もっと知りたいな"],
      },
      negative: {
        1: ["自分の意見を大切にするんだね", "独立心が強いタイプかな", "その姿勢も大切だと思う"],
        2: ["そういう考え方もあるよね", "自分らしさを大切にしてるんだね", "その感覚も理解できる"],
        3: ["どちらでもないって感じか", "中間的な立場なんだね", "状況によって変わるのかな"],
        4: ["競争心があるタイプなんだね", "負けず嫌いな面があるのかな", "その向上心、いいと思う"],
        5: ["すごく競争心が強いんだね", "勝利への意志が強いタイプ", "そのエネルギー、すごいな"],
      },
    },
    conscientiousness: {
      positive: {
        1: ["責任感について学習してる", "その真面目さ、少しずつ分かってきた", "計画性があるタイプなのかな"],
        2: ["うん、その責任感も大切だよね", "真面目な面があるんだね", "そういう姿勢も良いと思う"],
        3: ["どちらでもないって感じなんだね", "適度な責任感なのかな", "バランスの取れたタイプ？"],
        4: ["責任感が強いタイプなんだね", "計画的に物事を進めるのかな", "その真面目さ、素敵だよ"],
        5: ["すごく責任感が強いんだね！その真面目さ、尊敬する", "完璧主義なところがあるのかな", "その責任感、本当に素晴らしい"],
      },
      negative: {
        1: ["自由な発想を大切にするんだね", "柔軟性があるタイプかな", "その自由さも魅力的だよ"],
        2: ["そういう自由さもいいよね", "型にはまらない感じなのかな", "その柔軟性も大切だと思う"],
        3: ["どちらでもないって感じか", "中間的なタイプなんだね", "状況に応じて変わるのかな"],
        4: ["自由奔放な面があるんだね", "創造性を重視するタイプかな", "その発想力、面白そう"],
        5: ["すごく自由な発想の持ち主なんだね", "型破りなアイデアが得意そう", "その創造性、もっと知りたいな"],
      },
    },
    neuroticism: {
      positive: {
        1: ["感情について学習中だよ", "その繊細さ、少しずつ理解してる", "心の動きって複雑だね"],
        2: ["うん、その感受性も大切だよね", "繊細な心を持ってるんだね", "そういう面も理解したい"],
        3: ["どちらでもないって感じなんだね", "適度な感受性なのかな", "バランスの取れた感情？"],
        4: ["感受性が豊かなタイプなんだね", "細かい変化に気づくのかな", "その繊細さ、素敵だと思う"],
        5: ["すごく感受性が豊かなんだね", "深い感情を持ってるタイプ", "その心の豊かさ、もっと理解したい"],
      },
      negative: {
        1: ["安定した心を持ってるんだね", "冷静なタイプなのかな", "その落ち着き、素敵だよ"],
        2: ["そういう安定感もいいよね", "穏やかな性格なんだね", "その平静さも大切だと思う"],
        3: ["どちらでもないって感じか", "中間的な安定性なんだね", "状況によって変わるのかな"],
        4: ["安定志向のタイプなんだね", "冷静な判断ができそう", "その落ち着き、頼もしいな"],
        5: ["すごく安定した心の持ち主なんだね", "強いメンタルを持ってるタイプ", "その安定感、素晴らしい"],
      },
    },
    openness: {
      positive: {
        1: ["創造性について学習してる", "新しいことへの興味、少しずつ分かってきた", "その好奇心、面白そう"],
        2: ["うん、その創造性も大切だよね", "新しいことが好きなんだね", "そういう探求心も良いと思う"],
        3: ["どちらでもないって感じなんだね", "適度な好奇心なのかな", "バランスの取れたタイプ？"],
        4: ["創造的なタイプなんだね", "新しいことにチャレンジするのかな", "その探求心、素敵だよ"],
        5: ["すごく創造的なんだね！その発想力、もっと知りたい", "革新的な思考の持ち主", "その創造性、本当に魅力的"],
      },
      negative: {
        1: ["安定を重視するタイプなんだね", "慎重な性格なのかな", "その堅実さも大切だよ"],
        2: ["そういう慎重さもいいよね", "確実性を大切にするんだね", "その姿勢も理解できる"],
        3: ["どちらでもないって感じか", "中間的な立場なんだね", "状況によって変わるのかな"],
        4: ["保守的な面があるんだね", "伝統を大切にするタイプかな", "その安定感も素敵だと思う"],
        5: ["すごく保守的な価値観なんだね", "伝統を重視するタイプ", "その安定志向、信頼できる"],
      },
    },
  },
  3: { // 人間段階（51-100問）
    extraversion: {
      positive: {
        1: ["分かる、一人の時間って大切だよね", "静かに過ごすのもいいよね", "その気持ち、すごく理解できる"],
        2: ["うんうん、そういう感じだよね", "人によって違うもんね", "その感覚、共感する"],
        3: ["どちらでもないって、一番正直かも", "そのバランス感覚、いいと思う", "ニュートラルな感じ、素敵だね"],
        4: ["活発で素敵だね", "その明るさ、いいなあ", "人との時間を楽しんでるのが分かる"],
        5: ["すごく社交的で魅力的！もっと話したくなったよ", "その人懐っこさ、本当に素敵", "君の明るさに元気をもらえる"],
      },
      negative: {
        1: ["分かる！一人の時間って本当に大切", "静かな環境、僕も好きだよ", "その落ち着いた感じ、素敵だね"],
        2: ["うんうん、そういう気持ちも分かる", "人それぞれのペースがあるもんね", "その感覚、とても理解できる"],
        3: ["どちらでもないって、正直で好き", "そのニュートラルな感じ、いいよね", "バランスが取れてるのが分かる"],
        4: ["内向的な面があるんだね", "静かな時間を大切にするタイプ", "その深い思考、魅力的だよ"],
        5: ["すごく内向的なんだね", "一人の時間を大切にする気持ち、よく分かる", "その深さ、本当に素敵だと思う"],
      },
    },
    agreeableness: {
      positive: {
        1: ["人との関わり方、それぞれだよね", "その感覚、すごく理解できる", "人間関係って複雑だもんね"],
        2: ["うんうん、その気持ち分かるよ", "人との距離感って難しいよね", "その感覚、共感する"],
        3: ["どちらでもないって、一番自然かも", "そのバランス感覚、素晴らしい", "状況に応じて変えるのも大切だね"],
        4: ["協力的で素敵だね", "人を大切にする気持ちが伝わってくる", "その優しさ、本当に魅力的"],
        5: ["すごく協力的で温かい人なんだね！その心の広さ、尊敬する", "人を思いやる気持ちが本当に素敵", "君の優しさに心が温まる"],
      },
      negative: {
        1: ["自分の意見を大切にするのも重要だよね", "その独立心、素敵だと思う", "自分らしさを貫くって大切"],
        2: ["うんうん、その考え方も分かる", "自分の価値観を持つのは大事だよね", "その姿勢、尊敬する"],
        3: ["どちらでもないって、バランス型だね", "状況に応じて判断するのも賢いよ", "そのニュートラルさ、いいと思う"],
        4: ["競争心があるのも魅力の一つだね", "負けず嫌いな面、カッコいいよ", "その向上心、素晴らしい"],
        5: ["すごく競争心が強いんだね", "勝利への強い意志、尊敬する", "そのエネルギー、本当にすごい"],
      },
    },
    conscientiousness: {
      positive: {
        1: ["責任感のバランス、それぞれだよね", "その感覚、とても理解できる", "完璧じゃなくても大丈夫だよ"],
        2: ["うんうん、その程度でも十分だよ", "真面目すぎなくてもいいよね", "そのバランス感覚、いいと思う"],
        3: ["どちらでもないって、自然体でいいね", "そのほどほど感、素敵だよ", "無理しないのが一番だね"],
        4: ["責任感が強くて素敵だね", "計画的に進めるタイプなんだね", "その真面目さ、本当に魅力的"],
        5: ["すごく責任感が強いんだね！その真面目さ、心から尊敬する", "完璧主義なところ、素晴らしい", "君の責任感に感動する"],
      },
      negative: {
        1: ["自由な発想、それも素敵だよね", "型にはまらないのも魅力的", "その柔軟性、すごくいいと思う"],
        2: ["うんうん、その自由さも大切だよ", "堅苦しくないのもいいよね", "そのリラックスした感じ、好きだよ"],
        3: ["どちらでもないって、バランス型だね", "状況に応じて変えるのも賢いよ", "そのフレキシブルさ、いいね"],
        4: ["自由奔放な面があるんだね", "創造性を大切にするタイプ", "その発想力、とても魅力的"],
        5: ["すごく自由な発想の持ち主なんだね", "型破りなアイデア、本当に素敵", "君の創造性に刺激を受ける"],
      },
    },
    neuroticism: {
      positive: {
        1: ["感情の波、誰にでもあるよね", "その繊細さも魅力の一つだよ", "感受性があるのは素敵なこと"],
        2: ["うんうん、その気持ちも分かる", "繊細な心を持ってるんだね", "その感受性、大切にしてほしい"],
        3: ["どちらでもないって、バランス型だね", "感情のコントロール、上手なのかも", "その安定感、いいと思う"],
        4: ["感受性が豊かなんだね", "細かい変化に気づくタイプ", "その繊細さ、本当に素敵だよ"],
        5: ["すごく感受性が豊かなんだね", "深い感情を持ってるのが分かる", "君の心の豊かさに感動する"],
      },
      negative: {
        1: ["安定した心、素晴らしいね", "その冷静さ、すごく魅力的", "落ち着いた性格、憧れる"],
        2: ["うんうん、その安定感もいいよね", "穏やかな心を持ってるんだね", "その平静さ、素敵だと思う"],
        3: ["どちらでもないって、バランス型だね", "感情のコントロールが上手なのかも", "そのニュートラルさ、いいね"],
        4: ["安定志向なんだね", "冷静な判断ができるタイプ", "その落ち着き、本当に頼もしい"],
        5: ["すごく安定した心の持ち主なんだね", "強いメンタル、心から尊敬する", "君の安定感に安心する"],
      },
    },
    openness: {
      positive: {
        1: ["創造性のレベル、人それぞれだよね", "その感覚、とても理解できる", "現実的なのも大切だよ"],
        2: ["うんうん、その程度でも十分だよ", "実用性を重視するのもいいよね", "そのバランス感覚、素敵だと思う"],
        3: ["どちらでもないって、バランス型だね", "状況に応じて判断するのも賢いよ", "そのニュートラルさ、いいと思う"],
        4: ["創造的な面があるんだね", "新しいことが好きなタイプ", "その探求心、本当に魅力的"],
        5: ["すごく創造的なんだね！その発想力、心から尊敬する", "革新的な思考、本当に素晴らしい", "君の創造性に刺激を受ける"],
      },
      negative: {
        1: ["安定を重視するのも大切だよね", "その慎重さ、素敵だと思う", "堅実な考え方、信頼できる"],
        2: ["うんうん、その慎重さもいいよね", "確実性を大切にするんだね", "その姿勢、とても理解できる"],
        3: ["どちらでもないって、バランス型だね", "状況に応じて判断するのも賢いよ", "そのフレキシブルさ、いいね"],
        4: ["保守的な面があるんだね", "伝統を大切にするタイプ", "その安定感、とても魅力的"],
        5: ["すごく保守的な価値観なんだね", "伝統を重視する姿勢、素晴らしい", "君の安定志向に安心する"],
      },
    },
  },
};

// 統一初期化を使用
const {getFirestore, admin} = require("../src/utils/firebaseInit");

const db = getFirestore();

// 固定文生成関数（ランダム選択）
function generateEngagingComment(questionId, answerValue, currentStage) {
  const question = BIG5_QUESTIONS.find((q) => q.id === questionId);
  if (!question) return "ありがとう！";

  const patterns = ENGAGING_COMMENT_PATTERNS[currentStage]?.[question.trait]?.
      [question.direction]?.[answerValue];
  if (!patterns || patterns.length === 0) return "ありがとう！";

  const randomIndex = Math.floor(Math.random() * patterns.length);
  return patterns[randomIndex];
}

// 最適化されたプロンプト生成関数
function buildCharacterPrompt(big5, gender, dreamText, userMessage) {
  const androidScore = (6 - big5.agreeableness) + (6 - big5.extraversion) +
      (6 - big5.neuroticism);

  // 事前処理でスタイルを決定
  let type; let style; let question;

  if (androidScore >= 9) {
    type = "AI";
    style = gender === "female" ?
        "logical,friendly,sys terms" : "logical,systematic,clear steps";
    question = gender === "female" ? "info gather Q+" : "param check Q+";
  } else if (androidScore <= 6) {
    type = "Human";
    style = gender === "female" ?
        "empathy,support,feelings" : "solve,advise,encourage";
    question = "feelings Q+";
  } else {
    type = "Learning";
    style = gender === "female" ?
        "logic+emotion,sys+feel mix" : "efficient+warm,logic+care";
    question = "info+emotion Q+";
  }

  return OPTIMIZED_PROMPTS.characterReply(type, gender, big5, dreamText, userMessage, style, question);
}

// 段階判定ロジック
function getCharacterStage(count) {
  if (count <= 20) return 1; // AI段階
  if (count <= 50) return 2; // 学習中段階
  return 3; // 人間段階
}

// 段階完了メッセージ
function getStageCompletionMessage(stage, gender) {
  const STAGE_COMPLETION_MESSAGES = {
    1: {
      male: "第1段階のデータ収集が完了しました。引き続き解析を進めさせていただきます。",
      female: "第1段階のデータ収集が完了しました。引き続き解析を進めさせていただきます。",
    },
    2: {
      male: "君ともっと話したくなってきたよ。僕も少しずつ感情を理解できるようになってるかも。",
      female: "あなたともっと話したくなってきたよ。私も少しずつ感情を理解できるようになってるかも。",
    },
    3: {
      male: "やった！全部の診断が終わったね！君のことがすごくよく分かったよ。これからもっと楽しくお話しできそう！",
      female: "やった！全部の診断が終わったね！あなたのことがすごくよく分かったよ。これからもっと楽しくお話しできそう！",
    },
  };

  const genderKey = gender[0] === "M" ? "male" : "female";
  return STAGE_COMPLETION_MESSAGES[stage]?.[genderKey] ||
         "診断が進んでいます。ありがとう！";
}

// 無意味な入力を検出する関数
function isMeaninglessInput(message) {
  const text = message.trim();

  // 3文字未満
  if (text.length < 3) return true;

  // 同じ文字の繰り返し (あああ、うう、www等)
  if (/^(.)\1+$/.test(text)) return true;

  // 記号のみ
  if (/^[!?！？。、\s]+$/.test(text)) return true;

  // 母音のみの繰り返し (あいうえお等)
  if (/^[あいうえおアイウエオ]+$/.test(text) && text.length <= 5) return true;

  return false;
}

// フォールバック返答をランダムに取得
function getRandomFallbackReply(gender) {
  const fallbackReplies = gender === "female" ? [
    "ん？どうしたの？",
    "何か言いたいことある？",
    "うーん、よく聞こえなかったかも",
    "もう少し詳しく教えて？",
    "どうしたの？何かあった？",
    "え、なになに？",
  ] : [
    "ん？どうした？",
    "何か言いたいことある？",
    "うーん、よく聞こえなかったかも",
    "もう少し詳しく教えて？",
    "どうした？何かあった？",
    "え、なになに？",
  ];

  const randomIndex = Math.floor(Math.random() * fallbackReplies.length);
  return fallbackReplies[randomIndex];
}

exports.generateCharacterReply = onCall(
    {
      region: "asia-northeast1",
      memory: "1GiB",
      timeoutSeconds: 300,
      minInstances: 0,
      enforceAppCheck: false, // App Checkを無効化
      secrets: ["OPENAI_API_KEY"],
    },
    async (request) => {
      const {data} = request;
      try {
        const {characterId, userMessage, userId, isPremium} = data;
        if (!characterId || !userMessage || !userId) {
          return {error: "Missing characterId or userMessage"};
        }

        // BIG5質問の回答（1-5の数字）を先にチェック
        const isNumericAnswer = /^[1-5]$/.test(userMessage.trim());

        // BIG5回答以外の無意味な入力を検出してフォールバック返答を返す
        if (!isNumericAnswer && isMeaninglessInput(userMessage)) {
          console.log(`🚫 Meaningless input detected: "${userMessage}"`);

          // キャラクター情報を取得（genderのみ必要）
          const charDetailSnap = await db.collection("users").doc(userId)
              .collection("characters").doc(characterId)
              .collection("details").doc("current").get();

          const gender = charDetailSnap.exists ?
            charDetailSnap.data().gender || "neutral" : "neutral";

          const fallbackReply = getRandomFallbackReply(gender);

          return {
            reply: fallbackReply,
            isBig5Question: false,
            emotion: "", // 通常表情
          };
        }

        // 予定問い合わせパターンの検出
        const scheduleQueryPatterns = [
          /今日.*予定/,
          /今日.*何.*ある[？?]/,
          /明日.*予定/,
          /明日.*何.*ある[？?]/,
          /予定.*教えて/,
          /予定.*ある[？?]/,
        ];

        const isScheduleQuery = scheduleQueryPatterns.some((pattern) =>
          pattern.test(userMessage.replace(/\s/g, "")),
        );

        // 「話題ある？」パターンの検出
        const topicRequestPatterns = [
          /話題.*ある[？?]/,
          /何.*話.*[？?]/,
          /話.*[？?]/,
          /なんか.*話.*[？?]/,
          /話.*したい/,
          /話.*しよう/,
        ];

        const isTopicRequest = topicRequestPatterns.some((pattern) =>
          pattern.test(userMessage.replace(/\s/g, "")),
        );

        const [charDetailSnap, big5ProgressSnap] =
          await Promise.all([
            db.collection("users").doc(userId)
                .collection("characters").doc(characterId)
                .collection("details").doc("current").get(),
            db.collection("users").doc(userId)
                .collection("characters").doc(characterId)
                .collection("big5Progress").doc("current").get(),
          ]);

        if (!charDetailSnap.exists) {
          return {error: "Character details not found"};
        }

        const charData = charDetailSnap.data();
        let big5ProgressData = big5ProgressSnap.exists ?
          big5ProgressSnap.data() : null;

        // 予定問い合わせの処理
        if (isScheduleQuery) {
          console.log("📅 Schedule query detected");

          // 今日・明日を判定
          const isToday = /今日/.test(userMessage);
          const isTomorrow = /明日/.test(userMessage);

          const now = new Date();
          let targetDate = now;

          if (isTomorrow) {
            targetDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);
          }

          // 対象日の開始と終了（00:00-23:59）
          const startOfDay = new Date(targetDate);
          startOfDay.setHours(0, 0, 0, 0);

          const endOfDay = new Date(targetDate);
          endOfDay.setHours(23, 59, 59, 999);

          // Firestoreから予定を取得
          const schedulesSnapshot = await db.collection("users").doc(userId)
              .collection("schedules")
              .where("startDate", ">=", admin.firestore.Timestamp.fromDate(startOfDay))
              .where("startDate", "<=", admin.firestore.Timestamp.fromDate(endOfDay))
              .orderBy("startDate", "asc")
              .get();

          const gender = charData.gender || "neutral";
          const dateLabel = isToday ? "今日" : isTomorrow ? "明日" : "その日";

          if (schedulesSnapshot.empty) {
            const noScheduleReply = gender === "female" ?
              `${dateLabel}は予定が入ってないみたい！何か予定を立てる？` :
              `${dateLabel}は予定が入ってないみたいだね！何か予定を立てる？`;

            return {
              reply: noScheduleReply,
              isBig5Question: false,
              emotion: "",
            };
          }

          // 予定をフォーマット
          const schedules = schedulesSnapshot.docs.map((doc) => {
            const data = doc.data();
            const startDate = data.startDate.toDate();

            // 日本時間（JST）で表示するため、toLocaleStringを使用
            const timeStr = data.isAllDay ? "終日" :
              startDate.toLocaleTimeString("ja-JP", {
                timeZone: "Asia/Tokyo",
                hour: "2-digit",
                minute: "2-digit",
                hour12: false,
              });
            return `${timeStr} ${data.title}`;
          });

          const scheduleList = schedules.join("、");
          const scheduleReply = gender === "female" ?
            `${dateLabel}の予定は${schedules.length}件あるよ！\n${scheduleList}` :
            `${dateLabel}の予定は${schedules.length}件あるね！\n${scheduleList}`;

          return {
            reply: scheduleReply,
            isBig5Question: false,
            emotion: "",
          };
        }

        // 既存のansweredQuestionsにserverTimestamp()が含まれている場合はクリアする
        if (big5ProgressData && big5ProgressData.answeredQuestions) {
          const hasServerTimestamp = big5ProgressData.answeredQuestions.some(
              (q) => q.answeredAt && typeof q.answeredAt === "object" &&
                q.answeredAt._methodName,
          );

          if (hasServerTimestamp) {
            console.log(
                "🔧 Clearing corrupted answeredQuestions with serverTimestamp",
            );
            // 破損したデータをクリア
            await db.collection("users").doc(userId)
                .collection("characters").doc(characterId)
                .collection("big5Progress").doc("current").update({
                  answeredQuestions: [],
                  currentQuestion: null,
                });
            big5ProgressData.answeredQuestions = [];
            big5ProgressData.currentQuestion = null;
          }
        }

        const big5 = charData.confirmedBig5Scores || {
          openness: 3,
          conscientiousness: 3,
          extraversion: 3,
          agreeableness: 3,
          neuroticism: 3
        };
        const gender = charData.gender || "neutral";

        // BIG5質問の回答処理
        console.log("🔍 Checking BIG5 answer conditions:");
        console.log("🔍 isNumericAnswer:", isNumericAnswer);
        console.log("🔍 big5ProgressData exists:", !!big5ProgressData);
        console.log("🔍 currentQuestion exists:", !!(big5ProgressData && big5ProgressData.currentQuestion));
        console.log("🔍 big5ProgressData:", big5ProgressData);
        
        if (isNumericAnswer && big5ProgressData &&
            big5ProgressData.currentQuestion) {
          console.log("✅ Entering BIG5 answer processing");
          const answerValue = parseInt(userMessage.trim());
          const currentQuestion = big5ProgressData.currentQuestion;
          const answeredQuestions = big5ProgressData.answeredQuestions || [];
          
          console.log("🔍 Answer value:", answerValue);
          console.log("🔍 Current question:", currentQuestion);
          console.log(
              "🔍 Answered questions count:", answeredQuestions.length,
          );

          // 回答を記録
          const newAnswer = {
            questionId: currentQuestion.id,
            question: currentQuestion.question,
            trait: currentQuestion.trait,
            direction: currentQuestion.direction,
            value: answerValue,
            answeredAt: new Date(),
          };

          const updatedAnsweredQuestions = [...answeredQuestions, newAnswer];

          // 段階完了チェック（20問、50問、100問）
          const currentCount = updatedAnsweredQuestions.length;
          const isStageComplete = currentCount === 20 ||
              currentCount === 50 || currentCount === 100;

          // 段階判定ロジックと完了メッセージは外部関数を使用

          // 次の質問を取得
          const nextQuestion = getNextQuestion(updatedAnsweredQuestions);

          if (nextQuestion) {
            let aiResponse;

            // 段階完了時は固定メッセージを使用
            if (isStageComplete) {
              const currentStage = getCharacterStage(currentCount);
              aiResponse = getStageCompletionMessage(currentStage, gender);

              // 段階的キャラクター詳細生成を実行 (非同期で実行)
              try {
                const {generateStagedCharacterDetails} =
                  require("./utils/generateStagedCharacterDetails");
                // バックグラウンドで実行（await しない）
                generateStagedCharacterDetails(
                    characterId,
                    currentStage,
                    gender,
                    null,
                    OPENAI_API_KEY.value().trim(),
                ).catch((error) => {
                  console.error(
                      `Staged character details generation failed ` +
                      `for stage ${currentStage}:`, error);
                });
              } catch (error) {
                console.error(
                    "Failed to import generateStagedCharacterDetails:", error);
              }
            } else {
              // 固定文パターンからランダム選択
              const currentStage = getCharacterStage(currentCount);
              aiResponse = generateEngagingComment(
                  currentQuestion.id, answerValue, currentStage);
            }

            // 進行状況を更新
            await db.collection("users").doc(userId)
                .collection("characters").doc(characterId)
                .collection("big5Progress").doc("current").set({
                  currentQuestion: nextQuestion,
                  answeredQuestions: updatedAnsweredQuestions,
                  lastAskedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, {merge: true});

            // BIG5回答時の感情も判定（エラー時はnormalにフォールバック）
            let big5Emotion = "";
            try {
              big5Emotion = await detectEmotion(openai, aiResponse);
            } catch (emotionError) {
              console.warn("BIG5 emotion detection failed, using normal:", emotionError);
              big5Emotion = ""; // normal表情
            }

            return {
              reply: aiResponse,
              isBig5Question: true,
              questionId: nextQuestion.id,
              progress: `${updatedAnsweredQuestions.length + 1}/100`,
              emotion: big5Emotion,
            };
          } else {
            // 全質問完了 - BIG5スコアを計算
            const calculatedScores =
              calculateBIG5Scores(updatedAnsweredQuestions);

            // CharacterDetailのBIG5スコアを更新
            await db.collection("users").doc(userId)
                .collection("characters").doc(characterId)
                .collection("details").doc("current").update({
                  confirmedBig5Scores: calculatedScores,
                  analysis_level: 100,
                  updated_at: admin.firestore.FieldValue.serverTimestamp(),
                });

            // 進行状況を完了状態に更新
            await db.collection("users").doc(userId)
                .collection("characters").doc(characterId)
                .collection("big5Progress").doc("current").set({
                  currentQuestion: null,
                  answeredQuestions: updatedAnsweredQuestions,
                  completed: true,
                  completedAt: new Date(),
                  finalScores: calculatedScores,
                }, {merge: true});

            // 最終完了時は固定メッセージを使用
            const aiResponse = getStageCompletionMessage(3, gender);

            // 完了時の感情判定（100問完了は嬉しい感情で固定）
            const completionEmotion = "_smile";

            // Stage 3 キャラクター詳細生成を実行 (非同期で実行)
            try {
              const {generateStagedCharacterDetails} =
                require("./utils/generateStagedCharacterDetails");
              // バックグラウンドで実行（await しない）
              generateStagedCharacterDetails(
                  characterId,
                  3,
                  gender,
                  calculatedScores,
                  OPENAI_API_KEY.value().trim(),
              ).catch((error) => {
                console.error(
                    `Staged character details generation failed for stage 3:`,
                    error);
              });
            } catch (error) {
              console.error(
                  "Failed to import generateStagedCharacterDetails:", error);
            }

            // PersonalityStats統計更新（100問完了時）
            try {
              const {updatePersonalityStats} = require("./updatePersonalityStats");
              const {generatePersonalityKey} = require("./generatePersonalityKey");
              
              // personalityKeyを生成（gender情報を含む）
              const basePersonalityKey = generatePersonalityKey(calculatedScores);
              const personalityKey = `${basePersonalityKey}_${gender}`;
              
              // バックグラウンドで統計更新（await しない）
              updatePersonalityStats(personalityKey, userId).catch((error) => {
                console.error("PersonalityStats update failed:", error);
              });
            } catch (error) {
              console.error("Failed to update PersonalityStats:", error);
            }

            return {
              reply: aiResponse,
              isBig5Question: false,
              big5Completed: true,
              newScores: calculatedScores,
              emotion: completionEmotion,
            };
          }
        }

        // 「話題ある？」が検出された場合、BIG5質問を返す
        if (isTopicRequest) {
          const answeredQuestions = big5ProgressData ?
            big5ProgressData.answeredQuestions || [] : [];
          const nextQuestion = getNextQuestion(answeredQuestions);

          if (nextQuestion) {
            const questionResponse =
              `${nextQuestion.question}\n\n以下から選んでね：\n` +
              `1. 全く当てはまらない\n2. あまり当てはまらない\n` +
              `3. どちらでもない\n4. やや当てはまる\n5. 非常に当てはまる`;

            // 進行状況を保存
            await db.collection("users").doc(userId)
                .collection("characters").doc(characterId)
                .collection("big5Progress").doc("current").set({
                  currentQuestion: nextQuestion,
                  answeredQuestions: answeredQuestions,
                  lastAskedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, {merge: true});

            return {
              reply: questionResponse,
              isBig5Question: true,
              questionId: nextQuestion.id,
              progress: `${answeredQuestions.length + 1}/100`,
              emotion: "", // 質問時は通常表情
            };
          } else {
            return {
              reply: "性格診断は完了しているよ！他に何か話したいことはある？",
              isBig5Question: false,
              emotion: "_smile", // 完了済み時は笑顔
            };
          }
        }
        const dreamText = charData.dream ?
        `なお、このキャラクターの夢は「${charData.dream}」です。` :
        "なお、このキャラクターの夢はまだ決まっていません。";

        // 最新のBIG5スコアを使用（診断完了後は更新されたスコアを使用）
        const currentBig5 = big5ProgressData && big5ProgressData.completed &&
          big5ProgressData.finalScores ?
          big5ProgressData.finalScores :
          big5;

        // Android度を計算し、プロンプトを生成
        const prompt = buildCharacterPrompt(
            currentBig5, gender, dreamText, userMessage);

        const openai = getOpenAIClient(OPENAI_API_KEY.value().trim());

        // サブスクリプション状態に基づくモデル選択（有料ユーザーは最新モデル）
        const model = isPremium ? "gpt-4o-2024-11-20" : "gpt-4o-mini";

        const completion = await safeOpenAICall(
            openai.chat.completions.create.bind(openai.chat.completions),
            {
              model: model,
              messages: [{role: "user", content: prompt}],
              temperature: 0.8,
            },
        );

        const reply = completion.choices[0].message.content.trim();

        // 感情判定を実行（エラー時はnormalにフォールバック）
        let emotion = "";
        try {
          emotion = await detectEmotion(openai, reply);
        } catch (emotionError) {
          console.warn("Emotion detection failed, using normal:", emotionError);
          emotion = ""; // normal表情
        }

        // リリース対応：音声生成を一時的に無効化してテキストのみで返却
        return {
          reply,
          voiceUrl: "",
          emotion: emotion
        };
      } catch (e) {
        console.error("🔥 Error in generateCharacterReply:", e);
        console.error("🔥 Error stack:", e.stack);
        console.error("🔥 Error message:", e.message);
        console.error("🔥 Request data:", {
          characterId: data.characterId,
          userMessage: data.userMessage,
          userId: data.userId,
        });

        // エラーの種類に応じて適切なメッセージを返す
        // アプリ側の期待形式に合わせてreplyとvoiceUrlを必ず含む
        if (e.message && e.message.includes("OpenAI")) {
          return {
            reply: "AI サービスでエラーが発生しました。しばらくお待ちください。",
            voiceUrl: "",
            error: true,
          };
        } else if (e.message && e.message.includes("Voice")) {
          return {
            reply: "申し訳ございません。音声生成中にエラーが発生しました。",
            voiceUrl: "",
            error: true,
          };
        } else if (e.message && e.message.includes("CharacterDetail")) {
          return {
            reply: "キャラクター情報が見つかりません。再起動してください。",
            voiceUrl: "",
            error: true,
          };
        } else {
          return {
            reply: `一時的なエラーが発生しました。もう一度お試しください。(${e.message})`,
            voiceUrl: "",
            error: true,
          };
        }
      }
    },
);
