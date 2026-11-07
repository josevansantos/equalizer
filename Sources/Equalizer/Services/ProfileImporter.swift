import Foundation

/// Erros que podem ocorrer durante a importação de perfis.
public enum ProfileImportError: Error, Equatable {
    case invalidJSON
    case invalidFormat(line: Int, detail: String)
    case invalidAutoEQFormat
    case fileReadError
}

/// Conversor bidirecional de perfis de fones entre JSON e formatos externos (AutoEQ).
public final class ProfileImporter {
    
    public init() {}
    
    /// Importa um perfil a partir de um arquivo JSON local.
    public func importFromJSON(url: URL) throws -> HeadphoneProfile {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ProfileImportError.fileReadError
        }
        return try importFromJSON(data: data)
    }
    
    /// Importa um perfil a partir de uma string JSON.
    public func importFromJSON(string: String) throws -> HeadphoneProfile {
        guard let data = string.data(using: .utf8) else {
            throw ProfileImportError.invalidJSON
        }
        return try importFromJSON(data: data)
    }
    
    /// Importa um perfil a partir de dados JSON.
    public func importFromJSON(data: Data) throws -> HeadphoneProfile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(HeadphoneProfile.self, from: data)
        } catch {
            throw ProfileImportError.invalidJSON
        }
    }
    
    /// Exporta um perfil para um arquivo JSON.
    public func exportToJSON(profile: HeadphoneProfile, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)
        try data.write(to: url)
    }
    
    /// Importa um perfil a partir do formato texto do AutoEQ (`ParametricEQ.txt`).
    ///
    /// Exemplo de linha esperada:
    /// `Filter 1: ON PK Fc 105 Hz Gain -4.2 dB Q 0.70`
    public func importFromAutoEQ(text: String, brand: String = "", model: String = "") throws -> HeadphoneProfile {
        let lines = text.components(separatedBy: .newlines)
        var preampGain: Float = 0.0
        var bands: [ProfileBand] = []
        
        let preampRegex = try NSRegularExpression(
            pattern: #"Preamp:\s*([-+]?\d+\.?\d*)\s*dB"#,
            options: [.caseInsensitive]
        )
        let filterRegex = try NSRegularExpression(
            pattern: #"Filter\s+\d+:\s*(ON|OFF)\s+(PK|LSC|HSC|LS|HS|LP|HP|NO)\s+Fc\s+(\d+\.?\d*)\s*Hz\s+Gain\s+([-+]?\d+\.?\d*)\s*dB\s+Q\s+([-+]?\d+\.?\d*)"#,
            options: [.caseInsensitive]
        )
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            if let match = preampRegex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) {
                if let valueRange = Range(match.range(at: 1), in: trimmed),
                   let value = Float(trimmed[valueRange]) {
                    preampGain = value
                }
                continue
            }
            
            guard trimmed.lowercased().hasPrefix("filter") else { continue }
            
            let nsRange = NSRange(location: 0, length: trimmed.utf16.count)
            guard let match = filterRegex.firstMatch(in: trimmed, options: [], range: nsRange) else {
                throw ProfileImportError.invalidFormat(line: index + 1, detail: trimmed)
            }
            
            guard let stateRange = Range(match.range(at: 1), in: trimmed),
                  let typeRange = Range(match.range(at: 2), in: trimmed),
                  let freqRange = Range(match.range(at: 3), in: trimmed),
                  let gainRange = Range(match.range(at: 4), in: trimmed),
                  let qRange = Range(match.range(at: 5), in: trimmed),
                  let frequency = Float(trimmed[freqRange]),
                  let gain = Float(trimmed[gainRange]),
                  let qFactor = Float(trimmed[qRange]) else {
                throw ProfileImportError.invalidFormat(line: index + 1, detail: trimmed)
            }
            
            let filterType = filterType(from: String(trimmed[typeRange]))
            let isEnabled = String(trimmed[stateRange]).uppercased() == "ON"
            
            let band = ProfileBand(
                filterType: filterType,
                frequency: frequency,
                gain: gain,
                qFactor: qFactor,
                bandwidth: ProfileBand.qToBandwidth(q: qFactor),
                isEnabled: isEnabled
            )
            bands.append(band)
        }
        
        guard !bands.isEmpty else {
            throw ProfileImportError.invalidAutoEQFormat
        }
        
        let nameParts = [brand, model].filter { !$0.isEmpty }
        let name = nameParts.isEmpty ? "Imported AutoEQ Profile" : nameParts.joined(separator: " ")
        
        return HeadphoneProfile(
            name: name,
            brand: brand,
            model: model,
            description: "Importado do formato AutoEQ ParametricEQ",
            targetCurve: "Unknown",
            preampGain: preampGain,
            bands: bands,
            isBuiltIn: false,
            source: "AutoEQ"
        )
    }
    
    private func filterType(from token: String) -> EQFilterType {
        switch token.uppercased() {
        case "LSC", "LS":
            return .lowShelf
        case "HSC", "HS":
            return .highShelf
        case "LP":
            return .lowPass
        case "HP":
            return .highPass
        case "NO":
            return .notch
        default:
            return .peak
        }
    }
}
