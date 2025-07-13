import SwiftUI

struct CharacterDisplayComponent: View {
    @Binding var displayedMessage: String
    let singleImageUrl: URL?
    let characterConfig: CharacterConfig?
    @State private var live2DCharacterViewModel: Live2DCharacterViewModel?
    
    init(
        displayedMessage: Binding<String>,
        singleImageUrl: URL? = nil,
        characterConfig: CharacterConfig? = nil
    ) {
        self._displayedMessage = displayedMessage
        self.singleImageUrl = singleImageUrl
        self.characterConfig = characterConfig
    }
    
    var body: some View {
        ZStack {
            // キャラクター表示（背景レイヤー）
            if singleImageUrl != nil {
                CharacterView(singleImageUrl: singleImageUrl)
                    .clipped()
                    .allowsHitTesting(false)
                    .onAppear {
                        print("静的画像表示")
                    }
            } else {
                // ホーム画面で直接Live2Dを表示
                Live2DCharacterView(
                    modelName: "character_\(characterConfig?.gender.rawValue ?? "female")",
                    gender: characterConfig?.gender ?? .female
                )
                .clipped()
                .allowsHitTesting(true)
                .onAppear {
                    print("Live2D表示開始")
                    if !displayedMessage.isEmpty {
                        startLipSyncIfNeeded()
                    }
                }
                .onChange(of: displayedMessage) { _, message in
                    print("🔍 CharacterDisplayComponent - メッセージ変更: \(message)")
                    if message.isEmpty {
                        stopLipSync()
                    } else {
                        startLipSyncIfNeeded()
                    }
                }
                .onTapGesture {
                    print("🔍 CharacterDisplayComponent - タップされました")
                    // タップ時のモーション再生とランダム表情変更
                    triggerTapMotion()
                }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            let translation = value.translation
                            print("🔍 CharacterDisplayComponent - ドラッグ終了: \(translation)")
                            
                            // ドラッグ方向に応じてモーション再生
                            triggerDragMotion(translation: translation)
                        }
                )
            }
            
            // 吹き出し（上部固定）
            if !displayedMessage.isEmpty {
                VStack {
                    Text(displayedMessage)
                        .padding()
                        .background(Color.white.opacity(0.85))
                        .foregroundColor(.black)
                        .cornerRadius(16)
                        .padding(.horizontal)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 10)
            }
        }
    }
    
    private func startLipSyncIfNeeded() {
        // Live2Dキャラクターの話し始めアニメーション
        if live2DCharacterViewModel == nil {
            live2DCharacterViewModel = Live2DCharacterViewModel(gender: characterConfig?.gender ?? .female)
        }
        live2DCharacterViewModel?.startLipSync()
        print("キャラクターが話し始めました")
    }
    
    private func stopLipSync() {
        // Live2Dキャラクターの話し終わりアニメーション
        live2DCharacterViewModel?.stopLipSync()
        print("キャラクターが話し終わりました")
    }
    
    func changeExpression(to expression: CharacterExpression) {
        // Live2Dキャラクターの表情変更
        live2DCharacterViewModel?.changeExpression(to: expression)
        print("表情変更: \(expression)")
    }
    
    func switchCharacter(to config: CharacterConfig) {
        // キャラクター切り替え
        live2DCharacterViewModel?.switchGender()
        print("キャラクター切り替え: \(config.name)")
    }
    
    // MARK: - Interactive Motion Functions
    
    private func triggerTapMotion() {
        // タップ時のモーション再生
        let tapMotions = ["Tap"]
        let randomMotion = tapMotions.randomElement() ?? "Tap"
        
        // Live2Dモデルでのモーション再生
        if let viewModel = live2DCharacterViewModel {
            viewModel.playMotion(randomMotion)
        }
        
        // ランダムな表情変更
        let expressions: [CharacterExpression] = [.smile, .normal, .angry, .cry]
        let randomExpression = expressions.randomElement() ?? .normal
        changeExpression(to: randomExpression)
        
        // タップ効果音やフィードバック
        playTapFeedback()
    }
    
    private func triggerDragMotion(translation: CGSize) {
        let motionName: String
        
        // ドラッグ方向に応じたモーション決定
        if abs(translation.width) > abs(translation.height) {
            if translation.width > 50 {
                motionName = "FlickRight"
            } else if translation.width < -50 {
                motionName = "FlickLeft"
            } else {
                motionName = "Idle"
            }
        } else {
            if translation.height > 50 {
                motionName = "FlickDown"
            } else if translation.height < -50 {
                motionName = "FlickUp"
            } else {
                motionName = "Idle"
            }
        }
        
        // Live2Dモデルでのモーション再生
        if let viewModel = live2DCharacterViewModel {
            viewModel.playMotion(motionName)
        }
        
        // ドラッグ方向に応じた表情変更
        let expression: CharacterExpression
        switch motionName {
        case "FlickLeft", "FlickRight":
            expression = .angry
        case "FlickUp":
            expression = .smile
        case "FlickDown":
            expression = .cry
        default:
            expression = .normal
        }
        
        changeExpression(to: expression)
    }
    
    private func playTapFeedback() {
        // タップ時のフィードバック効果
        print("🔍 CharacterDisplayComponent - タップフィードバック再生")
        
        // 触覚フィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 将来的に音効果を追加可能
        // AudioService.shared.playTapSound()
    }
    
    func startIdleMotion() {
        // アイドル状態のモーション開始
        if let viewModel = live2DCharacterViewModel {
            viewModel.playMotion("Idle")
        }
    }
    
    func playRandomMotion() {
        // ランダムモーションの再生
        let motions = ["Idle", "Tap", "FlickLeft", "FlickRight", "FlickUp", "FlickDown"]
        let randomMotion = motions.randomElement() ?? "Idle"
        
        if let viewModel = live2DCharacterViewModel {
            viewModel.playMotion(randomMotion)
        }
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