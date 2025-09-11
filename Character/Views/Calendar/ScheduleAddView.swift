import SwiftUI

struct ScheduleAddView: View {
    let userId: String
    @AppStorage("isPremium") var isPremium: Bool = false
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @ObservedObject var tagSettings = TagSettingsManager.shared
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var firestoreManager: FirestoreManager
    
    @State private var title = ""
    @State private var isAllDay = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var remindValue = ""
    @State private var remindUnit = "分前"
    @State private var location = ""
    @State private var repeatSettings = RepeatSettings()
    @State private var notificationSettings = NotificationSettings()
    @State private var tag = ""
    @State private var memo = ""
    @State private var showTagSelection = false
    @State private var showRepeatSettings = false
    @State private var showNotificationSettings = false
    @State private var showDateValidationAlert = false
    
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
        _startDate = State(initialValue: selectedDate)
        _endDate = State(initialValue: selectedDate.addingTimeInterval(3600))
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
        
        let newSchedule = ScheduleItem(
            id: UUID().uuidString,   // 🔸 idを自動生成
            title: title,
            isAllDay: isAllDay,
            startDate: finalStartDate,
            endDate: finalEndDate,
            location: location,
            tag: tag,
            memo: memo,
            repeatOption: repeatSettings.getDescription(for: finalStartDate),
            remindValue: Int(remindValue) ?? 0,  // 🔸 String → Int変換
            remindUnit: remindUnit
        )
        
        firestoreManager.addSchedule(newSchedule, for: userId) { success in
            if success {
                // 通知を設定
                NotificationManager.shared.scheduleNotification(
                    for: newSchedule,
                    notificationSettings: notificationSettings
                )
                dismiss()
            } else {
                // エラー処理
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
