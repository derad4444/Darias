import Foundation

struct PersonalityKeyGenerator {
    static func generateAllKeys() -> [String] {
        var keys: [String] = []
        
        // O1 から O5 まで順番に生成
        for o in 1...5 {
            for c in 1...5 {
                for e in 1...5 {
                    for a in 1...5 {
                        for n in 1...5 {
                            let key = "O\(o)_C\(c)_E\(e)_A\(a)_N\(n)_female"
                            keys.append(key)
                        }
                    }
                }
            }
        }
        
        return keys
    }
    
    // 開放性別にバッチ分け（管理しやすくするため）
    static func getKeysByOpenness(_ openness: Int) -> [String] {
        var keys: [String] = []
        
        for c in 1...5 {
            for e in 1...5 {
                for a in 1...5 {
                    for n in 1...5 {
                        let key = "O\(openness)_C\(c)_E\(e)_A\(a)_N\(n)_female"
                        keys.append(key)
                    }
                }
            }
        }
        
        return keys
    }
    
    // 進捗確認用
    static func printProgress() {
        print("=== PersonalityKey生成進捗 ===")
        for o in 1...5 {
            let count = getKeysByOpenness(o).count
            print("開放性\(o): \(count)個のパターン")
        }
        print("総計: \(generateAllKeys().count)個")
    }
    
    // スコア解析用ヘルパー
    static func parsePersonalityKey(_ key: String) -> (o: Int, c: Int, e: Int, a: Int, n: Int)? {
        let components = key.components(separatedBy: "_")
        guard components.count == 6,
              let o = Int(components[0].dropFirst()),
              let c = Int(components[1].dropFirst()),
              let e = Int(components[2].dropFirst()),
              let a = Int(components[3].dropFirst()),
              let n = Int(components[4].dropFirst()) else {
            return nil
        }
        return (o: o, c: c, e: e, a: a, n: n)
    }
}