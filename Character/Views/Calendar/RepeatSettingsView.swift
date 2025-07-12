import SwiftUI

enum RepeatType: String, CaseIterable {
    case none = "繰り返さない"
    case daily = "毎日"
    case weekly = "毎週"
    case monthly = "毎月"
    case monthEnd = "月末"
    case monthStart = "月初"
    
    var displayName: String {
        return self.rawValue
    }
}

struct RepeatSettings {
    var type: RepeatType = .none
    var weekday: Int = 1 // 1=日曜日, 2=月曜日...
    var dayOfMonth: Int = 1 // 月の何日か
    
    func getDescription(for date: Date) -> String {
        let calendar = Calendar.current
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        weekdayFormatter.locale = Locale(identifier: "ja_JP")
        
        switch type {
        case .none:
            return "繰り返さない"
        case .daily:
            return "毎日"
        case .weekly:
            let weekdayName = weekdayFormatter.string(from: date)
            return "毎週\(weekdayName)"
        case .monthly:
            let day = calendar.component(.day, from: date)
            return "毎月\(day)日"
        case .monthEnd:
            return "毎月月末"
        case .monthStart:
            return "毎月月初（1日）"
        }
    }
}

struct RepeatSettingsView: View {
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @Binding var repeatSettings: RepeatSettings
    let baseDate: Date
    
    @State private var selectedType: RepeatType
    @State private var selectedWeekday: Int
    @State private var selectedDay: Int
    
    init(repeatSettings: Binding<RepeatSettings>, baseDate: Date) {
        self._repeatSettings = repeatSettings
        self.baseDate = baseDate
        self._selectedType = State(initialValue: repeatSettings.wrappedValue.type)
        self._selectedWeekday = State(initialValue: repeatSettings.wrappedValue.weekday)
        self._selectedDay = State(initialValue: repeatSettings.wrappedValue.dayOfMonth)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    // 背景
                    colorSettings.getCurrentBackgroundGradient()
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            // 繰り返しタイプ選択
                            ForEach(RepeatType.allCases, id: \.self) { type in
                                Button(action: {
                                    selectedType = type
                                    updateSettings()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(type.displayName)
                                                .dynamicBody()
                                                .foregroundColor(colorSettings.getCurrentTextColor())
                                            
                                            if type != .none {
                                                Text(getPreviewText(for: type))
                                                    .dynamicCaption()
                                                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedType == type {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(colorSettings.getCurrentAccentColor())
                                        }
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedType == type ? colorSettings.getCurrentAccentColor() : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // 詳細設定（必要な場合のみ表示）
                            if selectedType == .weekly {
                                weekdaySelectionView()
                            } else if selectedType == .monthly {
                                daySelectionView()
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("繰り返し設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(colorSettings.getCurrentAccentColor())
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        updateSettings()
                        dismiss()
                    }
                    .foregroundColor(colorSettings.getCurrentAccentColor())
                }
            }
        }
    }
    
    @ViewBuilder
    private func weekdaySelectionView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("曜日を選択")
                .dynamicHeadline()
                .foregroundColor(colorSettings.getCurrentTextColor())
            
            let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    Button(action: {
                        selectedWeekday = index + 1
                        updateSettings()
                    }) {
                        Text(weekdays[index])
                            .dynamicCallout()
                            .foregroundColor(selectedWeekday == index + 1 ? .white : colorSettings.getCurrentTextColor())
                            .frame(width: 40, height: 40)
                            .background(selectedWeekday == index + 1 ? colorSettings.getCurrentAccentColor() : Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func daySelectionView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("日付を選択")
                .dynamicHeadline()
                .foregroundColor(colorSettings.getCurrentTextColor())
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(1...31, id: \.self) { day in
                    Button(action: {
                        selectedDay = day
                        updateSettings()
                    }) {
                        Text("\(day)")
                            .dynamicCaption()
                            .foregroundColor(selectedDay == day ? .white : colorSettings.getCurrentTextColor())
                            .frame(width: 40, height: 40)
                            .background(selectedDay == day ? colorSettings.getCurrentAccentColor() : Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func getPreviewText(for type: RepeatType) -> String {
        let calendar = Calendar.current
        
        switch type {
        case .none:
            return ""
        case .daily:
            return "毎日同じ時間に実行"
        case .weekly:
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            weekdayFormatter.locale = Locale(identifier: "ja_JP")
            let weekdayName = weekdayFormatter.string(from: baseDate)
            return "毎週\(weekdayName)に実行"
        case .monthly:
            let day = calendar.component(.day, from: baseDate)
            return "毎月\(day)日に実行"
        case .monthEnd:
            return "毎月の最終日に実行"
        case .monthStart:
            return "毎月1日に実行"
        }
    }
    
    private func updateSettings() {
        let calendar = Calendar.current
        
        repeatSettings.type = selectedType
        
        switch selectedType {
        case .weekly:
            repeatSettings.weekday = selectedWeekday
        case .monthly:
            repeatSettings.dayOfMonth = selectedDay
        default:
            // 基準日から情報を取得
            if selectedType == .weekly {
                repeatSettings.weekday = calendar.component(.weekday, from: baseDate)
            } else if selectedType == .monthly {
                repeatSettings.dayOfMonth = calendar.component(.day, from: baseDate)
            }
        }
    }
}

struct RepeatSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            RepeatSettingsView(
                repeatSettings: .constant(RepeatSettings()),
                baseDate: Date()
            )
            .environmentObject(FontSettingsManager.shared)
        }
    }
}