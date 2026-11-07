import SwiftUI
import ServiceManagement

/// Painel de Configurações do Equalizer: Inicialização com sistema, atalhos globais, visualização e Sobre.
public struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("enableFFTVisualization") private var enableFFTVisualization: Bool = true

    @State private var selectedTab: SettingsTab = .general

    public enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case audio = "Audio & DSP"
        case shortcuts = "Shortcuts"
        case about = "About"
        public var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundColor(selectedTab == tab ? .eqForeground : .eqComment)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selectedTab == tab ? Color.eqCurrentLine : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(
                                                selectedTab == tab ? Color.eqAccent.opacity(0.35) : Color.clear,
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: selectedTab)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background(Color.eqBackground)

            Rectangle()
                .fill(Color.eqCurrentLine.opacity(0.8))
                .frame(height: 1)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .general:   generalSection
                    case .audio:     audioSection
                    case .shortcuts: shortcutsSection
                    case .about:     aboutSection
                    }
                }
                .padding(22)
            }
            .background(Color.eqBackground)
        }
        .frame(width: 460, height: 360)
        .background(Color.eqBackground)
        .foregroundColor(.eqForeground)
        .onChange(of: launchAtLogin) { _, newValue in
            toggleLaunchAtLogin(enabled: newValue)
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("System Integration")

            settingsRow {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .tint(.eqAccent)
                Text("Start automatically with macOS")
                    .font(.caption)
                    .foregroundColor(.eqComment)
            }

            Rectangle().fill(Color.eqCurrentLine.opacity(0.6)).frame(height: 1)

            sectionHeader("Visualization")

            settingsRow {
                Toggle("Enable Real-time FFT Spectrum Analyzer", isOn: $enableFFTVisualization)
                    .toggleStyle(.checkbox)
                    .tint(.eqAccent)
            }

            Text("Displays live frequency spectrum bars behind the EQ curve.")
                .font(.caption)
                .foregroundColor(.eqComment)
        }
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Core Audio Tap Engine")

            VStack(spacing: 0) {
                infoRow(label: "Engine", value: "Running (Core Audio Process Tap)", valueColor: .eqGreen)
                Rectangle().fill(Color.eqCurrentLine.opacity(0.5)).frame(height: 1).padding(.horizontal, 12)
                infoRow(label: "Pipeline", value: "64-Bit Float · vDSP Accelerate")
                Rectangle().fill(Color.eqCurrentLine.opacity(0.5)).frame(height: 1).padding(.horizontal, 12)
                infoRow(label: "FFT", value: "1024 Samples · Hann Window")
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.eqCurrentLine.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.eqComment.opacity(0.25), lineWidth: 1)
                    )
            )

            Text("Uses native macOS 14.2+ AudioHardwareCreateProcessTap — no kernel extensions or virtual audio drivers required.")
                .font(.caption)
                .foregroundColor(.eqComment)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Global Keyboard Shortcuts")

            VStack(spacing: 0) {
                shortcutRow(title: "Toggle Notch Window", shortcut: "⌘ + ⌥ + E")
                Rectangle().fill(Color.eqCurrentLine.opacity(0.5)).frame(height: 1).padding(.horizontal, 12)
                shortcutRow(title: "Bypass Equalizer", shortcut: "⌘ + ⌥ + B")
                Rectangle().fill(Color.eqCurrentLine.opacity(0.5)).frame(height: 1).padding(.horizontal, 12)
                shortcutRow(title: "Reset All Bands to 0 dB", shortcut: "⌘ + ⌥ + R")
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.eqCurrentLine.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.eqComment.opacity(0.25), lineWidth: 1)
                    )
            )

            Text("Shortcuts function globally across macOS when Equalizer is running in the background.")
                .font(.caption)
                .foregroundColor(.eqComment)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.eqAccentSecondary.opacity(0.3), Color.eqBackground],
                            center: .center,
                            startRadius: 10,
                            endRadius: 44
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.eqAccent, .eqAccentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.top, 4)

            Text("Equalizer for macOS")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.eqForeground)

            Text("Version 1.0.0 · Build 2026.07")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.eqComment)

            Text("A native, non-intrusive system-wide audio equalizer residing right in the macOS notch. Built exclusively using Swift, SwiftUI, AppKit, and Core Audio.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(.eqForeground.opacity(0.75))
                .padding(.horizontal, 20)

            Spacer(minLength: 8)

            Text("© 2026 Equalizer Project")
                .font(.system(size: 10))
                .foregroundColor(.eqComment.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color.eqAccent)
                .frame(width: 3, height: 14)
                .cornerRadius(1.5)
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.eqAccent)
        }
    }

    @ViewBuilder
    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.eqCurrentLine.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.eqComment.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func infoRow(label: String, value: String, valueColor: Color = Color(hex: "#f8f8f2").opacity(0.8)) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.eqComment)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func shortcutRow(title: String, shortcut: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.eqForeground.opacity(0.85))
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.eqAccentSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.eqCurrentLine)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.eqAccentSecondary.opacity(0.4), lineWidth: 1)
                        )
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Erro ao atualizar Launch at Login via SMAppService: \(error.localizedDescription)")
        }
    }
}
