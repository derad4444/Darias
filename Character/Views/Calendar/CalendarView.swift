import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import UniformTypeIdentifiers

// 吹き出しの尻尾用Triangle
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

// 期間予定バー用のカスタムShape（週またぎでの位置を正確に揃える）
struct ScheduleBarShape: Shape {
    let isStart: Bool
    let isEnd: Bool
    let cornerRadius: CGFloat = 3
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // 開始位置と終了位置に応じて角丸を適用
        if isStart && isEnd {
            // 1日だけの予定：すべての角を丸くする
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        } else if isStart {
            // 開始セグメント：左側の角のみ丸くする
            path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius), control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        } else if isEnd {
            // 終了セグメント：右側の角のみ丸くする
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius), control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        } else {
            // 中間セグメント：角丸なしの長方形
            path.addRect(rect)
        }
        
        return path
    }
}


struct CalendarView: View {
    @StateObject private var firestoreManager = FirestoreManager()
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @ObservedObject var tagSettings = TagSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var showPicker = false
    @State private var selectedDate: Date = Date()
    @State private var showBottomSheet = false
    @State private var characterExpression: CharacterExpression = .normal
    @State private var characterGender: CharacterGender?
    @State private var monthlyComment: String = "今月のひとことを読み込み中..."
    @State private var isLoadingComment = true
    @State private var isCalendarViewActive = false
    @State private var isHolidaysLoaded = false
    @State private var showSearchMode = false
    @State private var searchText = ""
    
    // ドラッグ&ドロップ用状態変数（一時的に無効化）
    // @State private var draggingSchedule: Schedule?
    // @State private var dragOffset: CGSize = .zero
    // @State private var isDragMode = false
    
    let calendar = Calendar.current
    var userId: String
    var characterId: String
    var isPremium: Bool
    
    init(userId: String, characterId: String, isPremium: Bool) {
        self.userId = userId
        self.characterId = characterId
        self.isPremium = isPremium

        // UserDefaultsから前回表示していた年月を復元、なければ現在の年月
        let savedYear = UserDefaults.standard.object(forKey: "CalendarLastViewedYear") as? Int
        let savedMonth = UserDefaults.standard.object(forKey: "CalendarLastViewedMonth") as? Int

        if let year = savedYear, let month = savedMonth {
            self._selectedYear = State(initialValue: year)
            self._selectedMonth = State(initialValue: month)
        } else {
            let now = Date()
            self._selectedYear = State(initialValue: Calendar.current.component(.year, from: now))
            self._selectedMonth = State(initialValue: Calendar.current.component(.month, from: now))
        }
    }

    private func dynamicHeaderHeight(for screenHeight: CGFloat) -> CGFloat {
        return screenHeight * 0.075
    }
    
    // ある日の予定一覧取得（期間予定に対応）
    func schedulesForDate(_ date: Date) -> [Schedule] {
        firestoreManager.schedules.filter { schedule in
            let calendar = Calendar.current

            // 指定された日付がスケジュールの期間内にあるかチェック
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            // スケジュールの開始日と終了日の範囲と重複するかチェック
            return schedule.startDate < endOfDay && schedule.endDate >= startOfDay
        }
    }

    // 検索フィルタリング
    private var filteredSchedules: [Schedule] {
        if searchText.isEmpty {
            return firestoreManager.schedules
        }
        return firestoreManager.schedules.filter { schedule in
            schedule.title.localizedCaseInsensitiveContains(searchText) ||
            schedule.memo.localizedCaseInsensitiveContains(searchText) ||
            schedule.tag.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func moveToNextMonth() {
        var newMonth = selectedMonth + 1
        var newYear = selectedYear
        if newMonth > 12 {
            newMonth = 1
            newYear += 1
        }
        selectedMonth = newMonth
        selectedYear = newYear
        saveCurrentViewedMonth()
    }
    
    private func moveToPreviousMonth() {
        var newMonth = selectedMonth - 1
        var newYear = selectedYear
        if newMonth < 1 {
            newMonth = 12
            newYear -= 1
        }
        selectedMonth = newMonth
        selectedYear = newYear
        saveCurrentViewedMonth()
    }
    
    // MARK: - Character Expression Functions
    private func getCharacterImageName() -> String? {
        guard let gender = characterGender else { return nil }
        let genderPrefix = "character_\(gender.rawValue)"
        switch characterExpression {
        case .normal:
            return genderPrefix
        case .smile:
            return "\(genderPrefix)_smile"
        case .angry:
            return "\(genderPrefix)_angry"
        case .cry:
            return "\(genderPrefix)_cry"
        case .sleep:
            return "\(genderPrefix)_sleep"
        }
    }
    
    private func triggerRandomExpression() {
        let expressions: [CharacterExpression] = [.normal, .smile, .angry, .cry, .sleep]
        let availableExpressions = expressions.filter { $0 != characterExpression }
        characterExpression = availableExpressions.randomElement() ?? .smile
    }
    
    // 年をカンマなしでフォーマットする関数
    private func formatYearWithoutComma(_ year: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.groupingSeparator = ""
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: year)) ?? "\(year)"
    }
    
    // 月次コメントを取得する関数
    private func fetchMonthlyComment() {
        guard !characterId.isEmpty, !userId.isEmpty else {
            // デフォルトメッセージを設定
            self.monthlyComment = "今月もあなたらしく、素敵な時間を過ごしてくださいね！新しい発見や楽しい出来事があることを願っています。"
            self.isLoadingComment = false
            return
        }

        let year = selectedYear
        let month = String(format: "%02d", selectedMonth)
        let monthId = "\(year)-\(month)"

        isLoadingComment = true


        let db = Firestore.firestore()
        db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("monthlyComments").document(monthId)
            .getDocument { document, error in
                DispatchQueue.main.async {
                    self.isLoadingComment = false

                    if let error = error {
                        self.monthlyComment = "今月のひとことを取得できませんでした。"
                        return
                    }

                    if let document = document, document.exists,
                       let data = document.data(),
                       let comment = data["comment"] as? String {
                        self.monthlyComment = comment
                    } else {
                        // フォールバック用デフォルトメッセージ
                        self.monthlyComment = "今月もあなたらしく、素敵な時間を過ごしてくださいね！新しい発見や楽しい出来事があることを願っています。"
                    }
                }
            }
    }
    
    // 現在の表示月をUserDefaultsに保存
    private func saveCurrentViewedMonth() {
        UserDefaults.standard.set(selectedYear, forKey: "CalendarLastViewedYear")
        UserDefaults.standard.set(selectedMonth, forKey: "CalendarLastViewedMonth")
    }
    
    // 現在の月にジャンプする関数
    func jumpToCurrentMonth() {
        let now = Date()
        let currentYear = Calendar.current.component(.year, from: now)
        let currentMonth = Calendar.current.component(.month, from: now)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedYear = currentYear
            selectedMonth = currentMonth
        }
        
