// Character/Models/SixPersonMeeting.swift

import Foundation
import FirebaseFirestore

// MARK: - 会議全体のデータモデル

struct SixPersonMeeting: Identifiable, Codable {
    var id: String = ""
    let conversation: MeetingConversation
    let statsData: MeetingStatsData
    let createdAt: Date

    // Firestoreにはない、追加フィールド（オプショナル）
    let personalityKey: String?
    let concernCategory: String?
    let usageCount: Int?
    let lastUsedAt: Date?

    enum CodingKeys: String, CodingKey {
        case conversation
        case statsData
        case createdAt
        case personalityKey
        case concernCategory
        case usageCount
        case lastUsedAt
    }
}

// MARK: - 会話データ

struct MeetingConversation: Codable {
    let rounds: [ConversationRound]
    let conclusion: MeetingConclusion
}

struct ConversationRound: Codable, Identifiable {
    var id: Int { roundNumber }
    let roundNumber: Int
    let messages: [ConversationMessage]
}

struct ConversationMessage: Codable, Identifiable {
    var id: String { "\(characterId)_\(timestamp)" }
    let characterId: String
    let characterName: String
    let text: String
    let timestamp: String

    var position: MessagePosition {
        // 左右の配置を決定
        // 左側（慎重派グループ）: original, ideal, wise
        // 右側（行動派グループ）: opposite, shadow, child
        switch characterId {
        case "original", "ideal", "wise":
            return .left
        case "opposite", "shadow", "child":
            return .right
        default:
            return .left
        }
    }

    var characterIcon: String {
        // キャラクターごとのアイコン（仕様書のアイコンに対応）
        switch characterId {
        case "original":
            return "person.fill"           // 🧑 今の自分
        case "opposite":
            return "arrow.triangle.2.circlepath"  // 🔄 真逆の自分
        case "ideal":
            return "star.fill"             // ✨ 理想の自分
        case "shadow":
            return "person.crop.circle"    // 👤 本音の自分
        case "child":
            return "figure.walk"           // 👶 子供の頃の自分
        case "wise":
            return "person.crop.square.filled.and.at.rectangle"  // 👴 未来の自分(70歳)
        default:
            return "person.fill"
        }
    }

    var characterColor: String {
        // キャラクターごとの色
        switch characterId {
        case "original":
            return "blue"      // 今の自分 - 冷静な青
        case "opposite":
            return "orange"    // 真逆の自分 - 活発なオレンジ
        case "ideal":
            return "purple"    // 理想の自分 - 高貴な紫
        case "shadow":
            return "red"       // 本音の自分 - 率直な赤
        case "child":
            return "green"     // 子供の頃の自分 - 新鮮な緑
        case "wise":
            return "brown"     // 未来の自分 - 落ち着いた茶色
        default:
            return "gray"
        }
    }
}

enum MessagePosition {
    case left
    case right
}

struct MeetingConclusion: Codable {
    let summary: String
    let recommendations: [String]
    let nextSteps: [String]
}

// MARK: - 統計データ

struct MeetingStatsData: Codable {
    let similarCount: Int
    let totalUsers: Int
    let avgAge: Int
    let percentile: Int
    let personalityKey: String

    var displayText: String {
        if similarCount > 0 {
            return "\(similarCount)人の似た性格の方のデータを参考にしています"
        } else {
            return "あなた専用の分析を生成しました"
        }
    }
}

// MARK: - 会議履歴

struct MeetingHistory: Identifiable, Codable {
    var id: String?
    let sharedMeetingId: String
    let userConcern: String
    let concernCategory: String
    let userBIG5: Big5Scores?
    let cacheHit: Bool
    let createdAt: Date

    var categoryDisplayName: String {
        getCategoryDisplayName(concernCategory)
    }

    enum CodingKeys: String, CodingKey {
        case sharedMeetingId
        case userConcern
        case concernCategory
        case userBIG5
        case cacheHit
        case createdAt
    }
}

// MARK: - カテゴリ表示名

func getCategoryDisplayName(_ category: String) -> String {
    let categoryNames: [String: String] = [
        "career": "キャリア・仕事",
        "romance": "恋愛・人間関係",
        "money": "お金・経済",
        "health": "健康・ライフスタイル",
        "family": "家族・子育て",
        "future": "将来・人生設計",
        "hobby": "趣味・自己実現",
        "study": "学習・スキル",
        "moving": "引っ越し・住居",
        "other": "その他"
    ]

    return categoryNames[category] ?? "その他"
}

// MARK: - カテゴリ一覧

enum ConcernCategory: String, CaseIterable, Identifiable {
    case career = "career"
    case romance = "romance"
    case money = "money"
    case health = "health"
    case family = "family"
    case future = "future"
    case hobby = "hobby"
    case study = "study"
    case moving = "moving"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        getCategoryDisplayName(rawValue)
    }

    var icon: String {
        switch self {
        case .career: return "briefcase.fill"
        case .romance: return "heart.fill"
        case .money: return "yensign.circle.fill"
        case .health: return "heart.text.square.fill"
        case .family: return "house.fill"
        case .future: return "calendar.badge.clock"
        case .hobby: return "paintbrush.fill"
        case .study: return "book.fill"
        case .moving: return "building.2.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - API Request/Response

struct GenerateMeetingRequest: Codable {
    let userId: String
    let characterId: String
    let concern: String
    let concernCategory: String?
}

struct GenerateMeetingResponse: Codable {
    let success: Bool
    let meetingId: String
    let conversation: MeetingConversation
    let statsData: MeetingStatsData
    let cacheHit: Bool
    let usageCount: Int
    let duration: Int
}
