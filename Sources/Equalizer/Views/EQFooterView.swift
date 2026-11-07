import SwiftUI

/// Rodapé inferior com controles de Preamp Gain, Volume de Saída e seletor de dispositivo de saída.
public struct EQFooterView: View {
    @ObservedObject var viewModel: EqualizerViewModel
    @ObservedObject var engineManager: AudioEngineManager

    public init(viewModel: EqualizerViewModel) {
        self.viewModel = viewModel
        self.engineManager = viewModel.engineManager as! AudioEngineManager
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Controle de Preamp Gain global (-15 a +15 dB)
            HStack(spacing: 7) {
                Text("Preamp")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.eqComment)

                Slider(
                    value: $viewModel.preampGain,
                    in: -15.0...15.0,
                    step: 0.1
                )
                .frame(width: 90)
                .tint(.eqAccentSecondary)

                Text(formattedPreamp)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(viewModel.preampGain == 0 ? .eqComment : .eqAccentSecondary)
                    .frame(width: 52, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.eqCurrentLine.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.eqAccentSecondary.opacity(viewModel.preampGain != 0 ? 0.35 : 0.12), lineWidth: 1)
                    )
            )

            // Controle de Volume de Saída (0% a 100%)
            HStack(spacing: 7) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.eqAccent)
                    .frame(width: 16)
                    .animation(.easeInOut(duration: 0.15), value: volumeIcon)

                Slider(
                    value: Binding(
                        get: { viewModel.outputVolume },
                        set: { viewModel.setOutputVolume($0) }
                    ),
                    in: 0.0...1.0
                )
                .frame(width: 90)
                .tint(.eqAccent)

                Text(String(format: "%d%%", Int(viewModel.outputVolume * 100)))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.eqAccent.opacity(0.8))
                    .frame(width: 32, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.eqCurrentLine.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.eqAccent.opacity(0.25), lineWidth: 1)
                    )
            )

            Spacer()

            // Seletor/Info de Saída (Output CoreAudio)
            Menu {
                Text("Dispositivo de Saída:")
                ForEach(engineManager.deviceManager.outputDevices) { device in
                    Button("\(device.name)\(device.name == engineManager.activeDeviceName ? " ✓" : "")") {
                        try? engineManager.deviceManager.setDefaultOutputDevice(device)
                    }
                }
                Divider()
                Button("Refresh Devices") {
                    engineManager.deviceManager.refreshDevices()
                }
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(engineManager.isRunning ? Color.eqGreen : Color.eqRed)
                        .frame(width: 6, height: 6)
                        .shadow(color: engineManager.isRunning ? Color.eqGreen.opacity(0.6) : .clear, radius: 3)
                    Text(shortName(for: engineManager.activeDeviceName))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.eqForeground.opacity(0.75))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.eqCurrentLine.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.eqComment.opacity(0.25), lineWidth: 1)
                        )
                )
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
    }

    private var formattedPreamp: String {
        if viewModel.preampGain > 0 {
            return String(format: "+%.1f dB", viewModel.preampGain)
        } else if viewModel.preampGain < 0 {
            return String(format: "%.1f dB", viewModel.preampGain)
        } else {
            return "0.0 dB"
        }
    }

    private var volumeIcon: String {
        switch viewModel.outputVolume {
        case 0: return "speaker.slash.fill"
        case 0..<0.33: return "speaker.wave.1.fill"
        case 0.33..<0.66: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    private func shortName(for name: String) -> String {
        if name.count > 18 { return String(name.prefix(16)) + "…" }
        return name
    }
}
