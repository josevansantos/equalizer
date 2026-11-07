import Testing
@testable import Equalizer

struct EqualizerTests {

    @Test func appTargetCompilesAndLinks() {
        // Verifica que o módulo Equalizer pode ser importado sem erros.
        #expect(Bool(true))
    }

    @Test func defaultTenBandsContainsExpectedFrequencies() {
        let bands = EQBand.defaultTenBands
        #expect(bands.count == 10)
        #expect(bands[0].frequency == 32)
        #expect(bands[9].frequency == 16000)
    }

    @Test func defaultTenBandsHasCorrectFilterTypes() {
        let bands = EQBand.defaultTenBands
        #expect(bands[0].filterType == .lowShelf)
        #expect(bands[1].filterType == .peak)
        #expect(bands[8].filterType == .peak)
        #expect(bands[9].filterType == .highShelf)
    }

    @Test func gainIsClampedToValidRange() {
        var band = EQBand(filterType: .peak, frequency: 1000, gain: 0)
        band.gain = 50
        #expect(band.gain == 30)

        band.gain = -50
        #expect(band.gain == -30)
    }

    @Test func eqFilterTypeHasExpectedRawValues() {
        #expect(EQFilterType.lowShelf.rawValue == "LOW_SHELF")
        #expect(EQFilterType.peak.rawValue == "PEAK")
        #expect(EQFilterType.highShelf.rawValue == "HIGH_SHELF")
    }

    @Test func presetBandValueDefaultsIsEnabledToTrue() {
        let band = EQPreset.EQBandValue(frequency: 1000, gain: 5.0, qFactor: 1.0, bandwidth: 1.0, filterType: .peak)
        #expect(band.isEnabled == true)
    }

    @Test func presetBandValueCanBeDisabled() {
        let band = EQPreset.EQBandValue(frequency: 1000, gain: 5.0, qFactor: 1.0, bandwidth: 1.0, filterType: .peak, isEnabled: false)
        #expect(band.isEnabled == false)
    }
}

@MainActor
struct EqualizerViewModelPresetTests {

    @Test func loadPresetAppliesAllBandProperties() {
        let viewModel = EqualizerViewModel(engineManager: MockAudioEngineManager())

        let customBands = EQBand.defaultTenBands.enumerated().map { index, band in
            EQPreset.EQBandValue(
                frequency: band.frequency,
                gain: Float(index + 1),
                qFactor: 2.0,
                bandwidth: 1.5,
                filterType: index == 0 ? .lowShelf : (index == 9 ? .highShelf : .peak),
                isEnabled: index != 5
            )
        }

        let preset = EQPreset(name: "Custom", bands: customBands, isBuiltIn: false)
        viewModel.loadPreset(preset)

        for (index, band) in viewModel.bands.enumerated() {
            #expect(band.gain == Float(index + 1))
            #expect(band.qFactor == 2.0)
            #expect(band.bandwidth == 1.5)
            #expect(band.isEnabled == (index != 5))
        }
    }

    @Test func loadPresetEmitsBandsPublisher() async {
        let viewModel = EqualizerViewModel(engineManager: MockAudioEngineManager())
        var received = false

        let cancellable = viewModel.$bands
            .dropFirst()
            .sink { _ in
                received = true
            }

        let preset = EQPreset(name: "Bass Boost", bands: EQPreset.builtInPresets[1].bands, isBuiltIn: true)
        viewModel.loadPreset(preset)

        // Aguarda um ciclo de runloop para o publisher emitir.
        await Task.yield()

        #expect(received == true)
        cancellable.cancel()
    }

    @Test func resetAllBandsRestoresDefaults() {
        let viewModel = EqualizerViewModel(engineManager: MockAudioEngineManager())
        let preset = EQPreset.builtInPresets[1] // Bass Boost
        viewModel.loadPreset(preset)
        #expect(viewModel.bands[0].gain != 0)

        viewModel.resetAllBands()

        #expect(viewModel.preampGain == 0)
        #expect(viewModel.selectedPreset == nil)
        #expect(viewModel.presetStore.activePreset == nil)
        for band in viewModel.bands {
            #expect(band.gain == 0)
            #expect(band.qFactor == 1.414)
            #expect(band.bandwidth == 1.0)
            #expect(band.isEnabled == true)
        }
    }
}
