import SwiftUI

// MARK: - Hex Color Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - App Palette

extension Color {
    static let backdrop      = Color(hex: "#C8C8C8") // full-screen bg behind card
    static let cardLight     = Color(hex: "#F0F0F0") // All Stations bg
    static let cardDark      = Color(hex: "#282828") // Now Playing cards / dark text
    static let charcoal      = Color(hex: "#202020") // station name / icons on light
    static let tagBackground = Color(hex: "#CFCFCF") // tag pills / NP outer bg
}

// MARK: - App Font

extension Font {
    /// System UI, weight 300 (light), size 14 px — used everywhere in the app
    static let appFont = Font.system(size: 14, weight: .light)
}

// MARK: - NSColor Helper

import AppKit

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8)  & 0xFF) / 255
        let b = CGFloat( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
