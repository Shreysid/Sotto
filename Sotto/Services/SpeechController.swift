import FluidAudio
import Foundation
import os

actor SpeechController {
    let logger = Logger(subsystem: "com.shreysid.Sotto", category: "Speech")
    var kokoro = KokoroAneManager(defaultVoice: "af_heart")
    let audioOutput = SpeechAudioOutput()

    var isPrepared = false
    var preparationTask: Task<Void, Error>?
    var playbackRate: Float = 1.0
    var activeRequest: UUID?
    var activeText: String?
    var synthesisTask: Task<Void, Never>?
    var sections: [String] = []
    var sectionIndex = 0
    var isPaused = false
    var kokoroUsingFallback = false
    var scheduledBufferCount = 0
    var completedBufferCount = 0
    var synthesisComplete = false
    var onOutputChanged: (@Sendable (String?) -> Void)?
    var onPlaybackFinished: (@Sendable () -> Void)?

    func setSpeed(_ speed: Float) {
        playbackRate = min(max(speed, 0.75), 1.35)
        audioOutput.setSpeed(playbackRate)
    }

    func speak(
        text: String,
        onFirstAudio: @escaping @Sendable (Duration) -> Void,
        onError: @escaping @Sendable (Error) -> Void,
        onPlaybackFinished: @escaping @Sendable () -> Void,
        onOutputChanged: @escaping @Sendable (String?) -> Void = { _ in }
    ) async throws {
        let started = ContinuousClock.now
        stop()
        let request = UUID()
        activeRequest = request
        activeText = text
        self.onOutputChanged = onOutputChanged
        do {
            try await prepare()
            guard activeRequest == request else { return }
            try await startPlaybackEngine(request: request, onError: onError)
            guard activeRequest == request else { return }
        } catch {
            guard activeRequest == request else { return }
            stop()
            throw error
        }
        isPaused = false
        resetPlaybackTracking(onPlaybackFinished: onPlaybackFinished)

        try await speakKokoro(
            text: text, request: request, started: started,
            onFirstAudio: onFirstAudio, onError: onError)
    }

    func stop() {
        activeRequest = nil
        activeText = nil
        onOutputChanged = nil
        synthesisTask?.cancel()
        synthesisTask = nil
        resetPlaybackTracking(onPlaybackFinished: nil)
        stopPlayer()
        isPaused = false
    }

    var isActive: Bool {
        activeRequest != nil
    }

    func isReading(_ text: String) -> Bool {
        activeRequest != nil && activeText == text
    }

    func togglePause() -> Bool {
        guard activeRequest != nil else { return false }
        if isPaused {
            playPlayer()
            isPaused = false
        } else {
            pausePlayer()
            isPaused = true
        }
        return isPaused
    }

    func jumpSection(
        by offset: Int,
        onFirstAudio: @escaping @Sendable (Duration) -> Void,
        onError: @escaping @Sendable (Error) -> Void,
        onPlaybackFinished: @escaping @Sendable () -> Void
    ) async throws {
        guard !sections.isEmpty else {
            throw SpeechError.noSections
        }
        let target = min(max(sectionIndex + offset, 0), sections.count - 1)
        guard target != sectionIndex else { return }

        stopPlayer()
        synthesisTask?.cancel()
        let request = UUID()
        activeRequest = request
        isPaused = false
        resetPlaybackTracking(onPlaybackFinished: onPlaybackFinished)
        do {
            try await startPlaybackEngine(request: request, onError: onError)
            guard activeRequest == request else { return }
        } catch {
            guard activeRequest == request else { return }
            stop()
            throw error
        }
        try await playKokoro(from: target, request: request, started: .now,
                             onFirstAudio: onFirstAudio, onError: onError)
    }
}
