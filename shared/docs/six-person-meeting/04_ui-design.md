# UI/UX設計

## 🗺️ 画面遷移フロー

```
HomeView（既存）
├─ チャットで悩みを話す
│  └─ キャラクターが「6人に相談する？」と提案
│     └─ [6人の自分に相談する]ボタン
│        └─ SixPersonMeetingView
│
└─ 右上の💭アイコンタップ
   └─ SixPersonInputView
      └─ SixPersonMeetingView

SixPersonMeetingView
├─ キャラクター紹介
├─ 検索中アニメーション
├─ 会話表示（チャット形式）
├─ 統合レポート
└─ アクション
   ├─ [キャラクターと話す] → HomeView
   ├─ [TODOに追加] → TodoView
   ├─ [予定に追加] → CalendarView
   └─ [メモに保存] → MemoView
```

---

## 📱 画面詳細設計

### 1. ホーム画面の修正

#### 既存HomeView.swiftへの追加

```swift
// 右上にアイコン追加
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: {
            showSixPersonMeeting = true
        }) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.title3)
                .foregroundColor(colorSettings.getCurrentAccentColor())
        }
    }
}

// Sheet追加
.sheet(isPresented: $showSixPersonMeeting) {
    NavigationStack {
        SixPersonInputView(userId: userId, characterId: characterId)
    }
}
```

#### チャットでの提案ロジック

```swift
// CharacterService.swiftに追加

func detectConcern(userMessage: String) -> ConcernType? {
    let concernPatterns: [String: ConcernType] = [
        "転職": .career,
        "仕事": .career,
        "辞めたい": .career,
        "恋愛": .romance,
        "好き": .romance,
        "結婚": .romance,
        "迷って": .decision,
        "悩んで": .decision,
        "不安": .stress,
        "疲れた": .stress
    ]

    for (keyword, type) in concernPatterns {
        if userMessage.contains(keyword) {
            return type
        }
    }

    return nil
}

enum ConcernType: String {
    case career = "career"
    case romance = "romance"
    case decision = "decision"
    case stress = "stress"
    case general = "general"
}
```

---

### 2. 入力画面（SixPersonInputView）

```swift
struct SixPersonInputView: View {
    let userId: String
    let characterId: String

    @State private var concernText: String = ""
    @State private var selectedCategory: ConcernCategory?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var fontSettings: FontSettingsManager
    @StateObject private var colorSettings = ColorSettingsManager.shared

    var body: some View {
        ZStack {
            colorSettings.getCurrentBackgroundGradient()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー
                    VStack(spacing: 8) {
                        Text("💭")
                            .font(.system(size: 60))

                        Text("6人の自分に相談")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(colorSettings.getCurrentTextColor())

                        Text("あなたの性格データから、\n6つの視点でアドバイスします")
                            .font(.body)
                            .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)

                    // 悩み入力
                    VStack(alignment: .leading, spacing: 12) {
                        Text("今、何について悩んでる？")
                            .font(.headline)
                            .foregroundColor(colorSettings.getCurrentTextColor())

                        TextEditor(text: $concernText)
                            .frame(height: 120)
                            .padding(12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                            )

                        Text("例: 転職すべきか迷ってる、告白すべきか悩んでる")
                            .font(.caption)
                            .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.6))
                    }
                    .padding(.horizontal)

                    // カテゴリ選択
                    VStack(alignment: .leading, spacing: 12) {
                        Text("または、カテゴリから選ぶ:")
                            .font(.headline)
                            .foregroundColor(colorSettings.getCurrentTextColor())

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(ConcernCategory.allCases, id: \.self) { category in
                                CategoryButton(
                                    category: category,
                                    isSelected: selectedCategory == category,
                                    action: {
                                        selectedCategory = category
                                        concernText = category.placeholder
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)

                    // 相談ボタン
                    Button(action: {
                        startMeeting()
                    }) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                            Text("6人会議を開く")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            concernText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                            Color.gray : colorSettings.getCurrentAccentColor()
                        )
                        .cornerRadius(16)
                    }
                    .disabled(concernText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal)

                    Spacer()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
    }

    func startMeeting() {
        // SixPersonMeetingViewへ遷移
        // NavigationStackで実装
    }
}

enum ConcernCategory: String, CaseIterable {
    case career = "💼 仕事・キャリア"
    case romance = "💕 恋愛・人間関係"
    case decision = "🎯 人生の決断"
    case stress = "😰 不安・悩み"
    case selfUnderstanding = "💡 自己理解"

    var placeholder: String {
        switch self {
        case .career: return "転職すべきか迷っている"
        case .romance: return "告白すべきか悩んでいる"
        case .decision: return "大きな決断を迫られている"
        case .stress: return "最近不安で仕方がない"
        case .selfUnderstanding: return "自分のことをもっと知りたい"
        }
    }
}
```

