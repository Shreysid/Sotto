# Project status

The audio-output startup and warm-up fixes are on `fix/macos-audio-startup`.

Diagnosis on macOS 27.0.1: the default LG ULTRAWIDE output times out after approximately ten seconds with CoreAudio/AVFAudio 1937010544. A silent engine probe starts on MacBook Pro Speakers in 0.033 seconds. Warm Kokoro synthesis of short passages measured 0.90–1.70 seconds; cold initialization and warm-up were substantially slower.

The changes provide actionable output errors, serialize audio startup with player operations, share model preparation, respect cancellation during preparation, and log separate timing stages. See `docs/history/001-audio-output-startup.md` for evidence and limitations.

The installed application and system audio-output selection have not been changed.
