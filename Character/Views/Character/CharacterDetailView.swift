import SwiftUI
import FirebaseFirestore

struct CharacterDetailView: View {
    let userId: String
    let characterId: String
    var isPreview: Bool

    @EnvironmentObject var fontSettings: FontSettingsManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @AppStorage("isPremium") var isPremium: Bool = false
    
    @State private var favoriteColor: String = ""
    @State private var favoritePlace: String = ""
    @State private var favoriteWord: String = ""
    @State private var wordTendency: String = ""
    @State private var strength: String = ""
    @State private var weakness: String = ""
    @State private var skill: String = ""
    @State private var hobby: String = ""
    @State private var aptitude: String = ""
    @State private var dream: String = ""
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景グラデーション
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea(.all)

                VStack(spacing: 0) {
                    // キャラクター画像（固定表示）
                    Image("sample_character")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .padding(.top, 20)
                    
                    // スクロール可能な情報エリア
                    ScrollView {
                        VStack(spacing: 20) {
                            // 2〜11. 各項目
                            Group {
                                infoRow(label: "好きな色", value: favoriteColor)
                                infoRow(label: "好きな場所", value: favoritePlace)
                                infoRow(label: "好きな言葉", value: favoriteWord)
                                infoRow(label: "言葉の傾向", value: wordTendency)
                                infoRow(label: "短所", value: weakness)
                                infoRow(label: "長所", value: strength)
                                infoRow(label: "特技", value: skill)
                                infoRow(label: "趣味", value: hobby)
                                infoRow(label: "適正", value: aptitude)
                                infoRow(label: "夢", value: dream)
                            }
                        }
                        .padding()
                        .padding(.bottom, 100) // タブバー分のパディングを追加
                    }
                    .frame(height: max(200, geometry.size.height - geometry.safeAreaInsets.top - geometry.safeAreaInsets.bottom - 100)) // キャラクター画像とタブバー分を除外
                }
            }
        }
        .navigationTitle("キャラ詳細")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !isPreview {
                fetchCharacterDetail()
            }
            
            // ナビゲーションバーとタブバーを透明にする
            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithTransparentBackground()
            UINavigationBar.appearance().standardAppearance = navAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
            
            let tabAppearance = UITabBarAppearance()
            tabAppearance.configureWithTransparentBackground()
            tabAppearance.backgroundColor = UIColor.clear
            tabAppearance.backgroundEffect = nil
            
            UITabBar.appearance().standardAppearance = tabAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
            
            // 強制的に透明化
            UITabBar.appearance().backgroundColor = UIColor.clear
            UITabBar.appearance().isTranslucent = true
        }
    }
    // Firestoreデータ取得処理
    private func fetchCharacterDetail() {
        let db = Firestore.firestore()
        let docRef = db.collection("CharacterDetail").document(characterId)

        docRef.getDocument { document, error in
            if let data = document?.data() {
                favoriteColor = data["favorite_color"] as? String ?? ""
                favoritePlace = data["favorite_place"] as? String ?? ""
                favoriteWord = data["favorite_word"] as? String ?? ""
                wordTendency = data["word_tendency"] as? String ?? ""
                strength = data["strength"] as? String ?? ""
                weakness = data["weakness"] as? String ?? ""
                skill = data["skill"] as? String ?? ""
                hobby = data["hobby"] as? String ?? ""
                aptitude = data["aptitude"] as? String ?? ""
                dream = data["dream"] as? String ?? ""
            }
        }
    }
    
    // 情報表示用の共通View
    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .dynamicCaption()
                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
            Text(value)
                .dynamicBody()
                .foregroundColor(colorSettings.getCurrentTextColor())
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// プレビュー画面
struct CharacterDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CharacterDetailView(
                userId: "sampleUserId",
                characterId: "sampleCharacterId",
                isPreview: true
            )
            .environmentObject(FontSettingsManager.shared)
        }
    }
}
