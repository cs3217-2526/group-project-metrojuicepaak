//
//  SamplerPad.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 22/3/26.
//

import Foundation

// MARK: - Pad Color Enum (Framework-agnostic)
enum SamplerPadColour: String, Codable, Hashable {
    case blue, red, green, yellow, purple, orange, pink, teal
    case gray, white, black, cyan, magenta, indigo, mint, brown
}


// MARK: - SwiftUI Color Extension (View-layer only)
#if canImport(SwiftUI)
import SwiftUI
extension SamplerPadColour {
    var swiftUIColor: Color {
        switch self {
        case .blue: return .blue
        case .red: return .red
        case .green: return .green
        case .yellow: return .yellow
        case .purple: return .purple
        case .orange: return .orange
        case .pink: return .pink
        case .teal: return .teal
        case .gray: return .gray
        case .white: return .white
        case .black: return .black
        case .cyan: return .cyan
        case .magenta: return Color(red: 1.0, green: 0.0, blue: 1.0)
        case .indigo: return .indigo
        case .mint: return .mint
        case .brown: return .brown
        }
    }
}
#endif

// MARK: - UIKit Color Extension (For AudioKit UI)
#if canImport(UIKit)
import UIKit

extension SamplerPadColour {
    var uiColor: UIColor {
        switch self {
        case .blue: return .systemBlue
        case .red: return .systemRed
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .purple: return .systemPurple
        case .orange: return .systemOrange
        case .pink: return .systemPink
        case .teal: return .systemTeal
        case .gray: return .systemGray
        case .white: return .white
        case .black: return .black
        case .cyan: return .systemCyan
        case .magenta: return .systemPink
        case .indigo: return .systemIndigo
        case .mint: return .systemMint
        case .brown: return .systemBrown
        }
    }
}
#endif


