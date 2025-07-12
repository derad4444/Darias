// RootView.swift
import SwiftUI

//画面分岐
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        VStack {
            if authManager.isLoading {
                ProgressView("起動中...")
            } else if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(authManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
        .onAppear {
            BGMPlayer.shared.playBGM(filename: "DARIAS BGM.mp3")
        }
    }
}