        saveCurrentViewedMonth()
        fetchMonthlyComment()
    }
    
    // 初期データを順次読み込み（祝日を最初に読み込む）
    private func loadInitialData() {
        // 祝日を最初に読み込む
        firestoreManager.fetchHolidays { [self] in
            isHolidaysLoaded = true

            // 他のデータを読み込み
            firestoreManager.fetchSchedules()

            // characterIdが空でない場合のみ日記を取得
            if !characterId.isEmpty {
                firestoreManager.fetchDiaries(characterId: characterId)
            } else {
            }

            fetchMonthlyComment()
            loadCharacterGender()
        }
    }

    private func loadCharacterGender() {
        let db = Firestore.firestore()
        let detailsRef = db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("details").document("current")

        detailsRef.getDocument { document, error in
            if let data = document?.data(),
               let genderString = data["gender"] as? String {
                DispatchQueue.main.async {
                    if genderString == "男性" {
                        characterGender = .male
                    } else {
                        characterGender = .female
                    }
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                // 画面高さに応じてカレンダー高さを調整（小さい画面では固定値で制限）
                let calendarHeight: CGFloat = geometry.size.height < 700 ? min(geometry.size.height * 0.36, 520) : geometry.size.height * 0.45
                let headerHeight = dynamicHeaderHeight(for: geometry.size.height)

                VStack(spacing: 0) {

                ZStack {
                    //背景
                    colorSettings.getCurrentBackgroundGradient()
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                            // ヘッダー（検索モードと通常モードで切り替え）
                            if showSearchMode {
                                // 検索モード用ヘッダー
                                HStack(spacing: 12) {
                                    // 戻るボタン
                                    Button(action: {
                                        withAnimation {
                                            showSearchMode = false
                                            searchText = ""
                                        }
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: geometry.size.height < 700 ? 18 : 20))
                                            .foregroundColor(colorSettings.getCurrentTextColor())
                                    }
                                    .padding(.leading, 16)

                                    // 検索バー
                                    HStack(spacing: 8) {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.gray)
                                            .font(.system(size: geometry.size.height < 700 ? 14 : 16))

                                        TextField("予定を検索", text: $searchText)
                                            .font(.system(size: geometry.size.height < 700 ? 14 : 16))

                                        // クリアボタン
                                        if !searchText.isEmpty {
                                            Button(action: {
                                                withAnimation {
                                                    searchText = ""
                                                }
                                                // キーボードを閉じる
                                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray.opacity(0.6))
                                                    .font(.system(size: geometry.size.height < 700 ? 14 : 16))
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(10)
                                    .padding(.trailing, 16)
                                }
                                .frame(height: headerHeight)
                                .padding(.top, geometry.size.height < 700 ? -5 : -20)
                                .background(Color.clear)
                                .offset(
                                    x: 0,
                                    y: geometry.size.height < 700 ? 15 : 0
                                )
                                .zIndex(1)
                            } else {
                                // 通常モード用ヘッダー
                                HStack {
                                    Button(action: {
                                        moveToPreviousMonth()
                                    }) {
                                        Image(systemName: "chevron.left")
                                            .font(FontSettingsManager.shared.font(size: 22, weight: .bold))
                                            .foregroundColor(colorSettings.getCurrentTextColor())
                                            .padding(.leading, 16)
                                    }
                                    Spacer()
                                    Button(action: { showPicker.toggle() }) {
                                        Text("\(formatYearWithoutComma(selectedYear))年 \(selectedMonth)月")
                                            .dynamicTitle2()
                                            .foregroundColor(colorSettings.getCurrentTextColor())
                                    }
                                    Spacer()
                                    Button(action: {
                                        moveToNextMonth()
                                    }) {
                                        Image(systemName: "chevron.right")
                                            .font(FontSettingsManager.shared.font(size: 22, weight: .bold))
                                            .foregroundColor(colorSettings.getCurrentTextColor())
                                    }
                                    .padding(.trailing, geometry.size.height < 700 ? 50 : 60) // 検索ボタン分のスペースを確保
                                }
                                .frame(height: headerHeight)
                                .padding(.top, -20)
                                .background(Color.clear)
                                .padding(.horizontal)
                                .offset(
                                    x: geometry.size.height < 700 ? 0 : -10,
                                    y: geometry.size.height < 700 ? 15 : 0
                                )
                                .zIndex(1)
                                .overlay(
                                    // 検索ボタンを右上にオーバーレイ
                                    Button(action: {
                                        withAnimation {
                                            showSearchMode = true
                                        }
                                    }) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: geometry.size.height < 700 ? 16 : 18))
                                            .foregroundColor(colorSettings.getCurrentAccentColor())
                                            .padding(geometry.size.height < 700 ? 8 : 10)
                                            .background(
                                                Circle()
                                                    .fill(Color.white.opacity(0.9))
                                                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                            )
                                    }
                                    .padding(.trailing, geometry.size.height < 700 ? 8 : 16)
                                    .offset(y: geometry.size.height < 700 ? 10 : -10),
                                    alignment: .topTrailing
                                )
                            }

                            // カレンダー本体または検索結果
                            if showSearchMode {
                                // 検索結果リスト
                                if filteredSchedules.isEmpty {
                                    VStack(spacing: 16) {
                                        Spacer()
                                        Image(systemName: searchText.isEmpty ? "calendar" : "magnifyingglass")
                                            .font(.system(size: 50))
                                            .foregroundColor(.gray.opacity(0.5))
                                        Text(searchText.isEmpty ? "予定を検索してください" : "検索結果がありません")
                                            .dynamicTitle3()
                                            .foregroundColor(.gray)
                                        if !searchText.isEmpty {
                                            Text("「\(searchText)」に一致する予定が見つかりませんでした")
                                                .dynamicCaption()
                                                .foregroundColor(.gray)
                                                .multilineTextAlignment(.center)
                                                .padding(.horizontal, 32)
                                        }
                                        Spacer()
                                    }
                                } else {
                                    ScrollView {
                                        VStack(spacing: 12) {
                                            ForEach(filteredSchedules.sorted(by: { $0.startDate < $1.startDate })) { schedule in
                                                ScheduleSearchResultCard(schedule: schedule, colorSettings: colorSettings)
                                                    .onTapGesture {
                                                        selectedDate = schedule.startDate
                                                        showSearchMode = false
                                                        searchText = ""
                                                        showBottomSheet = true
                                                    }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.top, 12)
                                        .padding(.bottom, 100)
                                    }
                                }
                            } else {
                                // 通常のカレンダー表示
                                CustomCalendarView(
                                    selectedDate: $selectedDate,
                                    selectedYear: $selectedYear,
                                    selectedMonth: $selectedMonth,
                                    schedulesForDate: self.schedulesForDate,
                                    firestoreManager: firestoreManager,
                                    userId: userId,
                                    showBottomSheet: $showBottomSheet,
                                    screenHeight: geometry.size.height
                                )
                                .frame(height: calendarHeight)
                                .frame(maxWidth: .infinity)
                            }

                        Spacer()
                    }
                    // オーバーレイ表示
                    .overlay(
                        Group {
                            if showPicker {
                                YearMonthInlinePickerView(selectedYear: $selectedYear, selectedMonth: $selectedMonth) {
                                    showPicker = false
                                }
                                .padding(.top, headerHeight)
                                .transition(.move(edge: .top))
                            }
                        }, alignment: .top
                    )
                    
                    // スライダー表示（ZStack内）
                    if showBottomSheet {
                        BottomSheetView(
                            date: $selectedDate,
                            schedules: schedulesForDate(selectedDate),
                            characterId: characterId,
                            userId: userId,
                            closeAction: { showBottomSheet = false }
                        )
                        .environmentObject(firestoreManager)
                        .zIndex(2)
                    }
                    
                    // 左下にキャラクター画像と吹き出しを配置
                    VStack {
                        Spacer()
                        HStack(alignment: .bottom, spacing: geometry.size.width < 400 ? -15 : 5) {
                            // キャラクター画像（Assets内の画像を使用）
                            if let imageName = getCharacterImageName() {
                                Image(imageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 150, height: 150)
                                    .onTapGesture {
                                        triggerRandomExpression()
                                    }
                            } else {
                                // 性別情報読み込み中
                                ProgressView()
                                    .frame(width: 150, height: 150)
                            }

                            // 当月コメントの吹き出し
                            VStack(alignment: .leading, spacing: 4) {
                                Text("今月のひとこと")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                if isLoadingComment {
                                    Text("今月のひとことを読み込み中...")
                                        .font(.body)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.leading)
                                } else {
                                    Text(monthlyComment)
                                        .font(.body)
                                        .foregroundColor(.black)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(16)
                            .overlay(
                                // 吹き出しの尻尾（左側）
                                Triangle()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 12, height: 8)
                                    .rotationEffect(.degrees(90))
                                    .offset(x: -18, y: 0),
                                alignment: .leading
                            )
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            .frame(width: 260)

                            Spacer()
                        }
                        .padding(.leading, geometry.size.width < 400 ? -20 : -20) // 小さい画面では更に左にずらす
                        .padding(.bottom, 10)
                    }
                    .allowsHitTesting(false) // タッチイベントを無効化
                }
            }
            }
        }
        .onAppear {
            // 祝日を最初に読み込んでから他のデータを読み込む
            loadInitialData()
            showBottomSheet = false
            isCalendarViewActive = true  // カレンダー画面がアクティブ
        }
        .onDisappear {
            isCalendarViewActive = false  // カレンダー画面が非アクティブ
        }
        .onChange(of: selectedYear) { _ in
            saveCurrentViewedMonth()  // UserDefaultsに保存
            fetchMonthlyComment()  // 年が変わったときに再取得
        }
        .onChange(of: selectedMonth) { _ in
            saveCurrentViewedMonth()  // UserDefaultsに保存
            fetchMonthlyComment()  // 月が変わったときに再取得
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ScheduleAdded"))) { _ in
            firestoreManager.fetchSchedules()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ScheduleDeleted"))) { notification in
            // 単一予定削除の場合
            if let scheduleId = notification.userInfo?["scheduleId"] as? String {
                firestoreManager.schedules.removeAll { $0.id == scheduleId }
            }
            // 繰り返し予定グループ削除の場合
            else if let recurringGroupId = notification.userInfo?["recurringGroupId"] as? String {
                firestoreManager.schedules.removeAll { $0.recurringGroupId == recurringGroupId }
            }
            // 安全のため、全体を再取得
            else {
                firestoreManager.fetchSchedules()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("CalendarTabTapped"))) { _ in
            // カレンダータブがタップされた際の処理
            // カレンダー画面がアクティブな状態でカレンダータブがタップされた場合のみジャンプ
            if isCalendarViewActive {
                jumpToCurrentMonth()
            } else {
            }
        }
    }
}

