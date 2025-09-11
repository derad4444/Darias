import Foundation
import SwiftUI

// MARK: - App Error Types
enum AppError: LocalizedError {
    case authenticationFailed
    case networkError(String)
    case firestoreError(String)
    case cloudFunctionError(String)
    case invalidInput(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "認証に失敗しました"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .firestoreError(let message):
            return "データベースエラー: \(message)"
        case .cloudFunctionError(let message):
            return "サーバーエラー: \(message)"
        case .invalidInput(let message):
            return "入力エラー: \(message)"
        case .unknownError(let message):
            return "予期しないエラー: \(message)"
        }
    }
}

// MARK: - Error Manager
class ErrorManager: ObservableObject {
    @Published var currentError: AppError?
    @Published var showingAlert = false
    
    func handleError(_ error: Error) {
        DispatchQueue.main.async {
            if let appError = error as? AppError {
                self.currentError = appError
            } else {
                self.currentError = AppError.unknownError(error.localizedDescription)
            }
            self.showingAlert = true
        }
        
        // ログ出力
        logError(error)
    }
    
    func handleError(_ appError: AppError) {
        DispatchQueue.main.async {
            self.currentError = appError
            self.showingAlert = true
        }
        
        // ログ出力
        logError(appError)
    }
    
    private func logError(_ error: Error) {
        // Error logging handled silently
        // In production, this would send to appropriate logging service
        #if DEBUG
        // Debug environment detailed logging is disabled
        #endif
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.showingAlert = false
        }
    }
}

// MARK: - Error Alert View Modifier
struct ErrorAlert: ViewModifier {
    @ObservedObject var errorManager: ErrorManager
    
    func body(content: Content) -> some View {
        content
            .alert("エラー", isPresented: $errorManager.showingAlert) {
                Button("OK") {
                    errorManager.clearError()
                }
            } message: {
                Text(errorManager.currentError?.localizedDescription ?? "不明なエラーが発生しました")
            }
    }
}

extension View {
    func errorAlert(_ errorManager: ErrorManager) -> some View {
        modifier(ErrorAlert(errorManager: errorManager))
    }
}