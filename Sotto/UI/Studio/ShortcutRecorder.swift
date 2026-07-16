import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: GlobalShortcut

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.onShortcutChanged = { shortcut in
            self.shortcut = shortcut
        }
        button.shortcut = shortcut
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.shortcut = shortcut
    }
}

final class ShortcutRecorderButton: NSButton {
    var shortcut: GlobalShortcut = .default {
        didSet {
            guard !isRecording else { return }
            title = shortcut.displayTitle
        }
    }
    var onShortcutChanged: ((GlobalShortcut) -> Void)?
    private var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        alignment = .center
        title = shortcut.displayTitle
        target = self
        action = #selector(beginRecording)
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    @objc private func beginRecording() {
        isRecording = true
        title = "Press shortcut"
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            title = shortcut.displayTitle
            return
        }
        guard let captured = GlobalShortcut(event: event) else {
            NSSound.beep()
            return
        }
        shortcut = captured
        isRecording = false
        onShortcutChanged?(captured)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        title = shortcut.displayTitle
        return super.resignFirstResponder()
    }
}
