import Foundation

struct PronunciationRule: Codable, Identifiable, Equatable {
    let id: UUID
    let term: String
    let spokenAs: String

    init(id: UUID = UUID(), term: String, spokenAs: String) {
        self.id = id
        self.term = term
        self.spokenAs = spokenAs
    }
}
