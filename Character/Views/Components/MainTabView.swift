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
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }
        
        self.userId = uid
        
        let db = Firestore.firestore()
        db.collection("characters")
            .whereField("user_id", isEqualTo: uid)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    // Character ID fetch error handled silently
                } else if let document = snapshot?.documents.first {
                    self.characterId = document.documentID
                }
                self.isLoading = false
            }
    }
    
}


