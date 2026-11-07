@preconcurrency import CoreAudio
import Combine
import Foundation

/// Gerencia e descobre dispositivos de áudio físicos e padrão do sistema via CoreAudio API.
@MainActor
public class AudioDeviceManager: ObservableObject {
    @Published public var outputDevices: [AudioDevice] = []
    @Published public var inputDevices: [AudioDevice] = []
    @Published public var defaultOutputDevice: AudioDevice?
    @Published public var defaultInputDevice: AudioDevice?
    
    private var isListeningForChanges = false
    
    public init() {
        refreshDevices()
    }
    
    /// Atualiza a lista de dispositivos de áudio disponíveis e identifica os dispositivos de saída/entrada padrão.
    public func refreshDevices() {
        let allDevices = fetchAllDevices()
        self.outputDevices = allDevices.filter { $0.isOutput }
        self.inputDevices = allDevices.filter { $0.isInput }
        self.defaultOutputDevice = fetchDefaultDevice(isOutput: true, from: allDevices)
        self.defaultInputDevice = fetchDefaultDevice(isOutput: false, from: allDevices)
    }
    
    /// Inicia a escuta para mudanças no dispositivo de saída padrão do macOS.
    public func startListeningForDeviceChanges() {
        guard !isListeningForChanges else { return }
        isListeningForChanges = true
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // A main queue é obrigatória: esta closure herda @MainActor, e o Swift 6 derruba o app
        // se o Core Audio a chamar em outra thread (o que aconteceria ao trocar de fone).
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main
        ) { [weak self] (_, _) -> Void in
            Task { @MainActor [weak self] in
                self?.refreshDevices()
            }
        }
    }
    
    private func fetchAllDevices() -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else { return [] }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = [AudioObjectID](repeating: 0, count: deviceCount)
        
        let fetchStatus = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs)
        guard fetchStatus == noErr else { return [] }
        
        return deviceIDs.compactMap { createDevice(from: $0) }
    }
    
    private func createDevice(from id: AudioObjectID) -> AudioDevice? {
        guard let name = getDeviceStringProperty(id: id, selector: kAudioObjectPropertyName),
              let uid = getDeviceStringProperty(id: id, selector: kAudioDevicePropertyDeviceUID),
              !uid.hasPrefix(CoreAudioTapManager.aggregateUIDPrefix) else {
            return nil
        }

        let outputChannels = getStreamConfigurationChannelCount(id: id, scope: kAudioDevicePropertyScopeOutput)
        let inputChannels = getStreamConfigurationChannelCount(id: id, scope: kAudioDevicePropertyScopeInput)
        
        let isOutput = outputChannels > 0
        let isInput = inputChannels > 0
        
        guard isOutput || isInput else { return nil }
        
        let sampleRate = getDeviceSampleRate(id: id)
        
        return AudioDevice(
            id: id,
            uid: uid,
            name: name,
            isOutput: isOutput,
            isInput: isInput,
            sampleRate: sampleRate
        )
    }
    
    private func getDeviceStringProperty(id: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        var cfString: CFString?
        
        let status = withUnsafeMutablePointer(to: &cfString) { ptr in
            AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, ptr)
        }
        guard status == noErr, let string = cfString as String? else { return nil }
        return string
    }
    
    private func getStreamConfigurationChannelCount(id: AudioObjectID, scope: AudioObjectPropertyScope) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &dataSize) == noErr, dataSize > 0 else { return 0 }
        
        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(dataSize))
        defer { bufferListPointer.deallocate() }
        
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, bufferListPointer) == noErr else { return 0 }
        
        var totalChannels = 0
        
        let buffers = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        for buffer in buffers {
            totalChannels += Int(buffer.mNumberChannels)
        }
        
        return totalChannels
    }
    
    private func getDeviceSampleRate(id: AudioObjectID) -> Double {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var sampleRate: Float64 = 44100.0
        var dataSize = UInt32(MemoryLayout<Float64>.size)
        
        if AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &sampleRate) == noErr {
            return sampleRate
        }
        return 44100.0
    }
    
    private func fetchDefaultDevice(isOutput: Bool, from devices: [AudioDevice]) -> AudioDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: isOutput ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID: AudioObjectID = 0
        var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
        
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID) == noErr else {
            return devices.first { isOutput ? $0.isOutput : $0.isInput }
        }
        
        return devices.first { $0.id == deviceID }
    }
    
    /// Define o dispositivo de entrada padrão do sistema/app.
    public func setDefaultInputDevice(_ device: AudioDevice) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = device.id
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioObjectID>.size),
            &deviceID
        )
        guard status == noErr else {
            throw CoreAudioTapError.missingDefaultOutputDevice
        }
        self.defaultInputDevice = device
    }
    
    /// Define o dispositivo de saída padrão do sistema.
    public func setDefaultOutputDevice(_ device: AudioDevice) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = device.id
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioObjectID>.size),
            &deviceID
        )
        guard status == noErr else {
            throw CoreAudioTapError.missingDefaultOutputDevice
        }
        self.defaultOutputDevice = device
    }
}
