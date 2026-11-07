import Testing
import Combine
@testable import Equalizer

// MARK: - Mocks

class MockAudioEngineManager: AudioEngineManagerProtocol {
    var isRunning: Bool = false
    var isBypassed: Bool = false
    var activeDeviceName: String = "Mock Device"
    let eqProcessor = EQProcessor()
    let parametricProcessor = ParametricEQProcessor()
    let tapManager = CoreAudioTapManager()
    let deviceManager = AudioDeviceManager()
    var levelMagnitudes: [Float] = Array(repeating: 0.0, count: 10)
    
    var isRunningPublisher: AnyPublisher<Bool, Never> {
        Just(isRunning).eraseToAnyPublisher()
    }
    
    var startEngineCalled = false
    var stopEngineCalled = false
    
    func startEngine() {
        startEngineCalled = true
        isRunning = true
    }
    
    func stopEngine() {
        stopEngineCalled = true
        isRunning = false
    }
    
    func setBypass(_ bypass: Bool) {
        isBypassed = bypass
    }
}

// MARK: - Tests

@MainActor
struct ViewModelTests {
    
    @Test func loadPresetStartsEngineIfStopped() {
        let mockEngine = MockAudioEngineManager()
        mockEngine.isRunning = false
        let viewModel = EqualizerViewModel(engineManager: mockEngine)
        
        let preset = EQPreset(name: "Test", bands: EQPreset.builtInPresets[0].bands)
        viewModel.loadPreset(preset)
        
        #expect(mockEngine.startEngineCalled == true)
        #expect(mockEngine.isRunning == true)
        #expect(viewModel.selectedPreset?.name == "Test")
    }
    
    @Test func loadPresetNilResetsBandsToFlat() {
        let mockEngine = MockAudioEngineManager()
        mockEngine.isRunning = true
        let viewModel = EqualizerViewModel(engineManager: mockEngine)
        
        // First load a preset to move away from flat
        let preset = EQPreset(name: "Bass Boost", bands: EQPreset.builtInPresets[1].bands)
        viewModel.loadPreset(preset)
        #expect(viewModel.bands[0].gain != 0)
        
        // Now load nil (Remove Preset)
        viewModel.loadPreset(nil)
        
        for band in viewModel.bands {
            #expect(band.gain == 0)
        }
        #expect(viewModel.selectedPreset == nil)
    }
    
    @Test func updateBandGainTriggersPublisher() async {
        let mockEngine = MockAudioEngineManager()
        mockEngine.isRunning = true
        let viewModel = EqualizerViewModel(engineManager: mockEngine)
        
        var publisherFired = false
        let cancellable = viewModel.$bands
            .dropFirst()
            .sink { _ in
                publisherFired = true
            }
        
        let bandID = viewModel.bands[0].id
        viewModel.updateBandGain(id: bandID, gain: 5.0)
        
        await Task.yield()
        
        #expect(publisherFired == true)
        #expect(viewModel.bands[0].gain == 5.0)
        cancellable.cancel()
    }
    
    @Test func loadHeadphoneProfileSchedulesSync() {
        let mockEngine = MockAudioEngineManager()
        mockEngine.isRunning = true
        let viewModel = EqualizerViewModel(engineManager: mockEngine)
        
        let profile = HeadphoneProfile(name: "Test Profile", brand: "Test", model: "Test", bands: [])
        viewModel.loadHeadphoneProfile(profile)
        
        #expect(viewModel.selectedProfile?.name == "Test Profile")
        #expect(mockEngine.parametricProcessor.activeProfile?.name == "Test Profile")
    }
}
