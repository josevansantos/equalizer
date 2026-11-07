import SwiftUI

/// A visualização colapsada que se mescla ao notch preto do macOS e exibe status e espectro do EQ em tempo real.
public struct NotchCollapsedView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var engineManager: AudioEngineManager
    var onToggle: () -> Void

    public init(viewModel: NotchViewModel, onToggle: @escaping () -> Void) {
        self.viewModel = viewModel
        self.engineManager = viewModel.equalizerViewModel.engineManager as! AudioEngineManager
        self.onToggle = onToggle
    }

    public var body: some View {
        let isBypassed = viewModel.equalizerViewModel.isBypassed
        let mags = engineManager.levelMagnitudes
        let hasAudio = !isBypassed && mags.contains(where: { $0 > 0.01 })

        ZStack {
            Rectangle().fill(Color.black)

            HStack(spacing: 5) {
                if hasAudio {
                    // Mini espectro animado — barras Cyan
                    HStack(spacing: 1.5) {
                        ForEach(0..<4, id: \.self) { i in
                            let magIndex = min(i * 2 + 1, mags.count - 1)
                            let val = CGFloat(min(max(mags[magIndex], 0.15), 1.0))
                            Capsule()
                                .fill(Color.eqAccent)
                                .frame(width: 2.5, height: 10 * val)
                                .shadow(color: Color.eqAccent.opacity(0.5), radius: 2)
                        }
                    }
                    .frame(height: 12)
                } else {
                    Image(systemName: isBypassed ? "slider.vertical.3" : "waveform.path.ecg")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isBypassed ? .eqBypass : .eqAccent)
                }

                Text(isBypassed ? "BYPASS" : "EQ")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(isBypassed ? .eqBypass : .eqForeground)
            }
            .padding(.horizontal, 10)
        }
        .frame(width: viewModel.baseNotchWidth, height: viewModel.baseNotchHeight)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}
