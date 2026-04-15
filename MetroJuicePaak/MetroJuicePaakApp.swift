//
//  MetroJuicePaakApp.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 17/3/26.
//

import SwiftUI

@main
struct MetroJuicePaakApp: App {
    // Renamed to match the terminology we used in the View
    @State private var orchestrator: SamplerViewModel?
    @State private var initializationError: Error?
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let viewModel = orchestrator {
                    // Pass it as 'orchestrator' since we updated the SamplerView parameter
                    SamplerView(orchestrator: viewModel)
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
        print("🎙️ 1. Starting audio initialization...")
        do {
            let repository = AudioSampleRepository()
            print("🎙️ 2. Repository created successfully.")
            
            // If the console stops here, the bug is inside your teammate's AudioService init!
            let audioService = try await AudioService()
            print("🎙️ 3. AudioService created successfully.")
            
            let waveformGenerator = WaveformCache()
            
            let viewModel = SamplerViewModel(
                repository: repository,
                audioService: audioService,
                waveformGenerator: waveformGenerator
            )
            print("🎙️ 4. Orchestrator built successfully.")
            
            self.orchestrator = viewModel
            print("🎙️ 5. State updated! The UI should switch right now.")
            
        } catch {
            self.initializationError = error
            print("🛑 Initialization failed: \(error.localizedDescription)")
        }
    }
}

// Simple error view to display initialization errors (Unchanged)
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
