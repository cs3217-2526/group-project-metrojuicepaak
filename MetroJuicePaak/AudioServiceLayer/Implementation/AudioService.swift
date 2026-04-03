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
        
        print("✅ Audio session configured")
        print("   Category: \(audioSession.category)")
        print("   Mode: \(audioSession.mode)")
        print("   Output volume: \(audioSession.outputVolume)")
        print("   Is other audio playing: \(audioSession.isOtherAudioPlaying)")
    }
    
    private func configureAudioApplication() async throws {
        // Check current permission status
        let currentPermission = audioApplication.recordPermission
        print("🎤 Current microphone permission: \(currentPermission.rawValue)")
        
        switch currentPermission {
        case .undetermined:
            print("🎤 Requesting microphone permission...")
            let granted = await AVAudioApplication.requestRecordPermission()
            print("🎤 Permission granted: \(granted)")
            if !granted {
                throw AudioServiceError.recordPermissionDenied
            }
        case .denied:
            print("❌ Microphone permission denied. Please enable in System Settings.")
            throw AudioServiceError.recordPermissionDenied
        case .granted:
            print("✅ Microphone permission already granted")
        @unknown default:
            print("⚠️ Unknown permission status")
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



