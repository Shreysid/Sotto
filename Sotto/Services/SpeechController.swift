@preconcurrency import AVFoundation
import FluidAudio
import os

actor SpeechController {
    let logger = Logger(subsystem: "com.shreysid.Sotto", category: "Speech")
    var kokoro = KokoroAneManager(defaultVoice: "af_heart")
    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    let timePitch = AVAudioUnitTimePitch()
    let playbackQueue = DispatchQueue(
        label: "com.shreysid.Sotto.speech.playback",
        qos: .userInitiated
    )
    let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 24_000,
        channels: 1,
        interleaved: false
    )!

    var isPrepared = false
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
    var onPlaybackFinished: (@Sendable () -> Void)?

    init() {
        engine.attach(player)
        engine.attach(timePitch)
        engine.connect(player, to: timePitch, format: playbackFormat)
        engine.connect(timePitch, to: engine.mainMixerNode, format: playbackFormat)
    }

    func setSpeed(_ speed: Float) {
        playbackRate = min(max(speed, 0.75), 1.35)
        let playbackRate = playbackRate
        playbackQueue.async { [timePitch] in
            timePitch.rate = playbackRate
        }
    }

    func speak(
        text: String,
        onFirstAudio: @escaping @Sendable (Duration) -> Void,
        onError: @escaping @Sendable (Error) -> Void,
        onPlaybackFinished: @escaping @Sendable () -> Void
    ) async throws {
        try await prepare()
        stopPlayer()
        if !engine.isRunning { try engine.start() }
        let request = UUID()
        activeRequest = request
        activeText = text
        synthesisTask?.cancel()
        isPaused = false
        resetPlaybackTracking(onPlaybackFinished: onPlaybackFinished)
        let started = ContinuousClock.now

        try await speakKokoro(
            text: text, request: request, started: started,
            onFirstAudio: onFirstAudio, onError: onError)
    }

    func stop() {
        activeRequest = nil
        activeText = nil
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
        if !engine.isRunning { try engine.start() }
        try await playKokoro(from: target, request: request, started: .now,
                             onFirstAudio: onFirstAudio, onError: onError)
    }
}
