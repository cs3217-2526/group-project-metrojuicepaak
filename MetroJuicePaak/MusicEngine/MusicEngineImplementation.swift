//
//  MusicEngineImpl.swift
//  MetroJuicePaak
//
//  Created by Edwin Wong on 04/04/2026.
//

import Foundation
import os

// MARK: - Time Provider Protocol

/// Abstracts audio time access from the MusicEngine
/// This allows MusicEngine to remain platform-agnostic and testable
protocol TimeProvider {
    /// Returns the current audio time in seconds since the audio engine started
    /// This should be monotonic and suitable for precise audio scheduling
    func getCurrentTime() -> TimeInterval
}

// MARK: - Music Engine Implementation

/// High-precision step sequencer engine that uses a lookahead scheduler
/// to guarantee glitch-free audio playback.
///
/// Architecture:
/// - Runs a background loop that ticks every ~50ms
/// - Calculates which 16th notes fall within the next 100ms lookahead window
/// - Schedules audio samples at exact TimeInterval timestamps
/// - Uses OSAllocatedUnfairLock for snapshot synchronization (not actor isolation)
///
/// Thread Safety:
/// - The engine's scheduler loop runs on a high-priority background thread
/// - Snapshot updates use OSAllocatedUnfairLock for minimal-overhead synchronization
/// - No async/await overhead - the protocol is synchronous for fire-and-forget semantics
///
/// Abstraction Boundaries:
/// - Does NOT import AVFoundation - completely platform-agnostic
/// - Works with TimeInterval (seconds) instead of AVAudioTime
/// - Audio scheduling details are hidden behind AudioPlaybackService protocol
final class MusicEngineImplementation: MusicEngine {
    
    // MARK: - Dependencies
    
    private let audioPlaybackService: AudioPlaybackService
    private let timeProvider: TimeProvider
    
    // MARK: - Snapshot State (Protected by OSAllocatedUnfairLock)
    
    /// Lock protecting snapshot access between main thread (writer) and timer thread (reader)
    /// OSAllocatedUnfairLock is the Swift 6-compatible replacement for os_unfair_lock
    private let snapshotLock = OSAllocatedUnfairLock<SequencerSnapshot?>(initialState: nil)
    
    // MARK: - Scheduler State (Timer thread only)
    
    /// Background timer that drives the lookahead scheduler
    private var schedulerTimer: DispatchSourceTimer?
    
    /// Tracks the last step we scheduled to prevent duplicate scheduling
    /// across multiple lookahead ticks
    private var lastScheduledStep: Int = -1
    
    /// Number of steps in the sequence (typically 16)
    private var stepCount: Int = 16
    
    /// Tracks whether the sequencer is currently running
    private var isRunning: Bool = false
    
    /// The audio time when the sequencer started (used as reference point)
    /// Stored in seconds (TimeInterval) not audio frames
    private var sequenceStartTime: TimeInterval = 0
    
    // MARK: - Configuration Constants
    
    /// How often the lookahead loop ticks (in seconds)
    private let lookaheadTickInterval: TimeInterval = 0.05 // 50ms
    
    /// How far ahead to schedule audio events (in seconds)
    private let lookaheadWindowSize: TimeInterval = 0.1 // 100ms
    
    /// Quality of service for the scheduler thread
    /// .userInteractive ensures the highest priority for real-time audio
    private let schedulerQoS: DispatchQoS = .userInteractive
    
    // MARK: - Initialization
    
    init(audioPlaybackService: AudioPlaybackService, timeProvider: TimeProvider) {
        self.audioPlaybackService = audioPlaybackService
        self.timeProvider = timeProvider
    }
    
    // MARK: - MusicEngine Protocol Implementation
    
