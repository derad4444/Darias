import SwiftUI

struct SimpleAnswerButtons: View {
    let question: String
    let onAnswer: (Int) -> Void
    @EnvironmentObject var fontSettings: FontSettingsManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // 選択肢ボタン（1⚪ 2⚪ 3⚪ 4⚪ 5⚪の形）
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { number in
                    Button(action: {
                        // ハプティックフィードバック
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        onAnswer(number)
                    }) {
                        HStack(spacing: 6) {
                            Text("\(number)")
                                .dynamicBody()
                                .fontWeight(.semibold)
                            
                            Circle()
                                .fill(colorSettings.getCurrentAccentColor())
                                .frame(width: 8, height: 8)
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(colorSettings.getCurrentAccentColor().opacity(0.3), lineWidth: 1)
                        )
                    }
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.1), value: false)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white, lineWidth: 2)
        )
        .padding(.horizontal, 20)
    }
}

struct SimpleAnswerButtons_Previews: PreviewProvider {
    static var previews: some View {
        SimpleAnswerButtons(question: "人と話すことが好きだ") { _ in }
            .environmentObject(FontSettingsManager())
    }
}