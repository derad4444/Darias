import SwiftUI

struct BIG5ContinueDialog: View {
    let onContinue: () -> Void
    let onLater: () -> Void
    @EnvironmentObject var fontSettings: FontSettingsManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared

    var body: some View {
        VStack(spacing: 20) {
            // アイコン
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(colorSettings.getCurrentAccentColor())

            // メッセージ
            Text("次の質問に進みますか？")
                .font(.system(size: 18 * fontSettings.fontSize.scale, weight: .semibold))
                .foregroundColor(colorSettings.getCurrentTextColor())
                .multilineTextAlignment(.center)

            // ボタン
            HStack(spacing: 12) {
                Button(action: {
                    onLater()
                }) {
                    Text("後で")
                        .font(.system(size: 16 * fontSettings.fontSize.scale, weight: .medium))
                        .foregroundColor(colorSettings.getCurrentTextColor())
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    // ハプティックフィードバック
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()

                    onContinue()
                }) {
                    Text("はい")
                        .font(.system(size: 16 * fontSettings.fontSize.scale, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(colorSettings.getCurrentAccentColor())
                        .cornerRadius(12)
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

        BIG5ContinueDialog(
            onContinue: {
            },
            onLater: {
            }
        )
        .environmentObject(FontSettingsManager())
    }
}
