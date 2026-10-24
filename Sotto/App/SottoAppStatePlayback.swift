import Foundation

extension SottoAppState {
    func speakSelection() {
        guard selectionReader.isAccessibilityTrusted else {
            accessibilityPermissionGranted = false
            updateStatus("Accessibility access required")
            onAccessibilityPermissionRequired?()
            return
        }
        accessibilityPermissionGranted = true

        Task {
            guard canSpeak else {
                updateStatus("Kokoro needs to be installed")
                if kokoroInstallationState == .downloadRequired {
                    onKokoroDownloadRequired?()
                }
                return
            }

            do {
                updateStatus("Reading selection...")
                let selectionStarted = ContinuousClock.now
                guard let text = try await selectionReader.read(), !text.isEmpty else {
                    await speech.stop()
                    isPaused = false
                    updateStatus("No text selected")
                    return
                }
                if await speech.isReading(text) {
                    await speech.stop()
                    isPaused = false
                    updateStatus("Stopped")
                    return
                }

                let captureTime = selectionStarted.duration(to: .now)
                recordWords(in: text)
                let spokenText = applyingPronunciationRules(to: text)
                updateStatus("Generating audio - capture \(captureTime.short)")
                try await speech.speak(
                    text: spokenText,
                    onFirstAudio: { firstAudio in
                        Task { @MainActor in
                            SottoAppState.shared.latestFirstAudio = firstAudio
                            SottoAppState.shared.finishDictationSession()
                            SottoAppState.shared.startDictationSession()
                            SottoAppState.shared.updateStatus(
                                "Speaking - capture \(captureTime.short), first audio \(firstAudio.short)"
                            )
                        }
                    },
                    onError: { error in
                        Task { @MainActor in
                            SottoAppState.shared.updateStatus("Playback error: \(error.localizedDescription)")
                        }
                    },
                    onPlaybackFinished: {
                        Task { @MainActor in
                            SottoAppState.shared.finishDictationSession()
                            SottoAppState.shared.isPaused = false
                            SottoAppState.shared.updateStatus("Finished")
                        }
                    }
                )
            } catch {
                updateStatus("Could not speak: \(error.localizedDescription)")
            }
        }
    }

    func stopSpeaking() {
        finishDictationSession()
        Task { await speech.stop() }
        isPaused = false
        updateStatus("Stopped")
    }

    func togglePause() {
        Task {
            let paused = await speech.togglePause()
            isPaused = paused
            updateStatus(paused ? "Paused" : "Speaking")
        }
    }

    func jumpSection(by offset: Int) {
        Task {
            do {
                updateStatus(offset < 0 ? "Going to previous section..." : "Going to next section...")
                try await speech.jumpSection(
                    by: offset,
                    onFirstAudio: { firstAudio in
                        Task { @MainActor in
                            SottoAppState.shared.latestFirstAudio = firstAudio
                            SottoAppState.shared.finishDictationSession()
                            SottoAppState.shared.startDictationSession()
                            SottoAppState.shared.updateStatus("Speaking - first audio \(firstAudio.short)")
                        }
                    },
                    onError: { error in
                        Task { @MainActor in
                            SottoAppState.shared.updateStatus("Playback error: \(error.localizedDescription)")
                        }
                    },
                    onPlaybackFinished: {
                        Task { @MainActor in
                            SottoAppState.shared.finishDictationSession()
                            SottoAppState.shared.isPaused = false
                            SottoAppState.shared.updateStatus("Finished")
                        }
                    }
                )
            } catch {
                updateStatus("Could not change section: \(error.localizedDescription)")
            }
        }
    }

    func startDictationSession() {
        dictationSessionStartedAt = .now
    }

    func finishDictationSession() {
        guard let started = dictationSessionStartedAt else { return }

        totalDictationSeconds += started.duration(to: .now).seconds
        dictationSessionStartedAt = nil
        UserDefaults.standard.set(totalDictationSeconds, forKey: DefaultsKey.totalDictationSeconds)
    }
}
