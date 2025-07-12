import Foundation
import FirebaseFirestore
import FirebaseAuth

class PointsManager: ObservableObject {
    @Published var currentPoints: Int = 0
    
    private let db = Firestore.firestore()
    private let pointsPerMessage = 10 // 1メッセージあたり10ポイント
    
    // ポイント読み込み
    func loadPoints(for characterId: String) {
        db.collection("CharacterDetail").document(characterId).getDocument { [weak self] document, error in
            if let error = error {
                print("❌ ポイント読み込みエラー: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists {
                let points = document.data()?["points"] as? Int ?? 0
                DispatchQueue.main.async {
                    self?.currentPoints = points
                }
                print("✅ ポイント読み込み成功: \(points)")
            } else {
                print("⚠️ キャラクタードキュメントが見つかりません")
            }
        }
    }
    
    // ポイント付与（チャット送信時）
    func addPoints(for characterId: String, completion: @escaping (Bool) -> Void = { _ in }) {
        let newPoints = currentPoints + pointsPerMessage
        
        db.collection("CharacterDetail").document(characterId).updateData([
            "points": newPoints,
            "updatedAt": Timestamp()
        ]) { [weak self] error in
            if let error = error {
                print("❌ ポイント更新エラー: \(error.localizedDescription)")
                completion(false)
            } else {
                DispatchQueue.main.async {
                    self?.currentPoints = newPoints
                }
                print("✅ ポイント追加成功: +\(self?.pointsPerMessage ?? 0) (総計: \(newPoints))")
                completion(true)
            }
        }
    }
    
    // ポイント消費（将来の機能拡張用）
    func consumePoints(for characterId: String, amount: Int, completion: @escaping (Bool) -> Void = { _ in }) {
        guard currentPoints >= amount else {
            print("❌ ポイント不足: 必要 \(amount), 現在 \(currentPoints)")
            completion(false)
            return
        }
        
        let newPoints = currentPoints - amount
        
        db.collection("CharacterDetail").document(characterId).updateData([
            "points": newPoints,
            "updatedAt": Timestamp()
        ]) { [weak self] error in
            if let error = error {
                print("❌ ポイント消費エラー: \(error.localizedDescription)")
                completion(false)
            } else {
                DispatchQueue.main.async {
                    self?.currentPoints = newPoints
                }
                print("✅ ポイント消費成功: -\(amount) (残り: \(newPoints))")
                completion(true)
            }
        }
    }
    
    // ポイント監視開始
    func startPointsListener(for characterId: String) {
        db.collection("CharacterDetail").document(characterId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                if let error = error {
                    print("❌ ポイント監視エラー: \(error.localizedDescription)")
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