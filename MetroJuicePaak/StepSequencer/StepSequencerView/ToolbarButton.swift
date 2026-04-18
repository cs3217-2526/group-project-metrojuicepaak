//
//  ToolbarButton.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 27/03/2026.
//

import SwiftUI

struct ToolbarButton: View {
    let icon: String
    let action: () -> Void
    var color: Color = .white
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isDisabled ? .gray : color)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(isDisabled)
    }
}
