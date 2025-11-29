import FirebaseFirestore
import FirebaseAuth
import Foundation
import WidgetKit

class FirestoreManager: ObservableObject {
    //Firestoreへの接続インスタンス
    private let db = Firestore.firestore()
    //現在ログイン中のFirebaseユーザーのIDを取得（認証が前提）
    private var userId: String? {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            return nil
        }
        return uid
    }
    
    //Firestoreから取得した予定データ（一覧）を保存する
    @Published var schedules: [Schedule] = []
    //Firestoreから取得した日記データ（一覧）を保存する
    @Published var diaries: [Diary] = []
    //Firestoreから取得した祝日データ（一覧）を保存する
    @Published var holidays: [Holiday] = []
    //Firestoreから取得したメモデータ（一覧）を保存する
    @Published var memos: [Memo] = []
    //Firestoreから取得したTODOデータ（一覧）を保存する
    @Published var todos: [TodoItem] = []
    
    //Firestoreからスケジュール一覧を取得して schedules に反映
    func fetchSchedules() {
        guard let userId = userId else {
            Logger.debug("fetchSchedules: userId is nil", category: Logger.firestore)
            return
        }

        Logger.debug("fetchSchedules: userId = \(userId)", category: Logger.firestore)
        db.collection("users").document(userId).collection("schedules")
            .getDocuments { snapshot, error in
                if let error = error {
                    Logger.error("Schedule fetch failed", category: Logger.firestore, error: error)
                    return
                }
                
                if let documents = snapshot?.documents {
                    self.schedules = documents.compactMap { doc in
                        let data = doc.data()

                        guard let title = data["title"] as? String else {
                            return nil
                        }

                        // startDateとendDateを取得
                        let startTimestamp = data["startDate"] as? Timestamp
                        let endTimestamp = data["endDate"] as? Timestamp

                        guard let startDate = startTimestamp?.dateValue() else {
                            return nil
                        }

                        // endDateが必須
                        guard let endDate = endTimestamp?.dateValue() else {
                            return nil
                        }

                        // isAllDayがFirestoreに無いケースも考慮してデフォルトfalse
                        let isAllDay = data["isAllDay"] as? Bool ?? false

                        // 詳細情報も取得（存在しない場合はデフォルト値）
                        let location = data["location"] as? String ?? ""
                        let memo = data["memo"] as? String ?? ""
                        let tag = data["tag"] as? String ?? ""
                        let repeatOption = data["repeatOption"] as? String ?? ""
                        let remindValue = data["remindValue"] as? Int ?? 0
                        let remindUnit = data["remindUnit"] as? String ?? ""
                        let recurringGroupId = data["recurringGroupId"] as? String

                        // 通知設定を復元
                        var notificationSettings: NotificationSettings? = nil
                        if let notificationJSON = data["notificationSettings"] as? String {
                            do {
                                if let jsonData = notificationJSON.data(using: .utf8) {
                                    notificationSettings = try JSONDecoder().decode(NotificationSettings.self, from: jsonData)
                                }
                            } catch {
                            }
                        }

                        let schedule = Schedule(
                            id: doc.documentID,
                            title: title,
                            date: startDate, // 下位互換性のため
                            startDate: startDate,
                            endDate: endDate,
                            isAllDay: isAllDay,
                            tag: tag,
                            location: location,
                            memo: memo,
                            repeatOption: repeatOption,
                            remindValue: remindValue,
                            remindUnit: remindUnit,
                            recurringGroupId: recurringGroupId,
                            notificationSettings: notificationSettings
                        )


                        return schedule
                    }

                    // ウィジェット用にキャッシュ
                    WidgetDataService.shared.cacheSchedules(self.schedules)
                }
            }
    }
    
    //Firestoreから日記一覧を取得して diaries に反映
    func fetchDiaries(characterId: String) {
        guard let userId = userId else {
            Logger.debug("fetchDiaries: userId is nil", category: Logger.firestore)
            return
        }

        guard !characterId.isEmpty else {
            Logger.debug("fetchDiaries: characterId is empty", category: Logger.firestore)
            return
        }

        Logger.debug("fetchDiaries: userId = \(userId), characterId = \(characterId)", category: Logger.firestore)

        // キャラクター別のサブコレクションから取得
        db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("diary")
            .getDocuments { snapshot, error in
                if let error = error {
                    Logger.error("Diary fetch failed", category: Logger.firestore, error: error)
                    return
                }

                if let documents = snapshot?.documents {
                    self.diaries = documents.compactMap { doc in
                        let data = doc.data()
                        guard let timestamp = data["date"] as? Timestamp,
                              let title = data["title"] as? String else { return nil }
                        return Diary(id: doc.documentID, title: title, date: timestamp.dateValue())
                    }
                    Logger.debug("fetchDiaries: Found \(self.diaries.count) diaries", category: Logger.firestore)
                }
            }
    }
    
    // Firestoreから祝日一覧取得
    func fetchHolidays(completion: @escaping () -> Void = {}) {
        db.collection("holidays").getDocuments { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion()
                }
                return
            }
            
            if let documents = snapshot?.documents {
                self.holidays = documents.compactMap { doc in
                    let data = doc.data()
                    guard let name = data["name"] as? String,
                          let dateString = data["dateString"] as? String else { 
                        return nil 
                    }
                    return Holiday(id: doc.documentID, name: name, dateString: dateString)
                }
            }
            
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    //予定（ScheduleItem型）を Firestore に保存する
    func addSchedule(_ schedule: ScheduleItem, for userId: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        // ユーザーサブコレクションに保存
        let docRef = db.collection("users").document(userId).collection("schedules").document()
        
        // 共通データ変換メソッドを使用
        var data = createScheduleData(from: schedule)
        data["created_at"] = Timestamp()
        
        docRef.setData(data) { error in
            if let error = error {
                Logger.error("Schedule add failed", category: Logger.firestore, error: error)
                completion(false)
            } else {
                Logger.success("Schedule added successfully", category: Logger.firestore)
                // 最新データを取得してウィジェット更新
                self.fetchSchedules()
                // CalendarViewに予定追加を通知
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .init("ScheduleAdded"), object: nil)
                }
                completion(true)
            }
        }
    }
    
    // 予定の日付を更新する
    func updateScheduleDates(scheduleId: String, newStartDate: Date, completion: @escaping (Bool) -> Void) {
        guard let userId = userId else { 
            completion(false)
            return 
        }
        
        let docRef = db.collection("users").document(userId).collection("schedules").document(scheduleId)
        
        // 現在の予定データを取得して期間を計算
        docRef.getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  let originalStartTimestamp = data["startDate"] as? Timestamp,
                  let originalEndTimestamp = data["endDate"] as? Timestamp else {
                completion(false)
                return
            }
            
            let originalStart = originalStartTimestamp.dateValue()
            let originalEnd = originalEndTimestamp.dateValue()
            let duration = originalEnd.timeIntervalSince(originalStart)
            
            // 新しい終了日時を計算（期間を維持）
            let newEndDate = newStartDate.addingTimeInterval(duration)
            
            // 日付を更新
            let updateData: [String: Any] = [
                "startDate": Timestamp(date: newStartDate),
                "endDate": Timestamp(date: newEndDate)
            ]
            
            docRef.updateData(updateData) { error in
                if let error = error {
                    completion(false)
                } else {
                    // 最新データを取得してウィジェット更新
                    self.fetchSchedules()
                    // CalendarViewに予定更新を通知
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .init("ScheduleAdded"), object: nil)
                    }
                    completion(true)
                }
            }
        }
    }

    // 共通データ変換メソッド - ScheduleItemから保存用データを作成
    private func createScheduleData(from schedule: ScheduleItem) -> [String: Any] {
        var data: [String: Any] = [
            "title": schedule.title,
            "isAllDay": schedule.isAllDay,
            "startDate": Timestamp(date: schedule.startDate),
            "endDate": Timestamp(date: schedule.endDate),
            "location": schedule.location,
            "tag": schedule.tag,
            "memo": schedule.memo,
            "repeatOption": schedule.repeatOption
        ]

        // recurringGroupIdがある場合は追加
        if let recurringGroupId = schedule.recurringGroupId {
            data["recurringGroupId"] = recurringGroupId
        }

        // 通知設定がある場合は追加
        if let notificationSettings = schedule.notificationSettings {
            do {
                let jsonData = try JSONEncoder().encode(notificationSettings)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    data["notificationSettings"] = jsonString
                }
            } catch {
            }
        }

        return data
    }

    // 予定の全情報を更新する
    func updateSchedule(_ schedule: ScheduleItem, completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            completion(false)
            return
        }

        let docRef = db.collection("users").document(userId).collection("schedules").document(schedule.id)

        // 共通データ変換メソッドを使用
        var data = createScheduleData(from: schedule)
        data["updated_at"] = Timestamp()

        docRef.updateData(data) { error in
            if let error = error {
                completion(false)
            } else {
                // 最新データを取得してウィジェット更新
                self.fetchSchedules()
                // CalendarViewに予定更新を通知
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .init("ScheduleAdded"), object: nil)
                }
                completion(true)
            }
        }
    }

    // 予定を削除する
    func deleteSchedule(scheduleId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            completion(false)
            return
        }

        let docRef = db.collection("users").document(userId).collection("schedules").document(scheduleId)

        docRef.delete { error in
            if let error = error {
                completion(false)
            } else {
                // ローカルの予定リストからも削除
                DispatchQueue.main.async {
                    self.schedules.removeAll { $0.id == scheduleId }
                    // ウィジェットキャッシュも更新
                    WidgetDataService.shared.cacheSchedules(self.schedules)
                    // 削除完了の通知を送信
                    NotificationCenter.default.post(
                        name: .init("ScheduleDeleted"),
                        object: nil,
                        userInfo: ["scheduleId": scheduleId]
                    )
                }
                completion(true)
            }
        }
    }


    // 繰り返し予定の一括作成
    func createRecurringSchedules(_ schedules: [ScheduleItem], completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            completion(false)
            return
        }

        let totalCount = schedules.count
        var successCount = 0
        var hasError = false

        for schedule in schedules {
            var data = createScheduleData(from: schedule)
            data["created_at"] = Timestamp()

            let docRef = db.collection("users").document(userId).collection("schedules").document(schedule.id)
            docRef.setData(data) { error in
                if let error = error {
                    hasError = true
                } else {
                }

                successCount += 1
                if successCount == totalCount {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .init("ScheduleAdded"), object: nil)
                    }
                    completion(!hasError)
                }
            }
        }
    }

    // 繰り返し予定グループの削除
    func deleteRecurringGroup(groupId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            completion(false)
            return
        }

        let schedulesRef = db.collection("users").document(userId).collection("schedules")
        schedulesRef.whereField("recurringGroupId", isEqualTo: groupId).getDocuments { snapshot, error in
            if let error = error {
                completion(false)
                return
            }

            guard let documents = snapshot?.documents else {
                completion(true) // 削除対象がない場合は成功
                return
            }

            let totalCount = documents.count
            var successCount = 0

            if totalCount == 0 {
                completion(true)
                return
            }

            for document in documents {
                document.reference.delete { error in
                    if let error = error {
                    } else {
                        // 通知も削除
                        NotificationManager.shared.removeNotifications(for: document.documentID)
                    }

                    successCount += 1
                    if successCount == totalCount {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .init("ScheduleDeleted"), object: nil)
                        }
                        completion(true)
                    }
                }
            }
        }
    }

    // 単一予定のrecurringGroupIdを削除
    func removeSingleFromGroup(scheduleId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            completion(false)
            return
        }

        let docRef = db.collection("users").document(userId).collection("schedules").document(scheduleId)
        docRef.updateData(["recurringGroupId": FieldValue.delete()]) { error in
            if let error = error {
                completion(false)
            } else {
                completion(true)
            }
        }
    }

    // 繰り返しグループから特定の予定以外を削除
    func deleteOthersInGroup(groupId: String, keepScheduleId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            completion(false)
            return
        }

        let schedulesRef = db.collection("users").document(userId).collection("schedules")
        schedulesRef.whereField("recurringGroupId", isEqualTo: groupId).getDocuments { snapshot, error in
            if let error = error {
                completion(false)
                return
            }

            guard let documents = snapshot?.documents else {
                completion(true)
                return
            }

            let documentsToDelete = documents.filter { $0.documentID != keepScheduleId }

            if documentsToDelete.isEmpty {
                completion(true)
                return
            }

            let totalCount = documentsToDelete.count
            var successCount = 0

            for document in documentsToDelete {
                document.reference.delete { error in
                    if error == nil {
                        NotificationManager.shared.removeNotifications(for: document.documentID)
                    }

                    successCount += 1
                    if successCount == totalCount {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .init("ScheduleDeleted"), object: nil)
                        }
                        completion(true)
                    }
                }
            }
        }
    }

    // ユーザーデータを完全削除
    func deleteUserData(userId: String) async throws {
        // ユーザードキュメントのサブコレクションを削除
        let userRef = db.collection("users").document(userId)

        // schedulesサブコレクションを削除
        let schedulesSnapshot = try await userRef.collection("schedules").getDocuments()
        for document in schedulesSnapshot.documents {
            try await document.reference.delete()
        }

        // charactersサブコレクションとその配下を削除
        let charactersSnapshot = try await userRef.collection("characters").getDocuments()
        for characterDoc in charactersSnapshot.documents {
            // detailsサブコレクションを削除
            let detailsSnapshot = try await characterDoc.reference.collection("details").getDocuments()
            for detailDoc in detailsSnapshot.documents {
                try await detailDoc.reference.delete()
            }

            // diaryサブコレクションを削除
            let diarySnapshot = try await characterDoc.reference.collection("diary").getDocuments()
            for diaryDoc in diarySnapshot.documents {
                try await diaryDoc.reference.delete()
            }

            // Big5分析サブコレクションを削除
            let big5Snapshot = try await characterDoc.reference.collection("big5_analysis").getDocuments()
            for big5Doc in big5Snapshot.documents {
                try await big5Doc.reference.delete()
            }

            // postsサブコレクション（チャット履歴）を削除
            let postsSnapshot = try await characterDoc.reference.collection("posts").getDocuments()
            for postDoc in postsSnapshot.documents {
                try await postDoc.reference.delete()
            }

            // キャラクタードキュメントを削除
            try await characterDoc.reference.delete()
        }

        // ユーザードキュメント自体を削除
        try await userRef.delete()
    }

    // MARK: - Memo CRUD Operations

    // メモ一覧を取得
    func fetchMemos(userId: String) {
        Logger.debug("fetchMemos: userId = \(userId)", category: Logger.firestore)

        db.collection("users").document(userId).collection("memos")
            .order(by: "isPinned", descending: true)
            .order(by: "updatedAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    Logger.error("Memo fetch failed", category: Logger.firestore, error: error)
                    return
                }

                if let documents = snapshot?.documents {
                    self.memos = documents.compactMap { doc in
                        let data = doc.data()

                        guard let title = data["title"] as? String,
                              let content = data["content"] as? String else {
                            return nil
                        }

                        let createdAtTimestamp = data["createdAt"] as? Timestamp
                        let updatedAtTimestamp = data["updatedAt"] as? Timestamp
                        let tag = data["tag"] as? String ?? ""
                        let isPinned = data["isPinned"] as? Bool ?? false

                        let createdAt = createdAtTimestamp?.dateValue() ?? Date()
                        let updatedAt = updatedAtTimestamp?.dateValue() ?? Date()

                        return Memo(
                            id: doc.documentID,
                            title: title,
                            content: content,
                            createdAt: createdAt,
                            updatedAt: updatedAt,
                            tag: tag,
                            isPinned: isPinned
                        )
                    }
                    Logger.debug("fetchMemos: Found \(self.memos.count) memos", category: Logger.firestore)

                    // ウィジェット用にキャッシュ
                    WidgetDataService.shared.cacheMemos(self.memos)
                }
            }
    }

    // メモを追加
    func addMemo(_ memo: Memo, userId: String, completion: @escaping (Bool) -> Void) {
        let docRef = db.collection("users").document(userId).collection("memos").document(memo.id)

        docRef.setData(memo.toDictionary()) { error in
            if let error = error {
                Logger.error("Memo add failed", category: Logger.firestore, error: error)
                completion(false)
            } else {
                Logger.success("Memo added successfully", category: Logger.firestore)
                // 最新データを取得してウィジェット更新
                self.fetchMemos(userId: userId)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .init("MemoAdded"), object: nil)
                }
                completion(true)
            }
        }
    }

    // メモを更新
    func updateMemo(_ memo: Memo, userId: String, completion: @escaping (Bool) -> Void) {
        let docRef = db.collection("users").document(userId).collection("memos").document(memo.id)

        var updatedMemo = memo
        updatedMemo.updatedAt = Date()

        docRef.updateData(updatedMemo.toDictionary()) { error in
            if let error = error {
                Logger.error("Memo update failed", category: Logger.firestore, error: error)
                completion(false)
            } else {
                Logger.success("Memo updated successfully", category: Logger.firestore)
                // 最新データを取得してウィジェット更新
                self.fetchMemos(userId: userId)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .init("MemoUpdated"), object: nil)
                }
                completion(true)
            }
        }
    }

    // メモを削除
    func deleteMemo(memoId: String, userId: String, completion: @escaping (Bool) -> Void) {
        let docRef = db.collection("users").document(userId).collection("memos").document(memoId)

        docRef.delete { error in
            if let error = error {
                Logger.error("Memo delete failed", category: Logger.firestore, error: error)
                completion(false)
            } else {
                Logger.success("Memo deleted successfully", category: Logger.firestore)
                DispatchQueue.main.async {
                    self.memos.removeAll { $0.id == memoId }
                    // ウィジェットキャッシュも更新
                    WidgetDataService.shared.cacheMemos(self.memos)
                    NotificationCenter.default.post(name: .init("MemoDeleted"), object: nil)
                }
                completion(true)
            }
        }
    }

    // メモのピン留め切り替え
    func toggleMemoPin(memoId: String, userId: String, isPinned: Bool, completion: @escaping (Bool) -> Void) {
        let docRef = db.collection("users").document(userId).collection("memos").document(memoId)

        docRef.updateData([
            "isPinned": isPinned,
            "updatedAt": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                Logger.error("Memo pin toggle failed", category: Logger.firestore, error: error)
                completion(false)
            } else {
                Logger.success("Memo pin toggled successfully", category: Logger.firestore)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .init("MemoUpdated"), object: nil)
                }
                completion(true)
            }
        }
    }

    // MARK: - Todo CRUD Operations

    // TODO一覧を取得
    func fetchTodos(userId: String) {
        Logger.debug("fetchTodos: userId = \(userId)", category: Logger.firestore)

        db.collection("users").document(userId).collection("todos")
            .order(by: "isCompleted")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    Logger.error("Todo fetch failed", category: Logger.firestore, error: error)
                    return
                }

                if let documents = snapshot?.documents {
                    self.todos = documents.compactMap { doc in
                        let data = doc.data()

                        guard let title = data["title"] as? String else {
                            return nil
                        }

                        let description = data["description"] as? String ?? ""
                        let isCompleted = data["isCompleted"] as? Bool ?? false
                        let dueDateTimestamp = data["dueDate"] as? Timestamp
                        let priorityString = data["priority"] as? String ?? "中"
                        let tag = data["tag"] as? String ?? ""
                        let createdAtTimestamp = data["createdAt"] as? Timestamp
                        let updatedAtTimestamp = data["updatedAt"] as? Timestamp

                        let dueDate = dueDateTimestamp?.dateValue()
                        let priority = TodoItem.TodoPriority(rawValue: priorityString) ?? .medium
                        let createdAt = createdAtTimestamp?.dateValue() ?? Date()
                        let updatedAt = updatedAtTimestamp?.dateValue() ?? Date()

                        return TodoItem(
                            id: doc.documentID,
                            title: title,
                            description: description,
                            isCompleted: isCompleted,
                            dueDate: dueDate,
                            priority: priority,
                            tag: tag,
                            createdAt: createdAt,
                            updatedAt: updatedAt
                        )
                    }
                    Logger.debug("fetchTodos: Found \(self.todos.count) todos", category: Logger.firestore)

                    // ウィジェット用にキャッシュ
                    WidgetDataService.shared.cacheTodos(self.todos)
                }
            }
    }

    // TODOを追加
    func addTodo(_ todo: TodoItem, userId: String, completion: @escaping (Bool) -> Void) {
        let docRef = db.collection("users").document(userId).collection("todos").document(todo.id)

        docRef.setData(todo.toDictionary()) { error in
            if let error = error {
                Logger.error("Todo add failed", category: Logger.firestore, error: error)
                completion(false)
            } else {
                Logger.success("Todo added successfully", category: Logger.firestore)
                // 最新データを取得してウィジェット更新
                self.fetchTodos(userId: userId)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .init("TodoAdded"), object: nil)
                }
                completion(true)
            }
        }
    }

    // TODOを更新
    func updateTodo(_ todo: TodoItem, userId: String, completion: @escaping (Bool) -> Void) {
        let docRef = db.collection("users").document(userId).collection("todos").document(todo.id)

        var updatedTodo = todo
        updatedTodo.updatedAt = Date()

        docRef.updateData(updatedTodo.toDictionary()) { error in
            if let error = error {
                Logger.error("Todo update failed", category: Logger.firestore, error: error)
                completion(false)
            } else {
                Logger.success("Todo updated successfully", category: Logger.firestore)
                // 最新データを取得してウィジェット更新
                self.fetchTodos(userId: userId)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .init("TodoUpdated"), object: nil)
                }
                completion(true)
            }
        }
    }

    // TODOを削除
    func deleteTodo(todoId: String, userId: String, completion: @escaping (Bool) -> Void) {
        let docRef = db.collection("users").document(userId).collection("todos").document(todoId)

        docRef.delete { error in
            if let error = error {
                Logger.error("Todo delete failed", category: Logger.firestore, error: error)
                completion(false)
            } else {
                Logger.success("Todo deleted successfully", category: Logger.firestore)
                DispatchQueue.main.async {
                    self.todos.removeAll { $0.id == todoId }
                    // ウィジェットキャッシュも更新
                    WidgetDataService.shared.cacheTodos(self.todos)
                    NotificationCenter.default.post(name: .init("TodoDeleted"), object: nil)
                }
                completion(true)
            }
        }
    }

    // TODO完了状態を切り替え
    func toggleTodoComplete(todoId: String, userId: String, isCompleted: Bool, completion: @escaping (Bool) -> Void) {
        let docRef = db.collection("users").document(userId).collection("todos").document(todoId)

        docRef.updateData([
            "isCompleted": isCompleted,
            "updatedAt": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                Logger.error("Todo complete toggle failed", category: Logger.firestore, error: error)
                completion(false)
            } else {
                Logger.success("Todo complete toggled successfully", category: Logger.firestore)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .init("TodoUpdated"), object: nil)
                }
                completion(true)
            }
        }
    }

    static let shared = FirestoreManager()
}
