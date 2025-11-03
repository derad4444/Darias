import SwiftUI
import FirebaseAuth

struct MemoListView: View {
    let userId: String

    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var colorSettings = ColorSettingsManager.shared
    @EnvironmentObject var fontSettings: FontSettingsManager

    @State private var searchText: String = ""
    @State private var selectedTag: String = "すべて"
    @State private var showAddMemo: Bool = false
    @State private var selectedMemo: Memo?

    private var filteredMemos: [Memo] {
        var memos = firestoreManager.memos

        // 検索フィルター
        if !searchText.isEmpty {
            memos = memos.filter { memo in
                memo.title.localizedCaseInsensitiveContains(searchText) ||
                memo.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        // タグフィルター
        if selectedTag != "すべて" {
            memos = memos.filter { $0.tag == selectedTag }
        }

        return memos
    }

    private var availableTags: [String] {
        let tags = Set(firestoreManager.memos.map { $0.tag }.filter { !$0.isEmpty })
        return ["すべて"] + tags.sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 検索バー
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("メモを検索", text: $searchText)
                            .dynamicBody()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // タグフィルター
                    if availableTags.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(availableTags, id: \.self) { tag in
                                    Button(action: {
                                        selectedTag = tag
                                    }) {
                                        Text(tag)
                                            .dynamicCallout()
                                            .foregroundColor(selectedTag == tag ? .white : colorSettings.getCurrentAccentColor())
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedTag == tag ? colorSettings.getCurrentAccentColor() : Color.white.opacity(0.8))
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 8)
                    }

                    // メモ一覧
                    if filteredMemos.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "note.text")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("メモがありません")
                                .dynamicTitle3()
                                .foregroundColor(.gray)
                            if !searchText.isEmpty {
                                Text("検索条件に一致するメモが見つかりませんでした")
                                    .dynamicBody()
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredMemos) { memo in
                                    Button(action: {
                                        selectedMemo = memo
                                    }) {
                                        MemoCardView(memo: memo)
                                            .environmentObject(fontSettings)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 80)
                        }
                    }
                }
            }
            .navigationTitle("メモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddMemo = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(colorSettings.getCurrentAccentColor())
                    }
                }
            }
            .sheet(isPresented: $showAddMemo) {
                MemoDetailView(userId: userId, memo: nil, onSave: {
                    firestoreManager.fetchMemos(userId: userId)
                })
                .environmentObject(fontSettings)
            }
            .sheet(item: $selectedMemo) { memo in
                MemoDetailView(userId: userId, memo: memo, onSave: {
                    firestoreManager.fetchMemos(userId: userId)
                })
                .environmentObject(fontSettings)
            }
            .onAppear {
                firestoreManager.fetchMemos(userId: userId)

                // 通知監視
                NotificationCenter.default.addObserver(
                    forName: .init("MemoAdded"),
                    object: nil,
                    queue: .main
                ) { _ in
                    firestoreManager.fetchMemos(userId: userId)
                }

                NotificationCenter.default.addObserver(
                    forName: .init("MemoUpdated"),
                    object: nil,
                    queue: .main
                ) { _ in
                    firestoreManager.fetchMemos(userId: userId)
                }
            }
        }
    }
}
