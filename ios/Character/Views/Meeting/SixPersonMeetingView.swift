// Character/Views/Meeting/SixPersonMeetingView.swift

import SwiftUI

struct SixPersonMeetingView: View {
    @Environment(\.dismiss) private var dismiss

    // 共有インスタンスは直接参照
    private let colorSettings = ColorSettingsManager.shared

    let meetingResponse: GenerateMeetingResponse
    let concernText: String

    @State private var displayedMessages: [ConversationMessage] = []
    @State private var currentRoundIndex: Int = 0
    @State private var currentMessageIndex: Int = 0
    @State private var showConclusion: Bool = false
    @State private var isAnimating: Bool = true
    @State private var userRating: Int = 0
    @State private var showRatingDialog: Bool = false
    @State private var showCharacterExplanation: Bool = false
    @State private var shouldAutoScroll: Bool = true
    @State private var animationTask: Task<Void, Never>?
    @State private var showShareSheet: Bool = false

    private var allMessages: [ConversationMessage] {
        meetingResponse.conversation.rounds.flatMap { $0.messages }
    }

    var body: some View {
        ZStack {
            // 背景
            colorSettings.getCurrentBackgroundGradient()
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                // ヘッダー
                headerSection

                Divider()

                // 会話表示（結論も含めて縦スクロール）
                conversationSection(proxy: proxy)

                Divider()

                // フッター
                footerSection
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showCharacterExplanation = true
                }) {
                    Image(systemName: "questionmark.circle")
                        .font(.title3)
                }
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            animationTask?.cancel()
        }
        .sheet(isPresented: $showRatingDialog) {
            RatingView(
                meetingId: meetingResponse.meetingId,
                onRatingSubmitted: { rating in
                    userRating = rating
                }
            )
        }
        .sheet(isPresented: $showCharacterExplanation) {
            NavigationStack {
                CharacterExplanationView()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ShareHelper.shareMeetingConclusion(
                concern: concernText,
                conclusion: meetingResponse.conversation.conclusion.summary
            ))
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.blue)

                Text("自分会議")
                    .font(.headline)

                Spacer()

                if meetingResponse.cacheHit {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                        Text("再利用")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            Text(concernText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Text(meetingResponse.statsData.displayText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Conversation Section

    private func conversationSection(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // チャットメッセージ
                LazyVStack(spacing: 16) {
                    ForEach(displayedMessages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 会話が終わったら結論を表示
                if showConclusion {
                    Divider()
                        .padding(.vertical, 24)
                        .id("conclusion-divider")

                    conclusionContent
                        .id("conclusion")
                        .transition(.opacity)
                }

                // スクロールの末尾マーカー
                Color.clear
                    .frame(height: 1)
                    .id("bottom")
            }
            .padding()
            .onChange(of: displayedMessages.count) { _ in
                guard shouldAutoScroll, isAnimating else { return }
                // スクロールを次のレンダリングサイクルまで遅延
                Task { @MainActor in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: showConclusion) { isShowing in
                guard isShowing else { return }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    proxy.scrollTo("conclusion", anchor: .top)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Conclusion Content

    private var conclusionContent: some View {
        VStack(alignment: .leading, spacing: 24) {
                // サマリー
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("会議の結論")
                            .font(.headline)
                    }

                    Text(meetingResponse.conversation.conclusion.summary)
                        .font(.body)
                        .lineSpacing(6)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)

                // レコメンデーション
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        Text("アドバイス")
                            .font(.headline)
                    }

                    ForEach(Array(meetingResponse.conversation.conclusion.recommendations.enumerated()), id: \.offset) { index, recommendation in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.subheadline)
                                .foregroundColor(.orange)

                            Text(recommendation)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)

                // 次のステップ
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "flag.checkered")
                            .foregroundColor(.blue)
                        Text("次のステップ")
                            .font(.headline)
                    }

                    ForEach(Array(meetingResponse.conversation.conclusion.nextSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "\(index + 1).circle.fill")
                                .foregroundColor(.blue)

                            Text(step)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

                // 共有ボタン
                Button(action: {
                    showShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("会議結果を共有")
                    }
                    .font(.headline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }

                // 評価ボタン
                Button(action: { showRatingDialog = true }) {
                    HStack {
                        Image(systemName: userRating > 0 ? "star.fill" : "star")
                        Text(userRating > 0 ? "評価済み (\(userRating))" : "この会議を評価する")
                    }
                    .font(.headline)
                    .foregroundColor(userRating > 0 ? .yellow : .blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(userRating > 0 ? Color.yellow.opacity(0.15) : Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack(spacing: 16) {
            if !showConclusion && isAnimating {
                Button(action: skipToConclusion) {
                    HStack {
                        Image(systemName: "forward.fill")
                        Text("結論へ")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            Spacer()

            Button(action: { dismiss() }) {
                Text("完了")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Color.blue.opacity(0.85))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Animation

    private func startAnimation() {
        animationTask?.cancel()

        animationTask = Task { @MainActor in
            while isAnimating && currentMessageIndex < allMessages.count {
                let message = allMessages[currentMessageIndex]
                displayedMessages.append(message)
                currentMessageIndex += 1

                // メッセージの長さに応じて2.5〜5秒で表示
                let baseDelay: UInt64 = 2_500_000_000 // 2.5秒ベース
                let charCount = message.text.count
                let additionalDelay = UInt64(min(charCount, 150)) * 17_000_000 // 1文字あたり0.017秒、最大2.5秒追加
                let totalDelay = min(baseDelay + additionalDelay, 5_000_000_000) // 最大5秒

                try? await Task.sleep(nanoseconds: totalDelay)

                if Task.isCancelled { break }
            }

            // 全メッセージ表示完了後、結論を表示
            if currentMessageIndex >= allMessages.count {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒待機
                if !Task.isCancelled {
                    showConclusion = true
                }
            }
        }
    }

    private func skipToConclusion() {
        animationTask?.cancel()
        isAnimating = false
        displayedMessages = allMessages
        showConclusion = true
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ConversationMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.position == .right {
                Spacer(minLength: 50)
            }

            VStack(alignment: message.position == .left ? .leading : .trailing, spacing: 4) {
                // キャラクター名とアイコン
                HStack(spacing: 6) {
                    if message.position == .right {
                        Spacer()
                    }

                    Image(systemName: message.characterIcon)
                        .font(.caption)
                        .foregroundColor(characterColor(message.characterColor))

                    Text(message.characterName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if message.position == .left {
                        Spacer()
                    }
                }

                // メッセージバブル
                Text(message.text)
                    .font(.body)
                    .padding(12)
                    .background(
                        message.position == .left ?
                            Color(.systemGray5) :
                            characterColor(message.characterColor).opacity(0.2)
                    )
                    .foregroundColor(.primary)
                    .cornerRadius(16)
            }

            if message.position == .left {
                Spacer(minLength: 50)
            }
        }
    }

    private func characterColor(_ colorName: String) -> Color {
        switch colorName {
        case "blue": return .blue
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        case "green": return .green
        case "yellow": return .yellow
        default: return .gray
        }
    }
}

// MARK: - Rating View

struct RatingView: View {
    @Environment(\.dismiss) private var dismiss

    // 共有インスタンスは直接参照
    private let meetingService = SixPersonMeetingService.shared

    let meetingId: String
    let onRatingSubmitted: (Int) -> Void

    @State private var selectedRating: Int = 0
    @State private var isSubmitting: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("この会議を評価してください")
                    .font(.headline)

                HStack(spacing: 16) {
                    ForEach(1...5, id: \.self) { rating in
                        Button(action: { selectedRating = rating }) {
                            Image(systemName: rating <= selectedRating ? "star.fill" : "star")
                                .font(.system(size: 32))
                                .foregroundColor(rating <= selectedRating ? .yellow : .gray)
                        }
                    }
                }

                if isSubmitting {
                    ProgressView()
                } else {
                    Button(action: submitRating) {
                        Text("評価を送信")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedRating > 0 ? Color.blue.opacity(0.85) : Color.gray.opacity(0.5))
                            .cornerRadius(12)
                    }
                    .disabled(selectedRating == 0)
                }
            }
            .padding()
            .navigationTitle("評価")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
    }

    private func submitRating() {
        isSubmitting = true

        Task {
            do {
                try await meetingService.rateMeeting(meetingId: meetingId, rating: selectedRating)
                onRatingSubmitted(selectedRating)
                dismiss()
            } catch {
                isSubmitting = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SixPersonMeetingView(
            meetingResponse: GenerateMeetingResponse(
                success: true,
                meetingId: "test_meeting",
                conversation: MeetingConversation(
                    rounds: [
                        ConversationRound(
                            roundNumber: 1,
                            messages: [
                                ConversationMessage(
                                    characterId: "cautious",
                                    characterName: "慎重派の自分",
                                    text: "よく考えてから決めよう",
                                    timestamp: ""
                                )
                            ]
                        )
                    ],
                    conclusion: MeetingConclusion(
                        summary: "会議のまとめ",
                        recommendations: ["アドバイス1", "アドバイス2"],
                        nextSteps: ["ステップ1", "ステップ2"]
                    )
                ),
                statsData: MeetingStatsData(
                    similarCount: 127,
                    totalUsers: 1523,
                    avgAge: 30,
                    percentile: 15,
                    personalityKey: "O4_C4_E2_A4_N3_female"
                ),
                cacheHit: true,
                usageCount: 1,
                duration: 500
            ),
            concernText: "転職すべきか迷っています"
        )
    }
}
