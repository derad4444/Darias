import Foundation
import FirebaseFirestore

struct Memo: Identifiable, Equatable {
    let id: String
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var tag: String
    var isPinned: Bool

    // Firestore保存用
    func toDictionary() -> [String: Any] {
        return [
            "title": title,
            "content": content,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "tag": tag,
            "isPinned": isPinned
        ]
    }

    // Firestoreから読み込み用
    init(id: String, title: String, content: String, createdAt: Date, updatedAt: Date, tag: String, isPinned: Bool) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tag = tag
        self.isPinned = isPinned
    }

    // 新規作成用
    init(title: String, content: String, tag: String = "", isPinned: Bool = false) {
        self.id = UUID().uuidString
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tag = tag
        self.isPinned = isPinned
    }
}
