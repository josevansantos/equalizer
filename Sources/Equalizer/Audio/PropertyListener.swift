@preconcurrency import CoreAudio
import Foundation

/// Observa uma propriedade Core Audio e chama `handler` na main queue.
///
/// Sem isolamento de ator: uma closure criada dentro de uma classe `@MainActor` herda esse
/// isolamento, e o Swift 6 derruba o app se o Core Audio a chamar em outra thread.
final class PropertyListener: @unchecked Sendable {
    private let objectID: AudioObjectID
    private var address: AudioObjectPropertyAddress
    private let block: AudioObjectPropertyListenerBlock

    init?(objectID: AudioObjectID, selector: AudioObjectPropertySelector, handler: @escaping @Sendable () -> Void) {
        self.objectID = objectID
        self.address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        self.block = { _, _ in handler() }
        guard AudioObjectAddPropertyListenerBlock(objectID, &address, DispatchQueue.main, block) == noErr else {
            return nil
        }
    }

    deinit {
        AudioObjectRemovePropertyListenerBlock(objectID, &address, DispatchQueue.main, block)
    }
}
