import SwiftUI
import FirebaseFirestore

struct DiaryDetailView: View {
    let diaryId: String
    let characterId: String
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @AppStorage("userId") private var userId: String = ""
    @AppStorage("isPremium") var isPremium: Bool = false
    
    @State private var diaryTitle: String = ""
    @State private var diaryContent: String = ""
    @State private var dateText: String = ""
    @State private var isLoading = true

    var body: some View {
        ZStack {
            // ✅ 背景グラデーション
            colorSettings.getCurrentBackgroundGradient()
                .ignoresSafeArea()

            if isLoading {
                ProgressView("読み込み中…")
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text(dateText)
                        .font(.headline)
                        .foregroundColor(.gray)

                    Text(diaryTitle)
                        .font(.title2)
                        .bold()

                    ScrollView {
                        Text(diaryContent)
                            .padding(.top)
                    }

                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("日記")
        .onAppear {
            fetchDiary()
        // 広告やAI用エリアを追加しやすい
        }.safeAreaInset(edge: .bottom) {
            // if !isPremium {
            //     // テスト用ID（本番時は差し替え）
            //     BannerAdView(adUnitID: "ca-app-pub-3940256099942544/2934735716")
            //         .frame(width: 320, height: 50)
            //         .padding(.bottom, 8)
            // }
        }
    }

    // Firestore からデータ取得
    func fetchDiary() {
        let db = Firestore.firestore()
        let docRef = db.collection("diaries").document(diaryId)

        docRef.getDocument { document, error in
            if let document = document, document.exists, let data = document.data() {
                diaryTitle = data["title"] as? String ?? "(タイトルなし)"
                diaryContent = data["content"] as? String ?? ""

                if let timestamp = data["createdAt"] as? Timestamp {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "ja_JP")
                    formatter.dateFormat = "yyyy年M月d日"
                    dateText = formatter.string(from: timestamp.dateValue())
                } else {
                    dateText = "(日付なし)"
                }
            } else {
                diaryTitle = "読み込みエラー"
                diaryContent = "データを取得できませんでした"
                dateText = ""
            }

            isLoading = false
        }
    }
}

//プレビュー画面表示
struct DiaryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        DiaryDetailView(diaryId: "dummyDiaryId", characterId: "dummyCharacterId")
    }
}
