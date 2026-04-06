//
//  AudioPlaybackService.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 3/4/26.
//

import Foundation

/// Protocol for audio playback operations
/// Handles loading, playing, and stopping audio samples
protocol AudioPlaybackService {
    
    /// Loads an audio sample into memory for playback
    /// Call this before attempting to play a sample
    /// - Parameter sample: The AudioSample to load
    /// - Throws: If audio file cannot be loaded or is corrupted
    func load(_ sample: AudioSample) async throws
    
    /// Unloads an audio sample from memory
    /// Call this when a sample is no longer needed to free resources
    /// - Parameter sample: The AudioSample to unload
    func unload(_ sample: AudioSample) async
    
    /// Plays a loaded audio sample with optional parameters
    /// - Parameters:
    ///   - sample: The AudioSample to play (must be loaded first)
    ///   - volume: Playback volume (0.0 to 1.0), defaults to 1.0
    ///   - pan: Stereo pan (-1.0 left to 1.0 right), defaults to 0.0 (center)
    func play(_ sample: AudioSample, volume: Float, pan: Float) async
    
    /// Stops playback of a specific sample
    /// - Parameter sample: The AudioSample to stop
    func stop(_ sample: AudioSample) async
    
    /// Stops all currently playing audio
    func stopAll() async
    
    /// Checks if a sample is currently loaded in memory
    /// - Parameter sample: The AudioSample to check
    /// - Returns: true if loaded, false otherwise
    func isLoaded(_ sample: AudioSample) -> Bool
    
    /// Checks if a sample is currently playing
    /// - Parameter sample: The AudioSample to check
    /// - Returns: true if playing, false otherwise
    func isPlaying(_ sample: AudioSample) -> Bool
}
