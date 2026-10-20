import CoreAudio
import Foundation

nonisolated struct AudioOutputDevice: Equatable, Sendable {
    let id: AudioDeviceID
    let name: String
    let isBuiltIn: Bool

    static func candidates(lastWorking: AudioDeviceID?) throws -> [AudioOutputDevice] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var selected: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = property(kAudioHardwarePropertyDefaultOutputDevice)
        let status = AudioObjectGetPropertyData(system, &address, 0, nil, &size, &selected)
        guard status == noErr else { throw SpeechError.audioOutputUnavailable(code: Int(status)) }

        address = property(kAudioHardwarePropertyDevices)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else {
            throw SpeechError.audioOutputUnavailable(code: -1)
        }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard !ids.isEmpty else { return [] }
        let readStatus = ids.withUnsafeMutableBytes {
            AudioObjectGetPropertyData(system, &address, 0, nil, &size, $0.baseAddress!)
        }
        guard readStatus == noErr else { throw SpeechError.audioOutputUnavailable(code: Int(readStatus)) }
        let devices = ids.compactMap { id -> AudioOutputDevice? in
            var streams = property(kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeOutput)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamSize) == noErr,
                  streamSize > 0, uint32(id, kAudioDevicePropertyDeviceIsAlive) == 1 else { return nil }
            return AudioOutputDevice(
                id: id, name: name(id),
                isBuiltIn: uint32(id, kAudioDevicePropertyTransportType) == kAudioDeviceTransportTypeBuiltIn)
        }
        return ordered(devices, selected: selected, lastWorking: lastWorking)
    }

    static func ordered(
        _ devices: [AudioOutputDevice], selected: AudioDeviceID, lastWorking: AudioDeviceID?
    ) -> [AudioOutputDevice] {
        // Prefer the user's route, then a known working route, then built-in audio.
        let preferred = [selected, lastWorking].compactMap { $0 }
        var ordered: [AudioOutputDevice] = []
        for id in preferred {
            if let device = devices.first(where: { $0.id == id }), !ordered.contains(device) {
                ordered.append(device)
            }
        }
        for device in devices.filter({ $0.isBuiltIn }) + devices {
            if !ordered.contains(device) { ordered.append(device) }
        }
        return ordered
    }

    static func property(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func uint32(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32 {
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = property(selector)
        _ = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        return value
    }

    private static func name(_ id: AudioObjectID) -> String {
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var address = property(kAudioObjectPropertyName)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        guard status == noErr, let value else { return "Audio output" }
        return value.takeRetainedValue() as String
    }
}
