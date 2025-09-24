import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var fontSettings: FontSettingsManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @State private var userId: String = ""
    @State private var characterId: String = ""
    @State private var isLoading = true
    @State private var selectedTab: Int = 0
    
    private var dynamicTabBarPadding: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        // iPhone SEなど小さい機種では小さめ、大きい機種では大きめに調整
        return screenHeight * 0.065
    }

    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("読み込み中...")
                    .font(FontSettingsManager.shared.font(size: 17, weight: .regular))
            } else {
                if !characterId.isEmpty {
                    TabView(selection: $selectedTab) {
                        HomeView(userId: userId, characterId: characterId)
                            .tabItem {
                                Image(systemName: "house")
                                Text("ホーム")
                            }
                            .tag(0)

                        CalendarView(userId: userId, characterId: characterId, isPremium: false)
                            .environmentObject(FirestoreManager())
                            .tabItem {
                                Image(systemName: "calendar")
                                Text("カレンダー")
                            }
                            .tag(1)

                        CharacterDetailView(userId: userId, characterId: characterId, isPreview: false)
                            .tabItem {
                                Image(systemName: "person.crop.circle")
                                Text("キャラクター詳細")
                            }
                            .tag(2)

                        OptionView()
                            .tabItem {
                                Image(systemName: "gearshape")
                                Text("設定")
                            }
                            .tag(3)
                    }
                    .accentColor(colorSettings.getCurrentAccentColor()) // 選択中タブの色
                } else {
                    // characterIdが空の場合のエラー画面
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)

                        Text("キャラクター情報を取得できません")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("アプリを再起動するか、再ログインしてください")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("再取得") {
                            isLoading = true
                            fetchUserAndCharacter()
                        }
                        .padding()
                        .background(colorSettings.getCurrentAccentColor())
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                }
                
                // フッター上に線を自然に配置
                VStack {
                    Spacer()
                    Divider()
                        .padding(.bottom, dynamicTabBarPadding)  // 線の高さ
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            fetchUserAndCharacter()

            // タブバーを透明化
            let tabAppearance = UITabBarAppearance()
            tabAppearance.configureWithTransparentBackground()
            tabAppearance.backgroundColor = UIColor.clear
            tabAppearance.backgroundEffect = nil

            UITabBar.appearance().standardAppearance = tabAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
            UITabBar.appearance().backgroundColor = UIColor.clear
            UITabBar.appearance().isTranslucent = true
        }
    }
    private func fetchUserAndCharacter() {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            print("❌ User ID is nil or empty")
            self.isLoading = false
            return
        }

        self.userId = uid
        print("✅ Fetching character for userId: \(uid)")

        let db = Firestore.firestore()

        // usersコレクションから character_id を取得（AuthManagerと同じパターン）
        db.collection("users").document(uid).getDocument { document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ User document fetch error: \(error)")
                    self.characterId = ""
                    self.isLoading = false
                } else if let document = document, document.exists {
                    let data = document.data() ?? [:]
                    if let characterId = data["character_id"] as? String, !characterId.isEmpty {
                        self.characterId = characterId
                        print("✅ Character ID fetched from users collection: \(self.characterId)")
                        self.isLoading = false
                    } else {
                        print("⚠️ character_id not found or empty in user document")
                        print("⚠️ User data: \(data)")
                        self.characterId = ""
                        self.isLoading = false
                    }
                } else {
                    print("⚠️ User document does not exist for uid: \(uid)")
                    self.characterId = ""
                    self.isLoading = false
                }
            }
        }
    }
    
}


