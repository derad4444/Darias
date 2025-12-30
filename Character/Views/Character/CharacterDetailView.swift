import SwiftUI
import FirebaseFirestore

// 選択された解析データを保持する構造体
struct SelectedAnalysisData: Identifiable {
    let id = UUID()
    let analysis: Big5DetailedAnalysis
    let level: Big5AnalysisLevel
}

struct CharacterDetailView: View {
    let userId: String
    let characterId: String
    var isPreview: Bool

    @EnvironmentObject var fontSettings: FontSettingsManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
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
    @State private var characterExpression: CharacterExpression = .normal
    @State private var characterGender: CharacterGender?
    @State private var analysisLevel: Int = 0  // 0, 20, 50, 100

    // Big5解析関連
    @StateObject private var big5AnalysisService = Big5AnalysisService()
    @State private var currentAnalysisLevel: Big5AnalysisLevel?
    @State private var selectedAnalysisData: SelectedAnalysisData?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景グラデーション
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                    // 1つ目のバナー広告（キャラクター画像の上）
                    if subscriptionManager.shouldDisplayBannerAd() {
                        BannerAdView(adUnitID: Config.characterDetailTopBannerAdUnitID)
                            .frame(height: 50)
                            .background(Color.clear)
                            .onAppear {
                                subscriptionManager.trackBannerAdImpression()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }

                    // キャラクター画像（Assets内の画像を使用）
                    if let imageName = getCharacterImageName() {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .onTapGesture {
                                triggerRandomExpression()
                            }
                            .frame(width: 200, height: 200)
                            .padding(.top, 20)
                    } else {
                        // 性別情報読み込み中
                        ProgressView()
                            .frame(width: 200, height: 200)
                            .padding(.top, 20)
                    }

                    // Big5性格解析セクション（キャラクター画像の直下）
                    big5AnalysisSection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    // 情報エリア
                    VStack(spacing: 0) {
                        // 基本情報
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                        // 2つ目のバナー広告（性格表示の一番下）
                        if subscriptionManager.shouldDisplayBannerAd() {
                            BannerAdView(adUnitID: Config.characterDetailBottomBannerAdUnitID)
                                .frame(height: 50)
                                .background(Color.clear)
                                .onAppear {
                                    subscriptionManager.trackBannerAdImpression()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
        }
        .navigationTitle("キャラ詳細")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !isPreview {
                fetchCharacterDetail()
                fetchBig5Analysis()
            }

            // サブスクリプション監視開始
            subscriptionManager.startMonitoring()

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
        .onDisappear {
            subscriptionManager.stopMonitoring()
        }
        .sheet(item: $selectedAnalysisData) { data in
            Big5AnalysisDetailView(
                analysis: data.analysis,
                analysisLevel: data.level
            )
            .environmentObject(fontSettings)
            .onAppear {
                print("✅ シート表示: \(data.analysis.category.displayName)")
            }
        }
    }
    
    // MARK: - Character Expression Functions
    private func getCharacterImageName() -> String? {
        guard let gender = characterGender else { return nil }
        let genderPrefix = "character_\(gender.rawValue)"
        switch characterExpression {
        case .normal:
            return genderPrefix
        case .smile:
            return "\(genderPrefix)_smile"
        case .angry:
            return "\(genderPrefix)_angry"
        case .cry:
            return "\(genderPrefix)_cry"
        case .sleep:
            return "\(genderPrefix)_sleep"
        }
    }
    
    private func triggerRandomExpression() {
        let expressions: [CharacterExpression] = [.normal, .smile, .angry, .cry, .sleep]
        let availableExpressions = expressions.filter { $0 != characterExpression }
        characterExpression = availableExpressions.randomElement() ?? .smile
    }
    
    // Firestoreデータ取得処理
    private func fetchCharacterDetail() {
        let db = Firestore.firestore()
        // ユーザーのキャラクター詳細からデータを取得
        let docRef = db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("details").document("current")

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

                // 分析レベルを取得
                analysisLevel = data["analysis_level"] as? Int ?? 0

                // 性別情報を取得
                if let genderString = data["gender"] as? String {
                    if genderString == "男性" {
                        characterGender = .male
                    } else {
                        characterGender = .female
                    }
                }
            }
        }
    }
    
    // 情報表示用の共通View
    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        // 空の値の場合は非表示にする
        if !value.isEmpty && value != "未設定" && value.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
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
    
    // MARK: - Big5 Analysis Section
    
