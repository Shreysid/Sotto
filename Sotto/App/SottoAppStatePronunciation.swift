import Foundation

extension SottoAppState {
    func addPronunciationRule(term: String, spokenAs: String) {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSpokenAs = spokenAs.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty, !trimmedSpokenAs.isEmpty else { return }

        pronunciationRules.removeAll {
            $0.term.compare(trimmedTerm, options: [.caseInsensitive]) == .orderedSame
        }
        pronunciationRules.append(PronunciationRule(term: trimmedTerm, spokenAs: trimmedSpokenAs))
        sortAndPersistPronunciationRules()
    }

    func updatePronunciationRule(id: PronunciationRule.ID, term: String, spokenAs: String) {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSpokenAs = spokenAs.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty, !trimmedSpokenAs.isEmpty else { return }

        pronunciationRules.removeAll {
            $0.id == id || $0.term.compare(trimmedTerm, options: [.caseInsensitive]) == .orderedSame
        }
        pronunciationRules.append(PronunciationRule(id: id, term: trimmedTerm, spokenAs: trimmedSpokenAs))
        sortAndPersistPronunciationRules()
    }

    func removePronunciationRule(id: PronunciationRule.ID) {
        pronunciationRules.removeAll { $0.id == id }
        persistPronunciationRules()
    }

    func applyingPronunciationRules(to text: String) -> String {
        pronunciationRules
            .sorted { $0.term.count > $1.term.count }
            .reduce(text) { result, rule in
                result.replacingOccurrences(
                    of: "\\b\(NSRegularExpression.escapedPattern(for: rule.term))\\b",
                    with: rule.spokenAs,
                    options: [.regularExpression, .caseInsensitive]
                )
            }
    }

    static func loadPronunciationRules() -> [PronunciationRule] {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.pronunciationRules),
              let rules = try? JSONDecoder().decode([PronunciationRule].self, from: data)
        else { return [] }
        return rules
    }

    func sortAndPersistPronunciationRules() {
        pronunciationRules.sort {
            $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending
        }
        persistPronunciationRules()
    }

    func persistPronunciationRules() {
        guard let data = try? JSONEncoder().encode(pronunciationRules) else { return }
        UserDefaults.standard.set(data, forKey: DefaultsKey.pronunciationRules)
    }
}
