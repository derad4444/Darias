import SwiftUI

struct ScheduleDetailView: View {
    let schedule: ScheduleItem
    let userId: String
    
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @ObservedObject var tagSettings = TagSettingsManager.shared
    @AppStorage("isPremium") var isPremium: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var navigateToEdit = false
    @State private var showDeleteConfirmation = false
    @State private var showRecurringDeleteOptions = false
    @State private var showRecurringEditOptions = false
    @State private var editSingleOnly = false
    @StateObject private var firestoreManager = FirestoreManager()
    
    private var dynamicContentHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let safeAreaTop: CGFloat = 47
        let safeAreaBottom: CGFloat = 34
        let headerHeight: CGFloat = 60
        let adHeight: CGFloat = isPremium ? 0 : 50
        return screenHeight - safeAreaTop - safeAreaBottom - headerHeight - adHeight - 20
    }
    
    private var dynamicAdHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        return screenHeight * 0.06
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景グラデーション
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
                        Button("編集") {
                            if schedule.recurringGroupId != nil {
                                showRecurringEditOptions = true
                            } else {
                                showEdit = true
                            }
                        }
                        .foregroundColor(colorSettings.getCurrentAccentColor())
                    }
                    .padding()
                    .background(Color.clear) // 完全透過
                    
                    // スクロール可能な情報エリア
                    ScrollView {
                        VStack(spacing: 20) {
                            // タイトル中央配置
                            Text(schedule.title)
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(colorSettings.getCurrentTextColor())
                                .padding(.horizontal)
                                .padding(.top, 5)
                            
                            // 日付 & 時間エリア
                            HStack {
                                VStack(alignment: .center, spacing: 4) {
                                    Text(formatDate(schedule.startDate))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(minWidth: 140)
                                    Text(formatTime(schedule.startDate))
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: 160)
                                
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 20))
                                    .foregroundColor(colorSettings.getCurrentTextColor())
                                Spacer()
                                
                                VStack(alignment: .center, spacing: 4) {
                                    Text(formatDate(schedule.endDate))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(minWidth: 140)
                                    Text(formatTime(schedule.endDate))
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: 160)
                            }
                            .padding()
                            
                            // 各項目リスト
                            VStack(spacing: 16) {
                                // 通知設定の表示
                                if let notificationSettings = schedule.notificationSettings,
                                   notificationSettings.isEnabled,
                                   !notificationSettings.notifications.isEmpty {
                                    detailRow(icon: "bell", label: notificationSettings.getDescription())
                                } else if schedule.remindValue > 0 {
                                    // 従来の通知設定がある場合（下位互換性）
                                    detailRow(icon: "bell", label: "\(schedule.remindValue)\(schedule.remindUnit)前")
                                }
                                if !schedule.repeatOption.isEmpty {
                                    detailRow(icon: "calendar", label: schedule.repeatOption)
                                }
                                if !schedule.tag.isEmpty {
                                    tagDetailRow(tagName: schedule.tag)
                                }
                                if !schedule.location.isEmpty {
                                    detailRow(icon: "mappin.and.ellipse", label: schedule.location)
                                }
                                if !schedule.memo.isEmpty {
                                    detailRow(icon: "note.text", label: schedule.memo)
                                }
                            }
                            .padding(.horizontal)
                            
                            // 削除ボタン
                            Button(action: {
                                if schedule.recurringGroupId != nil {
                                    showRecurringDeleteOptions = true
                                } else {
                                    showDeleteConfirmation = true
                                }
                            }) {
                                Text("削除")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
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
        .sheet(isPresented: $showEdit) {
            NavigationView {
                ScheduleEditView(schedule: schedule, userId: userId, editSingleOnly: editSingleOnly)
            }
        }
        .alert("予定を削除しますか？", isPresented: $showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                deleteSingleSchedule()
            }
        } message: {
            Text("この操作は取り消せません。")
        }
        .overlay(
            // カスタムダイアログ
            Group {
                if showRecurringDeleteOptions {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showRecurringDeleteOptions = false
                            }

                        VStack(spacing: 0) {
                            // タイトル部分
                            VStack(spacing: 12) {
                                Text("繰り返し予定の削除")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)

                                Text("どの予定を削除しますか？")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 24)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)

                            Divider()

                            // ボタン部分
                            VStack(spacing: 0) {
                                Button(action: {
                                    showRecurringDeleteOptions = false
                                    deleteSingleSchedule()
                                }) {
                                    Text("この予定のみ削除")
                                        .font(.system(size: 17))
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                }

                                Divider()

                                Button(action: {
                                    showRecurringDeleteOptions = false
                                    deleteAllRecurringSchedules()
                                }) {
                                    Text("すべての繰り返し予定を削除")
                                        .font(.system(size: 17))
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                }

                                Divider()

                                Button(action: {
                                    showRecurringDeleteOptions = false
                                }) {
                                    Text("キャンセル")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(14)
                        .frame(width: 300)
                        .shadow(radius: 20)
                    }
                }
            }
        )
        .overlay(
            // 編集選択肢のカスタムダイアログ
            Group {
                if showRecurringEditOptions {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showRecurringEditOptions = false
                            }

                        VStack(spacing: 0) {
                            // タイトル部分
                            VStack(spacing: 12) {
                                // アイコン追加で視覚的により分かりやすく
                                Image(systemName: "repeat.circle")
                                    .font(.system(size: 36))
                                    .foregroundColor(.blue)

                                Text("繰り返し予定の編集")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.primary)

                                Text("どの予定を編集しますか？")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 24)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)

                            Divider()

                            // ボタン部分
                            VStack(spacing: 0) {
                                Button(action: {
                                    showRecurringEditOptions = false
                                    editSingleOnly = true
                                    showEdit = true
                                }) {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 16))
                                            .foregroundColor(.blue)
                                        Text("この予定のみ編集")
                                            .font(.system(size: 17))
                                            .foregroundColor(.blue)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .padding(.horizontal, 20)
                                }

                                Divider()

                                Button(action: {
                                    showRecurringEditOptions = false
                                    editSingleOnly = false
                                    showEdit = true
                                }) {
                                    HStack {
                                        Image(systemName: "repeat")
                                            .font(.system(size: 16))
                                            .foregroundColor(.blue)
                                        Text("すべての繰り返し予定を編集")
                                            .font(.system(size: 17))
                                            .foregroundColor(.blue)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .padding(.horizontal, 20)
                                }

                                Divider()

                                Button(action: {
                                    showRecurringEditOptions = false
                                }) {
                                    Text("キャンセル")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(14)
                        .frame(width: 300)
                        .shadow(radius: 20)
                    }
                }
            }
        )
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
    
    // アイコン付き情報行
    @ViewBuilder
    private func detailRow(icon: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                .frame(width: 30)
            Text(label)
                .font(.system(size: 18))
                .foregroundColor(colorSettings.getCurrentTextColor())
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    // タグ専用の詳細行（色付きで表示）
    @ViewBuilder
    private func tagDetailRow(tagName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "tag")
                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                .frame(width: 20)
            
            HStack {
                if let selectedTag = tagSettings.getTag(by: tagName) {
                    Circle()
                        .fill(selectedTag.color)
                        .frame(width: 16, height: 16)
                    Text(selectedTag.name)
                        .dynamicBody()
                        .foregroundColor(colorSettings.getCurrentTextColor())
                } else {
                    Text(tagName)
                        .dynamicBody()
                        .foregroundColor(colorSettings.getCurrentTextColor())
                }
                Spacer()
            }
        }
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/M/d(E)"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // 単一予定のみ削除
    private func deleteSingleSchedule() {
        firestoreManager.deleteSchedule(scheduleId: schedule.id) { success in
            DispatchQueue.main.async {
                if success {
                    dismiss()
                } else {
                    print("❌ 予定の削除に失敗しました")
                }
            }
        }
    }

    // すべての繰り返し予定を削除
    private func deleteAllRecurringSchedules() {
        guard let recurringGroupId = schedule.recurringGroupId else {
            print("❌ recurringGroupIdがありません")
            return
        }

        print("🔍 繰り返し予定グループ削除開始 - \(schedule.title)")

        firestoreManager.deleteRecurringGroup(groupId: recurringGroupId) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ 繰り返し予定削除成功")
                    self.dismiss()
                } else {
                    print("❌ 繰り返し予定の削除に失敗しました")
                }
            }
        }
    }
}

// ✅ プレビュー用
struct ScheduleDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ScheduleDetailView(schedule: ScheduleItem(
                id: "dummyId",
                title: "接骨院",
                isAllDay: false,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                location: "東京都渋谷区",
                tag: "仕事",
                memo: "定期検診のため",
                repeatOption: "繰り返さない",
            ), userId: "preview_user_id")
            .environmentObject(FontSettingsManager.shared)
        }
    }
}
