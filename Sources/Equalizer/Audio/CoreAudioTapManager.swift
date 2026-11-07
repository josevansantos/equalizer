@preconcurrency import CoreAudio
import Foundation

/// Erros relacionados à criação e gerenciamento do Core Audio Tap.
public enum CoreAudioTapError: Error, Equatable {
    case tapCreationFailed(OSStatus)
    case tapDestructionFailed(OSStatus)
    case aggregateDeviceCreationFailed(OSStatus)
    case aggregateDeviceDestructionFailed(OSStatus)
    case missingDefaultOutputDevice
    case missingDeviceProperty
    case missingOwnProcessObject
}

/// Gerencia a criação e ciclo de vida de um Tap nativo no áudio de saída do sistema (macOS Core Audio Tap).
///
/// Cria um process tap global, que captura o áudio de todos os processos menos o próprio app, e um
/// aggregate device privado com o tap como entrada e o hardware como saída. O dispositivo de saída
/// padrão do sistema nunca é alterado: enquanto o tap é lido, os apps são silenciados no hardware
/// e só o áudio processado chega lá. Se o app parar ou cair, o som deles volta sozinho.
public final class CoreAudioTapManager: @unchecked Sendable {
    /// Prefixo do UID do aggregate, usado para escondê-lo das listas de dispositivos.
    public static let aggregateUIDPrefix = "com.josevansantos.Equalizer.Aggregate."

    private var tapObjectID: AudioObjectID = kAudioObjectUnknown
    private var aggregateDeviceID: AudioObjectID = kAudioObjectUnknown
    private var outputDeviceID: AudioObjectID = kAudioObjectUnknown
    private var isTapActive = false

    public init() {}

    deinit {
        try? destroyProcessTap()
    }

    /// Cria o tap e monta o aggregate device sobre o dispositivo de saída especificado.
    @discardableResult
    public func createProcessTap(on deviceID: AudioObjectID) -> Bool {
        guard !isTapActive else { return true }
        print("[CoreAudioTapManager] Iniciando criação do tap para deviceID: \(deviceID)")

        do {
            let tapUID = try createTap()
            print("[CoreAudioTapManager] Tap criado com ID: \(tapObjectID), UID: \(tapUID)")
            try createAggregateDevice(tapUID: tapUID, outputDeviceID: deviceID)
            print("[CoreAudioTapManager] Aggregate device criado com ID: \(aggregateDeviceID)")
            outputDeviceID = deviceID
            isTapActive = true
            return true
        } catch {
            print("[CoreAudioTapManager] Erro ao criar Core Audio Tap: \(error)")
            cleanup()
            return false
        }
    }

    /// Destrói o aggregate device e o tap ativos.
    public func destroyProcessTap() throws {
        guard isTapActive else { return }

        if aggregateDeviceID != kAudioObjectUnknown {
            let status = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            guard status == noErr else {
                throw CoreAudioTapError.aggregateDeviceDestructionFailed(status)
            }
            aggregateDeviceID = kAudioObjectUnknown
        }

        if tapObjectID != kAudioObjectUnknown {
            let status = AudioHardwareDestroyProcessTap(tapObjectID)
            guard status == noErr else {
                throw CoreAudioTapError.tapDestructionFailed(status)
            }
            tapObjectID = kAudioObjectUnknown
        }

        outputDeviceID = kAudioObjectUnknown
        isTapActive = false
    }

    /// Retorna se o tap de interceptação de áudio está ativo no momento.
    public var isActive: Bool {
        isTapActive
    }

    /// ID do aggregate device atual, onde o IOProc de renderização é instalado.
    public var currentAggregateDeviceID: AudioObjectID {
        aggregateDeviceID
    }

    /// ID do dispositivo de saída real, usado para controlar o volume no hardware.
    public var hardwareOutputDeviceID: AudioObjectID {
        outputDeviceID
    }

    /// Sample rate do aggregate device, que segue o relógio do hardware de saída.
    public var aggregateSampleRate: Double {
        guard aggregateDeviceID != kAudioObjectUnknown else { return 0 }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var sampleRate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        guard AudioObjectGetPropertyData(aggregateDeviceID, &address, 0, nil, &size, &sampleRate) == noErr else {
            return 0
        }
        return sampleRate
    }

