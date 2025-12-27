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
        switch characterId {
        case "cautious", "emotional", "opposite":
            return .left
        case "active", "logical", "ideal":
            return .right
        default:
            return .left
        }
    }

    var characterIcon: String {
        // キャラクターごとのアイコン
        switch characterId {
        case "cautious":
            return "shield.fill"
        case "active":
            return "bolt.fill"
        case "emotional":
            return "heart.fill"
        case "logical":
            return "brain.head.profile"
        case "opposite":
            return "arrow.triangle.2.circlepath"
        case "ideal":
            return "star.fill"
        default:
            return "person.fill"
        }
    }

    var characterColor: String {
        // キャラクターごとの色
        switch characterId {
        case "cautious":
            return "blue"
        case "active":
            return "orange"
        case "emotional":
            return "pink"
        case "logical":
            return "purple"
        case "opposite":
            return "green"
        case "ideal":
            return "yellow"
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
