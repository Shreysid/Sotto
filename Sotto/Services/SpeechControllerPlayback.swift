import Foundation

extension SpeechController {
    func startPlaybackEngine(request: UUID, onError: @escaping @Sendable (Error) -> Void) async throws {
        try await audioOutput.start(request: request, onError: { [weak self] error in
            Task { await self?.outputFailed(error, request: request, onError: onError) }
        }, onRoute: { [weak self] fallback in
            Task { await self?.outputChanged(fallback, request: request) }
        })
    }

    func outputFailed(_ error: Error, request: UUID, onError: @escaping @Sendable (Error) -> Void) {
        guard activeRequest == request else { return }
        stop()
        onError(error)
    }

    func outputChanged(_ fallback: String?, request: UUID) {
        guard activeRequest == request else { return }
        onOutputChanged?(fallback)
    }

    func schedule(samples: [Float], request: UUID) {
        scheduledBufferCount += 1
        audioOutput.schedule(samples: samples, request: request) { [weak self] in
            Task { await self?.bufferDidFinish(request: request) }
        }
    }

    func stopPlayer() { audioOutput.stop() }
    func playPlayer() { audioOutput.play() }
    func pausePlayer() { audioOutput.pause() }

    func resetPlaybackTracking(onPlaybackFinished: (@Sendable () -> Void)?) {
        scheduledBufferCount = 0
        completedBufferCount = 0
        synthesisComplete = false
        self.onPlaybackFinished = onPlaybackFinished
    }

    func bufferDidFinish(request: UUID) {
        guard activeRequest == request else { return }
        completedBufferCount += 1
        completePlaybackIfFinished(request: request)
    }

    func completePlaybackIfFinished(request: UUID) {
        guard activeRequest == request,
              synthesisComplete,
              scheduledBufferCount > 0,
              completedBufferCount >= scheduledBufferCount
        else { return }

        activeRequest = nil
        activeText = nil
        onOutputChanged = nil
        stopPlayer()
        synthesisTask = nil
        isPaused = false
        let callback = onPlaybackFinished
        onPlaybackFinished = nil
        callback?()
    }
}
