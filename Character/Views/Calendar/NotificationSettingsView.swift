import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @ObservedObject var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @Binding var notificationSettings: NotificationSettings
    
    @State private var isEnabled: Bool
    @State private var selectedValue: Int
    @State private var selectedUnit: NotificationUnit
    
    init(notificationSettings: Binding<NotificationSettings>) {
        self._notificationSettings = notificationSettings
        self._isEnabled = State(initialValue: notificationSettings.wrappedValue.isEnabled)
        self._selectedValue = State(initialValue: notificationSettings.wrappedValue.value)
        self._selectedUnit = State(initialValue: notificationSettings.wrappedValue.unit)
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
                            
                            // 通知許可状態の確認
                            if !notificationManager.isAuthorized {
                                notificationPermissionSection()
                            }
                            
                            // 通知ON/OFF設定
                            VStack(alignment: .leading, spacing: 12) {
                                Text("通知設定")
                                    .dynamicHeadline()
                                    .foregroundColor(colorSettings.getCurrentTextColor())
                                
                                Toggle(isOn: $isEnabled) {
                                    Text("通知を有効にする")
                                        .dynamicBody()
                                        .foregroundColor(colorSettings.getCurrentTextColor())
                                }
                                .disabled(!notificationManager.isAuthorized)
                            }
                            .padding()
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                            
                            // 通知タイミング設定（通知が有効な場合のみ表示）
                            if isEnabled && notificationManager.isAuthorized {
                                notificationTimingSection()
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("通知設定")
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
        .onAppear {
            notificationManager.checkAuthorizationStatus()
        }
    }
    
    @ViewBuilder
    private func notificationPermissionSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text("通知が無効です")
                    .dynamicHeadline()
                    .foregroundColor(colorSettings.getCurrentTextColor())
            }
            
            Text("予定の通知を受け取るには、通知を許可してください。")
                .dynamicBody()
                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
            
            Button(action: {
                notificationManager.requestAuthorization()
            }) {
                HStack {
                    Image(systemName: "bell")
                        .foregroundColor(.white)
                    Text("通知を許可")
                        .dynamicBody()
                        .foregroundColor(.white)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(colorSettings.getCurrentAccentColor())
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func notificationTimingSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("通知タイミング")
                .dynamicHeadline()
                .foregroundColor(colorSettings.getCurrentTextColor())
            
            // 数値選択
            VStack(alignment: .leading, spacing: 8) {
                Text("時間")
                    .dynamicCallout()
                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
                
                HStack {
                    Button(action: {
                        if selectedValue > 1 {
                            selectedValue -= 1
                        }
                    }) {
                        Image(systemName: "minus.circle")
                            .foregroundColor(colorSettings.getCurrentAccentColor())
                            .font(.title2)
                    }
                    
                    Spacer()
                    
                    Text("\(selectedValue)")
                        .dynamicTitle2()
                        .foregroundColor(colorSettings.getCurrentTextColor())
                        .frame(minWidth: 50)
                    
                    Spacer()
                    
                    Button(action: {
                        if selectedValue < 999 {
                            selectedValue += 1
                        }
                    }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(colorSettings.getCurrentAccentColor())
                            .font(.title2)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 単位選択
            VStack(alignment: .leading, spacing: 8) {
                Text("単位")
                    .dynamicCallout()
                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
                
                HStack(spacing: 8) {
                    ForEach(NotificationUnit.allCases, id: \.self) { unit in
                        Button(action: {
                            selectedUnit = unit
                        }) {
                            Text(unit.displayName)
                                .dynamicCallout()
                                .foregroundColor(selectedUnit == unit ? .white : colorSettings.getCurrentTextColor())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedUnit == unit ? colorSettings.getCurrentAccentColor() : Color.white.opacity(0.15))
                                .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
    }
    
    
    private func updateSettings() {
        notificationSettings.isEnabled = isEnabled && notificationManager.isAuthorized
        notificationSettings.value = selectedValue
        notificationSettings.unit = selectedUnit
    }
}

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NotificationSettingsView(
                notificationSettings: .constant(NotificationSettings())
            )
            .environmentObject(FontSettingsManager.shared)
        }
    }
}