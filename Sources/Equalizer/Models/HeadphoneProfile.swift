import Foundation

/// Representa uma banda de equalização dentro de um perfil paramétrico de fones de ouvido.
public struct ProfileBand: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var filterType: EQFilterType
    public var frequency: Float
    public var gain: Float
    public var qFactor: Float
    public var bandwidth: Float
    public var isEnabled: Bool
    
    public init(
        id: UUID = UUID(),
        filterType: EQFilterType,
        frequency: Float,
        gain: Float,
        qFactor: Float = 1.414,
        bandwidth: Float = 1.0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.filterType = filterType
        self.frequency = frequency
        self.gain = gain
        self.qFactor = qFactor
        self.bandwidth = bandwidth
        self.isEnabled = isEnabled
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case filterType
        case frequency
        case gain
        case qFactor
        case bandwidth
        case isEnabled = "enabled"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.filterType = try container.decode(EQFilterType.self, forKey: .filterType)
        self.frequency = try container.decode(Float.self, forKey: .frequency)
        self.gain = try container.decode(Float.self, forKey: .gain)
        self.qFactor = try container.decodeIfPresent(Float.self, forKey: .qFactor) ?? 1.414
        self.bandwidth = try container.decodeIfPresent(Float.self, forKey: .bandwidth) ?? ProfileBand.qToBandwidth(q: self.qFactor)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
    
    /// Converte Q-Factor em Bandwidth (oitavas).
    public static func qToBandwidth(q: Float) -> Float {
        guard q > 0 else { return 1.0 }
        let ln2 = Float(log(2.0))
        return 2.0 / ln2 * asinh(1.0 / (2.0 * q))
    }
    
    /// Converte Bandwidth (oitavas) em Q-Factor.
    public static func bandwidthToQ(bw: Float) -> Float {
        guard bw > 0 else { return 1.414 }
        let ln2 = Float(log(2.0))
        let sinhTerm = sinh(ln2 / 2.0 * bw)
        guard sinhTerm != 0 else { return 1.414 }
        return 1.0 / (2.0 * sinhTerm)
    }
}

/// Representa um setup de equalização para um fone específico (ex: Sony WH-1000XM4).
public struct HeadphoneProfile: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var brand: String
    public var model: String
    public var description: String
    public var targetCurve: String
    public var preampGain: Float
    public var bands: [ProfileBand]
    public var isBuiltIn: Bool
    public var source: String?
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        brand: String,
        model: String,
        description: String = "",
        targetCurve: String = "Harman 2019",
        preampGain: Float = 0.0,
        bands: [ProfileBand],
        isBuiltIn: Bool = false,
        source: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.model = model
        self.description = description
        self.targetCurve = targetCurve
        self.preampGain = preampGain
        self.bands = bands
        self.isBuiltIn = isBuiltIn
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case model
        case description
        case targetCurve
        case preampGain
        case bands
        case isBuiltIn
        case source
        case createdAt
        case updatedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.brand = try container.decode(String.self, forKey: .brand)
        self.model = try container.decode(String.self, forKey: .model)
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.targetCurve = try container.decodeIfPresent(String.self, forKey: .targetCurve) ?? "Harman 2019"
        self.preampGain = try container.decodeIfPresent(Float.self, forKey: .preampGain) ?? 0.0
        self.bands = try container.decode([ProfileBand].self, forKey: .bands)
        self.isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
        
        let isoFormatter = ISO8601DateFormatter()
        if let createdString = try container.decodeIfPresent(String.self, forKey: .createdAt),
           let created = isoFormatter.date(from: createdString) {
            self.createdAt = created
        } else {
            self.createdAt = Date()
        }
        
        if let updatedString = try container.decodeIfPresent(String.self, forKey: .updatedAt),
           let updated = isoFormatter.date(from: updatedString) {
            self.updatedAt = updated
        } else {
            self.updatedAt = Date()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(brand, forKey: .brand)
        try container.encode(model, forKey: .model)
        try container.encode(description, forKey: .description)
        try container.encode(targetCurve, forKey: .targetCurve)
        try container.encode(preampGain, forKey: .preampGain)
        try container.encode(bands, forKey: .bands)
        try container.encode(isBuiltIn, forKey: .isBuiltIn)
        try container.encodeIfPresent(source, forKey: .source)
        
        let isoFormatter = ISO8601DateFormatter()
        try container.encode(isoFormatter.string(from: createdAt), forKey: .createdAt)
        try container.encode(isoFormatter.string(from: updatedAt), forKey: .updatedAt)
    }
    
    /// Converte Q-Factor em Bandwidth (oitavas).
    public static func qToBandwidth(q: Float) -> Float {
        ProfileBand.qToBandwidth(q: q)
    }
    
    /// Converte Bandwidth (oitavas) em Q-Factor.
    public static func bandwidthToQ(bw: Float) -> Float {
        ProfileBand.bandwidthToQ(bw: bw)
    }
}
