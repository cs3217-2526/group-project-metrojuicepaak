//
//  AudioTimeProvider.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 04/04/2026.
//

import Foundation
import AVFoundation

/// AVFoundation-based implementation of TimeProvider
/// Provides high-precision audio time from the audio engine
final class AudioTimeProvider: TimeProvider {
    
    private let audioEngine: AVAudioEngine
    
    init(audioEngine: AVAudioEngine) {
        self.audioEngine = audioEngine
    }
    
    func getCurrentTime() -> TimeInterval {
        // Get the last render time (most accurate for scheduling)
        if let lastRenderTime = audioEngine.mainMixerNode.lastRenderTime,
           lastRenderTime.isSampleTimeValid {
            return timeIntervalFrom(audioTime: lastRenderTime)
        }
        
        // Fallback: use the output node's last render time
        if let lastRenderTime = audioEngine.outputNode.lastRenderTime,
           lastRenderTime.isSampleTimeValid {
            return timeIntervalFrom(audioTime: lastRenderTime)
        }
        
        // Last resort: use host time
        // This should rarely happen if the engine is running
        return timeIntervalFrom(hostTime: mach_absolute_time())
    }
    
    // MARK: - Helper Methods
    
    /// Converts AVAudioTime to TimeInterval (seconds)
    private func timeIntervalFrom(audioTime: AVAudioTime) -> TimeInterval {
        guard audioTime.isSampleTimeValid else {
            return timeIntervalFrom(hostTime: audioTime.hostTime)
        }
        
        // Convert sample time to seconds
        return Double(audioTime.sampleTime) / audioTime.sampleRate
    }
    
    /// Converts mach host time to TimeInterval
    private func timeIntervalFrom(hostTime: UInt64) -> TimeInterval {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        
        let nanoseconds = hostTime * UInt64(timebase.numer) / UInt64(timebase.denom)
        return Double(nanoseconds) / 1_000_000_000.0
    }
}

/// Mock implementation for testing
final class MockTimeProvider: TimeProvider {
    private var currentTime: TimeInterval = 0
    
    func getCurrentTime() -> TimeInterval {
        return currentTime
    }
    
    /// Manually advance time (for testing)
    func advance(by interval: TimeInterval) {
        currentTime += interval
    }
    
    /// Reset time to zero
    func reset() {
        currentTime = 0
    }
}
