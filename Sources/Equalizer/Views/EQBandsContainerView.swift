import SwiftUI

/// Container horizontal que alinha todas as 10 bandas de frequência lado a lado com espaçamento uniforme.
public struct EQBandsContainerView: View {
    @ObservedObject var viewModel: EqualizerViewModel
    
    public init(viewModel: EqualizerViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        HStack(spacing: 14) {
            ForEach(viewModel.bands.indices, id: \.self) { index in
                EQBandSlider(band: $viewModel.bands[index])
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}
