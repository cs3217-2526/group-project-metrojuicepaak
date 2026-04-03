//
//  AudioClipViewModel.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 4/4/26.
//

import Foundation
import Observation

/// The granular "Worker" node that wraps exactly one AudioSample.
///
/// By giving each sample its own @Observable wrapper, SwiftUI can subscribe
/// to individual clips. Trimming "Untitled 2" only re-renders views that
/// observe this specific instance — pads holding other clips are untouched.
///
/// Instances are created and cached by AudioSampleRepositoryViewModel (the Conductor).
/// Never create one directly; always go through the Conductor's factory method.
@Observable
final class AudioClipViewModel {

    // ─────────────────────────────────────────
    // MARK: - State
    // ─────────────────────────────────────────

    /// The pure data for this clip. Mutating this (trim, rename) triggers re-renders
    /// only in views that observe this specific node.
    var sample: AudioSample

    /// Waveform thumbnail, nil until refreshThumbnail is called.
    private(set) var thumbnailData: WaveformData?

    private let generator: any WaveformGenerationService

    // ─────────────────────────────────────────
    // MARK: - Init
    // ─────────────────────────────────────────

    init(sample: AudioSample, generator: any WaveformGenerationService) {
        self.sample = sample
        self.generator = generator
    }

    // ─────────────────────────────────────────
    // MARK: - Waveform
    // ─────────────────────────────────────────

    /// Regenerates the thumbnail at the given pixel width.
    ///
    /// It is the responsibility of holders of the AudioClipViewModel
    /// to call this after view is loaded, a trim is saved or a DSP effect is applied,
    /// so the waveform reflects the current trim region or
    /// DSP effected waveform at the correct resolution.
    func refreshThumbnail(uiWidth: Int) async {
        thumbnailData = await generator.generateWaveform(for: sample, resolution: uiWidth)
    }
}
