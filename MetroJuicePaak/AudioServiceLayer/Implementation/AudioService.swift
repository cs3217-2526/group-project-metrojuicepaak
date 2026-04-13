//
//  AudioService.swift
//  MetroJuicePaak
//

import Foundation
import AVFoundation
import os

enum AudioServiceError: Error {
    case recordPermissionDenied
    case audioSessionConfigureFailed
    case recordingFailed
    case noActiveRecording
}

class AudioService: AudioServiceProtocol {

    private let audioSession: AVAudioSession
    internal let audioApplication = AVAudioApplication.shared
    internal let audioEngine = AudioEngine()
    internal var activeRecorder: AVAudioRecorder?
    private var _masterVolume: Float = 1.0
    private let logger = Logger(subsystem: "MetroJuicePaak", category: "AudioService")

    required init() async throws {
        self.audioSession = AVAudioSession.sharedInstance()
        try await configureAudioApplication()
        do {
            try configureAudioSession()
        } catch {
            logger.error("Failed to configure audio session: \(error)")
        }
    }

    // MARK: - AudioConfigurationService

    func configureAudioSession() throws {
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker]
        )
        try audioSession.setActive(true)
        logger.info("Audio session configured — category: \(self.audioSession.category.rawValue)")
    }

    var masterVolume: Float { _masterVolume }

    func setMasterVolume(_ volume: Float) {
        _masterVolume = volume
        logger.debug("Master volume set to \(volume)")
    }

    func setDuckingEnabled(_ enabled: Bool) {
        let options: AVAudioSession.CategoryOptions = enabled
            ? [.defaultToSpeaker, .duckOthers]
            : [.defaultToSpeaker]
        try? audioSession.setCategory(.playAndRecord, mode: .default, options: options)
        logger.debug("Audio ducking \(enabled ? "enabled" : "disabled")")
    }

    // MARK: - AudioPlaybackService

    func load(sample: PlayableAudioSample, polyphony: Int = 6) async throws {
        try audioEngine.load(sample: sample, polyphony: polyphony)
    }

    func unload(_ sample: PlayableAudioSample) async {
        audioEngine.unload(sample)
    }

    func play(_ sample: PlayableAudioSample) async {
        audioEngine.play(sample)
    }

    func playOverlapping(_ sample: PlayableAudioSample) async {
        audioEngine.playOverlapping(sample)
    }

    func stop(_ sample: PlayableAudioSample) async {
        audioEngine.stop(sample)
    }

    func stopAll() async {
        audioEngine.stopAll()
    }

    func isLoaded(_ sample: PlayableAudioSample) -> Bool {
        audioEngine.isLoaded(sample)
    }

    func isPlaying(_ sample: PlayableAudioSample) -> Bool {
        audioEngine.isPlaying(sample)
    }

    // MARK: - AudioRecordingService

    var isRecording: Bool {
        activeRecorder?.isRecording ?? false
    }

    var recordingDuration: TimeInterval {
        activeRecorder?.currentTime ?? 0
    }

    func startRecording(settings: RecordingSettings?) async throws -> Bool {
        let config = settings ?? .default
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        return try await startRecording(url: url, settings: config)
    }

    func startRecording(url: URL) async throws -> Bool {
        try await startRecording(url: url, settings: .default)
    }

    func stopRecording() async -> RecordingResult? {
        guard let recorder = activeRecorder, recorder.isRecording else {
            logger.warning("stopRecording() called with no active recording")
            return nil
        }
        let duration = recorder.currentTime
        let url = recorder.url
        recorder.stop()
        activeRecorder = nil
        logger.info("Recording stopped — duration: \(duration)s, file: \(url.lastPathComponent)")
        return RecordingResult(url: url, duration: duration)
    }

    // MARK: - Private

    private func configureAudioApplication() async throws {
        switch audioApplication.recordPermission {
        case .undetermined:
            logger.info("Requesting microphone permission")
            let granted = await AVAudioApplication.requestRecordPermission()
            if !granted { throw AudioServiceError.recordPermissionDenied }
        case .denied:
            logger.error("Microphone permission denied")
            throw AudioServiceError.recordPermissionDenied
        case .granted:
            logger.debug("Microphone permission already granted")
        @unknown default:
            throw AudioServiceError.recordPermissionDenied
        }
    }

    private func startRecording(url: URL, settings config: RecordingSettings) async throws -> Bool {
        let quality: AVAudioQuality
        switch config.quality {
        case .high:   quality = .high
        case .medium: quality = .medium
        case .low:    quality = .low
        }

        let avSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: config.sampleRate,
            AVNumberOfChannelsKey: config.numberOfChannels,
            AVEncoderAudioQualityKey: quality.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: avSettings)
            recorder.record()
            activeRecorder = recorder
            logger.info("Recording started — file: \(url.lastPathComponent)")
            return true
        } catch {
            logger.error("Failed to start recording: \(error)")
            throw AudioServiceError.recordingFailed
        }
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            activeRecorder?.stop()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                try? audioSession.setActive(true)
            }
        @unknown default:
            break
        }
    }
}
