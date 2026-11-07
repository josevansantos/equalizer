@preconcurrency import AVFAudio
@preconcurrency import CoreAudio
import Foundation

/// Erros do caminho de renderização em tempo real.
public enum SystemAudioRendererError: Error, Equatable {
    case invalidFormat
    case ioProcCreationFailed(OSStatus)
    case deviceStartFailed(OSStatus)
}

/// Liga o aggregate device (tap como entrada, hardware como saída) à cadeia de EQ.
///
/// O `AVAudioEngine` roda em *manual rendering*, sem abrir nenhum dispositivo: quem conversa com
/// o hardware é o IOProc deste objeto. Isso evita o `inputNode` do engine, que se prende ao
/// microfone padrão (e força fones Bluetooth para o perfil de chamada).
///
/// Sem isolamento de ator de propósito: o bloco do IOProc roda na thread de tempo real do HAL.
/// Por isso todos os buffers são pré-alocados e o caminho de áudio não aloca nem bloqueia.
final class SystemAudioRenderer: @unchecked Sendable {
    /// O tap global é sempre estéreo; a cadeia de EQ trabalha em Float32 não intercalado.
    static let channelCount = 2
    static let maxFrames: AVAudioFrameCount = 4096

    let format: AVAudioFormat

    private let engine: AVAudioEngine
    private let renderBlock: AVAudioEngineManualRenderingBlock
    private let levelTap: AudioLevelTap?

    // Armazenamento pré-alocado, liberado no deinit.
    private let inputSamples: [UnsafeMutablePointer<Float32>]
    private let outputSamples: [UnsafeMutablePointer<Float32>]
    private let inputList: UnsafeMutableAudioBufferListPointer
    private let outputList: UnsafeMutableAudioBufferListPointer

    private var deviceID: AudioObjectID = kAudioObjectUnknown
    private var ioProcID: AudioDeviceIOProcID?

    /// Monta o grafo `entrada → nós → mixer → saída` em um engine novo e o inicia em modo manual.
    init(sampleRate: Double, nodes: [AVAudioNode], levelTap: AudioLevelTap?) throws {
        guard sampleRate > 0,
              let format = AVAudioFormat(
                  standardFormatWithSampleRate: sampleRate,
                  channels: AVAudioChannelCount(Self.channelCount)
              ) else {
            throw SystemAudioRendererError.invalidFormat
        }
        self.format = format
        self.levelTap = levelTap

        let capacity = Int(Self.maxFrames)
        let allocate = { () -> UnsafeMutablePointer<Float32> in
            let pointer = UnsafeMutablePointer<Float32>.allocate(capacity: capacity)
            pointer.initialize(repeating: 0, count: capacity)
            return pointer
        }
        inputSamples = (0..<Self.channelCount).map { _ in allocate() }
        outputSamples = (0..<Self.channelCount).map { _ in allocate() }
        inputList = AudioBufferList.allocate(maximumBuffers: Self.channelCount)
        outputList = AudioBufferList.allocate(maximumBuffers: Self.channelCount)

        let engine = AVAudioEngine()
        self.engine = engine
        try engine.enableManualRenderingMode(.realtime, format: format, maximumFrameCount: Self.maxFrames)

        // O bloco é chamado de dentro de `renderBlock`, na mesma thread: a entrada já está preenchida.
        let inputPointer = UnsafePointer(inputList.unsafePointer)
        engine.inputNode.setManualRenderingInputPCMFormat(format) { _ in inputPointer }

        var previous: AVAudioNode = engine.inputNode
        for node in nodes {
            engine.attach(node)
            engine.connect(previous, to: node, format: format)
            previous = node
        }
        engine.connect(previous, to: engine.mainMixerNode, format: format)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)

