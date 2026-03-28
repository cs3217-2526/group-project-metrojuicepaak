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
            if isSampleLoaded, let amplitudes = viewModel.pads[id]?.sample?.miniWaveform, !amplitudes.isEmpty {
                // Draw the cached waveform
                GeometryReader { geo in
                    Path { path in
                        let width = geo.size.width
                        let height = geo.size.height
                        let count = amplitudes.count
                        
                        for (index, amplitude) in amplitudes.enumerated() {
                            let x = width * CGFloat(index) / CGFloat(count - 1)
                            // Scale the amplitude down slightly so it fits nicely inside the pad
                            let y = height - (amplitude * height * 0.8)
                            
                            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                .padding(12)
            } else if isSampleLoaded {
                // Fallback if processing fails
                Text("Loaded").font(.caption).bold().foregroundColor(.white)
            } else {
                if let image = UIElements.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                }
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
                        Task {
                            await viewModel.handlePadPressed(id)
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        self.isBeingPressed = false
                    }
                    Task {
                        await viewModel.handlePadReleased(id)
                    }
                }
        )
    }
}
//#Preview("Blue Pad - Empty") {
//    SamplerPadButton(
//        id: UUID(),
//        viewModel: .mockForPreview(),
//        isSampleLoaded: false
//    )
//    .frame(width: 100, height: 100)
//    .padding()
//}
//
//#Preview("Red Pad - Loaded") {
//    SamplerPadButton(
//        id: UUID(),
//        viewModel: .mockForPreview(),
//        isSampleLoaded: true,
//        UIElements: SamplerPadButtonUIElements(color: .red)
//    )
//    .frame(width: 100, height: 100)
//    .padding()
//}
//
//#Preview("All Colors") {
//    let colors: [SamplerPadColour] = [.blue, .red, .green, .yellow, .purple, .orange, .pink, .teal]
//    let viewModel = SamplerViewModel.mockForPreview()
//    
//    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
//        ForEach(colors, id: \.self) { color in
//            SamplerPadButton(
//                id: UUID(),
//                viewModel: viewModel,
//                isSampleLoaded: false,
//                UIElements: SamplerPadButtonUIElements(color: color)
//            )
//        }
//    }
//    .padding()
//}
//
