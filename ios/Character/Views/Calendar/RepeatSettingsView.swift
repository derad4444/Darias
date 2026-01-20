import SwiftUI

enum RepeatType: String, CaseIterable {
    case none = "繰り返さない"
    case daily = "毎日"
    case weekly = "毎週"
    case monthly = "毎月"
    case monthStart = "月初"
    case monthEnd = "月末"

    var displayName: String {
        return self.rawValue
    }
}

enum RepeatEndType: String, CaseIterable {
    case never = "終了しない"
    case onDate = "日付で終了"
    case afterOccurrences = "回数で終了"

    var displayName: String {
        return self.rawValue
    }
}

struct RepeatSettings {
    var type: RepeatType = .none
    var weekday: Int = 1 // 1=日曜日, 2=月曜日...
    var dayOfMonth: Int = 1 // 月の何日か
    var endType: RepeatEndType = .never
    var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    var occurrenceCount: Int = 10

    func getDescription(for date: Date) -> String {
        let calendar = Calendar.current
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        weekdayFormatter.locale = Locale(identifier: "ja_JP")

        var baseDescription: String
        switch type {
        case .none:
            return "繰り返さない"
        case .daily:
            baseDescription = "毎日"
        case .weekly:
            let weekdayName = weekdayFormatter.string(from: date)
            baseDescription = "毎週\(weekdayName)"
        case .monthly:
            let day = calendar.component(.day, from: date)
            baseDescription = "毎月\(day)日"
        case .monthEnd:
            baseDescription = "毎月月末"
        case .monthStart:
            baseDescription = "毎月月初（1日）"
        }

        // 終了条件を追加
        switch endType {
        case .never:
            return baseDescription
        case .onDate:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.locale = Locale(identifier: "ja_JP")
            return "\(baseDescription)（\(formatter.string(from: endDate))まで）"
        case .afterOccurrences:
            return "\(baseDescription)（\(occurrenceCount)回）"
        }
    }

    func generateDates(from startDate: Date) -> [Date] {
        guard type != .none else { return [startDate] }

        let calendar = Calendar.current
        var dates: [Date] = []
        var currentDate = startDate
        var count = 0

        while shouldContinue(currentDate: currentDate, count: count) {
            dates.append(currentDate)
            count += 1

            guard let nextDate = getNextDate(from: currentDate) else { break }
            currentDate = nextDate
        }

        return dates
    }

    private func shouldContinue(currentDate: Date, count: Int) -> Bool {
        switch endType {
        case .never:
            return count < 100 // 安全上限
        case .onDate:
            return currentDate <= endDate
        case .afterOccurrences:
            return count < occurrenceCount
        }
    }

    private func getNextDate(from date: Date) -> Date? {
        let calendar = Calendar.current

        switch type {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly:
            // 指定した日付で次の月に移動
            let components = calendar.dateComponents([.year, .month], from: date)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: calendar.date(from: components) ?? date) else {
                return nil
            }
            let maxDayInMonth = calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? 31
            let targetDay = min(dayOfMonth, maxDayInMonth)
            return calendar.date(bySetting: .day, value: targetDay, of: nextMonth)
        case .monthEnd:
            // 次の月の末日
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date),
                  let range = calendar.range(of: .day, in: .month, for: nextMonth) else {
                return nil
            }
            return calendar.date(byAdding: .day, value: range.count - 1, to: calendar.startOfMonth(for: nextMonth))
        case .monthStart:
            // 次の月の1日
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else {
                return nil
            }
            return calendar.startOfMonth(for: nextMonth)
        }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

struct RepeatSettingsView: View {
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @Binding var repeatSettings: RepeatSettings
    let baseDate: Date
    
    @State private var selectedType: RepeatType
    @State private var selectedEndType: RepeatEndType
    @State private var selectedEndDate: Date
    @State private var selectedOccurrenceCount: Int

    init(repeatSettings: Binding<RepeatSettings>, baseDate: Date) {
        self._repeatSettings = repeatSettings
        self.baseDate = baseDate
        self._selectedType = State(initialValue: repeatSettings.wrappedValue.type)
        self._selectedEndType = State(initialValue: repeatSettings.wrappedValue.endType)
        self._selectedEndDate = State(initialValue: repeatSettings.wrappedValue.endDate)
        self._selectedOccurrenceCount = State(initialValue: repeatSettings.wrappedValue.occurrenceCount)
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
                            

                            // 終了条件設定（繰り返しありの場合のみ表示）
                            if selectedType != .none {
                                endConditionSelectionView()
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
    
    @ViewBuilder
    private func endConditionSelectionView() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("終了条件")
                .dynamicHeadline()
                .foregroundColor(colorSettings.getCurrentTextColor())

            ForEach(RepeatEndType.allCases, id: \.self) { endType in
                Button(action: {
                    selectedEndType = endType
                    updateSettings()
                }) {
                    HStack {
                        Text(endType.displayName)
                            .dynamicBody()
                            .foregroundColor(colorSettings.getCurrentTextColor())

                        Spacer()

                        if selectedEndType == endType {
                            Image(systemName: "checkmark")
                                .foregroundColor(colorSettings.getCurrentAccentColor())
                        }
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // 詳細設定
            if selectedEndType == .onDate {
                DatePicker("終了日", selection: $selectedEndDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .onChange(of: selectedEndDate) { _ in
                        updateSettings()
                    }
                    .foregroundColor(colorSettings.getCurrentTextColor())
            } else if selectedEndType == .afterOccurrences {
                HStack {
                    Text("回数:")
                        .dynamicBody()
                        .foregroundColor(colorSettings.getCurrentTextColor())

                    Picker("", selection: $selectedOccurrenceCount) {
                        ForEach(1...50, id: \.self) { count in
                            Text("\(count)回").tag(count)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                    .onChange(of: selectedOccurrenceCount) { _ in
                        updateSettings()
                    }
                }
            }

            // プレビュー表示
            if selectedType != .none {
                let previewDates = getPreviewDates()
                if !previewDates.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("プレビュー:")
                            .dynamicCaption()
                            .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))

                        ForEach(previewDates.prefix(5), id: \.self) { date in
                            Text(formatDate(date))
                                .dynamicCaption()
                                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
                        }

                        if previewDates.count > 5 {
                            Text("...他\(previewDates.count - 5)回")
                                .dynamicCaption()
                                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.6))
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }

    private func getPreviewDates() -> [Date] {
        let calendar = Calendar.current
        var previewSettings = RepeatSettings()
        previewSettings.type = selectedType
        previewSettings.weekday = calendar.component(.weekday, from: baseDate)
        previewSettings.dayOfMonth = calendar.component(.day, from: baseDate)
        previewSettings.endType = selectedEndType
        previewSettings.endDate = selectedEndDate
        previewSettings.occurrenceCount = selectedOccurrenceCount

        return previewSettings.generateDates(from: baseDate)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d（EEE）"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func updateSettings() {
        let calendar = Calendar.current

        repeatSettings.type = selectedType
        repeatSettings.endType = selectedEndType
        repeatSettings.endDate = selectedEndDate
        repeatSettings.occurrenceCount = selectedOccurrenceCount

        // 基準日から曜日と日付を設定
        repeatSettings.weekday = calendar.component(.weekday, from: baseDate)
        repeatSettings.dayOfMonth = calendar.component(.day, from: baseDate)
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