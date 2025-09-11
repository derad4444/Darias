import SwiftUI
import FirebaseFirestore

struct ScheduleEditView: View {
    let schedule: ScheduleItem  // ✅ ScheduleItemを受け取る
    let userId: String

    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @ObservedObject var tagSettings = TagSettingsManager.shared
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
    init(schedule: ScheduleItem, userId: String) {
        self.schedule = schedule
        self.userId = userId
        _scheduleTitle = State(initialValue: schedule.title)
        _startDate = State(initialValue: schedule.startDate)
        _endDate = State(initialValue: schedule.endDate)
        _location = State(initialValue: schedule.location)
        _tag = State(initialValue: schedule.tag)
        _memo = State(initialValue: schedule.memo)
        _isAllDay = State(initialValue: schedule.isAllDay)
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
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(userId).collection("schedules").document(schedule.id)

        var finalStartDate = startDate
        var finalEndDate = endDate
        if isAllDay {
            finalStartDate = Calendar.current.startOfDay(for: startDate)
            finalEndDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: endDate) ?? endDate
        }

        let data: [String: Any] = [
            "title": scheduleTitle,
            "startDate": Timestamp(date: finalStartDate),
            "endDate": Timestamp(date: finalEndDate),
            "isAllDay": isAllDay,
            "location": location,
            "tag": tag,
            "memo": memo,
            "repeatOption": repeatSettings.getDescription(for: finalStartDate)
        ]

        docRef.setData(data) { error in
            if error == nil { 
                // 既存の通知を削除
                NotificationManager.shared.removeNotification(for: schedule.id)
                
                // 新しい通知を設定
                let updatedSchedule = ScheduleItem(
                    id: schedule.id,
                    title: scheduleTitle,
                    isAllDay: isAllDay,
                    startDate: finalStartDate,
                    endDate: finalEndDate,
                    location: location,
                    tag: tag,
                    memo: memo,
                    repeatOption: repeatSettings.getDescription(for: finalStartDate),
                    remindValue: 0,
                    remindUnit: ""
                )
                
                NotificationManager.shared.scheduleNotification(
                    for: updatedSchedule,
                    notificationSettings: notificationSettings
                )
                
                // カレンダー画面に予定更新を通知
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .init("ScheduleAdded"),
                        object: nil
                    )
                }
                
                // 保存完了後に直接画面を閉じる
                dismiss()
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
                remindValue: 5,
                remindUnit: "分前"
            ), userId: "preview_user_id")
            .environmentObject(FontSettingsManager.shared)
        }
    }
}