//月カレンダー表示設定
struct CustomCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int
    var schedulesForDate: (Date) -> [Schedule]
    @ObservedObject var firestoreManager: FirestoreManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @ObservedObject var tagSettings = TagSettingsManager.shared
    let userId: String

    @State private var dragOffsetX: CGFloat = 0
    @State private var isDragging: Bool = false

    @Binding var showBottomSheet: Bool
    let screenHeight: CGFloat

    let calendar = Calendar.current
    let today = Date()

    private var dynamicCellHeight: CGFloat {
        return 80 // 固定に戻す
    }
    
    var body: some View {
        let components = DateComponents(year: selectedYear, month: selectedMonth)
        let firstDayOfMonth = calendar.date(from: components)!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)

        VStack(spacing: 8) {
            // 曜日ヘッダーを固定表示
            let gridColumns = Array(repeating: GridItem(.flexible()), count: 7)
            LazyVGrid(columns: gridColumns) {
                let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .dynamicCaption()
                        .foregroundColor(.primary)
                        .fontWeight(.semibold)
                }
            }
            .padding(.bottom, 4)

            // スワイプ可能な日付グリッド部分
            GeometryReader { geometry in
                let screenWidth = geometry.size.width

                ZStack {
                    monthView(for: currentComponents())
                        .offset(x: dragOffsetX)
                    monthView(for: nextComponents())
                        .offset(x: dragOffsetX + (dragOffsetX > 0 ? -screenWidth : screenWidth))
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffsetX = value.translation.width
                            isDragging = true
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                if value.translation.width < -100 {
                                    moveToNextMonth()
                                } else if value.translation.width > 100 {
                                    moveToPreviousMonth()
                                }
                                dragOffsetX = 0
                                isDragging = false
                            }
                        }
                )
            }
        }
    }
    
    // 日付の色を変更
    private func colorForDate(date: Date) -> Color {
        let isCurrentMonth = calendar.component(.month, from: date) == selectedMonth
        let weekday = calendar.component(.weekday, from: date)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let isHoliday = firestoreManager.holidays.contains { $0.dateString == dateString }
        
        // 当月以外の日付を薄くする
        if !isCurrentMonth { return Color.secondary }
        // 祝日を赤
        else if isHoliday { return .red }
        // 日曜を赤
        else if weekday == 1 { return .red }
        // 土曜を青
        else if weekday == 7 { return .blue }
        else { return Color.primary }
    }
    
    //　スライドで次月移動
    private func moveToNextMonth() {
        var newMonth = selectedMonth + 1
        var newYear = selectedYear
        if newMonth > 12 {
            newMonth = 1
            newYear += 1
        }
        selectedMonth = newMonth
        selectedYear = newYear
    }
    
    //　スライドで前月移動
    private func moveToPreviousMonth() {
        var newMonth = selectedMonth - 1
        var newYear = selectedYear
        if newMonth < 1 {
            newMonth = 12
            newYear -= 1
        }
        selectedMonth = newMonth
        selectedYear = newYear
    }
    
    // 月のカレンダー描画View
    @ViewBuilder
    private func monthView(for components: DateComponents) -> some View {
        let firstDayOfMonth = calendar.date(from: components)!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let gridColumns = Array(repeating: GridItem(.flexible()), count: 7)

        // 日付セルのみ（曜日ヘッダーは外側で固定表示）
        GeometryReader { geometry in
            ZStack {
                LazyVGrid(columns: gridColumns, spacing: 0) {
                    ForEach(Array(0..<42), id: \.self) { index in
                        calendarDateView(
                            index: index,
                            firstDayOfMonth: firstDayOfMonth,
                            firstWeekday: firstWeekday
                        )
                    }
                }

                // 期間予定をオーバーレイとして表示（連続バー表示用）
                multiDaySchedulesOverlay(for: components, geometry: geometry)

                // ドラッグ中のドロップゾーンオーバーレイ（一時的に無効化）
                // if isDragModeLocal {
                //     Color.clear
                //         .contentShape(Rectangle())
                //         .onDrop(of: [UTType.text], isTargeted: nil) { providers, location in
                //             if let draggingSchedule = draggingScheduleLocal,
                //                let targetDate = dateFromDropPosition(location, geometry: geometry) {
                //                 moveScheduleToDate(schedule: draggingSchedule, targetDate: targetDate)
                //             }
                //
                //             // ドラッグ状態をリセット
                //             withAnimation(.easeOut(duration: 0.3)) {
                //                 dragOffset = .zero
                //                 self.draggingSchedule = nil
                //                 self.isDragMode = false
                //             }
                //             return true
                //         }
                // }
            }
            .compositingGroup()
            .drawingGroup()
        }
        .padding(.horizontal)
    }
    
    // 日付セル表示ビュー
    @ViewBuilder
    private func calendarDateView(index: Int, firstDayOfMonth: Date, firstWeekday: Int) -> some View {
        let offset = index - (firstWeekday - 1)
        let date = calendar.date(byAdding: .day, value: offset, to: firstDayOfMonth)!
        let dateString = formattedDateString(date)
        let holiday = firestoreManager.holidays.first(where: { $0.dateString == dateString })
        
        GeometryReader { geometry in
            ZStack {
                // 背景全体をタップ可能にする
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // ハプティックフィードバック
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()

                        selectedDate = date
                        showBottomSheet = true
                    }
                    .onLongPressGesture {
                        // 長押しでハプティックフィードバック
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()

                        // プレビュー用の選択状態更新
                        selectedDate = date
                    }

                // 日付部分を最上部に絶対位置で固定配置
                let isToday = calendar.isDate(date, inSameDayAs: Date())
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

                Circle()
                    .fill(isSelected ? colorSettings.getCurrentAccentColor() : .clear)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 12))
                            .foregroundColor(
                                isSelected ? .white : colorForDate(date: date)
                            )
                            .fontWeight(isToday ? .bold : .regular)
                    )
                    .overlay(
                        // 今日の日付に枠線を追加
                        Circle()
                            .stroke(
                                isToday ? colorSettings.getCurrentAccentColor() : Color.clear,
                                lineWidth: isToday ? 1.5 : 0
                            )
                            .frame(width: 34, height: 34)
                    )
                    .position(x: geometry.size.width / 2, y: 16) // セル幅の中央、上から16px
                    .allowsHitTesting(false) // タップを透過
                
                // 祝日を上部に固定表示
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 27) // 日付の下
                    let holiday = firestoreManager.holidays.first(where: { $0.dateString == formattedDateString(date) })
                    if let holiday = holiday {
                        holidayItemView(holiday: holiday)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer()
                }
                .zIndex(15) // 最前面に表示
                .allowsHitTesting(false) // タップを透過

                // 予定表示エリア
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 28) // 固定オフセット（調整）
                    regularScheduleView(for: date)
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
                .allowsHitTesting(false) // タップを透過
            }
        }
        .frame(height: dynamicCellHeight) // 画面サイズに応じた高さ
        .frame(maxWidth: .infinity, maxHeight: .infinity) // セル全体を埋める
    }
    
    // 今選択されている年月をDateComponentsという日付構造体に変換
    private func currentComponents() -> DateComponents {
        return DateComponents(year: selectedYear, month: selectedMonth)
    }
    
    //スワイプで次月、前月表示
    private func nextComponents() -> DateComponents {
        var year = selectedYear
        var month = selectedMonth
        
        if dragOffsetX < 0 {
            // 右にスワイプ → 次月
            month += 1
            if month > 12 {
                month = 1
                year += 1
            }
        } else if dragOffsetX > 0 {
            // 左にスワイプ → 前月
            month -= 1
            if month < 1 {
                month = 12
                year -= 1
            }
        }
        return DateComponents(year: year, month: month)
    }
    
    // ドロップ位置から日付を計算
    private func dateFromDropPosition(_ location: CGPoint, geometry: GeometryProxy) -> Date? {
        let cellWidth = (geometry.size.width - 6 * 8) / 7
        let cellHeight = dynamicCellHeight
        let headerHeight: CGFloat = 30 // 曜日ヘッダーの高さ
        
        // Y座標から週を計算
        let adjustedY = location.y - headerHeight
        guard adjustedY >= 0 else { return nil }
        let weekRow = Int(adjustedY / cellHeight)
        
        // X座標から曜日を計算
        let dayInWeek = Int(location.x / (cellWidth + 8))
        guard dayInWeek >= 0 && dayInWeek < 7 else { return nil }
        
        // 日付を計算
        let firstDayOfMonth = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth))!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let totalDayIndex = weekRow * 7 + dayInWeek
        let offset = totalDayIndex - (firstWeekday - 1)
        
        return calendar.date(byAdding: .day, value: offset, to: firstDayOfMonth)
    }
    
    
    // 通常予定表示ビュー（祝日と予定を合わせて最大3件表示）
    @ViewBuilder
    private func regularScheduleView(for date: Date) -> some View {
        let dateString = formattedDateString(date)
        let holiday = firestoreManager.holidays.first(where: { $0.dateString == dateString })
        
        let regularSchedules = schedulesForDate(date)
            .filter { !$0.isMultiDay }
            .sorted { $0.startDate < $1.startDate }
        
        // この日の表示制限を計算（祝日・期間予定・通常予定合計3件まで）
        let dateStr = formattedDateString(date)
        let hasHoliday = firestoreManager.holidays.contains { $0.dateString == dateStr }
        
        // multiDaySchedulesOverlayと同じソート済みリストを使用して一貫性を保つ
        let allMultiDaySchedules = firestoreManager.schedules
            .filter { $0.isMultiDay }
            .sorted { $0.startDate < $1.startDate }
        
        let multiDaySchedulesForDate = allMultiDaySchedules.filter { schedule in
            let scheduleStart = calendar.startOfDay(for: schedule.startDate)
            let scheduleEnd = calendar.startOfDay(for: schedule.endDate)
            let currentDay = calendar.startOfDay(for: date)
            return currentDay >= scheduleStart && currentDay <= scheduleEnd
        }
        
        // 終日予定と時間指定予定を分離
        let allDaySchedules = regularSchedules.filter { $0.isAllDay }
        let timedSchedules = regularSchedules.filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }
        
        // 利用可能スロット数を計算（全体2件から祝日と期間予定を引く）
        let holidayCount = hasHoliday ? 1 : 0
        let multiDayCount = min(multiDaySchedulesForDate.count, 2 - holidayCount)
        let fixedSlots = max(0, 2 - holidayCount - multiDayCount)
        
        let totalRegularSchedules = allDaySchedules.count + timedSchedules.count
        
        // 3行目の条件分岐表示用の計算
        let actualMultiDayCount = multiDaySchedulesForDate.count
        let totalItems = holidayCount + actualMultiDayCount + totalRegularSchedules
        
        
        
        return VStack(alignment: .leading, spacing: 2) {
            // ①祝日は別の場所で表示される（セル上部に固定表示）

            // ②期間予定はオーバーレイで表示されるため、その分のスペースを確保
            let displayedMultiDayCount = min(multiDaySchedulesForDate.count, max(0, 2 - holidayCount))
            
            // 期間予定の分だけSpacerで空間を確保
            ForEach(0..<displayedMultiDayCount, id: \.self) { index in
                Spacer().frame(height: 16)
            }
            
            // ③通常予定を表示（期間予定と祝日で使用された分を除く）
            let remainingSlots = max(0, 2 - displayedMultiDayCount - holidayCount)
            let regularSchedulesToShow = allDaySchedules + timedSchedules
            
            // 祝日がある場合は1個目の予定のみ位置を調整
            VStack(alignment: .leading, spacing: 2) {
                ForEach(0..<min(remainingSlots, regularSchedulesToShow.count), id: \.self) { index in
                    let schedule = regularSchedulesToShow[index]
                    regularScheduleItemView(schedule: schedule)
                        .offset(y: hasHoliday && index == 0 ? 18 : 0) // 祝日がある場合は1個目のみ下にずらして重複を避ける
                }
            }
            
            // 空のスロットを埋める
            let totalDisplayed = displayedMultiDayCount + min(remainingSlots, regularSchedulesToShow.count)
            if totalDisplayed < 2 {
                ForEach(totalDisplayed..<2, id: \.self) { _ in
                    Spacer().frame(height: 16)
                }
            }

            // 3行目の条件分岐表示
            if totalItems > 2 {
                if totalItems == 3 {
                    // 合計3件の場合、3件目の予定を表示
                    
                    // 3件目が期間予定の場合はSpacerで空間確保（オーバーレイで表示）
                    // 3件目が通常予定の場合は直接表示
                    if displayedMultiDayCount < multiDaySchedulesForDate.count {
                        // 3件目が期間予定の場合
                        Spacer().frame(height: 16)
                    } else if remainingSlots < regularSchedulesToShow.count {
                        // 3件目が通常予定の場合
                        let thirdRegularIndex = remainingSlots
                        if thirdRegularIndex < regularSchedulesToShow.count {
                            regularScheduleItemView(schedule: regularSchedulesToShow[thirdRegularIndex])
                        }
                    }
                } else {
                    // 合計4件以上の場合、残り件数を表示

                    Button {
                        // ハプティックフィードバック
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()

                        selectedDate = date
                        showBottomSheet = true
                    } label: {
                        Text("+\(totalItems - 3)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .frame(height: 16)
                    }
                }
            }
        }
    }

    // 予定表示アイテムの種類
    private enum DisplayItem {
        case holiday(Holiday)
        case schedule(Schedule)
    }
    
    // 優先順位に従って予定を並び替え（①祝日②終日予定③1日予定④時間指定予定）
    private func prioritizeSchedules(
        regularSchedules: [Schedule],
        multiDaySchedules: [Schedule],
        holiday: Holiday?
    ) -> [DisplayItem] {
        var items: [DisplayItem] = []
        
        // ①祝日を最優先
        if let holiday = holiday {
            items.append(.holiday(holiday))
        }
        
        // ②期間予定はバー表示のみなので、1日予定リストからは除外
        
        // ③④通常予定を終日→時間指定の順で追加
        let sortedRegularSchedules = regularSchedules.sorted { first, second in
            // 終日予定を優先
            if first.isAllDay != second.isAllDay {
                return first.isAllDay && !second.isAllDay
            }
            // 同じタイプの場合は開始時間順
            return first.startDate < second.startDate
        }
        
        for schedule in sortedRegularSchedules {
            items.append(.schedule(schedule))
        }
        
        return items
    }
    
    // 祝日アイテム表示ビュー
    @ViewBuilder
    private func holidayItemView(holiday: Holiday) -> some View {
        Text(holiday.name)
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.red.opacity(0.8))
            .cornerRadius(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 16)
    }
    
    // 通常予定アイテム表示ビュー（タイトルのみ表示）
    @ViewBuilder
    private func regularScheduleItemView(schedule: Schedule) -> some View {
        let tagColor = tagSettings.getTag(by: schedule.tag)?.color ?? Color.blue

        // NavigationLinkを削除してタップ無効化
        Group {
            if schedule.isAllDay {
                // 終日予定：タイトルのみ、背景あり（セル全幅固定）
                Text(schedule.title.prefix(30))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(tagColor)
                    .cornerRadius(4)
            } else {
                // 時間指定予定：タイトルのみ、背景なし（文字色のみ）
                Text(schedule.title.prefix(30))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(tagColor)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 16) // コンパクトな高さに調整
        .allowsHitTesting(false) // タップを無効化
        // .simultaneousGesture(
        //     DragGesture()
        //         .onChanged { value in
        //             if draggingSchedule?.id == schedule.id {
        //                 dragOffset = value.translation
        //             }
        //         }
        //         .onEnded { value in
        //             if draggingSchedule?.id == schedule.id {
        //                 // ドラッグ状態をリセット（ドロップゾーンで処理される）
        //                 withAnimation(.easeOut(duration: 0.3)) {
        //                     dragOffset = .zero
        //                     draggingSchedule = nil
        //                     isDragMode = false
        //                 }
        //             }
        //         }
        // )
        // .onDrag {
        //     // ドラッグ可能なアイテムとして提供
        //     NSItemProvider(object: schedule.title as NSString)
        // }
    }
    
    // 日付変更処理
    private func moveScheduleToDate(schedule: Schedule, targetDate: Date) {
        guard let startDate = calculateNewStartDate(for: schedule, targetDate: targetDate) else {
            return
        }
        
        firestoreManager.updateScheduleDates(scheduleId: schedule.id, newStartDate: startDate) { success in
            DispatchQueue.main.async {
                if success {
                    // 成功時のハプティックフィードバック
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)
                    
                    // データを再取得
                    firestoreManager.fetchSchedules()
                } else {
                    // 失敗時のハプティックフィードバック
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                }
            }
        }
    }
    
    // 新しい開始日を計算
    private func calculateNewStartDate(for schedule: Schedule, targetDate: Date) -> Date? {
        let calendar = Calendar.current
        
        // 元の時刻を保持して新しい日付に設定
        let originalComponents = calendar.dateComponents([.hour, .minute, .second], from: schedule.startDate)
        var newComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
        newComponents.hour = originalComponents.hour
        newComponents.minute = originalComponents.minute
        newComponents.second = originalComponents.second
        
        return calendar.date(from: newComponents)
    }
    
    
    // 期間予定をオーバーレイとして表示
    @ViewBuilder
    private func multiDaySchedulesOverlay(for components: DateComponents, geometry: GeometryProxy) -> some View {
        let firstDayOfMonth = calendar.date(from: components)!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)

        // カレンダーグリッドで実際に表示される日付範囲を計算（前月・翌月の日付も含む）
        let startOffset = (firstWeekday - 1 + 7) % 7
        let firstDisplayDate = calendar.date(byAdding: .day, value: -startOffset, to: firstDayOfMonth)!
        let lastDisplayDate = calendar.date(byAdding: .day, value: 41, to: firstDisplayDate)!

        let multiDaySchedules = firestoreManager.schedules
            .filter { $0.isMultiDay }
            .filter { schedule in
                // 期間予定が実際に表示される日付範囲と重複するかチェック
                let scheduleStart = calendar.startOfDay(for: schedule.startDate)
                let scheduleEnd = calendar.startOfDay(for: schedule.endDate)
                let overlaps = (scheduleStart <= lastDisplayDate && scheduleEnd >= firstDisplayDate)


                return overlaps
            }
            .sorted { $0.startDate < $1.startDate }

        let cellWidth = (geometry.size.width - 6 * 8) / 7 // spacing 8
        let cellHeight = dynamicCellHeight

        ForEach(Array(multiDaySchedules.enumerated()), id: \.element.id) { index, schedule in
            let tagColor = tagSettings.getTag(by: schedule.tag)?.color ?? Color.blue

            // 期間予定の各週での表示を計算（期間予定のみでの連番インデックスを使用）
            let scheduleRows = getScheduleDisplayRows(
                for: schedule,
                firstDayOfMonth: firstDayOfMonth,
                firstWeekday: firstWeekday,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                scheduleIndex: index, // 期間予定内での連番（0から開始）
                totalScheduleCount: multiDaySchedules.count,
                allMultiDaySchedules: multiDaySchedules,
                geometry: geometry
            )

            scheduleRowsGroup(
                schedule: schedule,
                scheduleRows: scheduleRows,
                tagColor: tagColor,
                firstDayOfMonth: firstDayOfMonth,
                firstWeekday: firstWeekday,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                index: index,
                totalScheduleCount: multiDaySchedules.count,
                allMultiDaySchedules: multiDaySchedules,
                geometry: geometry
            )
        }
    }
    
    @ViewBuilder
    private func scheduleRowsGroup(
        schedule: Schedule,
        scheduleRows: [ScheduleDisplayRow],
        tagColor: Color,
        firstDayOfMonth: Date,
        firstWeekday: Int,
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        index: Int,
        totalScheduleCount: Int,
        allMultiDaySchedules: [Schedule],
        geometry: GeometryProxy
    ) -> some View {
        Group {
            ForEach(Array(0..<scheduleRows.count), id: \.self) { rowIndex in
                multiDayScheduleRowView(
                    schedule: schedule, 
                    row: scheduleRows[rowIndex], 
                    tagColor: tagColor
                )
            }
            
            scheduleTitlesView(
                schedule: schedule,
                firstDayOfMonth: firstDayOfMonth,
                firstWeekday: firstWeekday,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                index: index,
                totalScheduleCount: totalScheduleCount,
                allMultiDaySchedules: allMultiDaySchedules,
                geometry: geometry
            )
        }
    }
    
    @ViewBuilder
    private func scheduleTitlesView(
        schedule: Schedule,
        firstDayOfMonth: Date,
        firstWeekday: Int,
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        index: Int,
        totalScheduleCount: Int,
        allMultiDaySchedules: [Schedule],
        geometry: GeometryProxy
    ) -> some View {
        // 各セグメント（週ごりのバー片）にタイトルを表示
        let titleRows = getScheduleDisplayRows(
            for: schedule,
            firstDayOfMonth: firstDayOfMonth,
            firstWeekday: firstWeekday,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            scheduleIndex: index,
            totalScheduleCount: totalScheduleCount,
            allMultiDaySchedules: allMultiDaySchedules,
            geometry: geometry
        )
        
        // 週ごとに最初のセグメントのみにタイトルを表示
        let weeklyFirstRows = Dictionary(grouping: titleRows.enumerated()) { _, row in
            Int(row.y / cellHeight) // 週番号でグループ化
        }.compactMapValues { rows in
            rows.first { $0.element.width >= cellWidth * 1.0 }?.element // 幅条件を満たす最初のrow
        }.values
        
        ForEach(Array(weeklyFirstRows.enumerated()), id: \.offset) { _, row in
            let barHeight = cellHeight * 0.2 // セル高さの20%
            Text(schedule.title.prefix(30))
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white)
                .position(
                    x: row.x, // row.xが既に中央座標として計算されている
                    y: row.y - cellHeight * 0.01  // セル高さの1%分上に表示（端末対応）
                )
                .allowsHitTesting(false)
        }
    }
    
    // 期間予定行表示ビュー
    @ViewBuilder
    private func multiDayScheduleRowView(schedule: Schedule, row: ScheduleDisplayRow, tagColor: Color) -> some View {
        // NavigationLinkを削除してタップ無効化
        ScheduleBarShape(isStart: row.isStart, isEnd: row.isEnd)
            .fill(tagColor)
            .overlay(
                Group {
                    if row.showTitle {
                        VStack(alignment: .center, spacing: 0) {
                            Text(schedule.title.prefix(30))
                                .dynamicCaption2() // フォントサイズを元に戻す
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.top, -8) // バー外に押し出すため負の値を大きくする
                .padding(.bottom, 14)
            )
            .frame(width: row.width, height: 16)
            .position(x: row.x, y: row.y)
            .allowsHitTesting(false) // タップを完全に無効化
    }
    
    // 期間予定の表示情報を計算
    private func getScheduleDisplayRows(
        for schedule: Schedule,
        firstDayOfMonth: Date,
        firstWeekday: Int,
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        scheduleIndex: Int,
        totalScheduleCount: Int,
        allMultiDaySchedules: [Schedule],
        geometry: GeometryProxy
    ) -> [ScheduleDisplayRow] {
        
        var rows: [ScheduleDisplayRow] = []
        let calendar = Calendar.current
        
        // カレンダーグリッドで実際に表示される日付範囲を計算（firstDayOfMonthに依存せず）
        let startOffset = (firstWeekday - 1 + 7) % 7
        let firstDisplayDate = calendar.date(byAdding: .day, value: -startOffset, to: firstDayOfMonth)!
        let lastDisplayDate = calendar.date(byAdding: .day, value: 41, to: firstDisplayDate)!
        
        // 期間予定では日付のみを考慮（時刻は無視）
        let scheduleStartDate = calendar.startOfDay(for: schedule.startDate)
        let scheduleEndDate = calendar.startOfDay(for: schedule.endDate)
        let scheduleStart = max(scheduleStartDate, firstDisplayDate)
        let scheduleEnd = min(scheduleEndDate, lastDisplayDate)
        
        var currentDate = scheduleStart
        
        
        while currentDate <= scheduleEnd {
            // 現在の日付の週内での位置を計算
            let daysSinceMonthStart = calendar.dateComponents([.day], from: firstDayOfMonth, to: currentDate).day ?? 0
            let totalIndex = daysSinceMonthStart + firstWeekday - 1
            let weekRow = totalIndex / 7
            let dayInWeek = totalIndex % 7
            
            // この週での終了位置を計算
            let remainingDaysInWeek = 6 - dayInWeek
            let weekEndDate = calendar.date(byAdding: .day, value: remainingDaysInWeek, to: currentDate) ?? currentDate
            let segmentEnd = min(scheduleEnd, weekEndDate)
            
            let segmentDays = calendar.dateComponents([.day], from: currentDate, to: segmentEnd).day! + 1
            
            // セグメント日数が0以下の場合はスキップ
            guard segmentDays > 0 else {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? scheduleEnd
                continue
            }
            
            // 表示位置とサイズを計算（画面端まで伸ばして完全に揃える）
            let startX = cellWidth * CGFloat(dayInWeek) + CGFloat(dayInWeek) * 8
            let endX = cellWidth * CGFloat(dayInWeek + segmentDays) + CGFloat(dayInWeek + segmentDays - 1) * 8
            
            // 週の開始・終了で画面端まで伸ばす
            let adjustedStartX = (dayInWeek == 0) ? 0 : startX  // 週開始は画面左端まで
            let adjustedEndX = (dayInWeek + segmentDays == 7) ? geometry.size.width : endX  // 週終了は画面右端まで
            
            // タイトル用の中央X座標は、実際のセルの範囲で計算（画面端拡張は適用しない）
            let titleCenterX = startX + (endX - startX) / 2
            let x = titleCenterX
            // 現在の日付での期間予定リストを作成（開始日基準で並び替え）
            let schedulesOnThisDate = allMultiDaySchedules.filter { otherSchedule in
                let otherStart = calendar.startOfDay(for: otherSchedule.startDate)
                let otherEnd = calendar.startOfDay(for: otherSchedule.endDate)
                return currentDate >= otherStart && currentDate <= otherEnd
            }.sorted { $0.startDate < $1.startDate }
            
            // この期間予定全体が祝日をまたぐかチェック
            let hasHolidayInPeriod = checkHolidayInPeriod(start: scheduleStart, end: scheduleEnd)

            // この週にかかる期間予定の中での順番を計算（現在の週のみ）
            let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate))!
            let currentWeekEnd = calendar.date(byAdding: .day, value: 6, to: currentWeekStart)!
            let schedulesInThisWeek = allMultiDaySchedules.filter { otherSchedule in
                let otherStart = calendar.startOfDay(for: otherSchedule.startDate)
                let otherEnd = calendar.startOfDay(for: otherSchedule.endDate)
                return otherStart <= currentWeekEnd && otherEnd >= currentWeekStart
            }.sorted { $0.startDate < $1.startDate }
            
            
            // その日に表示される期間予定の中での順序を取得（開始日で並び替え済み）
            let periodScheduleIndex = schedulesOnThisDate.firstIndex(where: { $0.id == schedule.id }) ?? 0
            
            // 2+1表示制限チェック: その日の総アイテム数を計算
            let holidayCount = firestoreManager.holidays.contains { $0.dateString == formattedDateString(currentDate) } ? 1 : 0
            let regularSchedules = firestoreManager.schedules.filter { schedule in
                !schedule.isMultiDay && calendar.isDate(schedule.startDate, inSameDayAs: currentDate)
            }
            // その日にかかる期間予定の数（表示順序に関係なく、その日に表示される期間予定の実際の数）
            let multiDayCount = schedulesOnThisDate.count
            let totalItems = holidayCount + multiDayCount + regularSchedules.count
            
            // 期間予定の表示制限: 2+1パターンに従う
            let shouldShowPeriodBar: Bool
            if totalItems <= 2 {
                // 総アイテム数が2以下：全て表示
                shouldShowPeriodBar = true
            } else if totalItems == 3 {
                // 総アイテム数が3：全て表示（3件目も表示）
                shouldShowPeriodBar = true
            } else {
                // 総アイテム数が4以上：期間予定は祝日を考慮して表示件数を制限
                let maxPeriodBars = max(0, 2 - holidayCount)
                // その日に表示される期間予定の中での順序で判定
                shouldShowPeriodBar = periodScheduleIndex < maxPeriodBars
            }
            
            
            // 表示制限でスキップする場合
            if !shouldShowPeriodBar {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? scheduleEnd
                continue
            }
            
            // 期間バーのY位置（週ごとの絶対位置で計算）
            let cellHeight = cellHeight // 週の高さ
            let weekHeaderHeight: CGFloat = 30 // 曜日ヘッダーの高さ
            let baseY = weekHeaderHeight + CGFloat(weekRow) * cellHeight // その週の開始Y座標
            
            // 期間スケジュールの実際の表示位置を計算
            // 期間予定全体が祝日をまたぐ場合は、全体を通して一貫した位置に配置
            let scheduleOffsetY: CGFloat
            if hasHolidayInPeriod {
                // 期間中に祝日がある場合：祝日=予定0、期間予定=予定1から開始
                // periodScheduleIndexをそのまま使用（0なら予定1、1なら予定2の位置）
                let adjustedSlotIndex = periodScheduleIndex + 1 // 祝日の分だけシフト
                let slotPosition = CGFloat(adjustedSlotIndex) * (16.0 + 2.0)
                scheduleOffsetY = slotPosition + 5.0 // 基準位置から直接スロット位置を計算
            } else {
                // 期間中に祝日がない場合：通常の位置計算
                let vStackItemOffset = CGFloat(periodScheduleIndex) * (16.0 + 2.0)
                scheduleOffsetY = 28.0 - 5.0 - 18.0 + vStackItemOffset
            }
            let y = baseY + scheduleOffsetY
            
            
            let width = max(0, adjustedEndX - adjustedStartX) // 負の値を防ぐ
            
            
            // 無効なフレームをスキップ
            if width <= 0 || x.isNaN || y.isNaN {
                continue
            }
            
            // 有効な幅の場合のみ追加
            if width > 0 && !x.isNaN && !y.isNaN {
                // タイトル表示の判定
                let segmentDays = calendar.dateComponents([.day], from: currentDate, to: segmentEnd).day! + 1
                let shouldShow = shouldShowTitleInSegment(
                    currentDate: currentDate,
                    segmentDays: segmentDays,
                    schedule: schedule,
                    monthStart: firstDayOfMonth
                )
                
                rows.append(ScheduleDisplayRow(
                    x: x,
                    y: y,
                    width: width,
                    showTitle: false, // バー内表示は無効化（バー外表示を使用）
                    isStart: calendar.isDate(currentDate, inSameDayAs: schedule.startDate),
                    isEnd: calendar.isDate(segmentEnd, inSameDayAs: schedule.endDate)
                ))
                
            }
            
            // 週の終了まで進める（週ごとにセグメントを作成）
            currentDate = calendar.date(byAdding: .day, value: 1, to: segmentEnd) ?? scheduleEnd
        }
        
        return rows
    }
    
    // 期間予定の表示情報
    private struct ScheduleDisplayRow {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let showTitle: Bool
        let isStart: Bool
        let isEnd: Bool
    }
    
    //Schedule型 → ScheduleItem型 に変換（CustomCalendarView用）
    private func convertToScheduleItem(_ schedule: Schedule) -> ScheduleItem {
        return ScheduleItem(
            id: schedule.id,
            title: schedule.title,
            isAllDay: schedule.isAllDay,
            startDate: schedule.startDate,
            endDate: schedule.endDate,
            location: schedule.location,
            tag: schedule.tag,
            memo: schedule.memo,
            repeatOption: schedule.repeatOption,
            recurringGroupId: schedule.recurringGroupId,
            notificationSettings: schedule.notificationSettings
        )
    }
    
    // 期間予定が祝日をまたぐかチェック
    private func checkHolidayInPeriod(start: Date, end: Date) -> Bool {
        let calendar = Calendar.current
        var currentDate = start
        
        while currentDate <= end {
            let dateString = formattedDateString(currentDate)
            if firestoreManager.holidays.contains(where: { $0.dateString == dateString }) {
                return true
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? end
        }
        return false
    }
    
    // 最適なセグメントでタイトルを表示するかどうかを判定
    private func shouldShowTitleInSegment(currentDate: Date, segmentDays: Int, schedule: Schedule, monthStart: Date) -> Bool {
        let calendar = Calendar.current
        let scheduleStart = calendar.startOfDay(for: schedule.startDate)
        let scheduleEnd = calendar.startOfDay(for: schedule.endDate)
        
        // 期間予定の全セグメントを計算して最も長いセグメントを特定
        var maxSegmentDays = 0
        var longestSegmentStart: Date?
        var tempDate = scheduleStart
        
        while tempDate <= scheduleEnd {
            // 現在の週での終了位置を計算
            let daysSinceMonthStart = calendar.dateComponents([.day], from: monthStart, to: tempDate).day ?? 0
            let firstWeekday = calendar.component(.weekday, from: monthStart) - 1
            let totalIndex = daysSinceMonthStart + firstWeekday
            let dayInWeek = totalIndex % 7
            
            let remainingDaysInWeek = 6 - dayInWeek
            let weekEndDate = calendar.date(byAdding: .day, value: remainingDaysInWeek, to: tempDate) ?? tempDate
            let segmentEnd = min(scheduleEnd, weekEndDate)
            
            let currentSegmentDays = calendar.dateComponents([.day], from: tempDate, to: segmentEnd).day! + 1
            
            if currentSegmentDays > maxSegmentDays {
                maxSegmentDays = currentSegmentDays
                longestSegmentStart = tempDate
            }
            
            // 次のセグメントへ移動
            tempDate = calendar.date(byAdding: .day, value: currentSegmentDays, to: tempDate) ?? scheduleEnd
        }

        // 1日以上のセグメントにはタイトルを表示
        if segmentDays >= 1 {
            return true
        }
        
        return false
    }
    
    // 期間の真ん中の日かどうかを判定
    private func isMiddleDayOfSchedule(currentDate: Date, schedule: Schedule) -> Bool {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: schedule.startDate)
        let end = calendar.startOfDay(for: schedule.endDate)
        let current = calendar.startOfDay(for: currentDate)
        
        // 実際の日数を計算（開始日も含める）
        let daysBetween = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let actualDays = daysBetween + 1
        
        // 真ん中の日を計算（偶数日の場合は後半寄り）
        let middleDayOffset = actualDays / 2
        
        let middleDate = calendar.date(byAdding: .day, value: middleDayOffset, to: start) ?? start
        let isMiddle = calendar.isDate(current, inSameDayAs: middleDate)

        return isMiddle
    }
    
    // 期間予定バー全体の座標を計算
    private func getFullScheduleBarFrame(
        for schedule: Schedule,
        firstDayOfMonth: Date,
        firstWeekday: Int,
        cellWidth: CGFloat,
        cellHeight: CGFloat,
        geometry: GeometryProxy
    ) -> CGRect? {
        let calendar = Calendar.current
        let monthStart = firstDayOfMonth
        
        let scheduleStartDate = calendar.startOfDay(for: schedule.startDate)
        let scheduleEndDate = calendar.startOfDay(for: schedule.endDate)
        let scheduleStart = max(scheduleStartDate, monthStart)
        let scheduleEnd = min(scheduleEndDate, calendar.date(byAdding: .month, value: 1, to: monthStart)!)
        
        // 開始日の座標を計算
        let startDaysSinceMonth = calendar.dateComponents([.day], from: monthStart, to: scheduleStart).day ?? 0
        let startTotalIndex = startDaysSinceMonth + firstWeekday - 1
        let startWeekRow = startTotalIndex / 7
        let startDayInWeek = startTotalIndex % 7
        
        // 終了日の座標を計算
        let endDaysSinceMonth = calendar.dateComponents([.day], from: monthStart, to: scheduleEnd).day ?? 0
        let endTotalIndex = endDaysSinceMonth + firstWeekday - 1
        let endWeekRow = endTotalIndex / 7
        let endDayInWeek = endTotalIndex % 7
        
        // 週が異なる場合は、週をまたぐため計算が複雑になるが、
        // とりあえず開始日の週で計算（後で改良）
        let weekHeaderHeight: CGFloat = 30
        let cellTopY = weekHeaderHeight + cellHeight * CGFloat(startWeekRow)
        
        // 開始X座標
        let startX = cellWidth * CGFloat(startDayInWeek) + CGFloat(startDayInWeek) * 8
        
        // 終了X座標（同じ週の場合）
        let endX: CGFloat
        if startWeekRow == endWeekRow {
            // 同じ週内
            endX = cellWidth * CGFloat(endDayInWeek + 1) + CGFloat(endDayInWeek) * 8
        } else {
            // 週をまたぐ場合は、最初の週の終わりまで
            endX = geometry.size.width
        }
        
        // Y座標：期間予定の表示位置を計算（実際のバー表示と同じロジックを使用）
        let regularSchedulesOnDate = schedulesForDate(scheduleStart).filter { !$0.isMultiDay }
        
        // その日の通常予定数
        let regularScheduleCount = regularSchedulesOnDate.count
        
        // その日にかかる全ての期間予定を取得（実際のバー表示と同じ）
        let allMultiDaySchedulesOnDate = firestoreManager.schedules.filter { otherSchedule in
            guard otherSchedule.isMultiDay else { return false }
            let otherStart = calendar.startOfDay(for: otherSchedule.startDate)
            let otherEnd = calendar.startOfDay(for: otherSchedule.endDate)
            let currentDay = calendar.startOfDay(for: scheduleStart)
            return currentDay >= otherStart && currentDay <= otherEnd
        }.sorted { $0.startDate < $1.startDate }
        
        // この期間予定の順番
        let multiScheduleIndex = allMultiDaySchedulesOnDate.firstIndex { $0.id == schedule.id } ?? 0
        
        // 期間予定は全期間にわたって祝日がある場合にバー全体を下げる
        let hasHolidayInPeriod = checkHolidayInPeriod(start: scheduleStartDate, end: scheduleEndDate)
        
        let baseIndex = regularScheduleCount + multiScheduleIndex
        let adjustedIndex = hasHolidayInPeriod ? (baseIndex + 1) : baseIndex

        // 祝日表示エリア分を考慮してバーの開始位置を下に移動
        let holidayAreaHeight: CGFloat = hasHolidayInPeriod ? 22 : 0 // 期間内に祝日がある場合のエリア高さ
        let dateCircleToBarDistance = cellHeight * 0.4 + holidayAreaHeight // 祝日エリア分さらに下に移動
        let barHeight = cellHeight * 0.15 // バーの高さを少し縮める
        let barSpacing = cellHeight * 0.18 // バー間隔も少し縮める
        let barCenterOffset = barHeight / 2 // バーの中央
        
        let y = cellTopY + dateCircleToBarDistance + CGFloat(adjustedIndex) * barSpacing + barCenterOffset
        let width = endX - startX
        let height = barHeight

        return CGRect(x: startX, y: y, width: width, height: height)
    }
}

