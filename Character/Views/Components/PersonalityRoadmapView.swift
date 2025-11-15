import SwiftUI

struct PersonalityRoadmapView: View {
    let answeredCount: Int
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var fontSettings: FontSettingsManager
    @ObservedObject var colorSettings = ColorSettingsManager.shared
    @State private var showHowToPopover = false
    
    // 3段階の情報
    private let stages = [
        StageInfo(
            number: 1,
            title: "基本分析",
            description: "基本的な性格特性を分析します",
            questionRange: "1-20問",
            totalQuestions: 20,
            features: ["外向性の基本測定", "協調性の基本測定", "神経症傾向の基本測定"]
        ),
        StageInfo(
            number: 2,
            title: "詳細分析", 
            description: "より詳細な性格パターンを解析します",
            questionRange: "21-50問",
            totalQuestions: 30,
            features: ["誠実性の詳細分析", "開放性の詳細分析", "複合的な性格傾向"]
        ),
        StageInfo(
            number: 3,
            title: "完全分析",
            description: "総合的な性格プロファイルを完成させます", 
            questionRange: "51-100問",
            totalQuestions: 50,
            features: ["全特性の統合分析", "詳細な性格レポート", "個性の完全理解"]
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景グラデーション（設定画面で設定した色を使用）
                colorSettings.getCurrentBackgroundGradient()
                    .ignoresSafeArea()
                
                ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48 * fontSettings.fontSize.scale, weight: .bold))
                            .foregroundColor(colorSettings.getCurrentAccentColor())
                        
                        Text("性格解析ロードマップ")
                            .font(.system(size: 24 * fontSettings.fontSize.scale, weight: .bold))
                            .foregroundColor(colorSettings.getCurrentTextColor())
                        
                        Text("全100問の性格診断を3段階で進めて、\nあなたの個性を詳しく分析します")
                            .font(.system(size: 16 * fontSettings.fontSize.scale))
                            .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // 現在の進捗
                    VStack(spacing: 12) {
                        Text("現在の進捗")
                            .font(.system(size: 18 * fontSettings.fontSize.scale, weight: .semibold))
                            .foregroundColor(colorSettings.getCurrentTextColor())
                        
                        HStack {
                            Text("\(answeredCount)")
                                .font(.system(size: 32 * fontSettings.fontSize.scale, weight: .bold))
                                .foregroundColor(colorSettings.getCurrentAccentColor())
                            
                            Text("/ 100 問完了")
                                .font(.system(size: 16 * fontSettings.fontSize.scale))
                                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                        }
                        
                        ProgressView(value: Double(answeredCount), total: 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: colorSettings.getCurrentAccentColor()))
                            .frame(height: 8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )

                    // 段階別情報
                    VStack(spacing: 16) {
                        ForEach(stages, id: \.number) { stage in
                            StageCardView(
                                stage: stage,
                                answeredCount: answeredCount,
                                fontSettings: fontSettings,
                                colorSettings: colorSettings
                            )
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHowToPopover = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 20))
                            .foregroundColor(colorSettings.getCurrentAccentColor())
                    }
                    .popover(isPresented: $showHowToPopover) {
                        HowToPopoverContent(
                            fontSettings: fontSettings,
                            colorSettings: colorSettings
                        )
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(colorSettings.getCurrentAccentColor())
                }
            }
        }
    }
}

struct StageInfo {
    let number: Int
    let title: String
    let description: String
    let questionRange: String
    let totalQuestions: Int
    let features: [String]
}

struct StageCardView: View {
    let stage: StageInfo
    let answeredCount: Int
    let fontSettings: FontSettingsManager
    let colorSettings: ColorSettingsManager
    
    private var stageStatus: StageStatus {
        switch stage.number {
        case 1:
            if answeredCount >= 20 { return .completed }
            else if answeredCount > 0 { return .inProgress }
            else { return .notStarted }
        case 2:
            if answeredCount >= 50 { return .completed }
            else if answeredCount > 20 { return .inProgress }
            else { return .notStarted }
        case 3:
            if answeredCount >= 100 { return .completed }
            else if answeredCount > 50 { return .inProgress }
            else { return .notStarted }
        default:
            return .notStarted
        }
    }
    
