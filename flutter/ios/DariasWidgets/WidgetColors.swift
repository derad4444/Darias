//
//  WidgetColors.swift
//  DariasWidgets
//

import SwiftUI

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

struct WidgetColors {
    static let primaryPink = Color(red: 1.0, green: 0.42, blue: 0.616)       // #FF6B9D
    static let lavender    = Color(red: 0.769, green: 0.29, blue: 0.753)      // #C44AC0
    static let gradientStart = Color(red: 1.0, green: 0.898, blue: 0.945)    // #FFE5F1
    static let gradientEnd   = Color(red: 0.898, green: 0.953, blue: 1.0)    // #E5F3FF
    static let textPrimary   = Color(red: 0.176, green: 0.176, blue: 0.176)  // #2D2D2D
    static let textSecondary = Color(red: 0.42, green: 0.42, blue: 0.42)     // #6B6B6B

    static let backgroundGradient = LinearGradient(
        colors: [gradientStart, gradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [primaryPink, lavender],
        startPoint: .leading,
        endPoint: .trailing
    )
}
