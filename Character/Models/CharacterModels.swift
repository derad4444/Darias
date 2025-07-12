import Foundation

// MARK: - Character Expression
enum CharacterExpression: String, CaseIterable {
    case normal = ""
    case smile = "_smile"
    case angry = "_angry"
    case cry = "_cry"
    case sleep = "_sleep"
}

// MARK: - Character Gender
enum CharacterGender: String, CaseIterable {
    case male = "male"
    case female = "female"
}

// MARK: - Character Config
struct CharacterConfig: Identifiable, Equatable {
    let id: String
    let name: String
    let gender: CharacterGender
    let imageSource: ImageSource
    let isDefault: Bool
    
    enum ImageSource {
        case local(String) // Asset name
        case remote(URL) // Base URL for remote images
    }
    
    static func == (lhs: CharacterConfig, rhs: CharacterConfig) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Character Info
struct CharacterInfo {
    let singleImageUrl: URL? // 一枚画像用のURL
    let initialMessage: String
}

// MARK: - Character Reply
struct CharacterReply {
    let message: String
    let voiceUrl: URL
}