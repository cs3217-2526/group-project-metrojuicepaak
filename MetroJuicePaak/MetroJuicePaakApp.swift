//
//  MetroJuicePaakApp.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 17/3/26.
//

import SwiftUI
import AVFoundation

@main
struct MetroJuicePaakApp: App {
    @State private var samplerOrchestrator: SamplerViewModel?
    @State private var sequencerViewModel: StepSequencerViewModel?
    @State private var initializationError: Error?

    var body: some Scene {
        WindowGroup {
            Group {
                // Wait until BOTH ViewModels are successfully initialized
                if let samplerVM = samplerOrchestrator, let sequencerVM = sequencerViewModel {
                    MainTabView(
                        samplerOrchestrator: samplerVM,
                        sequencerViewModel: sequencerVM
                    )
                } else if let error = initializationError {
                    ErrorView(error: error)
                } else {
                    ProgressView("Initializing audio engine...")
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
 
            let avEngine = AVAudioEngine()
            
            let timeProvider = AudioTimeProvider(audioEngine: avEngine)
            
            let musicEngine = MusicEngineImplementation(audioPlaybackService: audioService, timeProvider: timeProvider)
            
            // Initialize Sampler
            let samplerVM = SamplerViewModel(
                repository: repository,
                audioService: audioService,
                waveformGenerator: waveformGenerator,
                effectRegistry: effectRegistry
            )
            print("🎙️ 4. Sampler Orchestrator built successfully.")
            
            // Initialize Step Sequencer
            // AudioService acts as the MusicEngine, Repository acts as ReadableAudioSampleRepository
            let sequencerVM = StepSequencerViewModel(
                repository: repository,
                musicEngine: musicEngine
            )
            print("🎙️ 5. Step Sequencer ViewModel built successfully.")
            
            self.samplerOrchestrator = samplerVM
            self.sequencerViewModel = sequencerVM
            print("🎙️ 6. State updated! Switching to TabView.")
            
        } catch {
            self.initializationError = error
            print("🛑 Initialization failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Effect Bootstrap

/// Centralized effect registration. Every built-in DSPEffect type the app
/// ships with is registered here. Adding a new effect means adding a
/// single line to this function, after including the file in ConcreteDSPEffects
/// the rest of the app discovers it via
/// the registry at runtime.
enum AppBootstrap {
    static func registerBuiltInEffects(into registry: EffectRegistry) {
        registry.register(GainEffect.self)
        registry.register(LowpassEffect.self)
        registry.register(ReverbEffect.self)
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
