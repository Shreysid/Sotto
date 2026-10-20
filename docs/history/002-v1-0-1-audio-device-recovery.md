# v1.0.1 — Automatic audio-device recovery

## Summary

Sotto follows the selected macOS audio output and recovers automatically from device and audio-format changes. If a selected output cannot start, it tries another available device and names the fallback in the menu and Studio. Version: **1.0.1**, build **2**.

## Motivation

An error message directing users to switch audio outputs does not provide reliable playback across displays, Bluetooth audio, and built-in speakers. CoreAudio can stop an engine during device reconfiguration, discard queued buffers, and issue completion callbacks even though speech has not finished.

## Design

A dedicated audio-output object owns the engine, player, pitch unit, output selection, and pending buffers on one serial queue. Speech synthesis remains in the speech controller. Output startup runs asynchronously so a stalled hardware start does not block the speech actor or interface.

The recovery order is the selected output, the last working output, built-in audio, then remaining live outputs. Device IDs are deduplicated. The system-wide output selection is never changed. A route that already failed is skipped while another output works; system output or device-list changes make it eligible again. If every output fails, the next explicit request retries discovery.

## Implementation

- Construct the entire audio graph before explicitly binding the output unit. Let the mixer negotiate its output format with the device.
- Monitor default-output, connected-device, and engine-configuration changes. Debounce related events and recover away from Apple's notification thread.
- Restart a stopped graph on the same device or replace it when moving to another device.
- Retain pending buffers, track playback position every 100 milliseconds, trim played samples, and restore playback or pause after recovery.
- Invalidate callbacks from old graph generations and ignore hardware-stopped completion callbacks.
- Reject stale request buffers and empty audio, and report failure only after available outputs are exhausted.
- Display the automatic fallback device in the menu and Studio.
- Set both Debug and Release to marketing version 1.0.1 and build number 2.

## Files Changed

- `Sotto/Services/AudioOutputDevice.swift`
- `Sotto/Services/SpeechAudioOutput.swift`
- `Sotto/Services/SpeechController.swift`
- `Sotto/Services/SpeechControllerPlayback.swift`
- `Sotto/Services/SpeechTypes.swift`
- `Sotto/App/SottoAppState.swift`
- `Sotto/App/SottoAppStatePlayback.swift`
- `Sotto/UI/MenuBar/SottoMenuBarView.swift`
- `Sotto/UI/Studio/SottoStudioSettingsView.swift`
- `Sotto.xcodeproj/project.pbxproj`
- `tests/AudioOutputChecks.swift`
- `tests/check-audio-output.sh`
- `README.md`

## Validation

- Release build on macOS 27.0.1 / Xcode 27; embedded bundle version checked as 1.0.1 (2).
- `tests/check-audio-output.sh`: selected Bluetooth/display preference, fallback order, disconnected selection, and deduplication.
- `tests/check-audio-output.sh --hardware`: silent real playback; unavailable-route recovery while paused; saved-position resume within a deadline shorter than the original buffer; exactly-once completion; failed-device suppression; stale-request rejection; and no-output errors.
- The live hardware test starts with the failing LG ULTRAWIDE selected and automatically plays through an available output. No system settings are changed.

## Tradeoffs

The first attempt to open a broken driver can still incur macOS's hardware timeout. Recovery cannot make a physically unavailable output produce sound; Sotto uses another available output instead. Playback position may repeat up to approximately one position-sampling interval if hardware stops before its final render timestamp can be read.

Bluetooth route selection is covered by deterministic checks. A physical Bluetooth device was not connected during validation, so profile transitions and disconnects still require device testing. The packaged build is unsigned, consistent with the existing preview distribution.

## Future Work

Validate physical Bluetooth profile changes, display hot-plug, and sleep/wake on additional Macs. Add distribution signing and notarization when a signing identity is available.
