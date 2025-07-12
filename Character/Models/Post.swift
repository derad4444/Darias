import Foundation
import FirebaseFirestore

struct Post: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let characterId: String
    let content: String
    let timestamp: Date
    let analysisResult: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case characterId = "character_id"
        case content
        case timestamp
        case analysisResult = "analysis_result"
    }
}

// チャットメッセージ表示用の構造体
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}