import Foundation
import FirebaseFirestore
import FirebaseFunctions

class Big5AnalysisService: ObservableObject {
    private let db = Firestore.firestore()
    private let cache = Big5AnalysisCache.shared
    
    @Published var currentAnalysisData: Big5AnalysisData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - PersonalityKey Generation
    
    func generatePersonalityKey(scores: Big5Scores, gender: String) -> String {
        let o = roundToFiveScale(scores.openness)
        let c = roundToFiveScale(scores.conscientiousness)
        let e = roundToFiveScale(scores.extraversion)
        let a = roundToFiveScale(scores.agreeableness)
        let n = roundToFiveScale(scores.neuroticism)
        
        return "O\(o)_C\(c)_E\(e)_A\(a)_N\(n)_\(gender)"
    }
    
    private func roundToFiveScale(_ score: Double) -> Int {
        return max(1, min(5, Int(round(score))))
    }
    
    // MARK: - Analysis Data Fetching
    
    func fetchAnalysisData(personalityKey: String, completion: @escaping (Result<Big5AnalysisData, Error>) -> Void) {
        // キャッシュから取得を試行
        if let cachedData = cache.getCachedAnalysis(personalityKey: personalityKey) {
            DispatchQueue.main.async {
                self.currentAnalysisData = cachedData
                completion(.success(cachedData))
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        db.collection("Big5Analysis").document(personalityKey).getDocument { [weak self] document, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
                return
            }
            
            if let document = document, document.exists, let data = document.data() {
                // データが存在する場合は既存の処理
                do {
                    let analysisData = try self?.parseAnalysisData(from: data, personalityKey: personalityKey)
                    if let analysisData = analysisData {
                        DispatchQueue.main.async {
                            self?.isLoading = false
                            self?.currentAnalysisData = analysisData
                            self?.cache.cacheAnalysis(key: personalityKey, data: analysisData)
                            completion(.success(analysisData))
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.errorMessage = "データの解析に失敗しました"
                        completion(.failure(error))
                    }
                }
            } else {
                // データが存在しない場合は動的生成
                self?.generateAnalysisData(personalityKey: personalityKey, completion: completion)
            }
        }
    }
    
    // MARK: - Data Parsing
    
    private func parseAnalysisData(from data: [String: Any], personalityKey: String) throws -> Big5AnalysisData {
        let lastUpdated = (data["last_updated"] as? Timestamp)?.dateValue() ?? Date()
        
        let analysis20 = parseAnalysisLevel(from: data, level: "analysis_20")
        let analysis50 = parseAnalysisLevel(from: data, level: "analysis_50")
        let analysis100 = parseAnalysisLevel(from: data, level: "analysis_100")
        
        return Big5AnalysisData(
            personalityKey: personalityKey,
            lastUpdated: lastUpdated,
            analysis20: analysis20,
            analysis50: analysis50,
            analysis100: analysis100
        )
    }
    
    private func parseAnalysisLevel(from data: [String: Any], level: String) -> [Big5AnalysisCategory: Big5DetailedAnalysis]? {
        guard let levelData = data[level] as? [String: Any] else { return nil }
        
        var result: [Big5AnalysisCategory: Big5DetailedAnalysis] = [:]
        let analysisLevel: Big5AnalysisLevel
        
        switch level {
        case "analysis_20":
            analysisLevel = .basic
        case "analysis_50":
            analysisLevel = .detailed
        case "analysis_100":
            analysisLevel = .complete
        default:
            return nil
        }
        
        for category in Big5AnalysisCategory.allCases {
            if let categoryData = levelData[category.rawValue] as? [String: Any],
               let personalityType = categoryData["personality_type"] as? String,
               let detailedText = categoryData["detailed_text"] as? String,
               let keyPoints = categoryData["key_points"] as? [String] {
                
                let analysis = Big5DetailedAnalysis(
                    category: category,
                    personalityType: personalityType,
                    detailedText: detailedText,
                    keyPoints: keyPoints,
                    analysisLevel: analysisLevel
                )
                
                result[category] = analysis
            }
        }
        
        return result.isEmpty ? nil : result
    }
    
    // MARK: - Character Analysis Data Fetching
    
    func fetchCharacterAnalysis(characterId: String, userId: String, completion: @escaping (Result<Big5AnalysisData, Error>) -> Void) {
        // ユーザーのキャラクター詳細からpersonalityKeyを取得
        db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("details").document("current").getDocument { [weak self] document, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let data = document?.data(),
                      let personalityKey = data["personalityKey"] as? String else {
                    let notFoundError = NSError(domain: "Big5AnalysisService", code: 404, userInfo: [NSLocalizedDescriptionKey: "キャラクターのpersonalityKeyが見つかりませんでした"])
                    DispatchQueue.main.async {
                        completion(.failure(notFoundError))
                    }
                    return
                }
                
                // personalityKeyで解析データを取得
                self?.fetchAnalysisData(personalityKey: personalityKey, completion: completion)
            }
    }
    
    // MARK: - Analysis Level Determination
    
    func determineAnalysisLevel(answeredCount: Int) -> Big5AnalysisLevel? {
        if answeredCount >= 100 {
            return .complete
        } else if answeredCount >= 50 {
            return .detailed
        } else if answeredCount >= 20 {
            return .basic
        } else {
            return nil
        }
    }
    
    // MARK: - Available Categories for Level
    
    func getAvailableCategories(for level: Big5AnalysisLevel) -> [Big5AnalysisCategory] {
        switch level {
        case .basic:
            // 基本解析では3つのカテゴリーのみ
            return [.career, .romance, .stress]
        case .detailed, .complete:
            // 詳細・完全解析では全5つのカテゴリー
            return Big5AnalysisCategory.allCases
        }
    }
    
    // MARK: - Dynamic Analysis Data Generation
    
    private func generateAnalysisData(personalityKey: String, completion: @escaping (Result<Big5AnalysisData, Error>) -> Void) {
        // Cloud Functionを呼び出してAIで解析データを生成
        let functions = Functions.functions(region: "asia-northeast1")
        
        functions.httpsCallable("generateBig5Analysis").call([
            "personalityKey": personalityKey
        ]) { [weak self] result, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "解析データの生成に失敗しました"
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = result?.data as? [String: Any] else {
                let parseError = NSError(domain: "Big5AnalysisService", code: 500, userInfo: [NSLocalizedDescriptionKey: "生成データの解析に失敗しました"])
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "生成データの解析に失敗しました"
                    completion(.failure(parseError))
                }
                return
            }
            
            do {
                // 生成されたデータを解析
                let analysisData = try self?.parseAnalysisData(from: data, personalityKey: personalityKey)
                if let analysisData = analysisData {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.currentAnalysisData = analysisData
                        // キャッシュに保存
                        self?.cache.cacheAnalysis(key: personalityKey, data: analysisData)
                        completion(.success(analysisData))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "生成されたデータの解析に失敗しました"
                    completion(.failure(error))
                }
            }
        }
    }
}