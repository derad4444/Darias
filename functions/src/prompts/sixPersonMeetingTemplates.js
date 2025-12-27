// src/prompts/sixPersonMeetingTemplates.js

/**
 * 6人会議の会話生成テンプレート
 */

/**
 * カテゴリ別の基本テンプレート
 */
const CONVERSATION_TEMPLATES = {
  career: {
    rounds: [
      {
        // ラウンド1: 状況確認
        cautious: "転職は慎重に考えるべきだよ。今の職場の良い点も見直してみたら？",
        active: "新しい環境に挑戦するのもありだと思う！",
        emotional: "本当にやりたいことは何か、心に聞いてみて。",
        logical: "キャリアパスと市場価値を客観的に分析しよう。",
        opposite: "今すぐ動くべきじゃない？迷ってる時間がもったいない。",
        ideal: "自分の価値観と将来のビジョンを整理してから決めよう。",
      },
      {
        // ラウンド2: 深掘り
        cautious: "リスクを洗い出して、失敗した時の対策も考えておこう。",
        active: "やってみないとわからないこともあるよ！",
        emotional: "周りの人との関係も大切にしながら決めたいね。",
        logical: "転職市場のデータと、自分のスキルセットを照らし合わせてみて。",
        opposite: "安定より成長を選ぶべきだと思う。",
        ideal: "短期的な損得だけでなく、長期的な幸せを考えよう。",
      },
    ],
    conclusion: {
      summary: "転職は人生の大きな決断。慎重派と行動派の意見を両方考慮しながら、自分の価値観に基づいて決めることが大切です。",
      recommendations: [
        "現在の職場での成長可能性を再評価する",
        "転職先の企業文化や価値観を徹底的にリサーチする",
        "短期的な給与だけでなく、長期的なキャリアパスを考える",
        "信頼できる人に相談し、客観的な意見を聞く",
      ],
      nextSteps: [
        "自己分析：本当にやりたいことを明確にする",
        "情報収集：転職市場と企業情報をリサーチする",
        "計画立案：転職のタイムラインと準備を計画する",
      ],
    },
  },

  romance: {
    rounds: [
      {
        cautious: "相手のことをもっと知ってから判断した方がいいかも。",
        active: "気持ちを素直に伝えてみたら？",
        emotional: "自分の心の声に正直になることが大切だよ。",
        logical: "相性や価値観の一致を冷静に見極めよう。",
        opposite: "考えすぎずに、直感を信じて動いてみて。",
        ideal: "相手を尊重しながら、自分の気持ちも大切にしよう。",
      },
      {
        cautious: "焦らず、時間をかけて関係を築いていくのがいいと思う。",
        active: "チャンスは今かもしれない！勇気を出して！",
        emotional: "お互いの気持ちを共有することで、より深い絆が生まれるよ。",
        logical: "長期的な関係を考えて、相性を客観的に評価してみて。",
        opposite: "リスクを恐れていたら、何も始まらないよ。",
        ideal: "自然体で接しながら、お互いの成長を支え合える関係を目指そう。",
      },
    ],
    conclusion: {
      summary: "恋愛は感情と理性のバランスが大切。自分の気持ちを大切にしながら、相手のことも考慮して進めましょう。",
      recommendations: [
        "相手の価値観やライフスタイルをよく理解する",
        "自分の気持ちを素直に表現する勇気を持つ",
        "焦らず、自然な関係の発展を大切にする",
        "お互いの個性を尊重し合える関係を築く",
      ],
      nextSteps: [
        "自己理解：自分が求める関係性を明確にする",
        "コミュニケーション：相手との対話を深める",
        "行動：適切なタイミングで気持ちを伝える",
      ],
    },
  },

  money: {
    rounds: [
      {
        cautious: "まずは支出を見直して、無駄を削減することから始めよう。",
        active: "投資にチャレンジして、お金を増やす方法も考えてみたら？",
        emotional: "お金で得られる幸せと、本当の幸せのバランスを考えて。",
        logical: "収支を数値化して、具体的な目標を設定しよう。",
        opposite: "節約ばかり考えずに、自己投資も大切だよ。",
        ideal: "短期的な節約と長期的な資産形成の両方を考えよう。",
      },
      {
        cautious: "リスクの低い貯蓄や保険を優先した方が安心だよ。",
        active: "勉強して、積極的に投資してみるのもいいと思う！",
        emotional: "お金の不安を減らすことで、心の余裕も生まれるよ。",
        logical: "ライフプランに基づいて、必要な金額を逆算してみて。",
        opposite: "お金は使ってこそ価値がある。経験にも投資しよう。",
        ideal: "将来の安心と、今の充実感のバランスを取ろう。",
      },
    ],
    conclusion: {
      summary: "お金の管理は、将来の安心と現在の充実のバランスが重要。計画的に、でも柔軟に対応しましょう。",
      recommendations: [
        "月々の収支を可視化し、無駄な支出を削減する",
        "緊急時の備えとして、生活費3〜6ヶ月分を貯蓄する",
        "リスクとリターンを理解した上で、少額から投資を始める",
        "自己投資にも適度にお金を使い、スキルアップを図る",
      ],
      nextSteps: [
        "現状把握：家計簿をつけて支出を分析する",
        "目標設定：短期・中期・長期の目標金額を決める",
        "行動計画：貯蓄・投資・自己投資のバランスを設計する",
      ],
    },
  },

  health: {
    rounds: [
      {
        cautious: "無理のない範囲で、少しずつ生活習慣を改善していこう。",
        active: "新しい運動や食事法にチャレンジしてみたら？",
        emotional: "心と体の声を聞いて、無理をしないことが大切だよ。",
        logical: "データを記録して、効果を客観的に測定しよう。",
        opposite: "完璧を目指さず、楽しみながら続けられる方法を見つけて。",
        ideal: "継続できる習慣を作ることが、長期的な健康につながるよ。",
      },
      {
        cautious: "専門家に相談して、自分に合った方法を見つけよう。",
        active: "思い切って新しいことを始めてみるのもいいよ！",
        emotional: "ストレスを溜めないことも、健康には大切だよ。",
        logical: "目標を数値化して、進捗を管理してみて。",
        opposite: "制限ばかりじゃなく、自分へのご褒美も大切に。",
        ideal: "心身のバランスを整えながら、持続可能な方法を選ぼう。",
      },
    ],
    conclusion: {
      summary: "健康は一日にして成らず。無理なく続けられる習慣を作ることが、長期的な健康につながります。",
      recommendations: [
        "睡眠時間を確保し、質の良い睡眠を心がける",
        "バランスの取れた食事と適度な運動を習慣化する",
        "ストレス管理法を見つけ、リラックスする時間を作る",
        "定期的な健康診断で、体の状態をチェックする",
      ],
      nextSteps: [
        "現状評価：生活習慣を見直し、改善点を洗い出す",
        "目標設定：達成可能な小さな目標から始める",
        "習慣化：続けやすい環境を整え、少しずつ習慣にする",
      ],
    },
  },

  family: {
    rounds: [
      {
        cautious: "家族の気持ちをよく聞いて、慎重に対応しよう。",
        active: "率直にコミュニケーションを取ってみたら？",
        emotional: "お互いの気持ちを理解し合うことが大切だよ。",
        logical: "問題を整理して、一つずつ解決策を考えよう。",
        opposite: "時には自分の意見をはっきり伝えることも必要だよ。",
        ideal: "家族それぞれの立場を尊重しながら、解決策を探ろう。",
      },
      {
        cautious: "時間をかけて、少しずつ関係を改善していこう。",
        active: "新しいコミュニケーションの方法を試してみて！",
        emotional: "愛情を言葉や行動で表現することも大切だよ。",
        logical: "役割分担や期待値を明確にすると、すれ違いが減るよ。",
        opposite: "遠慮しすぎずに、本音で話し合うことも必要。",
        ideal: "お互いの個性を認め合いながら、絆を深めていこう。",
      },
    ],
    conclusion: {
      summary: "家族関係は、お互いの理解と尊重が基盤。コミュニケーションを大切にしながら、良好な関係を築きましょう。",
      recommendations: [
        "定期的に家族で話し合う時間を設ける",
        "お互いの気持ちや考えを否定せず、まず聞く姿勢を持つ",
        "感謝の気持ちを言葉で伝える習慣をつける",
        "それぞれの個性や価値観を尊重する",
      ],
      nextSteps: [
        "対話：まずは家族の話を聞く時間を作る",
        "理解：それぞれの立場や気持ちを理解する",
        "行動：小さなことから関係改善を始める",
      ],
    },
  },

  future: {
    rounds: [
      {
        cautious: "将来の不安は誰にでもあるよ。計画を立てて備えよう。",
        active: "やりたいことリストを作って、挑戦してみたら？",
        emotional: "本当に大切にしたい価値観を見つめ直してみて。",
        logical: "目標を具体化して、達成までのステップを考えよう。",
        opposite: "完璧な計画より、まず一歩踏み出すことが大事だよ。",
        ideal: "柔軟性を持ちながら、方向性を持って進もう。",
      },
      {
        cautious: "リスクヘッジも考えながら、準備を進めよう。",
        active: "新しいことに挑戦して、可能性を広げてみて！",
        emotional: "自分の内なる声に従うことも、大切な選択肢だよ。",
        logical: "現状分析と将来予測を基に、合理的な計画を立てよう。",
        opposite: "変化を恐れずに、積極的に未来を創っていこう。",
        ideal: "現実的な計画と、理想への情熱の両方を持とう。",
      },
    ],
    conclusion: {
      summary: "将来は不確実だからこそ、計画と柔軟性の両方が必要。自分らしい人生を設計しましょう。",
      recommendations: [
        "短期・中期・長期の目標を設定する",
        "やりたいことと、やるべきことのバランスを取る",
        "スキルアップや自己投資を継続する",
        "人とのつながりを大切にし、支え合えるネットワークを作る",
      ],
      nextSteps: [
        "ビジョン設定：5年後、10年後の理想の姿を描く",
        "計画立案：目標達成のためのアクションプランを作る",
        "実行：小さな一歩から始めて、継続的に見直す",
      ],
    },
  },

  other: {
    rounds: [
      {
        cautious: "まずは状況を整理して、落ち着いて考えよう。",
        active: "新しい視点から問題を見てみたら？",
        emotional: "自分の気持ちを大切にしながら判断して。",
        logical: "問題を分解して、一つずつ解決策を考えよう。",
        opposite: "今までと違うアプローチを試してみるのもありだよ。",
        ideal: "様々な視点を統合して、バランスの取れた判断をしよう。",
      },
      {
        cautious: "慎重に進めながら、リスクも考慮しよう。",
        active: "行動しながら学んでいくのもいいと思う！",
        emotional: "心が納得できる選択をすることが大切だよ。",
        logical: "データや事実を基に、客観的に判断してみて。",
        opposite: "時には直感も大事。思い切って決断してみて。",
        ideal: "理性と感情のバランスを取りながら決めよう。",
      },
    ],
    conclusion: {
      summary: "どんな悩みも、多角的な視点から考えることで、より良い解決策が見つかります。",
      recommendations: [
        "問題を明確にし、何が本当の課題なのかを見極める",
        "複数の選択肢を検討し、それぞれのメリット・デメリットを考える",
        "信頼できる人に相談し、異なる視点を取り入れる",
        "決断したら、まずは小さく試してみる",
      ],
      nextSteps: [
        "問題の明確化：何に悩んでいるのかを整理する",
        "情報収集：必要な情報を集め、選択肢を洗い出す",
        "決断と行動：優先順位をつけて、できることから始める",
      ],
    },
  },
};

