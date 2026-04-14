//
//  StepButton.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 27/03/2026.
//

import SwiftUI

struct StepButton: View {
    let isActive: Bool
    let isCurrentStep: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 6)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        // Show a white border if the playhead is currently on this step
                        .stroke(isCurrentStep ? Color.white : Color.clear, lineWidth: 2)
                )
        }
        .frame(width: 40, height: 40)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var fillColor: Color {
        if isActive {
            return .cyan
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}
