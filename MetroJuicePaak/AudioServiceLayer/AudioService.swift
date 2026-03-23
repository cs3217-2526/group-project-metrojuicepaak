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
    internal let audioApplication = AVAudioApplication.shared
    internal let audioEngine = AudioEngine()
    internal var activeRecorder: AVAudioRecorder?
    
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
}