    /// Número de canais de um escopo do aggregate. A entrada precisa incluir os canais do tap.
    public func aggregateChannelCount(scope: AudioObjectPropertyScope) -> Int {
        guard aggregateDeviceID != kAudioObjectUnknown else { return 0 }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(aggregateDeviceID, &address, 0, nil, &size) == noErr, size > 0 else {
            return 0
        }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        let list = raw.assumingMemoryBound(to: AudioBufferList.self)
        guard AudioObjectGetPropertyData(aggregateDeviceID, &address, 0, nil, &size, list) == noErr else {
            return 0
        }
        return UnsafeMutableAudioBufferListPointer(list).reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    // MARK: - Private

    /// Cria o tap e devolve o UID pelo qual o aggregate device o referencia.
    private func createTap() throws -> String {
        // O próprio app precisa ficar de fora: senão o tap silenciaria nossa saída processada
        // e a recapturaria, criando realimentação.
        let ownProcess = try ownProcessObjectID()
        let tapDescription = CATapDescription(stereoGlobalTapButExcludeProcesses: [ownProcess])
        tapDescription.name = "Equalizer System Tap"
        tapDescription.uuid = UUID()
        tapDescription.isPrivate = true
        tapDescription.muteBehavior = .mutedWhenTapped

        var tapID: AudioObjectID = kAudioObjectUnknown
        let status = AudioHardwareCreateProcessTap(tapDescription, &tapID)
        guard status == noErr else {
            throw CoreAudioTapError.tapCreationFailed(status)
        }
        tapObjectID = tapID
        return tapDescription.uuid.uuidString
    }

    private func createAggregateDevice(tapUID: String, outputDeviceID: AudioObjectID) throws {
        let outputUID = try stringProperty(kAudioDevicePropertyDeviceUID, of: outputDeviceID)
        let outputName = try stringProperty(kAudioObjectPropertyName, of: outputDeviceID)
        print("[CoreAudioTapManager] Saída: \(outputName) (\(outputUID))")

        // O tap vai em `TapList`, não em `SubDeviceList`: um tap não é um dispositivo, e um UID
        // desconhecido na lista de subdispositivos é descartado sem erro, deixando a entrada vazia.
        let properties: [String: Any] = [
            kAudioAggregateDeviceUIDKey: Self.aggregateUIDPrefix + UUID().uuidString,
            kAudioAggregateDeviceNameKey: "Equalizer Aggregate - \(outputName)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [kAudioSubTapUIDKey: tapUID, kAudioSubTapDriftCompensationKey: true]
            ]
        ]

        var aggregateID: AudioObjectID = kAudioObjectUnknown
        let status = AudioHardwareCreateAggregateDevice(properties as CFDictionary, &aggregateID)
        guard status == noErr else {
            throw CoreAudioTapError.aggregateDeviceCreationFailed(status)
        }
        aggregateDeviceID = aggregateID
    }

    /// Traduz o PID do app para o objeto de processo do Core Audio.
    private func ownProcessObjectID() throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid = ProcessInfo.processInfo.processIdentifier
        var processObject: AudioObjectID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            UInt32(MemoryLayout<pid_t>.size),
            &pid,
            &size,
            &processObject
        )
        guard status == noErr, processObject != kAudioObjectUnknown else {
            throw CoreAudioTapError.missingOwnProcessObject
        }
        return processObject
    }

    private func stringProperty(_ selector: AudioObjectPropertySelector, of objectID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, pointer)
        }
        guard status == noErr, let string = value as String? else {
            throw CoreAudioTapError.missingDeviceProperty
        }
        return string
    }

    private func cleanup() {
        if aggregateDeviceID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = kAudioObjectUnknown
        }
        if tapObjectID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapObjectID)
            tapObjectID = kAudioObjectUnknown
        }
        outputDeviceID = kAudioObjectUnknown
        isTapActive = false
    }
}
