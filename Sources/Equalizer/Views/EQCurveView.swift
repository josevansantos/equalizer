import SwiftUI

/// Gráfico em tempo real que desenha a curva paramétrica do equalizador com analisador de espectro FFT de fundo.
public struct EQCurveView: View {
    var bands: [EQBand]
    var magnitudes: [Float]
    var range: ClosedRange<Float> = -15.0...15.0

    public init(bands: [EQBand], magnitudes: [Float] = [], range: ClosedRange<Float> = -15.0...15.0) {
        self.bands = bands
        self.magnitudes = magnitudes
        self.range = range
    }

    public var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let minGain = range.lowerBound
            let maxGain = range.upperBound
            let gainRange = maxGain - minGain
            let zeroY = height * CGFloat((0.0 - minGain) / gainRange)

            // Barras do analisador FFT — Dracula Purple com opacidade baixa
            if !magnitudes.isEmpty {
                let magCount = magnitudes.count
                let barWidth = max(width / CGFloat(magCount) - 14.0, 8.0)

                for (i, mag) in magnitudes.enumerated() {
                    let clampedMag = min(max(mag, 0.0), 1.0)
                    guard clampedMag > 0.005 else { continue }

                    let x = width * (CGFloat(i) + 0.5) / CGFloat(magCount) - (barWidth / 2.0)
                    let barHeight = height * CGFloat(clampedMag) * 0.82
                    let y = height - barHeight

                    let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                    let path = Path(roundedRect: barRect, cornerRadius: barWidth / 3.0)

                    // Dracula Purple → transparent
                    context.fill(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [
                                Color(hex: "#bd93f9").opacity(0.35),
                                Color(hex: "#bd93f9").opacity(0.04)
                            ]),
                            startPoint: CGPoint(x: x, y: y),
                            endPoint: CGPoint(x: x, y: height)
                        )
                    )
                }
            }

            // Linhas de grade horizontais (+10, +5, 0, -5, -10 dB)
            let gridSteps: [Float] = [10.0, 5.0, 0.0, -5.0, -10.0]
            for step in gridSteps {
                let y = height * CGFloat((maxGain - step) / gainRange)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))

                if step == 0 {
                    // Linha central (0 dB) — mais destacada
                    context.stroke(
                        path,
                        with: .color(Color(hex: "#6272a4").opacity(0.7)),
                        style: StrokeStyle(lineWidth: 1.2)
                    )
                } else {
                    context.stroke(
                        path,
                        with: .color(Color(hex: "#44475a").opacity(0.6)),
                        style: StrokeStyle(lineWidth: 0.6, dash: [3, 5])
                    )
                }
            }

            // Labels de dB nas grades
            let dbLabels: [(Float, String)] = [(10.0, "+10"), (5.0, "+5"), (-5.0, "-5"), (-10.0, "-10")]
            for (step, label) in dbLabels {
                let y = height * CGFloat((maxGain - step) / gainRange)
                let text = Text(label)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#6272a4").opacity(0.55))
                context.draw(text, at: CGPoint(x: 18, y: y - 5))
            }

            guard !bands.isEmpty else { return }

            // Pontos centrais de cada banda
            let bandCount = bands.count
            var points: [CGPoint] = []
            for (index, band) in bands.enumerated() {
                let x = width * (CGFloat(index) + 0.5) / CGFloat(bandCount)
                let normalizedGain = CGFloat((maxGain - band.gain) / gainRange)
                let y = height * min(max(normalizedGain, 0.0), 1.0)
                points.append(CGPoint(x: x, y: y))
            }

            guard points.count >= 2 else { return }

            // Curva suave (Bezier)
            var curvePath = Path()
            curvePath.move(to: CGPoint(x: 0, y: points[0].y))
            curvePath.addLine(to: points[0])

            for i in 0..<points.count - 1 {
                let current = points[i]
                let next = points[i + 1]
                let midX = (current.x + next.x) / 2.0
                curvePath.addCurve(
                    to: next,
                    control1: CGPoint(x: midX, y: current.y),
                    control2: CGPoint(x: midX, y: next.y)
                )
            }

            if let lastPoint = points.last {
                curvePath.addLine(to: CGPoint(x: width, y: lastPoint.y))
            }

            // Preenchimento gradiente — Cyan → Purple → clear (Dracula)
            var fillPath = curvePath
            if points.last != nil {
                fillPath.addLine(to: CGPoint(x: width, y: zeroY))
                fillPath.addLine(to: CGPoint(x: 0, y: zeroY))
                fillPath.closeSubpath()
            }

            context.fill(fillPath, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(hex: "#8be9fd").opacity(0.45), location: 0.0),
                    .init(color: Color(hex: "#bd93f9").opacity(0.20), location: 0.55),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: height)
            ))

            // Linha da curva — Cyan com brilho
            context.stroke(
                curvePath,
                with: .color(Color(hex: "#8be9fd")),
                style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
            )

            // Pontos nas bandas ativas
            for point in points {
                let bandIndex = points.firstIndex(of: point) ?? 0
                guard bandIndex < bands.count else { continue }
                let band = bands[bandIndex]
                guard band.gain != 0 else { continue }

                let dotColor = band.gain > 0 ? Color(hex: "#ffb86c") : Color(hex: "#8be9fd")
                let dotRect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#1e1f29"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: "#44475a").opacity(0.6), lineWidth: 1)
                )
        )
    }
}
