//
//  SamplerPadButton.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 22/3/26.
//

import SwiftUI

struct SamplerPadButton: View {
    let id: UUID
    let viewModel: SamplerViewModel
    let UIElements: SamplerPadButtonUIElements
    let isSampleLoaded: Bool
    
    @State private var isBeingPressed = false
    
    init(id: UUID, viewModel: SamplerViewModel, isSampleLoaded: Bool = false, UIElements: SamplerPadButtonUIElements = SamplerPadButtonUIElements()) {
        self.id = id
        self.viewModel = viewModel
        self.isSampleLoaded = isSampleLoaded
        self.UIElements = UIElements
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(UIElements.color.swiftUIColor)
                .shadow(color: .black.opacity(0.3), radius: isBeingPressed ? 2 : 4, y: isBeingPressed ? 2 : 4)
            if let image = UIElements.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(8)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(isBeingPressed ? 0.95 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !self.isBeingPressed {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            self.isBeingPressed = true
                        }
                        viewModel.handlePadPressed(id)
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        self.isBeingPressed = false
                    }
                    viewModel.handlePadReleased(id)
                }
        )
    }
}
#Preview("Blue Pad - Empty") {
    SamplerPadButton(
        id: UUID(),
        viewModel: .mockForPreview(),
        isSampleLoaded: false
    )
    .frame(width: 100, height: 100)
    .padding()
}

#Preview("Red Pad - Loaded") {
    SamplerPadButton(
        id: UUID(),
        viewModel: .mockForPreview(),
        isSampleLoaded: true,
        UIElements: SamplerPadButtonUIElements(color: .red)
    )
    .frame(width: 100, height: 100)
    .padding()
}

#Preview("All Colors") {
    let colors: [SamplerPadColour] = [.blue, .red, .green, .yellow, .purple, .orange, .pink, .teal]
    let viewModel = SamplerViewModel.mockForPreview()
    
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
        ForEach(colors, id: \.self) { color in
            SamplerPadButton(
                id: UUID(),
                viewModel: viewModel,
                isSampleLoaded: false,
                UIElements: SamplerPadButtonUIElements(color: color)
            )
        }
    }
    .padding()
}

