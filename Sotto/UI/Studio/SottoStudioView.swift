import SwiftUI

struct SottoStudioView: View {
    @EnvironmentObject private var state: SottoAppState
    @State private var selection: StudioSection? = .settings

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Configure") {
                    Label("Settings", systemImage: "gearshape")
                        .tag(StudioSection.settings)
                    Label("Pronunciation", systemImage: "text.book.closed")
                        .tag(StudioSection.pronunciation)
                }
                Section("Activity") {
                    Label("Stats", systemImage: "chart.bar.xaxis")
                        .tag(StudioSection.stats)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Sotto Studio")
            .frame(minWidth: 235)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            StudioDetailView(section: selection ?? .settings)
                .environmentObject(state)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .frame(minWidth: 900, minHeight: 580)
    }
}

enum StudioSection: Hashable {
    case settings
    case pronunciation
    case stats

    var title: String {
        switch self {
        case .settings: "App Settings"
        case .pronunciation: "Pronunciation"
        case .stats: "Stats"
        }
    }

    var symbol: String {
        switch self {
        case .settings: "gearshape.fill"
        case .pronunciation: "text.book.closed.fill"
        case .stats: "chart.bar.xaxis"
        }
    }
}

struct StudioDetailView: View {
    @EnvironmentObject private var state: SottoAppState
    let section: StudioSection

    var body: some View {
        switch section {
        case .settings:
            StudioSettingsView()
                .environmentObject(state)
        case .pronunciation:
            PronunciationDictionaryView()
                .environmentObject(state)
        case .stats:
            StudioStatsView()
                .environmentObject(state)
        }
    }
}
