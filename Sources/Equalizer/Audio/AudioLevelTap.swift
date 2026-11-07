@preconcurrency import AVFAudio
import Foundation
import os

/// Medição de nível fora da thread de tempo real.
///
/// O IOProc entrega as amostras em `capture`, que só copia para um buffer circular e desiste do
/// ciclo se o lock estiver ocupado, sem nunca bloquear o áudio. RMS e FFT são calculados em uma
/// fila própria, e a UI é notificada por uma closure `@Sendable`.
final class AudioLevelTap: @unchecked Sendable {
    private static let analysisFrames = 1024

    private let levelMeter = AudioLevelMeter()
    private let onUpdate: @Sendable (Float, [Float]) -> Void
    private let analysisBuffer: AVAudioPCMBuffer
    private let queue = DispatchQueue(label: "com.josevansantos.Equalizer.levels", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var wasSilent = false

    // Protegidos por `lock`.
    private let lock: UnsafeMutablePointer<os_unfair_lock>
    private let ring: UnsafeMutablePointer<Float32>
    private var writeIndex = 0
    private var inputEnergy: Double = 0
    private var outputEnergy: Double = 0
    private var energyFrames = 0

    // Diagnóstico: com `EQUALIZER_DIAG=1`, registra os níveis antes e depois do EQ a cada segundo.
    private let diagnosticsEnabled = ProcessInfo.processInfo.environment["EQUALIZER_DIAG"] != nil
    private var ticksSinceDiagnostics = 0

    init?(sampleRate: Double, onUpdate: @escaping @Sendable (Float, [Float]) -> Void) {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(Self.analysisFrames)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(Self.analysisFrames)
        self.analysisBuffer = buffer
        self.onUpdate = onUpdate

        lock = .allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
        ring = .allocate(capacity: Self.analysisFrames)
        ring.initialize(repeating: 0, count: Self.analysisFrames)
    }

    deinit {
        timer?.cancel()
        lock.deallocate()
        ring.deallocate()
    }

    /// Chamado na thread de tempo real, depois da renderização.
    func capture(input: [UnsafeMutablePointer<Float32>], output: [UnsafeMutablePointer<Float32>], frames: Int) {
        guard os_unfair_lock_trylock(lock) else { return }
        defer { os_unfair_lock_unlock(lock) }

        let left = output[0]
        for frame in 0..<frames {
            ring[writeIndex] = left[frame]
            writeIndex = (writeIndex + 1) % Self.analysisFrames
        }
        guard diagnosticsEnabled else { return }
        for frame in 0..<frames {
            inputEnergy += Double(input[0][frame] * input[0][frame])
            outputEnergy += Double(left[frame] * left[frame])
        }
        energyFrames += frames
    }

    func startPolling() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(33))
        timer.setEventHandler { [weak self] in self?.analyze() }
        timer.resume()
        self.timer = timer
    }

    func stopPolling() {
        timer?.cancel()
        timer = nil
    }

    private func analyze() {
        let destination = analysisBuffer.floatChannelData![0]
        var diagnostics: (input: Double, output: Double, frames: Int)?

        os_unfair_lock_lock(lock)
        let tail = Self.analysisFrames - writeIndex
        destination.update(from: ring + writeIndex, count: tail)
        (destination + tail).update(from: ring, count: writeIndex)
        ticksSinceDiagnostics += 1
        if diagnosticsEnabled, ticksSinceDiagnostics >= 30 {
            diagnostics = (inputEnergy, outputEnergy, energyFrames)
            inputEnergy = 0
            outputEnergy = 0
            energyFrames = 0
            ticksSinceDiagnostics = 0
        }
        os_unfair_lock_unlock(lock)

        if let diagnostics {
            log(diagnostics)
        }

        let rms = levelMeter.calculateRMS(from: analysisBuffer)
        let isSilent = rms <= -100.0
        defer { wasSilent = isSilent }
        guard !(isSilent && wasSilent) else { return }
        onUpdate(rms, levelMeter.calculateBandMagnitudes(from: analysisBuffer))
    }

    private func log(_ value: (input: Double, output: Double, frames: Int)) {
        // Sem terminal, o stdout usa buffer e o log só apareceria ao fechar o app.
        defer { fflush(nil) }
        guard value.frames > 0 else {
            print("[Diag] nenhum ciclo de IO no último segundo")
            return
        }
        let decibels = { (energy: Double) -> String in
            energy > 0 ? String(format: "%.1f dB", 10 * log10(energy / Double(value.frames))) : "silêncio"
        }
        print("[Diag] antes do EQ: \(decibels(value.input)) | depois do EQ: \(decibels(value.output)) | frames: \(value.frames)")
    }
}
