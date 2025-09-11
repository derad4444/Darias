import SwiftUI

struct BIG5ProgressView: View {
    let answeredCount: Int
    let totalQuestions: Int = 100
    let levelUpMessage: String?
    @State private var animatedProgress: Double = 0
    @State private var showPlusAnimation = false
    @State private var animationOffset: CGFloat = 0
    @State private var showRoadmap = false
    @State private var showLevelUpAnimation = false
    @State private var levelUpScale: CGFloat = 1.0
    @State private var levelUpOpacity: Double = 0.0
    @State private var previousStage: Int = 1
    @State private var displayedLevelUpMessage: String = ""
    @EnvironmentObject var fontSettings: FontSettingsManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    
    // 3段階のマイルストーン
    private let milestones = [20, 50, 100]
    
    private var progress: Double {
        min(Double(answeredCount) / Double(totalQuestions), 1.0)
    }
    
    private var progressPercentage: Int {
        Int(progress * 100)
    }
    
    // 現在の段階を取得
    private var currentStage: Int {
        if answeredCount <= 20 { return 1 }
        if answeredCount <= 50 { return 2 }
        return 3
    }
    
    // 現在の段階内での進捗を計算（段階ごとの独立ゲージ用）
    private var stageProgress: Double {
        switch currentStage {
        case 1:
            return Double(answeredCount) / 20.0
        case 2:
            return Double(answeredCount - 20) / 30.0
        case 3:
            return Double(answeredCount - 50) / 50.0
        default:
            return 0.0
        }
    }
    
    // 現在の段階の最大値
    private var stageMaxQuestions: Int {
        switch currentStage {
        case 1: return 20
        case 2: return 30
        case 3: return 50
        default: return 20
        }
    }
    
    // 現在の段階内での回答数
    private var stageAnsweredCount: Int {
        switch currentStage {
        case 1: return answeredCount
        case 2: return answeredCount - 20
        case 3: return answeredCount - 50
        default: return answeredCount
        }
    }
    
    // 段階のタイトルを取得
    private var stageTitle: String {
        switch currentStage {
        case 1: return "基本分析"
        case 2: return "詳細分析"
        case 3: return "完全分析"
        default: return "性格分析"
        }
    }
    
    // 段階の進捗表示を取得（段階ごとの独立表示）
    private var stageProgressText: String {
        return "\(stageAnsweredCount)/\(stageMaxQuestions)"
    }
    
