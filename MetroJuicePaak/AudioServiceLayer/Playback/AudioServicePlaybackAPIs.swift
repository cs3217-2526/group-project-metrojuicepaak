//
//  AudioServicePlaybackAPIs.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 24/3/26.
//

import AVFoundation

// AudioService.swift - Add playback APIs
extension AudioService {
    
    // MARK: - Playback Management
    
    /// Loads an audio file for later playback
    /// This will be slow due to file reading, so call this as early as you can before playing
    /// - Parameters:
    ///   - url: The file URL to load
    ///   - identifier: A unique identifier for this audio (e.g., pad ID or sample sound name)
    func loadAudio(from url: URL, identifier: String) async throws {
        try audioEngine.loadAudioFile(id: identifier, url: url)
    }
    
    /// Plays a previously loaded audio file
    /// - Parameters:
    ///   - identifier: The identifier of the audio to play
    ///   - volume: Playback volume (0.0 to 1.0)
    ///   - pan: Stereo pan (-1.0 left to 1.0 right)
    func playAudio(identifier: String, volume: Float = 1.0, pan: Float = 0.0) async {
        audioEngine.playAudioFile(id: identifier, volume: volume, pan: pan)
    }
    
    /// Stops playback of a specific audio file
    func stopAudio(identifier: String) async {
        audioEngine.stopPlayingFile(id: identifier)
    }
    
    /// Stops all audio playback
    func stopAllAudio() async {
        audioEngine.stopPlayingAllFiles()
    }
    
    /// Convenience: Load and immediately play
    /// WARNING: This will be slow due to file reading, so try to use loadAudio first and then playAudio to avoid latency
    func loadAndPlay(from url: URL, identifier: String, volume: Float = 1.0, pan: Float = 0.0) async throws {
        try await loadAudio(from: url, identifier: identifier)
        await playAudio(identifier: identifier, volume: volume, pan: pan)
    }
}
