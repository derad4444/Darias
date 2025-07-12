import SwiftUI
import FirebaseFirestore

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

struct CalendarView: View {
    @StateObject private var firestoreManager = FirestoreManager()
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @ObservedObject var tagSettings = TagSettingsManager.shared
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var showPicker = false
    @State private var selectedDate: Date = Date()
    @State private var showBottomSheet = false
    
    let calendar = Calendar.current
    var userId: String
    var characterId: String
    var isPremium: Bool
    
    // ある日の予定一覧取得
    func schedulesForDate(_ date: Date) -> [Schedule] {
        firestoreManager.schedules.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
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
    }
    
    var body: some View {
        let screenHeight = UIScreen.main.bounds.height
        let calendarHeight = screenHeight * 0.55
        
        NavigationStack {
            VStack(spacing: 0) {
                // 上部広告
                // if !isPremium {
                //     BannerAdView(adUnitID: "ca-app-pub-3940256099942544/2934735716")
                //         .frame(maxWidth: .infinity, maxHeight: 50)
                //         .padding(.top, 8)
                // }
                
                ZStack {
                    //背景
                    colorSettings.getCurrentBackgroundGradient()
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                            // ヘッダーを完全固定
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
                                    Text("\(selectedYear.description)年 \(selectedMonth)月")
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
                                        .padding(.trailing, 16)
                                }
                            }
                            .frame(height: 60)
                            .padding(.top, 20)
                            .background(Color.clear)
                            .padding(.horizontal)
                            .zIndex(1)
                            
                            // カレンダー本体
                            CustomCalendarView(
                                selectedDate: $selectedDate,
                                selectedYear: $selectedYear,
                                selectedMonth: $selectedMonth,
                                schedulesForDate: self.schedulesForDate,
                                firestoreManager: firestoreManager,
                                showBottomSheet: $showBottomSheet
                            )
                            .frame(height: calendarHeight) // カレンダー高さ調整
                            
                        Spacer()
                    }
                    // オーバーレイ表示
                    .overlay(
                        Group {
                            if showPicker {
                                YearMonthInlinePickerView(selectedYear: $selectedYear, selectedMonth: $selectedMonth) {
                                    showPicker = false
                                }
                                .padding(.top, 60)
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
                            closeAction: { showBottomSheet = false }
                        )
                        .environmentObject(firestoreManager)
                        .zIndex(2)
                    }
                    
                    // 左下にキャラクター画像と吹き出しを配置
                    VStack {
                        Spacer()
                        HStack(alignment: .bottom, spacing: 5) {
                            // キャラクター画像
                            Image("diary_button")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 150, height: 150)
                            
                            // 当月コメントの吹き出し
                            VStack(alignment: .leading, spacing: 4) {
                                Text("今月のひとこと")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text("3月は穏やかでリラックスした月だったね。休息も大切だよ。\n\n今月は新しいことにチャレンジしてみるのはどう？楽しい発見があるよ！")
                                    .font(.body)
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.leading)
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
                        .padding(.leading, 0) // 左端に配置
                        .padding(.bottom, 10) // タブバー分のスペース
                    }
                    .allowsHitTesting(false) // タッチイベントを無効化
                }
            }
        }
        .onAppear {
            firestoreManager.fetchSchedules()
            firestoreManager.fetchDiaries()
            firestoreManager.fetchHolidays()  // 祝日も読み込み
            showBottomSheet = false
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
    
    @State private var dragOffsetX: CGFloat = 0
    @State private var isDragging: Bool = false
    
    @Binding var showBottomSheet: Bool
    
    let calendar = Calendar.current
    let today = Date()
    
    var body: some View {
        let components = DateComponents(year: selectedYear, month: selectedMonth)
        let firstDayOfMonth = calendar.date(from: components)!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        ZStack {
            monthView(for: currentComponents())
                .offset(x: dragOffsetX)
            monthView(for: nextComponents())
                .offset(x: dragOffsetX + (dragOffsetX > 0 ? -UIScreen.main.bounds.width : UIScreen.main.bounds.width))
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
    
    // 日付の色を変更
    private func colorForDate(date: Date) -> Color {
        let isCurrentMonth = calendar.component(.month, from: date) == selectedMonth
        let weekday = calendar.component(.weekday, from: date)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let isHoliday = firestoreManager.holidays.contains { $0.dateString == dateString }
        
        // 当月以外の日付を薄くする
        if !isCurrentMonth { return colorSettings.getCurrentTextColor().opacity(0.4) }
        // 祝日を赤
        else if isHoliday { return .red }
        // 日曜を赤
        else if weekday == 1 { return .red }
        // 土曜を青
        else if weekday == 7 { return .blue }
        else { return colorSettings.getCurrentTextColor() }
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
        
        VStack(spacing: 8) {
            // 曜日ヘッダーを追加
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .dynamicCaption()
                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                }
            }
            .padding(.bottom, 4)
            
            // 日付セル
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(0..<42), id: \.self) { index in
                    let offset = index - (firstWeekday - 1)
                    let date = calendar.date(byAdding: .day, value: offset, to: firstDayOfMonth)!
                    let dateString = formattedDateString(date)
                    let holiday = firestoreManager.holidays.first(where: { $0.dateString == dateString })
                    
                    VStack(spacing: 2) {
                        // 日付の丸枠
                        Button {
                            selectedDate = date
                            showBottomSheet = true
                        } label: {
                            Circle()
                                .fill(calendar.isDate(date, inSameDayAs: selectedDate) ? colorSettings.getCurrentAccentColor() : .clear)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.system(size: 12))
                                        .foregroundColor(colorForDate(date: date))
                                )
                        }
                        
                        // 祝日があれば最上部に表示
                        if let holiday = holiday {
                            Text(holiday.name.prefix(5))
                                .font(.system(size: 7))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(3)
                        }
                        
                        // 予定（最大3件）を下に表示
                        ForEach(schedulesForDate(date).prefix(3), id: \.id) { schedule in
                            let tagColor = tagSettings.getTag(by: schedule.tag)?.color ?? Color.blue
                            
                            if schedule.isAllDay {
                                Text(schedule.title.prefix(5))
                                    .dynamicCaption2()
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(tagColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(3)
                            } else {
                                Text(schedule.title.prefix(5))
                                    .dynamicCaption2()
                                    .foregroundColor(tagColor)
                            }
                        }
                        
                        Spacer()
                        
                    }
                    .frame(height: 70) //カレンダーの縦の長さ調節
                }
            }
        }
        .padding(.horizontal)
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
}

