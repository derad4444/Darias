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
    @State private var selectedTab: MemoEditTab = .edit
    @State private var previousContent: String = ""
    @State private var textToInsert: String = ""

    enum MemoEditTab: String, CaseIterable {
        case edit = "編集"
        case preview = "プレビュー"
    }

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
                            HStack {
                                Text("内容")
                                    .dynamicCallout()
                                    .foregroundColor(.secondary)

                                Spacer()

                                // タブ切り替え
                                Picker("", selection: $selectedTab) {
                                    ForEach(MemoEditTab.allCases, id: \.self) { tab in
                                        Text(tab.rawValue).tag(tab)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 180)
                            }

                            if selectedTab == .edit {
                                // 編集タブ
                                CustomTextEditor(text: $content, textToInsert: $textToInsert)
                                    .frame(minHeight: 200)
                                    .padding(12)
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(10)

                                // マークダウンツールバー
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        MarkdownToolbarButton(icon: "bold", label: "太字", syntax: "**") { insertMarkdown(syntax: "**", placeholder: "太字") }
                                        MarkdownToolbarButton(icon: "list.bullet", label: "箇条書き", syntax: "- ") { insertMarkdown(syntax: "- ", placeholder: "", isPrefix: true) }
                                        MarkdownToolbarButton(icon: "number", label: "番号付き", syntax: "1. ") { insertMarkdown(syntax: "1. ", placeholder: "", isPrefix: true) }
                                        MarkdownToolbarButton(icon: "number.square", label: "見出し", syntax: "# ") { insertMarkdown(syntax: "# ", placeholder: "", isPrefix: true) }
                                        MarkdownToolbarButton(icon: "quote.closing", label: "引用", syntax: "> ") { insertMarkdown(syntax: "> ", placeholder: "", isPrefix: true) }
                                    }
                                    .padding(.horizontal, 4)
                                }
                            } else {
                                // プレビュータブ
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 8) {
                                        if content.isEmpty {
                                            Text("内容を入力すると、ここにプレビューが表示されます")
                                                .dynamicBody()
                                                .foregroundColor(.gray)
                                                .frame(maxWidth: .infinity, alignment: .center)
                                                .padding(40)
                                        } else {
                                            MarkdownText(content, fontSize: 16, color: .primary)
                                                .multilineTextAlignment(.leading)
                                                .environmentObject(fontSettings)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                }
                                .frame(minHeight: 200)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(10)
                            }
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
                    if selectedTab == .preview {
                        // プレビュータブ時は「編集」ボタン
                        Button("編集") {
                            selectedTab = .edit
                        }
                    } else {
                        // 編集タブ時は「保存」ボタン
                        Button("保存") {
                            saveMemo()
                        }
                        .disabled(title.isEmpty)
                    }
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
                    // 既存メモはプレビュータブから開始
                    selectedTab = .preview
                } else {
                    // 新規メモは編集タブから開始
                    selectedTab = .edit
                }
                previousContent = content
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

    // マークダウン記号を挿入する関数
    private func insertMarkdown(syntax: String, placeholder: String, isPrefix: Bool = false) {
        if isPrefix {
            // プレフィックス型（箇条書き、見出しなど）
            textToInsert = "\n\(syntax)\(placeholder)"
        } else {
            // ラップ型（太字、斜体など）
            textToInsert = "\(syntax)\(placeholder)\(syntax)"
        }
    }

    // 改行時の自動補完処理
    private func handleContentChange(_ newValue: String) {
        // 改行が追加されたかチェック
        if newValue.count > previousContent.count && newValue.last == "\n" {
            let lines = newValue.components(separatedBy: "\n")
            if lines.count >= 2 {
                let previousLine = lines[lines.count - 2]

                // 箇条書き（- で始まる行）の検出
                if previousLine.hasPrefix("- ") {
                    let trimmedLine = previousLine.trimmingCharacters(in: .whitespaces)
                    // 空の箇条書き行なら終了
                    if trimmedLine == "-" {
                        // 最後の改行と"-"を削除
                        content = String(content.dropLast())
                        content = String(content.dropLast(2))
                    } else {
                        // 次の箇条書きを追加
                        content += "- "
                    }
                }
                // 番号付きリスト（1. 2. 3. など）の検出
                else if let match = previousLine.range(of: #"^(\d+)\. "#, options: .regularExpression) {
                    let numberString = previousLine[match].dropLast(2) // ". "を除去
                    if let currentNumber = Int(numberString) {
                        let trimmedLine = previousLine.trimmingCharacters(in: .whitespaces)
                        // 空の番号付き行なら終了
                        if trimmedLine == "\(currentNumber)." {
                            // 最後の改行と番号を削除
                            content = String(content.dropLast())
                            let removeCount = "\(currentNumber). ".count
                            content = String(content.dropLast(removeCount))
                        } else {
                            // 次の番号を追加
                            let nextNumber = currentNumber + 1
                            content += "\(nextNumber). "
                        }
                    }
                }
            }
        }

        previousContent = content
    }
}

