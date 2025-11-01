import SwiftUI

struct CharacterDisplayComponent: View {
    @Binding var displayedMessage: String
    @Binding var currentExpression: CharacterExpression
    let characterConfig: CharacterConfig?
    @State private var currentImageName: String

    init(
        displayedMessage: Binding<String>,
        currentExpression: Binding<CharacterExpression>,
        characterConfig: CharacterConfig? = nil
    ) {
        self._displayedMessage = displayedMessage
        self._currentExpression = currentExpression
        self.characterConfig = characterConfig

        // 初期画像名を設定
        let gender = characterConfig?.gender ?? .female
        self._currentImageName = State(initialValue: "character_\(gender.rawValue)")
        print("🎨 CharacterDisplayComponent初期化 - gender: \(gender.rawValue), imageName: character_\(gender.rawValue)")
    }
    
    var body: some View {
        ZStack {
            // キャラクター画像表示（Assets内の画像を使用）
            Image(currentImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipped()
                .allowsHitTesting(false) // HomeViewのタップ領域を使用
                .onAppear {
                    updateImageBasedOnGender()
                }
                .onChange(of: currentExpression) { newExpression in
                    changeExpression(to: newExpression)
                }
        }
    }
    
    private func updateImageBasedOnGender() {
        let gender = characterConfig?.gender ?? .female
        let imageName = "character_\(gender.rawValue)"
        print("🖼️ 画像を更新: \(imageName) (gender: \(gender.rawValue))")
        currentImageName = imageName
    }
    
    func changeExpression(to expression: CharacterExpression) {
        let gender = characterConfig?.gender ?? .female
        let genderPrefix = "character_\(gender.rawValue)"
        
        switch expression {
        case .normal:
            currentImageName = genderPrefix
        case .smile:
            currentImageName = "\(genderPrefix)_smile"
        case .angry:
            currentImageName = "\(genderPrefix)_angry"
        case .cry:
            currentImageName = "\(genderPrefix)_cry"
        case .sleep:
            currentImageName = "\(genderPrefix)_sleep"
        }
    }
    
    func switchCharacter(to config: CharacterConfig) {
        let genderPrefix = "character_\(config.gender.rawValue)"
        currentImageName = genderPrefix
    }
    
    // MARK: - Interactive Expression Functions
    
    private func triggerTapExpression() {
        // ランダムな表情変更
        let expressions: [CharacterExpression] = [.smile, .normal, .angry, .cry]
        let randomExpression = expressions.randomElement() ?? .normal
        changeExpression(to: randomExpression)
        
        // タップ効果音やフィードバック
        playTapFeedback()
    }
    
    private func triggerDragExpression(translation: CGSize) {
        // ドラッグ方向に応じた表情変更
        let expression: CharacterExpression
        
        if abs(translation.width) > abs(translation.height) {
            if translation.width > 50 {
                expression = .smile  // 右フリック: 笑顔
            } else if translation.width < -50 {
                expression = .angry  // 左フリック: 怒り
            } else {
                expression = .normal
            }
        } else {
            if translation.height > 50 {
                expression = .cry    // 下フリック: 泣き
            } else if translation.height < -50 {
                expression = .smile  // 上フリック: 笑顔
            } else {
                expression = .normal
            }
        }
        
        changeExpression(to: expression)
    }
    
    private func playTapFeedback() {
        // タップ時のフィードバック効果
        
        // 触覚フィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 将来的に音効果を追加可能
        // AudioService.shared.playTapSound()
    }
    
    func startIdleExpression() {
        // 通常表情に戻す
        changeExpression(to: .normal)
    }
    
    func playRandomExpression() {
        // ランダムな表情変更
        let expressions: [CharacterExpression] = [.normal, .smile, .angry, .cry, .sleep]
        let randomExpression = expressions.randomElement() ?? .normal
        changeExpression(to: randomExpression)
    }
}

// MARK: - Placeholder Character View
struct PlaceholderCharacterView: View {
    @State private var pulse = false
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 最適化されたキャラクターシルエット
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.pink.opacity(0.4),
                            Color.purple.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(pulse ? 1.01 : 0.99)
                .animation(
                    isAnimating ? .easeInOut(duration: 2.0).repeatForever(autoreverses: true) : .none,
                    value: pulse
                )
            
            VStack(spacing: 20) {
                // キャラクターアイコン
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(radius: 2)
                
                // ステータステキスト
                Text("キャラクター")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                
                // サブテキスト
                Text("準備完了")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                isAnimating = true
                pulse = true
            }
        }
        .onDisappear {
            isAnimating = false
            pulse = false
        }
    }
}