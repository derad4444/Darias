import SwiftUI
import Foundation
import FirebaseFirestore
import FirebaseAuth

struct Tag: Identifiable, Codable {
    let id: String
    var name: String
    var color: Color

    init(id: String = UUID().uuidString, name: String, color: Color) {
        self.id = id
        self.name = name
        self.color = color
    }

    // Codable対応
    enum CodingKeys: String, CodingKey {
        case id, name, colorHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let colorHex = try container.decode(String.self, forKey: .colorHex)
        color = Color(hex: colorHex)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color.toHex(), forKey: .colorHex)
    }

    /// Firestoreドキュメントから生成
    init(document: DocumentSnapshot) {
        let data = document.data() ?? [:]
        self.id = document.documentID
        self.name = data["name"] as? String ?? ""
        let colorHex = data["colorHex"] as? String ?? "#2196f3"
        self.color = Color(hex: colorHex)
    }

    /// Firestoreに保存する辞書
    func toFirestoreData() -> [String: Any] {
        return [
            "name": name,
            "colorHex": color.toHex()
        ]
    }
}

class TagSettingsManager: ObservableObject {
    static let shared = TagSettingsManager()

    @Published var tags: [Tag] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    private var tagsCollection: CollectionReference? {
        guard let userId = userId else { return nil }
        return db.collection("users").document(userId).collection("tags")
    }

    private init() {
        startListening()

        // 認証状態の変化を監視
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if user != nil {
                self?.startListening()
            } else {
                self?.stopListening()
                self?.tags = []
            }
        }
    }

    func startListening() {
        stopListening()
        guard let collection = tagsCollection else { return }

        listener = collection.order(by: "name").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let snapshot = snapshot else { return }
            DispatchQueue.main.async {
                self.tags = snapshot.documents.map { Tag(document: $0) }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func addTag(name: String, color: Color) {
        guard let collection = tagsCollection else { return }
        let tag = Tag(name: name, color: color)
        collection.addDocument(data: tag.toFirestoreData())
    }

    func updateTag(id: String, name: String, color: Color) {
        guard let collection = tagsCollection else { return }
        collection.document(id).updateData([
            "name": name,
            "colorHex": color.toHex()
        ])
    }

    func deleteTag(id: String) {
        guard let collection = tagsCollection else { return }
        collection.document(id).delete()
    }

    func getTag(by name: String) -> Tag? {
        return tags.first { $0.name == name }
    }
}
