import Foundation

extension SottoAppState {
    func recordWords(in text: String) {
        let count = text.split(whereSeparator: { $0.isWhitespace }).count
        guard count > 0 else { return }

        wordsSpoken += count
        UserDefaults.standard.set(wordsSpoken, forKey: DefaultsKey.wordsSpoken)
    }
}
