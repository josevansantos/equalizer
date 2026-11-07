import Foundation

/// Representa um preset simples de equalização de 10 bandas fixas.
public struct EQPreset: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var bands: [EQBandValue]
    public var isBuiltIn: Bool
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        bands: [EQBandValue],
        isBuiltIn: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.bands = bands
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Valor de ganho para uma banda específica de um preset.
    public struct EQBandValue: Codable, Equatable, Sendable {
        public var frequency: Float
        public var gain: Float
        public var qFactor: Float
        public var bandwidth: Float
        public var filterType: EQFilterType
        public var isEnabled: Bool

        enum CodingKeys: String, CodingKey {
            case frequency, gain, qFactor, bandwidth, filterType, isEnabled
        }

        public init(
            frequency: Float,
            gain: Float,
            qFactor: Float = 1.414,
            bandwidth: Float = 1.0,
            filterType: EQFilterType = .peak,
            isEnabled: Bool = true
        ) {
            self.frequency = frequency
            self.gain = gain
            self.qFactor = qFactor
            self.bandwidth = bandwidth
            self.filterType = filterType
            self.isEnabled = isEnabled
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.frequency = try container.decode(Float.self, forKey: .frequency)
            self.gain = try container.decode(Float.self, forKey: .gain)
            self.qFactor = try container.decodeIfPresent(Float.self, forKey: .qFactor) ?? 1.414
            self.bandwidth = try container.decodeIfPresent(Float.self, forKey: .bandwidth)
                ?? ProfileBand.qToBandwidth(q: self.qFactor)
            self.filterType = try container.decode(EQFilterType.self, forKey: .filterType)
            self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        }
    }
    
    /// Presets padrão embutidos no app.
    public static var builtInPresets: [EQPreset] {
        let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        
        func makePreset(name: String, gains: [Float]) -> EQPreset {
            let bands = zip(frequencies, gains).enumerated().map { index, pair -> EQBandValue in
                let (frequency, gain) = pair
                let type: EQFilterType = index == 0 ? .lowShelf : (index == frequencies.count - 1 ? .highShelf : .peak)
                let q: Float = (type == .lowShelf || type == .highShelf) ? 0.71 : 1.0
                return EQBandValue(
                    frequency: Float(frequency),
                    gain: gain,
                    qFactor: q,
                    bandwidth: ProfileBand.qToBandwidth(q: q),
                    filterType: type
                )
            }
            return EQPreset(name: name, bands: bands, isBuiltIn: true)
        }
        
        return [
            makePreset(name: "Flat", gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
            makePreset(name: "Bass Boost", gains: [6, 5, 3, 1, 0, 0, 0, 0, 0, 0]),
            makePreset(name: "Vocal", gains: [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1]),
            makePreset(name: "Rock", gains: [4, 3, 1, 0, -1, 1, 3, 4, 3, 2]),
            makePreset(name: "Electronic", gains: [5, 4, 2, 0, -2, 0, 2, 4, 5, 4]),
            makePreset(name: "Acoustic", gains: [2, 2, 1, 1, 2, 2, 1, 3, 3, 2])
        ]
    }
}
