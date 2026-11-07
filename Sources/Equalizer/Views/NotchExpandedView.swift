import SwiftUI

/// A visualização expandida que abriga a interface gráfica completa do equalizador paramétrico de 10 bandas.
public struct NotchExpandedView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var engineManager: AudioEngineManager
    var onCollapse: () -> Void

    public init(viewModel: NotchViewModel, onCollapse: @escaping () -> Void) {
        self.viewModel = viewModel
        self.engineManager = viewModel.equalizerViewModel.engineManager as! AudioEngineManager
        self.onCollapse = onCollapse
    }

    public var body: some View {
        VStack(spacing: 10) {
            // Topo: Cabeçalho
            EQHeaderView(viewModel: viewModel.equalizerViewModel, onCollapse: onCollapse)
                .padding(.top, 10)
                .padding(.horizontal, 20)

            // Centro: Curva + Sliders sobrepostos
            ZStack {
                EQCurveView(
                    bands: viewModel.equalizerViewModel.bands,
                    magnitudes: engineManager.levelMagnitudes
                )

                EQBandsContainerView(viewModel: viewModel.equalizerViewModel)
            }
            .frame(height: 280)
            .padding(.horizontal, 16)

            // Base: Rodapé
            EQFooterView(viewModel: viewModel.equalizerViewModel)
                .padding(.bottom, 14)
                .padding(.horizontal, 20)
        }
        .frame(width: viewModel.targetWidth, height: viewModel.targetHeight)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0),
                style: .continuous
            )
            .fill(Color.eqBackground)
            .overlay(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0),
                    style: .continuous
                )
                .stroke(
                    LinearGradient(
                        colors: [Color.eqAccent.opacity(0.25), Color.eqAccentSecondary.opacity(0.15), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: Color.black.opacity(0.75), radius: 32, x: 0, y: 16)
        )
    }
}
