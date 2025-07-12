import SwiftUI

struct ChatInputComponent: View {
    @Binding var userInput: String
    @State private var oldInput: String = ""
    @State private var isInitialLoad: Bool = true
    @State private var hasSetInitialText: Bool = false
    @EnvironmentObject var fontSettings: FontSettingsManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    
    let onSendMessage: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom) {
                AutoSizingTextEditor(text: $userInput)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.4), lineWidth: 1))
                    .onTapGesture {
                        // タップしたら初期テキストを削除
                        if isInitialLoad && userInput == "話題ある？" {
                            userInput = ""
                            isInitialLoad = false
                        }
                    }
                    .onChange(of: userInput) { newValue in
                        // 初期テキスト以外の入力があったら初期状態を解除
                        if newValue != "話題ある？" && newValue != "" {
                            isInitialLoad = false
                        }
                        
                        if userInput.count > 100 {
                            userInput = oldInput
                        } else {
                            oldInput = userInput
                        }
                    }
                    .onAppear {
                        // 初回表示時に「話題ある？」を設定
                        if !hasSetInitialText {
                            userInput = "話題ある？"
                            hasSetInitialText = true
                        }
                    }
                
                Button(action: onSendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(colorSettings.getCurrentAccentColor())
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
            .padding(.horizontal)
            
            // 文字数カウント
            Text("\(userInput.count)/100文字")
                .dynamicCaption()
                .foregroundColor(userInput.count >= 100 ? .red : colorSettings.getCurrentTextColor().opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 12)
        }
        .padding(.bottom, 10)
    }
}