import SwiftUI

struct MemoDetailView: View {
    let userId: String
    let memo: Memo?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var firestoreManager = FirestoreManager.shared
    @StateObject private var colorSettings = ColorSettingsManager.shared
    @StateObject private var tagSettingsManager = TagSettingsManager.shared
    @EnvironmentObject var fontSettings: FontSettingsManager

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedTag: String = ""
    @State private var isPinned: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var showTagSelection: Bool = false

    private var isNewMemo: Bool {
        memo == nil
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

                        // 内容入力
                        VStack(alignment: .leading, spacing: 8) {
                            Text("内容")
                                .dynamicCallout()
                                .foregroundColor(.secondary)

                            TextEditor(text: $content)
                                .frame(minHeight: 200)
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
                                    Text(selectedTag.isEmpty ? "タグを選択" : selectedTag)
                                        .dynamicBody()
                                        .foregroundColor(selectedTag.isEmpty ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(10)
                            }
                        }

                        // ピン留め
                        Toggle(isOn: $isPinned) {
                            HStack {
                                Image(systemName: isPinned ? "pin.fill" : "pin")
                                    .foregroundColor(colorSettings.getCurrentAccentColor())
                                Text("ピン留め")
                                    .dynamicBody()
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)

                        // 削除ボタン（編集時のみ）
                        if !isNewMemo {
                            Button(action: {
                                showDeleteAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("メモを削除")
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
            .navigationTitle(isNewMemo ? "新規メモ" : "メモ編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveMemo()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showTagSelection) {
                TagSelectionView(selectedTag: $selectedTag)
            }
            .alert("メモを削除", isPresented: $showDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    deleteMemo()
                }
            } message: {
                Text("このメモを削除してもよろしいですか？")
            }
            .onAppear {
                if let memo = memo {
                    title = memo.title
                    content = memo.content
                    selectedTag = memo.tag
                    isPinned = memo.isPinned
                }
            }
        }
    }

    private func saveMemo() {
        if isNewMemo {
            let newMemo = Memo(
                title: title,
                content: content,
                tag: selectedTag,
                isPinned: isPinned
            )
            firestoreManager.addMemo(newMemo, userId: userId) { success in
                if success {
                    onSave()
                    dismiss()
                }
            }
        } else if let existingMemo = memo {
            var updatedMemo = existingMemo
            updatedMemo.title = title
            updatedMemo.content = content
            updatedMemo.tag = selectedTag
            updatedMemo.isPinned = isPinned

            firestoreManager.updateMemo(updatedMemo, userId: userId) { success in
                if success {
                    onSave()
                    dismiss()
                }
            }
        }
    }

    private func deleteMemo() {
        guard let memo = memo else { return }

        firestoreManager.deleteMemo(memoId: memo.id, userId: userId) { success in
            if success {
                onSave()
                dismiss()
            }
        }
    }
}
