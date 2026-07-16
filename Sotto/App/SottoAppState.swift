import Combine
import SwiftUI

@MainActor
final class SottoAppState: ObservableObject {
    static let shared = SottoAppState()

    static let speedSteps: [Float] = [0.75, 0.85, 1.0, 1.15, 1.25, 1.35]

    enum DefaultsKey {
        static let wordsSpoken = "stats.wordsSpoken"
        static let totalDictationSeconds = "stats.totalDictationSeconds"
        static let pronunciationRules = "speech.pronunciationRules"
        static let globalShortcut = "globalShortcut"
    }

    @Published var speed: Float = 1.0
    @Published var pauseForVoiceApps = true
    @Published var showMenuBarStatus = true
    @Published var status = "Preparing local voice..."
    @Published var isPaused = false
    @Published var wordsSpoken: Int
    @Published var totalDictationSeconds: Double
    @Published var latestFirstAudio: Duration?
    @Published var kokoroInstallationState: KokoroInstallationState = .checking
    @Published var kokoroInstalledProgress = 0.0
    @Published var accessibilityPermissionGranted: Bool
    @Published var statusIcon = WaveStatusIconAnimator.image(phase: 0)
    @Published var shortcut: GlobalShortcut
    @Published var shortcutError: String?
    @Published var pronunciationRules: [PronunciationRule]

    let speech = SpeechController()
    let selectionReader = SelectionReader()
    var dictationSessionStartedAt: ContinuousClock.Instant?
    lazy var waveAnimator = WaveStatusIconAnimator { [weak self] image in
        self?.statusIcon = image
    }

    var onShortcutChanged: ((GlobalShortcut) -> Void)?
    var onOpenStudio: (() -> Void)?
    var onKokoroDownloadRequired: (() -> Void)?
    var onAccessibilityPermissionRequired: (() -> Void)?

    private init() {
        wordsSpoken = UserDefaults.standard.integer(forKey: DefaultsKey.wordsSpoken)
        totalDictationSeconds = UserDefaults.standard.double(forKey: DefaultsKey.totalDictationSeconds)
        accessibilityPermissionGranted = selectionReader.isAccessibilityTrusted
        pronunciationRules = Self.loadPronunciationRules()

        if let data = UserDefaults.standard.data(forKey: DefaultsKey.globalShortcut),
           let saved = try? JSONDecoder().decode(GlobalShortcut.self, from: data) {
            shortcut = saved
        } else {
            shortcut = .default
        }
    }

    var isProcessing: Bool {
        ["Preparing", "Loading", "Reading", "Generating", "Speaking"].contains {
            status.hasPrefix($0)
        }
    }

    var speedIndex: Int {
        Self.speedSteps.indices.min {
            abs(Self.speedSteps[$0] - speed) < abs(Self.speedSteps[$1] - speed)
        } ?? 2
    }

    var canSpeak: Bool {
        kokoroInstallationState.canSpeak
    }

    func updateStatus(_ text: String) {
        status = text
        waveAnimator.setAnimating(isProcessing)
    }
}