        renderBlock = engine.manualRenderingBlock
        try engine.start()
    }

    deinit {
        engine.stop()
        (inputSamples + outputSamples).forEach { $0.deallocate() }
        free(inputList.unsafeMutablePointer)
        free(outputList.unsafeMutablePointer)
    }

    /// Começa a puxar áudio do tap e a devolvê-lo processado ao hardware.
    func start(on deviceID: AudioObjectID) throws {
        var procID: AudioDeviceIOProcID?
        // O bloco retém `self` até `stop()`, então o objeto nunca é liberado com o IOProc ativo.
        let createStatus = AudioDeviceCreateIOProcIDWithBlock(&procID, deviceID, nil) { _, input, _, output, _ in
            self.process(input: input, output: output)
        }
        guard createStatus == noErr, let procID else {
            throw SystemAudioRendererError.ioProcCreationFailed(createStatus)
        }

        let startStatus = AudioDeviceStart(deviceID, procID)
        guard startStatus == noErr else {
            AudioDeviceDestroyIOProcID(deviceID, procID)
            throw SystemAudioRendererError.deviceStartFailed(startStatus)
        }
        self.deviceID = deviceID
        self.ioProcID = procID
    }

    /// Para o IOProc. Depois disso o bloco de tempo real não é mais chamado.
    func stop() {
        guard let procID = ioProcID else { return }
        AudioDeviceStop(deviceID, procID)
        AudioDeviceDestroyIOProcID(deviceID, procID)
        ioProcID = nil
        deviceID = kAudioObjectUnknown
    }

    /// Solta os nós de EQ para que possam ser reaproveitados no próximo engine.
    func detach(_ nodes: [AVAudioNode]) {
        engine.stop()
        nodes.forEach { engine.detach($0) }
    }

    // MARK: - Caminho de tempo real

    /// Processa um ciclo de IO. Não aloca nem bloqueia.
    func process(input: UnsafePointer<AudioBufferList>, output: UnsafeMutablePointer<AudioBufferList>) {
        let outputBuffers = UnsafeMutableAudioBufferListPointer(output)
        let frames = Self.frameCount(of: outputBuffers)
        guard frames > 0, frames <= Int(Self.maxFrames) else {
            Self.silence(outputBuffers)
            return
        }

        Self.readStereo(
            from: UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input)),
            frames: frames,
            into: inputSamples
        )
        Self.prepare(inputList, samples: inputSamples, frames: frames)
        Self.prepare(outputList, samples: outputSamples, frames: frames)

        var renderError: OSStatus = noErr
        let status = renderBlock(AVAudioFrameCount(frames), outputList.unsafeMutablePointer, &renderError)
        guard status == .success else {
            Self.silence(outputBuffers)
            return
        }

        Self.writeStereo(from: outputSamples, frames: frames, to: outputBuffers)
        levelTap?.capture(input: inputSamples, output: outputSamples, frames: frames)
    }

    private static func prepare(
        _ list: UnsafeMutableAudioBufferListPointer,
        samples: [UnsafeMutablePointer<Float32>],
        frames: Int
    ) {
        let byteSize = UInt32(frames * MemoryLayout<Float32>.size)
        list.count = samples.count
        for index in 0..<samples.count {
            list[index] = AudioBuffer(mNumberChannels: 1, mDataByteSize: byteSize, mData: samples[index])
        }
    }

    private static func frameCount(of buffers: UnsafeMutableAudioBufferListPointer) -> Int {
        guard let first = buffers.first, first.mNumberChannels > 0 else { return 0 }
        return Int(first.mDataByteSize) / (MemoryLayout<Float32>.size * Int(first.mNumberChannels))
    }

    /// Copia o estéreo do tap. O tap é o último stream do aggregate: se o hardware também tiver
    /// entrada (ex.: headset USB), os canais do microfone vêm antes e são ignorados aqui.
    static func readStereo(
        from buffers: UnsafeMutableAudioBufferListPointer,
        frames: Int,
        into destination: [UnsafeMutablePointer<Float32>]
    ) {
        destination.forEach { $0.update(repeating: 0, count: frames) }
        guard let last = buffers.last, last.mData != nil, last.mNumberChannels > 0 else { return }

        if last.mNumberChannels >= 2 {
            let channels = Int(last.mNumberChannels)
            let source = last.mData!.assumingMemoryBound(to: Float32.self)
            let available = min(frames, Int(last.mDataByteSize) / (MemoryLayout<Float32>.size * channels))
            for frame in 0..<available {
                destination[0][frame] = source[frame * channels]
                destination[1][frame] = source[frame * channels + 1]
            }
        } else if buffers.count >= 2, let left = buffers[buffers.count - 2].mData {
            let available = min(frames, Int(last.mDataByteSize) / MemoryLayout<Float32>.size)
            destination[0].update(from: left.assumingMemoryBound(to: Float32.self), count: available)
            destination[1].update(from: last.mData!.assumingMemoryBound(to: Float32.self), count: available)
        } else {
            // Stream mono: replica nos dois canais.
            let available = min(frames, Int(last.mDataByteSize) / MemoryLayout<Float32>.size)
            let source = last.mData!.assumingMemoryBound(to: Float32.self)
            destination[0].update(from: source, count: available)
            destination[1].update(from: source, count: available)
        }
    }

    /// Escreve o estéreo nos dois primeiros canais do hardware e silencia os demais.
    static func writeStereo(
        from source: [UnsafeMutablePointer<Float32>],
        frames: Int,
        to buffers: UnsafeMutableAudioBufferListPointer
    ) {
        var firstChannel = 0
        for buffer in buffers {
            guard let data = buffer.mData else { continue }
            let channels = Int(buffer.mNumberChannels)
            let samples = data.assumingMemoryBound(to: Float32.self)
            for channel in 0..<channels {
                let target = firstChannel + channel
                for frame in 0..<frames {
                    samples[frame * channels + channel] = target < source.count ? source[target][frame] : 0
                }
            }
            firstChannel += channels
        }
    }

    private static func silence(_ buffers: UnsafeMutableAudioBufferListPointer) {
        for buffer in buffers {
            if let data = buffer.mData {
                memset(data, 0, Int(buffer.mDataByteSize))
            }
        }
    }
}
