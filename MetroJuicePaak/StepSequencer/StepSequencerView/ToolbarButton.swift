//
//  ToolbarButton.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 27/03/2026.
//

import SwiftUI

struct ToolbarButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(width: 44, height: 44)
            .background(Color(white: 0.2))
            .foregroundColor(configuration.isPressed ? .gray : .white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