// 表示アイテムの種類定義
enum DisplayItemType {
    case holiday(Holiday)
    case schedule(Schedule)
}

// ボトムシート風のView
struct BottomSheetView: View {
    @Binding var date: Date
    var schedules: [Schedule]
    var characterId: String
    let userId: String
    var closeAction: () -> Void

    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @ObservedObject var tagSettings = TagSettingsManager.shared
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @State private var selectedDiaryId: String = ""
    @State private var navigateToDiaryDetail = false
    @State private var selectedDiaryDate = Date()
    @State private var hasDiary = false
    @State private var characterExpression: CharacterExpression = .normal
    @State private var loadDiaryTask: Task<Void, Never>?

    @EnvironmentObject var firestoreManager: FirestoreManager
    
    // 並び替えされた表示アイテムを取得
    private var sortedDisplayItems: [DisplayItemType] {
        var items: [DisplayItemType] = []
        
        // 1. 祝日を追加
        let dateString = formattedDateString(date)
        if let holiday = firestoreManager.holidays.first(where: { $0.dateString == dateString }) {
            items.append(.holiday(holiday))
        }
        
        // 2. 期間予定を追加（開始時間順）
        let multiDaySchedules = schedules.filter { $0.isMultiDay }.sorted { $0.startDate < $1.startDate }
        for schedule in multiDaySchedules {
            items.append(.schedule(schedule))
        }
        
        // 3. 終日予定を追加（開始時間順）
        let allDaySchedules = schedules.filter { $0.isAllDay && !$0.isMultiDay }.sorted { $0.startDate < $1.startDate }
        for schedule in allDaySchedules {
            items.append(.schedule(schedule))
        }
        
        // 4. 通常予定を追加（開始時間順）
        let regularSchedules = schedules.filter { !$0.isAllDay && !$0.isMultiDay }.sorted { $0.startDate < $1.startDate }
        for schedule in regularSchedules {
            items.append(.schedule(schedule))
        }
        
        return items
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    Capsule()
                        .frame(width: 40, height: 6)
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.top, 8)

