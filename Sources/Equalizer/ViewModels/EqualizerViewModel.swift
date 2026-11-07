import SwiftUI
import Combine
@preconcurrency import CoreAudio

/// Fonte da verdade reativa para os ganhos e estados do equalizador na interface gráfica e ponte direta com o motor DSP.
@MainActor
public class EqualizerViewModel: ObservableObject {
    @Published public var bands: [EQBand] = EQBand.defaultTenBands
    @Published public var preampGain: Float = 0.0
    @Published public var isBypassed: Bool = false
    @Published public var selectedProfile: HeadphoneProfile?
    @Published public var selectedPreset: EQPreset?
    @Published public var outputVolume: Float = 1.0
    
    @Published public var profileStore = ProfileStore()
    @Published public var presetStore = PresetStore()
    
    public let engineManager: AudioEngineManagerProtocol
    private var cancellables = Set<AnyCancellable>()
    
    public init(engineManager: AudioEngineManagerProtocol = AudioEngineManager()) {
        self.engineManager = engineManager
        setupEngineBindings()
        setupProfileBindings()
        setupPresetBindings()
    }
    
    private func setupEngineBindings() {
        engineManager.isRunningPublisher
            .filter { $0 == true }
            .sink { [weak self] _ in
                print("[EqualizerViewModel] Engine detectou início. Sincronizando estados...")
                self?.syncToEngine()
                self?.readOutputVolume()
                self?.installVolumeListener()
            }
            .store(in: &cancellables)

        $bands
            .sink { [weak self] updatedBands in
                guard let self = self else { return }
                for (index, band) in updatedBands.enumerated() {
                    self.engineManager.eqProcessor.updateBand(
                        index: index,
                        filterType: band.filterType,
                        frequency: band.frequency,
                        gain: band.gain,
                        bandwidth: band.bandwidth
                    )
                    self.engineManager.eqProcessor.updateBandBypass(index: index, isEnabled: band.isEnabled)
                }
            }
            .store(in: &cancellables)

        $preampGain
            .sink { [weak self] newPreamp in
                self?.engineManager.eqProcessor.updateGlobalGain(newPreamp)
            }
            .store(in: &cancellables)

        $isBypassed
            .sink { [weak self] bypassed in
                print("[EqualizerViewModel] Bypass alternado: \(bypassed)")
                self?.engineManager.setBypass(bypassed)
            }
            .store(in: &cancellables)

        $selectedProfile
            .sink { [weak self] profile in
                guard let self = self else { return }
                if let profile = profile {
                    self.engineManager.parametricProcessor.loadProfile(profile)
                } else {
                    self.engineManager.parametricProcessor.unloadProfile()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupProfileBindings() {
        profileStore.$activeProfile
            .dropFirst() // Evita disparo no init antes do engine estar pronto
            .sink { [weak self] profile in
                self?.selectedProfile = profile
            }
            .store(in: &cancellables)
    }
    
    private func setupPresetBindings() {
        presetStore.$activePreset
            .dropFirst() // Evita disparo no init antes do engine estar pronto
            .sink { [weak self] preset in
                self?.selectedPreset = preset
                self?.applyPreset(preset)
            }
            .store(in: &cancellables)
    }
    
    /// Aplica todas as configurações de um preset simples às 10 bandas fixas.
    /// Usa matching por índice posicional para garantir que todos os presets built-in
    /// (que têm exatamente 10 bandas na mesma ordem) sejam aplicados corretamente.
    private func applyPreset(_ preset: EQPreset?) {
        print("[EqualizerViewModel] Aplicando preset: \(preset?.name ?? "Nenhum (Flat)") com \(preset?.bands.count ?? 0) bandas")
        var updatedBands: [EQBand]

        if let preset = preset {
            updatedBands = bands
            for (index, presetBand) in preset.bands.enumerated() {
                guard index < updatedBands.count else { break }
                updatedBands[index].frequency = presetBand.frequency
                updatedBands[index].gain = presetBand.gain
                updatedBands[index].filterType = presetBand.filterType
                updatedBands[index].qFactor = presetBand.qFactor
                updatedBands[index].bandwidth = presetBand.bandwidth > 0
                    ? presetBand.bandwidth
                    : ProfileBand.qToBandwidth(q: presetBand.qFactor)
                updatedBands[index].isEnabled = presetBand.isEnabled
                print("[EqualizerViewModel] Banda[\(index)] freq=\(presetBand.frequency)Hz gain=\(presetBand.gain)dB")
            }
        } else {
            print("[EqualizerViewModel] Resetando bandas para estado Flat (Nenhum preset)")
            updatedBands = EQBand.defaultTenBands
        }

        bands = updatedBands
        engineManager.eqProcessor.updateGlobalGain(preampGain)
        print("[EqualizerViewModel] Preset aplicado/resetado. Engine rodando: \(engineManager.isRunning)")
    }

    /// Restaura todas as bandas e o preamp para zero dB.
    public func resetAllBands() {
        print("[EqualizerViewModel] Reset All Bands")
        bands = EQBand.defaultTenBands
        preampGain = 0.0
        selectedPreset = nil
        presetStore.activePreset = nil
        syncToEngine()
    }
    
    /// Atualiza o ganho de uma banda específica por seu UUID.
    public func updateBandGain(id: UUID, gain: Float) {
        guard let index = bands.firstIndex(where: { $0.id == id }) else { return }
        let oldGain = bands[index].gain
        
        var updatedBands = bands
        updatedBands[index].gain = gain
        bands = updatedBands
        
        print("[EqualizerViewModel] Banda[\(index)] \(Int(bands[index].frequency))Hz: \(oldGain) → \(gain) dB (Publisher disparado)")
    }
    
    /// Atualiza o ganho global (Preamp).
    public func updatePreampGain(_ gain: Float) {
        let clamped = min(max(gain, -15.0), 15.0)
        print("[EqualizerViewModel] Preamp: \(preampGain) → \(clamped) dB")
        preampGain = clamped
        // Immediate push to engine
        engineManager.eqProcessor.updateGlobalGain(preampGain)
    }
    
    /// Carrega e ativa um perfil de fone de ouvido paramétrico.
    public func loadHeadphoneProfile(_ profile: HeadphoneProfile?) {
        let name = profile?.name ?? "nil"
        print("[EqualizerViewModel] Carregando perfil: \(name). Engine rodando: \(engineManager.isRunning)")
        selectedProfile = profile
        profileStore.activeProfile = profile
        
        // Ensure engine is live before loading profile.
        if !engineManager.isRunning {
            print("[EqualizerViewModel] Engine not running – starting before profile load")
            engineManager.startEngine()
        }
        
        // Apply directly to DSP.
        if let p = profile {
            engineManager.parametricProcessor.loadProfile(p)
            print("[EqualizerViewModel] Perfil '\(p.name)' carregado com \(p.bands.count) bandas")
        } else {
            engineManager.parametricProcessor.unloadProfile()
            print("[EqualizerViewModel] Perfil desativado")
        }
        
        // Sync state to ensure UI reflects any changes.
        syncToEngine()
    }
    
    /// Carrega e ativa um preset simples.
    public func loadPreset(_ preset: EQPreset?) {
        if !engineManager.isRunning {
            print("[EqualizerViewModel] Engine não está rodando. Iniciando antes de carregar preset...")
            engineManager.startEngine()
        }
        selectedPreset = preset
        presetStore.activePreset = preset
        applyPreset(preset)
        syncToEngine()
    }
    
    // MARK: - Volume de Saída

    /// ID do dispositivo de hardware real, onde o volume é controlado.
    private var volumeControlDeviceID: AudioObjectID? {
        let hardwareID = engineManager.tapManager.hardwareOutputDeviceID
        if hardwareID != kAudioObjectUnknown {
            return hardwareID
        }
        return engineManager.deviceManager.defaultOutputDevice?.id
    }

    /// Helper não-ator que mantém o listener CoreAudio de volume vivo enquanto o engine estiver ativo.
    /// Armazenado como propriedade para que o ARC não o destrua prematuramente.
    private var volumeListenerHelper: VolumeListenerHelper?

    /// Instala um listener CoreAudio que detecta mudanças de volume externas
    /// (teclas do teclado, painel de controle do macOS) e atualiza o slider automaticamente.
    ///
    /// Usa `VolumeListenerHelper` para evitar o crash `_dispatch_assert_queue_fail`:
    /// closures criadas em contexto `@MainActor` que capturam `self` são automaticamente
    /// anotadas como `@MainActor` pelo compilador, causando falha ao CoreAudio chamá-las
    /// num thread de background. O helper é uma classe sem isolamento de ator.
    public func installVolumeListener() {
        guard let deviceID = volumeControlDeviceID, volumeListenerHelper?.deviceID != deviceID else { return }
        volumeListenerHelper = nil

        let elements: [AudioObjectPropertyElement] = [1, kAudioObjectPropertyElementMain]
        for element in elements {
            let helper = VolumeListenerHelper(
                deviceID: deviceID,
                element: element,
                onVolumeChange: { @Sendable [weak self] in
                    // VolumeListenerHelper garante execução no main thread via DispatchQueue.main.async.
                    // MainActor.assumeIsolated informa ao compilador que estamos no ator correto.
                    MainActor.assumeIsolated { self?.readOutputVolume() }
                }
            )
            if helper.install() {
                volumeListenerHelper = helper
                print("[EqualizerViewModel] Volume listener instalado em deviceID=\(deviceID) element=\(element)")
                return
            }
        }
        print("[EqualizerViewModel] Aviso: não foi possível instalar volume listener")
    }

    /// Lê o volume atual do dispositivo de saída via CoreAudio.
    /// Usa kAudioDevicePropertyVolumeScalar no canal master (element main) do scope de output.
    public func readOutputVolume() {
        guard let deviceID = volumeControlDeviceID else {
            print("[EqualizerViewModel] Aviso: nenhum dispositivo de saída disponível para ler volume")
            return
        }

        // Tenta ler o volume do canal master primeiro, depois canal 1 (left)
        let elements: [AudioObjectPropertyElement] = [
            kAudioObjectPropertyElementMain,  // master (element 0)
            1,                                 // left channel
            2                                  // right channel
        ]
        for element in elements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            guard AudioObjectHasProperty(deviceID, &address) else { continue }
            var volume: Float32 = 1.0
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume) == noErr {
                outputVolume = min(max(volume, 0.0), 1.0)
                print("[EqualizerViewModel] Volume lido: \(Int(outputVolume * 100))% (element=\(element), device=\(deviceID))")
                return
            }
        }
        print("[EqualizerViewModel] Aviso: não foi possível ler o volume do dispositivo ID=\(deviceID)")
    }

    /// Define o volume do dispositivo de saída via CoreAudio.
    /// Equivalente ao controle de volume do teclado do macOS.
    public func setOutputVolume(_ volume: Float) {
        let clamped = min(max(volume, 0.0), 1.0)
        outputVolume = clamped
        print("[EqualizerViewModel] Setando volume para: \(Int(clamped * 100))%")
        guard let deviceID = volumeControlDeviceID else {
            print("[EqualizerViewModel] Aviso: sem dispositivo de saída para setar volume")
            return
        }
        
        // Define volume em TODOS os elementos suportados: master + canais individuais
        let elements: [AudioObjectPropertyElement] = [
            kAudioObjectPropertyElementMain,  // master
            1,                                 // left
            2                                  // right
        ]
        var anySet = false
        for element in elements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            var isSettable: DarwinBoolean = false
            guard AudioObjectHasProperty(deviceID, &address),
                  AudioObjectIsPropertySettable(deviceID, &address, &isSettable) == noErr,
                  isSettable.boolValue else { continue }
            
            var v = Float32(clamped)
            let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
            if status == noErr {
                anySet = true
                print("[EqualizerViewModel] Volume setado OK em element=\(element)")
            } else {
                print("[EqualizerViewModel] Falha ao setar volume em element=\(element): status=\(status)")
            }
        }
        if !anySet {
            print("[EqualizerViewModel] Aviso: não foi possível setar volume em nenhum elemento para deviceID=\(deviceID)")
        }
        // Verify by reading back the actual system volume
        readOutputVolume()
    }
    
