//
//  SampleEditorViewModel.swift
//  MetroJuicePaak
//
//  Created by proglab on 28/3/26.
//

import Foundation
import Observation

/// Manages the transient state and business logic for the Waveform Editor UI.
///
/// This ViewModel acts as a "Memento". It reads the initial trim state from a provided
/// `AudioClipViewModel`, allows the user to freely manipulate temporary UI ratios, and
/// safely previews those changes without permanently mutating the underlying domain model.
/// Changes are only committed when `saveEdits()` is explicitly called.
@Observable
class SamplerWaveformEditorViewModel {
    
    // MARK: - Dependencies
    
    /// The active reference wrapper containing the actual `AudioSample` domain data.
    let clipNode: AudioClipViewModel
    
    /// The service responsible for routing preview audio to the device speakers.
    private let playbackService: AudioPlaybackService

    /// The session manager responsible for committing updates to the domain model and triggering UI refreshes.
    private let audioSampleRepoVM: AudioSampleRepositoryViewModel
    // MARK: - Transient State
    
    /// The temporary starting trim position, represented as a normalized ratio (0.0 to 1.0).
    /// Bound directly to the SwiftUI left drag handle.
    var tempStartRatio: Double
    
    /// The temporary ending trim position, represented as a normalized ratio (0.0 to 1.0).
    /// Bound directly to the SwiftUI right drag handle.
    var tempEndRatio: Double
    
    /// Tracks whether the preview audio is currently playing to update UI toggle states.
    var isPlayingPreview: Bool = false
    
    // MARK: - Initialization
    
    /// Initializes the editor with a specific audio clip and playback service.
    /// - Parameters:
    ///   - clipNode: The node containing the sample to edit.
    ///   - playbackService: The engine used to preview the trimmed audio.
    init(clipNode: AudioClipViewModel, playbackService: AudioPlaybackService, sessionManager: AudioSampleRepositoryViewModel) {
        self.clipNode = clipNode
        self.playbackService = playbackService
        self.audioSampleRepoVM = sessionManager
        
        // Hydrate the transient state from the immutable domain model
        self.tempStartRatio = clipNode.sample.startTimeRatio
        self.tempEndRatio = clipNode.sample.endTimeRatio
    }
    
    /// The total, untrimmed duration of the audio file in seconds.
    var totalDuration: TimeInterval {
        clipNode.sample.duration
    }
    
    // MARK: - Preview Playback
    
    /// Toggles the playback of the audio sample using the current temporary trim ratios.
    ///
    /// If playback is started, this function creates a disposable copy of the `AudioSample`,
    /// applies the transient ratios to it, and routes the fake sample to the playback engine.
    /// This prevents premature mutation of the actual saved sample.
    func togglePreview() async {
        if isPlayingPreview {
            await playbackService.stop(clipNode.sample)
            await MainActor.run { isPlayingPreview = false }
        } else {
            await MainActor.run { isPlayingPreview = true }
            
            // Create a fake, temporary sample strictly for preview routing
            var previewSample = clipNode.sample
            
            // Apply the transient ratios to the copy safely
            // try? is safe here as UI drag constraints prevent invalid ratio crossings
            try? previewSample.setStartTrimRatio(tempStartRatio)
            try? previewSample.setEndTrimRatio(tempEndRatio)
            
            await playbackService.play(previewSample, volume: 1.0, pan: 0.0)
        }
    }
    
    /// Safely halts playback if it is currently running.
    /// Typically called when the user grabs a drag handle to prevent conflicting audio.
    func stopIfPlaying() async {
        if isPlayingPreview {
            await playbackService.stop(clipNode.sample)
            await MainActor.run { isPlayingPreview = false }
        }
    }
    
    // MARK: - The Commit
    
    /// Validates and commits the transient trim ratios to the underlying domain model.
    ///
    /// Triggers a UI redraw of the high-resolution waveform thumbnail upon successful save.
    func saveEdits() {
        // 1. Pull the struct out into a local mutable copy
        var updatedSample = clipNode.sample
        
        // 2. Modify the local copy using the domain's strict validation rules
        do {
            try updatedSample.setStartTrimRatio(tempStartRatio)
            try updatedSample.setEndTrimRatio(tempEndRatio)
            
            // Let the Conductor handle the atomic update
            audioSampleRepoVM.updateSample(updatedSample)
            
            // Trigger the UI redraw
            Task { await clipNode.refreshThumbnail(uiWidth: 100) }
        } catch {
            print("❌ Failed to save trim edits: \(error.localizedDescription)")
        }
    }
}
