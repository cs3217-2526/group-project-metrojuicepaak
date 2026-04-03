//
//  TrackHeaderView.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 27/03/2026.
//

import SwiftUI

struct TrackHeaderView: View {
    let trackIndex: Int
    var viewModel: StepSequencerViewModel
    let rowHeight: CGFloat
    
    var body: some View {
        if trackIndex < viewModel.sequencerModel.tracks.count {
            let currentTrack = viewModel.sequencerModel.tracks[trackIndex]
            let currentPadNumber = viewModel.padNumber(for: currentTrack.padID)
            
            HStack(spacing: 0) {
                Button(action: { viewModel.removeTrack(at: trackIndex) }) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .frame(width: 20, height: rowHeight)
                }
                .buttonStyle(.plain)
                
                Menu {
                    Text("Assign Sample to Track").font(.caption)
                    Divider()
                    
                    // Show only available pads PLUS the one currently assigned
                    ForEach(viewModel.pads) { pad in
                        let isCurrent = currentTrack.padID == pad.id
                        let isUsed = viewModel.sequencerModel.tracks.contains(where: { $0.padID == pad.id })
                        
                        if isCurrent || !isUsed {
                            let padNum = viewModel.padNumber(for: pad.id)
                            Button {
                                viewModel.updateTrackPad(trackIndex: trackIndex, newPadID: pad.id)
                            } label: {
                                HStack {
                                    Text("Pad \(padNum)")
                                    if pad.isSampleLoaded { Image(systemName: "waveform") }
                                    if isCurrent { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.gray)
                            .font(.caption)
                        
                        VStack(alignment: .leading) {
                            Text("Pad \(currentPadNumber)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 6)
                    .frame(height: rowHeight)
                }
            }
            .background(Color(white: 0.18))
            .cornerRadius(6)
        } else {
            EmptyView()
        }
    }
}