    private var progressInStage: Double {
        switch stage.number {
        case 1:
            return min(Double(answeredCount) / 20.0, 1.0)
        case 2:
            return answeredCount <= 20 ? 0 : min(Double(answeredCount - 20) / 30.0, 1.0)
        case 3:
            return answeredCount <= 50 ? 0 : min(Double(answeredCount - 50) / 50.0, 1.0)
        default:
            return 0
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ヘッダー
            HStack {
                // ステージ番号とアイコン
                ZStack {
                    Circle()
                        .fill(stageStatus.color(colorSettings: colorSettings))
                        .frame(width: 48, height: 48)
                    
                    if stageStatus == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20 * fontSettings.fontSize.scale, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(stage.number)")
                            .font(.system(size: 20 * fontSettings.fontSize.scale, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(stage.title)
                            .font(.system(size: 18 * fontSettings.fontSize.scale, weight: .semibold))
                            .foregroundColor(colorSettings.getCurrentTextColor())
                        
                        Spacer()
                        
                        Text(stage.questionRange)
                            .font(.system(size: 12 * fontSettings.fontSize.scale, weight: .medium))
                            .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    Text(stage.description)
                        .font(.system(size: 14 * fontSettings.fontSize.scale))
                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                }
                
                Spacer()
            }
            
            // 進捗バー
            if stageStatus != .notStarted {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("進捗")
                            .font(.system(size: 12 * fontSettings.fontSize.scale, weight: .medium))
                            .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
                        
                        Spacer()
                        
                        Text("\(Int(progressInStage * 100))%")
                            .font(.system(size: 12 * fontSettings.fontSize.scale, weight: .bold))
                            .foregroundColor(colorSettings.getCurrentAccentColor())
                    }
                    
                    ProgressView(value: progressInStage)
                        .progressViewStyle(LinearProgressViewStyle(tint: stageStatus.color(colorSettings: colorSettings)))
                        .frame(height: 6)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(3)
                }
            }
            
            // 特徴リスト
            VStack(alignment: .leading, spacing: 8) {
                Text("分析内容")
                    .font(.system(size: 14 * fontSettings.fontSize.scale, weight: .medium))
                    .foregroundColor(colorSettings.getCurrentTextColor())
                
                ForEach(stage.features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12 * fontSettings.fontSize.scale))
                            .foregroundColor(stageStatus == .completed ? 
                                           colorSettings.getCurrentAccentColor() : 
                                           Color.gray.opacity(0.5))
                        
                        Text(feature)
                            .font(.system(size: 13 * fontSettings.fontSize.scale))
                            .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(stageStatus.borderColor(colorSettings: colorSettings), lineWidth: 2)
                )
        )
    }
}

struct HowToPopoverContent: View {
    let fontSettings: FontSettingsManager
    let colorSettings: ColorSettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // タイトル
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18 * fontSettings.fontSize.scale))
                    .foregroundColor(.yellow)

                Text("診断の進め方")
                    .font(.system(size: 18 * fontSettings.fontSize.scale, weight: .bold))
                    .foregroundColor(colorSettings.getCurrentTextColor())
            }

            Divider()

            // 説明文
            Text("チャット画面でこのメッセージを送信すると質問が始まります：")
                .font(.system(size: 14 * fontSettings.fontSize.scale))
                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            // 送信例
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14 * fontSettings.fontSize.scale))
                        .foregroundColor(colorSettings.getCurrentAccentColor())

                    Text("「性格診断して」")
                        .font(.system(size: 15 * fontSettings.fontSize.scale, weight: .medium))
                        .foregroundColor(colorSettings.getCurrentTextColor())
                }

                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14 * fontSettings.fontSize.scale))
                        .foregroundColor(colorSettings.getCurrentAccentColor())

                    Text("「性格解析して」")
                        .font(.system(size: 15 * fontSettings.fontSize.scale, weight: .medium))
                        .foregroundColor(colorSettings.getCurrentTextColor())
                }
            }
            .padding(.leading, 4)

            // 補足
            Text("好きなタイミングで質問を受けられます。")
                .font(.system(size: 13 * fontSettings.fontSize.scale))
                .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.7))
        }
        .padding(20)
        .frame(width: 300)
        .background(Color(.systemBackground))
    }
}

enum StageStatus {
    case notStarted
    case inProgress
    case completed

    func color(colorSettings: ColorSettingsManager) -> Color {
        switch self {
        case .notStarted:
            return Color.gray.opacity(0.5)
        case .inProgress:
            return colorSettings.getCurrentAccentColor().opacity(0.7)
        case .completed:
            return colorSettings.getCurrentAccentColor()
        }
    }

    func borderColor(colorSettings: ColorSettingsManager) -> Color {
        switch self {
        case .notStarted:
            return Color.gray.opacity(0.2)
        case .inProgress:
            return colorSettings.getCurrentAccentColor().opacity(0.3)
        case .completed:
            return colorSettings.getCurrentAccentColor().opacity(0.5)
        }
    }
}

#Preview {
    PersonalityRoadmapView(answeredCount: 35)
        .environmentObject(FontSettingsManager())
}