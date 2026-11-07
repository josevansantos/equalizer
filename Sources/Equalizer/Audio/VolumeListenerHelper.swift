@preconcurrency import CoreAudio
import Foundation

/// Registra um listener CoreAudio para mudanças de volume num dispositivo de hardware.
///
/// Existe como classe separada **sem** isolamento de ator (`@MainActor`) para evitar que o
/// compilador Swift anote a closure do listener como `@MainActor`. Quando uma closure captura
/// `self` de uma classe `@MainActor`, o compilador insere `dispatch_assert_queue(main_queue)`
/// no prólogo da closure — o que causa `_dispatch_assert_queue_fail` ao CoreAudio chamá-la
/// num thread de background.
///
/// Aqui a closure interna não captura nenhum tipo `@MainActor`, portanto o compilador
/// não insere nenhuma verificação de executor. O callback é despachado para o main thread
/// explicitamente via `DispatchQueue.main.async`.
final class VolumeListenerHelper: @unchecked Sendable {

    let deviceID: AudioObjectID
    private let element: AudioObjectPropertyElement
    private let onVolumeChange: @Sendable () -> Void
    private var address: AudioObjectPropertyAddress
    private var installedBlock: AudioObjectPropertyListenerBlock?

    init(
        deviceID: AudioObjectID,
        element: AudioObjectPropertyElement,
        onVolumeChange: @escaping @Sendable () -> Void
    ) {
        self.deviceID = deviceID
        self.element = element
        self.onVolumeChange = onVolumeChange
        self.address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }

    /// Instala o listener CoreAudio. Retorna `true` se bem-sucedido.
    /// O callback `onVolumeChange` é sempre chamado no main thread.
    @discardableResult
    func install() -> Bool {
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        // Captura `cb` como plain () -> Void — sem @MainActor associado.
        // O compilador NÃO insere verificação de executor nesta closure.
        let cb: @Sendable () -> Void = onVolumeChange
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            // CoreAudio chama aqui num thread de background — sem @MainActor check.
            DispatchQueue.main.async { cb() }
        }
        guard AudioObjectAddPropertyListenerBlock(deviceID, &address, nil, block) == noErr else {
            return false
        }
        installedBlock = block
        return true
    }

    deinit {
        if let installedBlock {
            AudioObjectRemovePropertyListenerBlock(deviceID, &address, nil, installedBlock)
        }
    }
}
