@preconcurrency import AVFoundation
import Foundation

extension SpeechController {
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
