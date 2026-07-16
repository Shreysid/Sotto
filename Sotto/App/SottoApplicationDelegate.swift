import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
final class SottoApplicationDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var studioWindowController: SottoStudioWindowController?
    private var hasPresentedKokoroDownloadPrompt = false
    private var hasPresentedAccessibilityPrompt = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        installStudioWindow()
        configureShortcut()
        observeApplicationChanges()
        SottoAppState.shared.onAccessibilityPermissionRequired = { [weak self] in
            self?.presentAccessibilityPermissionPrompt()
        }
        SottoAppState.shared.requestAccessibilityPermission()
        SottoAppState.shared.onKokoroDownloadRequired = { [weak self] in
            self?.presentKokoroDownloadPrompt()
        }
        SottoAppState.shared.checkKokoroInstallation()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openStudio()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        SottoAppState.shared.refreshAccessibilityPermission()
    }

    private func installStudioWindow() {
        studioWindowController = SottoStudioWindowController(state: SottoAppState.shared)
        SottoAppState.shared.onOpenStudio = { [weak self] in
            self?.openStudio()
        }
    }

    private func openStudio() {
        if studioWindowController?.window == nil {
            studioWindowController = SottoStudioWindowController(state: SottoAppState.shared)
        }
        studioWindowController?.showAndActivate()
    }

    private func presentAccessibilityPermissionPrompt() {
        guard !hasPresentedAccessibilityPrompt else { return }
        hasPresentedAccessibilityPrompt = true

        openStudio()
        guard let window = studioWindowController?.window else { return }

        let alert = NSAlert()
        alert.messageText = "Allow Accessibility access"
        alert.informativeText = "Sotto needs Accessibility access to read selected text and use its global shortcut. Allow Sotto in System Settings, then return here."
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Not Now")
        alert.alertStyle = .informational
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                SottoAppState.shared.openAccessibilitySettings()
            }
        }
    }

    private func presentKokoroDownloadPrompt() {
        guard !hasPresentedKokoroDownloadPrompt else { return }
        hasPresentedKokoroDownloadPrompt = true

        openStudio()
        guard let window = studioWindowController?.window else { return }

        let alert = NSAlert()
        alert.messageText = "Download Kokoro voice?"
        alert.informativeText = "Sotto is installed, but its private local voice is separate. Download Kokoro (about 170 MB) to start reading selected text offline."
        alert.addButton(withTitle: "Download Kokoro")
        alert.addButton(withTitle: "Not Now")
        alert.alertStyle = .informational
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                SottoAppState.shared.downloadKokoro()
            }
        }
    }

    private func configureShortcut() {
        SottoAppState.shared.onShortcutChanged = { [weak self] shortcut in
            self?.registerHotKey(shortcut)
        }
        registerHotKey(SottoAppState.shared.shortcut)
    }

    private func registerHotKey(_ shortcut: GlobalShortcut) {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            guard GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            ) == noErr, hotKeyID.id == 1 else { return noErr }

            let delegate = Unmanaged<SottoApplicationDelegate>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in delegate.handleShortcut() }
            return noErr
        }

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        if hotKeyHandler == nil {
            InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &eventType, pointer, &hotKeyHandler)
        }
        let identifier = EventHotKeyID(signature: OSType(0x534F5454), id: 1) // SOTT
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            identifier,
            GetEventDispatcherTarget(),
            0,
            &hotKey
        )
        Task { @MainActor in
            SottoAppState.shared.setShortcutRegistrationError(
                status == noErr ? nil : "That shortcut is already in use."
            )
        }
    }

    private func observeApplicationChanges() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeApplicationChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    private func handleShortcut() {
        Task { @MainActor in SottoAppState.shared.speakSelection() }
    }

    @objc private func activeApplicationChanged(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return }
        Task { @MainActor in
            SottoAppState.shared.stopForVoiceApplication(bundleIdentifier: app.bundleIdentifier)
        }
    }
}
