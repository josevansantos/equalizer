import Foundation
import Combine

/// Gerencia os presets simples de equalização (10 bandas): built-in e customizados do usuário.
@MainActor
public final class PresetStore: ObservableObject {
    @Published public var presets: [EQPreset] = []
    @Published public var activePreset: EQPreset?
    
    private let userPresetsURL: URL
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    public init() {
        self.userPresetsURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Equalizer/Presets", isDirectory: true)
        
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        loadPresets()
    }
    
    /// Carrega presets built-in e do usuário. O preset ativo começa como nil
    /// e deve ser selecionado explicitamente pelo usuário.
    public func loadPresets() {
        let builtIn = EQPreset.builtInPresets
        let user = loadUserPresets()
        self.presets = builtIn + user
        // Não auto-ativar nenhum preset: o EQ inicia flat (sem preset selecionado).
    }
    
    /// Carrega presets salvos pelo usuário.
    public func loadUserPresets() -> [EQPreset] {
        createUserPresetsDirectoryIfNeeded()
        
        guard let enumerator = fileManager.enumerator(
            at: userPresetsURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        var result: [EQPreset] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "json" else { continue }
            do {
                let data = try Data(contentsOf: url)
                var preset = try decoder.decode(EQPreset.self, from: data)
                preset.isBuiltIn = false
                result.append(preset)
            } catch {
                print("Erro ao carregar preset do usuário \(url.lastPathComponent): \(error)")
            }
        }
        return result
    }
    
    /// Salva um preset customizado no disco.
    public func savePreset(_ preset: EQPreset) throws {
        createUserPresetsDirectoryIfNeeded()
        
        var presetToSave = preset
        presetToSave.isBuiltIn = false
        presetToSave.updatedAt = Date()
        
        let url = userPresetsURL.appendingPathComponent("\(presetToSave.id.uuidString).json")
        let data = try encoder.encode(presetToSave)
        try data.write(to: url)
        
        if let index = presets.firstIndex(where: { $0.id == presetToSave.id }) {
            presets[index] = presetToSave
        } else {
            presets.append(presetToSave)
        }
        
        objectWillChange.send()
    }
    
    /// Remove um preset do usuário do disco e da lista.
    public func deletePreset(_ preset: EQPreset) throws {
        guard !preset.isBuiltIn else { return }
        
        let url = userPresetsURL.appendingPathComponent("\(preset.id.uuidString).json")
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        
        presets.removeAll { $0.id == preset.id }
        
        if activePreset?.id == preset.id {
            activePreset = presets.first
        }
        
        objectWillChange.send()
    }
    
    /// Duplica um preset existente.
    public func duplicatePreset(_ preset: EQPreset) -> EQPreset {
        EQPreset(
            name: "\(preset.name) Copy",
            bands: preset.bands,
            isBuiltIn: false
        )
    }
    
    /// Define um preset como ativo.
    public func activatePreset(_ preset: EQPreset?) {
        activePreset = preset
    }
    
    private func createUserPresetsDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: userPresetsURL.path) {
            try? fileManager.createDirectory(
                at: userPresetsURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}
