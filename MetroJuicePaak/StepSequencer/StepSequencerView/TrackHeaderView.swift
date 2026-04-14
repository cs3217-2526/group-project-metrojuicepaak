//
//  TrackHeaderView.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 27/03/2026.
//

import SwiftUI

struct TrackHeaderView: View {
    // 🟢 Bindable allows SwiftUI to watch this specific class instance for changes
    @Bindable var track: SequencerTrack
    let viewModel: StepSequencerViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Text("Assign Sample").font(.caption)
                Divider()
                
                // Fetch the list of available samples from the injected repository protocol
                let availableSamples = viewModel.repository.allSamples
                
                if availableSamples.isEmpty {
                    Text("No samples loaded")
                } else {
                    // Iterate through the samples
                    ForEach(availableSamples, id: \.name) { sample in
                        // Create the ObjectIdentifier key for the audio engine
                        let sampleID = ObjectIdentifier(sample)
                        let isCurrent = track.sampleID == sampleID
                        
                        Button(action: {
                            viewModel.executeAssignSample(trackId: track.id, sampleID: sampleID)
                        }) {
                            HStack {
                                Text(sample.name)
                                if isCurrent { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
                
                if track.sampleID != nil {
                    Divider()
                    Button(role: .destructive, action: {
                        viewModel.executeRemoveSample(trackId: track.id)
                    }) {
                        Label("Remove Sample", systemImage: "trash")
                    }
                }
            } label: {
                menuLabel
            }
            
            // Delete Track Button
            Button(action: {
                viewModel.executeRemoveTrack(trackId: track.id)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Subviews & Helpers
    
    private var menuLabel: some View {
        HStack {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundColor(track.sampleID != nil ? .cyan : .gray)
            
            Text(currentSampleName)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(track.sampleID != nil ? .white : .gray)
                .lineLimit(1)
            
            Spacer()
            
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 8)
        .frame(width: 150, height: 40)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var currentSampleName: String {
        // Safely look up the readable name from the repository using the track's ID
        guard let sampleID = track.sampleID,
              let namedSample = viewModel.repository.getNamedSample(for: sampleID) else {
            return "Empty Track"
        }
        return namedSample.name
    }
}
