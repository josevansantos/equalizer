import SwiftUI
import UniformTypeIdentifiers

/// Lista de perfis de fones de ouvido agrupados por Built-in e Custom, com importação AutoEQ/JSON.
struct ProfileListView: View {
    @ObservedObject var store: ProfileStore
    @State private var selectedProfile: HeadphoneProfile?
    @State private var isShowingEditor = false
    @State private var isShowingImporter = false
    @State private var importErrorMessage: String?
    
    struct AlertItem: Identifiable {
        let id = UUID()
        let message: String
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Headphone Profiles")
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    Button(action: { isShowingImporter = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import...")
                        }
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: {
                        selectedProfile = nil
                        isShowingEditor = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("New")
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            List {
                Section("Built-in") {
                    ForEach(store.profiles.filter(\.isBuiltIn)) { profile in
                        profileRow(profile)
                    }
                }
                
                Section("My Profiles") {
                    ForEach(store.profiles.filter { !$0.isBuiltIn }) { profile in
                        profileRow(profile)
                    }
                }
            }
            .listStyle(.plain)
        }
        .padding()
        .frame(width: 380, height: 440)
        .background(Color.eqBackground)
        .sheet(isPresented: $isShowingEditor) {
            ProfileEditorView(
                profile: selectedProfile ?? HeadphoneProfile(
                    name: "New Profile",
                    brand: "",
                    model: "",
                    bands: [ProfileBand(filterType: .peak, frequency: 1000, gain: 0)]
                ),
                onSave: { profile in
                    try? store.saveProfile(profile)
                    store.activateProfile(profile)
                    isShowingEditor = false
                }
            )
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.json, .plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedURL = try result.get().first else { return }
                guard selectedURL.startAccessingSecurityScopedResource() else { return }
                defer { selectedURL.stopAccessingSecurityScopedResource() }
                
                let imported = try store.importProfile(from: selectedURL)
                store.activateProfile(imported)
            } catch {
                importErrorMessage = "Failed to import profile: \(error.localizedDescription)"
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                Task { @MainActor in
                    do {
                        let imported = try store.importProfile(from: url)
                        store.activateProfile(imported)
                    } catch {
                        importErrorMessage = "Drop failed: \(error.localizedDescription)"
                    }
                }
            }
            return true
        }
        .alert(item: Binding<AlertItem?>(
            get: { importErrorMessage.map { AlertItem(message: $0) } },
            set: { _ in importErrorMessage = nil }
        )) { alert in
            Alert(
                title: Text("Import Error"),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func profileRow(_ profile: HeadphoneProfile) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 13, weight: .medium))
                Text("\(profile.bands.count) bands · \(profile.targetCurve)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if store.activeProfile?.id == profile.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.eqAccent)
            }
            
            Button(action: {
                selectedProfile = profile
                isShowingEditor = true
            }) {
                Image(systemName: "pencil.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .padding(.leading, 4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.activateProfile(profile)
            selectedProfile = profile
        }
    }
}
