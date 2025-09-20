import FirebaseFirestore
import FirebaseAuth
import Foundation

class FirestoreManager: ObservableObject {
    //Firestoreへの接続インスタンス
    private let db = Firestore.firestore()
    //現在ログイン中のFirebaseユーザーのIDを取得（認証が前提）
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    //Firestoreから取得した予定データ（一覧）を保存する
    @Published var schedules: [Schedule] = []
    //Firestoreから取得した日記データ（一覧）を保存する
    @Published var diaries: [Diary] = []
    //Firestoreから取得した祝日データ（一覧）を保存する
    @Published var holidays: [Holiday] = []
    
    //Firestoreからスケジュール一覧を取得して schedules に反映
    func fetchSchedules() {
        guard let userId = userId else { return }
        
        db.collection("users").document(userId).collection("schedules")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ fetchSchedules error: \(error)")
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
                            recurringGroupId: recurringGroupId
                        )


                        return schedule
                    }
                }
            }
    }
    
    //Firestoreから日記一覧を取得して diaries に反映
    func fetchDiaries(characterId: String) {
        guard let userId = userId else { return }
        // キャラクター別のサブコレクションから取得
        db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("diary")
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    self.diaries = documents.compactMap { doc in
                        let data = doc.data()
                        guard let timestamp = data["date"] as? Timestamp,
                              let title = data["title"] as? String else { return nil }
                        return Diary(id: doc.documentID, title: title, date: timestamp.dateValue())
                    }
                }
            }
    }
    
    // Firestoreから祝日一覧取得
    func fetchHolidays(completion: @escaping () -> Void = {}) {
        db.collection("holidays").getDocuments { snapshot, error in
            if let error = error {
                print("❌ fetchHolidays error: \(error)")
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
        
        // 🔽 ScheduleItem → [String: Any] に手動変換
        var data: [String: Any] = [
            "title": schedule.title,
            "isAllDay": schedule.isAllDay,
            "startDate": Timestamp(date: schedule.startDate),
            "endDate": Timestamp(date: schedule.endDate),
            "location": schedule.location,
            "tag": schedule.tag,
            "memo": schedule.memo,
            "repeatOption": schedule.repeatOption,
            "remindValue": schedule.remindValue,
            "remindUnit": schedule.remindUnit,
            "created_at": Timestamp()
        ]

        // recurringGroupIdがある場合は追加
        if let recurringGroupId = schedule.recurringGroupId {
            data["recurringGroupId"] = recurringGroupId
        }
        
        docRef.setData(data) { error in
            if let error = error {
                print("❌ Schedule add error: \(error)")
                completion(false)
            } else {
                print("✅ Schedule added to users/\(userId)/schedules")
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
                print("❌ Failed to get original schedule data")
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
                    print("❌ Schedule update error: \(error)")
                    completion(false)
                } else {
                    print("✅ Schedule dates updated for \(scheduleId)")
                    // CalendarViewに予定更新を通知
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .init("ScheduleAdded"), object: nil)
                    }
                    completion(true)
                }
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
                print("❌ Schedule delete error: \(error)")
                completion(false)
            } else {
                print("✅ Schedule deleted: \(scheduleId)")
                // ローカルの予定リストからも削除
                DispatchQueue.main.async {
                    self.schedules.removeAll { $0.id == scheduleId }
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

    // 繰り返し予定グループを削除する
    func deleteRecurringGroup(groupId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            print("❌ deleteRecurringGroup: userId is nil")
            completion(false)
            return
        }



        // まず同じgroupIdを持つ全ての予定を取得
        db.collection("users").document(userId).collection("schedules")
            .whereField("recurringGroupId", isEqualTo: groupId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch recurring group: \(error)")
                    completion(false)
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("❌ No documents found for group: \(groupId)")
                    completion(false)
                    return
                }


                if documents.isEmpty {
                    print("❌ No schedules found with recurringGroupId: \(groupId)")
                    completion(false)
                    return
                }

                // バッチ削除を実行
                let batch = self.db.batch()
                for document in documents {
                    batch.deleteDocument(document.reference)
                }
                batch.commit { error in
                    if let error = error {
                        print("❌ Batch delete error: \(error)")
                        completion(false)
                    } else {
                        print("✅ Recurring group deleted: \(groupId), count: \(documents.count)")
                        // ローカルの予定リストからも削除
                        DispatchQueue.main.async {
                            self.schedules.removeAll { $0.recurringGroupId == groupId }

                            // 削除完了の通知を送信
                            NotificationCenter.default.post(
                                name: .init("ScheduleDeleted"),
                                object: nil,
                                userInfo: ["recurringGroupId": groupId]
                            )
                        }
                        completion(true)
                    }
                }
            }
    }
}
