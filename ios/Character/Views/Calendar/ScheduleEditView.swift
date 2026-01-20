import SwiftUI
import FirebaseFirestore

struct ScheduleEditView: View {
    let schedule: ScheduleItem  // ✅ ScheduleItemを受け取る
    let userId: String
    let editSingleOnly: Bool  // 単一予定のみ編集するかどうか
    let isNewSchedule: Bool  // 新規作成モード（チャットから追加の場合はtrue）

    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @ObservedObject var tagSettings = TagSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @AppStorage("isPremium") var isPremium: Bool = false
    
    @State private var scheduleTitle: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var location: String
    @State private var tag: String
    @State private var memo: String
    @State private var isAllDay: Bool
    @State private var repeatSettings = RepeatSettings()
    @State private var notificationSettings = NotificationSettings()

    @State private var isLoading = false
    @State private var showTagSelection = false
    @State private var showRepeatSettings = false
    @State private var showNotificationSettings = false
    @State private var showDateValidationAlert = false
    @State private var errorMessage = ""
    @State private var isCreatingRecurringSchedules = false
    @State private var recurringProgress = 0
    @State private var recurringTotal = 0

    @Environment(\.dismiss) private var dismiss

    private var dynamicContentHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let safeAreaTop: CGFloat = 47
        let safeAreaBottom: CGFloat = 34
        let headerHeight: CGFloat = 60
        let adHeight: CGFloat = isPremium ? 0 : 50
        return screenHeight - safeAreaTop - safeAreaBottom - headerHeight - adHeight - 20
    }
    
    private var dynamicTextFieldHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        return screenHeight * 0.1
    }
    
    private var dynamicAdHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        return screenHeight * 0.06
    }

    // ✅ 初期化でStateに代入
    init(schedule: ScheduleItem, userId: String, editSingleOnly: Bool = false, isNewSchedule: Bool = false) {
        self.schedule = schedule
        self.userId = userId
        self.editSingleOnly = editSingleOnly
        self.isNewSchedule = isNewSchedule
        _scheduleTitle = State(initialValue: schedule.title)
        _startDate = State(initialValue: schedule.startDate)
        _endDate = State(initialValue: schedule.endDate)
        _location = State(initialValue: schedule.location)
        _tag = State(initialValue: schedule.tag)
        _memo = State(initialValue: schedule.memo)
        _isAllDay = State(initialValue: schedule.isAllDay)

        // 既存の繰り返し設定を復元
        _repeatSettings = State(initialValue: Self.parseRepeatOption(schedule.repeatOption))

        // 既存の通知設定を復元
        _notificationSettings = State(initialValue: schedule.notificationSettings ?? NotificationSettings())
    }

    // 繰り返し設定の文字列から RepeatSettings を復元
    static func parseRepeatOption(_ repeatOption: String) -> RepeatSettings {
        var settings = RepeatSettings()

        if repeatOption == "繰り返さない" || repeatOption.isEmpty {
            settings.type = .none
            return settings
        }

        if repeatOption.contains("毎日") {
            settings.type = .daily
        } else if repeatOption.contains("毎週") {
            settings.type = .weekly
        } else if repeatOption.contains("毎月") {
            if repeatOption.contains("月末") {
                settings.type = .monthEnd
            } else if repeatOption.contains("月初") || repeatOption.contains("1日") {
                settings.type = .monthStart
            } else {
                settings.type = .monthly
            }
        }

        // 終了条件の解析
        if repeatOption.contains("まで") {
            settings.endType = .onDate
            // 日付の抽出は複雑なので、とりあえずデフォルト値を使用
        } else if repeatOption.contains("回") {
            settings.endType = .afterOccurrences
            // 回数の抽出
            let pattern = #"(\d+)回"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: repeatOption, options: [], range: NSRange(location: 0, length: repeatOption.count)),
               let range = Range(match.range(at: 1), in: repeatOption) {
                if let count = Int(String(repeatOption[range])) {
                    settings.occurrenceCount = count
                }
            }
        } else {
            settings.endType = .never
        }

        return settings
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
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
                                saveSchedule()
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
                                    BannerAdView(adUnitID: Config.scheduleEditTopBannerAdUnitID)
                                        .frame(height: 50)
                                        .background(Color.clear)
                                        .onAppear {
                                            subscriptionManager.trackBannerAdImpression()
                                        }
                                        .padding(.horizontal, 16)
                                }

                                glassSection(title: "タイトル") {
                                    TextField("予定のタイトル", text: $scheduleTitle)
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                }

                                glassSection(title: "日付") {
                                    VStack(spacing: 16) {
                                        HStack {
                                            Text("終日").font(.system(size: 16)).foregroundColor(colorSettings.getCurrentTextColor()).frame(width: 60, alignment: .leading)
                                            Spacer()
                                            Toggle("", isOn: $isAllDay).labelsHidden()
                                        }

                                        HStack {
                                            Text("開始").font(.system(size: 16)).foregroundColor(colorSettings.getCurrentTextColor()).frame(width: 60, alignment: .leading)
                                            Spacer()
                                            DatePicker("", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                                                .datePickerStyle(.compact)
                                                .labelsHidden()
                                                .padding(8)
                                                .frame(minWidth: 200)
                                                .background(Color.white.opacity(0.15))
                                                .cornerRadius(8)
                                        }

                                        HStack {
                                            Text("終了").font(.system(size: 16)).foregroundColor(colorSettings.getCurrentTextColor()).frame(width: 60, alignment: .leading)
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
                                                .font(.system(size: 16))
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
                                                .font(.system(size: 16))
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
                                                    .foregroundColor(colorSettings.getCurrentTextColor())
                                            } else {
                                                Text(tag.isEmpty ? "タグを選択" : tag)
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
                                            .foregroundColor(colorSettings.getCurrentTextColor())
                                            .frame(height: dynamicTextFieldHeight)
                                            .background(Color.clear)
                                            .scrollContentBackground(.hidden)
                                    }
                                }

                                // 2つ目のバナー広告（メモ欄の下）
                                if subscriptionManager.shouldDisplayBannerAd() {
                                    BannerAdView(adUnitID: Config.scheduleEditBottomBannerAdUnitID)
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
                        .frame(height: dynamicContentHeight)
                        .clipped() // 画面外をクリップ
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
            .alert("日付エラー", isPresented: $showDateValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("終了日は開始日の後に設定してください")
            }
            .sheet(isPresented: $showTagSelection) {
                TagSelectionView(selectedTag: $tag)
            }
            .sheet(isPresented: $showRepeatSettings) {
                RepeatSettingsView(repeatSettings: $repeatSettings, baseDate: startDate)
            }
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView(notificationSettings: $notificationSettings)
            }
        }
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#EDE6F2"), Color(hex: "#F9F6F0")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .navigationBarBackButtonHidden(true)
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
                    .frame(height: dynamicAdHeight)
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

                            Text("\(recurringTotal)件の予定を作成中")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
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

    @ViewBuilder
    private func glassSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption).foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
            VStack(spacing: 16) { content() }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.4))
                        .background(BlurView(style: .systemUltraThinMaterial))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                        )
                )
        }
    }

    // Firestore保存
    func saveSchedule() {
        // 日付検証
        if endDate < startDate {
            showDateValidationAlert = true
            return
        }

        guard !userId.isEmpty else { return }

        var finalStartDate = startDate
        var finalEndDate = endDate
        if isAllDay {
            finalStartDate = Calendar.current.startOfDay(for: startDate)
            finalEndDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: endDate) ?? endDate
        }

        // 新規作成モードの場合は新規保存、それ以外は既存予定を更新
        if isNewSchedule {
            createNewSchedule(startDate: finalStartDate, endDate: finalEndDate)
        } else {
            updateExistingSchedule(startDate: finalStartDate, endDate: finalEndDate)
        }
    }

    private func updateExistingSchedule(startDate: Date, endDate: Date) {

        // editSingleOnlyフラグに基づく処理分岐
        if editSingleOnly {
            // 単一予定のみ編集：FirestoreManagerを使用して更新、その後グループから分離
            var updatedSchedule = ScheduleItem(
                id: schedule.id,
                title: scheduleTitle,
                isAllDay: isAllDay,
                startDate: startDate,
                endDate: endDate,
                location: location,
                tag: tag,
                memo: memo,
                repeatOption: repeatSettings.getDescription(for: startDate),
                recurringGroupId: nil
            )
            // 通知設定をScheduleItemに設定
            updatedSchedule.notificationSettings = notificationSettings

            let firestoreManager = FirestoreManager()
            firestoreManager.updateSchedule(updatedSchedule) { success in
                if success {
                    // 更新成功後、recurringGroupIdを削除してグループから分離
                    firestoreManager.removeSingleFromGroup(scheduleId: schedule.id) { removeSuccess in
                        if removeSuccess {
                            // 新しい通知システムを使用
                            NotificationManager.shared.updateNotifications(for: updatedSchedule)
                            self.notifyScheduleUpdate()
                            DispatchQueue.main.async { dismiss() }
                        }
                    }
                }
            }
            return
        }

        // 全体編集の場合の処理（従来のロジック）
        if repeatSettings.type != .none {
            // 既存の繰り返しグループがあれば削除してから新しい繰り返し予定を作成
            if let groupId = schedule.recurringGroupId {
                deleteRecurringGroup(groupId: groupId) {
                    // 削除完了後に新しい予定群を作成（元の予定の更新はスキップ）
                    self.createNewRecurringSchedulesOnly(
                        baseStartDate: startDate,
                        baseEndDate: endDate
                    )
                }
            } else {
                // 単発→繰り返しの場合、元の予定を更新してから追加予定を作成

                // FirestoreManagerの統一メソッドを使用
                var updatedSchedule = ScheduleItem(
                    id: schedule.id,
                    title: scheduleTitle,
                    isAllDay: isAllDay,
                    startDate: startDate,
                    endDate: endDate,
                    location: location,
                    tag: tag,
                    memo: memo,
                    repeatOption: repeatSettings.getDescription(for: startDate),
                    remindValue: 0,
                    remindUnit: "",
                    recurringGroupId: nil
                )
                // 通知設定をScheduleItemに設定
                updatedSchedule.notificationSettings = notificationSettings

                let firestoreManager = FirestoreManager()
                firestoreManager.updateSchedule(updatedSchedule) { success in
                    if success {
                        NotificationManager.shared.removeNotification(for: schedule.id)
                        self.createAdditionalRecurringSchedules(
                            baseStartDate: startDate,
                            baseEndDate: endDate
                        )
                        self.notifyScheduleUpdate()
                        DispatchQueue.main.async { dismiss() }
                    }
                }
                return
            }
        } else {
            // 繰り返し→単発または単発→単発の場合、通常の更新
            if let groupId = schedule.recurringGroupId {
                deleteOtherRecurringSchedules(groupId: groupId, keepScheduleId: schedule.id)
            }

            // FirestoreManagerの統一メソッドを使用
            var updatedSchedule = ScheduleItem(
                id: schedule.id,
                title: scheduleTitle,
                isAllDay: isAllDay,
                startDate: startDate,
                endDate: endDate,
                location: location,
                tag: tag,
                memo: memo,
                repeatOption: repeatSettings.getDescription(for: startDate),
                recurringGroupId: nil
            )
            // 通知設定をScheduleItemに設定
            updatedSchedule.notificationSettings = notificationSettings

            // FirestoreManagerの統一メソッドを使用（通知設定も含めて保存される）
            let firestoreManager = FirestoreManager()
            firestoreManager.updateSchedule(updatedSchedule) { success in
                if success {
                    // 新しい通知システムを使用
                    NotificationManager.shared.updateNotifications(for: updatedSchedule)
                    self.notifyScheduleUpdate()
                    DispatchQueue.main.async { dismiss() }
                }
            }
        }
    }

    // 新規作成（INSERT）処理
    private func createNewSchedule(startDate: Date, endDate: Date) {
        let db = Firestore.firestore()
        let scheduleRef = db.collection("users").document(userId).collection("schedules").document()

        let scheduleDoc: [String: Any] = [
            "id": scheduleRef.documentID,
            "title": scheduleTitle,
            "isAllDay": isAllDay,
            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: endDate),
            "location": location,
            "tag": tag,
            "memo": memo,
            "repeatOption": repeatSettings.getDescription(for: startDate),
            "created_at": Timestamp(date: Date())
        ]

        scheduleRef.setData(scheduleDoc) { error in
            if let error = error {
                print("❌ 予定の保存に失敗: \(error.localizedDescription)")
                return
            }

            // 保存成功後の処理
            DispatchQueue.main.async {
                // 通知設定
                let newSchedule = ScheduleItem(
                    id: scheduleRef.documentID,
                    title: self.scheduleTitle,
                    isAllDay: self.isAllDay,
                    startDate: startDate,
                    endDate: endDate,
                    location: self.location,
                    tag: self.tag,
                    memo: self.memo,
                    repeatOption: self.repeatSettings.getDescription(for: startDate),
                    recurringGroupId: nil,
                    notificationSettings: self.notificationSettings
                )

                NotificationManager.shared.updateNotifications(for: newSchedule)

                // カレンダーのリフレッシュを通知
                NotificationCenter.default.post(
                    name: .init("ScheduleAdded"),
                    object: nil
                )

                // 画面を閉じる
                dismiss()
            }
        }
    }

    // 既存の繰り返しグループを削除 (FirestoreManagerの統一メソッドを使用)
    private func deleteRecurringGroup(groupId: String, completion: @escaping () -> Void) {
        let firestoreManager = FirestoreManager()
        firestoreManager.deleteRecurringGroup(groupId: groupId) { success in
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    // 他の関連予定のみ削除（指定した予定は残す） (FirestoreManagerの統一メソッドを使用)
    private func deleteOtherRecurringSchedules(groupId: String, keepScheduleId: String) {
        let firestoreManager = FirestoreManager()
        firestoreManager.deleteOthersInGroup(groupId: groupId, keepScheduleId: keepScheduleId) { success in
            // 削除完了
        }
    }

    // 通知処理を共通化
    private func notifyScheduleUpdate() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .init("ScheduleAdded"),
                object: nil
            )
        }
    }

    // 新しい繰り返し予定群を作成（完全に新規作成、元予定のIDは使用しない）(FirestoreManagerの統一メソッドを使用)
    private func createNewRecurringSchedulesOnly(baseStartDate: Date, baseEndDate: Date) {
        let duration = baseEndDate.timeIntervalSince(baseStartDate)
        let recurringDates = repeatSettings.generateDates(from: baseStartDate)
        let newGroupId = UUID().uuidString

        var schedules: [ScheduleItem] = []

        // 全ての予定を完全に新規作成
        for date in recurringDates {
            let scheduleStartDate = date
            let scheduleEndDate = Date(timeInterval: duration, since: date)
            let scheduleId = UUID().uuidString // 全て新しいIDを使用

            var newSchedule = ScheduleItem(
                id: scheduleId,
                title: scheduleTitle,
                isAllDay: isAllDay,
                startDate: scheduleStartDate,
                endDate: scheduleEndDate,
                location: location,
                tag: tag,
                memo: memo,
                repeatOption: repeatSettings.getDescription(for: baseStartDate),
                recurringGroupId: newGroupId
            )

            // 通知設定をScheduleItemに設定
            newSchedule.notificationSettings = notificationSettings
            schedules.append(newSchedule)
        }

        // FirestoreManagerの統一メソッドを使用して一括作成
        isCreatingRecurringSchedules = true
        recurringTotal = schedules.count
        let firestoreManager = FirestoreManager()
        firestoreManager.createRecurringSchedules(schedules) { success in
            DispatchQueue.main.async {
                self.isCreatingRecurringSchedules = false
                self.notifyScheduleUpdate()
                dismiss()
            }
        }
    }

    // 新しい繰り返し予定群を作成（全て新規作成） (FirestoreManagerの統一メソッドを使用)
    private func createNewRecurringSchedules(baseStartDate: Date, baseEndDate: Date, updatedScheduleId: String) {
        let duration = baseEndDate.timeIntervalSince(baseStartDate)
        let recurringDates = repeatSettings.generateDates(from: baseStartDate)
        let newGroupId = UUID().uuidString

        var schedules: [ScheduleItem] = []

        // 全ての予定を新規作成（元の予定も含めて）
        for (index, date) in recurringDates.enumerated() {
            let scheduleStartDate = date
            let scheduleEndDate = Date(timeInterval: duration, since: date)

            // 最初の予定は既存のIDを使用、それ以外は新しいIDを生成
            let scheduleId = (index == 0) ? updatedScheduleId : UUID().uuidString

            var newSchedule = ScheduleItem(
                id: scheduleId,
                title: scheduleTitle,
                isAllDay: isAllDay,
                startDate: scheduleStartDate,
                endDate: scheduleEndDate,
                location: location,
                tag: tag,
                memo: memo,
                repeatOption: repeatSettings.getDescription(for: baseStartDate),
                recurringGroupId: newGroupId
            )

            // 通知設定をScheduleItemに設定
            newSchedule.notificationSettings = notificationSettings
            schedules.append(newSchedule)
        }

        // FirestoreManagerの統一メソッドを使用して一括作成
        isCreatingRecurringSchedules = true
        recurringTotal = schedules.count
        let firestoreManager = FirestoreManager()
        firestoreManager.createRecurringSchedules(schedules) { success in
            DispatchQueue.main.async {
                self.isCreatingRecurringSchedules = false
            }
        }
    }

    // 編集時に追加の繰り返し予定を作成（単発→繰り返し） (FirestoreManagerの統一メソッドを使用)
    private func createAdditionalRecurringSchedules(baseStartDate: Date, baseEndDate: Date) {
        let duration = baseEndDate.timeIntervalSince(baseStartDate)
        let recurringDates = repeatSettings.generateDates(from: baseStartDate)
        let groupId = UUID().uuidString

        var schedules: [ScheduleItem] = []

        // 全ての予定を作成（元の予定も含めて新しいグループIDで再作成）
        for date in recurringDates {
            let scheduleStartDate = date
            let scheduleEndDate = Date(timeInterval: duration, since: date)

            var newSchedule = ScheduleItem(
                id: UUID().uuidString,
                title: scheduleTitle,
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
            newSchedule.notificationSettings = notificationSettings
            schedules.append(newSchedule)
        }

        // FirestoreManagerの統一メソッドを使用して一括作成
        isCreatingRecurringSchedules = true
        recurringTotal = schedules.count
        let firestoreManager = FirestoreManager()
        firestoreManager.createRecurringSchedules(schedules) { success in
            DispatchQueue.main.async {
                self.isCreatingRecurringSchedules = false
            }
        }
    }
}

// プレビュー画面表示
struct ScheduleEditView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ScheduleEditView(schedule: ScheduleItem(
                id: "dummyId",
                title: "接骨院",
                isAllDay: false,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                location: "うう",
                tag: "忙しいなぁ",
                memo: "プライベート",
                repeatOption: "繰り返さない",
            ), userId: "preview_user_id")
            .environmentObject(FontSettingsManager.shared)
        }
    }
}
