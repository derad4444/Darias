import SwiftUI

struct TodoDetailView: View {
    let userId: String
    let todo: TodoItem?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var colorSettings = ColorSettingsManager.shared
    @StateObject private var tagSettingsManager = TagSettingsManager.shared
    @EnvironmentObject var fontSettings: FontSettingsManager

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var dueDate: Date = Date()
    @State private var hasDueDate: Bool = false
    @State private var priority: TodoItem.TodoPriority = .medium
    @State private var selectedTag: String = ""
    @State private var isCompleted: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var showTagSelection: Bool = false

    private var isNewTodo: Bool {
        todo == nil
    }

    // タグの色を取得（設定されていない場合はアクセントカラー）
    private var tagColor: Color {
        if !selectedTag.isEmpty, let tag = tagSettingsManager.getTag(by: selectedTag) {
            return tag.color
        }
        return colorSettings.getCurrentAccentColor()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // タイトル入力
                        VStack(alignment: .leading, spacing: 8) {
                            Text("タイトル")
                                .dynamicCallout()
                                .foregroundColor(.secondary)

                            TextField("タイトルを入力", text: $title)
                                .dynamicBody()
                                .padding(12)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(10)
                        }

                        // 説明入力
                        VStack(alignment: .leading, spacing: 8) {
                            Text("説明")
                                .dynamicCallout()
                                .foregroundColor(.secondary)

                            TextEditor(text: $description)
                                .frame(minHeight: 100)
                                .padding(12)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(10)
                        }

                        // 期限設定
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $hasDueDate) {
                                Text("期限を設定")
                                    .dynamicBody()
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)

                            if hasDueDate {
                                DatePicker(
                                    "期限",
                                    selection: $dueDate,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                                .padding(12)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(10)
                            }
                        }

                        // 優先度選択
                        VStack(alignment: .leading, spacing: 8) {
                            Text("優先度")
                                .dynamicCallout()
                                .foregroundColor(.secondary)

                            Picker("優先度", selection: $priority) {
                                ForEach(TodoItem.TodoPriority.allCases, id: \.self) { priority in
                                    Text(priority.displayName).tag(priority)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(12)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                        }

                        // タグ選択
                        VStack(alignment: .leading, spacing: 8) {
                            Text("タグ")
                                .dynamicCallout()
                                .foregroundColor(.secondary)

                            Button(action: {
                                showTagSelection = true
                            }) {
                                HStack {
                                    if selectedTag.isEmpty {
                                        Text("タグを選択")
                                            .dynamicBody()
                                            .foregroundColor(.gray)
                                    } else {
                                        Text(selectedTag)
                                            .dynamicBody()
                                            .foregroundColor(tagColor)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(tagColor.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(10)
                            }
                        }

                        // 完了状態（編集時のみ）
                        if !isNewTodo {
                            Toggle(isOn: $isCompleted) {
                                HStack {
                                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isCompleted ? .green : .gray)
                                    Text("完了")
                                        .dynamicBody()
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                        }

                        // 削除ボタン（編集時のみ）
                        if !isNewTodo {
                            Button(action: {
                                showDeleteAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("TODOを削除")
                                        .dynamicBody()
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(isNewTodo ? "新規TODO" : "TODO編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveTodo()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showTagSelection) {
                TagSelectionView(selectedTag: $selectedTag)
            }
            .alert("TODOを削除", isPresented: $showDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    deleteTodo()
                }
            } message: {
                Text("このTODOを削除してもよろしいですか？")
            }
            .onAppear {
                if let todo = todo {
                    title = todo.title
                    description = todo.description
                    if let dueDate = todo.dueDate {
                        self.dueDate = dueDate
                        self.hasDueDate = true
                    }
                    priority = todo.priority
                    selectedTag = todo.tag
                    isCompleted = todo.isCompleted
                }
            }
        }
    }

    private func saveTodo() {
        if isNewTodo {
            let newTodo = TodoItem(
                title: title,
                description: description,
                dueDate: hasDueDate ? dueDate : nil,
                priority: priority,
                tag: selectedTag
            )
            firestoreManager.addTodo(newTodo, userId: userId) { success in
                if success {
                    onSave()
                    dismiss()
                }
            }
        } else if let existingTodo = todo {
            var updatedTodo = existingTodo
            updatedTodo.title = title
            updatedTodo.description = description
            updatedTodo.dueDate = hasDueDate ? dueDate : nil
            updatedTodo.priority = priority
            updatedTodo.tag = selectedTag
            updatedTodo.isCompleted = isCompleted

            firestoreManager.updateTodo(updatedTodo, userId: userId) { success in
                if success {
                    onSave()
                    dismiss()
                }
            }
        }
    }

    private func deleteTodo() {
        guard let todo = todo else { return }

        firestoreManager.deleteTodo(todoId: todo.id, userId: userId) { success in
            if success {
                onSave()
                dismiss()
            }
        }
    }
}