                    HStack {
                        Text(formattedDate(date))
                            .dynamicHeadline()
                            .foregroundColor(colorSettings.getCurrentTextColor())
                            .padding(.leading, 20)

                        Spacer()

                        NavigationLink(destination: ScheduleAddView(selectedDate: date, userId: self.userId)
                            .environmentObject(firestoreManager)) {
                            Image(systemName: "plus.circle.fill")
                                .font(FontSettingsManager.shared.font(size: 22, weight: .bold))
                                .foregroundColor(colorSettings.getCurrentAccentColor())
                                .padding(.trailing, 20)
                        }
                    }
                    .padding(.top, 8)

                    // 常に本マーク＋予定表示の構成にする
                    HStack(alignment: .top) {
                        // 左：本マークボタン（常に表示）
                        Button(action: {
                            if !selectedDiaryId.isEmpty {
                                self.navigateToDiaryDetail = true
                            }
                        }) {
                            ZStack {
                                let circleSize = geometry.size.width / 3 * 0.7
                                let imageSize = geometry.size.width / 3 * 0.65

                                Circle()
                                    .fill(hasDiary ? colorSettings.getCurrentAccentColor() : Color.gray.opacity(0.4))
                                    .frame(width: circleSize, height: circleSize)
                                Image(systemName: "book.fill") // 日記アイコン（本のマーク）
                                    .font(.system(size: imageSize * 0.5))
                                    .foregroundColor(hasDiary ? .white : .gray.opacity(0.7))
                            }
                        }
                        .frame(width: geometry.size.width / 3)

                        // 右：予定リスト（予定がなくても空表示）
                        VStack(alignment: .leading, spacing: 8) {
                            if sortedDisplayItems.isEmpty {
                                Text("予定はありません")
                                    .dynamicBody()
                                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.6))
                                    .padding(.top, 8)
                            } else {
                                ForEach(Array(sortedDisplayItems.prefix(5).enumerated()), id: \.offset) { index, item in
                                    displayItemRow(for: item)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                    }

                    // バナー広告
                    if subscriptionManager.shouldDisplayBannerAd() {
                        BannerAdView(adUnitID: Config.calendarScreenBannerAdUnitID)
                            .frame(height: 50)
                            .background(Color.clear)
                            .onAppear {
                                subscriptionManager.trackBannerAdImpression()
                            }
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(colorSettings.getCurrentBackgroundGradient())
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                )
                .edgesIgnoringSafeArea(.bottom)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if abs(value.translation.width) > abs(value.translation.height) {
                                // 横スワイプが優勢
                                if value.translation.width < -50 {
                                    // 右スワイプ → 翌日
                                    date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
                                } else if value.translation.width > 50 {
                                    // 左スワイプ → 前日
                                    date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                                }
                            } else if value.translation.height > 100 {
                                // 下スワイプで閉じる
                                closeAction()
                            }
                        }
                )
                .transition(.move(edge: .bottom))
                .onAppear {
                    loadDiary(for: date)
                }
                .onChange(of: date) { newDate in
                    // 既存のタスクをキャンセル
                    loadDiaryTask?.cancel()

                    // 新しいタスクを作成（デバウンス）
                    loadDiaryTask = Task {
                        try? await Task.sleep(nanoseconds: 150_000_000) // 0.15秒待機

                        if !Task.isCancelled {
                            await MainActor.run {
                                loadDiary(for: newDate)
                            }
                        }
                    }
                }
                .onDisappear {
                    // BottomSheetが閉じられたときにタスクをキャンセル
                    loadDiaryTask?.cancel()
                }

                // NavigationLinkを非表示で配置
                if !selectedDiaryId.isEmpty {
                    NavigationLink(
                        destination: DiaryDetailView(diaryId: selectedDiaryId, characterId: characterId, userId: userId),
                        isActive: $navigateToDiaryDetail
                    ) {
                        EmptyView()
                    }
                    .frame(width: 0, height: 0)
                    .opacity(0)
                }
            }
        }
    }
    
    @ViewBuilder
    private func displayItemRow(for item: DisplayItemType) -> some View {
        switch item {
        case .holiday(let holiday):
            holidayRow(for: holiday)
        case .schedule(let schedule):
            scheduleRow(for: schedule)
        }
    }
    
    @ViewBuilder
    private func holidayRow(for holiday: Holiday) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(holiday.name)
                .dynamicHeadline()
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(4)
        }
    }
    
    @ViewBuilder
    private func scheduleRow(for schedule: Schedule) -> some View {
        let tagColor = tagSettings.getTag(by: schedule.tag)?.color ?? Color.blue

        NavigationLink(destination: ScheduleDetailView(schedule: ScheduleItem(
            id: schedule.id,
            title: schedule.title,
            isAllDay: schedule.isAllDay,
            startDate: schedule.startDate,
            endDate: schedule.endDate,
            location: schedule.location,
            tag: schedule.tag,
            memo: schedule.memo,
            repeatOption: schedule.repeatOption,
            recurringGroupId: schedule.recurringGroupId,
            notificationSettings: schedule.notificationSettings
        ), userId: userId)) {
            VStack(alignment: .center, spacing: 2) {
                if schedule.isAllDay || schedule.isMultiDay {
                    Text(schedule.title)
                        .dynamicHeadline()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(tagColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                } else {
                    Text(schedule.title)
                        .dynamicHeadline()
                        .foregroundColor(tagColor)
                }
                
            }
        }
    }
    
    // 日付の日本語フォーマット関数
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E)"
        return formatter.string(from: date)
    }
    
    
    //日記の取得情報を使い回すラッパー関数
    private func loadDiary(for date: Date) {
        queryDiary(for: date) { documentID in
            DispatchQueue.main.async {
                // 日付を日本時間の文字列で表示するためのフォーマッター
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "yyyy-MM-dd"
                displayFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
                let displayDateString = displayFormatter.string(from: date)
                
                self.selectedDiaryId = documentID ?? ""
                self.hasDiary = (documentID != nil)
            }
        }
    }

    private func triggerRandomExpression() {
        let expressions: [CharacterExpression] = [.normal, .smile, .angry, .cry, .sleep]
        let availableExpressions = expressions.filter { $0 != characterExpression }
        characterExpression = availableExpressions.randomElement() ?? .smile
    }
    
    //日記取得
    private func queryDiary(for date: Date, completion: @escaping (_ documentID: String?) -> Void) {
        guard !characterId.isEmpty, !userId.isEmpty else {
            completion(nil)
            return
        }

        let db = Firestore.firestore()

        // yyyy-MM-dd 形式の文字列を生成
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let dateString = dateFormatter.string(from: date)


        // 正しい構造で日記検索を実行: users/{userId}/characters/{characterId}/diary
        db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("diary")
            .whereField("created_date", isEqualTo: dateString)
            .order(by: "created_at", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil)
                    return
                }

                if let doc = snapshot?.documents.first {
                    completion(doc.documentID)
                } else {
                    completion(nil)
                }
            }
    }
}

