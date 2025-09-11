import SwiftUI

struct ChatHistoryView: View {
    @StateObject private var chatHistoryService = ChatHistoryService()
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @AppStorage("isPremium") var isPremium: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var currentDateString: String = ""
    
    let userId: String
    let characterId: String
    
    var body: some View {
        ZStack {
            // 全画面背景
            colorSettings.getCurrentBackgroundGradient()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 固定日付ヘッダー（中央揃え）
                if !currentDateString.isEmpty {
                    HStack {
                        Spacer()
                        Text(currentDateString)
                            .dynamicCaption()
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(colorSettings.getCurrentAccentColor().opacity(0.8))
                            .cornerRadius(16)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .background(colorSettings.getCurrentBackgroundGradient())
                }
                
                // チャット履歴
                if chatHistoryService.isLoading {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("読み込み中...")
                            .dynamicBody()
                    }
                    Spacer()
                } else if chatHistoryService.posts.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "message")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("チャット履歴がありません")
                            .dynamicBody()
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            let messagesByDate = chatHistoryService.getChatMessagesByDate()
                            let dateList = chatHistoryService.getDateList().reversed() // 古い順（時系列順）
                            
                            ForEach(Array(dateList), id: \.self) { dateString in
                                // その日のメッセージ（古い順）
                                if let messages = messagesByDate[dateString] {
                                    ForEach(messages.reversed()) { message in
                                        ChatMessageBubble(message: message)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 2)
                                            .onAppear {
                                                // スクロール位置に基づいて日付を更新
                                                updateCurrentDate(for: dateString)
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .defaultScrollAnchor(.bottom) // iOS 17以降で下から表示
                    .padding(.bottom, 10) // タブバー分の下部パディングを調整
                    .clipped() // 範囲外をクリップ
                    .onAppear {
                        // 初期表示時に最新の日付を設定
                        let dateList = chatHistoryService.getDateList()
                        if let firstDate = dateList.first {
                            currentDateString = firstDate
                        }
                    }
                }
            }
        }
        .navigationTitle("チャット履歴")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(hex: "#A084CA"))
                        .font(.system(size: 18, weight: .semibold))
                }
            }
        }
        .onAppear {
            chatHistoryService.fetchChatHistory(userId: userId, characterId: characterId)
        }
    }
    
    // スクロール位置に基づいて現在の日付を更新
    private func updateCurrentDate(for dateString: String) {
        DispatchQueue.main.async {
            currentDateString = dateString
        }
    }
}

// 日付ヘッダービュー
struct DateHeaderView: View {
    let dateString: String
    
    var body: some View {
        Text(dateString)
            .dynamicCaption()
            .foregroundColor(.gray)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.7))
            .cornerRadius(12)
    }
}

// チャットメッセージバブル
struct ChatMessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                // ユーザーメッセージ（右側、青色）
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .dynamicBody()
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#A084CA"))
                        .cornerRadius(18)
                    
                    Text(timeString(from: message.timestamp))
                        .dynamicCaption2()
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            } else {
                // キャラクターメッセージ（左側、グレー）
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .dynamicBody()
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(18)
                    
                    Text(timeString(from: message.timestamp))
                        .dynamicCaption2()
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                Spacer()
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct ChatHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ChatHistoryView(userId: "sampleUserId", characterId: "sampleCharacterId")
        }
    }
}
