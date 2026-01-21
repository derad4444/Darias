import SwiftUI
import FirebaseFirestore

struct DiaryHistoryView: View {
    let userId: String
    let characterId: String

    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var diaries: [DiaryEntry] = []
    @State private var isLoading = true
    @State private var searchText: String = ""
    @State private var selectedDiaryId: String? = nil
    @State private var showDiaryDetail = false

    // 検索フィルタリング
    private var filteredDiaries: [DiaryEntry] {
        if searchText.isEmpty {
            return diaries
        }
        return diaries.filter { diary in
            diary.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("日記を検索", text: $searchText)
                    .dynamicBody()

                Button(action: {
                    withAnimation {
                        searchText = ""
                    }
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

            // 日記一覧
            if isLoading {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                    Text("読み込み中...")
                        .dynamicBody()
                }
                Spacer()
            } else if diaries.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("日記がありません")
                            .dynamicBody()
                            .foregroundColor(.gray)
                    }
                    Spacer()

                    // バナー広告
                    if subscriptionManager.shouldDisplayBannerAd() {
                        bannerAdSection
                    }
                }
            } else if filteredDiaries.isEmpty {
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("検索結果がありません")
                            .dynamicBody()
                            .foregroundColor(.gray)
                        Text("「\(searchText)」に一致する日記が見つかりませんでした")
                            .dynamicCaption()
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    Spacer()

                    if subscriptionManager.shouldDisplayBannerAd() {
                        bannerAdSection
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredDiaries) { diary in
                            DiaryCardView(diary: diary)
                                .onTapGesture {
                                    selectedDiaryId = diary.id
                                    showDiaryDetail = true
                                }
                        }

                        // バナー広告
                        if subscriptionManager.shouldDisplayBannerAd() {
                            VStack(spacing: 16) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 1)
                                    .padding(.horizontal, 32)

                                BannerAdView(adUnitID: Config.chatHistoryBannerAdUnitID)
                                    .frame(height: 50)
                                    .background(Color.clear)
                                    .onAppear {
                                        subscriptionManager.trackBannerAdImpression()
                                    }
                                    .padding(.horizontal, 16)

                                Spacer()
                                    .frame(height: 20)
                            }
                            .padding(.top, 16)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("日記履歴")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // taskはビューが表示される時に確実に実行される
            await fetchDiariesAsync()
            subscriptionManager.startMonitoring()
            NotificationManager.shared.clearBadge()
        }
        .onDisappear {
            subscriptionManager.stopMonitoring()
        }
        .sheet(isPresented: $showDiaryDetail) {
            if let diaryId = selectedDiaryId {
                NavigationStack {
                    DiaryDetailView(
                        diaryId: diaryId,
                        characterId: characterId,
                        userId: userId
                    )
                }
            }
        }
    }

    private var bannerAdSection: some View {
        VStack(spacing: 16) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 32)

            BannerAdView(adUnitID: Config.chatHistoryBannerAdUnitID)
                .frame(height: 50)
                .background(Color.clear)
                .onAppear {
                    subscriptionManager.trackBannerAdImpression()
                }
                .padding(.horizontal, 16)

            Spacer()
                .frame(height: 20)
        }
    }

    @MainActor
    private func fetchDiariesAsync() async {
        let db = Firestore.firestore()

        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("characters").document(characterId)
                .collection("diary")
                .order(by: "date", descending: true)
                .getDocuments()

            diaries = snapshot.documents.compactMap { doc -> DiaryEntry? in
                let data = doc.data()
                guard let timestamp = data["date"] as? Timestamp else { return nil }

                return DiaryEntry(
                    id: doc.documentID,
                    content: data["content"] as? String ?? "",
                    date: timestamp.dateValue(),
                    userComment: data["user_comment"] as? String
                )
            }
        } catch {
            print("❌ 日記取得エラー: \(error.localizedDescription)")
        }

        isLoading = false
    }
}

// 日記エントリモデル
struct DiaryEntry: Identifiable {
    let id: String
    let content: String
    let date: Date
    let userComment: String?
}

// 日記カードビュー
struct DiaryCardView: View {
    let diary: DiaryEntry
    @ObservedObject var colorSettings = ColorSettingsManager.shared

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }

    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 日付ヘッダー
            HStack {
                Image(systemName: "book.closed")
                    .foregroundColor(.brown.opacity(0.7))

                Text(dateFormatter.string(from: diary.date))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.brown)

                Text("(\(weekdayFormatter.string(from: diary.date)))")
                    .font(.system(size: 12))
                    .foregroundColor(.brown.opacity(0.7))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            // 日記の内容プレビュー
            Text(diary.content)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(.black.opacity(0.8))
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // コメントがある場合は表示
            if let comment = diary.userComment, !comment.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 10))
                        .foregroundColor(colorSettings.getCurrentAccentColor().opacity(0.7))
                    Text("コメントあり")
                        .font(.system(size: 11))
                        .foregroundColor(colorSettings.getCurrentAccentColor().opacity(0.7))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
    }
}

#Preview {
    DiaryHistoryView(
        userId: "test_user",
        characterId: "test_character"
    )
}
