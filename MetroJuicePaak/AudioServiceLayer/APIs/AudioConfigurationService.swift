//
//  AudioConfigurationService.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 3/4/26.
//

/// Protocol for managing audio session configuration
protocol AudioConfigurationService {
    
    /// Configures the audio session for playback and recording
    /// Should be called during app initialization
    /// - Throws: If audio session configuration fails
    func configureAudioSession() throws
    
    /// Sets the master output volume
    /// - Parameter volume: Volume level (0.0 to 1.0)
    func setMasterVolume(_ volume: Float)
    
    /// Gets the current master volume
    var masterVolume: Float { get }
    
    /// Enables or disables audio ducking (lowering volume when other audio plays)
    /// - Parameter enabled: true to enable ducking, false to disable
    func setDuckingEnabled(_ enabled: Bool)
}
