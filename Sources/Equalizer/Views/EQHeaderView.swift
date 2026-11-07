import SwiftUI

/// Cabeçalho superior com controle de Bypass, título, seletores de perfil/preset e ações rápidas.
public struct EQHeaderView: View {
    @ObservedObject var viewModel: EqualizerViewModel
    var onCollapse: () -> Void
    @State private var isShowingProfileList = false
    @State private var isShowingSettings = false

    public init(viewModel: EqualizerViewModel, onCollapse: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onCollapse = onCollapse
    }

    public var body: some View {
        HStack(spacing: 10) {
            // Botão de Bypass
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isBypassed.toggle()
                }
            }) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(viewModel.isBypassed ? Color.eqBypass : Color.eqGreen)
                        .frame(width: 7, height: 7)
                        .shadow(color: viewModel.isBypassed ? .clear : Color.eqGreen.opacity(0.7), radius: 4)
                    Text(viewModel.isBypassed ? "BYPASS" : "ACTIVE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(viewModel.isBypassed ? .eqBypass : .eqGreen)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.eqCurrentLine.opacity(0.8))
                        .overlay(
                            Capsule().stroke(
                                viewModel.isBypassed ? Color.eqBypass.opacity(0.5) : Color.eqGreen.opacity(0.4),
                                lineWidth: 1
                            )
                        )
                )
            }
            .buttonStyle(.plain)

            // Título e logo
            HStack(spacing: 5) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.eqAccentSecondary)
                    .font(.system(size: 13, weight: .bold))
                Text("Equalizer")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.eqForeground)
            }

            Spacer()

            // Seletor de Presets
            Menu {
                ForEach(viewModel.presetStore.presets) { preset in
                    Button(preset.name) {
                        viewModel.loadPreset(preset)
                    }
                }
                Divider()
                Button("Nenhum (Remover Preset)") {
                    viewModel.loadPreset(nil)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10))
                        .foregroundColor(.eqAccentTertiary)
                    Text(viewModel.selectedPreset?.name ?? "Preset")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(viewModel.selectedPreset != nil ? .eqAccentTertiary : .eqComment)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.eqCurrentLine.opacity(0.8))
                        .overlay(
                            Capsule().stroke(
                                viewModel.selectedPreset != nil ? Color.eqAccentTertiary.opacity(0.5) : Color.eqComment.opacity(0.3),
                                lineWidth: 1
                            )
                        )
                )
            }
            .menuStyle(.button)
            .buttonStyle(.plain)

            // Seletor de Perfis de Fone
            Menu {
                ForEach(viewModel.profileStore.profiles) { profile in
                    Button(profile.name) {
                        viewModel.loadHeadphoneProfile(profile)
                    }
                }
                Divider()
                Button("Nenhum Perfil") {
                    viewModel.loadHeadphoneProfile(nil)
                }
                Divider()
                Button("Manage Profiles...") {
                    isShowingProfileList = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "headphones")
                        .font(.system(size: 10))
                        .foregroundColor(.eqAccentSecondary)
                    Text(viewModel.selectedProfile?.name ?? "Profile")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(viewModel.selectedProfile != nil ? .eqAccentSecondary : .eqComment)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.eqCurrentLine.opacity(0.8))
                        .overlay(
                            Capsule().stroke(
                                viewModel.selectedProfile != nil ? Color.eqAccentSecondary.opacity(0.5) : Color.eqComment.opacity(0.3),
                                lineWidth: 1
                            )
                        )
                )
            }
            .menuStyle(.button)
            .buttonStyle(.plain)

            // Botão de Reset
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.resetAllBands()
                }
            }) {
                Text("Reset")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.eqComment)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.eqCurrentLine.opacity(0.8))
                            .overlay(Capsule().stroke(Color.eqComment.opacity(0.3), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            // Botão de Configurações
            Button(action: { isShowingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.eqComment)
            }
            .buttonStyle(.plain)

            // Botão de fechar
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.eqComment.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Fechar Equalizer")

            // Botão de colapsar no notch
            Button(action: onCollapse) {
                Image(systemName: "chevron.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.eqAccent.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $isShowingProfileList) {
            ProfileListView(store: viewModel.profileStore)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }
}
