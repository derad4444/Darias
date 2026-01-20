import Foundation
import UIKit
import FirebaseStorage

/// Firebase Storageからキャラクター画像を取得・管理するサービス
class FirebaseImageService {
    static let shared = FirebaseImageService()

    private let storage = Storage.storage()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    // キャッシュ設定
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB
    private let cacheExpirationDays = 30

    // ダウンロード中の画像を追跡
    private var downloadTasks: [String: Task<UIImage, Error>] = [:]
    private let taskQueue = DispatchQueue(label: "com.character.firebase-image-service")

    private init() {
        // キャッシュディレクトリのセットアップ
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesDirectory.appendingPathComponent("CharacterImages")

        // ディレクトリが存在しない場合は作成
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }

        // 起動時に期限切れキャッシュをクリーン
        cleanExpiredCache()
    }

    // MARK: - Public Methods

    /// 画像を取得（キャッシュ優先）
    /// - Parameters:
    ///   - fileName: 画像ファイル名（例: "Female_HLMHL"）
    ///   - gender: 性別
    /// - Returns: UIImage
    func fetchImage(fileName: String, gender: CharacterGender) async throws -> UIImage {
        let cacheKey = "\(gender.rawValue)_\(fileName)"

        // 1. キャッシュチェック
        if let cachedImage = loadFromCache(cacheKey: cacheKey) {
            Logger.debug("🖼️ キャッシュから画像取得: \(fileName)", category: Logger.imageService)
            return cachedImage
        }

        // 2. 既にダウンロード中かチェック
        if let existingTask = taskQueue.sync(execute: { downloadTasks[cacheKey] }) {
            Logger.debug("⏳ ダウンロード中の画像を待機: \(fileName)", category: Logger.imageService)
            return try await existingTask.value
        }

        // 3. 新規ダウンロードタスクを作成
        let task = Task<UIImage, Error> {
            defer {
                taskQueue.sync {
                    downloadTasks.removeValue(forKey: cacheKey)
                }
            }

            let image = try await downloadImage(fileName: fileName, gender: gender)

            // キャッシュに保存
            saveToCache(image: image, cacheKey: cacheKey)

            return image
        }

        taskQueue.sync {
            downloadTasks[cacheKey] = task
        }

        return try await task.value
    }

    /// 画像をプリロード（バックグラウンドダウンロード）
    /// - Parameters:
    ///   - fileName: 画像ファイル名
    ///   - gender: 性別
    func preloadImage(fileName: String, gender: CharacterGender) async {
        let cacheKey = "\(gender.rawValue)_\(fileName)"

        // 既にキャッシュにある場合はスキップ
        if cacheExists(cacheKey: cacheKey) {
            return
        }

        do {
            _ = try await fetchImage(fileName: fileName, gender: gender)
            Logger.debug("✅ プリロード完了: \(fileName)", category: Logger.imageService)
        } catch {
            Logger.debug("❌ プリロード失敗: \(fileName) - \(error.localizedDescription)", category: Logger.imageService)
        }
    }

    /// キャッシュをクリア
    func clearCache() throws {
        let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        for file in files {
            try fileManager.removeItem(at: file)
        }
        Logger.debug("🗑️ キャッシュをクリアしました", category: Logger.imageService)
    }

    /// キャッシュサイズを取得（バイト）
    func getCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        return files.reduce(0) { total, fileURL in
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                return total
            }
            return total + Int64(fileSize)
        }
    }

    /// キャッシュサイズを人間が読める形式で取得
    func getCacheSizeFormatted() -> String {
        let bytes = getCacheSize()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: - Private Methods

    /// Firebase Storageから画像をダウンロード
    private func downloadImage(fileName: String, gender: CharacterGender) async throws -> UIImage {
        let storagePath = "character-images/\(gender.rawValue)/\(fileName).png"
        let storageRef = storage.reference().child(storagePath)

        Logger.debug("⬇️ Firebase Storageからダウンロード開始: \(storagePath)", category: Logger.imageService)

        // 最大サイズ: 10MB
        let maxSize: Int64 = 10 * 1024 * 1024

        do {
            let data = try await storageRef.data(maxSize: maxSize)

            guard let image = UIImage(data: data) else {
                throw FirebaseImageError.invalidImageData
            }

            Logger.debug("✅ ダウンロード完了: \(storagePath)", category: Logger.imageService)
            return image
        } catch {
            Logger.debug("❌ ダウンロード失敗: \(storagePath) - \(error.localizedDescription)", category: Logger.imageService)
            throw FirebaseImageError.downloadFailed(error)
        }
    }

    /// キャッシュから画像を読み込み
    private func loadFromCache(cacheKey: String) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).png")

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        // ファイルの更新日時をチェック
        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let modificationDate = attributes[.modificationDate] as? Date {
            let daysSinceModification = Calendar.current.dateComponents([.day], from: modificationDate, to: Date()).day ?? 0

            if daysSinceModification > cacheExpirationDays {
                // 期限切れのキャッシュは削除
                try? fileManager.removeItem(at: fileURL)
                return nil
            }
        }

        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    /// 画像をキャッシュに保存
    private func saveToCache(image: UIImage, cacheKey: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).png")

        guard let data = image.pngData() else {
            Logger.debug("❌ 画像データの変換に失敗: \(cacheKey)", category: Logger.imageService)
            return
        }

        do {
            try data.write(to: fileURL)
            Logger.debug("💾 キャッシュに保存: \(cacheKey)", category: Logger.imageService)

            // キャッシュサイズをチェックして必要に応じてクリーン
            checkCacheSizeAndClean()
        } catch {
            Logger.debug("❌ キャッシュ保存失敗: \(cacheKey) - \(error.localizedDescription)", category: Logger.imageService)
        }
    }

    /// キャッシュが存在するかチェック
    private func cacheExists(cacheKey: String) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).png")
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// 期限切れキャッシュをクリーン
    private func cleanExpiredCache() {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }

        let expirationDate = Calendar.current.date(byAdding: .day, value: -cacheExpirationDays, to: Date())!

        for fileURL in files {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
               let modificationDate = resourceValues.contentModificationDate,
               modificationDate < expirationDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    /// キャッシュサイズをチェックして制限を超えていたら古いファイルを削除
    private func checkCacheSizeAndClean() {
        let currentSize = getCacheSize()

        guard currentSize > maxCacheSize else {
            return
        }

        Logger.debug("⚠️ キャッシュサイズが制限を超えています: \(ByteCountFormatter.string(fromByteCount: currentSize, countStyle: .file))", category: Logger.imageService)

        // 古いファイルから削除
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }

        let sortedFiles = files.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return date1 < date2
        }

        var currentSizeAfterClean = currentSize
        for fileURL in sortedFiles {
            if currentSizeAfterClean <= maxCacheSize {
                break
            }

            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                try? fileManager.removeItem(at: fileURL)
                currentSizeAfterClean -= Int64(fileSize)
            }
        }

        Logger.debug("🗑️ キャッシュクリーン完了: \(ByteCountFormatter.string(fromByteCount: currentSizeAfterClean, countStyle: .file))", category: Logger.imageService)
    }
}

// MARK: - Error Types

enum FirebaseImageError: LocalizedError {
    case invalidImageData
    case downloadFailed(Error)
    case cacheError

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "画像データが無効です"
        case .downloadFailed(let error):
            return "ダウンロードに失敗しました: \(error.localizedDescription)"
        case .cacheError:
            return "キャッシュエラーが発生しました"
        }
    }
}
