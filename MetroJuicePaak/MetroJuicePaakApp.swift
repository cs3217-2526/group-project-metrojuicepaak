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
    
    private func initializeAudio() async {
        do {
            let audioService = try await AudioService()
            let viewModel = SamplerViewModel(audioService: audioService)
            samplerViewModel = viewModel
        } catch {
            initializationError = error
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
            
            if (error as? AudioServiceError) == .recordPermissionDenied {
                Text("Please enable microphone access in Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding()
    }
}

