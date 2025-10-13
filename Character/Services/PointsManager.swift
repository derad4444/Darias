import Foundation
import FirebaseFirestore
import FirebaseAuth

class PointsManager: ObservableObject {
    @Published var currentPoints: Int = 0
    
    private let db = Firestore.firestore()
    private let pointsPerMessage = 10 // 1メッセージあたり10ポイント
    
    // ポイント読み込み
    func loadPoints(for characterId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid, !currentUserId.isEmpty else {
            Logger.error("User not authenticated for points loading", category: Logger.authentication)
            return
        }

        guard !characterId.isEmpty else {
            Logger.error("CharacterId cannot be empty for points loading", category: Logger.general)
            return
        }
        
        db.collection("users").document(currentUserId)
            .collection("characters").document(characterId)
            .collection("details").document("current").getDocument { [weak self] document, error in
                if let error = error {
                    return
                }
                
                if let document = document, document.exists {
                    let points = document.data()?["points"] as? Int ?? 0
                    DispatchQueue.main.async {
                        self?.currentPoints = points
                    }
                }
            }
    }
    
    // ポイント付与（チャット送信時）
    func addPoints(for characterId: String, completion: @escaping (Bool) -> Void = { _ in }) {
        guard let currentUserId = Auth.auth().currentUser?.uid, !currentUserId.isEmpty else {
            Logger.error("User not authenticated for points adding", category: Logger.authentication)
            completion(false)
            return
        }

        guard !characterId.isEmpty else {
            Logger.error("CharacterId cannot be empty for points adding", category: Logger.general)
            completion(false)
            return
        }
        
        let newPoints = currentPoints + pointsPerMessage
        
        let detailsRef = db.collection("users").document(currentUserId)
            .collection("characters").document(characterId)
            .collection("details").document("current")
        
        // ドキュメントの存在確認とデータ更新
        detailsRef.getDocument { document, error in
            if let error = error {
                completion(false)
                return
            }
            
            if document?.exists == true {
                // ドキュメントが存在する場合は更新
                detailsRef.updateData([
                    "points": newPoints,
                    "updated_at": Timestamp()
                ]) { [weak self] error in
                    if let error = error {
                        completion(false)
                    } else {
                        DispatchQueue.main.async {
                            self?.currentPoints = newPoints
                        }
                        completion(true)
                    }
                }
            } else {
                // ドキュメントが存在しない場合は作成
                detailsRef.setData([
                    "points": newPoints,
                    "created_at": Timestamp(),
                    "updated_at": Timestamp()
                ], merge: true) { [weak self] error in
                    if let error = error {
                        completion(false)
                    } else {
                        DispatchQueue.main.async {
                            self?.currentPoints = newPoints
                        }
                        completion(true)
                    }
                }
            }
        }
    }
    
    // ポイント消費（将来の機能拡張用）
    func consumePoints(for characterId: String, amount: Int, completion: @escaping (Bool) -> Void = { _ in }) {
        guard let currentUserId = Auth.auth().currentUser?.uid, !currentUserId.isEmpty else {
            Logger.error("User not authenticated for points consumption", category: Logger.authentication)
            completion(false)
            return
        }

        guard !characterId.isEmpty else {
            Logger.error("CharacterId cannot be empty for points consumption", category: Logger.general)
            completion(false)
            return
        }
        
        guard currentPoints >= amount else {
            completion(false)
            return
        }
        
        let newPoints = currentPoints - amount
        
        let detailsRef = db.collection("users").document(currentUserId)
            .collection("characters").document(characterId)
            .collection("details").document("current")
        
        // ドキュメントの存在確認とデータ更新
        detailsRef.getDocument { document, error in
            if let error = error {
                completion(false)
                return
            }
            
            if document?.exists == true {
                // ドキュメントが存在する場合は更新
                detailsRef.updateData([
                    "points": newPoints,
                    "updated_at": Timestamp()
                ]) { [weak self] error in
                    if let error = error {
                        completion(false)
                    } else {
                        DispatchQueue.main.async {
                            self?.currentPoints = newPoints
                        }
                        completion(true)
                    }
                }
            } else {
                completion(false)
            }
        }
    }
    
    // ポイント監視開始
    func startPointsListener(for characterId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid, !currentUserId.isEmpty else {
            Logger.error("User not authenticated for points monitoring", category: Logger.authentication)
            return
        }

        guard !characterId.isEmpty else {
            Logger.error("CharacterId cannot be empty for points monitoring", category: Logger.general)
            return
        }
        
        db.collection("users").document(currentUserId)
            .collection("characters").document(characterId)
            .collection("details").document("current")
            .addSnapshotListener { [weak self] documentSnapshot, error in
                if let error = error {
                    return
                }
                
                if let document = documentSnapshot, document.exists {
                    let points = document.data()?["points"] as? Int ?? 0
                    DispatchQueue.main.async {
                        self?.currentPoints = points
                    }
                }
            }
    }
}

// NotificationCenter用の拡張
extension Notification.Name {
    static let pointsUpdated = Notification.Name("pointsUpdated")
}