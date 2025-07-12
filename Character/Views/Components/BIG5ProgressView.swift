import SwiftUI

struct BIG5ProgressView: View {
    let answeredCount: Int
    let totalQuestions: Int = 100
    @State private var animatedProgress: Double = 0
    @State private var showPlusAnimation = false
    @State private var animationOffset: CGFloat = 0
    @EnvironmentObject var fontSettings: FontSettingsManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    
    private var progress: Double {
        min(Double(answeredCount) / Double(totalQuestions), 1.0)
    }
    
    private var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // BIG5アイコン
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                colorSettings.getCurrentAccentColor().opacity(0.8),
                                colorSettings.getCurrentAccentColor()
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: colorSettings.getCurrentAccentColor().opacity(0.3), radius: 4, x: 0, y: 2)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14 * fontSettings.fontSize.scale, weight: .bold))
                    .foregroundColor(.white)
                    .offset(y: animationOffset)
            }
            
            // 進捗ゲージ
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("性格分析")
                        .font(.system(size: 12 * fontSettings.fontSize.scale, weight: .medium))
                        .foregroundColor(colorSettings.getCurrentTextColor())
                    
                    Spacer()
                    
                    Text("\(answeredCount)/\(totalQuestions)")
                        .font(.system(size: 12 * fontSettings.fontSize.scale, weight: .bold))
                        .foregroundColor(colorSettings.getCurrentTextColor())
                        .monospacedDigit()
                }
                
                // プログレスバー
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        // 進捗バー
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        colorSettings.getCurrentAccentColor().opacity(0.8),
                                        colorSettings.getCurrentAccentColor()
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * animatedProgress, height: 8)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8), value: animatedProgress)
                        
                        // グロー効果
                        if animatedProgress > 0 {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            colorSettings.getCurrentAccentColor().opacity(0.6),
                                            Color.clear
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * animatedProgress, height: 8)
                                .blur(radius: 2)
                        }
                    }
                }
                .frame(height: 8)
            }
            
            // プラスアニメーション
            if showPlusAnimation {
                Text("+1")
                    .font(.system(size: 14 * fontSettings.fontSize.scale, weight: .bold))
                    .foregroundColor(.green)
                    .offset(y: animationOffset)
                    .opacity(showPlusAnimation ? 0 : 1)
                    .animation(.easeOut(duration: 1.5), value: showPlusAnimation)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
        )
        .onAppear {
            // 初期アニメーション
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = progress
            }
        }
        .onChange(of: answeredCount) { newValue in
            // 回答数が変わったらアニメーション実行
            playProgressAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .big5ProgressUpdated)) { _ in
            playProgressAnimation()
        }
    }
    
    private func playProgressAnimation() {
        // アイコンのバウンスアニメーション
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            animationOffset = -8
        }
        
        // プラスアニメーション
        showPlusAnimation = true
        
        // プログレスバーのアニメーション
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            animatedProgress = progress
        }
        
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

// NotificationCenter の拡張
extension Notification.Name {
    static let big5ProgressUpdated = Notification.Name("big5ProgressUpdated")
}

#Preview {
    VStack(spacing: 20) {
        BIG5ProgressView(answeredCount: 0)
        BIG5ProgressView(answeredCount: 25)
        BIG5ProgressView(answeredCount: 50)
        BIG5ProgressView(answeredCount: 75)
        BIG5ProgressView(answeredCount: 100)
    }
    .padding()
    .environmentObject(FontSettingsManager())
}