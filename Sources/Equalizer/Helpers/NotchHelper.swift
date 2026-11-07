@preconcurrency import AppKit
import SwiftUI

/// Painel que pode ocupar a faixa do notch e receber digitação (ex.: editor de perfis).
private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    /// O AppKit empurra janelas para baixo da barra de menus; aqui o topo da tela é o lugar certo.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// Gerencia a instância de NSPanel e sua geometria/comportamento na tela do macOS.
@MainActor
public class NotchHelper {
    private var panel: NSPanel?
    private var globalEventMonitor: Any?
    private var screenChangeObserver: NSObjectProtocol?
    private weak var viewModel: NotchViewModel?
    
    public init() {}
    
    isolated deinit {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// Cria e configura o painel flutuante do notch.
    public func createNotchPanel<Content: View>(viewModel: NotchViewModel, content: () -> Content) -> NSPanel {
        self.viewModel = viewModel
        
        let initialFrame = ScreenHelper.activeNotchFrame
        let panel = NotchPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Nesta ordem: `isFloatingPanel = true` redefine o nível da janela para `.floating`.
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.becomesKeyOnlyIfNeeded = true
        panel.canHide = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        // Impede que o conteúdo SwiftUI redimensione o painel automaticamente.
        panel.contentView?.autoresizingMask = [.width, .height]
        panel.contentView?.translatesAutoresizingMaskIntoConstraints = true
        
        let hostingView = NSHostingView(rootView: content())
        hostingView.frame = NSRect(origin: .zero, size: initialFrame.size)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        
        self.panel = panel
        setupGlobalMonitors()
        setupScreenChangeObservers()
        
        // Garante posicionamento correto após a criação.
        updatePosition(animated: false)
        
        return panel
    }
    
    /// Atualiza a geometria e posição do painel de acordo com o estado do ViewModel.
    public func updatePosition(animated: Bool = true) {
        guard let panel = panel, let viewModel = viewModel else { return }
        
        let screen = ScreenHelper.activeScreen ?? NSScreen.main
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let notchFrame = screen?.notchFrame ?? ScreenHelper.activeNotchFrame
        let targetWidth = viewModel.targetWidth
        let targetHeight = viewModel.targetHeight
        
        let targetFrame: NSRect
        if viewModel.state == .collapsed {
            // Estado colapsado: encaixa exatamente na área do notch.
            targetFrame = notchFrame
        } else {
            // Estado expandido: centralizado horizontalmente, topo alinhado à base do notch.
            let x = screenFrame.midX - (targetWidth / 2.0)
            let y = notchFrame.minY - targetHeight
            targetFrame = NSRect(x: x, y: y, width: targetWidth, height: targetHeight)
        }
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
        }
    }
    
    private func setupGlobalMonitors() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let viewModel = self.viewModel else { return }
                if viewModel.state == .expanded {
                    viewModel.collapse()
                    self.updatePosition(animated: true)
                }
            }
        }
    }
    
    private func setupScreenChangeObservers() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updatePosition(animated: false)
            }
        }
    }
}
