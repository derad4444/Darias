import SwiftUI

struct MeetingFeatureUnlockPopup: View {
    let onTryNow: () -> Void
    let onDismiss: () -> Void
    @State private var isPresented = false
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        ZStack {
            // 背景オーバーレイ
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // ポップアップ本体
            VStack(spacing: 24) {
                // UNLOCKEDタイトル
                HStack(spacing: 4) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)

                    Text("UNLOCKED!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.green)
                }
                .padding(.top, 8)

                // アイコンエリア
                ZStack {
                    // 背景の光エフェクト
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(glowOpacity),
                                    Color.blue.opacity(0)
                                ]),
                                center: .center,
                                startRadius: 10,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: glowOpacity
                        )

                    // カード風の背景
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.1),
                                    Color.purple.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        )

                    // 会議アイコンとテキスト
                    VStack(spacing: 4) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.blue)

                        Text("自分会議")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                .scaleEffect(isPresented ? 1.0 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isPresented)

                // 解禁メッセージ
                Text("レベル1達成で解禁!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                // 説明文
                VStack(spacing: 8) {
                    Text("6つの視点であなたの悩みを")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text("深掘りする新機能です")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                // 無料プランの注意書き
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)

                    Text("無料プランで1回お試しいただけます")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )

                // ボタンエリア
                VStack(spacing: 12) {
                    // プライマリボタン
                    Button(action: {
                        onTryNow()
                    }) {
                        Text("使ってみる")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }

                    // セカンダリボタン
                    Button(action: {
                        onDismiss()
                    }) {
                        Text("スキップ")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
            .scaleEffect(isPresented ? 1.0 : 0.8)
            .opacity(isPresented ? 1.0 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isPresented = true
            }
            glowOpacity = 0.6
        }
    }
}

// MARK: - Preview
struct MeetingFeatureUnlockPopup_Previews: PreviewProvider {
    static var previews: some View {
        MeetingFeatureUnlockPopup(
            onTryNow: {
                print("Try now tapped")
            },
            onDismiss: {
                print("Dismiss tapped")
            }
        )
        .previewDisplayName("会議機能解禁ポップアップ")
    }
}
