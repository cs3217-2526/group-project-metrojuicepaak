//
//  AudioServicerRecordingAPIs.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 23/3/26.
//

import AVFoundation
import Foundation

extension AudioService {
    
    func recordAudio(url: URL) async throws -> Bool {
        guard audioApplication.recordPermission == .granted else {
            throw AudioServiceError.recordPermissionDenied
        }
        let recorder = try AVAudioRecorder(url: url, settings: recordingSettings())
        self.activeRecorder = recorder
        if let activeRecorder {
            return activeRecorder.record()
        } else {
            return false
        }
    }
    
    func pauseRecording() async {
        if let activeRecorder {
            activeRecorder.pause()
        }
    }
    
    func stopRecording() async -> URL? {
        if let activeRecorder {
            activeRecorder.stop()
            return activeRecorder.url
        } else {
            return nil
        }
    }
}

