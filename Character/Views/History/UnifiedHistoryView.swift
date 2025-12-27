// Character/Views/History/UnifiedHistoryView.swift

import SwiftUI

struct UnifiedHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    let userId: String
    let characterId: String

    @State private var selectedTab: HistoryTab = .chat

    // 共有インスタンスは直接参照
    private let colorSettings = ColorSettingsManager.shared

    enum HistoryTab: String, CaseIterable {
        case chat = "チャット"
        case meeting = "会議"

        var icon: String {
            switch self {
            case .chat: return "message.fill"
            case .meeting: return "person.3.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景グラデーション
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // カスタムヘッダー
                    HStack {
                        Spacer()
                        Text("履歴")
                            .font(.headline)
                        Spacer()
                    }
                    .overlay(
                        HStack {
                            Spacer()
                            Button("閉じる") {
                                dismiss()
                            }
                            .foregroundColor(colorSettings.getCurrentAccentColor())
                            .padding(.trailing, 16)
                        }
                    )
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(
                        Color.white.opacity(0.1)
                            .ignoresSafeArea(edges: .top)
                    )

                    // タブ切り替えボタン
                    HStack(spacing: 0) {
                        ForEach(HistoryTab.allCases, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 22))
                                    Text(tab.rawValue)
                                        .font(.caption)
                                }
                                .foregroundColor(selectedTab == tab ? colorSettings.getCurrentAccentColor() : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.1))

                    // コンテンツ（スワイプ対応）
                    TabView(selection: $selectedTab) {
                        ChatHistoryView(
                            userId: userId,
                            characterId: characterId
                        )
                        .tag(HistoryTab.chat)

                        MeetingHistoryView(
                            userId: userId,
                            characterId: characterId
                        )
                        .tag(HistoryTab.meeting)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    UnifiedHistoryView(
        userId: "test_user",
        characterId: "test_character"
    )
}
