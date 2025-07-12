import SwiftUI

struct TagSettingsView: View {
    @ObservedObject var tagSettings = TagSettingsManager.shared
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAddTag = false
    @State private var editingTag: Tag?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    // 背景
                    colorSettings.getCurrentBackgroundGradient()
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            // 既存タグ一覧
                            ForEach(tagSettings.tags) { tag in
                                HStack {
                                    // タグの色サンプル
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 20, height: 20)
                                    
                                    Text(tag.name)
                                        .dynamicBody()
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                    
                                    Spacer()
                                    
                                    // 編集ボタン
                                    Button(action: {
                                        editingTag = tag
                                    }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(colorSettings.getCurrentAccentColor())
                                    }
                                    
                                    // 削除ボタン
                                    Button(action: {
                                        tagSettings.deleteTag(id: tag.id)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                            }
                            
                            // 新規追加ボタン
                            Button(action: {
                                showAddTag = true
                            }) {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("新しいタグを追加")
                                        .dynamicBody()
                                }
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(colorSettings.getCurrentAccentColor())
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("タグ設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundColor(colorSettings.getCurrentAccentColor())
                }
            }
        }
        .sheet(isPresented: $showAddTag) {
            TagEditView(tag: nil)
        }
        .sheet(item: $editingTag) { tag in
            TagEditView(tag: tag)
        }
    }
}

struct TagEditView: View {
    @ObservedObject var tagSettings = TagSettingsManager.shared
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    let tag: Tag?
    
    @State private var tagName: String = ""
    @State private var tagColor: Color = Color.blue
    
    var isEditing: Bool {
        tag != nil
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    // 背景
                    colorSettings.getCurrentBackgroundGradient()
                        .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        // タグ名入力
                        VStack(alignment: .leading, spacing: 12) {
                            Text("タグ名")
                                .dynamicHeadline()
                                .foregroundColor(colorSettings.getCurrentTextColor())
                            
                            TextField("タグ名を入力", text: $tagName)
                                .dynamicBody()
                                .foregroundColor(colorSettings.getCurrentTextColor())
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                        }
                        
                        // タグ色選択
                        VStack(alignment: .leading, spacing: 12) {
                            Text("タグ色")
                                .dynamicHeadline()
                                .foregroundColor(colorSettings.getCurrentTextColor())
                            
                            HStack {
                                Text("色")
                                    .dynamicCallout()
                                    .foregroundColor(colorSettings.getCurrentTextColor())
                                Spacer()
                                ColorPicker("", selection: $tagColor)
                                    .labelsHidden()
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                        }
                        
                        // プレビュー
                        VStack(alignment: .leading, spacing: 12) {
                            Text("プレビュー")
                                .dynamicHeadline()
                                .foregroundColor(colorSettings.getCurrentTextColor())
                            
                            HStack {
                                Circle()
                                    .fill(tagColor)
                                    .frame(width: 16, height: 16)
                                Text(tagName.isEmpty ? "サンプルタグ" : tagName)
                                    .dynamicCallout()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(tagColor)
                                    .cornerRadius(16)
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditing ? "タグ編集" : "新規タグ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(colorSettings.getCurrentAccentColor())
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveTag()
                    }
                    .foregroundColor(colorSettings.getCurrentAccentColor())
                    .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if let tag = tag {
                tagName = tag.name
                tagColor = tag.color
            }
        }
    }
    
    private func saveTag() {
        let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        if let tag = tag {
            tagSettings.updateTag(id: tag.id, name: trimmedName, color: tagColor)
        } else {
            tagSettings.addTag(name: trimmedName, color: tagColor)
        }
        
        dismiss()
    }
}

struct TagSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TagSettingsView()
                .environmentObject(FontSettingsManager.shared)
        }
    }
}