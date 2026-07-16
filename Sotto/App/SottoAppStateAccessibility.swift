extension SottoAppState {
    func requestAccessibilityPermission() {
        refreshAccessibilityPermission()
    }

    func refreshAccessibilityPermission() {
        accessibilityPermissionGranted = selectionReader.isAccessibilityTrusted
        guard !accessibilityPermissionGranted else { return }

        updateStatus("Accessibility access required")
        onAccessibilityPermissionRequired?()
    }

    func openAccessibilitySettings() {
        selectionReader.openAccessibilitySettings()
    }
}
