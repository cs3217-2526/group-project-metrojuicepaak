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
            Rectangle()
                .fill(fillColor)
                .overlay(
                    Rectangle()
                        .stroke(isCurrentStep ? Color.white : Color.clear, lineWidth: 2)
                )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .buttonStyle(PlainButtonStyle())
        .cornerRadius(2)
    }
    
    private var fillColor: Color {
        if isActive {
            return Color(red: 0.0, green: 0.8, blue: 0.9)
        } else {
            return Color(white: 0.15)
        }
    }
}
