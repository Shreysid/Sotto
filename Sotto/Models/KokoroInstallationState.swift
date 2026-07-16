enum KokoroInstallationState: Equatable {
    case checking
    case downloadRequired
    case downloading(Double)
    case loading
    case ready
    case failed(String)

    var canSpeak: Bool {
        self == .ready
    }

    var actionTitle: String {
        switch self {
        case .checking, .loading:
            "Checking Kokoro"
        case .downloadRequired:
            "Download Kokoro"
        case .downloading:
            "Downloading Kokoro"
        case .ready:
            "Speak Selection"
        case .failed:
            "Retry Kokoro Download"
        }
    }

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }

    var downloadProgress: Double? {
        if case let .downloading(progress) = self {
            return min(max(progress, 0), 1)
        }
        return nil
    }
}
