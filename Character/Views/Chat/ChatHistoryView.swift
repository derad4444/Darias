import SwiftUI

struct ChatHistoryView: View {
    @StateObject private var chatHistoryService = ChatHistoryService()
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @AppStorage("isPremium") var isPremium: Bool = false
    @Environment(\.dismiss) private var dismiss

    let userId: String
    let characterId: String
    
    var body: some View {
        ZStack {
            // 全画面背景
            colorSettings.getCurrentBackgroundGradient()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
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
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                let messagesByDate = chatHistoryService.getChatMessagesByDate()
                                let dateList = chatHistoryService.getDateList().reversed() // 古い順（時系列順）

                                ForEach(Array(dateList), id: \.self) { dateString in
                                    // 日付ヘッダー
                                    HStack {
                                        Spacer()
                                        DateHeaderView(dateString: dateString)
                                            .id("header-\(dateString)")
                                        Spacer()
                                    }
                                    .padding(.vertical, 16)
                                    .padding(.top, dateList.first == dateString ? 8 : 0) // 最初の日付は上部マージン追加

                                    // その日のメッセージ（古い順）
                                    if let messages = messagesByDate[dateString] {
                                        ForEach(Array(messages.reversed().enumerated()), id: \.offset) { index, message in
                                            ChatMessageBubble(message: message)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 2)
                                                .id("\(dateString)-\(index)")
                                        }

                                        // 各日付の最後に少し余白を追加
                                        Spacer()
                                            .frame(height: 8)
                                    }
                                }

                                // バナー広告（全チャット履歴の最下部に配置）
                                if subscriptionManager.shouldDisplayBannerAd() {
                                    VStack(spacing: 16) {
                                        // 区切り線
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 1)
                                            .padding(.horizontal, 32)

                                        // バナー広告
                                        BannerAdView(adUnitID: "ca-app-pub-3940256099942544/2934735716") // テスト用ID
                                            .frame(height: 50)
                                            .background(Color.clear)
                                            .id("banner-ad")
                                            .onAppear {
                                                subscriptionManager.trackBannerAdImpression()
                                            }
                                            .padding(.horizontal, 16)

                                        // 下部余白
                                        Spacer()
                                            .frame(height: 20)
                                    }
                                    .padding(.top, 16)
                                }
                            }
                        }
                        .padding(.bottom, 10) // 元の設定に戻す
                        .clipped() // 範囲外をクリップ
                        .onAppear {
                            // データロード後に最下部にスクロール
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                if subscriptionManager.shouldDisplayBannerAd() {
                                    // バナー広告がある場合は広告まで
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        proxy.scrollTo("banner-ad", anchor: .bottom)
                                    }
                                } else {
                                    // バナー広告がない場合は最新メッセージまで
                                    let messagesByDate = chatHistoryService.getChatMessagesByDate()
                                    let dateList = chatHistoryService.getDateList()

                                    if let latestDate = dateList.first,
                                       let latestMessages = messagesByDate[latestDate],
                                       !latestMessages.isEmpty {
                                        let latestIndex = 0 // reversed()で最新が最初
                                        withAnimation(.easeOut(duration: 0.5)) {
                                            proxy.scrollTo("\(latestDate)-\(latestIndex)", anchor: .bottom)
                                        }
                                    }
                                }
                            }
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
            subscriptionManager.startMonitoring()
        }
        .onDisappear {
            subscriptionManager.stopMonitoring()
        }
    }
}

// 日付ヘッダービュー
struct DateHeaderView: View {
    let dateString: String
    @ObservedObject var colorSettings = ColorSettingsManager.shared

    var body: some View {
        HStack {
            // 左の線
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)

            // 日付テキスト
            Text(dateString)
                .dynamicCaption()
                .foregroundColor(.gray)
                .fontWeight(.semibold)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )

            // 右の線
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, 32)
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
