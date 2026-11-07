import AppKit

public extension NSScreen {
    /// Verifica se a tela possui um notch físico (área de entalhe na parte superior).
    var hasNotch: Bool {
        guard #available(macOS 12.0, *) else { return false }
        return safeAreaInsets.top > 24
    }
    
    /// Altura real da barra de menus/notch na tela.
    /// Usa a diferença entre o frame total e o frame visível para obter a altura exata.
    var menuBarHeight: CGFloat {
        return frame.maxY - visibleFrame.maxY
    }
    
    /// Tamanho exato ou estimado do notch.
    var notchSize: NSSize {
        if hasNotch {
            // Em telas com notch, a largura pode ser calculada pelas áreas auxiliares.
            guard #available(macOS 12.0, *) else { return NSSize(width: 200, height: menuBarHeight) }
            if let leftArea = auxiliaryTopLeftArea, let rightArea = auxiliaryTopRightArea,
               leftArea != .zero, rightArea != .zero {
                let width = rightArea.minX - leftArea.maxX
                return NSSize(width: max(width, 180), height: max(menuBarHeight, 32))
            }
            return NSSize(width: 210, height: max(menuBarHeight, 32))
        } else {
            // Tamanho simulado para telas sem notch (monitor externo)
            return NSSize(width: 200, height: max(menuBarHeight, 32))
        }
    }
    
    /// O retângulo do notch em coordenadas globais da tela (AppKit: y=0 no fundo da tela).
    /// O notch físico está no topo absoluto da tela (frame.maxY), não em visibleFrame.maxY
    /// (que é a borda inferior da barra de menus, abaixo do notch).
    var notchFrame: NSRect {
        let size = notchSize
        let screenFrame = frame
        let x = screenFrame.midX - (size.width / 2.0)
        // CORRETO: frame.maxY = topo físico da tela. O retângulo do notch começa em
        // frame.maxY - height (base inferior do notch no sistema de coordenadas AppKit).
        let y = screenFrame.maxY - size.height
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}

public struct ScreenHelper {
    /// Retorna a tela com o cursor ou a tela principal (`NSScreen.main`).
    public static var activeScreen: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
    }
    
    /// Verifica se a tela ativa atual tem notch.
    public static var activeScreenHasNotch: Bool {
        return activeScreen?.hasNotch ?? false
    }
    
    /// Geometria do notch na tela ativa.
    public static var activeNotchFrame: NSRect {
        return activeScreen?.notchFrame ?? NSRect(x: 0, y: 0, width: 200, height: 32)
    }
}
