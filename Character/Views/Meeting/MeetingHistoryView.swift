// Character/Views/Meeting/MeetingHistoryView.swift

import SwiftUI

struct MeetingHistoryView: View {
    @StateObject private var viewModel: MeetingHistoryViewModel
    @State private var loadingMessage: String = "読み込み中..."
    @State private var searchText: String = ""

    // 共有インスタンスは直接参照
    private let colorSettings = ColorSettingsManager.shared

    init(userId: String, characterId: String) {
        _viewModel = StateObject(wrappedValue: MeetingHistoryViewModel(
            userId: userId,
            characterId: characterId
        ))
    }

    // 検索フィルタリング
    private var filteredHistories: [MeetingHistory] {
        if searchText.isEmpty {
            return viewModel.histories
        }
        return viewModel.histories.filter { history in
            history.userConcern.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("会議内容を検索", text: $searchText)
                    .font(.body)

                // クリアボタン
                Button(action: {
                    withAnimation {
                        searchText = ""
                    }
                    // キーボードを閉じる
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(searchText.isEmpty ? .gray.opacity(0.3) : .gray.opacity(0.6))
                }
                .disabled(searchText.isEmpty)
            }
            .padding(12)
            .background(Color.white.opacity(0.8))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // コンテンツ
            if viewModel.isLoading {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                    Text(loadingMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if viewModel.histories.isEmpty {
                emptyStateView
            } else if filteredHistories.isEmpty {
                // 検索結果が空の場合
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("検索結果がありません")
                        .font(.body)
                        .foregroundColor(.gray)
                    Text("「\(searchText)」に一致する会議が見つかりませんでした")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Spacer()
            } else {
                historyListView
            }
        }
        .navigationTitle("会議履歴")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            print("🔄 MeetingHistoryView: Refreshing...")
            await viewModel.loadHistories()
        }
        .task {
            print("📋 MeetingHistoryView: Starting to load histories...")
            await viewModel.loadHistories()
            print("✅ MeetingHistoryView: Finished loading histories")
        }
        .onAppear {
            print("👀 MeetingHistoryView: View appeared")
        }
        .onDisappear {
            print("👋 MeetingHistoryView: View disappeared")
        }
        .alert("エラー", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("会議履歴がありません")
                    .font(.headline)

                Text("「自分会議」ボタンから\n最初の会議を始めてみましょう")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    // MARK: - History List

    private var historyListView: some View {
        List {
            ForEach(filteredHistories) { history in
                NavigationLink {
                    // 遅延評価: タップされるまでビューを初期化しない
                    MeetingDetailView(
                        history: history,
                        userId: viewModel.userId,
                        characterId: viewModel.characterId
                    )
                } label: {
                    HistoryRow(history: history)
                }
                .listRowBackground(Color.white.opacity(0.7))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - History Row

struct HistoryRow: View {
    let history: MeetingHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // カテゴリアイコンとバッジ
                if let category = ConcernCategory(rawValue: history.concernCategory) {
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.caption)
                        Text(category.displayName)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }

                Spacer()

                // キャッシュヒットバッジ
                if history.cacheHit {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption2)
                        Text("再利用")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(6)
                }
            }

            Text(history.userConcern)
                .font(.body)
                .lineLimit(2)
                .foregroundColor(.primary)

            Text(formatDate(history.createdAt))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - View Model

@MainActor
class MeetingHistoryViewModel: ObservableObject {
    let userId: String
    let characterId: String

    @Published var histories: [MeetingHistory] = []
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    private let meetingService = SixPersonMeetingService.shared

    init(userId: String, characterId: String) {
        self.userId = userId
        self.characterId = characterId
    }

    func loadHistories() async {
        print("🔍 ViewModel: Starting loadHistories()")
        isLoading = true

        do {
            print("📡 ViewModel: Fetching from Firestore...")

            // タイムアウト付きでフェッチ（15秒）
            histories = try await withTimeout(seconds: 15) {
                try await self.meetingService.fetchMeetingHistory(
                    userId: self.userId,
                    characterId: self.characterId,
                    limit: 10  // さらに軽量化 20 -> 10
                )
            }

            print("✅ ViewModel: Got \(histories.count) histories")
            isLoading = false
        } catch is TimeoutError {
            print("⏱️ ViewModel: Request timed out after 15 seconds")
            isLoading = false
            errorMessage = "読み込みがタイムアウトしました。ネットワーク接続を確認して、もう一度お試しください。"
            showError = true
        } catch {
            print("❌ ViewModel: Error loading histories - \(error)")
            isLoading = false
            errorMessage = "履歴の読み込みに失敗しました: \(error.localizedDescription)"
            showError = true
        }
    }

    // タイムアウト処理のヘルパー
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // 実際の処理
            group.addTask {
                try await operation()
            }

            // タイムアウト監視
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            // 最初に完了した結果を返す
            guard let result = try await group.next() else {
                throw TimeoutError()
            }

            // 残りのタスクをキャンセル
            group.cancelAll()

            return result
        }
    }
}

// タイムアウトエラー
struct TimeoutError: LocalizedError {
    var errorDescription: String? {
        "処理がタイムアウトしました"
    }
}

// MARK: - Meeting Detail View

struct MeetingDetailView: View {
    let history: MeetingHistory
    let userId: String
    let characterId: String

    // 共有インスタンスは直接参照（@StateObjectは不要）
    private let meetingService = SixPersonMeetingService.shared
    private let colorSettings = ColorSettingsManager.shared

    @State private var meeting: SixPersonMeeting?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // 背景
            colorSettings.getCurrentBackgroundGradient()
                .ignoresSafeArea()

            Group {
            if isLoading {
                ProgressView("会議データを読み込み中...")
            } else if let meeting = meeting {
                // 会議の詳細を表示
                meetingDetailContent(meeting: meeting)
            } else {
                errorView
            }
            }
        }
        .navigationTitle("会議の詳細")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMeetingDetail()
        }
    }

