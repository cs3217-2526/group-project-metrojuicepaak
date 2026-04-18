import Foundation
import Observation

/// Identifiable wrapper for triggering the Sampler Editor modal.
struct EditContext: Identifiable {
    let id: ObjectIdentifier
}

/// Identifiable wrapper for triggering the Sample Picker modal.
struct PickerContext: Identifiable {
    let id: Int
}

/// The central orchestrator for the MetroJuicePaak drum machine.
///
/// Holds the pad-to-sample mapping, routes tap gestures, and manages
/// recording lifecycle. It no longer owns the dependencies needed to
/// construct editor view models — that responsibility belongs to
/// `EditorViewModelFactory`, which is injected alongside.
@Observable
final class SamplerViewModel {

    // MARK: - Dependencies

    typealias SamplerRepositoryProtocols =
        WritableAudioSampleRepository
        & ReadableAudioSampleRepository

    let repository: SamplerRepositoryProtocols
    private let audioService: AudioServiceProtocol
    private let editorFactory: EditorViewModelFactory
    private let padViewModelGenerator: WaveformGenerationService

    // MARK: - Core State

    var padAssignments: [Int: ObjectIdentifier] = [:]
    var isRecordingPadIndex: Int? = nil

    @ObservationIgnored
    private var padViewModelCache: [Int: SamplerPadViewModel] = [:]

    // MARK: - Global Interaction State

    var isEditMode: Bool = false {
        didSet {
            if isEditMode {
                Task { await audioService.stopAll() }
            }
        }
    }

    // MARK: - Navigation State

    var sampleIDToEdit: EditContext? = nil
    var padIndexAwaitingAssignment: PickerContext? = nil

    // MARK: - Initialization

    init(repository: SamplerRepositoryProtocols
               & WaveformSourceAudioSampleRepository,
         audioService: AudioServiceProtocol,
         editorFactory: EditorViewModelFactory,
         padViewModelGenerator: WaveformGenerationService) {
        self.repository = repository
        self.audioService = audioService
        self.editorFactory = editorFactory
        self.padViewModelGenerator = padViewModelGenerator
    }

    // MARK: - Pad UI Factory

    func getViewModel(for padIndex: Int) -> SamplerPadViewModel? {
        guard let sampleID = padAssignments[padIndex] else {
            padViewModelCache.removeValue(forKey: padIndex)
            return nil
        }

        if let existingVM = padViewModelCache[padIndex],
           existingVM.sampleID == sampleID {
            return existingVM
        }

        guard let repositoryForPad = repository as? (SamplerRepositoryProtocols
                                                     & WaveformSourceAudioSampleRepository)
        else {
            return nil
        }

        let newVM = SamplerPadViewModel(
            sampleID: sampleID,
            repository: repositoryForPad,
            generator: padViewModelGenerator
        )
        padViewformCache(for: padIndex, vm: newVM)
        return newVM
    }

    private func padViewformCache(for padIndex: Int, vm: SamplerPadViewModel) {
        padViewModelCache[padIndex] = vm
    }

    // MARK: - Editor View Model Factories (delegated)

    func getEditorViewModel(for sampleID: ObjectIdentifier) -> SamplerEditorViewModel? {
        editorFactory.makeSamplerEditor(for: sampleID)
    }

    func getEffectsEditorViewModel(for sampleID: ObjectIdentifier) -> EffectChainEditorViewModel? {
        editorFactory.makeEffectsEditor(for: sampleID)
    }

    // MARK: - Interaction Routing

    func handlePadTap(padIndex: Int) {
        if isEditMode {
            if let assignedID = padAssignments[padIndex] {
                sampleIDToEdit = EditContext(id: assignedID)
            } else {
                padIndexAwaitingAssignment = PickerContext(id: padIndex)
            }
        } else {
            Task { await playPad(padIndex: padIndex) }
        }
    }

    // MARK: - Playback Flow

    func playPad(padIndex: Int) async {
        guard let sampleID = padAssignments[padIndex],
              let playableSample = repository.getPlayableSample(for: sampleID) else { return }

        await audioService.playOverlapping(playableSample)
    }

    // MARK: - Recording Flow

    func startRecording(on padIndex: Int) async {
        guard !audioService.isRecording else { return }
        do {
            let started = try await audioService.startRecording(settings: nil)
            if started { isRecordingPadIndex = padIndex }
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording(on padIndex: Int) async {
        isRecordingPadIndex = nil
        guard let result = await audioService.stopRecording() else { return }

        let newSampleID = repository.addSample(url: result.url)
        padAssignments[padIndex] = newSampleID

        if let playableSample = repository.getPlayableSample(for: newSampleID) {
            do {
                try await audioService.load(sample: playableSample, polyphony: 6)
            } catch {
                print("Failed to load sample into engine: \(error)")
            }
        }
    }

    // MARK: - Helper Methods

    func assignSample(_ sampleID: ObjectIdentifier, toPad padIndex: Int) {
        padAssignments[padIndex] = sampleID
        Task {
            if let playable = repository.getPlayableSample(for: sampleID) {
                do {
                    try await audioService.load(sample: playable, polyphony: 6)
                } catch {
                    print("Failed to load picked sample: \(error.localizedDescription)")
                }
            }
        }
    }
}
