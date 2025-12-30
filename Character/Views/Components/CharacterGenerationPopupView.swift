import SwiftUI
import FirebaseFirestore

struct CharacterGenerationPopupView: View {
    let status: CharacterGenerationStatus
    let userId: String
    let characterId: String
    
    var body: some View {
        ZStack {
            // 背景オーバーレイ
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {} // タップを無効化
            
            // ポップアップ本体
            VStack(spacing: 20) {
                // アニメーション付きアイコン
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.3)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                    
                    if status.isGenerating {
                        // 生成中のアニメーション
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(rotationAngle))
                            .animation(
                                Animation.linear(duration: 2.0)
                                    .repeatForever(autoreverses: false),
                                value: rotationAngle
                            )
                            .onAppear {
                                rotationAngle = 360
                            }
                    } else if status.isCompleted {
                        // 完了アイコン
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                    } else if status.isFailed {
                        // 失敗アイコン
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.red)
                    }
                }
                
                // タイトル
                Text(titleText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                // メッセージ
                Text(status.displayMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                // 進捗バー（生成中の場合のみ）
                if status.isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(1.2)
                }
                
                // 段階情報（生成中の場合のみ）
                if status.isGenerating && status.stage > 0 {
                    Text("段階 \(status.stage) の性格を生成中")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // ボタン（完了・失敗時のみ）
                if status.isCompleted {
                    // 完了時: キャラクター詳細への誘導ボタン
                    VStack(spacing: 12) {
                        Button(action: {
                            // ポップアップを閉じる
                            NotificationCenter.default.post(
                                name: .dismissCharacterGenerationPopup,
                                object: nil
                            )
                            // キャラクター詳細タブに切り替え
                            NotificationCenter.default.post(
                                name: .openCharacterDetail,
                                object: nil
                            )
                        }) {
                            Text("キャラクター詳細を見る")
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
                        .buttonStyle(PlainButtonStyle())

                        // 共有ボタン
                        Button(action: {
                            fetchCharacterDataAndShare()
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("結果を共有")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            NotificationCenter.default.post(
                                name: .dismissCharacterGenerationPopup,
                                object: nil
                            )
                        }) {
                            Text("閉じる")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                } else if status.isFailed {
                    // 失敗時: OKボタンのみ
                    Button("OK") {
                        // ポップアップを閉じる処理
                        NotificationCenter.default.post(
                            name: .dismissCharacterGenerationPopup,
                            object: nil
                        )
                    }
                    .buttonStyle(
                        .borderedProminent
                    )
                    .controlSize(.regular)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            )
            .padding(.horizontal, 40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ShareHelper.sharePersonalityAnalysis(
                stage: status.stage,
                strengths: characterStrength,
                weaknesses: characterWeakness,
                dreams: characterDream
            ))
        }
    }
    
    // MARK: - Private Properties
    @State private var rotationAngle: Double = 0
    @State private var showShareSheet: Bool = false
    @State private var characterStrength: String = ""
    @State private var characterWeakness: String = ""
    @State private var characterDream: String = ""
    
    private var titleText: String {
        switch status.status {
        case .generating:
            return "性格を生成中です"
        case .completed:
            return status.completionTitle
        case .failed:
            return "生成に失敗しました"
        case .notStarted:
            return ""
        }
    }

    // MARK: - Private Methods

    private func fetchCharacterDataAndShare() {
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(userId)
            .collection("characters").document(characterId)
            .collection("details").document("current")

        docRef.getDocument { document, error in
            if let data = document?.data() {
                characterStrength = data["strength"] as? String ?? "未設定"
                characterWeakness = data["weakness"] as? String ?? "未設定"
                characterDream = data["dream"] as? String ?? "未設定"

                // データ取得後に共有シートを表示
                showShareSheet = true
            } else {
                // データ取得失敗時もデフォルト値で共有
                characterStrength = "未設定"
                characterWeakness = "未設定"
                characterDream = "未設定"
                showShareSheet = true
            }
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let dismissCharacterGenerationPopup = Notification.Name("dismissCharacterGenerationPopup")
    static let openCharacterDetail = Notification.Name("openCharacterDetail")
}

// MARK: - Preview
struct CharacterGenerationPopupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 生成中
            CharacterGenerationPopupView(
                status: CharacterGenerationStatus(
                    stage: 1,
                    status: .generating,
                    message: "性格生成中です。画面を閉じずに少々お待ちください。",
                    updatedAt: Timestamp()
                ),
                userId: "preview_user",
                characterId: "preview_character"
            )
            .previewDisplayName("生成中")

            // 完了
            CharacterGenerationPopupView(
                status: CharacterGenerationStatus(
                    stage: 1,
                    status: .completed,
                    message: nil,
                    updatedAt: Timestamp()
                ),
                userId: "preview_user",
                characterId: "preview_character"
            )
            .previewDisplayName("完了")

            // 失敗
            CharacterGenerationPopupView(
                status: CharacterGenerationStatus(
                    stage: 1,
                    status: .failed,
                    message: "生成に失敗しました: ネットワークエラー",
                    updatedAt: Timestamp()
                ),
                userId: "preview_user",
                characterId: "preview_character"
            )
            .previewDisplayName("失敗")
        }
    }
}