    // 段階1の塗りつぶし色
    private var stage1Fill: AnyShapeStyle {
        if answeredCount >= 20 {
            return AnyShapeStyle(colorSettings.getCurrentAccentColor())
        } else if answeredCount > 0 {
            return AnyShapeStyle(LinearGradient(
                gradient: Gradient(colors: [
                    colorSettings.getCurrentAccentColor().opacity(0.8),
                    colorSettings.getCurrentAccentColor()
                ]),
                startPoint: .leading,
                endPoint: .trailing
            ))
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }
    
    // 段階2の塗りつぶし色
    private var stage2Fill: AnyShapeStyle {
        if answeredCount >= 50 {
            return AnyShapeStyle(colorSettings.getCurrentAccentColor())
        } else if answeredCount > 20 {
            return AnyShapeStyle(LinearGradient(
                gradient: Gradient(colors: [
                    colorSettings.getCurrentAccentColor().opacity(0.8),
                    colorSettings.getCurrentAccentColor()
                ]),
                startPoint: .leading,
                endPoint: .trailing
            ))
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }
    
    // 段階3の塗りつぶし色
    private var stage3Fill: AnyShapeStyle {
        if answeredCount >= 100 {
            return AnyShapeStyle(colorSettings.getCurrentAccentColor())
        } else if answeredCount > 50 {
            return AnyShapeStyle(LinearGradient(
                gradient: Gradient(colors: [
                    colorSettings.getCurrentAccentColor().opacity(0.8),
                    colorSettings.getCurrentAccentColor()
                ]),
                startPoint: .leading,
                endPoint: .trailing
            ))
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }
    
    // 段階1の幅
    private var stage1Width: CGFloat {
        if answeredCount >= 20 {
            return 1.0
        } else {
            return min(Double(answeredCount) / 20.0, 1.0)
        }
    }
    
    // 段階2の幅
    private var stage2Width: CGFloat {
        if answeredCount <= 20 {
            return 0
        } else if answeredCount >= 50 {
            return 1.0
        } else {
            return min(Double(answeredCount - 20) / 30.0, 1.0)
        }
    }
    
    // 段階3の幅
    private var stage3Width: CGFloat {
        if answeredCount <= 50 {
            return 0
        } else {
            return min(Double(answeredCount - 50) / 50.0, 1.0)
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // BIG5アイコン（ボタン化）
            Button(action: {
                showRoadmap = true
            }) {
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
            }
            .buttonStyle(PlainButtonStyle())
            
            // 縦向き進捗ゲージ
            VStack(alignment: .center, spacing: 4) {
                // タイトルとプログレス（縦表示用）
                VStack(spacing: 2) {
                    Text(stageTitle)
                        .font(.system(size: 10 * fontSettings.fontSize.scale, weight: .medium))
                        .foregroundColor(colorSettings.getCurrentTextColor())
                        .multilineTextAlignment(.center)
                    
                    Text(stageProgressText)
                        .font(.system(size: 10 * fontSettings.fontSize.scale, weight: .bold))
                        .foregroundColor(colorSettings.getCurrentTextColor())
                        .monospacedDigit()
                }
                
                // 段階ごとの独立縦向きプログレスバー
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        // 背景（全体）
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 12)
                        
                        // 現在段階のプログレスバー（下から上に伸びる）
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [
                                    colorSettings.getCurrentAccentColor().opacity(0.8),
                                    colorSettings.getCurrentAccentColor()
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            ))
                            .frame(width: 10, height: geometry.size.height * stageProgress)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8), value: stageProgress)
                    }
                }
                .frame(width: 12, height: 120)
                .scaleEffect(levelUpScale)
                .opacity(1.0)
            }
            
            // プラスアニメーション
            if showPlusAnimation {
                Text("+1")
                    .font(.system(size: 12 * fontSettings.fontSize.scale, weight: .bold))
                    .foregroundColor(.green)
                    .offset(y: animationOffset)
                    .opacity(showPlusAnimation ? 0 : 1)
                    .animation(.easeOut(duration: 1.5), value: showPlusAnimation)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
        )
        .overlay {
            // レベルアップアニメーション
            if showLevelUpAnimation {
                VStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.yellow)
                        .scaleEffect(levelUpScale)
                    
                    if !displayedLevelUpMessage.isEmpty {
                        Text(displayedLevelUpMessage)
                            .font(.system(size: 12 * fontSettings.fontSize.scale, weight: .bold))
                            .foregroundColor(colorSettings.getCurrentAccentColor())
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .scaleEffect(levelUpScale)
                            .lineLimit(3)
                    } else {
                        Text("LEVEL UP!")
                            .font(.system(size: 12 * fontSettings.fontSize.scale, weight: .bold))
                            .foregroundColor(colorSettings.getCurrentAccentColor())
                            .scaleEffect(levelUpScale)
                    }
                }
                .opacity(levelUpOpacity)
                .animation(.easeInOut(duration: 0.8), value: levelUpOpacity)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: levelUpScale)
            }
        }
        .onAppear {
            // 初期アニメーション
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = stageProgress
            }
            previousStage = currentStage
        }
        .onChange(of: answeredCount) { newValue in
            // 段階変更検出
            let newStage = currentStage
            if newStage > previousStage {
                playLevelUpAnimation()
                previousStage = newStage
            } else {
                playProgressAnimation()
            }
        }
        .onChange(of: levelUpMessage) { newMessage in
            // レベルアップメッセージが変更されたときにアニメーション実行
            if let message = newMessage, !message.isEmpty {
                displayedLevelUpMessage = message
                playLevelUpAnimation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .big5ProgressUpdated)) { _ in
            let newStage = currentStage
            if newStage > previousStage {
                playLevelUpAnimation()
                previousStage = newStage
            } else {
                playProgressAnimation()
            }
        }
        .sheet(isPresented: $showRoadmap) {
            PersonalityRoadmapView(answeredCount: answeredCount)
                .environmentObject(fontSettings)
        }
    }
    
    private func playProgressAnimation() {
        // アイコンのバウンスアニメーション
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            animationOffset = -8
        }
        
        // プラスアニメーション
        showPlusAnimation = true
        
        // プログレスバーのアニメーション（段階別）
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            animatedProgress = stageProgress
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
    
    private func playLevelUpAnimation() {
        // 通常のプログレスアニメーションを実行
        playProgressAnimation()
        
        // レベルアップメッセージを設定（プロパティから優先、なければデフォルト）
        if let message = levelUpMessage, !message.isEmpty {
            displayedLevelUpMessage = message
        } else {
            displayedLevelUpMessage = "LEVEL UP!"
        }
        
        // レベルアップアニメーション開始
        showLevelUpAnimation = true
        levelUpOpacity = 1.0
        levelUpScale = 0.5
        
        // スケールアップアニメーション
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            levelUpScale = 1.2
        }
        
        // 少し待ってから縮小
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                levelUpScale = 1.0
            }
        }
        
        // フェードアウト
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                levelUpOpacity = 0.0
            }
        }
        
        // アニメーション終了
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showLevelUpAnimation = false
            levelUpScale = 1.0
            displayedLevelUpMessage = ""
        }
    }
}

// NotificationCenter の拡張
extension Notification.Name {
    static let big5ProgressUpdated = Notification.Name("big5ProgressUpdated")
}

#Preview {
    VStack(spacing: 20) {
        BIG5ProgressView(answeredCount: 0, levelUpMessage: nil)   // 開始前
        BIG5ProgressView(answeredCount: 10, levelUpMessage: nil)  // 段階1進行中
        BIG5ProgressView(answeredCount: 20, levelUpMessage: "第1段階のデータ収集が完了しました。")  // 段階1完了
        BIG5ProgressView(answeredCount: 35, levelUpMessage: nil)  // 段階2進行中
        BIG5ProgressView(answeredCount: 50, levelUpMessage: "君ともっと話したくなってきたよ。")  // 段階2完了
        BIG5ProgressView(answeredCount: 75, levelUpMessage: nil)  // 段階3進行中
        BIG5ProgressView(answeredCount: 100, levelUpMessage: "やった！全部の診断が終わったね！") // 段階3完了
    }
    .padding()
    .environmentObject(FontSettingsManager())
}