/**
 * テンプレートから会話を生成
 * @param {string} category - カテゴリ
 * @param {Array<Object>} personalities - 6人のキャラクター情報
 * @return {Object} - 会話データ
 */
function generateConversationFromTemplate(category, personalities) {
  const template = CONVERSATION_TEMPLATES[category] || CONVERSATION_TEMPLATES.other;

  const rounds = template.rounds.map((roundTemplate, roundIndex) => {
    const messages = personalities.map((person) => {
      const messageText = roundTemplate[person.id] || roundTemplate.logical;
      return {
        characterId: person.id,
        characterName: person.name,
        text: messageText,
        timestamp: new Date().toISOString(),
      };
    });

    return {
      roundNumber: roundIndex + 1,
      messages,
    };
  });

  return {
    rounds,
    conclusion: template.conclusion,
  };
}

/**
 * GPT-4o-mini用のプロンプトを生成
 * @param {string} concern - ユーザーの悩み
 * @param {string} category - カテゴリ
 * @param {Array<Object>} personalities - 6人のキャラクター情報
 * @param {Object} statsData - 統計データ
 * @return {string} - プロンプト
 */
function createMeetingPrompt(concern, category, personalities, statsData) {
  const personalityDescriptions = personalities
      .map((p) => {
        return `- ${p.name}: ${p.description}
  開放性:${p.big5.openness}, 誠実性:${p.big5.conscientiousness}, 外向性:${p.big5.extraversion}, 協調性:${p.big5.agreeableness}, 神経症傾向:${p.big5.neuroticism}`;
      })
      .join("\n");

  return `あなたは性格心理学の専門家です。以下の状況で、6人の異なる性格の自分が集まって会議をする場面を生成してください。

【ユーザーの悩み】
${concern}

【カテゴリ】
${category}

【6人のキャラクター】
${personalityDescriptions}

【参考データ】
- 類似性格者: ${statsData.similarCount}人
- 平均年齢: ${statsData.avgAge}歳

【生成ルール】
1. 2ラウンドの会議形式で生成
2. 各ラウンドで6人全員が1回ずつ発言
3. 各発言は50-100文字程度
4. 慎重派(cautious)と行動派(active)が対立する構図
5. 感情派(emotional)と論理派(logical)が補完する構図
6. 真逆の自分(opposite)が予想外の視点を提供
7. 理想の自分(ideal)が全体をまとめる
8. 最後に、統合的な結論とアクションプランを提示

【出力形式】
以下のJSON形式で出力してください：

{
  "rounds": [
    {
      "roundNumber": 1,
      "messages": [
        {"characterId": "cautious", "characterName": "慎重派の自分", "text": "発言内容"},
        {"characterId": "active", "characterName": "行動派の自分", "text": "発言内容"},
        {"characterId": "emotional", "characterName": "感情重視の自分", "text": "発言内容"},
        {"characterId": "logical", "characterName": "論理重視の自分", "text": "発言内容"},
        {"characterId": "opposite", "characterName": "真逆の自分", "text": "発言内容"},
        {"characterId": "ideal", "characterName": "理想の自分", "text": "発言内容"}
      ]
    },
    {
      "roundNumber": 2,
      "messages": [...]
    }
  ],
  "conclusion": {
    "summary": "会議全体のまとめ (200文字程度)",
    "recommendations": ["アドバイス1", "アドバイス2", "アドバイス3", "アドバイス4"],
    "nextSteps": ["ステップ1", "ステップ2", "ステップ3"]
  }
}`;
}

module.exports = {
  CONVERSATION_TEMPLATES,
  generateConversationFromTemplate,
  createMeetingPrompt,
};
