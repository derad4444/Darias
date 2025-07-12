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
        db.collection("users").document(userId).collection("schedule")
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    self.schedules = documents.compactMap { doc in
                        let data = doc.data()
                        guard let timestamp = data["date"] as? Timestamp,
                              let title = data["title"] as? String else { return nil }
                        
                        // isAllDayがFirestoreに無いケースも考慮してデフォルトfalse
                        let isAllDay = data["isAllDay"] as? Bool ?? false
                        
                        return Schedule(
                            id: doc.documentID,
                            title: title,
                            date: timestamp.dateValue(),
                            isAllDay: isAllDay
                            
                        )
                    }
                    
                    // ダミー予定
                    let dummySchedule = Schedule(
                        id: UUID().uuidString,
                        title: "カフェ",
                        date: Date(),  // 今日
                        isAllDay: true
                    )
                    self.schedules.append(dummySchedule)
                }
            }
    }
    
    //Firestoreから日記一覧を取得して diaries に反映
    func fetchDiaries() {
        guard let userId = userId else { return }
        db.collection("users").document(userId).collection("posts")
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
    func fetchHolidays() {
        db.collection("holidays").getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                self.holidays = documents.compactMap { doc in
                    let data = doc.data()
                    guard let name = data["name"] as? String,
                          let dateString = data["dateString"] as? String else { return nil }
                    return Holiday(id: doc.documentID, name: name, dateString: dateString)
                }
                print("✅ holidays読み込み完了: \(self.holidays.count)件")
            }
        }
    }
    
    //予定（ScheduleItem型）を Firestore に保存する
    func addSchedule(_ schedule: ScheduleItem, for userId: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let docRef = db.collection("Schedule").document(schedule.id)
        
        // 🔽 ScheduleItem → [String: Any] に手動変換
        let data: [String: Any] = [
            "id": userId,
            "title": schedule.title,
            "isAllDay": schedule.isAllDay,
            "startDate": schedule.startDate,
            "endDate": schedule.endDate,
            "location": schedule.location,
            "tag": schedule.tag,
            "memo": schedule.memo,
            "repeatOption": schedule.repeatOption,
            "remindValue": schedule.remindValue,
            "remindUnit": schedule.remindUnit
        ]
        
        docRef.setData(data) { error in
            if let error = error {
                print("🔥 Failed to save schedule: \(error)")
                completion(false)
            } else {
                print("✅ Schedule saved successfully")
                completion(true)
            }
        }
    }
}
