import Foundation

/// Representa uma banda individual de equalização paramétrica ou gráfica.
public struct EQBand: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var filterType: EQFilterType
    public var frequency: Float
    public var qFactor: Float
    public var bandwidth: Float
    public var isEnabled: Bool
    
    private var _gain: Float
    public var gain: Float {
        get { _gain }
        set { _gain = min(max(newValue, -30.0), 30.0) }
    }
    
    public init(id: UUID = UUID(), filterType: EQFilterType, frequency: Float, gain: Float, qFactor: Float = 1.414, bandwidth: Float = 1.0, isEnabled: Bool = true) {
        self.id = id
        self.filterType = filterType
        self.frequency = frequency
        self._gain = min(max(gain, -30.0), 30.0)
        self.qFactor = qFactor
        self.bandwidth = bandwidth
        self.isEnabled = isEnabled
    }
    
    /// As 10 frequências padrão do equalizador gráfico simples (32 Hz a 16 kHz).
    public static var defaultTenBands: [EQBand] {
        let freqs: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        return freqs.map { freq in
            let type: EQFilterType
            if freq == 32 {
                type = .lowShelf
            } else if freq == 16000 {
                type = .highShelf
            } else {
                type = .peak
            }
            return EQBand(
                filterType: type,
                frequency: freq,
                gain: 0.0,
                qFactor: 1.414,
                bandwidth: 1.0,
                isEnabled: true
            )
        }
    }
}
