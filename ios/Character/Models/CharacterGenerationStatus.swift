import Foundation
import FirebaseFirestore

/// キャラクター生成状態を表すモデル
struct CharacterGenerationStatus: Codable {
    let stage: Int
    let status: GenerationStatusType
    let message: String?
    let startedAt: Timestamp?
    let completedAt: Timestamp?
    let failedAt: Timestamp?
    let updatedAt: Timestamp
    
    /// 生成状態の種類
    enum GenerationStatusType: String, Codable, CaseIterable {
        case notStarted = "not_started"
        case generating = "generating"
        case completed = "completed"
        case failed = "failed"
    }
    
    /// デフォルトの初期状態
    static let notStarted = CharacterGenerationStatus(
        stage: 0,
        status: .notStarted,
        message: nil,
        startedAt: nil,
        completedAt: nil,
        failedAt: nil,
        updatedAt: Timestamp()
    )
    
    /// Firestoreドキュメントから生成状態を作成
    init(from document: DocumentSnapshot) {
        let data = document.data() ?? [:]
        
        self.stage = data["stage"] as? Int ?? 0
        self.status = GenerationStatusType(rawValue: data["status"] as? String ?? "not_started") ?? .notStarted
        self.message = data["message"] as? String
        self.startedAt = data["startedAt"] as? Timestamp
        self.completedAt = data["completedAt"] as? Timestamp
        self.failedAt = data["failedAt"] as? Timestamp
        self.updatedAt = data["updatedAt"] as? Timestamp ?? Timestamp()
    }
    
    /// 基本的な初期化
    init(stage: Int, status: GenerationStatusType, message: String? = nil, startedAt: Timestamp? = nil, completedAt: Timestamp? = nil, failedAt: Timestamp? = nil, updatedAt: Timestamp) {
        self.stage = stage
        self.status = status
        self.message = message
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.failedAt = failedAt
        self.updatedAt = updatedAt
    }
}

/// 生成状態の便利プロパティ
extension CharacterGenerationStatus {
    /// 現在生成中かどうか
    var isGenerating: Bool {
        return status == .generating
    }
    
    /// 生成完了かどうか
    var isCompleted: Bool {
        return status == .completed
    }
    
    /// 生成失敗かどうか
    var isFailed: Bool {
        return status == .failed
    }
    
    /// 表示用メッセージ
    var displayMessage: String {
        switch status {
        case .notStarted:
            return ""
        case .generating:
            return message ?? "性格を生成しています..."
        case .completed:
            // 段階ごとに異なるメッセージ
            switch stage {
            case 1:
                return "基本分析が完了しました！\n20問の診断お疲れさまでした。\n基本的な性格データが生成されました。"
            case 2:
                return "詳細分析が完了しました！\n50問の診断お疲れさまでした。\nより詳しい性格データが生成されました。"
            case 3:
                return "総合分析が完了しました！\n100問の診断お疲れさまでした。\nあなたの性格データが完成しました。"
            default:
                return "性格データの生成が完了しました！"
            }
        case .failed:
            return message ?? "生成に失敗しました"
        }
    }

    /// 完了時のタイトル
    var completionTitle: String {
        switch stage {
        case 1:
            return "基本分析完了！"
        case 2:
            return "詳細分析完了！"
        case 3:
            return "総合分析完了！"
        default:
            return "生成完了！"
        }
    }
    
    /// ポップアップを表示すべきかどうか
    var shouldShowPopup: Bool {
        return status == .generating || status == .completed
    }
}