---

### 3. 6人会議画面（SixPersonMeetingView）

#### 画面構成

```
┌─────────────────────────────────┐
│ ← 💭 6人会議                     │
├─────────────────────────────────┤
│                                 │
│  [Phase 1: キャラクター紹介]     │
│  または                          │
│  [Phase 2: 検索中アニメーション]  │
│  または                          │
│  [Phase 3: 会話表示]             │
│  または                          │
│  [Phase 4: 統合レポート]         │
│                                 │
└─────────────────────────────────┘
```

#### 実装

```swift
struct SixPersonMeetingView: View {
    let userId: String
    let characterId: String
    let concern: String
    let userBIG5: Big5Scores

    @State private var phase: MeetingPhase = .introduction
    @State private var meeting: SixPersonMeeting?
    @State private var displayedMessages: [SixPersonMeeting.Message] = []
    @State private var currentMessageIndex = 0

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var fontSettings: FontSettingsManager
    @StateObject private var colorSettings = ColorSettingsManager.shared
    @StateObject private var meetingService = SixPersonMeetingService()

    enum MeetingPhase {
        case introduction    // キャラクター紹介
        case searching       // 検索中
        case conversation    // 会話表示
        case conclusion      // 統合レポート
    }

    var body: some View {
        ZStack {
            colorSettings.getCurrentBackgroundGradient()
                .ignoresSafeArea()

            switch phase {
            case .introduction:
                CharacterIntroductionView(
                    onStart: {
                        phase = .searching
                        startMeeting()
                    }
                )

            case .searching:
                SearchingAnimationView()

            case .conversation:
                ConversationView(
                    messages: displayedMessages,
                    onSkip: {
                        phase = .conclusion
                    }
                )

            case .conclusion:
                if let meeting = meeting {
                    ConclusionView(
                        meeting: meeting,
                        onDismiss: { dismiss() }
                    )
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("6人会議")
                        .font(.headline)
                    Text(concern.prefix(20) + "...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    func startMeeting() {
        Task {
            do {
                let result = await meetingService.generateMeeting(
                    userId: userId,
                    characterId: characterId,
                    concern: concern,
                    userBIG5: userBIG5
                )

                await MainActor.run {
                    self.meeting = result
                    phase = .conversation
                    startConversationAnimation()
                }
            } catch {
                // エラーハンドリング
            }
        }
    }

    func startConversationAnimation() {
        guard let meeting = meeting else { return }

        let allMessages = meeting.conversation.rounds.flatMap { $0.messages }

        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            if currentMessageIndex < allMessages.count {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    displayedMessages.append(allMessages[currentMessageIndex])
                    currentMessageIndex += 1
                }
            } else {
                timer.invalidate()
                // 全メッセージ表示完了後、自動で結論へ
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        phase = .conclusion
                    }
                }
            }
        }
    }
}
```

---

### 4. キャラクター紹介（CharacterIntroductionView）

```swift
struct CharacterIntroductionView: View {
    let onStart: () -> Void

    @EnvironmentObject var fontSettings: FontSettingsManager
    @StateObject private var colorSettings = ColorSettingsManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("参加メンバー紹介")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(colorSettings.getCurrentTextColor())
                    .padding(.top, 20)

                ForEach(PersonalityVariant.allCases, id: \.self) { variant in
                    CharacterCard(variant: variant)
                }

                Button(action: onStart) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("会議を始める")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(colorSettings.getCurrentAccentColor())
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
}

struct CharacterCard: View {
    let variant: PersonalityVariant

    @StateObject private var colorSettings = ColorSettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(variant.icon)
                    .font(.largeTitle)

                VStack(alignment: .leading, spacing: 4) {
                    Text(variant.name)
                        .font(.headline)
                        .foregroundColor(colorSettings.getCurrentTextColor())

                    Text(getTagline(variant))
                        .font(.subheadline)
                        .foregroundColor(colorSettings.getCurrentAccentColor())
                }

                Spacer()
            }

            Text(variant.description)
                .font(.body)
                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    func getTagline(_ variant: PersonalityVariant) -> String {
        switch variant {
        case .original: return "慎重派の分析家"
        case .opposite: return "自由奔放な冒険家"
        case .ideal: return "冷静な完璧主義者"
        case .shadow: return "率直な現実主義者"
        case .child: return "純粋な夢見る少年/少女"
        case .wise: return "達観した人生の先輩"
        }
    }
}
```

