import SwiftUI

struct NoteView: View {
    let userId: String

    @StateObject private var colorSettings = ColorSettingsManager.shared
    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @EnvironmentObject var fontSettings: FontSettingsManager
    @State private var selectedSegment: NoteSegment = .memo
    @State private var showAddMemo: Bool = false
    @State private var showAddTodo: Bool = false
    @State private var selectedMemo: Memo?
    @State private var selectedTodo: TodoItem?

    enum NoteSegment: String, CaseIterable {
        case memo = "メモ"
        case todo = "タスク"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // セグメントコントロール
                    Picker("表示切り替え", selection: $selectedSegment) {
                        ForEach(NoteSegment.allCases, id: \.self) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    // 選択されたビューを表示
                    switch selectedSegment {
                    case .memo:
                        MemoContentView(
                            userId: userId,
                            selectedMemo: $selectedMemo
                        )
                        .environmentObject(fontSettings)
                    case .todo:
                        TodoContentView(
                            userId: userId,
                            selectedTodo: $selectedTodo
                        )
                        .environmentObject(fontSettings)
                    }
                }
            }
            .navigationTitle("ノート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if selectedSegment == .memo {
                            showAddMemo = true
                        } else {
                            showAddTodo = true
                        }
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
            .sheet(isPresented: $showAddTodo) {
                TodoDetailView(userId: userId, todo: nil, onSave: {
                    firestoreManager.fetchTodos(userId: userId)
                })
                .environmentObject(fontSettings)
            }
            .sheet(item: $selectedTodo) { todo in
                TodoDetailView(userId: userId, todo: todo, onSave: {
                    firestoreManager.fetchTodos(userId: userId)
                })
                .environmentObject(fontSettings)
            }
            .onAppear {
                // サブスクリプション監視開始
                subscriptionManager.startMonitoring()

                firestoreManager.fetchMemos(userId: userId)
                firestoreManager.fetchTodos(userId: userId)

                // メモの通知監視
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

                // TODOの通知監視
                NotificationCenter.default.addObserver(
                    forName: .init("TodoAdded"),
                    object: nil,
                    queue: .main
                ) { _ in
                    firestoreManager.fetchTodos(userId: userId)
                }

                NotificationCenter.default.addObserver(
                    forName: .init("TodoUpdated"),
                    object: nil,
                    queue: .main
                ) { _ in
                    firestoreManager.fetchTodos(userId: userId)
                }
            }
            .onDisappear {
                // サブスクリプション監視停止
                subscriptionManager.stopMonitoring()
            }
        }
    }
}

// メモ表示用コンテンツビュー
struct MemoContentView: View {
    let userId: String
    @Binding var selectedMemo: Memo?

    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var colorSettings = ColorSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @EnvironmentObject var fontSettings: FontSettingsManager

    @State private var searchText: String = ""
    @State private var selectedTag: String = "すべて"
    @State private var memoToDelete: Memo?
    @State private var showDeleteAlert: Bool = false

