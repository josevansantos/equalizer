@preconcurrency import AVFAudio
import Foundation

/// Processador de 10 bandas gráfico/paramétrico baseado no AVAudioUnitEQ.
@MainActor
public class EQProcessor {
    public let eqNode: AVAudioUnitEQ
    
    private let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    
    public init() {
        self.eqNode = AVAudioUnitEQ(numberOfBands: 10)
        setupDefaultBands()
    }
    
    private func setupDefaultBands() {
        for (index, frequency) in frequencies.enumerated() {
            guard index < eqNode.bands.count else { break }
            let band = eqNode.bands[index]
            
            if index == 0 {
                band.filterType = .lowShelf
            } else if index == frequencies.count - 1 {
                band.filterType = .highShelf
            } else {
                band.filterType = .parametric
            }
            
            band.frequency = frequency
            band.bandwidth = 1.0
            band.gain = 0.0
            band.bypass = false
        }
        eqNode.globalGain = 0.0
    }
    
    /// Atualiza o ganho em decibéis de uma das 10 bandas (índice 0 a 9).
    public func updateBandGain(index: Int, gain: Float) {
        guard index >= 0, index < eqNode.bands.count else { return }
        let band = eqNode.bands[index]
        band.gain = min(max(gain, -30.0), 30.0)
    }

    /// Atualiza todos os parâmetros de uma das 10 bandas (índice 0 a 9).
    public func updateBand(index: Int, filterType: EQFilterType, frequency: Float, gain: Float, bandwidth: Float) {
        guard index >= 0, index < eqNode.bands.count else { return }
        let band = eqNode.bands[index]
        band.filterType = filterType.audioUnitFilterType
        band.frequency = max(frequency, 1.0)
        band.gain = min(max(gain, -30.0), 30.0)
        band.bandwidth = max(bandwidth, 0.01)
    }

    /// Ativa ou desativa o bypass de uma banda individual.
    public func updateBandBypass(index: Int, isEnabled: Bool) {
        guard index >= 0, index < eqNode.bands.count else { return }
        eqNode.bands[index].bypass = !isEnabled
    }

    /// Atualiza o ganho global (Preamp) em decibéis.
    public func updateGlobalGain(_ gain: Float) {
        eqNode.globalGain = min(max(gain, -30.0), 30.0)
    }

    /// Ativa ou desativa o bypass global da unidade de equalização.
    public func setBypass(_ bypass: Bool) {
        eqNode.bypass = bypass
    }
}
