import Foundation

/// Representa o estado visual do painel flutuante no notch.
public enum NotchState: Equatable, Sendable {
    /// Painel colapsado dentro do notch visível como um indicador ou miniatura.
    case collapsed
    /// Painel expandido exibindo a interface principal do equalizador.
    case expanded
    
    /// Retorna `true` se o painel estiver expandido.
    public var isExpanded: Bool {
        self == .expanded
    }
}
