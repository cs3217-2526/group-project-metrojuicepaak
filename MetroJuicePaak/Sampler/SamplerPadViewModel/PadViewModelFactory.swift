//
//  DefaultPadViewModelFactory.swift
//  MetroJuicePaak
//
//  Created by Noah Ang Shi Hern on 19/4/26.
//

 class PadViewModelFactory {
    typealias Repository = ReadableAudioSampleRepository
                         & WaveformSourceAudioSampleRepository

    private let repository: Repository
    private let waveformService: WaveformGenerationService

    init(repository: Repository, waveformService: WaveformGenerationService) {
        self.repository = repository
        self.waveformService = waveformService
    }

    func makePadViewModel(for sampleID: ObjectIdentifier) -> SamplerPadViewModel {
        SamplerPadViewModel(
            sampleID: sampleID,
            repository: repository,
            generator: waveformService
        )
    }
}
