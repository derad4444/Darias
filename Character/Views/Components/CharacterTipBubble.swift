import SwiftUI

struct CharacterTipBubble: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 吹き出し本体
            VStack(alignment: .leading, spacing: 12) {
                Text(message)
                    .font(.callout)
                    .lineLimit(nil)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                HStack {
                    Spacer()
                    Button("わかった！") {
                        withAnimation(.easeOut(duration: 0.3)) {
                            onDismiss()
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )

            // 吹き出しの矢印（下向き）
            TipBubbleArrow()
                .fill(Color(.systemBackground))
                .frame(width: 20, height: 10)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .offset(y: -1)
        }
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct TipBubbleArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack {
        CharacterTipBubble(
            message: "早速、お話ししましょう！"
        ) {
        }
        .padding()

        Spacer()

        CharacterTipBubble(
            message: "性格解析は全部で100問あるよ。好きなタイミングで「話題ある？」と話しかけてくれれば質問するから答えてね！"
        ) {
        }
        .padding()

        Spacer()
    }
    .background(Color(.systemGray6))
}