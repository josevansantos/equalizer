import SwiftUI

/// Componente de controle deslizante vertical para uma banda individual do equalizador.
public struct EQBandSlider: View {
    @Binding var band: EQBand
    var range: ClosedRange<Float> = -15.0...15.0

    @State private var isDragging: Bool = false

    public init(band: Binding<EQBand>, range: ClosedRange<Float> = -15.0...15.0) {
        self._band = band
        self.range = range
    }

    /// Cor semântica do thumb e do preenchimento com base no ganho atual
    private var gainColor: Color {
        if isDragging { return .eqAccentSecondary }
        if band.gain > 0 { return .eqOrange }
        if band.gain < 0 { return .eqAccent }
        return .eqComment
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Valor de ganho atual em dB (topo)
            Text(formattedGain)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(band.gain == 0 ? .eqComment.opacity(0.5) : gainColor)
                .frame(height: 13)

            // Trilho vertical do slider
            GeometryReader { geometry in
                let trackHeight = geometry.size.height
                let normalizedValue = CGFloat((band.gain - range.lowerBound) / (range.upperBound - range.lowerBound))
                let thumbOffset = trackHeight * (1.0 - normalizedValue)
                let zeroOffset = trackHeight * CGFloat((0.0 - range.lowerBound) / (range.upperBound - range.lowerBound))

                ZStack(alignment: .top) {
                    // Trilho de fundo
                    Capsule()
                        .fill(Color.eqCurrentLine)
                        .frame(width: 4)
                        .frame(maxWidth: .infinity)

                    // Linha central (0 dB)
                    Rectangle()
                        .fill(Color.eqComment.opacity(0.5))
                        .frame(height: 1)
                        .offset(y: trackHeight - zeroOffset)

                    // Preenchimento entre 0 dB e o thumb
                    let startY = min(trackHeight - zeroOffset, thumbOffset)
                    let barHeight = abs((trackHeight - zeroOffset) - thumbOffset)
                    Capsule()
                        .fill(band.gain == 0 ? Color.clear : gainColor.opacity(0.7))
                        .frame(width: 4, height: max(barHeight, 2))
                        .offset(y: startY)
                        .frame(maxWidth: .infinity)

                    // Thumb
                    Circle()
                        .fill(gainColor)
                        .frame(width: 13, height: 13)
                        .shadow(color: gainColor.opacity(isDragging ? 0.7 : 0.4), radius: isDragging ? 5 : 3, x: 0, y: 1)
                        .scaleEffect(isDragging ? 1.15 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
                        .offset(x: (geometry.size.width - 13) / 2.0, y: thumbOffset - 6.5)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let progress = 1.0 - Float(value.location.y / trackHeight)
                            let clampedProgress = min(max(progress, 0.0), 1.0)
                            let newGain = range.lowerBound + clampedProgress * (range.upperBound - range.lowerBound)
                            // Snap suave no 0 dB
                            if abs(newGain) < 0.4 {
                                band.gain = 0.0
                            } else {
                                band.gain = (newGain * 10).rounded() / 10.0
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        band.gain = 0.0
                    }
                }
            }
            .frame(width: 28)

            // Frequência (base)
            Text(formattedFrequency)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.eqComment)
                .frame(height: 13)
        }
    }

    private var formattedGain: String {
        if band.gain > 0 { return String(format: "+%.1f", band.gain) }
        if band.gain < 0 { return String(format: "%.1f", band.gain) }
        return "0.0"
    }

    private var formattedFrequency: String {
        if band.frequency >= 1000 {
            let k = band.frequency / 1000
            return k == k.rounded() ? String(format: "%.0fk", k) : String(format: "%.1fk", k)
        } else {
            return String(format: "%.0f", band.frequency)
        }
    }
}
