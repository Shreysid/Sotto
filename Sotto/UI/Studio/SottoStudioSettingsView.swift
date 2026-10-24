import SwiftUI

struct StudioSettingsView: View {
    @EnvironmentObject private var state: SottoAppState

    var body: some View {
        StudioPage(title: StudioSection.settings.title, symbol: StudioSection.settings.symbol) {
            VStack(spacing: 28) {
                StudioSettingsGroup {
                    voiceEngineRow
                    accessibilityRow
                    playbackSpeedRow
                    pauseForVoiceAppsRow
                    menuBarStatusRow
                }

                StudioSettingsGroup {
                    keyboardShortcutRow
                    voiceStatusRow
                }
            }
        }
    }

    private var voiceEngineRow: some View {
        StudioSettingRow("Voice engine", detail: "Kokoro is the local voice engine for this version of Sotto.") {
            VStack(alignment: .trailing, spacing: 7) {
                Text(state.status)
                    .foregroundStyle(.secondary)
                if let progress = state.kokoroInstallationState.downloadProgress {
                    ProgressView(value: progress) {
                        Text("\(Int((progress * 100).rounded()))% downloaded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .controlSize(.small)
                } else if state.kokoroInstallationState == .loading {
                    ProgressView("Loading")
                        .controlSize(.small)
                } else if state.canSpeak {
                    Button("Delete Kokoro Model", role: .destructive, action: state.deleteKokoro)
                } else if !state.canSpeak {
                    Button(state.kokoroInstallationState.actionTitle, action: state.downloadKokoro)
                }
            }
        }
    }

    private var accessibilityRow: some View {
        StudioSettingRow(
            "Accessibility",
            detail: "Required to read selected text and respond to the global shortcut."
        ) {
            if state.accessibilityPermissionGranted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Open Accessibility Settings", action: state.openAccessibilitySettings)
            }
        }
    }

    private var playbackSpeedRow: some View {
        StudioSettingRow("Playback speed", detail: "Used for new selections and applied immediately during playback.") {
            VStack(alignment: .trailing, spacing: 5) {
                Slider(value: speedIndex, in: 0...Double(SottoAppState.speedSteps.count - 1), step: 1)
                Text("\(state.speed, specifier: "%.2f")x")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pauseForVoiceAppsRow: some View {
        StudioSettingRow("Pause for voice apps", detail: "Stop when a supported calling or voice app becomes active.") {
            Toggle("Pause for voice apps", isOn: $state.pauseForVoiceApps)
                .labelsHidden()
        }
    }

    private var menuBarStatusRow: some View {
        StudioSettingRow("Menu bar status", detail: "Show the live playback state in the Sotto menu.") {
            Toggle("Menu bar status", isOn: $state.showMenuBarStatus)
                .labelsHidden()
        }
    }

    private var keyboardShortcutRow: some View {
        StudioSettingRow("Keyboard shortcut", detail: "Choose the global shortcut used to speak selected text.") {
            VStack(alignment: .trailing, spacing: 5) {
                ShortcutRecorder(shortcut: shortcutBinding)
                    .frame(width: 150, height: 26)
                if let shortcutError = state.shortcutError {
                    Text(shortcutError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var voiceStatusRow: some View {
        StudioSettingRow("Voice status", detail: "Current local model state.") {
            Text(state.status)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var speedIndex: Binding<Double> {
        Binding(
            get: { Double(state.speedIndex) },
            set: { state.setSpeedIndex(Int($0.rounded())) }
        )
    }

    private var shortcutBinding: Binding<GlobalShortcut> {
        Binding(get: { state.shortcut }, set: { state.setShortcut($0) })
    }
}

struct StudioStatsView: View {
    @EnvironmentObject private var state: SottoAppState

    var body: some View {
        StudioPage(title: StudioSection.stats.title, symbol: StudioSection.stats.symbol) {
            StudioSettingsGroup {
                StudioSettingRow("Words spoken", detail: "All selected words sent to the local speech engine on this Mac.") {
                    Text("\(state.wordsSpoken) words")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                StudioSettingRow("Total dictation time", detail: "Total time Sotto has spent speaking selected text.") {
                    Text(Self.dictationTimeText(state.totalDictationSeconds))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private static func dictationTimeText(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}
