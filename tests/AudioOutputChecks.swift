import CoreAudio
import Foundation

private final class Events: @unchecked Sendable {
    private let lock = NSLock()
    private var completions = 0
    private var errors = 0
    private var routes: [String?] = []
    func completed() { lock.lock(); defer { lock.unlock() }; completions += 1 }
    func failed() { lock.lock(); defer { lock.unlock() }; errors += 1 }
    func routed(_ name: String?) { lock.lock(); defer { lock.unlock() }; routes.append(name) }
    var snapshot: (Int, Int, [String?]) {
        lock.lock(); defer { lock.unlock() }; return (completions, errors, routes)
    }

}

private final class Devices: @unchecked Sendable {
    private let lock = NSLock()
    private var value: [AudioOutputDevice]
    init(_ value: [AudioOutputDevice]) { self.value = value }
    func set(_ devices: [AudioOutputDevice]) { lock.lock(); defer { lock.unlock() }; value = devices }
    func get() -> [AudioOutputDevice] { lock.lock(); defer { lock.unlock() }; return value }
}

@main struct AudioOutputChecks {
    static func main() async throws {
        setbuf(stdout, nil)
        let speakers = AudioOutputDevice(id: 1, name: "Built-in", isBuiltIn: true)
        let display = AudioOutputDevice(id: 2, name: "Display", isBuiltIn: false)
        let bluetooth = AudioOutputDevice(id: 3, name: "Bluetooth", isBuiltIn: false)
        let all = [speakers, display, bluetooth]
        precondition(AudioOutputDevice.ordered(all, selected: 3, lastWorking: 2) == [bluetooth, display, speakers])
        precondition(AudioOutputDevice.ordered(all, selected: 2, lastWorking: 2) == [display, speakers, bluetooth])
        precondition(AudioOutputDevice.ordered(all, selected: 99, lastWorking: nil) == all)
        print("PASS: selected Bluetooth/display routes, fallback order, disconnected device, deduplication")

        guard CommandLine.arguments.contains("--hardware") else { return }
        let available = try AudioOutputDevice.candidates(lastWorking: nil)
        guard let builtIn = available.first(where: { $0.isBuiltIn }) else {
            throw NSError(domain: "Checks require a built-in output", code: 1)
        }
        let events = Events()
        let devices = Devices([builtIn])
        let output = SpeechAudioOutput(deviceProvider: { _ in devices.get() })
        let request = UUID()
        try await output.start(request: request, onError: { _ in events.failed() }, onRoute: { events.routed($0) })
        output.schedule(samples: [Float](repeating: 0, count: 72_000), request: request) { events.completed() }
        output.play()
        try await Task.sleep(for: .milliseconds(1800))
        output.pause()
        // A new route that cannot open forces graph recovery on the same speaker.
        // This exercises the real hardware graph without changing macOS settings.
        let unavailable = AudioOutputDevice(id: UInt32.max, name: "Disconnected output", isBuiltIn: false)
        devices.set([unavailable, builtIn])
        output.refreshRoute()
        try await waitUntil { events.snapshot.2.last! == builtIn.name }
        try await Task.sleep(for: .milliseconds(200))
        precondition(events.snapshot.0 == 0, "Recovery must preserve pause and ignore old graph completions")
        precondition(events.snapshot.1 == 0, "Recovery should find the available speaker")
        precondition(events.snapshot.2.last! == builtIn.name, "Fallback must be reported")
        output.play()
        // Less than the original three-second buffer: restarting the chunk
        // instead of retaining its playback position would fail this deadline.
        try await waitUntil(timeout: .seconds(2)) { events.snapshot.0 == 1 }
        precondition(events.snapshot.0 == 1, "Resumed audio must finish exactly once")
        output.stop()
        let retryStarted = ContinuousClock.now
        let nextRequest = UUID()
        try await output.start(request: nextRequest, onError: { _ in events.failed() }, onRoute: { events.routed($0) })
        precondition(retryStarted.duration(to: .now) < .seconds(1), "Failed output suppression must prevent repeated startup timeouts")
        output.schedule(samples: [Float](repeating: 0, count: 2_400), request: request) { events.completed() }
        output.play()
        try await Task.sleep(for: .milliseconds(200))
        precondition(events.snapshot.0 == 1, "A replaced request must not schedule old audio")
        output.stop()
        print("PASS: unavailable route fallback, paused graph recovery, resumed buffers, exactly-once completion")

        let noOutput = SpeechAudioOutput(deviceProvider: { _ in [] })
        do {
            try await noOutput.start(request: UUID(), onError: { _ in }, onRoute: { _ in })
            preconditionFailure("No output must report a recoverable failure")
        } catch SpeechError.audioOutputUnavailable { }
        print("PASS: failed output suppression, stale request rejection, and no-output error")

        // Exercise the user's actual default output and automatic fallback.
        let liveEvents = Events()
        let live = SpeechAudioOutput()
        let liveRequest = UUID()
        try await live.start(request: liveRequest, onError: { _ in liveEvents.failed() }, onRoute: { liveEvents.routed($0) })
        live.schedule(samples: [Float](repeating: 0, count: 2_400), request: liveRequest) { liveEvents.completed() }
        live.play()
        try await Task.sleep(for: .seconds(1))
        precondition(liveEvents.snapshot.0 == 1 && liveEvents.snapshot.1 == 0)
        live.stop()
        print("PASS: actual default output recovery and silent playback")
    }

    private static func waitUntil(
        timeout: Duration = .seconds(15), condition: () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            precondition(ContinuousClock.now < deadline, "Timed out waiting for audio recovery")
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
