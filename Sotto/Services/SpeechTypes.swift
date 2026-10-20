import Foundation

enum SpeechError: LocalizedError {
    case noSections
    case audioOutputUnavailable(code: Int)

    var errorDescription: String? {
        switch self {
        case .noSections: "No readable section is available"
        case .audioOutputUnavailable(let code):
            "macOS could not start the selected audio output (\(code)). Choose a working output in System Settings → Sound, then try again."
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
