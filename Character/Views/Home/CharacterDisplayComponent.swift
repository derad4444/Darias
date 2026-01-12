import SwiftUI

struct CharacterDisplayComponent: View {
    @Binding var displayedMessage: String
    let characterConfig: CharacterConfig?
    let personalityScores: Big5Scores?
    @State private var showImageNotFoundAlert: Bool = false
    @State private var currentImageName: String

    init(
        displayedMessage: Binding<String>,
        characterConfig: CharacterConfig? = nil,
        personalityScores: Big5Scores? = nil
    ) {
        self._displayedMessage = displayedMessage
        self.characterConfig = characterConfig
        self.personalityScores = personalityScores

        // 初期画像名を設定（デフォルト画像）
        let gender = characterConfig?.gender ?? .female
        self._currentImageName = State(initialValue: "character_\(gender.rawValue)")
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
                    updateImage()
                }
        }
        .alert("画像が見つかりません", isPresented: $showImageNotFoundAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("性格に対応する画像ファイルが見つかりませんでした。デフォルト画像を表示しています。")
        }
    }

    private func updateImage() {
        let gender = characterConfig?.gender ?? .female

        // 性格スコアがある場合は性格別画像を使用
        if let scores = personalityScores {
            let fileName = PersonalityImageService.generateImageFileName(from: scores, gender: gender)

            // 画像の存在確認
            if UIImage(named: fileName) != nil {
                currentImageName = fileName
            } else {
                // 画像が見つからない場合はデフォルト画像を使用し、アラート表示
                currentImageName = "character_\(gender.rawValue)"
                showImageNotFoundAlert = true
                print("⚠️ 性格別画像が見つかりません: \(fileName)")
            }
        } else {
            // スコアがない場合はデフォルト画像
            currentImageName = "character_\(gender.rawValue)"
        }
    }

    func switchCharacter(to config: CharacterConfig, personalityScores: Big5Scores?) {
        // 新しいキャラクターに切り替え
        let gender = config.gender

        if let scores = personalityScores {
            let fileName = PersonalityImageService.generateImageFileName(from: scores, gender: gender)
            if UIImage(named: fileName) != nil {
                currentImageName = fileName
            } else {
                currentImageName = "character_\(gender.rawValue)"
                showImageNotFoundAlert = true
            }
        } else {
            currentImageName = "character_\(gender.rawValue)"
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