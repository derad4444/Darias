import SwiftUI

struct ScheduleDetailView: View {
    let schedule: ScheduleItem
    
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @AppStorage("isPremium") var isPremium: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var navigateToEdit = false
    
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
                            showEdit = true
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
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                    Text(formatTime(schedule.startDate))
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 24))
                                    .foregroundColor(colorSettings.getCurrentTextColor())
                                Spacer()
                                VStack(alignment: .center, spacing: 4) {
                                    Text(formatDate(schedule.endDate))
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                    Text(formatTime(schedule.endDate))
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                }
                            }
                            .padding()
                            
                            // 各項目リスト
                            VStack(spacing: 16) {
                                if schedule.remindValue > 0 {
                                    detailRow(icon: "alarm", label: "\(schedule.remindValue)\(schedule.remindUnit)前")
                                }
                                if !schedule.repeatOption.isEmpty {
                                    detailRow(icon: "calendar", label: schedule.repeatOption)
                                }
                                if !schedule.tag.isEmpty {
                                    detailRow(icon: "tag", label: schedule.tag)
                                }
                                if !schedule.location.isEmpty {
                                    detailRow(icon: "mappin.and.ellipse", label: schedule.location)
                                }
                                if !schedule.memo.isEmpty {
                                    detailRow(icon: "note.text", label: schedule.memo)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 120) // タブバー分の余白を確保
                    }
                    .frame(height: 670) // より大きな高さを指定
                    .clipped() // 画面外をクリップ
                }
            }
        }
        .navigationBarHidden(true) // NavigationBarを完全に隠す
        .sheet(isPresented: $showEdit) {
            NavigationView {
                ScheduleEditView(schedule: schedule)
            }
        }
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E)"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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
                remindValue: 5,
                remindUnit: "分前"
            ))
            .environmentObject(FontSettingsManager.shared)
        }
    }
}
