import SwiftUI

struct MeetingFeatureLockedDialog: View {
    let currentProgress: Int
    let onContinueDiagnosis: () -> Void
    let onDismiss: () -> Void
    @EnvironmentObject var fontSettings: FontSettingsManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared

    private let requiredProgress = 20

    var body: some View {
        VStack(spacing: 20) {
            // ロックアイコン
            ZStack {
                Circle()
                    .fill(colorSettings.getCurrentAccentColor().opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "lock.fill")
                    .font(.system(size: 36))
                    .foregroundColor(colorSettings.getCurrentAccentColor())
            }

            // タイトル
            Text("自分会議はまだ使えません")
                .font(.system(size: 18 * fontSettings.fontSize.scale, weight: .semibold))
                .foregroundColor(colorSettings.getCurrentTextColor())
                .multilineTextAlignment(.center)

            // 説明文
            VStack(spacing: 8) {
                Text("基本分析(20問)を完了すると")
                    .font(.system(size: 14 * fontSettings.fontSize.scale))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("解禁されます")
                    .font(.system(size: 14 * fontSettings.fontSize.scale))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 進捗表示
            VStack(spacing: 12) {
                HStack {
                    Text("現在:")
                        .font(.system(size: 14 * fontSettings.fontSize.scale, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(currentProgress)/\(requiredProgress) 完了")
                        .font(.system(size: 14 * fontSettings.fontSize.scale, weight: .bold))
                        .foregroundColor(colorSettings.getCurrentAccentColor())
                }

                // プログレスバー
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景バー
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)

                        // 進捗バー
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        colorSettings.getCurrentAccentColor(),
                                        colorSettings.getCurrentAccentColor().opacity(0.7)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * CGFloat(min(Double(currentProgress) / Double(requiredProgress), 1.0)),
                                height: 12
                            )
                    }
                }
                .frame(height: 12)

                // パーセント表示
                Text("\(Int(Double(currentProgress) / Double(requiredProgress) * 100))%")
                    .font(.system(size: 12 * fontSettings.fontSize.scale, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            // ボタン
            VStack(spacing: 12) {
                // プライマリボタン
                Button(action: {
                    // ハプティックフィードバック
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()

                    onContinueDiagnosis()
                }) {
                    Text("診断を始める")
                        .font(.system(size: 16 * fontSettings.fontSize.scale, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(colorSettings.getCurrentAccentColor())
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                // セカンダリボタン
                Button(action: {
                    onDismiss()
                }) {
                    Text("閉じる")
                        .font(.system(size: 14 * fontSettings.fontSize.scale, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(height: 44)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(colorSettings.getCurrentAccentColor().opacity(0.2), lineWidth: 2)
                )
        )
        .padding(.horizontal, 32)
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()

        MeetingFeatureLockedDialog(
            currentProgress: 15,
            onContinueDiagnosis: {
                print("Continue diagnosis")
            },
            onDismiss: {
                print("Dismiss")
            }
        )
        .environmentObject(FontSettingsManager())
    }
}
