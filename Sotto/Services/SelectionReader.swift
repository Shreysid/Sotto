import AppKit
import Carbon.HIToolbox

@MainActor
final class SelectionReader {
    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }

        NSWorkspace.shared.open(url)
    }

    func read() async throws -> String? {
        guard isAccessibilityTrusted else {
            throw SelectionError.accessibilityPermissionRequired
        }

        if let text = selectedTextFromAccessibility(), !text.isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        simulateCopy()

        for _ in 0..<20 {
            try await Task.sleep(for: .milliseconds(10))
            if pasteboard.changeCount != snapshot.changeCount, let text = pasteboard.string(forType: .string) {
                snapshot.restore(to: pasteboard)
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        snapshot.restore(to: pasteboard)
        return nil
    }

    private func simulateCopy() {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func selectedTextFromAccessibility() -> String? {
        var focusedValue: CFTypeRef?
        let focusedKey = ("AXFocusedUIElement" as NSString) as CFString
        guard AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(), focusedKey, &focusedValue) == .success,
            let focusedValue,
            CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
        else { return nil }

        let focused = unsafeDowncast(focusedValue, to: AXUIElement.self)
        var selectionValue: CFTypeRef?
        let selectedTextKey = ("AXSelectedText" as NSString) as CFString
        guard AXUIElementCopyAttributeValue(focused, selectedTextKey, &selectionValue) == .success else {
            return nil
        }
        return selectionValue as? String
    }
}

private struct PasteboardSnapshot {
    let changeCount: Int
    let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ pasteboard: NSPasteboard) {
        changeCount = pasteboard.changeCount
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        guard pasteboard.changeCount != changeCount else { return }
        pasteboard.clearContents()
        let restored = items.map { saved -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in saved { item.setData(data, forType: type) }
            return item
        }
        pasteboard.writeObjects(restored)
    }
}

enum SelectionError: LocalizedError {
    case accessibilityPermissionRequired

    var errorDescription: String? {
        "Allow Accessibility access for Sotto, then try again."
    }
}