    private var filteredMemos: [Memo] {
        var memos = firestoreManager.memos

        if !searchText.isEmpty {
            memos = memos.filter { memo in
                memo.title.localizedCaseInsensitiveContains(searchText) ||
                memo.content.localizedCaseInsensitiveContains(searchText)
            }
        }

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
        VStack(spacing: 0) {
            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("メモを検索", text: $searchText)
                    .dynamicBody()

                // クリアボタン（常に表示、テキストがない時は無効化）
                Button(action: {
                    searchText = ""
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
                        // 上部バナー広告（無料ユーザーのみ）
                        if subscriptionManager.shouldDisplayBannerAd() {
                            BannerAdView(adUnitID: Config.memoTopBannerAdUnitID)
                                .frame(height: 50)
                                .background(Color.clear)
                                .onAppear {
                                    subscriptionManager.trackBannerAdImpression()
                                }
                                .padding(.bottom, 8)
                        }

                        ForEach(filteredMemos) { memo in
                            Button(action: {
                                selectedMemo = memo
                            }) {
                                MemoCardView(memo: memo)
                                    .environmentObject(fontSettings)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    memoToDelete = memo
                                    showDeleteAlert = true
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }

                        // 下部バナー広告（無料ユーザーのみ）
                        if subscriptionManager.shouldDisplayBannerAd() {
                            BannerAdView(adUnitID: Config.memoBottomBannerAdUnitID)
                                .frame(height: 50)
                                .background(Color.clear)
                                .onAppear {
                                    subscriptionManager.trackBannerAdImpression()
                                }
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                }
            }
        }
        .alert("メモを削除", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {
                memoToDelete = nil
            }
            Button("削除", role: .destructive) {
                if let memo = memoToDelete {
                    deleteMemo(memo)
                }
            }
        } message: {
            Text("このメモを削除してもよろしいですか？")
        }
    }

    private func deleteMemo(_ memo: Memo) {
        firestoreManager.deleteMemo(memoId: memo.id, userId: userId) { success in
            if success {
                firestoreManager.fetchMemos(userId: userId)
                memoToDelete = nil
            }
        }
    }
}

// TODO表示用コンテンツビュー
struct TodoContentView: View {
    let userId: String
    @Binding var selectedTodo: TodoItem?

    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var colorSettings = ColorSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @EnvironmentObject var fontSettings: FontSettingsManager

    @State private var selectedFilter: TodoFilter = .all
    @State private var selectedTag: String = "すべて"
    @State private var todoToDelete: TodoItem?
    @State private var showDeleteAlert: Bool = false

    enum TodoFilter: String, CaseIterable {
        case all = "すべて"
        case incomplete = "未完了"
        case completed = "完了済み"
    }

    private var filteredTodos: [TodoItem] {
        var todos = firestoreManager.todos

        // 完了状態でフィルター
        switch selectedFilter {
        case .all:
            break
        case .incomplete:
            todos = todos.filter { !$0.isCompleted }
        case .completed:
            todos = todos.filter { $0.isCompleted }
        }

        // タグでフィルター
        if selectedTag != "すべて" {
            todos = todos.filter { $0.tag == selectedTag }
        }

        return todos
    }

    private var availableTags: [String] {
        let tags = Set(firestoreManager.todos.map { $0.tag }.filter { !$0.isEmpty })
        return ["すべて"] + tags.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // セグメントコントロール
            Picker("フィルター", selection: $selectedFilter) {
                ForEach(TodoFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
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

            // TODO統計
            HStack(spacing: 16) {
                StatCard(
                    title: "未完了",
                    count: firestoreManager.todos.filter { !$0.isCompleted }.count,
                    color: .blue
                )
                .environmentObject(fontSettings)

                StatCard(
                    title: "期限切れ",
                    count: firestoreManager.todos.filter { $0.isOverdue }.count,
                    color: .red
                )
                .environmentObject(fontSettings)

                StatCard(
                    title: "完了",
                    count: firestoreManager.todos.filter { $0.isCompleted }.count,
                    color: .green
                )
                .environmentObject(fontSettings)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // TODO一覧
            if filteredTodos.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "checklist")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("タスクがありません")
                        .dynamicTitle3()
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // 上部バナー広告（無料ユーザーのみ）
                        if subscriptionManager.shouldDisplayBannerAd() {
                            BannerAdView(adUnitID: Config.taskTopBannerAdUnitID)
                                .frame(height: 50)
                                .background(Color.clear)
                                .onAppear {
                                    subscriptionManager.trackBannerAdImpression()
                                }
                                .padding(.bottom, 8)
                        }

                        ForEach(filteredTodos) { todo in
                            Button(action: {
                                selectedTodo = todo
                            }) {
                                TodoRowView(todo: todo) { isCompleted in
                                    toggleComplete(todo: todo, isCompleted: isCompleted)
                                }
                                .environmentObject(fontSettings)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    todoToDelete = todo
                                    showDeleteAlert = true
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }

                        // 下部バナー広告（無料ユーザーのみ）
                        if subscriptionManager.shouldDisplayBannerAd() {
                            BannerAdView(adUnitID: Config.taskBottomBannerAdUnitID)
                                .frame(height: 50)
                                .background(Color.clear)
                                .onAppear {
                                    subscriptionManager.trackBannerAdImpression()
                                }
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                }
            }
        }
        .alert("タスクを削除", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) {
                todoToDelete = nil
            }
            Button("削除", role: .destructive) {
                if let todo = todoToDelete {
                    deleteTodo(todo)
                }
            }
        } message: {
            Text("このタスクを削除してもよろしいですか？")
        }
    }

    private func deleteTodo(_ todo: TodoItem) {
        firestoreManager.deleteTodo(todoId: todo.id, userId: userId) { success in
            if success {
                firestoreManager.fetchTodos(userId: userId)
                todoToDelete = nil
            }
        }
    }

    private func toggleComplete(todo: TodoItem, isCompleted: Bool) {
        firestoreManager.toggleTodoComplete(todoId: todo.id, userId: userId, isCompleted: isCompleted) { success in
            if success {
                firestoreManager.fetchTodos(userId: userId)
            }
        }
    }
}
