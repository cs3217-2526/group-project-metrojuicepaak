//
//  AudioEngine.swift
//  MetroJuicePaak
//

import AVFoundation
import os

final class AudioEngine {

    private let avEngine = AVAudioEngine()
    private var voicePools: [ObjectIdentifier: VoicePool] = [:]
    private let registry: EffectRegistry = StubEffectRegistry()
    private let logger = Logger(subsystem: "MetroJuicePaak", category: "AudioEngine")

    // MARK: - Voice Pool

    private final class VoicePool {
        let voices: [SampleVoice]
        var nextVoiceIndex = 0

        init(voices: [SampleVoice]) {
            self.voices = voices
        }

        /// Returns the next voice for overlapping playback using round-robin selection.
        /// If the selected voice is already playing it will be stopped by SampleVoice.start()
        /// before rescheduling — this is the voice-stealing behaviour.
        func nextVoice() -> SampleVoice {
            let voice = voices[nextVoiceIndex]
            nextVoiceIndex = (nextVoiceIndex + 1) % voices.count
            return voice
        }
    }

    // MARK: - Private Helpers

    /// Derives a stable identity key from a PlayableAudioSample.
    /// Assumes all conformers are reference types (classes), which is true for AudioSample.
    private func poolKey(for sample: PlayableAudioSample) -> ObjectIdentifier {
        ObjectIdentifier(sample as AnyObject)
    }

    private func applyMixerProperties(_ sample: PlayableAudioSample, to voice: SampleVoice) {
        voice.playerNode.volume = Float(sample.volume)
        // PlayableAudioSample.pan is [0, 1] (0.5 = centre).
        // AVAudioPlayerNode.pan expects [-1, 1].
        voice.playerNode.pan = Float(sample.pan * 2.0 - 1.0)
    }

    // MARK: - Load / Unload

    func load(sample: PlayableAudioSample, polyphony: Int) throws {
        let key = poolKey(for: sample)
        guard voicePools[key] == nil else {
            logger.debug("Sample '\(sample.url.lastPathComponent)' already loaded, skipping")
            return
        }

        let voiceCount = max(1, polyphony)
        var voices: [SampleVoice] = []
        for _ in 0..<voiceCount {
            let voice = SampleVoice(engine: avEngine, registry: registry)
            try voice.loadFile(from: sample.url)
            voices.append(voice)
        }

        voicePools[key] = VoicePool(voices: voices)
        logger.info("Loaded '\(sample.url.lastPathComponent)' with polyphony \(voiceCount)")
    }

    func unload(_ sample: PlayableAudioSample) {
        let key = poolKey(for: sample)
        guard let pool = voicePools.removeValue(forKey: key) else { return }
        pool.voices.forEach { $0.detach() }
        logger.info("Unloaded '\(sample.url.lastPathComponent)'")
    }

    // MARK: - Playback

    /// Retrigger: stops all voices for this sample and restarts from voice 0.
//    func play(_ sample: PlayableAudioSample) {
//        let key = poolKey(for: sample)
//        guard let pool = voicePools[key] else {
//            logger.warning("play() called on unloaded sample '\(sample.url.lastPathComponent)'")
//            return
//        }
//        pool.voices.forEach { $0.stop() }
//        pool.nextVoiceIndex = 0
//        let voice = pool.voices[0]
//        applyMixerProperties(sample, to: voice)
//        voice.start()
//    }
    
    // MARK: - CHANGES TO NOTE:
    /// Retriggers playback: stops all active voices for this sample and restarts from voice 0.
    ///
    /// **Architecture Update:**
    /// The Audio Engine acts as the bridge between the domain model (`PlayableAudioSample`)
    /// and the hardware wrapper (`SampleVoice`). Because `SampleVoice` is strictly decoupled
    /// from domain concepts, the engine is responsible for extracting the sample's current
    /// trim ratios and injecting them directly into the voice at the moment of playback.
    ///
    /// - Parameter sample: The read-only playback view of the sample to play.
    func play(_ sample: PlayableAudioSample) {
        let key = poolKey(for: sample)
        guard let pool = voicePools[key] else { return }
        pool.voices.forEach { $0.stop() }
        pool.nextVoiceIndex = 0
        let voice = pool.voices[0]
        applyMixerProperties(sample, to: voice)
        
        // Pass the live domain trim ratios down to the hardware voice
        voice.start(startTimeRatio: sample.startTimeRatio, endTimeRatio: sample.endTimeRatio)
    }

    /// Triggers overlapping playback using round-robin voice stealing.
    ///
    /// **Architecture Update:**
    /// Similar to standard `play()`, this method extracts the `startTimeRatio` and
    /// `endTimeRatio` from the domain model and explicitly passes them down so the
    /// physical audio buffer respects any trims made in the Waveform Editor UI.
    ///
    /// - Parameter sample: The read-only playback view of the sample to play.
    func playOverlapping(_ sample: PlayableAudioSample) {
        let key = poolKey(for: sample)
        guard let pool = voicePools[key] else { return }
        let voice = pool.nextVoice()
        applyMixerProperties(sample, to: voice)
        
        // Pass the live domain trim ratios down to the hardware voice
        voice.start(startTimeRatio: sample.startTimeRatio, endTimeRatio: sample.endTimeRatio)
    }
    // MARK: - CHANGES TO NOTE ^ ^

    /// Overlapping playback with round-robin voice stealing.
    /// When all polyphony slots are busy the oldest voice is stopped and reused.
//    func playOverlapping(_ sample: PlayableAudioSample) {
//        let key = poolKey(for: sample)
//        guard let pool = voicePools[key] else {
//            logger.warning("playOverlapping() called on unloaded sample '\(sample.url.lastPathComponent)'")
//            return
//        }
//        let voice = pool.nextVoice()
//        applyMixerProperties(sample, to: voice)
//        // SampleVoice.start() calls playerNode.stop() before scheduling,
//        // so this naturally steals the voice if it is already playing.
//        voice.start()
//    }

    func stop(_ sample: PlayableAudioSample) {
        voicePools[poolKey(for: sample)]?.voices.forEach { $0.stop() }
    }

    func stopAll() {
        voicePools.values.forEach { pool in
            pool.voices.forEach { $0.stop() }
        }
    }

    // MARK: - State Queries

    func isLoaded(_ sample: PlayableAudioSample) -> Bool {
        voicePools[poolKey(for: sample)] != nil
    }

    func isPlaying(_ sample: PlayableAudioSample) -> Bool {
        voicePools[poolKey(for: sample)]?.voices.contains { $0.playerNode.isPlaying } ?? false
    }
}
