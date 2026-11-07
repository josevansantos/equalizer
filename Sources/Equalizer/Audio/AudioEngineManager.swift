@preconcurrency import AVFAudio
@preconcurrency import CoreAudio
import Combine

/// Interface para o orquestrador do motor de áudio, permitindo Mocking para testes unitários.
@MainActor
public protocol AudioEngineManagerProtocol: AnyObject, ObservableObject {
    var isRunning: Bool { get }
    var isBypassed: Bool { get set }
    var activeDeviceName: String { get }
    var eqProcessor: EQProcessor { get }
    var parametricProcessor: ParametricEQProcessor { get }
    var tapManager: CoreAudioTapManager { get }
    var deviceManager: AudioDeviceManager { get }
    var levelMagnitudes: [Float] { get }
    var isRunningPublisher: AnyPublisher<Bool, Never> { get }
    func startEngine()
    func stopEngine()
    func setBypass(_ bypass: Bool)
}

/// Orquestrador master que integra interceptação de áudio, nós de equalização (10-Band EQ + Parametric EQ) e medições FFT.
@MainActor
public class AudioEngineManager: ObservableObject, AudioEngineManagerProtocol {
    @Published public var isRunning: Bool = false
    @Published public var isBypassed: Bool = false
    @Published public var activeDeviceName: String = "Default CoreAudio"
    @Published public var levelMagnitudes: [Float] = Array(repeating: 0.0, count: 10)
    @Published public var currentRMS: Float = -100.0
    @Published public var lastError: String?

    public var isRunningPublisher: AnyPublisher<Bool, Never> {
        $isRunning.eraseToAnyPublisher()
    }

    public let eqProcessor = EQProcessor()
    public let parametricProcessor = ParametricEQProcessor()
    public let tapManager = CoreAudioTapManager()
    public let deviceManager = AudioDeviceManager()

    private var cancellables = Set<AnyCancellable>()
    private var renderer: SystemAudioRenderer?
    private var levelTap: AudioLevelTap?
    private var sampleRateListener: PropertyListener?

    private var eqNodes: [AVAudioNode] {
        [eqProcessor.eqNode, parametricProcessor.eqNode]
    }

    public init() {
        setupDeviceChangeMonitoring()
        self.activeDeviceName = deviceManager.defaultOutputDevice?.name ?? "System Output"
    }

    private func setupDeviceChangeMonitoring() {
        deviceManager.$defaultOutputDevice
            .removeDuplicates { $0?.id == $1?.id }
            .dropFirst()
            .sink { [weak self] newDevice in
                guard let self = self, let device = newDevice else { return }
                self.activeDeviceName = device.name
                print("[AudioEngineManager] Dispositivo de saída alterado para: \(device.name)")
                self.restartIfRunning()
            }
            .store(in: &cancellables)
        deviceManager.startListeningForDeviceChanges()
    }

    /// Inicia o processamento: tap + aggregate device → IOProc → cadeia de EQ → hardware.
    public func startEngine() {
        guard !isRunning else {
            print("[AudioEngineManager] Engine já está rodando, ignorando startEngine()")
            return
        }

        do {
            let outputDeviceID = try defaultOutputDeviceID()
            print("[AudioEngineManager] Dispositivo de saída detectado: ID=\(outputDeviceID)")

            guard tapManager.createProcessTap(on: outputDeviceID) else {
                throw AudioEngineError.tapCreationFailed
            }

            let inputChannels = tapManager.aggregateChannelCount(scope: kAudioDevicePropertyScopeInput)
            let sampleRate = tapManager.aggregateSampleRate
            print("[AudioEngineManager] Aggregate: \(inputChannels) canal(is) de entrada, \(sampleRate) Hz")
            guard inputChannels >= SystemAudioRenderer.channelCount else {
                throw AudioEngineError.invalidInputFormat
            }

            let levelTap = AudioLevelTap(sampleRate: sampleRate) { [weak self] rms, magnitudes in
                Task { @MainActor [weak self] in
                    self?.currentRMS = rms
                    self?.levelMagnitudes = magnitudes
                }
            }
            let renderer = try SystemAudioRenderer(sampleRate: sampleRate, nodes: eqNodes, levelTap: levelTap)
            self.renderer = renderer
            self.levelTap = levelTap

            // Atributos dos AVAudioUnitEQ são reinicializados pelo engine; reaplica antes do áudio passar.
            if let profile = parametricProcessor.activeProfile {
                parametricProcessor.loadProfile(profile)
            }
            eqProcessor.setBypass(isBypassed)
            parametricProcessor.setBypass(isBypassed)

            try renderer.start(on: tapManager.currentAggregateDeviceID)
            levelTap?.startPolling()
            observeSampleRate(expected: sampleRate)

            activeDeviceName = deviceManager.defaultOutputDevice?.name ?? "System Output"
            isRunning = true
            lastError = nil
            print("[AudioEngineManager] ✅ Engine ativo em \(activeDeviceName)")
        } catch {
            print("[AudioEngineManager] ❌ Erro ao iniciar engine: \(error)")
            lastError = String(describing: error)
            teardown()
        }
    }

    /// Para o processamento e destrói o tap.
    public func stopEngine() {
        guard isRunning else { return }
        print("[AudioEngineManager] Parando engine...")
        teardown()
        print("[AudioEngineManager] Engine parado")
    }

    /// Ativa ou desativa o bypass global do processamento no áudio.
    public func setBypass(_ bypass: Bool) {
        self.isBypassed = bypass
        eqProcessor.setBypass(bypass)
        parametricProcessor.setBypass(bypass)
        print("[AudioEngineManager] Bypass: \(bypass)")
    }

    // MARK: - Private

    private func teardown() {
        sampleRateListener = nil
        levelTap?.stopPolling()
        levelTap = nil
        renderer?.stop()
        renderer?.detach(eqNodes)
        renderer = nil
        try? tapManager.destroyProcessTap()
        isRunning = false
        currentRMS = -100.0
        levelMagnitudes = Array(repeating: 0.0, count: 10)
    }

    private func restartIfRunning() {
        guard isRunning else { return }
        print("[AudioEngineManager] Reiniciando engine...")
        stopEngine()
        startEngine()
    }

    /// O hardware pode mudar de sample rate em uso (ex.: AirPods ao entrar em uma chamada);
    /// como o grafo é fixo no formato inicial, é preciso remontá-lo.
    private func observeSampleRate(expected: Double) {
        sampleRateListener = PropertyListener(
            objectID: tapManager.currentAggregateDeviceID,
            selector: kAudioDevicePropertyNominalSampleRate
        ) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning, self.tapManager.aggregateSampleRate != expected else { return }
                print("[AudioEngineManager] Sample rate do hardware mudou")
                self.restartIfRunning()
            }
        }
    }

    private func defaultOutputDeviceID() throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioObjectID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr, deviceID != kAudioObjectUnknown else {
            throw AudioEngineError.defaultOutputDeviceUnavailable
        }
        return deviceID
    }
}

/// Erros do motor de áudio.
public enum AudioEngineError: Error, Equatable {
    case defaultOutputDeviceUnavailable
    case tapCreationFailed
    case invalidInputFormat
    case invalidOutputFormat
}
