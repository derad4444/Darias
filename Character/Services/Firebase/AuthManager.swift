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
        if let user = Auth.auth().currentUser, !user.uid.isEmpty {
            userId = user.uid
            isAuthenticated = true

            // 🔥 characterId も復元
            db.collection("users").document(user.uid).getDocument { document, error in
                if let error = error {
                    Logger.error("Failed to get user document", category: Logger.authentication, error: error)
                } else if let data = document?.data() {
                    self.characterId = data["character_id"] as? String ?? ""
                }
            }
        } else {
            // ユーザーが存在しないか、UIDが空の場合
            userId = ""
            characterId = ""
            isAuthenticated = false
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
            
            // キャラクターIDを生成（UUIDベース）
            let characterId = UUID().uuidString

            // usersドキュメントにcharacter_idを保存
            db.collection("users").document(user.uid).updateData(["character_id": characterId]) { error in
                if error == nil {
                    self.characterId = characterId
                    
                    // ユーザーのキャラクター詳細情報に初期データを保存
                    let characterDetailData: [String: Any] = [
                        "gender": gender,
                        "personalityKey": "O5_C4_A2_E2_N2_\(gender)",
                        "confirmedBig5Scores": [  // 確定スコアとして初期値を設定
                            "openness": 5,
                            "conscientiousness": 4,
                            "agreeableness": 2,
                            "extraversion": 2,
                            "neuroticism": 2
                        ],
                        "analysis_level": 0, // 初期は未解析（20問回答後に詳細情報が生成される）
                        "points": 0,
                        "created_at": Timestamp(),
                        "updated_at": Timestamp()
                    ]

                    // ユーザーのキャラクターサブコレクション内に詳細情報を保存
                    db.collection("users").document(user.uid)
                        .collection("characters").document(characterId)
                        .collection("details").document("current").setData(characterDetailData) { err in
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
        } catch {
            // Sign out failed
        }
    }

    var user: User? {
        return Auth.auth().currentUser
    }

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザーが見つかりません"])
        }

        // Firebase Authenticationからアカウント削除
        try await user.delete()

        // ローカルの状態をクリア
        self.isAuthenticated = false
        self.userId = ""
        self.characterId = ""
    }
}
