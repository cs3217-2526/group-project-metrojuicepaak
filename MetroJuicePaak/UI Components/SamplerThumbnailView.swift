//
//  SampleThumbnailView.swift
//  MetroJuicePaak
//
//  Created by proglab on 4/4/26.
//

import SwiftUI

// 1. The Pure Shape
struct WaveformShape: Shape {
    var data: WaveformData
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let count = data.points.count
        
        guard count > 1 else { return path }
        
        for (index, amplitude) in data.points.enumerated() {
            let x = width * CGFloat(index) / CGFloat(count - 1)
            // Scale amplitude down slightly to fit cleanly inside the pad bounds
            let y = height - (CGFloat(amplitude) * height * 0.8)
            
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        
        return path
    }
}

// 2. The View Wrapper
struct SamplerThumbnailView: View {
    var data: WaveformData
    var strokeColor: Color = .white
    
    var body: some View {
        WaveformShape(data: data)
            .stroke(strokeColor.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .padding(12)
    }
}
