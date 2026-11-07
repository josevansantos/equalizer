@preconcurrency import AVFAudio
import Foundation

/// Tipos de filtros paramétricos suportados pelo equalizador.
public enum EQFilterType: String, Codable, CaseIterable, Sendable {
    case lowShelf = "LOW_SHELF"
    case peak = "PEAK"
    case highShelf = "HIGH_SHELF"
    case lowPass = "LOW_PASS"
    case highPass = "HIGH_PASS"
    case bandPass = "BAND_PASS"
    case notch = "NOTCH"
    
    /// Converte para o tipo nativo do Core Audio (`AVAudioUnitEQFilterType`).
    public var audioUnitFilterType: AVAudioUnitEQFilterType {
        switch self {
        case .lowShelf:
            return .lowShelf
        case .peak:
            return .parametric
        case .highShelf:
            return .highShelf
        case .lowPass:
            return .lowPass
        case .highPass:
            return .highPass
        case .bandPass:
            return .bandPass
        case .notch:
            return .bandStop
        }
    }
}
