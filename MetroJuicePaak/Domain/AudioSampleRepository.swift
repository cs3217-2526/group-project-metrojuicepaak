//
//  AudioSampleRepository.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 4/4/26.
//

import Foundation

/// Pure data layer representing the entire "Project Pool" of recorded audio.
///
/// This is a value type (struct) that holds the canonical state of all samples.
/// It knows nothing about UI, waveforms, or AVAudioEngine — those concerns
/// belong to AudioSampleRepositoryViewModel (the Conductor) above it.
struct AudioSampleRepository: Codable {

    // ─────────────────────────────────────────
    // MARK: - Storage
    // ─────────────────────────────────────────

    /// The master pool of every AudioSample the user has recorded this session.
    private(set) var allSamples: [UUID: AudioSample] = [:]

    // ─────────────────────────────────────────
    // MARK: - Auto-naming
    // ─────────────────────────────────────────

    private static let defaultNamePrefix = "Untitled"

    /// Scans the pool and returns the next available "Untitled X" name.
    ///
    /// Works in two steps:
    ///   1. Collect every number already in use by iterating `allSamples` and
    ///      parsing the numeric suffix from names that match "Untitled N".
    ///      Anything that doesn't match (custom names, partial matches) is ignored
    ///      via `compactMap` returning nil.
    ///   2. Start at 1 and increment until a number not in that set is found.
    ///      This fills gaps — if "Untitled 1" and "Untitled 3" exist, it returns
    ///      "Untitled 2" rather than "Untitled 4".
    private func calculateNextDefaultName() -> String {
        let usedNumbers = Set(
            allSamples.values.compactMap { sample -> Int? in
                guard sample.name.hasPrefix(Self.defaultNamePrefix) else { return nil }
                let suffix = sample.name
                    .dropFirst(Self.defaultNamePrefix.count)
                    .trimmingCharacters(in: .whitespaces)
                return Int(suffix)
            }
        )

        var candidate = 1
        while usedNumbers.contains(candidate) {
            candidate += 1
        }
        return "\(Self.defaultNamePrefix) \(candidate)"
    }

    // ─────────────────────────────────────────
    // MARK: - Sample Management
    // ─────────────────────────────────────────

    /// Creates an AudioSample from a recording result, auto-names it, and inserts it into the pool.
    ///
    /// This is the single entry-point for new recordings — naming lives here
    /// because the repository is the only component that can see the full pool
    /// and therefore know which numbers are already taken.
    ///
    /// - Returns: The newly created and stored AudioSample.
    @discardableResult
    mutating func addSample(from result: RecordingResult) -> AudioSample {
        let name = calculateNextDefaultName()
        let sample = AudioSample(filename: result.filename, duration: result.duration, name: name)
        allSamples[sample.id] = sample
        return sample
    }

    /// Removes a sample from the pool and clears any pad assignments that pointed to it.
    ///
    /// Removing a UUID that is not in the pool is a safe no-op — deletion is idempotent.
    mutating func removeSample(id: UUID) {
        allSamples.removeValue(forKey: id)
    }

    /// Persists a mutated AudioSample (e.g. after a trim or rename) back into the pool.
    ///
    /// Triggers an assertion failure in debug builds if the ID is not in the pool,
    /// since the Conductor should never hold a stale UUID reference.
    mutating func updateSample(_ sample: AudioSample) {
        assert(allSamples[sample.id] != nil, "updateSample called with UUID not in pool: \(sample.id)")
        allSamples[sample.id] = sample
    }

    // ─────────────────────────────────────────
    // MARK: - Lookup
    // ─────────────────────────────────────────

    /// Returns the sample for a UUID from the pool, or nil if it does not exist.
    func sample(for id: UUID) -> AudioSample? {
        allSamples[id]
    }
}
