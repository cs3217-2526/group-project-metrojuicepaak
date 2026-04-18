//
//  EffectChainEditorViewModel.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 18/4/26.
//

import Foundation

@Observable
final class EffectChainEditorViewModel {

    private let effectable: EffectableAudioSample
    private let playable: PlayableAudioSample
    private let audioService: AudioServiceProtocol
    private let registry: EffectRegistry


    var isPlayingPreview: Bool = false
    
    // MARK: - Derived state for the UI

    /// The current chain, read directly from the domain model.
    /// Because AudioSample is @Observable, SwiftUI views that read this
    /// will re-render when the chain changes.
    var chain: [EffectInstanceDescriptor] {
        effectable.effectDescriptorChain
    }

    /// All registered effects grouped by category for the browser.
    var availableEffectsByCategory: [EffectCategory: [EffectMetadata]] {
        Dictionary(grouping: registry.allMetadata(), by: \.category)
    }

    init?(sampleId: ObjectIdentifier,
          repository: EffectableAudioSampleRepository & ReadableAudioSampleRepository,
          audioService: AudioServiceProtocol,
          registry: EffectRegistry,
) {

        guard let effectable = repository.getEffectableSample(for: sampleId),
              let playable = repository.getPlayableSample(for: sampleId) else {
            return nil
        }
        self.effectable = effectable
        self.playable = playable
        self.registry = registry
        self.audioService = audioService
    }
    
    // MARK: - Metadata lookup

    /// Returns the registry metadata for a given effect identifier.
    /// Used by the UI to get display names and parameter descriptors.
    func metadata(for effectIdentifier: String) -> EffectMetadata? {
        registry.allMetadata().first { $0.identifier == effectIdentifier }
    }

    // MARK: - Structural edits

    func addEffect(identifier: String) async throws {
        guard let meta = metadata(for: identifier) else { return }

        let defaults = Dictionary(
            uniqueKeysWithValues: meta.parameterDescriptors.map {
                ($0.id, $0.defaultValue)
            }
        )

        let descriptor = EffectInstanceDescriptor(
            effectIdentifier: identifier,
            parameterValues: defaults
        )

        // 1. Mutate the domain model.
        try effectable.addEffect(descriptor)

        // 2. Engine reads the updated chain from the sample directly.
        try await audioService.rebuildEffectChain(for: effectable)
    }

    func removeEffect(instanceId: UUID) async throws {
        effectable.removeEffect(instanceId: instanceId)
        try await audioService.rebuildEffectChain(for: effectable)
    }

    func moveEffect(from: Int, to: Int) async throws {
        effectable.moveEffect(from: from, to: to)
        try await audioService.rebuildEffectChain(for: effectable)
    }

    func toggleBypass(instanceId: UUID) async throws {
        effectable.toggleBypass(instanceId: instanceId)
        try await audioService.rebuildEffectChain(for: effectable)
    }

    // MARK: - Live parameter updates

    func setParameterLive(effectInstanceId: UUID,
                          parameterId: String,
                          value: Float) {
        audioService.updateEffectParameter(
            for: effectable,
            effectInstanceId: effectInstanceId,
            parameterId: parameterId,
            value: value
        )
    }

    /// To save edits to the actual AudioSample
    func commitParameter(effectInstanceId: UUID,
                         parameterId: String,
                         value: Float) {
        effectable.updateParameter(
            instanceId: effectInstanceId,
            parameterId: parameterId,
            value: value
        )
    }
    
    // MARK: - Preview playback
    
    func togglePreview() async {
        if isPlayingPreview {
            await audioService.stop(playable)
            isPlayingPreview = false
        } else {
            await audioService.play(playable)
            isPlayingPreview = true
        }
    }

    func stopPreview() async {
        if isPlayingPreview {
            await audioService.stop(playable)
            isPlayingPreview = false
        }
    }
}
