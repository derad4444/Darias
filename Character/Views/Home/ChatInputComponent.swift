import SwiftUI

struct ChatInputComponent: View {
    @Binding var userInput: String
    let isWaitingForReply: Bool
    @State private var oldInput: String = ""
    @State private var isPlaceholderVisible: Bool = true
    @State private var hasSetInitialText: Bool = false
    @EnvironmentObject var fontSettings: FontSettingsManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    
    let onSendMessage: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom) {
                ZStack(alignment: .topLeading) {
                    AutoSizingTextEditor(text: $userInput)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(isWaitingForReply ? 0.1 : 0.2))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.4), lineWidth: 1))
                        .disabled(isWaitingForReply)
                        .onTapGesture {
                            // 待機中はタップを無効化
                            if !isWaitingForReply && isPlaceholderVisible {
                                isPlaceholderVisible = false
                                userInput = ""
                            }
                        }
                        .onChange(of: userInput) { _, newValue in
                            // 入力があったらプレースホルダーを非表示
                            if !newValue.isEmpty {
                                isPlaceholderVisible = false
                            } else {
                                isPlaceholderVisible = true
                            }
                            
                            if userInput.count > 100 {
                                userInput = oldInput
                            } else {
                                oldInput = userInput
                            }
                        }
                    
                    // プレースホルダーテキスト
                    if isPlaceholderVisible && userInput.isEmpty {
                        Text(isWaitingForReply ? "返答を待っています..." : "話題ある？")
                            .foregroundColor(.gray) // グレー色で見やすく
                            .padding(.horizontal, 15)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false) // タップを通す
                    }
                }
                
                Button(action: {
                    // 待機中または無効な入力の場合は送信しない
                    if !isWaitingForReply && !isPlaceholderVisible && !userInput.isEmpty {
                        onSendMessage()
                    }
                }) {
                    Image(systemName: isWaitingForReply ? "hourglass" : "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(!isWaitingForReply && !isPlaceholderVisible && !userInput.isEmpty ? colorSettings.getCurrentAccentColor() : Color.gray.opacity(0.5))
                        .clipShape(Circle())
                        .shadow(radius: !isWaitingForReply && !isPlaceholderVisible && !userInput.isEmpty ? 4 : 0)
                        .disabled(isWaitingForReply)
                }
            }
            .padding(.horizontal)
            
            // 文字数カウント（プレースホルダー時は0文字表示）
            Text("\(isPlaceholderVisible ? 0 : userInput.count)/100文字")
                .dynamicCaption()
                .foregroundColor(userInput.count >= 100 ? .red : colorSettings.getCurrentTextColor().opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 12)
        }
        .padding(.bottom, 10)
    }
}