//年月スクロール
struct YearMonthInlinePickerView: View {
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int
    var onClose: () -> Void
    
    // 年をカンマなしでフォーマットする関数
    private func formatYearWithoutComma(_ year: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.groupingSeparator = ""
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: year)) ?? "\(year)"
    }
    
    private func dynamicPickerHeight(for screenHeight: CGFloat) -> CGFloat {
        return screenHeight * 0.18
    }

    var body: some View {
        GeometryReader { geometry in
            let pickerHeight = dynamicPickerHeight(for: geometry.size.height)

            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    Button(action: { onClose() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(FontSettingsManager.shared.font(size: 20, weight: .semibold)).foregroundColor(.gray)
                    }
                    .padding(.trailing)
                }

                HStack {
                    Picker("年", selection: $selectedYear) {
                        ForEach(1900...2100, id: \.self) { year in
                            Text("\(formatYearWithoutComma(year))年")
                                .dynamicBody()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: pickerHeight)
                    .clipped()
                    .pickerStyle(WheelPickerStyle())

                    Picker("月", selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month)月")
                                .dynamicBody()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: pickerHeight)
                    .clipped()
                    .pickerStyle(WheelPickerStyle())
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(colorSettings.getCurrentBackgroundGradient())
            .cornerRadius(0)
            .overlay(
                Rectangle()
                    .stroke(Color.gray, lineWidth: 1)
            )
            .ignoresSafeArea(.container, edges: .horizontal)
            .transition(.move(edge: .top))
        }
    }
}

