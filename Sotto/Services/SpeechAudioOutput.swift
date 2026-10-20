@preconcurrency import AVFoundation
import AudioToolbox
import CoreAudio
import os

// All graph, routing, and buffer state is confined to queue. CoreAudio callbacks
// only enqueue work; they never tear down an engine on Apple's notification thread.
nonisolated final class SpeechAudioOutput: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.shreysid.Sotto.audio", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.shreysid.Sotto", category: "AudioOutput")
    private let deviceProvider: @Sendable (AudioDeviceID?) throws -> [AudioOutputDevice]
    private let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 24_000, channels: 1, interleaved: false)!
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var pitch: AVAudioUnitTimePitch?
    private var currentDevice: AudioOutputDevice?
    private var failedDevices: Set<AudioDeviceID> = []
    private var generation = UUID()
    private var pending: [PendingBuffer] = []
    private var endFrame: AVAudioFramePosition = 0
    private var baseFrame: AVAudioFramePosition = 0
    private var lastFrame: AVAudioFramePosition = 0
    private var wantsPlayback = false
    private var rate: Float = 1
    private var request: UUID?
    private var onError: (@Sendable (Error) -> Void)?
    private var onRoute: (@Sendable (String?) -> Void)?
    private var routeListener: AudioObjectPropertyListenerBlock?
    private var configurationObserver: NSObjectProtocol?
    private var recovery: DispatchWorkItem?
    private var positionTimer: DispatchSourceTimer?

    private struct PendingBuffer {
        let id: UUID
        let buffer: AVAudioPCMBuffer
        let startFrame: AVAudioFramePosition
        let completion: @Sendable () -> Void
    }

    init(deviceProvider: @escaping @Sendable (AudioDeviceID?) throws -> [AudioOutputDevice] = {
        try AudioOutputDevice.candidates(lastWorking: $0)
    }) {
        self.deviceProvider = deviceProvider
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refreshRoute(retryFailedDevices: true)
        }
        routeListener = listener
        for selector in [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDevices] {
            var address = AudioOutputDevice.property(selector)
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, queue, listener)
        }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: nil, queue: nil
        ) { [weak self] notification in
            guard let changedEngine = notification.object as? AVAudioEngine else { return }
            self?.queue.async { [weak self] in
                guard let self, self.engine === changedEngine else { return }
                self.scheduleRecovery()
            }
        }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in self?.rememberPosition() }
        timer.resume()
        positionTimer = timer
    }

    deinit {
        if let routeListener {
            for selector in [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDevices] {
                var address = AudioOutputDevice.property(selector)
                AudioObjectRemovePropertyListenerBlock(
                    AudioObjectID(kAudioObjectSystemObject), &address, queue, routeListener)
            }
        }
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        positionTimer?.cancel()
        recovery?.cancel()
        engine?.stop()
    }

    func start(
        request: UUID,
        onError: @escaping @Sendable (Error) -> Void,
        onRoute: @escaping @Sendable (String?) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                self.request = request
                self.onError = onError
                self.onRoute = onRoute
                do {
                    let devices = try deviceProvider(currentDevice?.id)
                    if eligibleDevices(devices).isEmpty { failedDevices.removeAll() }
                    if engine?.isRunning != true || currentDevice?.id != eligibleDevices(devices).first?.id {
                        try rebuild(devices: devices)
                    }
                    reportRoute(devices: devices)
                    continuation.resume()
                } catch {
                    self.request = nil
                    self.onError = nil
                    self.onRoute = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func refreshRoute(retryFailedDevices: Bool = false) {
        queue.async { [weak self] in
            guard let self else { return }
            if retryFailedDevices { self.failedDevices.removeAll() }
            self.scheduleRecovery()
        }
    }

    func stop() {
        queue.async { [self] in
            generation = UUID()
            request = nil
            onError = nil
            onRoute = nil
            wantsPlayback = false
            pending.removeAll()
            player?.stop()
            endFrame = 0
            baseFrame = 0
            lastFrame = 0
        }
    }

    func setSpeed(_ speed: Float) {
        queue.async { [self] in rate = speed; pitch?.rate = speed }
    }

    func pause() {
        queue.async { [self] in
            rememberPosition()
            wantsPlayback = false
            player?.pause()
        }
    }

    func play() {
        queue.async { [self] in
            wantsPlayback = true
            guard engine?.isRunning == true else { scheduleRecovery(); return }
            player?.play()
        }
    }

    func schedule(samples: [Float], request: UUID, completion: @escaping @Sendable () -> Void) {
        queue.async { [self] in
            guard self.request == request else { return }
            guard !samples.isEmpty, samples.count <= Int(UInt32.max),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
            else { fail(SpeechError.noAudio); return }
            buffer.frameLength = buffer.frameCapacity
            samples.withUnsafeBufferPointer {
                buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count)
            }
            let start = max(endFrame, renderedFrame())
            let item = PendingBuffer(id: UUID(), buffer: buffer, startFrame: start, completion: completion)
            pending.append(item)
            endFrame = start + AVAudioFramePosition(buffer.frameLength)
            enqueue(item)
        }
    }

    private func enqueue(_ item: PendingBuffer) {
        let epoch = generation
        player?.scheduleBuffer(item.buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            self?.queue.async { [weak self] in
                guard let self, self.generation == epoch,
                      let index = self.pending.firstIndex(where: { $0.id == item.id }) else { return }
                guard self.engine?.isRunning == true else {
                    self.scheduleRecovery()
                    return
                }
                self.pending.remove(at: index)
                self.lastFrame = max(self.lastFrame, item.startFrame + AVAudioFramePosition(item.buffer.frameLength))
                item.completion()
            }
        }
    }

    private func renderedFrame() -> AVAudioFramePosition {
        guard let player, let time = player.lastRenderTime,
              let position = player.playerTime(forNodeTime: time) else { return lastFrame }
        return max(lastFrame, baseFrame + position.sampleTime)
    }

    private func rememberPosition() {
        guard wantsPlayback else { return }
        lastFrame = min(endFrame, renderedFrame())
    }

    private func scheduleRecovery() {
        // Debounce the device and engine notifications emitted by one route change.
        recovery?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do {
                let devices = try self.deviceProvider(self.currentDevice?.id)
                if self.engine?.isRunning == true,
                   self.currentDevice?.id == self.eligibleDevices(devices).first?.id { return }
                guard self.request != nil else { self.tearDown(); return }
                try self.rebuild(devices: devices)
                self.reportRoute(devices: devices)
            } catch { self.fail(error) }
        }
        recovery = work
        queue.asyncAfter(deadline: .now() + .milliseconds(250), execute: work)
    }

    private func rebuild(devices: [AudioOutputDevice]) throws {
        rememberPosition()
        let cursor = lastFrame
        generation = UUID()
        player?.stop()
        engine?.stop()
        var lastError: Error = SpeechError.audioOutputUnavailable(code: -1)
        // Do not repeat a failed device's hardware timeout on every selection.
        // A system route/device change makes failed devices eligible again.
        let eligible = eligibleDevices(devices)
        for device in eligible {
            do {
                if currentDevice?.id == device.id, let engine {
                    engine.reset()
                    try bind(engine, to: device)
                    engine.prepare()
                    try engine.start()
                } else {
                    tearDown()
                    try makeGraph(device: device)
                }
                failedDevices.remove(device.id)
                currentDevice = device
                baseFrame = cursor
                reschedule(after: cursor)
                if wantsPlayback { player?.play() }
                logger.notice("Audio output connected: \(device.name, privacy: .public)")
                return
            } catch {
                lastError = error
                failedDevices.insert(device.id)
                logger.error("Audio output failed: \(device.name, privacy: .public), \(error.localizedDescription, privacy: .public)")
                tearDown()
            }
        }
        if let error = lastError as? SpeechError { throw error }
        throw SpeechError.audioOutputUnavailable(code: (lastError as NSError).code)
    }

    private func eligibleDevices(_ devices: [AudioOutputDevice]) -> [AudioOutputDevice] {
        devices.filter { !failedDevices.contains($0.id) }
    }

    private func makeGraph(device: AudioOutputDevice) throws {
        let graph = AVAudioEngine()
        engine = graph
        let node = AVAudioPlayerNode()
        let speed = AVAudioUnitTimePitch()
        player = node
        pitch = speed
        graph.attach(node)
        graph.attach(speed)
        graph.connect(node, to: speed, format: format)
        graph.connect(speed, to: graph.mainMixerNode, format: format)
        // Create the complete graph before binding its output unit: creating
        // the mixer can otherwise renegotiate the device back to the default.
        // Leave the mixer's output connection automatic so AVAudioEngine performs
        // rate/channel conversion for the device, rather than pinning its format.
        try bind(graph, to: device)
        speed.rate = rate
        graph.prepare()
        try graph.start()
    }

    private func bind(_ graph: AVAudioEngine, to device: AudioOutputDevice) throws {
        var alive = AudioOutputDevice.property(kAudioDevicePropertyDeviceIsAlive)
        guard device.id != kAudioObjectUnknown, AudioObjectHasProperty(device.id, &alive) else {
            throw SpeechError.audioOutputUnavailable(code: Int(kAudioHardwareBadDeviceError))
        }
        guard let unit = graph.outputNode.audioUnit else {
            throw SpeechError.audioOutputUnavailable(code: -1)
        }
        var id = device.id
        let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global, 0, &id, UInt32(MemoryLayout<AudioDeviceID>.size))
        guard status == noErr else { throw SpeechError.audioOutputUnavailable(code: Int(status)) }
        let hardware = graph.outputNode.outputFormat(forBus: 0)
        guard hardware.sampleRate > 0, hardware.channelCount > 0 else {
            throw SpeechError.audioOutputUnavailable(code: -1)
        }
    }

    private func reschedule(after cursor: AVAudioFramePosition) {
        let old = pending
        pending.removeAll(keepingCapacity: true)
        for item in old {
            let skipped = min(AVAudioFramePosition(item.buffer.frameLength), max(0, cursor - item.startFrame))
            let remaining = item.buffer.frameLength - AVAudioFrameCount(skipped)
            guard remaining > 0 else { item.completion(); continue }
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: remaining)!
            buffer.frameLength = remaining
            buffer.floatChannelData![0].update(
                from: item.buffer.floatChannelData![0].advanced(by: Int(skipped)), count: Int(remaining))
            let resumed = PendingBuffer(id: item.id, buffer: buffer,
                startFrame: max(cursor, item.startFrame), completion: item.completion)
            pending.append(resumed)
            enqueue(resumed)
        }
    }

    private func tearDown() {
        generation = UUID() // Ignore completion callbacks caused by stopping the old graph.
        player?.stop()
        engine?.stop()
        player = nil
        pitch = nil
        engine = nil
    }

    private func reportRoute(devices: [AudioOutputDevice]) {
        guard let currentDevice else { return }
        onRoute?(currentDevice.id == devices.first?.id ? nil : currentDevice.name)
    }

    private func fail(_ error: Error) {
        let callback = onError
        request = nil
        pending.removeAll()
        wantsPlayback = false
        tearDown()
        callback?(error)
    }
}
