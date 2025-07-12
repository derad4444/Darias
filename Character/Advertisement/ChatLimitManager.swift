import Foundation
import FirebaseFirestore
import FirebaseAuth

class ChatLimitManager: ObservableObject {
    @Published var remainingChats: Int = 5
    
    private let db = Firestore.firestore()
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    init() {
        fetchChatLimit()
    }
    
    func fetchChatLimit() {
        guard let userId = userId else { return }
        let docRef = db.collection("users").document(userId)
        docRef.getDocument { document, error in
            if let data = document?.data(),
               let count = data["remaining_chats"] as? Int {
                self.remainingChats = count
            } else {
                self.remainingChats = 5
            }
        }
    }
    
    func consumeChat() {
        guard remainingChats > 0 else { return }
        remainingChats -= 1
        updateFirestore()
    }
    
    func refillChats() {
        remainingChats = 5
        updateFirestore()
    }
    
    private func updateFirestore() {
        guard let userId = userId else { return }
        db.collection("users").document(userId).updateData([
            "remaining_chats": remainingChats
        ])
    }
}