    /// Re-sincroniza imediatamente todos os parâmetros e o perfil ativo com o motor de áudio.
    public func syncToEngine() {
        print("[EqualizerViewModel] Re-sincronizando todos os parâmetros com o AudioEngineManager...")
        // Re-aplica preset ativo se existir, para garantir consistência após reinicialização do engine
        if let preset = selectedPreset {
            applyPreset(preset)
        } else {
            for (index, band) in bands.enumerated() {
                engineManager.eqProcessor.updateBand(
                    index: index,
                    filterType: band.filterType,
                    frequency: band.frequency,
                    gain: band.gain,
                    bandwidth: band.bandwidth
                )
                engineManager.eqProcessor.updateBandBypass(index: index, isEnabled: band.isEnabled)
            }
            engineManager.eqProcessor.updateGlobalGain(preampGain)
        }
        engineManager.setBypass(isBypassed)
        if let profile = selectedProfile ?? profileStore.activeProfile {
            engineManager.parametricProcessor.loadProfile(profile)
            print("[EqualizerViewModel] Perfil \(profile.name) carregado via syncToEngine")
        } else {
            engineManager.parametricProcessor.unloadProfile()
            print("[EqualizerViewModel] Profilo descarregado via syncToEngine")
        }
        print("[EqualizerViewModel] Sync completo. Engine rodando: \(engineManager.isRunning)")
    }
}
