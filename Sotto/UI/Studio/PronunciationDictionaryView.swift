import SwiftUI

struct PronunciationDictionaryView: View {
    @EnvironmentObject private var state: SottoAppState
    @State private var term = ""
    @State private var spokenAs = ""
    @State private var editingRuleID: PronunciationRule.ID?

    var body: some View {
        StudioPage(title: StudioSection.pronunciation.title, symbol: StudioSection.pronunciation.symbol) {
            VStack(alignment: .leading, spacing: 22) {
                editor
                rulesList
            }
            .frame(maxWidth: 420, alignment: .leading)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(editingRuleID == nil ? "Add new" : "Edit pronunciation")
                .font(.headline.weight(.semibold))

            PronunciationField(title: "Word or phrase", placeholder: "e.g. Kokoro", text: $term)
            PronunciationField(title: "Speak as", placeholder: "e.g. ko-ko-ro", text: $spokenAs)

            Button(action: saveRule) {
                Label(
                    editingRuleID == nil ? "Add Pronunciation" : "Save Pronunciation",
                    systemImage: editingRuleID == nil ? "plus" : "checkmark"
                )
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 0.31, green: 0.91, blue: 0.82))
            }
            .opacity(canSave ? 1 : 0.45)
            .disabled(!canSave)
            .help(editingRuleID == nil ? "Add pronunciation" : "Save pronunciation")
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private var rulesList: some View {
        if state.pronunciationRules.isEmpty {
            Text("CUSTOM PRONUNCIATIONS")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            ContentUnavailableView("No custom pronunciations", systemImage: "text.book.closed")
                .frame(maxWidth: .infinity, minHeight: 160)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("CUSTOM PRONUNCIATIONS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                ForEach(state.pronunciationRules) { rule in
                    PronunciationRuleCard(
                        rule: rule,
                        onEdit: { editRule(rule) },
                        onDelete: { deleteRule(rule) }
                    )
                }
            }
        }
    }

    private var canSave: Bool {
        !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !spokenAs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveRule() {
        if let editingRuleID {
            state.updatePronunciationRule(id: editingRuleID, term: term, spokenAs: spokenAs)
        } else {
            state.addPronunciationRule(term: term, spokenAs: spokenAs)
        }
        term = ""
        spokenAs = ""
        editingRuleID = nil
    }

    private func editRule(_ rule: PronunciationRule) {
        editingRuleID = rule.id
        term = rule.term
        spokenAs = rule.spokenAs
    }

    private func deleteRule(_ rule: PronunciationRule) {
        if editingRuleID == rule.id {
            term = ""
            spokenAs = ""
            editingRuleID = nil
        }
        state.removePronunciationRule(id: rule.id)
    }
}

private struct PronunciationField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.35))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.primary.opacity(0.16), lineWidth: 1)
                        }
                }
        }
    }
}

private struct PronunciationRuleCard: View {
    let rule: PronunciationRule
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(rule.term)
                    .font(.headline.weight(.semibold))
                Label(rule.spokenAs, systemImage: "person.wave.2")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }

            Spacer(minLength: 18)

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Edit pronunciation")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Remove pronunciation")
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }
        }
    }
}
