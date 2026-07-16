import SwiftUI

@main
struct SottoApp: App {
    @NSApplicationDelegateAdaptor(SottoApplicationDelegate.self) private var applicationDelegate
    @StateObject private var state: SottoAppState

    init() {
        _state = StateObject(wrappedValue: SottoAppState.shared)
    }

    var body: some Scene {
        MenuBarExtra {
            SottoMenuBarView()
                .environmentObject(state)
        } label: {
            Image(nsImage: state.statusIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
        .menuBarExtraStyle(.window)
    }
}
