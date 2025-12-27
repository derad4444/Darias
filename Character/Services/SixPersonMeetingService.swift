// Character/Services/SixPersonMeetingService.swift

import Foundation
import Firebase
import FirebaseFunctions
import FirebaseFirestore

@MainActor
class SixPersonMeetingService: ObservableObject {
    static let shared = SixPersonMeetingService()

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let functions = Functions.functions(region: "asia-northeast1")
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - 会議を生成または取得

    /// 6人会議を生成または既存データを取得
    /// - Parameters:
    ///   - userId: ユーザーID
    ///   - characterId: キャラクターID
    ///   - concern: 悩み内容
    ///   - category: カテゴリ（省略可）
    /// - Returns: 会議データ
    func generateOrReuseMeeting(
        userId: String,
        characterId: String,
        concern: String,
        category: String? = nil
    ) async throws -> GenerateMeetingResponse {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let callable = functions.httpsCallable("generateOrReuseMeeting")

            let params: [String: Any] = [
                "userId": userId,
                "characterId": characterId,
                "concern": concern,
                "concernCategory": category ?? ""
            ]

            Logger.debug("Calling generateOrReuseMeeting", category: Logger.network)

            let result = try await callable.call(params)

            guard let data = result.data as? [String: Any] else {
                throw MeetingError.invalidResponse
            }

            // レスポンスをパース
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let response = try JSONDecoder().decode(GenerateMeetingResponse.self, from: jsonData)

            Logger.info("Meeting generated: \(response.meetingId), cacheHit: \(response.cacheHit), duration: \(response.duration)ms", category: Logger.network)

            return response

        } catch let error as NSError {
            Logger.error("Failed to generate meeting", category: Logger.network, error: error)

            // デバッグ: エラーの詳細情報をログ出力
            Logger.debug("Error domain: \(error.domain)", category: Logger.network)
            Logger.debug("Error code: \(error.code)", category: Logger.network)
            Logger.debug("Error userInfo: \(error.userInfo)", category: Logger.network)

            // エラーメッセージを取得（複数のパターンを試す）
            var message: String? = nil

            // Firebase Functions のエラーメッセージを取得
            // まずlocalizedDescriptionを試す（HttpsErrorのメッセージはここに含まれる）
            message = error.localizedDescription
            Logger.debug("localizedDescription: \(error.localizedDescription)", category: Logger.network)

            // 空の場合は他のキーを試す
            if message?.isEmpty != false {
                // パターン1: NSLocalizedDescriptionKey
                if let errorMessage = error.userInfo[NSLocalizedDescriptionKey] as? String, !errorMessage.isEmpty {
                    message = errorMessage
                    Logger.debug("Found message in NSLocalizedDescriptionKey: \(errorMessage)", category: Logger.network)
                }
                // パターン2: "message" キー
                else if let errorMessage = error.userInfo["message"] as? String, !errorMessage.isEmpty {
                    message = errorMessage
                    Logger.debug("Found message in 'message' key: \(errorMessage)", category: Logger.network)
                }
                // パターン3: NSLocalizedFailureReasonErrorKey
                else if let errorMessage = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String, !errorMessage.isEmpty {
                    message = errorMessage
                    Logger.debug("Found message in NSLocalizedFailureReasonErrorKey: \(errorMessage)", category: Logger.network)
                }
            }

            // プレミアム制限のエラーをチェック
            if let msg = message, msg.contains("無料ユーザーは1回のみ") || msg.contains("プレミアムにアップグレード") || msg.contains("プレミアムに") {
                Logger.info("Premium required error detected", category: Logger.network)
                errorMessage = "無料プランでは自分会議は1回のみ利用可能です。プレミアムにアップグレードしてください。"
                throw MeetingError.premiumRequired
            }

            errorMessage = message ?? "会議の生成に失敗しました"
            Logger.error("Final error message: \(errorMessage ?? "nil")", category: Logger.network)
            throw MeetingError.networkError(message ?? "不明なエラー")
        }
    }

    // MARK: - 会議履歴の取得

    /// ユーザーの会議履歴を取得
    /// - Parameters:
    ///   - userId: ユーザーID
    ///   - characterId: キャラクターID
    ///   - limit: 取得件数
    /// - Returns: 会議履歴の配列
    func fetchMeetingHistory(
        userId: String,
        characterId: String,
        limit: Int = 20
    ) async throws -> [MeetingHistory] {
        print("🔧 SixPersonMeetingService: fetchMeetingHistory called")
        print("   userId: \(userId)")
        print("   characterId: \(characterId)")
        print("   limit: \(limit)")

        do {
            print("🔧 [1/5] Starting fetchMeetingHistory...")

            // getMeetingUsageCountと同じパターンを使用
            print("🔧 [2/5] Building query...")
            let query = db
                .collection("users").document(userId)
                .collection("characters").document(characterId)
                .collection("meeting_history")
                .limit(to: limit)
            print("✅ [2/5] Query built")

            print("🔧 [3/5] Executing getDocuments()...")
            let snapshot = try await query.getDocuments()
            print("✅ [3/5] Got snapshot with \(snapshot.documents.count) documents")

            print("🔧 [4/5] Decoding documents...")
            var histories = try snapshot.documents.compactMap { doc -> MeetingHistory? in
                var history = try doc.data(as: MeetingHistory.self)
                history.id = doc.documentID
                return history
            }
            print("✅ [4/5] Decoded \(histories.count) histories")

            // クライアント側でソート
            print("🔧 [5/5] Sorting on client side...")
            histories.sort { $0.createdAt > $1.createdAt }
            print("✅ [5/5] Sorted \(histories.count) histories")

            Logger.debug("Fetched \(histories.count) meeting histories", category: Logger.firestore)

            return histories

        } catch {
            print("❌ fetchMeetingHistory error: \(error)")
            Logger.error("Failed to fetch meeting history", category: Logger.firestore, error: error)
            throw MeetingError.firestoreError(error.localizedDescription)
        }
    }

    /// 特定の会議データを取得
    /// - Parameter meetingId: shared_meetingsのドキュメントID
    /// - Returns: 会議データ
    func fetchMeetingById(meetingId: String) async throws -> SixPersonMeeting {
        do {
            let doc = try await db
                .collection("shared_meetings")
                .document(meetingId)
                .getDocument()

            guard doc.exists else {
                Logger.error("Meeting document does not exist: \(meetingId)", category: Logger.firestore)
                throw MeetingError.meetingNotFound
            }

            // デバッグ: 実際のデータ構造をログ出力
            if let data = doc.data() {
                Logger.debug("Firestore data keys: \(data.keys.sorted())", category: Logger.firestore)
                Logger.debug("Full data: \(data)", category: Logger.firestore)
            }

            // Firestoreのデータを直接デコード（Timestamp型などに対応）
            var meeting = try doc.data(as: SixPersonMeeting.self)
            meeting.id = doc.documentID

            Logger.debug("Successfully fetched meeting: \(meetingId)", category: Logger.firestore)

            return meeting

        } catch let decodingError as DecodingError {
            Logger.error("Failed to decode meeting data", category: Logger.firestore, error: decodingError)

            // デコードエラーの詳細をログ出力
            switch decodingError {
            case .keyNotFound(let key, let context):
                Logger.error("Key '\(key.stringValue)' not found: \(context.debugDescription)", category: Logger.firestore)
            case .typeMismatch(let type, let context):
                Logger.error("Type mismatch for type \(type): \(context.debugDescription)", category: Logger.firestore)
            case .valueNotFound(let type, let context):
                Logger.error("Value not found for type \(type): \(context.debugDescription)", category: Logger.firestore)
            case .dataCorrupted(let context):
                Logger.error("Data corrupted: \(context.debugDescription)", category: Logger.firestore)
            @unknown default:
                Logger.error("Unknown decoding error", category: Logger.firestore)
            }

            throw MeetingError.firestoreError(decodingError.localizedDescription)
        } catch {
            Logger.error("Failed to fetch meeting", category: Logger.firestore, error: error)
            throw MeetingError.firestoreError(error.localizedDescription)
        }
    }

    // MARK: - 会議の評価

    /// 会議に評価をつける
    /// - Parameters:
    ///   - meetingId: shared_meetingsのドキュメントID
    ///   - rating: 評価（1-5）
    func rateMeeting(meetingId: String, rating: Int) async throws {
        guard rating >= 1 && rating <= 5 else {
            throw MeetingError.invalidRating
        }

        do {
            let meetingRef = db.collection("shared_meetings").document(meetingId)

            try await db.runTransaction { transaction, errorPointer in
                let document: DocumentSnapshot
                do {
                    document = try transaction.getDocument(meetingRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                guard var data = document.data(),
                      var ratings = data["ratings"] as? [String: Any] else {
                    let error = NSError(
                        domain: "MeetingService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid meeting data"]
                    )
                    errorPointer?.pointee = error
                    return nil
                }

                let totalRatings = (ratings["totalRatings"] as? Int ?? 0) + 1
                let ratingSum = (ratings["ratingSum"] as? Int ?? 0) + rating
                let avgRating = Double(ratingSum) / Double(totalRatings)

                ratings["totalRatings"] = totalRatings
                ratings["ratingSum"] = ratingSum
                ratings["avgRating"] = avgRating

                transaction.updateData(["ratings": ratings], forDocument: meetingRef)

                return nil
            }

            Logger.info("Meeting rated successfully: \(meetingId), rating: \(rating)", category: Logger.firestore)

        } catch {
            Logger.error("Failed to rate meeting", category: Logger.firestore, error: error)
            throw MeetingError.firestoreError(error.localizedDescription)
        }
    }

    // MARK: - 利用統計

    /// ユーザーの会議利用回数を取得
    /// - Parameters:
    ///   - userId: ユーザーID
    ///   - characterId: キャラクターID
    /// - Returns: 利用回数
    func getMeetingUsageCount(userId: String, characterId: String) async throws -> Int {
        do {
            let count = try await db
                .collection("users").document(userId)
                .collection("characters").document(characterId)
                .collection("meeting_history")
                .count
                .getAggregation(source: .server)

            return Int(count.count)

        } catch {
            Logger.error("Failed to get usage count", category: Logger.firestore, error: error)
            return 0
        }
    }
}

// MARK: - エラー定義

enum MeetingError: LocalizedError {
    case invalidResponse
    case networkError(String)
    case firestoreError(String)
    case meetingNotFound
    case invalidRating
    case premiumRequired
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "サーバーからの応答が不正です"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .firestoreError(let message):
            return "データベースエラー: \(message)"
        case .meetingNotFound:
            return "会議データが見つかりません"
        case .invalidRating:
            return "評価は1〜5の範囲で指定してください"
        case .premiumRequired:
            return "この機能を使用するにはプレミアムプランが必要です"
        case .timeout:
            return "読み込みがタイムアウトしました。もう一度お試しください"
        }
    }
}