// マークダウンツールバーボタンコンポーネント
struct MarkdownToolbarButton: View {
    let icon: String
    let label: String
    let syntax: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#A084CA"))
            .cornerRadius(8)
        }
    }
}

// カスタムTextEditorコンポーネント（カーソル位置追跡対応）
struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var textToInsert: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = .clear
        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // 挿入するテキストがある場合
        if !textToInsert.isEmpty && textToInsert != context.coordinator.lastInsertedText {
            context.coordinator.lastInsertedText = textToInsert
            // カーソル位置に挿入
            uiView.insertText(textToInsert)

            // textToInsertをクリア
            DispatchQueue.main.async {
                self.textToInsert = ""
                context.coordinator.lastInsertedText = ""
            }
            return
        }

        // テキストが変更された場合のみ更新
        if uiView.text != text && !context.coordinator.isInternalUpdate {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor
        var textView: UITextView?
        var isInternalUpdate = false
        var lastInsertedText = ""
        var previousText = ""

        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            let currentText = textView.text ?? ""

            // 内部更新中はスキップ
            if isInternalUpdate {
                return
            }

            // 改行が追加されたかチェック
            if currentText.count > previousText.count && currentText.last == "\n" {
                isInternalUpdate = true
                handleNewline(textView: textView, currentText: currentText)
                isInternalUpdate = false
            }

            parent.text = textView.text ?? ""
            previousText = textView.text ?? ""
        }

        private func handleNewline(textView: UITextView, currentText: String) {
            let lines = currentText.components(separatedBy: "\n")
            if lines.count >= 2 {
                let previousLine = lines[lines.count - 2]

                // 箇条書き（- で始まる行）の検出
                if previousLine.hasPrefix("- ") {
                    let trimmedLine = previousLine.trimmingCharacters(in: .whitespaces)
                    // 空の箇条書き行なら終了
                    if trimmedLine == "-" {
                        // 最後の改行と"-"を削除
                        var newText = currentText
                        newText = String(newText.dropLast())
                        newText = String(newText.dropLast(2))
                        textView.text = newText

                        // カーソル位置を調整
                        if let newPosition = textView.position(from: textView.beginningOfDocument, offset: newText.count) {
                            textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
                        }
                    } else {
                        // 次の箇条書きを追加
                        textView.insertText("- ")
                    }
                }
                // 番号付きリスト（1. 2. 3. など）の検出
                else if let match = previousLine.range(of: #"^(\d+)\. "#, options: .regularExpression) {
                    let numberString = previousLine[match].dropLast(2) // ". "を除去
                    if let currentNumber = Int(numberString) {
                        let trimmedLine = previousLine.trimmingCharacters(in: .whitespaces)
                        // 空の番号付き行なら終了
                        if trimmedLine == "\(currentNumber)." {
                            // 最後の改行と番号を削除
                            var newText = currentText
                            newText = String(newText.dropLast())
                            let removeCount = "\(currentNumber). ".count
                            newText = String(newText.dropLast(removeCount))
                            textView.text = newText

                            // カーソル位置を調整
                            if let newPosition = textView.position(from: textView.beginningOfDocument, offset: newText.count) {
                                textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
                            }
                        } else {
                            // 次の番号を追加
                            let nextNumber = currentNumber + 1
                            textView.insertText("\(nextNumber). ")
                        }
                    }
                }
            }
        }
    }
}
