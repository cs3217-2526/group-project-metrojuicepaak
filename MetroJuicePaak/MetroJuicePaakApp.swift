//
//  MetroJuicePaakApp.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 17/3/26.
//

import SwiftUI

@main
struct MetroJuicePaakApp: App {
    @State private var orchestrator: SamplerViewModel?
    @State private var initializationError: Error?

    var body: some Scene {
        WindowGroup {
            Group {
                if let viewModel = orchestrator {
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

            // Bootstrap the effect registry and register every built-in DSP effect.
            // The same instance is shared by AudioService (for instantiating live
            // effects on the audio thread) and SamplerViewModel (for browsing
            // effect metadata in the UI). Single source of truth.
            let effectRegistry = EffectRegistry()
            AppBootstrap.registerBuiltInEffects(into: effectRegistry)
            print("🎙️ 3. Effect registry populated with \(effectRegistry.allMetadata().count) effects.")

            // Register the AU subclass with the AudioComponentManager exactly once.
            // Required before any call to AVAudioUnit.instantiate.
            DSPEffectAUBridge.registerOnce()
            print("🎙️ 4. DSPEffectAUBridge registered with AudioComponentManager.")

            let audioService = try await AudioService(registry: effectRegistry)
            print("🎙️ 5. AudioService created successfully.")

            let waveformGenerator = WaveformCache()

            let viewModel = SamplerViewModel(
                repository: repository,
                audioService: audioService,
                waveformGenerator: waveformGenerator,
                effectRegistry: effectRegistry
            )
            print("🎙️ 6. Orchestrator built successfully.")

            self.orchestrator = viewModel
            print("🎙️ 7. State updated! The UI should switch right now.")

        } catch {
            self.initializationError = error
            print("🛑 Initialization failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Effect Bootstrap

/// Centralized effect registration. Every built-in DSPEffect type the app
/// ships with is registered here. Adding a new effect means adding a
/// single line to this function — the rest of the app discovers it via
/// the registry at runtime.
enum AppBootstrap {
    static func registerBuiltInEffects(into registry: EffectRegistry) {
        // Register each concrete DSPEffect type as it becomes available.
        
        registry.register(GainEffect.self)
        registry.register(LowpassEffect.self)
        registry.register(ReverbEffect.self)
        // registry.register(HighpassEffect.self)
        // registry.register(DistortionEffect.self)
        // registry.register(DelayEffect.self)
        // registry.register(CompressorEffect.self)
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
