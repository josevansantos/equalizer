import SwiftUI

public extension Color {
    // MARK: - Dracula Theme Palette

    /// Fundo principal — Dracula Background (#282a36)
    static let eqBackground      = Color(hex: "#282a36")
    /// Fundo de cards e containers — Dracula Current Line (#44475a)
    static let eqCurrentLine     = Color(hex: "#44475a")
    /// Texto principal — Dracula Foreground (#f8f8f2)
    static let eqForeground      = Color(hex: "#f8f8f2")
    /// Texto secundário / desabilitado — Dracula Comment (#6272a4)
    static let eqComment         = Color(hex: "#6272a4")
    /// Acento principal Cyan — curva EQ, sliders, ícones (#8be9fd)
    static let eqAccent          = Color(hex: "#8be9fd")
    /// Acento secundário Purple — preamp, profile (#bd93f9)
    static let eqAccentSecondary = Color(hex: "#bd93f9")
    /// Acento terciário Pink — ações, presets (#ff79c6)
    static let eqAccentTertiary  = Color(hex: "#ff79c6")
    /// Verde para status ativo — Dracula Green (#50fa7b)
    static let eqGreen           = Color(hex: "#50fa7b")
    /// Laranja para ganho positivo — Dracula Orange (#ffb86c)
    static let eqOrange          = Color(hex: "#ffb86c")
    /// Vermelho — Dracula Red (#ff5555)
    static let eqRed             = Color(hex: "#ff5555")
    /// Amarelo — Dracula Yellow (#f1fa8c)
    static let eqYellow          = Color(hex: "#f1fa8c")
    /// Cor de bypass — Dracula Comment (#6272a4)
    static let eqBypass          = Color(hex: "#6272a4")
    /// Linhas de grade do gráfico
    static let eqGrid            = Color(hex: "#44475a")

    // MARK: - Hex Init

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

public struct EQTheme {
    /// Gradiente da área sob a curva de equalização — Cyan → Purple → clear
    public static var eqCurveGradient: LinearGradient {
        LinearGradient(
            colors: [.eqAccent.opacity(0.50), .eqAccentSecondary.opacity(0.20), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Gradiente das barras FFT
    public static var fftBarGradient: LinearGradient {
        LinearGradient(
            colors: [.eqAccentSecondary.opacity(0.45), .eqAccentSecondary.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
