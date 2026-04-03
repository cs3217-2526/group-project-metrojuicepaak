//
//  StepView.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 27/03/2026.
//

import SwiftUI

struct StepView: View {
    let isActive: Bool
    let isCurrentStep: Bool
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: width > 10 ? 4 : 1)
                .fill(isActive ? Color.cyan : Color(white: 0.15))
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: width > 10 ? 4 : 1)
                        .stroke(isCurrentStep ? Color.white.opacity(0.8) : Color.clear, lineWidth: width > 15 ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}
