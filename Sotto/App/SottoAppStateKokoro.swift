import Foundation

extension SottoAppState {
    func checkKokoroInstallation() {
        Task {
            kokoroInstalledProgress = await speech.kokoroInstallationProgress()
            guard await speech.isKokoroInstalled() else {
                kokoroInstallationState = .downloadRequired
                updateStatus("Kokoro not installed")
                onKokoroDownloadRequired?()
                return
            }

            kokoroInstallationState = .loading
            updateStatus("Loading Kokoro...")
            do {
                try await speech.prepare()
                kokoroInstallationState = .ready
                updateStatus("Kokoro ready")
            } catch {
                kokoroInstallationState = .failed(error.localizedDescription)
                updateStatus("Voice unavailable: \(error.localizedDescription)")
            }
        }
    }

    func downloadKokoro() {
        guard !kokoroInstallationState.isDownloading, kokoroInstallationState != .loading else { return }

        Task {
            let initialProgress = await speech.kokoroInstallationProgress()
            kokoroInstalledProgress = initialProgress
            kokoroInstallationState = .downloading(initialProgress)
            updateStatus("Downloading Kokoro \(Self.percentText(initialProgress))")
            do {
                try await speech.downloadKokoro { progress in
                    Task { @MainActor in
                        SottoAppState.shared.setKokoroDownloadProgress(progress)
                    }
                }
                kokoroInstallationState = .ready
                kokoroInstalledProgress = 1
                updateStatus("Kokoro ready")
            } catch {
                kokoroInstallationState = .failed(error.localizedDescription)
                updateStatus("Kokoro download failed: \(error.localizedDescription)")
            }
        }
    }

    func deleteKokoro() {
        guard kokoroInstallationState == .ready || kokoroInstalledProgress > 0 else { return }

        Task {
            do {
                try await speech.deleteKokoroModels()
                kokoroInstalledProgress = 0
                kokoroInstallationState = .downloadRequired
                updateStatus("Kokoro deleted")
                onKokoroDownloadRequired?()
            } catch {
                kokoroInstallationState = .failed(error.localizedDescription)
                updateStatus("Could not delete Kokoro: \(error.localizedDescription)")
            }
        }
    }

    func setKokoroDownloadProgress(_ progress: Double) {
        let clamped = min(max(progress, 0), 1)
        kokoroInstalledProgress = clamped
        kokoroInstallationState = .downloading(clamped)
        updateStatus("Downloading Kokoro \(Self.percentText(clamped))")
    }

    static func percentText(_ progress: Double) -> String {
        "\(Int((min(max(progress, 0), 1) * 100).rounded()))%"
    }
}
