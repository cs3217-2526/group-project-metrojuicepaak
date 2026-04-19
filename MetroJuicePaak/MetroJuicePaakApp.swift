//
//  MetroJuicePaakApp.swift
//  MetroJuicePaak
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
        // Detect if we are running Unit Tests or UI Tests
        let isXCTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let isUITestingFlag = ProcessInfo.processInfo.arguments.contains("--uitesting")
        
        if isXCTestEnvironment || isUITestingFlag {
            #if DEBUG
            await initializeMockAudio()
            return
            #endif
        }
        
        // If not testing, boot the real audio engine
        await initializeRealAudio()
    }
    
    #if DEBUG
    @MainActor
    private func initializeMockAudio() async {
        print("🧪 Testing Mode Detected: Booting Mock Services...")
        do {
            let repository = AudioSampleRepository()
            let effectRegistry = EffectRegistry() // Safe to use the real registry, it's just a data structure
            
            // Inject the Mocks we built in MockServices.swift
            let mockAudioService = try await MockAudioService()
            let mockWaveformGenerator = MockWaveformGenerator()
            
            let editorFactory = EditorViewModelFactory(
                repository: repository,
                audioService: mockAudioService,
                waveformGenerator: mockWaveformGenerator,
                effectRegistry: effectRegistry
            )
            
            // We use the real MusicEngine but feed it the MockAudioService
            // so it never touches the real hardware AV layer
            let avEngine = AVAudioEngine()
            let timeProvider = AudioTimeProvider(audioEngine: avEngine)
            let musicEngine = MusicEngineImplementation(
                audioPlaybackService: mockAudioService,
                timeProvider: timeProvider
            )
            
            self.samplerOrchestrator = SamplerViewModel(
                repository: repository,
                audioService: mockAudioService,
                editorFactory: editorFactory,
                padViewModelGenerator: mockWaveformGenerator
            )
            
            self.sequencerViewModel = StepSequencerViewModel(
                repository: repository,
                musicEngine: musicEngine
            )
            
            print("🧪 Testing Mode: Mocks successfully injected. App ready for tests!")
            
        } catch {
            self.initializationError = error
            print("🛑 Mock Initialization failed: \(error.localizedDescription)")
        }
    }
    #endif
    
    @MainActor
    private func initializeRealAudio() async {
        print("🎙️ 1. Starting real audio initialization...")
        do {
            let repository = AudioSampleRepository()
            print("🎙️ 2. Repository created.")

            let effectRegistry = EffectRegistry()
            AppBootstrap.registerBuiltInEffects(into: effectRegistry)
            print("🎙️ 3. Effect registry populated with \(effectRegistry.allMetadata().count) effects.")

            DSPEffectAUBridge.registerOnce()
            print("🎙️ 4. DSPEffectAUBridge registered.")

            let audioService = try await AudioService(registry: effectRegistry)
            print("🎙️ 5. AudioService created.")

            let waveformGenerator = WaveformCache()
            print("🎙️ 6. Waveform generator created.")

            let editorFactory = EditorViewModelFactory(
                repository: repository,
                audioService: audioService,
                waveformGenerator: waveformGenerator,
                effectRegistry: effectRegistry
            )
            print("🎙️ 7. Editor view model factory built.")

            let avEngine = AVAudioEngine()
            let timeProvider = AudioTimeProvider(audioEngine: avEngine)
            let musicEngine = MusicEngineImplementation(
                audioPlaybackService: audioService,
                timeProvider: timeProvider
            )

            let samplerVM = SamplerViewModel(
                repository: repository,
                audioService: audioService,
                editorFactory: editorFactory,
                padViewModelGenerator: waveformGenerator
            )
            print("🎙️ 8. Sampler orchestrator built.")

            let sequencerVM = StepSequencerViewModel(
                repository: repository,
                musicEngine: musicEngine
            )
            print("🎙️ 9. Step Sequencer ViewModel built.")

            self.samplerOrchestrator = samplerVM
            self.sequencerViewModel = sequencerVM
            print("🎙️ 10. State updated! Switching to TabView.")

        } catch {
            self.initializationError = error
            print("🛑 Initialization failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Effect Bootstrap
enum AppBootstrap {
    static func registerBuiltInEffects(into registry: EffectRegistry) {
        registry.register(GainEffect.self)
        registry.register(LowpassEffect.self)
        registry.register(ReverbEffect.self)
    }
}

// MARK: - Error View
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
