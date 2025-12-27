import SwiftUI

struct ChatHistoryView: View {
    @StateObject private var chatHistoryService = ChatHistoryService()
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @AppStorage("isPremium") var isPremium: Bool = false
    @State private var showPremiumUpgrade = false
    @State private var searchText: String = ""

    let userId: String
    let characterId: String

    // 検索フィルタリング
    private var filteredPosts: [Post] {
        if searchText.isEmpty {
            return chatHistoryService.posts
        }
        return chatHistoryService.posts.filter { post in
            post.content.localizedCaseInsensitiveContains(searchText) ||
            post.analysisResult.localizedCaseInsensitiveContains(searchText)
        }
    }

    // フィルタリングされた投稿から日付別メッセージを取得
    private func getFilteredMessagesByDate() -> [String: [ChatMessage]] {
        var messagesByDate: [String: [ChatMessage]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年M月d日"
        dateFormatter.locale = Locale(identifier: "ja_JP")

        for post in filteredPosts {
            let dateString = dateFormatter.string(from: post.timestamp)

            let userMessage = ChatMessage(
                content: post.content,
                isUser: true,
                timestamp: post.timestamp
            )
            let characterMessage = ChatMessage(
                content: post.analysisResult,
                isUser: false,
                timestamp: post.timestamp.addingTimeInterval(1) // 少し後の時間
            )

            if messagesByDate[dateString] != nil {
                messagesByDate[dateString]?.append(userMessage)
                messagesByDate[dateString]?.append(characterMessage)
            } else {
                messagesByDate[dateString] = [userMessage, characterMessage]
            }
        }

        // 各日付内でメッセージを時間順にソート（新しい順）
        for dateKey in messagesByDate.keys {
            messagesByDate[dateKey]?.sort { $0.timestamp > $1.timestamp }
        }

        return messagesByDate
    }

    private func getFilteredDateList() -> [String] {
        return Array(getFilteredMessagesByDate().keys).sorted { date1, date2 in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年M月d日"
            formatter.locale = Locale(identifier: "ja_JP")

            guard let d1 = formatter.date(from: date1),
                  let d2 = formatter.date(from: date2) else {
                return date1 > date2
            }
            return d1 > d2
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("メッセージを検索", text: $searchText)
                    .dynamicBody()

                // クリアボタン（常に表示、テキストがない時は無効化）
                Button(action: {
                    withAnimation {
                        searchText = ""
                    }
                    // キーボードを閉じる
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(searchText.isEmpty ? .gray.opacity(0.3) : .gray.opacity(0.6))
                }
                .disabled(searchText.isEmpty)
            }
            .padding(12)
            .background(Color.white.opacity(0.8))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

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
                VStack(spacing: 0) {
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

                        // バナー広告（チャット履歴が空でも表示）
                        if subscriptionManager.shouldDisplayBannerAd() {
                            VStack(spacing: 16) {
                                // 区切り線
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 1)
                                    .padding(.horizontal, 32)

                                // バナー広告
                                BannerAdView(adUnitID: Config.chatHistoryBannerAdUnitID)
                                    .frame(height: 50)
                                    .background(Color.clear)
                                    .onAppear {
                                        subscriptionManager.trackBannerAdImpression()
                                    }
                                    .padding(.horizontal, 16)

                                // 下部余白
                                Spacer()
                                    .frame(height: 20)
                            }
                        }
                    }
                } else if filteredPosts.isEmpty {
                    // 検索結果が空の場合
                    VStack(spacing: 0) {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("検索結果がありません")
                                .dynamicBody()
                                .foregroundColor(.gray)
                            Text("「\(searchText)」に一致するメッセージが見つかりませんでした")
                                .dynamicCaption()
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        Spacer()

                        // バナー広告（チャット履歴が空でも表示）
                        if subscriptionManager.shouldDisplayBannerAd() {
                            VStack(spacing: 16) {
                                // 区切り線
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 1)
                                    .padding(.horizontal, 32)

                                // バナー広告
                                BannerAdView(adUnitID: Config.chatHistoryBannerAdUnitID)
                                    .frame(height: 50)
                                    .background(Color.clear)
                                    .onAppear {
                                        subscriptionManager.trackBannerAdImpression()
                                    }
                                    .padding(.horizontal, 16)

                                // 下部余白
                                Spacer()
                                    .frame(height: 20)
                            }
                        }
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                let messagesByDate = getFilteredMessagesByDate()
                                let dateList = getFilteredDateList().reversed() // 古い順（時系列順）

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

                                // プレミアム履歴アップグレードプロンプト
                                if chatHistoryService.hasMoreHistory && !subscriptionManager.isPremium {
                                    VStack(spacing: 16) {
                                        // 区切り線
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 1)
                                            .padding(.horizontal, 32)

                                        // アップグレードプロンプト
                                        VStack(spacing: 12) {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .font(.system(size: 40))
                                                .foregroundColor(.orange)

                                            Text("さらに古い履歴があります")
                                                .dynamicTitle3()
                                                .fontWeight(.semibold)
                                                .foregroundColor(colorSettings.getCurrentTextColor())

                                            Text("プレミアムにアップグレードして\n無制限のチャット履歴をご利用ください")
                                                .dynamicBody()
                                                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
                                                .multilineTextAlignment(.center)

                                            Button(action: {
                                                showPremiumUpgrade = true
                                            }) {
                                                HStack {
                                                    Image(systemName: "crown.fill")
                                                    Text("プレミアムにアップグレード")
                                                        .fontWeight(.semibold)
                                                }
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(
                                                    LinearGradient(
                                                        colors: [.orange, .red],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .cornerRadius(10)
                                            }
                                            .padding(.horizontal, 40)
                                        }
                                        .padding(.vertical, 20)
                                        .padding(.horizontal, 20)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(colorSettings.getCurrentTextColor().opacity(0.05))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                        .padding(.horizontal, 20)
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
                                        BannerAdView(adUnitID: Config.chatHistoryBannerAdUnitID)
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
                                    let messagesByDate = getFilteredMessagesByDate()
                                    let dateList = getFilteredDateList().reversed() // 古い順に変換

                                    if let latestDate = dateList.last, // 最後の日付が最新
                                       let latestMessages = messagesByDate[latestDate],
                                       !latestMessages.isEmpty {
                                        // reversed()後の最後のインデックスが最新メッセージ
                                        let latestIndex = latestMessages.count - 1
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
        .navigationTitle("チャット履歴")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            chatHistoryService.fetchChatHistory(userId: userId, characterId: characterId)
            subscriptionManager.startMonitoring()
        }
        .onDisappear {
            subscriptionManager.stopMonitoring()
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            PremiumUpgradeView()
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
