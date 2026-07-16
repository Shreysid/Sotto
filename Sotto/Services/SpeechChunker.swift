import Foundation
import NaturalLanguage

enum SpeechChunker {
    // A Kokoro request is capped by phonemes, not characters. These bounds
    // remain safely below that cap for ordinary English while keeping enough
    // queued audio for the next chunk to render during playback.
    nonisolated private static let minimumLength = 80
    nonisolated private static let hardLength = 240
    nonisolated private static let firstChunkMinimumLength = 45
    nonisolated private static let firstChunkHardLength = 110

    nonisolated static func chunks(from text: String) -> [String] {
        let normalized = normalize(text)
        let sentences = sentenceRanges(in: normalized)
        var chunks: [String] = []
        var current = ""

        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            chunks.append(trimmed)
            current = ""
        }

        for sentence in sentences {
            for phrase in boundedPhrases(in: sentence) {
                let candidate = current.isEmpty ? phrase : "\(current) \(phrase)"
                let limit = chunks.isEmpty ? firstChunkHardLength : hardLength
                if !current.isEmpty, candidate.count > limit {
                    flush()
                }

                if current.isEmpty, chunks.isEmpty, phrase.count > firstChunkHardLength {
                    let split = splitForFirstAudio(phrase)
                    chunks.append(split.head)
                    current = split.tail
                    continue
                }
                current = current.isEmpty ? phrase : "\(current) \(phrase)"

                let reachedFirstBoundary = chunks.isEmpty
                    && current.count >= firstChunkMinimumLength
                    && endsNaturalBoundary(phrase)
                if reachedFirstBoundary || (current.count >= minimumLength && endsStrongBoundary(phrase)) {
                    flush()
                }
            }
        }
        flush()
        return chunks
    }

    nonisolated private static func normalize(_ text: String) -> String {
        let lineNormalized = text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
        // LLM selections frequently omit a space after a full stop before the
        // next capitalized sentence, e.g. "finish.But". Restore that boundary
        // without touching decimal numbers or ordinary abbreviations.
        return lineNormalized.replacingOccurrences(
            of: "([.!?])(?=[A-Z0-9])",
            with: "$1 ",
            options: .regularExpression
        )
    }

    nonisolated private static func sentenceRanges(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { sentences.append(sentence) }
            return true
        }
        return sentences.isEmpty ? [text] : sentences
    }

    nonisolated private static func boundedPhrases(in sentence: String) -> [String] {
        var phrases: [String] = []
        var current: [String] = []
        var currentLength = 0

        func flush() {
            guard !current.isEmpty else { return }
            phrases.append(current.joined(separator: " "))
            current.removeAll(keepingCapacity: true)
            currentLength = 0
        }

        for word in sentence.split(whereSeparator: { $0.isWhitespace }) {
            let token = String(word)
            let separatorLength = current.isEmpty ? 0 : 1
            if !current.isEmpty, currentLength + separatorLength + token.count > hardLength {
                flush()
            }
            current.append(token)
            currentLength += separatorLength + token.count

            let phraseBoundary = token.last.map { ",;:".contains($0) } ?? false
            if phraseBoundary {
                flush()
            }
        }
        flush()
        return phrases
    }

    nonisolated private static func endsStrongBoundary(_ text: String) -> Bool {
        text.last.map { ".!?".contains($0) } ?? false
    }

    nonisolated private static func endsNaturalBoundary(_ text: String) -> Bool {
        text.last.map { ".!?,;:".contains($0) } ?? false
    }

    nonisolated private static func splitForFirstAudio(_ phrase: String) -> (head: String, tail: String) {
        var head: [Substring] = []
        var length = 0
        let words = phrase.split(whereSeparator: { $0.isWhitespace })

        for word in words {
            let separator = head.isEmpty ? 0 : 1
            guard !head.isEmpty, length + separator + word.count > firstChunkHardLength else {
                head.append(word)
                length += separator + word.count
                continue
            }
            break
        }

        guard !head.isEmpty else { return (phrase, "") }
        let headText = head.joined(separator: " ")
        let tail = words.dropFirst(head.count).joined(separator: " ")
        return (headText, tail)
    }
}
