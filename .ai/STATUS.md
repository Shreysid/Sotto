# Project status

Version 1.0.1 (build 2) is implemented on `fix/macos-audio-startup`.

Audio playback now follows selected outputs, observes device/configuration changes, preserves pending audio and pause state during recovery, and falls back automatically when a selected device fails. The complete graph is constructed before output-unit binding. Failed-device timeouts are suppressed until route/device changes. Fallback is named in the menu and Studio. Shared Kokoro warm-up and timing diagnostics remain in place.

See `docs/history/002-v1-0-1-audio-device-recovery.md` for design, validation, and limitations. Silent hardware checks include automatic recovery from the failing LG ULTRAWIDE to available speakers without changing system output settings. Physical Bluetooth playback still needs device validation.

Version 1.0.1 (2) is installed and running from `/Applications/Sotto.app`. Startup logs confirmed Neural Engine warm-up in 3.75 seconds on the installation launch. The previous app was backed up to `/private/tmp/Sotto-backup-20261020-143952/Sotto.app` (temporary storage). The release has not been published.

The installed build does not include an updater. A future updater-enabled release can use Sparkle 2 with an HTTPS appcast and signed archives for scheduled checks, an explicit Check for Updates action, and install/defer choices.
