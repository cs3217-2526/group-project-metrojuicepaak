//
//  PlayBackService.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 13/4/26.
//

import Foundation

/// Protocol for audio playback operations
/// Handles loading, playing, and stopping audio samples
protocol AudioPlaybackService {
    
    /// Loads an audio sample into memory for playback
    /// Call this before attempting to play a sample
    /// - Parameters:
    ///   - sample: The AudioSample to load
    ///   - polyphony: The number of concurrent voices the audio sample will be allowed to have at once
    ///
    /// - Throws: If audio file cannot be loaded or is corrupted
    func load(sample: PlayableAudioSample, polyphony: Int) async throws
    
    /// Unloads an audio sample from memory
    /// Call this when a sample is no longer needed to free resources
    /// - Parameter sample: The AudioSample to unload
    func unload(_ sample: PlayableAudioSample) async
    
    /// Plays a sample, interrupting any current playback of the same sample.
    ///
    /// - Parameter onCompletion: Fires on MainActor when playback ends — either
    ///   by reaching the end of the buffer, by a matching ``stop(_:)`` call, or
    ///   by being interrupted by a subsequent `play` for the same sample.
    ///
    /// - Important: UI flows that toggle a button between "play" and "stop"
    ///   (e.g. the editor preview buttons) MUST pass a completion handler to
    ///   flip their state back. Without it, a button bound to an `isPlaying`
    ///   flag stays stuck in the "playing" state after the sample finishes
    ///   naturally. Use ``playOverlapping(_:)`` when no completion signal is
    ///   needed.
    ///
    /// - Note: The handler fires exactly once per call. Stale completions from
    ///   a superseded session can still land after a rapid stop-then-play —
    ///   call sites that toggle rapidly should guard against stale state
    ///   (see `previewGeneration` in `EffectChainEditorViewModel`).
    func play(_ sample: PlayableAudioSample,
              onCompletion: (@Sendable @MainActor () -> Void)?) async
    
    /// Plays a loaded audio sample
    /// If the audio sample is already playing,
    /// this immediately plays the audio sample again,
    /// overlapping with the currently playing audio sample.
    ///
    /// If more overlapping playbacks are happening
    /// than the polyphony that this AudioSample was loaded with,
    /// voice-stealing will occur, which is where the most recent playOverlapping()
    /// call will stop playing the least recent's call immediately in order to
    /// immediately start playing.
    /// - Parameter sample: The AudioSample to play. If the sample
    ///     is not loaded, this call is a no-op.
    func playOverlapping(_ sample: PlayableAudioSample,
                         onCompletion: (@Sendable @MainActor () -> Void)?) async
    
    /// Returns the current time in seconds on the host timeline.
    /// Use this as the reference point for `scheduleAt` times.
    var currentHostTime: TimeInterval { get }
    
    /// Schedules a loaded audio sample for playback
    /// at the specified absolute time on the host timeline.
    ///
    /// Playback overlaps with any currently playing voices
    /// of the same sample. If the number of concurrent voices
    /// exceeds the polyphony this sample was loaded with,
    /// the least recently scheduled voice is stolen.
    ///
    /// This method is synchronous and safe to call
    /// from time-critical contexts.
    ///
    /// To use this sample-accurately, you should first
    /// snapshot the current host time using currentTime.
    /// Then you compute the time you want to schedule a playback with pure arithmetic.
    ///
    /// - Parameters:
    ///   - sample: The AudioSample to play. If the sample
    ///     is not loaded, this call is a no-op.
    ///   - time: Absolute time in seconds on the host timeline,
    ///     as returned by `AVAudioTime.seconds`.
    ///     If `time` is in the past, the event is silently dropped.
    func scheduleAt(_ sample: PlayableAudioSample,
                    time: TimeInterval,
                    onCompletion: (@Sendable @MainActor () -> Void)?)
    
    /// Stops playback of a specific sample
    /// - Parameter sample: The AudioSample to stop
    func stop(_ sample: PlayableAudioSample) async
    
    /// Stops all currently playing audio
    func stopAll() async
    
    /// Checks if a sample is currently loaded in memory
    /// - Parameter sample: The AudioSample to check
    /// - Returns: true if loaded, false otherwise
    func isLoaded(_ sample: PlayableAudioSample) -> Bool
    
    /// Checks if a sample is currently playing
    /// - Parameter sample: The AudioSample to check
    /// - Returns: true if playing, false otherwise
    func isPlaying(_ sample: PlayableAudioSample) -> Bool
}
