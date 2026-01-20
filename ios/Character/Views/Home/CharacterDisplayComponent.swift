import SwiftUI

struct CharacterDisplayComponent: View {
    @Binding var displayedMessage: String
    let characterConfig: CharacterConfig?
    let personalityScores: Big5Scores?
    @State private var showImageNotFoundAlert: Bool = false
    @State private var currentImage: UIImage?
    @State private var isLoadingImage: Bool = false

    init(
        displayedMessage: Binding<String>,
        characterConfig: CharacterConfig? = nil,
        personalityScores: Big5Scores? = nil
    ) {
        self._displayedMessage = displayedMessage
        self.characterConfig = characterConfig
        self.personalityScores = personalityScores

        // 初期画像を設定（デフォルト画像）
        let gender = characterConfig?.gender ?? .female
        self._currentImage = State(initialValue: UIImage(named: "character_\(gender.rawValue)"))
    }

    var body: some View {
        ZStack {
            // キャラクター画像表示
            if let image = currentImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipped()
                    .allowsHitTesting(false) // HomeViewのタップ領域を使用
            } else {
                // ローディング中のプレースホルダー
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .task {
            await loadImage()
        }
        .alert("画像が見つかりません", isPresented: $showImageNotFoundAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("性格に対応する画像ファイルが見つかりませんでした。デフォルト画像を表示しています。")
        }
    }

    private func loadImage() async {
        guard !isLoadingImage else { return }
        isLoadingImage = true

        let gender = characterConfig?.gender ?? .female

        // 性格スコアがある場合は性格別画像を使用
        if let scores = personalityScores {
            // Firebase Storageから画像を取得（フォールバック付き）
            let image = await PersonalityImageService.fetchImageWithFallback(from: scores, gender: gender)
            await MainActor.run {
                currentImage = image
                isLoadingImage = false
            }
        } else {
            // スコアがない場合はデフォルト画像
            await MainActor.run {
                currentImage = PersonalityImageService.getDefaultImage(for: gender)
                isLoadingImage = false
            }
        }
    }

    func switchCharacter(to config: CharacterConfig, personalityScores: Big5Scores?) {
        // 新しいキャラクターに切り替え
        Task {
            isLoadingImage = true
            let gender = config.gender

            if let scores = personalityScores {
                let image = await PersonalityImageService.fetchImageWithFallback(from: scores, gender: gender)
                await MainActor.run {
                    currentImage = image
                    isLoadingImage = false
                }
            } else {
                await MainActor.run {
                    currentImage = PersonalityImageService.getDefaultImage(for: gender)
                    isLoadingImage = false
                }
            }
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