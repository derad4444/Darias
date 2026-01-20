import SwiftUI
import Foundation

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
}

class TagSettingsManager: ObservableObject {
    static let shared = TagSettingsManager()
    
    @Published var tags: [Tag] = []
    
    private let userDefaults = UserDefaults.standard
    private let tagsKey = "savedTags"
    
    private init() {
        loadTags()
        // タグの初期設定は無し（空の状態でスタート）
    }
    
    func addTag(name: String, color: Color) {
        let newTag = Tag(name: name, color: color)
        tags.append(newTag)
        saveTags()
    }
    
    func updateTag(id: String, name: String, color: Color) {
        if let index = tags.firstIndex(where: { $0.id == id }) {
            tags[index].name = name
            tags[index].color = color
            saveTags()
        }
    }
    
    func deleteTag(id: String) {
        tags.removeAll { $0.id == id }
        saveTags()
    }
    
    func getTag(by name: String) -> Tag? {
        return tags.first { $0.name == name }
    }
    
    private func saveTags() {
        if let encoded = try? JSONEncoder().encode(tags) {
            userDefaults.set(encoded, forKey: tagsKey)
        }
    }
    
    private func loadTags() {
        if let data = userDefaults.data(forKey: tagsKey),
           let decodedTags = try? JSONDecoder().decode([Tag].self, from: data) {
            tags = decodedTags
        }
    }
}