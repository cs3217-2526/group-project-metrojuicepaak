//
//  AudioService.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 23/3/26.
//

import Foundation
import AVFoundation

enum AudioServiceError: Error {
    case recordPermissionDenied
    case audioSessionConfigureFailed
    case recordingFailed
    case noActiveRecording
}

class AudioService {
    
    private var audioSession: AVAudioSession
    private let audioApplication = AVAudioApplication.shared
    private let audioEngine = AVAudioEngine()
    private var activeRecorder: AVAudioRecorder?
    private var recordingIdentifier: UUID?
    
    init() async throws {
        self.audioSession = AVAudioSession.sharedInstance()
        try await configureAudioApplication()
        do {
            try configureAudioSession()
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func configureAudioSession() throws {
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker]
        )
        try audioSession.setActive(true)
        
        }
    
    private func configureAudioApplication() async throws {
        let granted = await AVAudioApplication.requestRecordPermission()
        if !granted {
            throw AudioServiceError.recordPermissionDenied
        }
    }
    

    // MARK: Recording settings for AVAudioRecorder
    
    private func recordingSettings() -> [String: Any] {
        return [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }

    private func compressedRecordingSettings() -> [String: Any] {
        return [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            activeRecorder?.stop()
            
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                // Resume audio
                try? audioSession.setActive(true)
            }
        
        @unknown default:
            break
        }
    }
    
    
    
//    func recordSample() async throws -> AudioSample {
//        // Request permission if needed
//        let hasPermission = await requestMicrophonePermission()
//        guard hasPermission else {
//            throw AudioServiceError.permissionDenied
//        }
//        
//        // TODO: Implement with AVAudioRecorder
//        // This is a placeholder
//        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sample_\(UUID().uuidString).m4a")
//        return AudioSample(url: url, duration: 0)
//    }
//    
//    func stopRecording() async throws -> AudioSample? {
//        // TODO: Implement stopping and returning the recorded sample
//        nil
//    }
//    
//    func playSample(_ sample: AudioSample) {
//        // TODO: Implement with AVAudioPlayer or AVAudioEngine
//    }
//    
//    func stopPlayingSample() {
//        
//    }
}
