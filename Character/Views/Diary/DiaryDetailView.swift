import SwiftUI
import FirebaseFirestore

struct DiaryDetailView: View {
    let diaryId: String
    let characterId: String
    let userId: String
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @AppStorage("isPremium") var isPremium: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    @State private var diaryContent: String = ""
    @State private var dateText: String = ""
    @State private var userComment: String = ""
    @State private var isLoading = true
    @State private var isSavingComment = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 設定された背景グラデーション
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView("読み込み中…")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                        // 広告バナー1（日記の上）
                        if !isPremium {
                            BannerAdView(adUnitID: "ca-app-pub-3940256099942544/2934735716")
                                .frame(width: 320, height: 50)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }

                        // 日記帳のような紙のカード
                        VStack(alignment: .leading, spacing: 16) {
                            // 日付ヘッダー（日記風）
                            HStack {
                                Text(dateText)
                                    .font(.system(size: 18, weight: .medium, design: .serif))
                                    .foregroundColor(.brown)
                                Spacer()
                                Image(systemName: "book.closed")
                                    .foregroundColor(.brown.opacity(0.6))
                            }
                            .padding(.bottom, 8)
                            
                            // 日記の内容（手書き風）
                            ZStack(alignment: .topLeading) {
                                // ノートの線を本文エリアに配置
                                VStack(spacing: 22) {
                                    ForEach(0..<25, id: \.self) { _ in
                                        Rectangle()
                                            .fill(Color.blue.opacity(0.15))
                                            .frame(height: 0.5)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                Text(diaryContent)
                                    .font(.system(size: 16, weight: .regular, design: .serif))
                                    .lineSpacing(6)
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(.black.opacity(0.8))
                            }
                        }
                        .padding(24)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        // コメント欄（現代的なスタイル）
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "message")
                                    .foregroundColor(colorSettings.getCurrentAccentColor())
                                Text("あなたのコメント")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            
                            TextEditor(text: $userComment)
                                .frame(minHeight: 80)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                }
                            
                            HStack {
                                Spacer()
                                Button(action: saveUserComment) {
                                    HStack(spacing: 6) {
                                        if isSavingComment {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "checkmark")
                                            Text("保存")
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .medium))
                                }
                                .frame(width: 90, height: 40)
                                .background(colorSettings.getCurrentAccentColor())
                                .cornerRadius(20)
                                .disabled(isSavingComment)
                            }
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                        // 広告バナー2（コメント欄の下）
                        if !isPremium {
                            BannerAdView(adUnitID: "ca-app-pub-3940256099942544/2934735716")
                                .frame(width: 320, height: 50)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }

                        Spacer(minLength: 20)
                    }
                }
            }
        }
        }
        .navigationTitle("日記")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(colorSettings.getCurrentAccentColor())
                        .font(.title2)
                }
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 100 {
                        dismiss()
                    }
                }
        )
        .onAppear {
            fetchDiary()
        }
    }

    // Firestore からデータ取得
    func fetchDiary() {
        // diaryIdが空の場合は早期リターン
        guard !diaryId.isEmpty, !characterId.isEmpty, !userId.isEmpty else {
            diaryContent = "日記データを取得できませんでした"
            dateText = ""
            isLoading = false
            return
        }

        let db = Firestore.firestore()
        // キャラクター別のサブコレクションから取得
        let docRef = db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("diary").document(diaryId)

        docRef.getDocument { document, error in
            if let document = document, document.exists, let data = document.data() {
                diaryContent = data["content"] as? String ?? ""
                userComment = data["user_comment"] as? String ?? ""

                if let timestamp = data["date"] as? Timestamp {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "ja_JP")
                    formatter.dateFormat = "yyyy年M月d日"
                    dateText = formatter.string(from: timestamp.dateValue())
                } else {
                    dateText = "(日付なし)"
                }
            } else {
                diaryContent = "データを取得できませんでした"
                dateText = ""
            }

            isLoading = false
        }
    }
    
    func saveUserComment() {
        guard !userComment.isEmpty else { return }
        
        isSavingComment = true
        let db = Firestore.firestore()
        // キャラクター別のサブコレクションに保存
        let docRef = db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("diary").document(diaryId)
        
        docRef.updateData(["user_comment": userComment]) { error in
            DispatchQueue.main.async {
                isSavingComment = false
            }
        }
    }
}

//プレビュー画面表示
struct DiaryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        DiaryDetailView(diaryId: "dummyDiaryId", characterId: "dummyCharacterId", userId: "dummyUserId")
    }
}
