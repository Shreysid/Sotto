@preconcurrency import AVFoundation
import Foundation
import os

extension SpeechController {
    func startPlaybackEngine() throws {
        let started = ContinuousClock.now
        // Keep graph changes and hardware startup ordered with player.stop().
        // CoreAudio may have stopped the engine after an output-device change.
        do {
            try playbackQueue.sync { [engine, timePitch, playbackFormat] in
                guard !engine.isRunning else { return }
                engine.reset()
                engine.disconnectNodeOutput(timePitch)
                engine.connect(timePitch, to: engine.mainMixerNode, format: playbackFormat)
                engine.prepare()
                do {
                    try engine.start()
                } catch {
                    engine.stop()
                    engine.reset()
                    throw error
                }
            }
            logger.notice("Audio output ready in \(started.duration(to: .now).seconds, format: .fixed(precision: 2)) s")
        } catch {
            logger.error("Audio output failed after \(started.duration(to: .now).seconds, format: .fixed(precision: 2)) s: \(error.localizedDescription, privacy: .public)")
            throw SpeechError.audioOutputUnavailable(code: (error as NSError).code)
        }
    }

    func schedule(samples: [Float], request: UUID) {
        let buffer = AVAudioPCMBuffer(
            pcmFormat: playbackFormat, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }
        scheduledBufferCount += 1
        playbackQueue.async { [player] in
            player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { await self?.bufferDidFinish(request: request) }
            }
        }
    }

    func stopPlayer() {
        playbackQueue.async { [player] in
            player.stop()
        }
    }

    func playPlayer() {
        playbackQueue.async { [player] in
            player.play()
        }
    }

    func pausePlayer() {
        playbackQueue.async { [player] in
            player.pause()
        }
    }

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
        synthesisTask = nil
        isPaused = false
        let callback = onPlaybackFinished
        onPlaybackFinished = nil
        callback?()
    }
}
