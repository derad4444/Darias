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
    @State private var showErrorAlert = false
    @State private var showSignUp = false
    @State private var showDiaryDetail = false
    @State private var selectedDiaryId: String = ""
    @State private var selectedDiaryCharacterId: String = ""
    @State private var selectedDiaryUserId: String = ""
    
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
            } else if !characterId.isEmpty {
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
                            Text("予定")
                        }
                        .tag(1)

                    NoteView(userId: userId)
                        .environmentObject(fontSettings)
                        .tabItem {
                            Image(systemName: "note.text")
                            Text("ノート")
                        }
                        .tag(2)

                    CharacterDetailView(userId: userId, characterId: characterId, isPreview: false)
                        .tabItem {
                            Image(systemName: "person.circle")
                            Text("詳細")
                        }
                        .tag(3)

                    OptionView()
                        .tabItem {
                            Image(systemName: "gearshape")
                            Text("設定")
                        }
                        .tag(4)
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

            // 日記を開く通知を監視
            NotificationCenter.default.addObserver(
                forName: .openDiary,
                object: nil,
                queue: .main
            ) { notification in
                if let userInfo = notification.userInfo,
                   let diaryId = userInfo["diaryId"] as? String,
                   let characterId = userInfo["characterId"] as? String,
                   let userId = userInfo["userId"] as? String {
                    self.selectedDiaryId = diaryId
                    self.selectedDiaryCharacterId = characterId
                    self.selectedDiaryUserId = userId
                    self.showDiaryDetail = true
                }
            }
        }
        .alert("アカウント情報の取得ができませんでした", isPresented: $showErrorAlert) {
            Button("ログアウト", role: .cancel) {
                authManager.signOut()
            }
            Button("アカウント登録") {
                showSignUp = true
            }
        } message: {
            Text("アカウントが作成されていない可能性があります。\n新規アカウントを作成する場合は「アカウント登録」を、ログイン画面に戻る場合は「ログアウト」を選択してください。")
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
                .environmentObject(authManager)
        }
        .fullScreenCover(isPresented: $showDiaryDetail) {
            NavigationStack {
                DiaryDetailView(
                    diaryId: selectedDiaryId,
                    characterId: selectedDiaryCharacterId,
                    userId: selectedDiaryUserId
                )
            }
        }
    }
    private func fetchUserAndCharacter() {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            self.isLoading = false
            self.showErrorAlert = true
            return
        }

        self.userId = uid

        let db = Firestore.firestore()

        // usersコレクションから character_id を取得（AuthManagerと同じパターン）
        db.collection("users").document(uid).getDocument { document, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.characterId = ""
                    self.isLoading = false
                    self.showErrorAlert = true
                } else if let document = document, document.exists {
                    let data = document.data() ?? [:]
                    if let characterId = data["character_id"] as? String, !characterId.isEmpty {
                        self.characterId = characterId
                        self.isLoading = false
                    } else {
                        self.characterId = ""
                        self.isLoading = false
                        self.showErrorAlert = true
                    }
                } else {
                    self.characterId = ""
                    self.isLoading = false
                    self.showErrorAlert = true
                }
            }
        }
    }
    
}


