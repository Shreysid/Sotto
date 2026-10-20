import Foundation

enum SpeechError: LocalizedError {
    case noAudio
    case noSections
    case audioOutputUnavailable(code: Int)

    var errorDescription: String? {
        switch self {
        case .noAudio: "The voice engine returned no playable audio"
        case .noSections: "No readable section is available"
        case .audioOutputUnavailable(let code):
            "macOS could not start any available audio output (\(code)). Sotto will reconnect on the next request."
        }
    }
}

extension Duration {
    nonisolated var seconds: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    var short: String {
        formatted(.units(allowed: [.seconds, .milliseconds], width: .abbreviated, maximumUnitCount: 1))
    }
}
