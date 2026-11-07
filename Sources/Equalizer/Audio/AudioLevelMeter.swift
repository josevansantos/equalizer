@preconcurrency import AVFAudio
import Accelerate
import Foundation

/// Processador de sinais não-bloqueante utilizando vDSP / Accelerate para cálculo de RMS e magnitudes de frequência para a UI.
public class AudioLevelMeter: @unchecked Sendable {
    private var fftSetup: FFTSetup?
    private let log2n: vDSP_Length = 10 // 1024 amostras para FFT rápida
    private let bufferSize: Int = 1024
    
    public init() {
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }
    
    /// Processa um buffer de áudio PCM float para extrair o nível RMS em decibéis.
    public func calculateRMS(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return -100.0 }
        let channelPointer = channelData[0]
        let frameLength = vDSP_Length(buffer.frameLength)
        guard frameLength > 0 else { return -100.0 }
        
        var rms: Float = 0.0
        vDSP_rmsqv(channelPointer, 1, &rms, frameLength)
        
        guard rms > 0 else { return -100.0 }
        let db = 20.0 * log10(rms)
        return max(min(db, 0.0), -100.0)
    }
    
    /// Processa o buffer para obter magnitudes normalizadas para as 10 frequências padrão.
    public func calculateBandMagnitudes(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let fftSetup = fftSetup, let channelData = buffer.floatChannelData else {
            return Array(repeating: 0.0, count: 10)
        }
        
        // A FFT está configurada para exatamente `bufferSize` amostras (log2n): com menos, leria fora dos buffers.
        guard Int(buffer.frameLength) >= bufferSize else { return Array(repeating: 0.0, count: 10) }
        let n = bufferSize

        let halfN = n / 2
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        
        var windowedSamples = [Float](repeating: 0, count: n)
        vDSP_vmul(channelData[0], 1, window, 1, &windowedSamples, 1, vDSP_Length(n))
        
        var realP = [Float](repeating: 0, count: halfN)
        var imagP = [Float](repeating: 0, count: halfN)
        
        var magnitudes = [Float](repeating: 0, count: 10)
        
        realP.withUnsafeMutableBufferPointer { realPtr in
            imagP.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                
                windowedSamples.withUnsafeBufferPointer { samplesPtr in
                    samplesPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: n) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfN))
                    }
                }
                
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                
                var rawMagnitudes = [Float](repeating: 0, count: halfN)
                vDSP_zvmags(&splitComplex, 1, &rawMagnitudes, 1, vDSP_Length(halfN))
                
                // Mapeia magnitudes brutas em 10 bandas simples
                let sampleRate = Float(buffer.format.sampleRate)
                let binSize = sampleRate / Float(n)
                let freqs: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
                
                for (index, targetFreq) in freqs.enumerated() {
                    let binIndex = min(max(Int(targetFreq / binSize), 0), halfN - 1)
                    let val = sqrt(rawMagnitudes[binIndex])
                    magnitudes[index] = min(val / 50.0, 1.0)
                }
            }
        }
        
        return magnitudes
    }
}
