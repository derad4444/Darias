import SwiftUI
import FirebaseAuth

struct TodoListView: View {
    let userId: String

    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var colorSettings = ColorSettingsManager.shared
    @EnvironmentObject var fontSettings: FontSettingsManager

    @State private var selectedFilter: TodoFilter = .all
    @State private var showAddTodo: Bool = false
    @State private var selectedTodo: TodoItem?

    enum TodoFilter: String, CaseIterable {
        case all = "すべて"
        case incomplete = "未完了"
        case completed = "完了済み"
    }

    private var filteredTodos: [TodoItem] {
        let todos = firestoreManager.todos

        switch selectedFilter {
        case .all:
            return todos
        case .incomplete:
            return todos.filter { !$0.isCompleted }
        case .completed:
            return todos.filter { $0.isCompleted }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea()

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

                    // TODO統計
                    HStack(spacing: 16) {
                        StatCard(
                            title: "未完了",
                            count: firestoreManager.todos.filter { !$0.isCompleted }.count,
                            color: .blue
                        )

                        StatCard(
                            title: "期限切れ",
                            count: firestoreManager.todos.filter { $0.isOverdue }.count,
                            color: .red
                        )

                        StatCard(
                            title: "完了",
                            count: firestoreManager.todos.filter { $0.isCompleted }.count,
                            color: .green
                        )
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
                            Text("TODOがありません")
                                .dynamicTitle3()
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
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
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 80)
                        }
                    }
                }
            }
            .navigationTitle("タスク")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddTodo = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(colorSettings.getCurrentAccentColor())
                    }
                }
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
                firestoreManager.fetchTodos(userId: userId)

                // 通知監視
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

// 統計カード
struct StatCard: View {
    let title: String
    let count: Int
    let color: Color

    @EnvironmentObject var fontSettings: FontSettingsManager

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .dynamicTitle2()
                .foregroundColor(color)

            Text(title)
                .dynamicCaption()
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.8))
        .cornerRadius(10)
    }
}
