@preconcurrency import AVFAudio
import Foundation

/// Processador dinâmico de equalização paramétrica capaz de carregar N bandas a partir de um perfil de fone.
@MainActor
public class ParametricEQProcessor {
    public private(set) var eqNode: AVAudioUnitEQ
    public private(set) var activeProfile: HeadphoneProfile?
    public private(set) var isBypassed: Bool = false
    
    public init() {
        // O schema de perfis limita a 20 bandas; usamos 20 slots e ativamos apenas as usadas.
        self.eqNode = AVAudioUnitEQ(numberOfBands: 20)
        setupEmptyBands()
    }
    
    private func setupEmptyBands() {
        for band in eqNode.bands {
            band.filterType = .parametric
            band.frequency = 1000.0
            band.gain = 0.0
            band.bandwidth = 1.0
            band.bypass = true
        }
        eqNode.globalGain = 0.0
    }
    
    /// Carrega e aplica as configurações de filtros paramétricos de um perfil de fone de ouvido.
    public func loadProfile(_ profile: HeadphoneProfile) {
        self.activeProfile = profile
        
        let activeBands = profile.bands.filter(\.isEnabled)
        let bandCount = min(activeBands.count, eqNode.bands.count)
        
        for index in 0..<eqNode.bands.count {
            let nodeBand = eqNode.bands[index]
            if index < bandCount {
                let profileBand = activeBands[index]
                nodeBand.filterType = profileBand.filterType.audioUnitFilterType
                nodeBand.frequency = profileBand.frequency
                nodeBand.gain = profileBand.gain
                nodeBand.bandwidth = profileBand.bandwidth > 0 ? profileBand.bandwidth : HeadphoneProfile.qToBandwidth(q: profileBand.qFactor)
                nodeBand.bypass = false
            } else {
                nodeBand.gain = 0.0
                nodeBand.bypass = true
            }
        }
        
        eqNode.globalGain = profile.preampGain
        eqNode.bypass = isBypassed
    }
    
    /// Remove o perfil atual e desativa todas as bandas paramétricas.
    public func unloadProfile() {
        self.activeProfile = nil
        setupEmptyBands()
    }
    
    /// Ativa ou desativa o bypass do processador paramétrico.
    public func setBypass(_ bypass: Bool) {
        self.isBypassed = bypass
        eqNode.bypass = bypass
    }
}
