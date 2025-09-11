import Foundation

// MARK: - BIG5 Question
struct BIG5Question {
    let id: String
    let question: String
    let trait: String
    let direction: String
}

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
    let voiceUrl: URL?
}

// MARK: - Big5 Analysis Models

// Big5特性
enum Big5Trait: String, CaseIterable {
    case openness = "openness"
    case conscientiousness = "conscientiousness"
    case extraversion = "extraversion"
    case agreeableness = "agreeableness"
    case neuroticism = "neuroticism"
    
    var displayName: String {
        switch self {
        case .openness: return "経験への開放性"
        case .conscientiousness: return "誠実性"
        case .extraversion: return "外向性"
        case .agreeableness: return "協調性"
        case .neuroticism: return "情緒安定性"
        }
    }
    
    var shortCode: String {
        switch self {
        case .openness: return "O"
        case .conscientiousness: return "C"
        case .extraversion: return "E"
        case .agreeableness: return "A"
        case .neuroticism: return "N"
        }
    }
}

// Big5解析レベル
enum Big5AnalysisLevel: Int, CaseIterable {
    case basic = 20
    case detailed = 50
    case complete = 100
    
    var displayName: String {
        switch self {
        case .basic: return "基本プログラム解析"
        case .detailed: return "学習進化解析"
        case .complete: return "完全人格解析"
        }
    }
    
    var icon: String {
        switch self {
        case .basic: return "🤖"
        case .detailed: return "🧠"
        case .complete: return "👤"
        }
    }
    
    var description: String {
        switch self {
        case .basic: return "アンドロイドとして起動したばかりの基本設定"
        case .detailed: return "多くの経験を積み、人間らしい感情が発達"
        case .complete: return "完全な人間へと進化した豊かな人格"
        }
    }
}

// Big5解析カテゴリー
enum Big5AnalysisCategory: String, CaseIterable {
    case career = "career"
    case romance = "romance"
    case stress = "stress"
    case learning = "learning"
    case decision = "decision"
    
    var displayName: String {
        switch self {
        case .career: return "仕事・キャリアスタイル"
        case .romance: return "恋愛・人間関係の特徴"
        case .stress: return "ストレス対処・感情管理"
        case .learning: return "学習・成長アプローチ"
        case .decision: return "意思決定・問題解決スタイル"
        }
    }
    
    var icon: String {
        switch self {
        case .career: return "💼"
        case .romance: return "💕"
        case .stress: return "🧘‍♀️"
        case .learning: return "📚"
        case .decision: return "🎯"
        }
    }
}

// Big5詳細解析データ
struct Big5DetailedAnalysis: Identifiable {
    let id = UUID()
    let category: Big5AnalysisCategory
    let personalityType: String
    let detailedText: String
    let keyPoints: [String]
    let analysisLevel: Big5AnalysisLevel
}

// Big5解析結果データ
struct Big5AnalysisData {
    let personalityKey: String
    let lastUpdated: Date
    let analysis20: [Big5AnalysisCategory: Big5DetailedAnalysis]?
    let analysis50: [Big5AnalysisCategory: Big5DetailedAnalysis]?
    let analysis100: [Big5AnalysisCategory: Big5DetailedAnalysis]?
    
    func getAvailableAnalysis(for level: Big5AnalysisLevel) -> [Big5AnalysisCategory: Big5DetailedAnalysis]? {
        switch level {
        case .basic:
            return analysis20
        case .detailed:
            return analysis50
        case .complete:
            return analysis100
        }
    }
}

// personalityKey生成用のスコア構造
struct Big5Scores {
    let openness: Double
    let conscientiousness: Double
    let extraversion: Double
    let agreeableness: Double
    let neuroticism: Double
    
    func toScoreMap() -> [String: Double] {
        return [
            "openness": openness,
            "conscientiousness": conscientiousness,
            "extraversion": extraversion,
            "agreeableness": agreeableness,
            "neuroticism": neuroticism
        ]
    }
    
    static func fromScoreMap(_ map: [String: Any]) -> Big5Scores? {
        guard let oValue = (map["openness"] as? Double) ?? (map["openness"] as? Int).map(Double.init),
              let cValue = (map["conscientiousness"] as? Double) ?? (map["conscientiousness"] as? Int).map(Double.init),
              let eValue = (map["extraversion"] as? Double) ?? (map["extraversion"] as? Int).map(Double.init),
              let aValue = (map["agreeableness"] as? Double) ?? (map["agreeableness"] as? Int).map(Double.init),
              let nValue = (map["neuroticism"] as? Double) ?? (map["neuroticism"] as? Int).map(Double.init) else {
            return nil
        }
        
        return Big5Scores(
            openness: oValue,
            conscientiousness: cValue,
            extraversion: eValue,
            agreeableness: aValue,
            neuroticism: nValue
        )
    }
}