# Handoff

Version 1.0.1 (2) is on `fix/macos-audio-startup`. FluidAudio remains at the existing pinned revision.

Build the Sotto scheme in Release. Current build products are under `/tmp/sotto-diagnostics-build`, with package checkouts in `/tmp/sotto-source-packages`. The local release archive belongs under `build/` and is ignored by Git.

Run `tests/check-audio-output.sh` for routing checks. Add `--hardware` for silent live engine tests; this requires access to CoreAudio and built-in speakers and does not change system output settings. It tests pause/resume recovery, saved position, callback ownership, automatic fallback, failure suppression, and error paths.

Important graph detail: create the mixer and internal connections before binding the output unit. Leave mixer-to-output negotiation automatic. Engine-configuration callbacks can arrive after setup; ignore stale graph callbacks and avoid tearing down an engine from Apple's notification thread.

Remaining validation: physical Bluetooth profile changes, display hot-plug, sleep/wake, and additional Mac hardware. The installed application has not been replaced. Signing/notarization and publishing are not performed.
