import Foundation
import FirebaseFirestore

struct Big5AnalysisStats {
    static let shared = Big5AnalysisStats()
    private let db = Firestore.firestore()
    
    // 生成済みpattern数を取得
    func getGeneratedPatternCount(completion: @escaping (Int) -> Void) {
        db.collection("Big5Analysis").getDocuments { snapshot, error in
            let count = snapshot?.documents.count ?? 0
            DispatchQueue.main.async {
                completion(count)
            }
        }
    }
    
    // personalityKey別の統計取得
    func getPatternStats(completion: @escaping ([String: Int]) -> Void) {
        db.collection("Big5Analysis").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                completion([:])
                return
            }
            
            var stats: [String: Int] = [:]
            
            for doc in documents {
                let personalityKey = doc.documentID
                if let scores = PersonalityKeyGenerator.parsePersonalityKey(personalityKey) {
                    let openness = "O\(scores.o)"
                    stats[openness, default: 0] += 1
                }
            }
            
            DispatchQueue.main.async {
                completion(stats)
            }
        }
    }
    
    // 進捗レポート表示
    func printProgressReport() {
        getGeneratedPatternCount { totalGenerated in
            self.getPatternStats { stats in
                print("=== Big5解析データ生成進捗 ===")
                print("総生成数: \(totalGenerated) / 3125 (\(String(format: "%.1f", Double(totalGenerated) / 3125 * 100))%)")
                print("\n開放性別統計:")
                
                for o in 1...5 {
                    let key = "O\(o)"
                    let count = stats[key] ?? 0
                    let percentage = Double(count) / 625.0 * 100
                    print("  \(key): \(count)/625 (\(String(format: "%.1f", percentage))%)")
                }
                print("========================")
            }
        }
    }
    
    // 未生成のpersonalityKeyリストを取得（開発・デバッグ用）
    func getMissingKeys(openness: Int, completion: @escaping ([String]) -> Void) {
        let expectedKeys = PersonalityKeyGenerator.getKeysByOpenness(openness)
        
        db.collection("Big5Analysis")
            .whereField("personality_key", ">=", "O\(openness)_")
            .whereField("personality_key", "<", "O\(openness + 1)_")
            .getDocuments { snapshot, error in
                
                let existingKeys = snapshot?.documents.map { $0.documentID } ?? []
                let missingKeys = expectedKeys.filter { !existingKeys.contains($0) }
                
                DispatchQueue.main.async {
                    completion(missingKeys)
                }
            }
    }
}

// 使用例:
// Big5AnalysisStats.shared.printProgressReport()
// Big5AnalysisStats.shared.getMissingKeys(openness: 1) { missing in
//     print("開放性1で未生成: \(missing.count)個")
// }