import Foundation
import Network
import SwiftUI

class CharacterPreloadService: ObservableObject {
    static let shared = CharacterPreloadService()
    
    @Published var isConnectedToWiFi: Bool = false
    @Published var preloadProgress: Double = 0.0
    @Published var isPreloading: Bool = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "CharacterPreloadService")
    private var availableCharacters: [CharacterConfig] = []
    
    private init() {
        startNetworkMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnectedToWiFi = path.usesInterfaceType(.wifi)
                
                // WiFi接続時に自動プリロード
                if path.usesInterfaceType(.wifi) && !path.usesInterfaceType(.cellular) {
                    self?.startAutoPreload()
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func addCharacterForPreload(_ config: CharacterConfig) {
        guard !config.isDefault else { return } // デフォルトキャラクターはローカル画像なのでスキップ
        
        if !availableCharacters.contains(where: { $0.id == config.id }) {
            availableCharacters.append(config)
        }
        
        // WiFi環境なら即座に開始
        if isConnectedToWiFi {
            preloadCharacter(config)
        }
    }
    
    func startAutoPreload() {
        guard isConnectedToWiFi && !isPreloading else { return }
        
        isPreloading = true
        preloadProgress = 0.0
        
        Task {
            let totalCharacters = availableCharacters.count
            var completedCharacters = 0
            
            for character in availableCharacters {
                await preloadCharacterImages(character)
                completedCharacters += 1
                
                await MainActor.run {
                    self.preloadProgress = Double(completedCharacters) / Double(totalCharacters)
                }
            }
            
            await MainActor.run {
                self.isPreloading = false
                self.preloadProgress = 1.0
            }
        }
    }
    
    func preloadCharacter(_ config: CharacterConfig) {
        guard !config.isDefault else { return }
        
        Task {
            await preloadCharacterImages(config)
        }
    }
    
    private func preloadCharacterImages(_ config: CharacterConfig) async {
        guard case .remote(let baseURL) = config.imageSource else { return }
        
        for expression in CharacterExpression.allCases {
            let fileName = "\(config.id)\(expression.rawValue).png"
            let imageURL = baseURL.appendingPathComponent(fileName)
            
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                if let _ = UIImage(data: data) {
                    // 成功時はキャッシュに保存（実際のViewModelに通知）
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .characterImagePreloaded,
                            object: nil,
                            userInfo: [
                                "characterId": config.id,
                                "expression": expression.rawValue,
                                "imageData": data
                            ]
                        )
                    }
                }
            } catch {
                print("Failed to preload image for \(config.id) \(expression.rawValue): \(error)")
            }
        }
    }
    
    func shouldPreloadNow() -> Bool {
        return isConnectedToWiFi || UIApplication.shared.applicationState == .background
    }
    
    func getPreloadStatus(for characterId: String) -> PreloadStatus {
        // 実装は必要に応じて追加
        return .notStarted
    }
}

enum PreloadStatus {
    case notStarted
    case inProgress
    case completed
    case failed
}

extension Notification.Name {
    static let characterImagePreloaded = Notification.Name("characterImagePreloaded")
}