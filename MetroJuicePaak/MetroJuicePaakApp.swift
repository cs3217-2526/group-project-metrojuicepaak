//
//  MetroJuicePaakApp.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 17/3/26.
//

import SwiftUI

@main
struct MetroJuicePaakApp: App {
    @State private var samplerViewModel: SamplerViewModel?
    @State private var initializationError: Error?
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let viewModel = samplerViewModel {
                    SamplerView(viewModel: viewModel)
                } else if let error = initializationError {
                    ErrorView(error: error)
                } else {
                    ProgressView("Initializing audio...")
                }
            }
            .task {
                await initializeAudio()
            }
        }
    }
    
    @MainActor
    private func initializeAudio() async {
        do {
            // Instantiate the Mocks!
            let waveformGenerator: WaveformGenerationService = MockWaveformGenerator()
            let playbackService: AudioPlaybackService = MockAudioPlaybackService()
            let recordingService: AudioRecordingService = MockAudioRecordingService()
            
            // Pass them into the Conductor and Sampler exactly as before
            let audioSampleRepoVM = AudioSampleRepositoryViewModel(generator: waveformGenerator)
            
            let viewModel = SamplerViewModel(
                audioSampleVM: audioSampleRepoVM,
                playbackService: playbackService,
                recordingService: recordingService
            )
            
            self.samplerViewModel = viewModel
            
        } catch {
            self.initializationError = error
        }
    }
}

// Simple error view to display initialization errors
struct ErrorView: View {
    let error: Error
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            
            Text("Audio Initialization Failed")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Optional cast might require your specific Error enum type here
            if error.localizedDescription.contains("Permission") {
                Text("Please enable microphone access in Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding()
    }
}
