//
//  RecordingResult.swift
//  MetroJuicePaak
//
//  Created by proglab on 3/4/26.
//

import Foundation

/// Result of a recording session
struct RecordingResult {
    /// Absolute URL to the recorded file (AudioService creates this)
    let url: URL
    
    /// Duration of the recording in seconds
    let duration: TimeInterval
    
    /// Relative filename for storage (extracted from URL)
    var filename: String {
        url.lastPathComponent
    }
}
