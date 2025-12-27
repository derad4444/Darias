// Character/Views/Meeting/CharacterExplanationView.swift

import SwiftUI

struct CharacterExplanationView: View {
    @Environment(\.dismiss) private var dismiss

    // 共有インスタンスは直接参照
    private let colorSettings = ColorSettingsManager.shared

    let characters: [(id: String, name: String, icon: String, color: Color, description: String, traits: [String])] = [
        (
            id: "cautious",
            name: "慎重派の自分",
            icon: "shield.fill",
            color: .blue,
            description: "リスクを避け、計画的に行動する自分",
            traits: [
                "物事を慎重に考える傾向",
                "失敗を避けるための準備を重視",
                "安定した選択を好む",
                "時間をかけて判断する"
            ]
        ),
        (
            id: "active",
            name: "行動派の自分",
            icon: "bolt.fill",
            color: .orange,
            description: "直感的に動き、チャレンジを恐れない自分",
            traits: [
                "即座に行動に移す傾向",
                "新しいことに挑戦するのが好き",
                "失敗を恐れない",
                "スピード感を重視"
            ]
        ),
        (
            id: "emotional",
            name: "感情重視の自分",
            icon: "heart.fill",
            color: .pink,
            description: "心の声を大切にする自分",
            traits: [
                "感情や直感を大切にする",
                "人との繋がりを重視",
                "共感力が高い",
                "心地よさを優先"
            ]
        ),
        (
            id: "logical",
            name: "論理重視の自分",
            icon: "brain.head.profile",
            color: .purple,
            description: "データと理性で判断する自分",
            traits: [
                "論理的な思考を重視",
                "データや事実に基づいて判断",
                "客観的な分析を得意とする",
                "効率性を追求"
            ]
        ),
        (
            id: "opposite",
            name: "真逆の自分",
            icon: "arrow.triangle.2.circlepath",
            color: .green,
            description: "あなたとは正反対の性格を持つ自分",
            traits: [
                "普段とは異なる視点を提供",
                "意外な発見をもたらす",
                "固定観念を打ち破る",
                "新しい可能性を示す"
            ]
        ),
        (
            id: "ideal",
            name: "理想の自分",
            icon: "star.fill",
            color: .yellow,
            description: "バランスが取れた理想的な性格の自分",
            traits: [
                "各視点を統合する",
                "バランスの取れた判断",
                "長期的な視点を持つ",
                "全体を俯瞰して考える"
            ]
        )
    ]

    var body: some View {
        ZStack {
            // 背景
            colorSettings.getCurrentBackgroundGradient()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // ヘッダー説明
                    VStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)

                        Text("6人の性格について")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("あなたのBIG5性格診断データを基に、\n6つの異なる視点から議論します")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                    // 各キャラクターの説明
                    ForEach(characters, id: \.id) { character in
                        CharacterCard(
                            name: character.name,
                            icon: character.icon,
                            color: character.color,
                            description: character.description,
                            traits: character.traits
                        )
                    }

                    // 補足説明
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("会議のポイント")
                                .font(.headline)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            BulletPoint(text: "慎重派と行動派が対立しながら議論")
                            BulletPoint(text: "感情派と論理派がバランスを提供")
                            BulletPoint(text: "真逆の自分が予想外の視点を追加")
                            BulletPoint(text: "理想の自分が全体をまとめて結論")
                        }
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("性格の説明")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("閉じる") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Character Card

struct CharacterCard: View {
    let name: String
    let icon: String
    let color: Color
    let description: String
    let traits: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.15))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // 特徴
            VStack(alignment: .leading, spacing: 6) {
                ForEach(traits, id: \.self) { trait in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(color)
                        Text(trait)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Bullet Point

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.headline)
                .foregroundColor(.yellow)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    CharacterExplanationView()
}
