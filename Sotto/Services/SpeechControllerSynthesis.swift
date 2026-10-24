import FluidAudio
import Foundation
import os

extension SpeechController {
    func speakKokoro(
        text: String,
        request: UUID,
        started: ContinuousClock.Instant,
        onFirstAudio: @escaping @Sendable (Duration) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) async throws {
        sections = SpeechChunker.chunks(from: text)
        try await playKokoro(from: 0, request: request, started: started,
                             onFirstAudio: onFirstAudio, onError: onError)
    }

    func playKokoro(
        from index: Int,
        request: UUID,
        started: ContinuousClock.Instant,
        onFirstAudio: @escaping @Sendable (Duration) -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) async throws {
        guard sections.indices.contains(index) else { throw SpeechError.noSections }
        let firstChunk = sections[index]
        sectionIndex = index

        do {
            let result = try await kokoro.synthesizeDetailed(text: firstChunk)
            guard activeRequest == request else { return }
            schedule(samples: result.samples, request: request)
            if !isPaused { playPlayer() }
            let firstAudio = started.duration(to: .now)
            logger.info(
                "First audio: \(firstChunk.count) chars in \(firstAudio.seconds, format: .fixed(precision: 2)) s using \(self.kokoroUsingFallback ? "CPU/GPU fallback" : "ANE", privacy: .public)"
            )
            onFirstAudio(firstAudio)

            let remaining = Array(sections.dropFirst(index + 1))
            if remaining.isEmpty {
                synthesisComplete = true
                completePlaybackIfFinished(request: request)
            } else {
                synthesisTask = Task { [weak self] in
                    await self?.synthesizeKokoroRemaining(
                        remaining, startingAt: index + 1, request: request, onError: onError)
                }
            }
        } catch {
            guard activeRequest == request else { return }
            onError(error)
        }
    }

    func synthesizeKokoroRemaining(
        _ chunks: [String],
        startingAt startIndex: Int,
        request: UUID,
        onError: @escaping @Sendable (Error) -> Void
    ) async {
        do {
            for (offset, chunk) in chunks.enumerated() {
                guard activeRequest == request, !Task.isCancelled else { return }
                let result = try await kokoro.synthesizeDetailed(text: chunk)
                guard activeRequest == request, !Task.isCancelled else { return }
                schedule(samples: result.samples, request: request)
                sectionIndex = startIndex + offset
            }
            guard activeRequest == request, !Task.isCancelled else { return }
            synthesisComplete = true
            completePlaybackIfFinished(request: request)
        } catch {
            guard activeRequest == request, !Task.isCancelled else { return }
            onError(error)
        }
    }
}
