// BIG5質問データベース（各特性20問ずつ、計100問）
const BIG5_QUESTIONS = [
  // 外向性 (Extraversion) - 20問
  {
    id: "E1",
    question: "人と話すことが好きだ",
    trait: "extraversion",
    direction: "positive",
    keywords: ["話す", "会話", "コミュニケーション", "人との交流"],
  },
  {
    id: "E2",
    question: "パーティーや集まりが好きだ",
    trait: "extraversion",
    direction: "positive",
    keywords: ["パーティー", "集まり", "イベント", "飲み会"],
  },
  {
    id: "E3",
    question: "一人でいることが好きだ",
    trait: "extraversion",
    direction: "negative",
    keywords: ["一人", "独り", "ソロ", "単独"],
  },
  {
    id: "E4",
    question: "新しい人と出会うのが楽しい",
    trait: "extraversion",
    direction: "positive",
    keywords: ["新しい人", "出会い", "知り合い", "初対面"],
  },
  {
    id: "E5",
    question: "静かな場所を好む",
    trait: "extraversion",
    direction: "negative",
    keywords: ["静か", "静寂", "騒音", "音"],
  },
  {
    id: "E6",
    question: "積極的に話しかけることが多い",
    trait: "extraversion",
    direction: "positive",
    keywords: ["積極的", "話しかける", "声をかける", "自分から"],
  },
  {
    id: "E7",
    question: "大勢の人の前で話すのが得意だ",
    trait: "extraversion",
    direction: "positive",
    keywords: ["大勢", "人前", "プレゼン", "発表"],
  },
  {
    id: "E8",
    question: "人混みを避けたがる",
    trait: "extraversion",
    direction: "negative",
    keywords: ["人混み", "混雑", "人が多い", "満員"],
  },
  {
    id: "E9",
    question: "エネルギッシュで活発だ",
    trait: "extraversion",
    direction: "positive",
    keywords: ["エネルギッシュ", "活発", "元気", "アクティブ"],
  },
  {
    id: "E10",
    question: "控えめで目立たないようにしている",
    trait: "extraversion",
    direction: "negative",
    keywords: ["控えめ", "目立たない", "謙虚", "遠慮"],
  },
  {
    id: "E11",
    question: "社交的な場面で居心地が良い",
    trait: "extraversion",
    direction: "positive",
    keywords: ["社交的", "社交場", "交流", "ネットワーキング"],
  },
  {
    id: "E12",
    question: "会話の中心にいることが多い",
    trait: "extraversion",
    direction: "positive",
    keywords: ["会話の中心", "主導", "リード", "話題提供"],
  },
  {
    id: "E13",
    question: "内気で恥ずかしがり屋だ",
    trait: "extraversion",
    direction: "negative",
    keywords: ["内気", "恥ずかしがり", "シャイ", "人見知り"],
  },
  {
    id: "E14",
    question: "明るく陽気な性格だ",
    trait: "extraversion",
    direction: "positive",
    keywords: ["明るい", "陽気", "ポジティブ", "楽観的"],
  },
  {
    id: "E15",
    question: "知らない人とすぐに打ち解けられる",
    trait: "extraversion",
    direction: "positive",
    keywords: ["打ち解ける", "親しくなる", "仲良く", "距離を縮める"],
  },
  {
    id: "E16",
    question: "休日は家でゆっくり過ごしたい",
    trait: "extraversion",
    direction: "negative",
    keywords: ["家", "ゆっくり", "インドア", "休息"],
  },
  {
    id: "E17",
    question: "大きな声で話すことが多い",
    trait: "extraversion",
    direction: "positive",
    keywords: ["大きな声", "声が大きい", "音量", "うるさい"],
  },
  {
    id: "E18",
    question: "グループの中では聞き役に回ることが多い",
    trait: "extraversion",
    direction: "negative",
    keywords: ["聞き役", "聞く", "傾聴", "受け身"],
  },
  {
    id: "E19",
    question: "注目されることを楽しむ",
    trait: "extraversion",
    direction: "positive",
    keywords: ["注目", "注目される", "目立つ", "スポットライト"],
  },
  {
    id: "E20",
    question: "少数の親しい友人がいれば十分だ",
    trait: "extraversion",
    direction: "negative",
    keywords: ["少数", "親しい友人", "深い関係", "質重視"],
  },

  // 協調性 (Agreeableness) - 20問
  {
    id: "A1",
    question: "他人の気持ちを理解しようとする",
    trait: "agreeableness",
    direction: "positive",
    keywords: ["気持ち", "理解", "共感", "感情"],
  },
  {
    id: "A2",
    question: "人を助けることが好きだ",
    trait: "agreeableness",
    direction: "positive",
    keywords: ["助ける", "ヘルプ", "サポート", "支援"],
  },
  {
    id: "A3",
    question: "競争することが好きだ",
    trait: "agreeableness",
    direction: "negative",
    keywords: ["競争", "勝負", "争い", "ライバル"],
  },
  {
    id: "A4",
    question: "寛容で理解があると思う",
    trait: "agreeableness",
    direction: "positive",
    keywords: ["寛容", "理解", "許す", "受け入れる"],
  },
  {
    id: "A5",
    question: "自分の意見を主張することが大切だ",
    trait: "agreeableness",
    direction: "negative",
    keywords: ["意見主張", "自己主張", "主張", "譲らない"],
  },
  {
    id: "A6",
    question: "人に親切にすることを心がけている",
    trait: "agreeableness",
    direction: "positive",
    keywords: ["親切", "優しい", "思いやり", "配慮"],
  },
  {
    id: "A7",
    question: "他人を信頼しやすい",
    trait: "agreeableness",
    direction: "positive",
    keywords: ["信頼", "信じる", "疑わない", "性善説"],
  },
  {
    id: "A8",
    question: "人と対立することが多い",
    trait: "agreeableness",
    direction: "negative",
    keywords: ["対立", "喧嘩", "衝突", "言い争い"],
  },
  {
    id: "A9",
    question: "協力して物事を進めるのが好きだ",
    trait: "agreeableness",
    direction: "positive",
    keywords: ["協力", "チームワーク", "連携", "協働"],
  },
  {
    id: "A10",
    question: "自分の利益を優先することが多い",
    trait: "agreeableness",
    direction: "negative",
    keywords: ["自分の利益", "利己的", "得", "損得"],
  },
  {
    id: "A11",
    question: "困っている人を見ると放っておけない",
    trait: "agreeableness",
    direction: "positive",
    keywords: ["困っている人", "放っておけない", "手を差し伸べる", "助けたい"],
  },
  {
    id: "A12",
    question: "人の悪口を言うことは少ない",
    trait: "agreeableness",
    direction: "positive",
    keywords: ["悪口", "陰口", "批判", "ネガティブ"],
  },
  {
    id: "A13",
    question: "自分が正しいと思ったら譲らない",
    trait: "agreeableness",
    direction: "negative",
    keywords: ["譲らない", "頑固", "正しい", "妥協しない"],
  },
  {
    id: "A14",
    question: "相手の立場に立って考えることができる",
    trait: "agreeableness",
    direction: "positive",
    keywords: ["相手の立場", "立場に立つ", "視点を変える", "相手目線"],
  },
  {
    id: "A15",
    question: "利害関係で人を判断することがある",
    trait: "agreeableness",
    direction: "negative",
    keywords: ["利害関係", "損得勘定", "計算", "利用価値"],
  },
  {
    id: "A16",
    question: "平和主義者だと思う",
    trait: "agreeableness",
    direction: "positive",
    keywords: ["平和主義", "争いを避ける", "穏やか", "調和"],
  },
  {
    id: "A17",
    question: "人を疑うことが多い",
    trait: "agreeableness",
    direction: "negative",
    keywords: ["疑う", "疑心暗鬼", "警戒", "信じない"],
  },
  {
    id: "A18",
    question: "他人のために時間を使うことを惜しまない",
    trait: "agreeableness",
    direction: "positive",
    keywords: ["他人のため", "時間を使う", "惜しまない", "献身的"],
  },
  {
    id: "A19",
    question: "勝ち負けにこだわることが多い",
    trait: "agreeableness",
    direction: "negative",
    keywords: ["勝ち負け", "こだわる", "勝利", "負けず嫌い"],
  },
  {
    id: "A20",
    question: "人の成功を心から喜べる",
    trait: "agreeableness",
    direction: "positive",
    keywords: ["人の成功", "喜ぶ", "祝福", "嫉妬しない"],
  },

  // 誠実性 (Conscientiousness) - 20問
  {
    id: "C1",
    question: "決めたことは最後までやり通す",
    trait: "conscientiousness",
    direction: "positive",
    keywords: ["やり通す", "最後まで", "完遂", "継続"],
  },
  {
    id: "C2",
    question: "計画を立てて物事を進めるのが好きだ",
    trait: "conscientiousness",
    direction: "positive",
    keywords: ["計画", "プラン", "予定", "スケジュール"],
  },
  {
    id: "C3",
    question: "思いついたらすぐに行動する",
    trait: "conscientiousness",
    direction: "negative",
    keywords: ["思いつき", "すぐ行動", "衝動的", "直感的"],
  },
  {
    id: "C4",
    question: "整理整頓が得意だ",
    trait: "conscientiousness",
    direction: "positive",
    keywords: ["整理整頓", "片付け", "整理", "綺麗"],
  },
  {
    id: "C5",
    question: "時間に遅れることがよくある",
    trait: "conscientiousness",
    direction: "negative",
    keywords: ["遅れる", "遅刻", "時間", "約束"],
  },
  {
    id: "C6",
    question: "責任感が強いと思う",
    trait: "conscientiousness",
    direction: "positive",
    keywords: ["責任感", "責任", "義務", "使命感"],
  },
  {
    id: "C7",
    question: "細かいことにも注意を払う",
    trait: "conscientiousness",
    direction: "positive",
    keywords: ["細かい", "注意", "気を配る", "ディテール"],
  },
  {
    id: "C8",
    question: "物事を先延ばしにしがちだ",
    trait: "conscientiousness",
    direction: "negative",
    keywords: ["先延ばし", "後回し", "先送り", "締切"],
  },
  {
    id: "C9",
    question: "ルールや規則を守ることを重視する",
    trait: "conscientiousness",
    direction: "positive",
    keywords: ["ルール", "規則", "守る", "規律"],
  },
  {
    id: "C10",
    question: "気分によって行動が変わりやすい",
    trait: "conscientiousness",
    direction: "negative",
    keywords: ["気分", "行動が変わる", "ムラ", "一貫性"],
  },
  {
    id: "C11",
    question: "目標を設定して努力することが好きだ",
    trait: "conscientiousness",
    direction: "positive",
    keywords: ["目標", "努力", "設定", "ゴール"],
  },
  {
    id: "C12",
    question: "約束を守ることを大切にする",
    trait: "conscientiousness",
    direction: "positive",
    keywords: ["約束", "守る", "大切", "信頼"],
  },
  {
    id: "C13",
    question: "部屋が散らかっていても気にならない",
    trait: "conscientiousness",
    direction: "negative",
    keywords: ["散らかる", "気にならない", "だらしない", "乱雑"],
  },
  {
    id: "C14",
    question: "完璧主義な傾向がある",
    trait: "conscientiousness",
    direction: "positive",
    keywords: ["完璧主義", "完璧", "妥協しない", "徹底的"],
  },
  {
    id: "C15",
    question: "面倒くさがりだ",
    trait: "conscientiousness",
    direction: "negative",
    keywords: ["面倒くさがり", "面倒", "めんどい", "億劫"],
  },
  {
    id: "C16",
    question: "仕事や勉強に集中できる",
    trait: "conscientiousness",
    direction: "positive",
    keywords: ["集中", "集中力", "没頭", "フォーカス"],
  },
  {
    id: "C17",
    question: "準備不足で失敗することが多い",
    trait: "conscientiousness",
    direction: "negative",
    keywords: ["準備不足", "失敗", "準備", "事前準備"],
  },
  {
    id: "C18",
    question: "自分に厳しいと思う",
    trait: "conscientiousness",
    direction: "positive",
    keywords: ["自分に厳しい", "厳格", "ストイック", "自己管理"],
  },
  {
    id: "C19",
    question: "適当にやることが多い",
    trait: "conscientiousness",
    direction: "negative",
    keywords: ["適当", "いい加減", "雑", "テキトー"],
  },
  {
    id: "C20",
    question: "効率を考えて行動する",
    trait: "conscientiousness",
    direction: "positive",
    keywords: ["効率", "効率的", "合理的", "最適化"],
  },

  // 神経症傾向 (Neuroticism) - 20問
  {
    id: "N1",
    question: "心配事があると眠れない",
    trait: "neuroticism",
    direction: "positive",
    keywords: ["心配事", "眠れない", "不眠", "悩み"],
  },
  {
    id: "N2",
    question: "ストレスを感じやすい",
    trait: "neuroticism",
    direction: "positive",
    keywords: ["ストレス", "プレッシャー", "緊張", "負担"],
  },
  {
    id: "N3",
    question: "冷静でいることが多い",
    trait: "neuroticism",
    direction: "negative",
    keywords: ["冷静", "落ち着く", "平静", "安定"],
  },
  {
    id: "N4",
    question: "不安になることが多い",
    trait: "neuroticism",
    direction: "positive",
    keywords: ["不安", "心配", "憂鬱", "恐れ"],
  },
  {
    id: "N5",
    question: "感情的になることは少ない",
    trait: "neuroticism",
    direction: "negative",
    keywords: ["感情的", "理性的", "論理的", "客観的"],
  },
  {
    id: "N6",
    question: "ちょっとしたことでイライラする",
    trait: "neuroticism",
    direction: "positive",
    keywords: ["イライラ", "怒り", "短気", "苛立ち"],
  },
  {
    id: "N7",
    question: "気持ちが落ち込みやすい",
    trait: "neuroticism",
    direction: "positive",
    keywords: ["落ち込む", "沈む", "うつ", "憂鬱"],
  },
  {
    id: "N8",
    question: "気分が安定している",
    trait: "neuroticism",
    direction: "negative",
    keywords: ["気分安定", "安定", "一定", "変わらない"],
  },
  {
    id: "N9",
    question: "緊張しやすい性格だ",
    trait: "neuroticism",
    direction: "positive",
    keywords: ["緊張", "緊張しやすい", "あがり症", "ナーバス"],
  },
  {
    id: "N10",
    question: "リラックスして過ごすことが多い",
    trait: "neuroticism",
    direction: "negative",
    keywords: ["リラックス", "のんびり", "ゆったり", "気楽"],
  },
  {
    id: "N11",
    question: "小さなことで動揺してしまう",
    trait: "neuroticism",
    direction: "positive",
    keywords: ["動揺", "小さなこと", "パニック", "うろたえる"],
  },
  {
    id: "N12",
    question: "困難な状況でも冷静に対処できる",
    trait: "neuroticism",
    direction: "negative",
    keywords: ["困難", "冷静対処", "危機管理", "平常心"],
  },
  {
    id: "N13",
    question: "失敗を引きずってしまう",
    trait: "neuroticism",
    direction: "positive",
    keywords: ["失敗", "引きずる", "後悔", "くよくよ"],
  },
  {
    id: "N14",
    question: "楽観的に物事を考える",
    trait: "neuroticism",
    direction: "negative",
    keywords: ["楽観的", "ポジティブ", "前向き", "明るい"],
  },
  {
    id: "N15",
    question: "人の目が気になることが多い",
    trait: "neuroticism",
    direction: "positive",
    keywords: ["人の目", "気になる", "人目", "評価"],
  },
  {
    id: "N16",
    question: "マイペースで過ごせる",
    trait: "neuroticism",
    direction: "negative",
    keywords: ["マイペース", "自分のペース", "焦らない", "ゆっくり"],
  },
  {
    id: "N17",
    question: "将来のことを考えると不安になる",
    trait: "neuroticism",
    direction: "positive",
    keywords: ["将来", "不安", "先行き", "心配"],
  },
  {
    id: "N18",
    question: "ストレス発散が上手だ",
    trait: "neuroticism",
    direction: "negative",
    keywords: ["ストレス発散", "上手", "リフレッシュ", "切り替え"],
  },
  {
    id: "N19",
    question: "批判されると深く傷つく",
    trait: "neuroticism",
    direction: "positive",
    keywords: ["批判", "傷つく", "ダメージ", "落ち込む"],
  },
  {
    id: "N20",
    question: "何事も気にしない性格だ",
    trait: "neuroticism",
    direction: "negative",
    keywords: ["気にしない", "おおらか", "大らか", "細かくない"],
  },

  // 開放性 (Openness) - 20問
  {
    id: "O1",
    question: "新しいことにチャレンジするのが好きだ",
    trait: "openness",
    direction: "positive",
    keywords: ["新しいこと", "チャレンジ", "挑戦", "新規"],
  },
  {
    id: "O2",
    question: "芸術や美しいものに興味がある",
    trait: "openness",
    direction: "positive",
    keywords: ["芸術", "美しい", "アート", "美術"],
  },
  {
    id: "O3",
    question: "決まった方法でやるのが好きだ",
    trait: "openness",
    direction: "negative",
    keywords: ["決まった方法", "定型", "慣習", "いつも通り"],
  },
  {
    id: "O4",
    question: "想像力が豊かだと思う",
    trait: "openness",
    direction: "positive",
    keywords: ["想像力", "豊か", "創造", "イマジネーション"],
  },
  {
    id: "O5",
    question: "現実的な考え方をする",
    trait: "openness",
    direction: "negative",
    keywords: ["現実的", "実用的", "プラクティカル", "現実"],
  },
  {
    id: "O6",
    question: "抽象的な議論や哲学に興味がある",
    trait: "openness",
    direction: "positive",
    keywords: ["抽象的", "哲学", "議論", "思想"],
  },
  {
    id: "O7",
    question: "創造的な活動をするのが好きだ",
    trait: "openness",
    direction: "positive",
    keywords: ["創造的", "クリエイティブ", "創作", "制作"],
  },
  {
    id: "O8",
    question: "伝統的な方法を好む",
    trait: "openness",
    direction: "negative",
    keywords: ["伝統的", "昔ながら", "古典的", "保守的"],
  },
  {
    id: "O9",
    question: "好奇心が強い方だ",
    trait: "openness",
    direction: "positive",
    keywords: ["好奇心", "興味", "探求", "知りたい"],
  },
  {
    id: "O10",
    question: "安定した生活を重視する",
    trait: "openness",
    direction: "negative",
    keywords: ["安定", "安定した生活", "変化なし", "平穏"],
  },
  {
    id: "O11",
    question: "新しい文化や価値観を学ぶのが楽しい",
    trait: "openness",
    direction: "positive",
    keywords: ["新しい文化", "価値観", "学ぶ", "多様性"],
  },
  {
    id: "O12",
    question: "変化を嫌う傾向がある",
    trait: "openness",
    direction: "negative",
    keywords: ["変化を嫌う", "変化", "ルーティン", "同じ"],
  },
  {
    id: "O13",
    question: "独創的なアイデアを考えるのが得意だ",
    trait: "openness",
    direction: "positive",
    keywords: ["独創的", "アイデア", "ユニーク", "オリジナル"],
  },
  {
    id: "O14",
    question: "慣れ親しんだものを好む",
    trait: "openness",
    direction: "negative",
    keywords: ["慣れ親しんだ", "馴染み", "お決まり", "いつもの"],
  },
  {
    id: "O15",
    question: "複雑な問題を考えるのが好きだ",
    trait: "openness",
    direction: "positive",
    keywords: ["複雑な問題", "考える", "思考", "分析"],
  },
  {
    id: "O16",
    question: "シンプルで分かりやすいものを好む",
    trait: "openness",
    direction: "negative",
    keywords: ["シンプル", "分かりやすい", "簡単", "明快"],
  },
  {
    id: "O17",
    question: "異なる視点から物事を見るのが好きだ",
    trait: "openness",
    direction: "positive",
    keywords: ["異なる視点", "多角的", "違う見方", "別の角度"],
  },
  {
    id: "O18",
    question: "一つの考え方にこだわることが多い",
    trait: "openness",
    direction: "negative",
    keywords: ["こだわる", "一つの考え", "固執", "頑固"],
  },
  {
    id: "O19",
    question: "知的な刺激を求めることが多い",
    trait: "openness",
    direction: "positive",
    keywords: ["知的刺激", "刺激", "学習", "知識"],
  },
  {
    id: "O20",
    question: "実用的でないことには興味がない",
    trait: "openness",
    direction: "negative",
    keywords: ["実用的でない", "興味がない", "役に立たない", "無駄"],
  },
];