    func startSequencer() {
        guard !isRunning else {
            return
        }
        
        isRunning = true
        lastScheduledStep = -1
        
        // Capture start time on the timer queue to avoid threading issues
        // We'll set it on the first tick
        sequenceStartTime = 0
        
        // Create and configure the high-priority scheduler timer
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: schedulerQoS.qosClass))
        
        timer.schedule(
            deadline: .now(),
            repeating: lookaheadTickInterval,
            leeway: .milliseconds(5)
        )
        
        timer.setEventHandler { [weak self] in
            self?.lookaheadTick()
        }
        
        schedulerTimer = timer
        timer.resume()
    }
    
    func stopSequencer() {
        guard isRunning else {
            return
        }
        
        isRunning = false
        
        schedulerTimer?.cancel()
        schedulerTimer = nil
        
        lastScheduledStep = -1
        sequenceStartTime = 0
    }
    
    func apply(snapshot: SequencerSnapshot) {
        // Synchronous write from main thread
        snapshotLock.withLock { $0 = snapshot }
        
        // Update step count (doesn't need lock - only read on timer thread after snapshot read)
        if let firstTrack = snapshot.tracks.values.first {
            stepCount = firstTrack.steps.count
        }
    }
    
    // MARK: - Snapshot Access
    
    /// Thread-safe snapshot read for the timer thread
    private func readSnapshot() -> SequencerSnapshot? {
        return snapshotLock.withLock { $0 }
    }
    
    // MARK: - Lookahead Scheduler Core
    
    /// The heartbeat of the sequencer.
    /// Called every ~50ms to calculate and schedule upcoming audio events.
    /// Runs on the high-priority timer queue.
    private func lookaheadTick() {
        guard isRunning else { return }
        
        // Step A: Read the State
        guard let snapshot = readSnapshot() else {
            return
        }
        
        let bpm = snapshot.bpm
        let tracks = snapshot.tracks
        
        // Step B: Calculate the Time Window
        let currentTime = timeProvider.getCurrentTime()
        
        // Initialize sequence start time on first tick
        if sequenceStartTime == 0 {
            sequenceStartTime = currentTime
        }
        
        // Calculate the lookahead window end time (in seconds)
        let windowEndTime = currentTime + lookaheadWindowSize
        
        // Step C: Determine Upcoming Steps
        let secondsPerBeat = 60.0 / bpm
        let secondsPerSixteenthNote = secondsPerBeat / 4.0
        
        // Find which steps fall within the lookahead window
        let upcomingSteps = calculateUpcomingSteps(
            currentTime: currentTime,
            windowEndTime: windowEndTime,
            secondsPerSixteenthNote: secondsPerSixteenthNote
        )
        
        // Step D: Track Evaluation & Scheduling
        for (stepIndex, absoluteStep, targetTime) in upcomingSteps {
            scheduleStep(
                stepIndex: stepIndex,
                absoluteStep: absoluteStep,
                targetTime: targetTime,
                tracks: tracks
            )
        }
    }
    
    /// Calculates which step indices fall within the current lookahead window
    /// Returns an array of (stepIndex, absoluteStep, targetTime) tuples
    private func calculateUpcomingSteps(
        currentTime: TimeInterval,
        windowEndTime: TimeInterval,
        secondsPerSixteenthNote: TimeInterval
    ) -> [(stepIndex: Int, absoluteStep: Int, targetTime: TimeInterval)] {
        
        var upcomingSteps: [(Int, Int, TimeInterval)] = []
        
        // Calculate elapsed time since sequence start
        let elapsedTime = currentTime - sequenceStartTime
        
        // Calculate which step we're currently on (relative to sequence start)
        let elapsedSteps = elapsedTime / secondsPerSixteenthNote
        let absoluteStepIndex = Int(floor(elapsedSteps))
        
        // Check several steps ahead to catch anything in the lookahead window
        for offset in 0...4 {
            let absoluteStep = absoluteStepIndex + offset
            let stepIndex = absoluteStep % stepCount
            
            // Skip if we've already scheduled this step
            if absoluteStep <= lastScheduledStep {
                continue
            }
            
            // Calculate the exact time when this step should fire
            let targetTime = sequenceStartTime + (Double(absoluteStep) * secondsPerSixteenthNote)
            
            // Check if this step falls within our lookahead window
            if targetTime >= currentTime && targetTime <= windowEndTime {
                upcomingSteps.append((stepIndex, absoluteStep, targetTime))
            }
            
            // Stop looking if we've gone past the window
            if targetTime > windowEndTime {
                break
            }
        }
        
        return upcomingSteps
    }
    
    /// Schedules all active tracks for a given step
    private func scheduleStep(
        stepIndex: Int,
        absoluteStep: Int,
        targetTime: TimeInterval,
        tracks: [UUID: EngineTrack]
    ) {
        
        // Iterate through all tracks
        for (_, track) in tracks {
            // Check for Audio Payload
            guard let sample = track.sample else {
                continue
            }
            
            // Check if Step is Active
            guard stepIndex < track.steps.count else {
                continue
            }
            
            guard track.steps[stepIndex] else {
                continue
            }
            
            // Schedule the Audio
            // The AudioPlaybackService handles the conversion to AVAudioTime internally
            audioPlaybackService.scheduleAt(sample, time: targetTime)
        }
        
        // Update last scheduled step to the absolute step index
        // This prevents re-scheduling the same step across multiple ticks
        lastScheduledStep = absoluteStep
    }
}
