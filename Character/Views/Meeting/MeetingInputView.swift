// Character/Views/Meeting/MeetingInputView.swift

import SwiftUI

struct MeetingInputView: View {
    @Environment(\.dismiss) private var dismiss

    // 共有インスタンスは直接参照（パフォーマンス改善）
    private let meetingService = SixPersonMeetingService.shared
    private let colorSettings = ColorSettingsManager.shared
    private let subscriptionManager = SubscriptionManager.shared

    let userId: String
    let characterId: String

    @State private var concernText: String = ""
    @State private var selectedCategory: ConcernCategory = .other
    @State private var isGenerating: Bool = false
    @State private var showMeetingView: Bool = false
    @State private var generatedResponse: GenerateMeetingResponse?
    @State private var showError: Bool = false
    @State private var showPremiumRequiredAlert: Bool = false
    @State private var showPremiumUpgradeSheet: Bool = false
    @State private var showCharacterExplanation: Bool = false
    @State private var usageCount: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea()

                ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー
                    headerSection

                    // 制限情報バナー（無料ユーザーのみ表示）
                    if !subscriptionManager.isPremium {
                        usageLimitBanner
                    }

                    // カテゴリ選択
                    categorySection

                    // 悩み入力
                    concernInputSection

                    // 生成ボタン
                    generateButton

                    Spacer()
                }
                .padding()
                }
            }
            .navigationTitle("自分会議")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showCharacterExplanation = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle")
                            Text("説明")
                                .font(.subheadline)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCharacterExplanation) {
                NavigationStack {
                    CharacterExplanationView()
                }
            }
            .sheet(isPresented: $showPremiumUpgradeSheet) {
                PremiumUpgradeView()
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(meetingService.errorMessage ?? "エラーが発生しました")
            }
            .alert("プレミアムプランで無制限に", isPresented: $showPremiumRequiredAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("プレミアムプランを見る") {
                    showPremiumUpgradeSheet = true
                }
            } message: {
                Text("無料プランでは自分会議は1回のみ利用可能です。\n\nプレミアムプランにアップグレードすると：\n✨ 自分会議を無制限に開催\n✨ AIとの会話も無制限\n✨ すべての機能をフル活用")
            }
            .navigationDestination(isPresented: $showMeetingView) {
                if let response = generatedResponse {
                    SixPersonMeetingView(
                        meetingResponse: response,
                        concernText: concernText,
                        category: selectedCategory
                    )
                }
            }
            .onAppear {
                loadUsageCount()
            }
        }
    }

    // MARK: - Helper Methods

    private func loadUsageCount() {
        Task {
            do {
                usageCount = try await meetingService.getMeetingUsageCount(
                    userId: userId,
                    characterId: characterId
                )

                // デバッグ情報
                print("📊 Meeting Usage Count: \(usageCount)")
                print("👑 Is Premium: \(subscriptionManager.isPremium)")
                print("📈 Subscription Status: \(subscriptionManager.subscriptionStatus)")
            } catch {
                // エラー時は0として扱う（制限を緩める方向で）
                usageCount = 0
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("6人の自分があなたの悩みを\n多角的に議論します")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(.vertical)
    }

    // MARK: - Usage Limit Banner

    private var usageLimitBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: usageCount >= 1 ? "exclamationmark.triangle.fill" : "info.circle.fill")
                    .foregroundColor(usageCount >= 1 ? .orange : .blue)

                VStack(alignment: .leading, spacing: 4) {
                    if usageCount >= 1 {
                        Text("利用制限に達しました")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("無料プランでは1回のみ利用可能です")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("無料プランでは1回のみ利用可能")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("プレミアムなら無制限に利用できます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            Button(action: {
                showPremiumUpgradeSheet = true
            }) {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("プレミアムで無制限に")
                        .fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(usageCount >= 1 ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(usageCount >= 1 ? Color.orange : Color.blue, lineWidth: 1)
                )
        )
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("カテゴリを選択")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ConcernCategory.allCases) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    // MARK: - Concern Input Section

    private var concernInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("悩みを入力してください")
                .font(.headline)

            TextEditor(text: $concernText)
                .frame(minHeight: 150)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Text("\(concernText.count) / 500文字")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button(action: generateMeeting) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "sparkles")
                    Text("会議を開始")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(concernText.isEmpty || isGenerating ? Color.gray.opacity(0.5) : Color.blue.opacity(0.85))
            .cornerRadius(12)
        }
        .disabled(concernText.isEmpty || isGenerating)
    }

    // MARK: - Generate Meeting

    private func generateMeeting() {
        isGenerating = true

        Task {
            do {
                let response = try await meetingService.generateOrReuseMeeting(
                    userId: userId,
                    characterId: characterId,
                    concern: concernText,
                    category: selectedCategory.rawValue
                )

                generatedResponse = response
                showMeetingView = true
                isGenerating = false

                // 使用回数を更新（無料ユーザーのバナー表示用）
                loadUsageCount()

            } catch {
                isGenerating = false

                // プレミアム制限エラーをチェック
                if let meetingError = error as? MeetingError,
                   case .premiumRequired = meetingError {
                    showPremiumRequiredAlert = true
                } else {
                    showError = true
                }
            }
        }
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let category: ConcernCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)

                Text(category.displayName)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isSelected {
                        Color.blue.opacity(0.15)
                    } else {
                        Color(.systemGray6).opacity(0.8)
                    }
                }
            )
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    MeetingInputView(
        userId: "test_user",
        characterId: "test_character"
    )
}
