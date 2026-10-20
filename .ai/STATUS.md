# Project status

Version 1.0.1 (build 2) is implemented on `fix/macos-audio-startup`.

Audio playback now follows selected outputs, observes device/configuration changes, preserves pending audio and pause state during recovery, and falls back automatically when a selected device fails. The complete graph is constructed before output-unit binding. Failed-device timeouts are suppressed until route/device changes. Fallback is named in the menu and Studio. Shared Kokoro warm-up and timing diagnostics remain in place.

See `docs/history/002-v1-0-1-audio-device-recovery.md` for design, validation, and limitations. Silent hardware checks include automatic recovery from the failing LG ULTRAWIDE to available speakers without changing system output settings. Physical Bluetooth playback still needs device validation.

The installed app has not been replaced and the release has not been published.
