import AppKit
import SwiftUI

@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    public let viewModel = NotchViewModel()
    public let notchHelper = NotchHelper()
    private var notchPanel: NSPanel?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Precaução: o app processa áudio em segundo plano, sem janelas comuns, e não deve ser
        // tratado como ocioso. Encerrar sem aviso também pularia o applicationWillTerminate.
        ProcessInfo.processInfo.disableAutomaticTermination("Equalizer processa o áudio do sistema continuamente")
        ProcessInfo.processInfo.disableSuddenTermination()

        // Cria a janela flutuante ancorada no notch e a mantém em exibição
        notchPanel = notchHelper.createNotchPanel(viewModel: viewModel) {
            NotchContainerView(viewModel: self.viewModel, notchHelper: self.notchHelper)
        }
        
        notchPanel?.orderFront(nil)
        
        // Inicia o motor de áudio e a interceptação DSP no boot da aplicação
        viewModel.equalizerViewModel.engineManager.startEngine()
        
        // Sincroniza todas as bandas de ganho e o perfil paramétrico inicial no motor ativo
        viewModel.equalizerViewModel.syncToEngine()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        // Restaura o dispositivo de saída real e remove o aggregate device/tap
        viewModel.equalizerViewModel.engineManager.stopEngine()
    }
}
