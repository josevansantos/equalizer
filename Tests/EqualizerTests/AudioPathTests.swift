import Testing
import Foundation
@preconcurrency import AVFAudio
@preconcurrency import CoreAudio
@testable import Equalizer

/// Passa sinal real pela cadeia usada em produção, sem tocar em dispositivos de áudio.
@MainActor
struct AudioPathTests {
    private static let sampleRate = 48_000.0
    private static let blockFrames = 512

    /// Lista de buffers com a forma que o HAL entrega ao IOProc.
    private final class Buffers {
        let list: UnsafeMutableAudioBufferListPointer
        private var storage: [UnsafeMutablePointer<Float32>] = []

        /// `layout` tem um item por stream, com a quantidade de canais dele.
        init(layout: [Int], frames: Int) {
            list = AudioBufferList.allocate(maximumBuffers: layout.count)
            for (index, channels) in layout.enumerated() {
                let count = channels * frames
                let samples = UnsafeMutablePointer<Float32>.allocate(capacity: count)
                samples.initialize(repeating: 0, count: count)
                storage.append(samples)
                list[index] = AudioBuffer(
                    mNumberChannels: UInt32(channels),
                    mDataByteSize: UInt32(count * MemoryLayout<Float32>.size),
                    mData: samples
                )
            }
        }

        func samples(_ stream: Int) -> UnsafeMutablePointer<Float32> { storage[stream] }

        deinit {
            storage.forEach { $0.deallocate() }
            free(list.unsafeMutablePointer)
        }
    }

    private func renderer(nodes: [AVAudioNode]) throws -> SystemAudioRenderer {
        try SystemAudioRenderer(sampleRate: Self.sampleRate, nodes: nodes, levelTap: nil)
    }

    /// Envia uma senoide e devolve a variação de nível, em dB, depois que os filtros estabilizam.
    private func gainInDecibels(through renderer: SystemAudioRenderer, frequency: Double) -> Double {
        let input = Buffers(layout: [2], frames: Self.blockFrames)
        let output = Buffers(layout: [2], frames: Self.blockFrames)
        let amplitude = 0.1
        var phase = 0.0
        var outputEnergy = 0.0
        var inputEnergy = 0.0

        for block in 0..<40 {
            for frame in 0..<Self.blockFrames {
                let sample = Float32(amplitude * sin(phase))
                input.samples(0)[frame * 2] = sample
                input.samples(0)[frame * 2 + 1] = sample
                phase += 2 * .pi * frequency / Self.sampleRate
            }
            renderer.process(input: UnsafePointer(input.list.unsafePointer), output: output.list.unsafeMutablePointer)

            guard block >= 20 else { continue }
            for frame in 0..<Self.blockFrames {
                inputEnergy += pow(Double(input.samples(0)[frame * 2]), 2)
                outputEnergy += pow(Double(output.samples(0)[frame * 2]), 2)
            }
        }
        return 10 * log10(outputEnergy / inputEnergy)
    }

    @Test func flatChainPassesSignalUnchanged() throws {
        let eq = EQProcessor()
        let renderer = try renderer(nodes: [eq.eqNode])
        defer { renderer.detach([eq.eqNode]) }

        #expect(abs(gainInDecibels(through: renderer, frequency: 1000)) < 0.5)
    }

    @Test func bandGainChangesTheAudio() throws {
        let eq = EQProcessor()
        let renderer = try renderer(nodes: [eq.eqNode])
        defer { renderer.detach([eq.eqNode]) }

        eq.updateBandGain(index: 5, gain: 12) // 1 kHz
        let boosted = gainInDecibels(through: renderer, frequency: 1000)
        #expect(abs(boosted - 12) < 1.0, "ganho medido em 1 kHz: \(boosted) dB")

        let elsewhere = gainInDecibels(through: renderer, frequency: 8000)
        #expect(abs(elsewhere) < 1.0, "ganho medido em 8 kHz: \(elsewhere) dB")
    }