---

### 5. 検索中アニメーション（SearchingAnimationView）

```swift
struct SearchingAnimationView: View {
    @State private var progress: [PersonalityVariant: Bool] = [:]
    @StateObject private var colorSettings = ColorSettingsManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Text("🔍")
                .font(.system(size: 60))

            Text("6人が調査中...")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(colorSettings.getCurrentTextColor())

            VStack(alignment: .leading, spacing: 16) {
                ForEach(PersonalityVariant.allCases, id: \.self) { variant in
                    HStack {
                        Text(variant.icon)
                        Text(variant.name)
                            .foregroundColor(colorSettings.getCurrentTextColor())

                        Spacer()

                        if progress[variant] == true {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            ProgressView()
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            animateProgress()
        }
    }

    func animateProgress() {
        for (index, variant) in PersonalityVariant.allCases.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                withAnimation {
                    progress[variant] = true
                }
            }
        }
    }
}
```

---

### 6. 会話表示（ConversationView）

```swift
struct ConversationView: View {
    let messages: [SixPersonMeeting.Message]
    let onSkip: () -> Void

    @EnvironmentObject var fontSettings: FontSettingsManager
    @StateObject private var colorSettings = ColorSettingsManager.shared

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // スキップボタン
            Button(action: onSkip) {
                HStack {
                    Image(systemName: "forward.fill")
                    Text("結論へスキップ")
                }
                .font(.subheadline)
                .foregroundColor(colorSettings.getCurrentAccentColor())
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.2))
                .cornerRadius(20)
            }
            .padding(.bottom)
        }
    }
}

struct MessageBubbleView: View {
    let message: SixPersonMeeting.Message

    @StateObject private var colorSettings = ColorSettingsManager.shared

    var variant: PersonalityVariant {
        PersonalityVariant(rawValue: message.speaker) ?? .original
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isLeft {
                // 左側（慎重派）
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(variant.icon)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(variant.name)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(colorSettings.getCurrentTextColor())
                        }
                    }

                    Text(message.text)
                        .padding(12)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(16)
                        .foregroundColor(colorSettings.getCurrentTextColor())

                    Text(message.emotion)
                        .font(.title3)
                }
                Spacer()

            } else {
                // 右側（行動派）
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(variant.name)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(colorSettings.getCurrentTextColor())
                        }
                        Text(variant.icon)
                            .font(.title2)
                    }

                    Text(message.text)
                        .padding(12)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(16)
                        .foregroundColor(colorSettings.getCurrentTextColor())

                    Text(message.emotion)
                        .font(.title3)
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: message.isLeft ? .leading : .trailing)
                .combined(with: .opacity),
            removal: .opacity
        ))
    }
}
```

---

### 7. 統合レポート（ConclusionView）

画面設計は長くなるため、別ドキュメントまたはコメントで詳細化。
基本構成：
- 結論サマリー
- 推奨アクション（3つ程度）
- 6人の投票結果
- アクションボタン（TODO追加、予定追加、メモ保存）

---

## 🎨 デザインガイドライン

### カラー
- 既存のColorSettingsManagerを活用
- 左側メッセージ: blue.opacity(0.2)
- 右側メッセージ: orange.opacity(0.2)

### フォント
- 既存のDynamicFontSystemを活用
- .dynamicBody(), .dynamicTitle()等を使用

### アニメーション
- spring(response: 0.6, dampingFraction: 0.8)
- メッセージ表示間隔: 1.5秒

---

次のステップ: API設計 (`05_api-design.md`)
