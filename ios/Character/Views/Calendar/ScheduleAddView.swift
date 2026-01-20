import SwiftUI

struct ScheduleAddView: View {
    let userId: String
    @AppStorage("isPremium") var isPremium: Bool = false
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @ObservedObject var tagSettings = TagSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var firestoreManager: FirestoreManager
    
    @State private var title = ""
    @State private var isAllDay = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var location = ""
    @State private var repeatSettings = RepeatSettings()
    @State private var notificationSettings = NotificationSettings()
    @State private var tag = ""
    @State private var memo = ""
    @State private var showTagSelection = false
    @State private var showRepeatSettings = false
    @State private var showNotificationSettings = false
    @State private var showDateValidationAlert = false
    @State private var isCreatingRecurringSchedules = false
    @State private var recurringProgress = 0
    @State private var recurringTotal = 0
    
    private var dynamicHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let safeAreaTop = UIApplication.shared.windows.first?.safeAreaInsets.top ?? 47
        let safeAreaBottom = UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 34
        let navigationBarHeight: CGFloat = 44
        
        return screenHeight - safeAreaTop - navigationBarHeight - safeAreaBottom - 60
    }
    
    //開始終了日付の初期化
    let selectedDate: Date
    init(selectedDate: Date, userId: String) {
        self.selectedDate = selectedDate
        self.userId = userId

        // 現在時間の次の時間の0分を計算
        let calendar = Calendar.current
        let now = Date()

        // 現在の時間を取得し、次の時間に設定
        let currentHour = calendar.component(.hour, from: now)
        let nextHour = currentHour + 1

        // 選択された日付と次の時間の0分を組み合わせ
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        var startComponents = dateComponents
        startComponents.hour = nextHour
        startComponents.minute = 0
        startComponents.second = 0

        let calculatedStartDate = calendar.date(from: startComponents) ?? selectedDate

        _startDate = State(initialValue: calculatedStartDate)
        _endDate = State(initialValue: calculatedStartDate.addingTimeInterval(3600))
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // ✅ グラデーション背景
                    colorSettings.getCurrentBackgroundGradient()
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // カスタムヘッダー
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(colorSettings.getCurrentAccentColor())
                                    .font(.title2)
                            }
                            Spacer()
                            Button("保存") {
                                addSchedule()
                            }
                            .foregroundColor(colorSettings.getCurrentAccentColor())
                        }
                        .padding()
                        .background(Color.clear) // 完全透過
                        
                        // スクロール可能な情報エリア
                        ScrollView {
                            VStack(spacing: 20) {
                                // 1つ目のバナー広告（タイトルの上）
                                if subscriptionManager.shouldDisplayBannerAd() {
                                    BannerAdView(adUnitID: Config.scheduleAddTopBannerAdUnitID)
                                        .frame(height: 50)
                                        .background(Color.clear)
                                        .onAppear {
                                            subscriptionManager.trackBannerAdImpression()
                                        }
                                        .padding(.horizontal, 16)
                                }

                                    glassSection(title: "タイトル") {
                                        TextField("予定のタイトル", text: $title)
                                            .dynamicBody()
                                            .foregroundColor(colorSettings.getCurrentTextColor())
                                    }
                                    
                                    glassSection(title: "日付") {
                                        VStack(spacing: 16) {
                                            // 終日の行
                                            HStack {
                                                Text("終日")
                                                    .dynamicBody()
                                                    .foregroundColor(colorSettings.getCurrentTextColor())
                                                    .frame(width: 60, alignment: .leading)
                                                Spacer()
                                                Toggle("", isOn: $isAllDay)
                                                    .labelsHidden()
                                            }
                                            
                                            // 開始の行
                                            HStack {
                                                Text("開始")
                                                    .dynamicBody()
                                                    .foregroundColor(colorSettings.getCurrentTextColor())
                                                    .frame(width: 60, alignment: .leading)
                                                Spacer()
                                                DatePicker("", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                                                    .datePickerStyle(.compact)
                                                    .labelsHidden()
                                                    .padding(8)
                                                    .frame(minWidth: 200)
                                                    .background(Color.white.opacity(0.15))
                                                    .cornerRadius(8)
                                            }
                                            
                                            // 終了の行
                                            HStack {
                                                Text("終了")
                                                    .dynamicBody()
                                                    .foregroundColor(colorSettings.getCurrentTextColor())
                                                    .frame(width: 60, alignment: .leading)
                                                Spacer()
                                                DatePicker("", selection: $endDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                                                    .datePickerStyle(.compact)
                                                    .labelsHidden()
                                                    .padding(8)
                                                    .frame(minWidth: 200)
                                                    .background(Color.white.opacity(0.15))
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                    
                                    glassSection(title: "繰り返し") {
                                        Button(action: {
                                            showRepeatSettings = true
                                        }) {
                                            HStack {
                                                Image(systemName: "repeat")
                                                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                                                
                                                Text(repeatSettings.getDescription(for: startDate))
                                                    .dynamicBody()
                                                    .foregroundColor(colorSettings.getCurrentTextColor())
                                                
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    
                                    glassSection(title: "通知") {
                                        Button(action: {
                                            showNotificationSettings = true
                                        }) {
                                            HStack {
                                                Image(systemName: "bell")
                                                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                                                
                                                Text(notificationSettings.getDescription())
                                                    .dynamicBody()
                                                    .foregroundColor(colorSettings.getCurrentTextColor())
                                                
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    
                                    glassSection(title: "詳細") {
                                        HStack {
                                            Image(systemName: "mappin.and.ellipse")
                                                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                                            TextField("場所", text: $location)
                                                .dynamicBody()
                                                .foregroundColor(colorSettings.getCurrentTextColor())
                                        }
                                        Button(action: {
                                            showTagSelection = true
                                        }) {
                                            HStack {
                                                Image(systemName: "tag")
                                                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                                                
                                                if let selectedTag = tagSettings.getTag(by: tag) {
                                                    Circle()
                                                        .fill(selectedTag.color)
                                                        .frame(width: 16, height: 16)
                                                    Text(selectedTag.name)
                                                        .dynamicBody()
                                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                                } else {
                                                    Text(tag.isEmpty ? "タグを選択" : tag)
                                                        .dynamicBody()
                                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                                }
                                                
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        HStack(alignment: .top) {
                                            Image(systemName: "note.text")
                                                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                                            TextEditor(text: $memo)
                                                .dynamicBody()
                                                .foregroundColor(colorSettings.getCurrentTextColor())
                                                .frame(height: 80)
                                                .background(Color.clear)
                                                .scrollContentBackground(.hidden)
                                        }
                                    }

                                    // 2つ目のバナー広告（メモ欄の下）
                                    if subscriptionManager.shouldDisplayBannerAd() {
                                        BannerAdView(adUnitID: Config.scheduleAddBottomBannerAdUnitID)
                                            .frame(height: 50)
                                            .background(Color.clear)
                                            .onAppear {
                                                subscriptionManager.trackBannerAdImpression()
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.top, 10)
                                    }
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 115)
                        }
                        .frame(height: dynamicHeight)
                        .clipped() // 画面外をクリップ
                    }
                }
            }
        }
        .navigationBarHidden(true) // NavigationBarを完全に隠す
        .onAppear {
            subscriptionManager.startMonitoring()
        }
        .onDisappear {
            subscriptionManager.stopMonitoring()
        }
        
#if os(iOS)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showTagSelection) {
            TagSelectionView(selectedTag: $tag)
        }
        .sheet(isPresented: $showRepeatSettings) {
            RepeatSettingsView(repeatSettings: $repeatSettings, baseDate: startDate)
        }
        .sheet(isPresented: $showNotificationSettings) {
            NotificationSettingsView(notificationSettings: $notificationSettings)
        }
        .alert("日付エラー", isPresented: $showDateValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("終了日は開始日の後に設定してください")
        }
        .navigationBarBackButtonHidden(true)
        // カレンダーを日本語表示に
        .environment(\.locale, Locale(identifier: "ja_JP"))
        // 広告やAI用エリアを追加しやすい
        .safeAreaInset(edge: .bottom) {
            if !isPremium {
                // テスト用ID（本番時は差し替え）
                // BannerAdView(adUnitID: "ca-app-pub-3940256099942544/2934735716")
                //     .frame(width: 320, height: 50)
                //     .padding(.bottom, 8)
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 50)
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 100 {
                        dismiss()
                    }
                }
        )
#endif
        .overlay(
            // 繰り返し予定作成中のローディングポップアップ
            Group {
                if isCreatingRecurringSchedules {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)

                            Text("繰り返し予定を作成中...")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("\(recurringProgress) / \(recurringTotal)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))

                            // プログレスバー
                            ProgressView(value: Double(recurringProgress), total: Double(recurringTotal))
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                .frame(width: 200)
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.8))
                        )
                    }
                }
            }
        )
    }
    
    // 予定を追加する関数
    func addSchedule() {
        // 🔸 日付検証
        if endDate < startDate {
            showDateValidationAlert = true
            return
        }

        // 🔸 時刻補正
        var finalStartDate = startDate
        var finalEndDate = endDate

        if isAllDay {
            finalStartDate = Calendar.current.startOfDay(for: startDate)
            finalEndDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: endDate) ?? endDate
        }

        // 繰り返し予定の場合は複数の予定を生成
        if repeatSettings.type != .none {
            isCreatingRecurringSchedules = true
            createRecurringSchedules(
                baseStartDate: finalStartDate,
                baseEndDate: finalEndDate
            )
        } else {
            // 単発予定の場合
            var newSchedule = ScheduleItem(
                id: UUID().uuidString,
                title: title,
                isAllDay: isAllDay,
                startDate: finalStartDate,
                endDate: finalEndDate,
                location: location,
                tag: tag,
                memo: memo,
                repeatOption: repeatSettings.getDescription(for: finalStartDate),
                recurringGroupId: nil
            )

            // 通知設定をScheduleItemに設定
            newSchedule.notificationSettings = notificationSettings

            firestoreManager.addSchedule(newSchedule, for: userId) { success in
                if success {
                    // 新しい通知システムを使用
                    NotificationManager.shared.scheduleNotifications(for: newSchedule)
                    dismiss()
                } else {
                    // エラー処理
                }
            }
        }
    }

    // 繰り返し予定を複数作成する関数
    private func createRecurringSchedules(baseStartDate: Date, baseEndDate: Date) {
        let duration = baseEndDate.timeIntervalSince(baseStartDate)
        let recurringDates = repeatSettings.generateDates(from: baseStartDate)
        let groupId = UUID().uuidString // 繰り返し予定グループの共通ID

        var successCount = 0
        let totalCount = recurringDates.count

        // 進捗状況を初期化
        DispatchQueue.main.async {
            self.recurringTotal = totalCount
            self.recurringProgress = 0
        }

        for (index, date) in recurringDates.enumerated() {
            let scheduleStartDate = date
            let scheduleEndDate = Date(timeInterval: duration, since: date)

            var schedule = ScheduleItem(
                id: UUID().uuidString,
                title: title,
                isAllDay: isAllDay,
                startDate: scheduleStartDate,
                endDate: scheduleEndDate,
                location: location,
                tag: tag,
                memo: memo,
                repeatOption: repeatSettings.getDescription(for: baseStartDate),
                recurringGroupId: groupId
            )

            // 通知設定をScheduleItemに設定
            schedule.notificationSettings = notificationSettings

            firestoreManager.addSchedule(schedule, for: userId) { success in
                DispatchQueue.main.async {
                    if success {
                        successCount += 1
                        self.recurringProgress = successCount

                        // 新しい通知システムを使用
                        NotificationManager.shared.scheduleNotifications(for: schedule)

                        // 全ての予定の保存が完了したら画面を閉じる
                        if successCount == totalCount {
                            self.isCreatingRecurringSchedules = false
                            dismiss()
                        }
                    } else {
                        // エラー処理 - 部分的に失敗した場合の処理
                        successCount += 1 // エラーでもカウントを増やして進行
                        self.recurringProgress = successCount

                        if successCount == totalCount {
                            self.isCreatingRecurringSchedules = false
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    // ScrollViewの高さを計算する関数
    private func calculateScrollViewHeight(geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        let topSafeArea = geometry.safeAreaInsets.top
        let bottomSafeArea = geometry.safeAreaInsets.bottom
        
        
        // ツールバー + フッターの最小マージン
        let reservedSpace: CGFloat = isPremium ? 100 : 150
        
        // 利用可能な高さを最大化
        let availableHeight = screenHeight - reservedSpace
        
        
        return availableHeight
    }
    
    // ガラス風セクション
    @ViewBuilder
    private func glassSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .dynamicCaption()
                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
            VStack(spacing: 16) {   // 詳細欄の感覚
                content()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.4))   // ★ ここを 0.2 に変更
                    .background(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
            )
        }
    }
}

//プレビュー画面表示
struct ScheduleAddView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ScheduleAddView(selectedDate: Date(), userId: "preview_user_id")
                .environmentObject(FirestoreManager())
                .environmentObject(FontSettingsManager.shared)
        }
    }
}