    @Test func bypassRemovesTheEffect() throws {
        let eq = EQProcessor()
        let renderer = try renderer(nodes: [eq.eqNode])
        defer { renderer.detach([eq.eqNode]) }

        eq.updateBandGain(index: 5, gain: 12)
        eq.setBypass(true)
        #expect(abs(gainInDecibels(through: renderer, frequency: 1000)) < 0.5)
    }

    @Test func headphoneProfileChangesTheAudio() throws {
        let eq = EQProcessor()
        let parametric = ParametricEQProcessor()
        let nodes: [AVAudioNode] = [eq.eqNode, parametric.eqNode]
        let renderer = try renderer(nodes: nodes)
        defer { renderer.detach(nodes) }

        let band = ProfileBand(filterType: .peak, frequency: 1000, gain: -9, qFactor: 1.0)
        parametric.loadProfile(HeadphoneProfile(name: "Teste", brand: "Teste", model: "Teste", preampGain: 0, bands: [band]))

        let measured = gainInDecibels(through: renderer, frequency: 1000)
        #expect(abs(measured + 9) < 1.0, "ganho medido: \(measured) dB")
    }

    @Test func readsTapFromLastStreamWhenHardwareAlsoHasInput() {
        // Headset USB: microfone mono primeiro, tap estéreo por último.
        let input = Buffers(layout: [1, 2], frames: 4)
        input.samples(0).update(repeating: 0.9, count: 4)
        for frame in 0..<4 {
            input.samples(1)[frame * 2] = 0.25
            input.samples(1)[frame * 2 + 1] = -0.25
        }
        let destination = (0..<2).map { _ in UnsafeMutablePointer<Float32>.allocate(capacity: 4) }
        defer { destination.forEach { $0.deallocate() } }

        SystemAudioRenderer.readStereo(from: input.list, frames: 4, into: destination)

        #expect(destination[0][3] == 0.25)
        #expect(destination[1][3] == -0.25)
    }

    @Test func writesStereoToBothHardwareLayouts() {
        let source = (0..<2).map { _ in UnsafeMutablePointer<Float32>.allocate(capacity: 2) }
        defer { source.forEach { $0.deallocate() } }
        source[0].update(repeating: 0.5, count: 2)
        source[1].update(repeating: -0.5, count: 2)

        // Intercalado, com canais a mais que precisam ficar em silêncio.
        let interleaved = Buffers(layout: [4], frames: 2)
        interleaved.samples(0).update(repeating: 1, count: 8)
        SystemAudioRenderer.writeStereo(from: source, frames: 2, to: interleaved.list)
        #expect(Array(UnsafeBufferPointer(start: interleaved.samples(0), count: 4)) == [0.5, -0.5, 0, 0])

        // Não intercalado.
        let separate = Buffers(layout: [1, 1], frames: 2)
        SystemAudioRenderer.writeStereo(from: source, frames: 2, to: separate.list)
        #expect(separate.samples(0)[1] == 0.5)
        #expect(separate.samples(1)[1] == -0.5)
    }

    /// Regressão: o tap era descartado do aggregate sem erro, deixando a entrada sem canais.
    /// Não inicia IO, portanto não silencia nada.
    @Test func aggregateIncludesTapAndKeepsSystemDefaultOutput() throws {
        let before = defaultOutputDevice()
        try #require(before != kAudioObjectUnknown, "esta máquina não tem saída de áudio")

        let manager = CoreAudioTapManager()
        #expect(manager.createProcessTap(on: before))
        defer { try? manager.destroyProcessTap() }

        #expect(manager.aggregateChannelCount(scope: kAudioDevicePropertyScopeInput) >= 2)
        #expect(manager.aggregateChannelCount(scope: kAudioDevicePropertyScopeOutput) >= 1)
        #expect(manager.aggregateSampleRate > 0)
        #expect(manager.hardwareOutputDeviceID == before)
        #expect(defaultOutputDevice() == before)
    }

    private func defaultOutputDevice() -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device: AudioObjectID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return device
    }
}
