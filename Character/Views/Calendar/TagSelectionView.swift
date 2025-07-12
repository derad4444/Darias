import SwiftUI

struct TagSelectionView: View {
    @ObservedObject var tagSettings = TagSettingsManager.shared
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedTag: String
    @State private var showTagSettings = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    // 背景
                    colorSettings.getCurrentBackgroundGradient()
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            // タグなしオプション
                            Button(action: {
                                selectedTag = ""
                                dismiss()
                            }) {
                                HStack {
                                    Circle()
                                        .stroke(colorSettings.getCurrentTextColor().opacity(0.5), lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                    
                                    Text("タグなし")
                                        .dynamicBody()
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                    
                                    Spacer()
                                    
                                    if selectedTag.isEmpty {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(colorSettings.getCurrentAccentColor())
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedTag.isEmpty ? colorSettings.getCurrentAccentColor() : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 既存タグ一覧
                            ForEach(tagSettings.tags) { tag in
                                Button(action: {
                                    selectedTag = tag.name
                                    dismiss()
                                }) {
                                    HStack {
                                        // タグの色サンプル
                                        Circle()
                                            .fill(tag.color)
                                            .frame(width: 24, height: 24)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(tag.name)
                                                .dynamicBody()
                                                .foregroundColor(colorSettings.getCurrentTextColor())
                                            
                                            // タグ色のプレビュー
                                            HStack {
                                                Text("プレビュー")
                                                    .dynamicCaption2()
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(tag.color)
                                                    .cornerRadius(12)
                                                Spacer()
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedTag == tag.name {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(colorSettings.getCurrentAccentColor())
                                        }
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedTag == tag.name ? colorSettings.getCurrentAccentColor() : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // タグ管理ボタン
                            Button(action: {
                                showTagSettings = true
                            }) {
                                HStack {
                                    Image(systemName: "gear")
                                        .foregroundColor(.white)
                                    Text("タグを管理")
                                        .dynamicBody()
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(colorSettings.getCurrentAccentColor())
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 新規タグ作成ボタン
                            NavigationLink(destination: TagEditView(tag: nil)) {
                                HStack {
                                    Image(systemName: "plus")
                                        .foregroundColor(.white)
                                    Text("新しいタグを作成")
                                        .dynamicBody()
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(colorSettings.getCurrentTextColor().opacity(0.8))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("タグ選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(colorSettings.getCurrentAccentColor())
                }
            }
        }
        .sheet(isPresented: $showTagSettings) {
            TagSettingsView()
        }
    }
}

struct TagSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TagSelectionView(selectedTag: .constant(""))
                .environmentObject(FontSettingsManager.shared)
        }
    }
}