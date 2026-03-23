//
//  AudioEngine.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 23/3/26.
//


import AVFoundation

final class AudioEngine {
    private let audioEngine = AVAudioEngine()
    private var playerNodes: [String: AVAudioPlayerNode] = [:]
    private var audioFiles: [String: AVAudioFile] = [:]
    private var isEngineRunning = false

    init() {
        
    }

    func loadAudioFile(id: String, url: URL) throws {
        guard audioFiles[id] == nil else { 
            print("⚠️ Audio file already loaded for id: \(id)")
            return 
        }
        
        // Check if file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            print("❌ File does not exist at path: \(url.path)")
            throw NSError(domain: "AudioEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        }
        
        // Check file size
        if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? Int64 {
            print("📁 File size: \(fileSize) bytes at \(url.path)")
            if fileSize == 0 {
                print("⚠️ Warning: File is empty!")
            }
        }
        
        let file = try AVAudioFile(forReading: url)
        print("🎵 Audio file format: \(file.fileFormat)")
        print("🎵 Audio file length: \(file.length) frames")
        print("🎵 Audio file duration: \(Double(file.length) / file.fileFormat.sampleRate) seconds")
        
        let player = AVAudioPlayerNode()

        audioEngine.attach(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: file.processingFormat)

        playerNodes[id] = player
        audioFiles[id] = file
        
        print("✅ Loaded audio file: \(id) from \(url.lastPathComponent)")
    }

    func playAudioFile(id: String, volume: Float = 1.0, pan: Float = 0.0) {
        guard
            let player = playerNodes[id],
            let file = audioFiles[id]
        else {
            print("❌ Cannot play: player or file not found for id: \(id)")
            print("   Available IDs: \(playerNodes.keys.joined(separator: ", "))")
            return
        }

//        // Stop if currently playing to allow re-triggering
//        if player.isPlaying {
//            player.stop()
//        }

        player.volume = volume
        player.pan = pan

        // Start engine if needed
        if !isEngineRunning {
            do {
                try audioEngine.start()
                isEngineRunning = true
                print("✅ Audio engine started")
            } catch {
                print("❌ Failed to start audio engine: \(error)")
                return
            }
        }
        
        print("🔊 Engine running: \(audioEngine.isRunning)")
        print("🔊 Main mixer volume: \(audioEngine.mainMixerNode.volume)")
        print("🔊 Player volume: \(player.volume), pan: \(player.pan)")

        // Schedule and play
        player.scheduleFile(file, at: nil) {
            print("🎵 Finished playing: \(id)")
        }
        player.play()
        
        print("▶️ Playing audio: \(id), isPlaying: \(player.isPlaying)")
    }

    func stopPlayingFile(id: String) {
        playerNodes[id]?.stop()
        print("⏹️ Stopped audio: \(id)")
    }

    func stopPlayingAllFiles() {
        playerNodes.values.forEach { $0.stop() }
        print("⏹️ Stopped all audio")
    }
    
    func cleanUp() {
        audioEngine.stop()
        isEngineRunning = false
        print("🧹 Audio engine cleaned up")
    }
}
