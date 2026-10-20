# Audio output startup and model preparation

The initial output-error handling described here is superseded by the automatic recovery in [v1.0.1](002-v1-0-1-audio-device-recovery.md).

## Summary

Report audio-output startup failures with a recovery action, order engine startup with player controls, and share model preparation across concurrent requests.

## Motivation

On macOS 27.0.1, an LG ULTRAWIDE selected as the default output failed to establish a CoreAudio timeline. Each attempt waited approximately ten seconds and returned AVFAudio error 1937010544 (`stop`). The failure occurred before synthesis and was displayed as an unexplained voice-engine error.

Cold model preparation also takes longer than ordinary synthesis and could overlap another preparation call because actor methods can interleave at awaited operations.

## Design

Keep output startup on the serial playback queue. When the engine is stopped, reset it and reconnect the pitch unit to the mixer before starting it. Surface a Sound settings recovery instruction on failure. Preserve the selected system output.

Share a single preparation task between startup and speech requests. Establish the request identity before preparation so stopping or replacing a request during warm-up prevents it from starting playback later. Wait for preparation before deleting model files.

## Implementation

- Serialize engine preparation and startup with player stop, scheduling, and speed changes.
- Reset failed engine state for the next attempt; avoid automatic retries that would add another hardware timeout.
- Share model initialization and warm-up until it completes.
- Clear active playback state on preparation, output, or synthesis failure.
- Log output startup, model preparation, synthesis, and accelerator fallback at persisted log levels without logging selected text.
- Measure first-audio latency from request entry, including preparation and output startup. Selection capture remains separate.

## Files Changed

- `Sotto/Services/SpeechController.swift`
- `Sotto/Services/SpeechControllerPlayback.swift`
- `Sotto/Services/SpeechControllerKokoro.swift`
- `Sotto/Services/SpeechControllerSynthesis.swift`
- `Sotto/Services/SpeechTypes.swift`
- `README.md`
- `.gitignore`

## Validation

On macOS 27.0.1 with Xcode 27 and the pinned FluidAudio revision:

- Release build succeeded.
- Silent engine-start probe using Sotto's player/pitch/mixer graph: LG ULTRAWIDE failed with 1937010544 after 10.11 seconds; the same probe routed only its own engine to MacBook Pro Speakers started in 0.033 seconds. The system output selection was unchanged.
- Direct Kokoro benchmark: initialization 11.82 seconds; first `Ready.` synthesis 5.42 seconds; subsequent short passages of 71–94 characters took 0.90–1.70 seconds. These are single-run measurements, not latency guarantees.
- Startup regression check covers concurrent preparation, stopping a speech request during warm-up, and reuse of the prepared model.

## Tradeoffs

A stalled output device still incurs the macOS hardware timeout. The application can explain the failure and reset its graph, but cannot repair the display driver. Reconnecting does not guarantee recovery from every device change, particularly during active playback.

First-audio timing ends after the first buffer is queued and play is requested; it does not measure physical speaker onset. Cold loading, text composition, model fallback, and system load can still affect latency.

## Future Work

Collect timing distributions across longer passages and sleep/wake cycles. Add dedicated coverage for output-device changes during active playback and expose accelerator status if fallback proves common.