// 回答の選択肢
const ANSWER_OPTIONS = [
  {value: 1, label: "全く当てはまらない"},
  {value: 2, label: "あまり当てはまらない"},
  {value: 3, label: "どちらでもない"},
  {value: 4, label: "やや当てはまる"},
  {value: 5, label: "非常に当てはまる"},
];

// 回答を点数に変換する関数
function convertAnswerToScore(answer, direction) {
  if (direction === "positive") {
    return answer; // 1-5をそのまま使用
  } else {
    return 6 - answer; // 逆転項目: 1→5, 2→4, 3→3, 4→2, 5→1
  }
}

// 特定の特性の質問を取得
function getQuestionsForTrait(trait) {
  return BIG5_QUESTIONS.filter((q) => q.trait === trait);
}

// 全質問をシャッフルして返す
function getShuffledQuestions() {
  const shuffled = [...BIG5_QUESTIONS];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

// 次の質問を取得（進捗を考慮、再出題を防止）
function getNextQuestion(answeredQuestions = []) {
  const answeredIds = answeredQuestions.map((q) => q.questionId || q.id);
  const remainingQuestions = BIG5_QUESTIONS.filter((q) =>
    !answeredIds.includes(q.id));

  if (remainingQuestions.length === 0) {
    return null; // 全質問完了
  }

  // 各特性から均等に出題するロジック
  const traits = ["extraversion", "agreeableness", "conscientiousness",
    "neuroticism", "openness"];
  const traitCounts = {};

  // 各特性の回答済み数をカウント
  traits.forEach((trait) => {
    traitCounts[trait] = answeredQuestions.filter((q) => {
      const questionId = q.questionId || q.id;
      const question = BIG5_QUESTIONS.find((bq) => bq.id === questionId);
      return question && question.trait === trait;
    }).length;
  });

  // 最も回答数の少ない特性を選択
  const minCount = Math.min(...Object.values(traitCounts));
  const leastAnsweredTraits = traits.filter((trait) =>
    traitCounts[trait] === minCount);

  // その特性の中からランダムに質問を選択
  const targetTrait = leastAnsweredTraits[Math.floor(
      Math.random() * leastAnsweredTraits.length)];
  const traitQuestions = remainingQuestions.filter((q) =>
    q.trait === targetTrait);

  return traitQuestions[Math.floor(Math.random() * traitQuestions.length)];
}

// BIG5スコアを計算
function calculateBIG5Scores(answers) {
  const scores = {
    extraversion: 0,
    agreeableness: 0,
    conscientiousness: 0,
    neuroticism: 0,
    openness: 0,
  };

  const counts = {
    extraversion: 0,
    agreeableness: 0,
    conscientiousness: 0,
    neuroticism: 0,
    openness: 0,
  };

  // 各回答を処理
  answers.forEach((answer) => {
    const questionId = answer.questionId || answer.id;
    const question = BIG5_QUESTIONS.find((q) => q.id === questionId);
    if (question) {
      const score = convertAnswerToScore(answer.value, question.direction);
      scores[question.trait] += score;
      counts[question.trait]++;
    }
  });

  // 平均を計算（1-5の範囲で）
  const finalScores = {};
  Object.keys(scores).forEach((trait) => {
    if (counts[trait] > 0) {
      finalScores[trait] = Math.round(scores[trait] / counts[trait]);
    } else {
      finalScores[trait] = 3; // デフォルト値
    }
  });

  return finalScores;
}

// チャット内容からBIG5関連の話題を検出し、該当する質問を取得
function detectBIG5TopicInChat(message) {
  const lowerMessage = message.toLowerCase();

  for (const question of BIG5_QUESTIONS) {
    // キーワードマッチング
    const hasKeyword = question.keywords.some((keyword) =>
      lowerMessage.includes(keyword.toLowerCase()),
    );

    if (hasKeyword) {
      return {
        question: question,
        relevantKeywords: question.keywords.filter((keyword) =>
          lowerMessage.includes(keyword.toLowerCase()),
        ),
      };
    }
  }

  return null;
}

// チャット内容から推定スコアを計算
function estimateScoreFromChat(message, question) {
  const lowerMessage = message.toLowerCase();

  // ポジティブ/ネガティブなワードを含んでいるかチェック
  const positiveWords = ["好き", "得意", "そう", "はい", "そうです", "よく", "いつも", "大好き"];
  const negativeWords = ["嫌い", "苦手", "ない", "いいえ", "あまり", "全然", "めったに", "大嫌い"];

  let score = 3; // デフォルト（中間値）

  const hasPositive = positiveWords.some((word) => lowerMessage.includes(word));
  const hasNegative = negativeWords.some((word) => lowerMessage.includes(word));

  if (hasPositive && !hasNegative) {
    score = question.direction === "positive" ? 4 : 2;
  } else if (hasNegative && !hasPositive) {
    score = question.direction === "positive" ? 2 : 4;
  }

  return score;
}

module.exports = {
  BIG5_QUESTIONS,
  ANSWER_OPTIONS,
  convertAnswerToScore,
  getQuestionsForTrait,
  getShuffledQuestions,
  getNextQuestion,
  calculateBIG5Scores,
  detectBIG5TopicInChat,
  estimateScoreFromChat,
};
