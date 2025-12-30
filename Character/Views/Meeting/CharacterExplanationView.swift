// Character/Views/Meeting/CharacterExplanationView.swift

import SwiftUI

struct CharacterExplanationView: View {
    @Environment(\.dismiss) private var dismiss

    // 共有インスタンスは直接参照
    private let colorSettings = ColorSettingsManager.shared

    let characters: [(id: String, name: String, icon: String, color: Color, description: String, traits: [String])] = [
        (
            id: "original",
            name: "今の自分",
            icon: "person.fill",
            color: .blue,
            description: "現在のあなたの考え方や価値観",
            traits: [
                "現実的な視点で物事を考える",
                "今の状況を踏まえた判断",
                "実際の経験に基づく意見",
                "バランスの取れた視点"
            ]
        ),
        (
            id: "opposite",
            name: "真逆の自分",
            icon: "arrow.triangle.2.circlepath",
            color: .orange,
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
            color: .purple,
            description: "なりたい姿、目指している理想の自分",
            traits: [
                "長期的な視点を持つ",
                "理想の価値観で判断",
                "目標達成を重視",
                "成長を促す視点"
            ]
        ),
        (
            id: "shadow",
            name: "本音の自分",
            icon: "person.crop.circle",
            color: .red,
            description: "普段は隠している本当の気持ち",
            traits: [
                "率直な感情を表現",
                "本心からの意見",
                "建前を排除した視点",
                "抑圧された欲求を代弁"
            ]
        ),
        (
            id: "child",
            name: "子供の頃の自分",
            icon: "figure.walk",
            color: .green,
            description: "純粋で素直だった子供時代の自分",
            traits: [
                "純粋な感性で物事を見る",
                "素直な感情表現",
                "夢や希望を大切にする",
                "シンプルな幸せを追求"
            ]
        ),
        (
            id: "wise",
            name: "未来の自分(70歳)",
            icon: "person.crop.square.filled.and.at.rectangle",
            color: Color(red: 0.6, green: 0.4, blue: 0.2),
            description: "人生経験を積んだ未来の自分",
            traits: [
                "長い人生経験からの知恵",
                "俯瞰的な視点",
                "本当に大切なものを見抜く",
                "後悔しない選択を促す"
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

                        Text("6人の自分について")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("あなたのBIG5性格診断データを基に、\n6つの異なる自分が多角的に議論します")
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
                            BulletPoint(text: "今の自分と真逆の自分が異なる視点で議論")
                            BulletPoint(text: "理想の自分が目標達成の視点を提供")
                            BulletPoint(text: "本音の自分が率直な感情を表現")
                            BulletPoint(text: "子供の頃の自分が純粋な視点を追加")
                            BulletPoint(text: "未来の自分が長期的な視野で結論")
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
        .navigationTitle("自分会議の説明")
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
