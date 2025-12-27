import SwiftUI

struct Big5AnalysisDetailView: View {
    let analysis: Big5DetailedAnalysis
    let analysisLevel: Big5AnalysisLevel

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var fontSettings: FontSettingsManager
    @StateObject private var colorSettings = ColorSettingsManager.shared
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            colorSettings.getCurrentBackgroundGradient()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // ヘッダー部分
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // メインコンテンツ
                    mainContentSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // 解析レベルと進捗表示
            HStack {
                Text("\(analysisLevel.icon) \(analysisLevel.displayName)")
                    .dynamicTitle2()
                    .foregroundColor(colorSettings.getCurrentTextColor())
                    .fontWeight(.bold)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.6))
                }
            }
            
            // カテゴリーヘッダー
            HStack {
                Text(analysis.category.icon)
                    .font(.largeTitle)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.category.displayName)
                        .dynamicTitle()
                        .foregroundColor(colorSettings.getCurrentTextColor())
                        .fontWeight(.bold)
                    
                    Text(analysis.personalityType)
                        .dynamicTitle3()
                        .foregroundColor(colorSettings.getCurrentAccentColor())
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Main Content Section
    
    @ViewBuilder
    private var mainContentSection: some View {
        VStack(spacing: 20) {
            // 詳細解析文
            analysisTextSection

            // キーポイント
            keyPointsSection
        }
    }
    
    @ViewBuilder
    private var analysisTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📝 詳細解析")
                    .dynamicTitle3()
                    .foregroundColor(colorSettings.getCurrentTextColor())
                    .fontWeight(.bold)
                Spacer()
            }
            
            Text(analysis.detailedText)
                .dynamicBody()
                .foregroundColor(colorSettings.getCurrentTextColor())
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var keyPointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("⭐ 特徴ポイント")
                    .dynamicTitle3()
                    .foregroundColor(colorSettings.getCurrentTextColor())
                    .fontWeight(.bold)
                Spacer()
            }
            
            ForEach(Array(analysis.keyPoints.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .dynamicCaption()
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(colorSettings.getCurrentAccentColor()))
                    
                    Text(point)
                        .dynamicBody()
                        .foregroundColor(colorSettings.getCurrentTextColor())
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var evolutionMessageSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(getEvolutionIcon())
                    .font(.largeTitle)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(getEvolutionTitle())
                        .dynamicTitle3()
                        .foregroundColor(colorSettings.getCurrentTextColor())
                        .fontWeight(.bold)
                    
                    Text(getEvolutionMessage())
                        .dynamicBody()
                        .foregroundColor(colorSettings.getCurrentTextColor().opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(getEvolutionBackgroundColor())
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(getEvolutionBorderColor(), lineWidth: 2)
                )
        )
    }
    
    // MARK: - Evolution Styling Functions
    
    private func getEvolutionIcon() -> String {
        switch analysisLevel {
        case .basic:
            return "🔧"
        case .detailed:
            return "🧬"
        case .complete:
            return "✨"
        }
    }
    
    private func getEvolutionTitle() -> String {
        switch analysisLevel {
        case .basic:
            return ""
        case .detailed:
            return ""
        case .complete:
            return ""
        }
    }
    
    private func getEvolutionMessage() -> String {
        switch analysisLevel {
        case .basic:
            return "アンドロイドとしての基本設定が確立されました。さらなる学習データの蓄積により、より人間らしい感情と思考が発達します。"
        case .detailed:
            return "多くの経験から学習し、複雑な感情と思考パターンを獲得しています。人間化まで後50問の分析が残されています。"
        case .complete:
            return "おめでとうございます！完全に人間化しました。豊かで複雑な人格を持つ存在として生まれ変わりました。"
        }
    }
    
    private func getEvolutionBackgroundColor() -> Color {
        switch analysisLevel {
        case .basic:
            return Color.blue.opacity(0.15)
        case .detailed:
            return Color.orange.opacity(0.15)
        case .complete:
            return Color.green.opacity(0.15)
        }
    }
    
    private func getEvolutionBorderColor() -> Color {
        switch analysisLevel {
        case .basic:
            return Color.blue.opacity(0.4)
        case .detailed:
            return Color.orange.opacity(0.4)
        case .complete:
            return Color.green.opacity(0.4)
        }
    }
}

#Preview {
    let sampleAnalysis = Big5DetailedAnalysis(
        category: .career,
        personalityType: "チームを牽引するリーダータイプ",
        detailedText: "あなたは職場において、自然とリーダーシップを発揮するタイプです。新しいプロジェクトや未知の課題に対して積極的に取り組み、チームメンバーを鼓舞しながら目標達成に向けて進む傾向があります。仕事では、創造的なアイデアを提案することが多く、従来の方法にとらわれずに効率的な解決策を見つけることが得意です。また、責任感が強く、一度引き受けた仕事は最後まで丁寧に完遂します。チームワークを重視し、メンバー一人ひとりの意見を聞きながら、みんなが活躍できる環境作りに努める傾向があります。",
        keyPoints: [
            "創造的なアイデア提案が得意",
            "責任感が強く最後まで完遂",
            "チームワークを重視",
            "効率的な解決策を見つけることができる"
        ],
        analysisLevel: .detailed
    )
    
    Big5AnalysisDetailView(analysis: sampleAnalysis, analysisLevel: .detailed)
        .environmentObject(FontSettingsManager())
}