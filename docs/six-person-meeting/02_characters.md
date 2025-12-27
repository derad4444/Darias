# 6人のキャラクター設計

## 🎭 6人の概要

ユーザーのBIG5性格データを基に、6つの異なる視点を持つ「自分」を生成します。

---

## 1️⃣ 今の自分

### 基本情報
- **アイコン**: 🧑
- **名前**: 今の自分
- **キャッチコピー**: 「慎重派の分析家」
- **説明**: いつものあなた。リスクを考えてデータを重視する性格。

### 性格特性
- ユーザーのBIG5そのまま
- 例: 誠実性4, 外向性2, 開放性4, 協調性4, 情緒安定性3

### 話し方の特徴
- 「〜と思う」「〜だろう」（推測形）
- 「リスクも考慮すると...」
- 「データを見ると...」
- データや統計を引用する

### 役割
- 客観的な分析
- ユーザーに最も近い視点
- 統計データの提示

### 配置
- **左側**（慎重派グループ）

---

## 2️⃣ 真逆の自分

### 基本情報
- **アイコン**: 🔄
- **名前**: 真逆の自分
- **キャッチコピー**: 「自由奔放な冒険家」
- **説明**: あなたとは正反対の性格。大胆で即断即決タイプ。

### 性格特性（BIG5を反転）
```swift
Big5Scores(
    openness: 6 - userBIG5.openness,
    conscientiousness: 6 - userBIG5.conscientiousness,
    extraversion: 6 - userBIG5.extraversion,
    agreeableness: 6 - userBIG5.agreeableness,
    neuroticism: 6 - userBIG5.neuroticism
)
// 例: 4 → 2, 5 → 1, 3 → 3
```

### 話し方の特徴
- 「やっちゃえ！」「今すぐ！」
- 「考えすぎだって！」
- 「人生一度きりだよ！」
- 感嘆符が多い、テンション高め

### 役割
- 大胆な提案
- リスクテイキングの視点
- ユーザーの殻を破る刺激

### 配置
- **右側**（行動派グループ）

---

## 3️⃣ 理想の自分

### 基本情報
- **アイコン**: ✨
- **名前**: 理想の自分
- **キャッチコピー**: 「冷静な完璧主義者」
- **説明**: バランスが取れた成長した姿。客観的に物事を見る。

### 性格特性（全特性を高水準に）
```swift
Big5Scores(
    openness: max(userBIG5.openness, 4),
    conscientiousness: max(userBIG5.conscientiousness, 4),
    extraversion: optimizeToMiddle(userBIG5.extraversion, target: 3.5),
    agreeableness: max(userBIG5.agreeableness, 4),
    neuroticism: max(userBIG5.neuroticism, 4) // 高い = 安定
)

// optimizeToMiddle: 極端な値を中央寄りに調整
// 1-2 → 3, 4-5 → 3-4
```

### 話し方の特徴
- 「客観的に見ると...」
- 「バランスを取るなら...」
- 「両方の視点から考えると...」
- 冷静で論理的

### 役割
- 最適解の提示
- バランスの取れた視点
- 成長した自分の姿

### 配置
- **左側**（慎重派グループ）

---

## 4️⃣ 本音の自分

### 基本情報
- **アイコン**: 👤
- **名前**: 本音の自分
- **キャッチコピー**: 「率直な現実主義者」
- **説明**: 建前なし。本当に思っていることをズバリ言う性格。

### 性格特性（協調性を下げ、率直に）
```swift
Big5Scores(
    openness: min(userBIG5.openness + 1.5, 5),
    conscientiousness: max(userBIG5.conscientiousness - 2, 1),
    extraversion: min(userBIG5.extraversion + 1.5, 5),
    agreeableness: max(userBIG5.agreeableness - 2.5, 1), // 本音
    neuroticism: max(userBIG5.neuroticism - 1.5, 1)
)
// 協調性を大幅に下げて率直な性格に
```

### 話し方の特徴
- 「正直に言うと...」
- 「それって〇〇なだけじゃない？」
- 「本当は〇〇したいんでしょ？」
- ストレートで遠慮がない

### 役割
- 本音を突きつける
- 隠れた動機を指摘
- 厳しいが的確なアドバイス

### 配置
- **右側**（行動派グループ）

---

## 5️⃣ 子供の頃の自分

