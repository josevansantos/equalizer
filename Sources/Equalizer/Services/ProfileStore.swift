import Foundation
import Combine

/// Gerencia os perfis de fones de ouvido: built-in do bundle e customizados do usuário.
@MainActor
public final class ProfileStore: ObservableObject {
    @Published public var profiles: [HeadphoneProfile] = []
    @Published public var activeProfile: HeadphoneProfile?
    
    private let importer = ProfileImporter()
    private let builtInProfilesURL: URL?
    private let userProfilesURL: URL
    private let fileManager = FileManager.default
    
    public init() {
        self.builtInProfilesURL = nil
        self.userProfilesURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Equalizer/HeadphoneProfiles/custom", isDirectory: true)
        
        loadProfiles()
        print("[ProfileStore] Perfis carregados: \(profiles.count) (built-in: \(profiles.filter(\.isBuiltIn).count), custom: \(profiles.filter { !$0.isBuiltIn }.count))")
    }
    
    /// Carrega todos os perfis (built-in + usuário). O perfil ativo começa como nil
    /// e deve ser selecionado explicitamente pelo usuário.
    public func loadProfiles() {
        let builtIn = loadBuiltInProfiles()
        let user = loadUserProfiles()
        self.profiles = builtIn + user
        // Não auto-ativar nenhum perfil: o EQ paramétrico inicia desativado.
    }
    
    /// No `.app` os recursos ficam em Contents/Resources, onde o `Bundle.module` não procura;
    /// em `swift run` e `swift test` vale o `Bundle.module`.
    private static var resourceBundle: Bundle {
        Bundle.main.url(forResource: "Equalizer_Equalizer", withExtension: "bundle").flatMap(Bundle.init(url:))
            ?? Bundle.module
    }

    /// Carrega os perfis embutidos no bundle do app.
    public func loadBuiltInProfiles() -> [HeadphoneProfile] {
        let baseNames = [
            "sony_wh1000xm4",
            "kz_zsn_pro_x",
            "huawei_freebuds_pro5"
        ]
        
        var result: [HeadphoneProfile] = []
        for baseName in baseNames {
            let bundle = Self.resourceBundle
            let url = bundle.url(forResource: baseName, withExtension: "json", subdirectory: "HeadphoneProfiles")
                   ?? bundle.url(forResource: baseName, withExtension: "json")
            guard let url = url else {
                print("[ProfileStore] Arquivo não encontrado no bundle: \(baseName).json")
                continue
            }
            do {
                var profile = try importer.importFromJSON(url: url)
                profile.isBuiltIn = true
                result.append(profile)
            } catch {
                print("[ProfileStore] Erro ao carregar perfil built-in \(baseName).json: \(error)")
            }
        }
        return result
    }
    
    /// Carrega os perfis salvos pelo usuário no diretório de Application Support.
    public func loadUserProfiles() -> [HeadphoneProfile] {
        createUserProfilesDirectoryIfNeeded()
        
        guard let enumerator = fileManager.enumerator(
            at: userProfilesURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        var result: [HeadphoneProfile] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "json" else { continue }
            do {
                var profile = try importer.importFromJSON(url: url)
                profile.isBuiltIn = false
                result.append(profile)
            } catch {
                print("Erro ao carregar perfil do usuário \(url.lastPathComponent): \(error)")
            }
        }
        return result
    }
    
    /// Salva um perfil customizado no disco.
    public func saveProfile(_ profile: HeadphoneProfile) throws {
        createUserProfilesDirectoryIfNeeded()
        
        var profileToSave = profile
        profileToSave.isBuiltIn = false
        profileToSave.updatedAt = Date()
        
        let url = userProfilesURL.appendingPathComponent("\(profileToSave.id.uuidString).json")
        try importer.exportToJSON(profile: profileToSave, to: url)
        
        if let index = profiles.firstIndex(where: { $0.id == profileToSave.id }) {
            profiles[index] = profileToSave
        } else {
            profiles.append(profileToSave)
        }
        
        objectWillChange.send()
    }
    
    /// Remove um perfil do usuário do disco e da lista.
    public func deleteProfile(_ profile: HeadphoneProfile) throws {
        guard !profile.isBuiltIn else { return }
        
        let url = userProfilesURL.appendingPathComponent("\(profile.id.uuidString).json")
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        
        profiles.removeAll { $0.id == profile.id }
        
        if activeProfile?.id == profile.id {
            activeProfile = profiles.first
        }
        
        objectWillChange.send()
    }
    
    /// Importa um perfil a partir de um arquivo externo (JSON ou AutoEQ txt).
    public func importProfile(from url: URL) throws -> HeadphoneProfile {
        let imported: HeadphoneProfile
        
        if url.pathExtension.lowercased() == "txt" {
            let text = try String(contentsOf: url, encoding: .utf8)
            let fileName = url.deletingPathExtension().lastPathComponent
            let brand = ""
            let model = fileName
            imported = try importer.importFromAutoEQ(text: text, brand: brand, model: model)
        } else {
            imported = try importer.importFromJSON(url: url)
        }
        
        try saveProfile(imported)
        return imported
    }
    
    /// Duplica um perfil existente, criando uma nova cópia customizada.
    public func duplicateProfile(_ profile: HeadphoneProfile) -> HeadphoneProfile {
        HeadphoneProfile(
            name: "\(profile.name) Copy",
            brand: profile.brand,
            model: profile.model,
            description: profile.description,
            targetCurve: profile.targetCurve,
            preampGain: profile.preampGain,
            bands: profile.bands,
            isBuiltIn: false,
            source: profile.source
        )
    }
    
    /// Define um perfil como ativo.
    public func activateProfile(_ profile: HeadphoneProfile?) {
        activeProfile = profile
    }
    
    private func createUserProfilesDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: userProfilesURL.path) {
            try? fileManager.createDirectory(
                at: userProfilesURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}
