@preconcurrency import CoreAudio
import Foundation

/// Representa um dispositivo de áudio físico ou virtual no macOS.
public struct AudioDevice: Identifiable, Equatable, Sendable {
    public let id: AudioObjectID
    public let uid: String
    public let name: String
    public let isOutput: Bool
    public let isInput: Bool
    public let sampleRate: Double
    
    public init(id: AudioObjectID, uid: String, name: String, isOutput: Bool, isInput: Bool, sampleRate: Double = 44100.0) {
        self.id = id
        self.uid = uid
        self.name = name
        self.isOutput = isOutput
        self.isInput = isInput
        self.sampleRate = sampleRate
    }
}