// 日付を"yyyy-MM-dd"形式にフォーマットして返す（祝日判定などで使用）
func formattedDateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}


// 検索結果カード
struct ScheduleSearchResultCard: View {
    let schedule: Schedule
    let colorSettings: ColorSettingsManager

    private func formatDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d(E)"
        formatter.locale = Locale(identifier: "ja_JP")

        let startStr = formatter.string(from: schedule.startDate)

        // 終了日が開始日と異なる場合
        let calendar = Calendar.current
        if !calendar.isDate(schedule.startDate, inSameDayAs: schedule.endDate) {
            let endStr = formatter.string(from: schedule.endDate)
            return "\(startStr) 〜 \(endStr)"
        }

        return startStr
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // タグ
                if !schedule.tag.isEmpty {
                    Text(schedule.tag)
                        .dynamicCaption2()
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(colorSettings.getCurrentAccentColor())
                        .cornerRadius(4)
                }

                Spacer()

                // 日付
                Text(formatDateRange())
                    .dynamicCaption()
                    .foregroundColor(.gray)
            }

            // タイトル
            Text(schedule.title)
                .dynamicBody()
                .foregroundColor(colorSettings.getCurrentTextColor())
                .fontWeight(.semibold)

            // メモ（空でない場合）
            if !schedule.memo.isEmpty {
                Text(schedule.memo)
                    .dynamicCaption()
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.8))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

// プレビュー画面表示
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CalendarView(
                userId: "sampleUserId",
                characterId: "sampleCharacterId",
                isPremium: false
            )
            .environmentObject(FirestoreManager())
            .environmentObject(FontSettingsManager.shared)
        }
    }
}
