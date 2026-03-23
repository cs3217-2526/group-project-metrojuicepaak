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
            print("❌ Recording permission denied")
            throw AudioServiceError.recordPermissionDenied
        }
        
        print("🎙️ Starting recording to: \(url.path)")
        print("   Directory exists: \(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))")
        
        let recorder = try AVAudioRecorder(url: url, settings: recordingSettings())
        recorder.prepareToRecord()
        
        // Enable metering to check if audio is being captured
        recorder.isMeteringEnabled = true
        
        self.activeRecorder = recorder
        
        if let activeRecorder {
            let success = activeRecorder.record()
            if success {
                print("✅ Recording started successfully")
                print("   Recording: \(activeRecorder.isRecording)")
                print("   Format: \(activeRecorder.format)")
            } else {
                print("❌ Recording failed to start")
            }
            return success
        } else {
            print("❌ No active recorder")
            return false
        }
    }
    
    func pauseRecording() async {
        if let activeRecorder {
            activeRecorder.pause()
            print("⏸️ Recording paused")
        }
    }
    
    func stopRecording() async -> URL? {
        if let activeRecorder {
            // Check metering before stopping
            activeRecorder.updateMeters()
            let averagePower = activeRecorder.averagePower(forChannel: 0)
            let peakPower = activeRecorder.peakPower(forChannel: 0)
            print("🎙️ Recording levels - Average: \(averagePower) dB, Peak: \(peakPower) dB")
            
            activeRecorder.stop()
            let url = activeRecorder.url
            
            // Check file after recording
            if FileManager.default.fileExists(atPath: url.path) {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let fileSize = attributes[.size] as? Int64 {
                    print("⏹️ Recording stopped, saved to: \(url.lastPathComponent)")
                    print("   File size: \(fileSize) bytes")
                    if fileSize == 0 {
                        print("⚠️ Warning: Recorded file is empty!")
                    }
                } else {
                    print("⚠️ Could not get file attributes")
                }
            } else {
                print("❌ Recording file does not exist after stopping!")
            }
            
            self.activeRecorder = nil
            return url
        } else {
            print("❌ No active recording to stop")
            return nil
        }
    }
}

