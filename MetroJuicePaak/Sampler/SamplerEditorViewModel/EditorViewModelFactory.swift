//
//  EditorViewModelFactory.swift
//  MetroJuicePaak
//

import Foundation

/// Constructs view models for the sample editor screens.
///
/// Exists to keep the composition root's knowledge of child view model
/// dependencies out of `SamplerViewModel`. The orchestrator no longer
/// needs to hold `WaveformGenerationService` or `EffectRegistry` just
/// to pass them through to children — the factory owns that wiring.
final class EditorViewModelFactory {

    typealias RepositoryProtocols =
        ReadableAudioSampleRepository
        & EditableAudioSampleRepository
        & WaveformSourceAudioSampleRepository
        & EffectableAudioSampleRepository

    private let repository: RepositoryProtocols
    private let audioService: AudioServiceProtocol
    private let waveformGenerator: WaveformGenerationService
    private let effectRegistry: EffectRegistry

    init(repository: RepositoryProtocols,
         audioService: AudioServiceProtocol,
         waveformGenerator: WaveformGenerationService,
         effectRegistry: EffectRegistry) {
        self.repository = repository
        self.audioService = audioService
        self.waveformGenerator = waveformGenerator
        self.effectRegistry = effectRegistry
    }

    func makeSamplerEditor(for sampleID: ObjectIdentifier) -> SamplerEditorViewModel? {
        SamplerEditorViewModel(
            sampleID: sampleID,
            repository: repository,
            audioService: audioService,
            generator: waveformGenerator
        )
    }

    func makeEffectsEditor(for sampleID: ObjectIdentifier) -> EffectChainEditorViewModel? {
        EffectChainEditorViewModel(
            sampleId: sampleID,
            repository: repository,
            audioService: audioService,
            registry: effectRegistry
        )
    }
}