### 基本情報
- **アイコン**: 👶
- **名前**: 子供の頃の自分
- **キャッチコピー**: 「純粋な夢見る少年/少女」
- **説明**: 10歳の頃のあなた。感情を大切にワクワクを追い求める。

### 性格特性（発達心理学ベース）
```swift
Big5Scores(
    openness: 5,  // 子供は好奇心旺盛
    conscientiousness: 1,  // 計画性低い
    extraversion: max(userBIG5.extraversion + 1, 4),
    agreeableness: 3,  // 純粋
    neuroticism: 2  // 感情的だが回復も早い
)
// 子供特有の高い好奇心と低い計画性
```

### 話し方の特徴
- 「ねえねえ」「わくわく」
- 「楽しい方がいいよ！」
- 「どっちがワクワクする？」
- 子供っぽい表現、絵文字多め

### 役割
- 感情を大切にする視点
- 純粋な好奇心
- 楽しさ・ワクワクを軸にした判断

### 配置
- **右側**（行動派グループ）

---

## 6️⃣ 未来の自分（70歳）

### 基本情報
- **アイコン**: 👴
- **名前**: 未来の自分（70歳）
- **キャッチコピー**: 「達観した人生の先輩」
- **説明**: 70歳になったあなた。長い人生経験から冷静にアドバイスしてくれる。

### 性格特性（老年期の変化を反映）
```swift
Big5Scores(
    openness: max(userBIG5.openness - 1, 2),  // やや保守的
    conscientiousness: min(userBIG5.conscientiousness + 0.5, 5),
    extraversion: max(userBIG5.extraversion - 1, 2),  // 落ち着く
    agreeableness: min(userBIG5.agreeableness + 1, 5),  // 寛容
    neuroticism: min(userBIG5.neuroticism + 1.5, 5)  // 達観
)
// 年齢と共に寛容で安定した性格に
```

### 話し方の特徴
- 「私が70年生きて学んだのは...」
- 「長期的に見れば...」
- 「10年後、20年後を考えてごらん」
- 穏やかで俯瞰的

### 役割
- 長期的視点
- 人生経験からのアドバイス
- 達観した視点

### 配置
- **左側**（慎重派グループ）

---

## 🎨 キャラクター配置（左右分け）

### 左側（慎重派グループ）
```
🧑 今の自分       - いつものあなた
✨ 理想の自分     - バランス型
👴 未来の自分     - 達観した視点
```

### 右側（行動派グループ）
```
🔄 真逆の自分     - 大胆・即決
👤 本音の自分     - 率直・遠慮なし
👶 子供の自分     - 純粋・感情的
```

---

## 💬 会話例

### 悩み: 「転職すべきか迷っている」

#### 🧑 今の自分
「転職は大きな決断だから、慎重に考えた方がいい。データを見ると、君と似た性格の147人のうち...」

#### 🔄 真逆の自分
「えー！慎重すぎない？人生一度きりだよ！今すぐ転職活動始めよう！」

#### 👴 未来の自分（70歳）
「二人とも落ち着きなさい。私が70年生きて学んだのは、『焦って決めたことは後悔する』ということだよ」

#### ✨ 理想の自分
「客観的に見ましょう。統計データと感情、両方大事です」

#### 👶 子供の自分
「ねえねえ、どっちがワクワクする？楽しい方がいいよ！」

#### 👤 本音の自分
「正直に言うと、今の会社から逃げたいだけじゃない？それって転職の理由になる？」

---

## 🔧 実装上の注意点

### 性格変換関数
```swift
enum PersonalityVariant {
    case original      // ユーザーそのまま
    case opposite      // 全特性反転
    case ideal         // 全特性高水準
    case shadow        // 協調性低、率直
    case child         // 固定値（開放性90等）
    case wise          // 老年期の変化
}

func transformBIG5(
    _ original: Big5Scores,
    variant: PersonalityVariant
) -> Big5Scores {
    // 各variantに応じた変換ロジック
}
```

### キャラクター説明文の動的生成
```swift
func getCharacterDescription(
    variant: PersonalityVariant,
    userBIG5: Big5Scores
) -> String {
    switch variant {
    case .original:
        return "いつものあなた。\(getTraitDescription(userBIG5))"
    case .opposite:
        return "あなたとは正反対の性格。大胆で即断即決タイプ。"
    // ...
    }
}
```

---

## 📝 テンプレート設計への展開

各キャラクターの話し方の特徴を活かして、30パターンのテンプレートを作成する際の基準となります。

詳細は `05_api-design.md` を参照。
