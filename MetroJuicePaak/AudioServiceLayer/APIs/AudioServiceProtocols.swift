//
//  AudioServiceProtocols.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 3/4/26.
//

import Foundation

/// Combined protocol that AudioService should conform to
/// This provides the complete audio engine API
protocol AudioServiceProtocol:
    AudioPlaybackService,
    AudioRecordingService,
    AudioConfigurationService {
    
    /// Initializes the audio service
    /// - Throws: If initialization fails
    init() async throws
}
