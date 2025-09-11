import Foundation

class Big5AnalysisCache {
    static let shared = Big5AnalysisCache()
    
    private init() {}
    
    // LRU (Least Recently Used) キャッシュ
    private var cache: [String: CacheItem] = [:]
    private var accessOrder: [String] = []
    private let maxCacheSize = 10
    
    private struct CacheItem {
        let data: Big5AnalysisData
        let timestamp: Date
        
        init(data: Big5AnalysisData) {
            self.data = data
            self.timestamp = Date()
        }
    }
    
    // MARK: - Cache Operations
    
    func getCachedAnalysis(personalityKey: String) -> Big5AnalysisData? {
        guard let cacheItem = cache[personalityKey] else {
            return nil
        }
        
        // アクセス順序を更新
        updateAccessOrder(for: personalityKey)
        
        // キャッシュの有効期限をチェック（1時間）
        if Date().timeIntervalSince(cacheItem.timestamp) > 3600 {
            removeCachedAnalysis(personalityKey: personalityKey)
            return nil
        }
        
        return cacheItem.data
    }
    
    func cacheAnalysis(key personalityKey: String, data: Big5AnalysisData) {
        let cacheItem = CacheItem(data: data)
        cache[personalityKey] = cacheItem
        
        // アクセス順序を更新
        updateAccessOrder(for: personalityKey)
        
        // キャッシュサイズ制限をチェック
        enforceMaxCacheSize()
    }
    
    func removeCachedAnalysis(personalityKey: String) {
        cache.removeValue(forKey: personalityKey)
        accessOrder.removeAll { $0 == personalityKey }
    }
    
    func clearAllCache() {
        cache.removeAll()
        accessOrder.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func updateAccessOrder(for personalityKey: String) {
        // 既存のエントリを削除
        accessOrder.removeAll { $0 == personalityKey }
        // 最新アクセスとして末尾に追加
        accessOrder.append(personalityKey)
    }
    
    private func enforceMaxCacheSize() {
        while cache.count > maxCacheSize && !accessOrder.isEmpty {
            // 最も古いアクセスのアイテムを削除
            let oldestKey = accessOrder.removeFirst()
            cache.removeValue(forKey: oldestKey)
        }
    }
    
    // MARK: - Cache Statistics
    
    var cacheSize: Int {
        return cache.count
    }
    
    var cachedKeys: [String] {
        return Array(cache.keys)
    }
    
    func getCacheInfo() -> String {
        let size = cache.count
        let keys = cache.keys.joined(separator: ", ")
        return "Cache size: \(size)/\(maxCacheSize)\nCached keys: \(keys)"
    }
    
    // MARK: - Preemptive Caching
    
    func preloadAnalysisData(for personalityKeys: [String], service: Big5AnalysisService) {
        for key in personalityKeys {
            if cache[key] == nil {
                service.fetchAnalysisData(personalityKey: key) { [weak self] result in
                    switch result {
                    case .success(let data):
                        self?.cacheAnalysis(key: key, data: data)
                    case .failure:
                        break
                    }
                }
            }
        }
    }
}