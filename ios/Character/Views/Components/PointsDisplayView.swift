import SwiftUI

struct PointsDisplayView: View {
    let points: Int
    @State private var animationOffset: CGFloat = 0
    @State private var showPlusAnimation = false
    @EnvironmentObject var fontSettings: FontSettingsManager
    
    var body: some View {
        HStack(spacing: 6) {
            // ポイントアイコン
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.yellow.opacity(0.8), Color.orange.opacity(0.9)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Image(systemName: "star.fill")
                    .font(.system(size: 14 * fontSettings.fontSize.scale, weight: .bold))
                    .foregroundColor(.white)
                    .offset(y: animationOffset)
            }
            
            // ポイント数値
            Text("\(points)")
                .font(.system(size: 16 * fontSettings.fontSize.scale, weight: .bold))
                .foregroundColor(.primary)
                .monospacedDigit()
            
            // プラスアニメーション
            if showPlusAnimation {
                Text("+10")
                    .font(.system(size: 14 * fontSettings.fontSize.scale, weight: .bold))
                    .foregroundColor(.green)
                    .offset(y: animationOffset)
                    .opacity(showPlusAnimation ? 0 : 1)
                    .animation(.easeOut(duration: 1.5), value: showPlusAnimation)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
        )
        .onReceive(NotificationCenter.default.publisher(for: .pointsEarned)) { _ in
            playPointsAnimation()
        }
    }
    
    private func playPointsAnimation() {
        // スターアイコンのバウンスアニメーション
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            animationOffset = -8
        }
        
        // プラスポイントアニメーション
        showPlusAnimation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                animationOffset = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showPlusAnimation = false
            animationOffset = 0
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PointsDisplayView(points: 150)
        PointsDisplayView(points: 1250)
        PointsDisplayView(points: 0)
    }
    .padding()
    .environmentObject(FontSettingsManager())
}