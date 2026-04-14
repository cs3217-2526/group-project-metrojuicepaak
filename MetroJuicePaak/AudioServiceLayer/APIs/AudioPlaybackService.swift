//
//  AudioPlaybackService.swift
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
    
    /// Plays a loaded audio sample
    /// If the audio sample is already playing,
    /// this stops the currently playing audio sample and
    /// immediately plays it again from the start
    /// - Parameter sample: The AudioSample to play (must be loaded first)
    func play(_ sample: PlayableAudioSample) async
    
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
    /// - Parameter sample: The AudioSample to play (must be loaded first)
    func playOverlapping(_ sample: PlayableAudioSample) async
    
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

/// Result of a recording session
struct RecordingResult {
    /// Absolute URL to the recorded file (AudioService creates this)
    let url: URL
    
    /// Duration of the recording in seconds
    let duration: TimeInterval
}
