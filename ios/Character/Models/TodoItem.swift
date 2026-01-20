import Foundation
import FirebaseFirestore

struct TodoItem: Identifiable, Equatable {
    let id: String
    var title: String
    var description: String
    var isCompleted: Bool
    var dueDate: Date?
    var priority: TodoPriority
    var tag: String
    var createdAt: Date
    var updatedAt: Date

    enum TodoPriority: String, CaseIterable, Codable {
        case low = "低"
        case medium = "中"
        case high = "高"

        var displayName: String {
            return self.rawValue
        }

        var color: String {
            switch self {
            case .low:
                return "gray"
            case .medium:
                return "blue"
            case .high:
                return "red"
            }
        }
    }

    // 期限切れかどうか
    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else {
            return false
        }
        return dueDate < Date()
    }

    // Firestore保存用
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "title": title,
            "description": description,
            "isCompleted": isCompleted,
            "priority": priority.rawValue,
            "tag": tag,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]

        if let dueDate = dueDate {
            dict["dueDate"] = Timestamp(date: dueDate)
        }

        return dict
    }

    // Firestoreから読み込み用
    init(id: String, title: String, description: String, isCompleted: Bool, dueDate: Date?, priority: TodoPriority, tag: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.priority = priority
        self.tag = tag
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // 新規作成用
    init(title: String, description: String = "", dueDate: Date? = nil, priority: TodoPriority = .medium, tag: String = "") {
        self.id = UUID().uuidString
        self.title = title
        self.description = description
        self.isCompleted = false
        self.dueDate = dueDate
        self.priority = priority
        self.tag = tag
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