    private func meetingDetailContent(meeting: SixPersonMeeting) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 悩み
                VStack(alignment: .leading, spacing: 8) {
                    Text("相談内容")
                        .font(.headline)

                    Text(history.userConcern)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }

                // 統計データ
                VStack(alignment: .leading, spacing: 8) {
                    Text("参考データ")
                        .font(.headline)

                    Text(meeting.statsData.displayText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // 会話
                VStack(alignment: .leading, spacing: 12) {
                    Text("会議の内容")
                        .font(.headline)

                    ForEach(meeting.conversation.rounds) { round in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ラウンド \(round.roundNumber)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ForEach(round.messages) { message in
                                CompactMessageBubble(message: message)
                            }
                        }
                    }
                }

                Divider()

                // 結論
                conclusionSection(meeting.conversation.conclusion)
            }
            .padding()
        }
    }

    private func conclusionSection(_ conclusion: MeetingConclusion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // サマリー
            VStack(alignment: .leading, spacing: 8) {
                Text("結論")
                    .font(.headline)

                Text(conclusion.summary)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
            }

            // レコメンデーション
            VStack(alignment: .leading, spacing: 8) {
                Text("アドバイス")
                    .font(.headline)

                ForEach(Array(conclusion.recommendations.enumerated()), id: \.offset) { index, rec in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .foregroundColor(.orange)

                        Text(rec)
                            .font(.subheadline)
                    }
                }
            }

            // 次のステップ
            VStack(alignment: .leading, spacing: 8) {
                Text("次のステップ")
                    .font(.headline)

                ForEach(Array(conclusion.nextSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "\(index + 1).circle.fill")
                            .foregroundColor(.blue)

                        Text(step)
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text(errorMessage ?? "会議データの読み込みに失敗しました")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func loadMeetingDetail() async {
        do {
            meeting = try await meetingService.fetchMeetingById(meetingId: history.sharedMeetingId)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Compact Message Bubble

struct CompactMessageBubble: View {
    let message: ConversationMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: message.characterIcon)
                .font(.caption)
                .foregroundColor(characterColor(message.characterColor))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.characterName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(message.text)
                    .font(.subheadline)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
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

// MARK: - Preview

#Preview {
    MeetingHistoryView(
        userId: "test_user",
        characterId: "test_character"
    )
}
