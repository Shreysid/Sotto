import Foundation

enum SpeechError: LocalizedError {
    case noSections

    var errorDescription: String? {
        switch self {
        case .noSections: "No readable section is available"
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
