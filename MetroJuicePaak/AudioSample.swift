//
//  AudioSample.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 22/3/26.
//

import Foundation

struct AudioSample: Codable, Equatable {
    
    // ─────────────────────────────────────────
    // Identity
    // ─────────────────────────────────────────
    
    let id: UUID
    
    /// Relative filename stored in app's Documents directory
    /// (e.g., "A1B2C3D4.m4a")
    /// NEVER store absolute URLs - iOS randomizes sandbox paths on each launch
    /// AudioService reconstructs the full path at runtime
    let filename: String
    
    /// User-facing name for this sample
    /// Can be changed at any time without affecting identity
    var name: String
    
    // ─────────────────────────────────────────
    // Immutable after construction
    // Used for both playback range validation
    // and DSP effect processing — effects such
    // as reverb tail extension or time-stretching
    // depend on the full sample duration to
    // compute buffer sizes and delay lines correctly
    // ─────────────────────────────────────────
    
    let duration: TimeInterval
    
    // ─────────────────────────────────────────
    // Mutable trim state
    // Stored internally as TimeInterval for
    // precision — exposed externally as
    // normalised ratios so callers have no
    // knowledge of duration or sample rates
    // ─────────────────────────────────────────
    
    private var _startTimeRatio: Double
    private var _endTimeRatio: Double
    
    // ─────────────────────────────────────────
    // Initialisation
    // ─────────────────────────────────────────
    
    /// Creates a new AudioSample
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - filename: Relative filename in Documents directory (e.g., "recording.m4a")
    ///   - duration: Total duration in seconds
    ///   - name: User-facing name (should be provided by AudioSampleRepository for proper numbering)
    init(id: UUID = UUID(), filename: String, duration: TimeInterval, name: String) {
        self.id = id
        self.filename = filename
        self.duration = duration
        self.name = name
        self._startTimeRatio = 0
        self._endTimeRatio = 1
    }
    
    // ─────────────────────────────────────────
    // Ratio accessors
    // These are what all callers use —
    // AudioService converts to TimeInterval
    // internally using duration
    // ─────────────────────────────────────────
    
    var startTimeRatio: Double {
        _startTimeRatio
    }
    
    var endTimeRatio: Double {
        _endTimeRatio
    }
    
    // ─────────────────────────────────────────
    // Convenience time accessors
    // Computed from ratios × duration
    // Useful for UI labels or debugging —
    // AudioService should use ratios directly
    // to slice PCM buffers by frame count
    // ─────────────────────────────────────────
    
    var startTime: TimeInterval { _startTimeRatio * duration }
    var endTime: TimeInterval { _endTimeRatio * duration }
    
    var trimDuration: TimeInterval {
        endTime - startTime
    }
    
    // ─────────────────────────────────────────
    // Trim operations
    // All take normalised 0-1 ratios —
    // AudioSample converts to TimeInterval
    // internally, callers never deal with
    // duration or frame arithmetic
    // ─────────────────────────────────────────
    
    enum TrimError: Error, LocalizedError {
        case invalidStartRatio(Double)
        case invalidEndRatio(Double)
        case startExceedsEnd
        
        var errorDescription: String? {
            switch self {
            case .invalidStartRatio(let ratio):
                return "Start ratio \(ratio) must be in range [0.0, 1.0)"
            case .invalidEndRatio(let ratio):
                return "End ratio \(ratio) must be in range (0.0, 1.0]"
            case .startExceedsEnd:
                return "Start trim cannot exceed end trim"
            }
        }
    }
    
    mutating func setStartTrimRatio(_ ratio: Double) throws {
        guard ratio >= 0, ratio < 1 else {
            throw TrimError.invalidStartRatio(ratio)
        }
        guard ratio < _endTimeRatio else {
            throw TrimError.startExceedsEnd
        }
        _startTimeRatio = ratio
    }
    
    mutating func setEndTrimRatio(_ ratio: Double) throws {
        guard ratio > 0, ratio <= 1 else {
            throw TrimError.invalidEndRatio(ratio)
        }
        guard ratio > _startTimeRatio else {
            throw TrimError.startExceedsEnd
        }
        _endTimeRatio = ratio
    }
    
    mutating func resetToStart() {
        _startTimeRatio = 0
    }
    
    mutating func resetToEnd() {
        _endTimeRatio = 1
    }
    
    // ─────────────────────────────────────────
    // Computed properties
    // ─────────────────────────────────────────
    
    var isTrimmed: Bool {
        _startTimeRatio > 0 || _endTimeRatio < 1
    }
    
    /// Convenience identifier for AudioService
    /// Uses UUID string as the playback identifier
    var identifier: String {
        id.uuidString
    }
}
