// Views/Extensions/ButtonStyles.swift

import SwiftUI

// プライマリボタンスタイル - メインアクション用
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(LinearGradient.AppGradients.primaryButton)
                    .shadow(color: Color.AppTheme.primaryPink.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// セカンダリボタンスタイル - サブアクション用
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(Color.AppTheme.primaryPink)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.AppTheme.creamWhite)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.AppTheme.primaryPink.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.AppTheme.cardShadow, radius: 4, x: 0, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// 小さなアクションボタン - アイコン付き
struct SmallActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(LinearGradient.AppGradients.accentHighlight)
                    .shadow(color: Color.AppTheme.accentGold.opacity(0.3), radius: 4, x: 0, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// フローティングアクションボタン - チャット送信など
struct FloatingActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 56, height: 56)
            .background(
                Circle()
                    .fill(LinearGradient.AppGradients.primaryButton)
                    .shadow(color: Color.AppTheme.primaryPink.opacity(0.4), radius: 12, x: 0, y: 6)
            )
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// カードボタンスタイル - 選択可能なカード
struct CardButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ?
                          LinearGradient.AppGradients.primaryButton :
                          LinearGradient.AppGradients.cardShine)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.clear : Color.AppTheme.primaryPink.opacity(0.2),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isSelected ?
                            Color.AppTheme.primaryPink.opacity(0.3) :
                            Color.AppTheme.cardShadow,
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// ボタンスタイル適用のための拡張
extension Button {
    func primaryStyle() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    func secondaryStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
    
    func smallActionStyle() -> some View {
        self.buttonStyle(SmallActionButtonStyle())
    }
    
    func floatingActionStyle() -> some View {
        self.buttonStyle(FloatingActionButtonStyle())
    }
    
    func cardStyle(isSelected: Bool = false) -> some View {
        self.buttonStyle(CardButtonStyle(isSelected: isSelected))
    }
}