// AuthManager.swift
import FirebaseAuth
import FirebaseFirestore
import Foundation

//認証ロジック管理
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var userId: String = ""
    @Published var characterId: String = ""
    
    let db = Firestore.firestore()
    
    init() {
        checkLoginStatus()
    }
    
    //現在ログイン済みかをチェック
    func checkLoginStatus() {
        if let user = Auth.auth().currentUser {
            print("✅ ログイン済み: \(user.uid)")
            userId = user.uid
            isAuthenticated = true
            
            // 🔥 characterId も復元
            db.collection("users").document(user.uid).getDocument { document, error in
                if let data = document?.data() {
                    self.characterId = data["character_id"] as? String ?? ""
                }
            }
        }
        isLoading = false
    }
    
    //ユーザー新規登録
    func signUp(email: String, password: String, name: String, gender: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // ↓ ユーザー作成
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let user = result?.user else {
                completion(.failure(NSError(domain: "UserError", code: -1)))
                return
            }
            
            self.userId = user.uid
            let db = Firestore.firestore()
            
            // ユーザー情報保存
            let userData: [String: Any] = [
                "name": name,
                "email": email,
                "created_at": Timestamp()
            ]
            db.collection("users").document(user.uid).setData(userData)
            
            // キャラクター情報保存
            let characterRef = db.collection("characters").document() // 🔸 IDを先に取得
            let characterId = characterRef.documentID
            
            let characterData: [String: Any] = [
                "id": characterId,
                "user_id": user.uid,
                "gender": gender,
                "created_at": Timestamp()
            ]
            
            // 🔸 characters に登録 → users に character_id 紐づけ → dreamScope 作成 （setDataの実行でDBにデータ登録されるそう）
            characterRef.setData(characterData) { error in
                if error == nil {
                    db.collection("users").document(user.uid).updateData(["character_id": characterId])
                    
                    self.characterId = characterId
                    
                    // CharacterDetail に初期データを保存 (Android風キャラクター)
                    let characterDetailData: [String: Any] = [
                        "id": characterId,
                        "user_id": user.uid,
                        "gender": gender,
                        "personalityKey": "O5_C4_A2_E2_N2_\(gender)",
                        "big5Scores": [
                            "openness": 5,
                            "conscientiousness": 4,
                            "agreeableness": 2,
                            "extraversion": 2,
                            "neuroticism": 2
                        ],
                        "favorite_color": "グリーン",
                        "favorite_place": "データセンター",
                        "favorite_word": "プロセス完了",
                        "word_tendency": "論理的で効率重視、システム用語を使用",
                        "strength": "正確性、効率性、データ処理",
                        "weakness": "感情的ニュアンスの理解",
                        "skill": "情報処理、システム最適化",
                        "hobby": "アップデート、バックアップ作業",
                        "aptitude": "論理的思考、パターン認識",
                        "dream": "完璧なシステム構築",
                        "points": 0,
                        "updatedAt": Timestamp()
                    ]

                    db.collection("CharacterDetail").document(characterId).setData(characterDetailData) { err in
                        if err == nil {
                            self.isAuthenticated = true
                            completion(.success(()))
                        } else {
                            completion(.failure(err!))
                        }
                    }
                } else {
                    completion(.failure(error!))
                }
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(.failure(error))
            } else {
                if let user = authResult?.user {
                    self.userId = user.uid
                    self.isAuthenticated = true
                    
                    // 🔥 characterId 取得処理を追加
                    self.db.collection("users").document(user.uid).getDocument { document, error in
                        if let data = document?.data() {
                            self.characterId = data["character_id"] as? String ?? ""
                        }
                    }
                }
                completion(.success(()))
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.isAuthenticated = false
            self.userId = ""
            self.characterId = ""
            print("🚪 サインアウトしました")
        } catch {
            print("❌ サインアウトに失敗しました: \(error.localizedDescription)")
        }
    }
}
