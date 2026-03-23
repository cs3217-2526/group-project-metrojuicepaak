//
//  RecordingSettings.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 23/3/26.
//

import AVFoundation

extension AudioService {
    
    internal func recordingSettings() -> [String: Any] {
        return [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }

    internal func compressedRecordingSettings() -> [String: Any] {
        return [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
    }
}