    @ViewBuilder
    private var big5AnalysisSection: some View {
        // 100問完了時（analysisLevel == 100）のみBig5Analysisを表示
        if analysisLevel >= 100, let analysisLevel = currentAnalysisLevel {
            VStack(alignment: .leading, spacing: 12) {
                // セクションヘッダー
                HStack {
                    Text("\(analysisLevel.icon) \(analysisLevel.displayName)")
                        .dynamicTitle2()
                        .foregroundColor(colorSettings.getCurrentTextColor())
                        .fontWeight(.bold)
                    Spacer()
                    Text("(\(analysisLevel.rawValue)/100)")
                        .dynamicCaption()
                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                }
                .padding(.bottom, 12)
                
                // 解析カテゴリー一覧
                if let analysisData = big5AnalysisService.currentAnalysisData {
                    let availableCategories = big5AnalysisService.getAvailableCategories(for: analysisLevel)
                    let categoryAnalysis = analysisData.getAvailableAnalysis(for: analysisLevel)
                    
                    ForEach(availableCategories, id: \.self) { category in
                        if let analysis = categoryAnalysis?[category] {
                            analysisRowButton(analysis: analysis)
                        } else {
                            analysisPlaceholderRow(category: category)
                        }
                    }
                } else if big5AnalysisService.isLoading {
                    loadingAnalysisRows(for: analysisLevel)
                } else {
                    noAnalysisDataRow()
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        } else if analysisLevel < 20 {
            // 20問未満の場合のみ、解析レベルに達していないメッセージを表示
            analysisNotAvailableSection
        }
        // 20問以上100問未満の場合は、Big5Analysisセクション自体を表示しない
    }
    
    @ViewBuilder
    private func analysisRowButton(analysis: Big5DetailedAnalysis) -> some View {
        Button {
            // デバッグログ
            print("🔍 タップされたカテゴリ: \(analysis.category.displayName)")
            print("🔍 currentAnalysisLevel: \(String(describing: currentAnalysisLevel))")
            print("🔍 analysisData: \(big5AnalysisService.currentAnalysisData != nil ? "存在" : "nil")")

            // 選択されたデータを保存
            if let level = currentAnalysisLevel {
                let data = SelectedAnalysisData(analysis: analysis, level: level)
                print("✅ selectedAnalysisData を設定: \(analysis.category.displayName)")
                selectedAnalysisData = data
            } else {
                print("❌ currentAnalysisLevel が nil")
            }
        } label: {
            HStack {
                Text(analysis.category.icon)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.category.displayName)
                        .dynamicBody()
                        .foregroundColor(colorSettings.getCurrentTextColor())
                        .fontWeight(.medium)
                    
                    Text(analysis.personalityType)
                        .dynamicCaption()
                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.5))
                    .font(.caption)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func analysisPlaceholderRow(category: Big5AnalysisCategory) -> some View {
        HStack {
            Text(category.icon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category.displayName)
                    .dynamicBody()
                    .foregroundColor(colorSettings.getCurrentTextColor())
                    .fontWeight(.medium)
                
                Text("解析データが見つかりませんでした")
                    .dynamicCaption()
                    .foregroundColor(.red.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(.red.opacity(0.7))
                .font(.caption)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func loadingAnalysisRows(for level: Big5AnalysisLevel) -> some View {
        let categories = big5AnalysisService.getAvailableCategories(for: level)
        ForEach(categories, id: \.self) { category in
            HStack {
                Text(category.icon)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.displayName)
                        .dynamicBody()
                        .foregroundColor(colorSettings.getCurrentTextColor())
                        .fontWeight(.medium)
                    
                    Text("AI解析データ生成中...")
                        .dynamicCaption()
                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                }
                
                Spacer()
                
                ProgressView()
                    .scaleEffect(0.8)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private func noAnalysisDataRow() -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("解析データを取得できませんでした")
                    .dynamicBody()
                    .foregroundColor(colorSettings.getCurrentTextColor())
                    .fontWeight(.medium)
                
                if let errorMessage = big5AnalysisService.errorMessage {
                    Text(errorMessage)
                        .dynamicCaption()
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var analysisNotAvailableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🤖 性格解析")
                    .dynamicTitle2()
                    .foregroundColor(colorSettings.getCurrentTextColor())
                    .fontWeight(.bold)
                Spacer()
            }
            
            Text("性格解析を行うには、最低20問のBig5質問に回答してください。\nチャットでキャラクターと会話を続けると、時々性格質問が表示されます。")
                .dynamicBody()
                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Big5 Analysis Data Fetching
    
    private func fetchBig5Analysis() {
        // まず、Big5の進捗レベルを確認
        checkBig5Progress { answeredCount in
            if let analysisLevel = big5AnalysisService.determineAnalysisLevel(answeredCount: answeredCount) {
                currentAnalysisLevel = analysisLevel
                
                // 解析データを取得
                big5AnalysisService.fetchCharacterAnalysis(characterId: characterId, userId: userId) { result in
                    switch result {
                    case .success(_):
                        // データは既にサービス内で設定済み
                        break
                    case .failure(let error):
                        break
                    }
                }
            } else {
                currentAnalysisLevel = nil
            }
        }
    }
    
    private func checkBig5Progress(completion: @escaping (Int) -> Void) {
        let db = Firestore.firestore()
        db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("big5Progress").document("current")
            .getDocument { document, error in
                if let data = document?.data(),
                   let answeredQuestions = data["answeredQuestions"] as? [[String: Any]] {
                    DispatchQueue.main.async {
                        completion(answeredQuestions.count)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(0)
                    }
                }
            }
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