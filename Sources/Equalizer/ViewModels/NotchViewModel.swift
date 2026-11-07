import SwiftUI
import Combine

/// Gerencia o ciclo de vida e transições animadas entre os estados do painel no notch.
@MainActor
public class NotchViewModel: ObservableObject {
    @Published public var state: NotchState = .collapsed
    @Published public var isHovering: Bool = false
    @Published public var equalizerViewModel: EqualizerViewModel = EqualizerViewModel()
    
    /// Largura base do notch na tela ativa ou tamanho padrão.
    public var baseNotchWidth: CGFloat {
        ScreenHelper.activeScreen?.notchSize.width ?? 200.0
    }
    
    /// Altura base do notch na tela ativa.
    public var baseNotchHeight: CGFloat {
        ScreenHelper.activeScreen?.notchSize.height ?? 32.0
    }
    
    /// Largura alvo dependendo do estado.
    public var targetWidth: CGFloat {
        state == .expanded ? 680.0 : baseNotchWidth
    }
    
    /// Altura alvo dependendo do estado.
    public var targetHeight: CGFloat {
        state == .expanded ? 450.0 : baseNotchHeight
    }
    
    public init() {}
    
    /// Alterna suavemente entre colapsado e expandido com animação de mola.
    public func toggleExpand() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78, blendDuration: 0)) {
            if state == .collapsed {
                state = .expanded
            } else {
                state = .collapsed
            }
        }
    }
    
    /// Expande o painel flutuante.
    public func expand() {
        guard state != .expanded else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78, blendDuration: 0)) {
            state = .expanded
        }
    }
    
    /// Colapsa o painel para dentro do notch.
    public func collapse() {
        guard state != .collapsed else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78, blendDuration: 0)) {
            state = .collapsed
        }
    }
}
