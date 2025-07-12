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
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("読み込み中...")
                    .font(FontSettingsManager.shared.font(size: 17, weight: .regular))
            } else {
                TabView {
                    HomeView(userId: userId, characterId: characterId)
                        .tabItem {
                            Image(systemName: "house")
                            Text("ホーム")
                        }
                    
                    CalendarView(userId: userId, characterId: characterId, isPremium: false)
                        .environmentObject(FirestoreManager())
                        .tabItem {
                            Image(systemName: "calendar")
                            Text("カレンダー")
                        }
                    
                    CharacterDetailView(userId: userId, characterId: characterId, isPreview: false)
                        .tabItem {
                            Image(systemName: "person.crop.circle")
                            Text("キャラクター詳細")
                        }
                    
                    OptionView()
                        .tabItem {
                            Image(systemName: "gearshape")
                            Text("設定")
                        }
                }
                .accentColor(colorSettings.getCurrentAccentColor()) // 選択中タブの色
                
                // フッター上に線を自然に配置
                VStack {
                    Spacer()
                    Divider()
                        .padding(.bottom, 55)  // 線の高さ
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
            print("ユーザーIDが取得できませんでした")
            return
        }
        
        self.userId = uid
        
        let db = Firestore.firestore()
        db.collection("characters")
            .whereField("user_id", isEqualTo: uid)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("characterIdの取得エラー: \(error.localizedDescription)")
                } else if let document = snapshot?.documents.first {
                    self.characterId = document.documentID
                } else {
                    print("characterIdが見つかりませんでした")
                }
                self.isLoading = false
            }
    }
}
