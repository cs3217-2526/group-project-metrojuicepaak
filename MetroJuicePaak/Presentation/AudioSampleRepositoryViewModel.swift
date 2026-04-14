////
////  AudioSampleRepositoryViewModel.swift
////  MetroJuicePaak
////
////  Created by Noah Ang Shi Hern on 4/4/26.
////
//
//import Foundation
//import Observation
//
///// The global session manager ("The Conductor") sitting above the Sampler and Step Sequencer.
/////
///// Responsibilities:
/////   1. Owns the AudioSampleRepository (the pure data pool).
/////   2. Maintains a one-to-one cache of AudioClipViewModel instances keyed by UUID,
/////      guaranteeing that every consumer (a sampler pad, a sequencer track) that
/////      references the same sample shares the exact same wrapper object.
/////      The SamplePickerView reads `allClipNodes` to let the user browse and select;
/////      consumers store the returned reference directly.
/////   3. Propagates mutations (trim, rename, delete) atomically to both the data pool
/////      and the live wrappers so no caller needs to touch the repository directly.
//@Observable
//final class AudioSampleRepositoryViewModel {
//
//    // ─────────────────────────────────────────
//    // MARK: - State
//    // ─────────────────────────────────────────
//
//    /// The canonical data pool. Read by child ViewModels (e.g. for a sample picker list).
//    private(set) var repository: AudioSampleRepository
//
//    /// Flyweight cache — at most one AudioClipViewModel per UUID in the pool.
//    private var activeAudioSamples: [ObjectIdentifier: AudioSample] = [:]
//
//    private let generator: any WaveformGenerationService
//
//    // ─────────────────────────────────────────
//    // MARK: - Init
//    // ─────────────────────────────────────────
//
//    init(generator: any WaveformGenerationService) {
//        self.repository = AudioSampleRepository()
//        self.generator = generator
//    }
//
//    // ─────────────────────────────────────────
//    // MARK: - Clip Node Access
//    // ─────────────────────────────────────────
//
//    /// All live clip nodes, sorted by sample name.
//    /// This is the list the SamplePickerView displays.
//    var allClipNodes: [NamedAudioSample & WaveformSource] {
//        repository.allSamples.sorted(by: \.name)
//    }
//
//    // ─────────────────────────────────────────
//    // MARK: - Recording
//    // ─────────────────────────────────────────
//
//    /// Processes a completed recording: names the sample, stores it in the pool,
//    /// and immediately creates and caches its AudioClipViewModel.
//    ///
//    /// - Returns: The new AudioClipViewModel, ready to be handed to the requesting pad/track.
//    @discardableResult
//    func addNewRecording(result: RecordingResult) -> AudioClipViewModel {
//        let sample = repository.addSample(from: result)
//        let node = AudioClipViewModel(sample: sample, generator: generator)
//        activeClipNodes[sample.id] = node
//        return node
//    }
//
//    // ─────────────────────────────────────────
//    // MARK: - Mutations
//    // ─────────────────────────────────────────
//
//    /// Propagates a trim or rename to both the data pool and the live clip node.
//    ///
//    /// Because all features share the same AudioClipViewModel instance,
//    /// updating `node.sample` here triggers a re-render in every view observing it.
//    func updateSample(_ sample: AudioSample) {
//        repository.updateSample(sample)
//        activeClipNodes[sample.id]?.sample = sample
//    }
//
//    /// Removes a sample from the pool and evicts its wrapper from the cache.
//    ///
//    /// After this call, any feature holding a reference to the evicted
//    /// AudioClipViewModel should treat it as stale and nil out its reference.
//    func removeSample(id: UUID) {
//        repository.removeSample(id: id)
//        activeClipNodes.removeValue(forKey: id)
//    }
//}