// ボトムシート風のView
struct BottomSheetView: View {
    @Binding var date: Date
    var schedules: [Schedule]
    var characterId: String
    var closeAction: () -> Void
    
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @ObservedObject var tagSettings = TagSettingsManager.shared
    @State private var selectedDiaryId: String = ""
    @State private var navigateToDiaryDetail = false
    @State private var selectedDiaryDate = Date()
    @State private var hasDiary = false
    // アニメーション用のオフセット
    @State private var offsetY: CGFloat = 300
    // ドラッグ量保持
    @GestureState private var dragOffset: CGFloat = 0
    
    @EnvironmentObject var firestoreManager: FirestoreManager
    
    var body: some View {
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
                
                NavigationLink(destination: ScheduleAddView(selectedDate: date)) {
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
                    } else {
                        print("📘 該当日のDiaryは存在しません")
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(hasDiary ? colorSettings.getCurrentAccentColor() : Color.gray.opacity(0.4))
                            .frame(width: UIScreen.main.bounds.width / 3 * 0.7, height: UIScreen.main.bounds.width / 3 * 0.7)
                        Image("diary_button") // 新しく追加した画像名に変更
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: UIScreen.main.bounds.width / 3 * 0.65, height: UIScreen.main.bounds.width / 3 * 0.65)
                    }
                }
                
                .frame(width: UIScreen.main.bounds.width / 3)
                
                // 右：予定リスト（予定がなくても空表示）
                VStack(alignment: .leading, spacing: 8) {
                    if schedules.isEmpty {
                        Text("予定はありません")
                            .dynamicBody()
                            .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.6))
                            .padding(.top, 8)
                    } else {
                        ForEach(schedules.prefix(5)) { schedule in
                            scheduleRow(for: schedule)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
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
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    if value.translation.height > 0 {
                        state = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.width < -50 {
                        // 右スワイプ → 翌日
                        date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
                    } else if value.translation.width > 50 {
                        // 左スワイプ → 前日
                        date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                    } else if value.translation.height > 100 {
                        // 下スワイプで閉じる
                        closeAction()
                    }
                }
        )
        .offset(y: offsetY + dragOffset)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                offsetY = 0
            }
            loadDiary(for: date)
        }
        .onChange(of: date) { newDate in
            loadDiary(for: newDate)
        }
        .transition(.move(edge: .bottom))
        NavigationLink(
            destination: DiaryDetailView(diaryId: selectedDiaryId, characterId: characterId),
            isActive: $navigateToDiaryDetail
        ) {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func scheduleRow(for schedule: Schedule) -> some View {
        let tagColor = tagSettings.getTag(by: schedule.tag)?.color ?? Color.blue
        
        NavigationLink(destination: ScheduleDetailView(schedule: convertToScheduleItem(schedule))) {
            if schedule.isAllDay {
                Text(schedule.title)
                    .dynamicHeadline()
                    .padding(.horizontal, 6)
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
    
    // 日付の日本語フォーマット関数
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E)"
        return formatter.string(from: date)
    }
    
    //Schedule型 → ScheduleItem型 に変換
    private func convertToScheduleItem(_ schedule: Schedule) -> ScheduleItem {
        return ScheduleItem(
            id: schedule.id,
            title: schedule.title,
            isAllDay: schedule.isAllDay,
            startDate: schedule.date,
            endDate: schedule.date,
            location: "",
            tag: schedule.tag,
            memo: "",
            repeatOption: "",
            remindValue: 0,
            remindUnit: ""
        )
    }
    
    //日記の取得情報を使い回すラッパー関数
    private func loadDiary(for date: Date) {
        queryDiary(for: date) { documentID in
            DispatchQueue.main.async {
                if let id = documentID {
                    print("✅ Diaryが見つかりました: \(id)")
                } else {
                    print("📘 Diaryは存在しません (日付: \(date))")
                }
                self.selectedDiaryId = documentID ?? ""
                self.hasDiary = (documentID != nil)
            }
        }
    }
    
    //日記取得
    private func queryDiary(for date: Date, completion: @escaping (_ documentID: String?) -> Void) {
        let db = Firestore.firestore()
        
        // yyyy-MM-dd 形式の文字列を生成
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let dateString = dateFormatter.string(from: date)
        print("(characterId: \(characterId))(日付: \(dateString))")
        
        db.collection("diaries")
            .whereField("character_id", isEqualTo: characterId)
            .whereField("created_date", isEqualTo: dateString)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("🔥 Diaryクエリ失敗: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                if let doc = snapshot?.documents.first {
                    let data = doc.data()  // ← Firestoreのドキュメント中身（[String: Any]）
                    print("📘 Diary取得成功: \(doc.documentID)")
                    print("📘 Diaryの内容: \(data)")
                    
                    completion(doc.documentID)
                } else {
                    print("📭 該当するDiaryは見つかりませんでした (characterId: \(characterId), created_date: \(dateString))")
                    
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
    
    var body: some View {
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
                        Text("\(year)年")
                            .dynamicBody()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)  // ⭐ ← 高さUP
                .clipped()
                .pickerStyle(WheelPickerStyle())
                
                Picker("月", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text("\(month)月")
                            .dynamicBody()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
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

// 日付を"yyyy-MM-dd"形式にフォーマットして返す（祝日判定などで使用）
func formattedDateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
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
