import AppKit

extension SottoAppState {
    func setSpeedIndex(_ index: Int) {
        let boundedIndex = min(max(index, 0), Self.speedSteps.count - 1)
        setSpeed(Self.speedSteps[boundedIndex])
    }

    func setSpeed(_ value: Float) {
        let nearest = Self.speedSteps.min { abs($0 - value) < abs($1 - value) } ?? 1.0
        speed = nearest
        Task { await speech.setSpeed(nearest) }
    }

    func setShortcut(_ shortcut: GlobalShortcut) {
        self.shortcut = shortcut
        shortcutError = nil
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.globalShortcut)
        }
        onShortcutChanged?(shortcut)
    }

    func setShortcutRegistrationError(_ message: String?) {
        shortcutError = message
    }

    func stopForVoiceApplication(bundleIdentifier: String?) {
        guard pauseForVoiceApps else { return }
        let voiceApps: Set<String> = [
            "com.apple.Siri", "com.openai.chat", "com.anthropic.claudefordesktop",
            "us.zoom.xos", "com.apple.FaceTime", "com.microsoft.teams2",
            "com.hnc.Discord", "com.tinyspeck.slackmacgap",
        ]
        guard let bundleIdentifier, voiceApps.contains(bundleIdentifier) else { return }
        stopSpeaking()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    func openStudio() {
        onOpenStudio?()
    }
}
