//
//  WaveformTrimContent.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 19/4/26.
//

import SwiftUI

/// The existing waveform trim UI, extracted into its own view so the parent
/// can swap between trim and effects modes.
struct WaveformTrimContent: View {

    let viewModel: SamplerEditorViewModel

    @State private var lastStartRatio: CGFloat = 0.0
    @State private var lastEndRatio: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 20) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let startRatio = CGFloat(viewModel.tempStartRatio)
                let endRatio = CGFloat(viewModel.tempEndRatio)

                ZStack(alignment: .leading) {

                    if let waveform = viewModel.waveformData {
                        SamplerThumbnailView(data: waveform, strokeColor: .cyan)
                    } else {
                        Text("Loading visual...")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: startRatio * width)

                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: (1.0 - endRatio) * width)
                        .offset(x: endRatio * width)

                    TrimHandle()
                        .offset(x: startRatio * width)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    viewModel.stopPreview()
                                    let delta = value.translation.width / width
                                    let proposed = lastStartRatio + delta
                                    let clamped = max(0.0, min(proposed, endRatio - 0.05))
                                    viewModel.tempStartRatio = Double(clamped)
                                }
                                .onEnded { _ in lastStartRatio = startRatio }
                        )

                    TrimHandle()
                        .offset(x: (endRatio * width) - 4)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    viewModel.stopPreview()
                                    let delta = value.translation.width / width
                                    let proposed = lastEndRatio + delta
                                    let clamped = min(1.0, max(proposed, startRatio + 0.05))
                                    viewModel.tempEndRatio = Double(clamped)
                                }
                                .onEnded { _ in lastEndRatio = endRatio }
                        )
                }
                .onAppear {
                    self.lastStartRatio = startRatio
                    self.lastEndRatio = endRatio
                }
                .task {
                    if viewModel.waveformData == nil {
                        await viewModel.generateThumbnail(resolution: Int(width))
                    }
                }
            }
            .frame(height: 150)
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .padding(.horizontal)

            HStack(spacing: 40) {
                Button {
                    Task { await viewModel.togglePreview() }
                } label: {
                    Image(systemName: viewModel.isPlayingPreview
                          ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(viewModel.isPlayingPreview ? .red : .cyan)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
    }
}
