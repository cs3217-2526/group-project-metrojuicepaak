//
//  AudioTimeConverter.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 15/04/2026.
//

import Foundation
import AVFoundation

/// A pure utility for converting between human-readable seconds and hardware clock ticks.
struct AudioTimeConverter {
    
    /// Converts a precise TimeInterval (seconds) back into a CPU mach_absolute_time tick.
    static func hostTimeFrom(timeInterval: TimeInterval) -> UInt64 {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        
        let nanoseconds = timeInterval * 1_000_000_000.0
        let hostTime = UInt64(nanoseconds) * UInt64(timebase.denom) / UInt64(timebase.numer)
        
        return hostTime
    }
}
