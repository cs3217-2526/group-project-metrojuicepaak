//
//  TrackHeaderView.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 27/03/2026.
//

import SwiftUI

struct TrackHeaderView: View {
    let trackId: UUID
    var viewModel: StepSequencerViewModel
    let rowHeight: CGFloat
    
    var body: some View {
        if let currentTrack = viewModel.sequencerModel.tracks[trackId] {
            HStack(spacing: 0) {
                deleteTrackButton
                sampleAssignmentMenu(for: currentTrack)
            }
            .background(Color(white: 0.18))
            .cornerRadius(6)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Subcomponents
private extension TrackHeaderView {
    
    var deleteTrackButton: some View {
        Button(action: { viewModel.executeRemoveTrack(trackId: trackId) }) {
            Image(systemName: "xmark")
                .font(.caption2)
                .foregroundColor(.gray)
                .frame(width: 20, height: rowHeight)
        }
        .buttonStyle(.plain)
    }
    
    func sampleAssignmentMenu(for currentTrack: SequencerTrack) -> some View {
        Menu {
            Text("Assign Sample to Track").font(.caption)
            Divider()
            
            sampleList(currentTrack: currentTrack)
            
            if currentTrack.sample != nil {
                Divider()
                removeSampleButton
            }
            
        } label: {
            menuLabel(for: currentTrack)
        }
    }
    
    @ViewBuilder
    func sampleList(currentTrack: SequencerTrack) -> some View {
        let availableSamples = Array(viewModel.sessionManager.repository.allSamples.values)
        
        if availableSamples.isEmpty {
            Text("No samples loaded")
        } else {
            ForEach(availableSamples) { sample in
                let isCurrent = currentTrack.sample?.id == sample.id
                
                Button(action: { viewModel.executeAddSample(trackId: trackId, newSample: sample) }) {
                    HStack {
                        Text(sample.userGivenName)
                        if isCurrent { Image(systemName: "checkmark") }
                    }
                }
            }
        }
    }
    
    var removeSampleButton: some View {
        Button(role: .destructive, action: { viewModel.executeRemoveSample(trackId: trackId) }) {
            Text("Remove Sample")
            Image(systemName: "trash")
        }
    }
    
    func menuLabel(for currentTrack: SequencerTrack) -> some View {
        HStack {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundColor(currentTrack.sample != nil ? .cyan : .gray)
                .font(.caption)
            
            VStack(alignment: .leading) {
                Text(currentTrack.sample?.name ?? "Empty Track")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(currentTrack.sample != nil ? .white : .gray)
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
