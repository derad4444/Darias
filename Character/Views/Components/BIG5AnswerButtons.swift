import SwiftUI

struct BIG5AnswerButtons: View {
    let question: String
    let onAnswer: (Int) -> Void
    @EnvironmentObject var fontSettings: FontSettingsManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    
    private let answerOptions = [
        (value: 1, text: "全く当てはまらない", emoji: "😔"),
        (value: 2, text: "あまり当てはまらない", emoji: "🤔"),
        (value: 3, text: "どちらでもない", emoji: "😐"),
        (value: 4, text: "やや当てはまる", emoji: "🙂"),
        (value: 5, text: "非常に当てはまる", emoji: "😊")
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // 質問文
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20 * fontSettings.fontSize.scale, weight: .bold))
                        .foregroundColor(colorSettings.getCurrentAccentColor())
                    
                    Text("性格診断")
                        .font(.system(size: 16 * fontSettings.fontSize.scale, weight: .semibold))
                        .foregroundColor(colorSettings.getCurrentAccentColor())
                    
                    Spacer()
                }
                
                Text(question)
                    .font(.system(size: 18 * fontSettings.fontSize.scale, weight: .medium))
                    .foregroundColor(colorSettings.getCurrentTextColor())
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            // 回答選択肢
            VStack(spacing: 8) {
                ForEach(answerOptions, id: \.value) { option in
                    Button(action: {
                        // ハプティックフィードバック
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        onAnswer(option.value)
                    }) {
                        HStack(spacing: 12) {
                            // エモジとバリューの表示
                            HStack(spacing: 8) {
                                Text(option.emoji)
                                    .font(.system(size: 20 * fontSettings.fontSize.scale))
                                
                                Text("\\(option.value)")
                                    .font(.system(size: 16 * fontSettings.fontSize.scale, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        Circle()
                                            .fill(colorSettings.getCurrentAccentColor())
                                    )
                            }
                            
                            // 回答テキスト
                            Text(option.text)
                                .font(.system(size: 16 * fontSettings.fontSize.scale, weight: .medium))
                                .foregroundColor(colorSettings.getCurrentTextColor())
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            // 矢印アイコン
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14 * fontSettings.fontSize.scale, weight: .semibold))
                                .foregroundColor(colorSettings.getCurrentAccentColor().opacity(0.6))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(colorSettings.getCurrentAccentColor().opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorSettings.getCurrentAccentColor().opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(colorSettings.getCurrentAccentColor().opacity(0.1), lineWidth: 2)
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack(spacing: 20) {
        BIG5AnswerButtons(
            question: "人と話すことが好きだ",
            onAnswer: { value in
                print("Selected: \\(value)")
            }
        )
        .environmentObject(FontSettingsManager())
        
        Spacer()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}