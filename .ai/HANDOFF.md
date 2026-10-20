# Handoff

Use `fix/macos-audio-startup` for the audio startup fixes. FluidAudio remains pinned to the existing resolved revision.

Build with the Sotto scheme in Release. The diagnostic build uses `/tmp/sotto-diagnostics-build` and package checkouts in `/tmp/sotto-source-packages`. Direct model timing and startup regression harnesses are temporary diagnostic files under `/tmp/sotto-*`.

To recover from the observed output failure, choose a working output in System Settings → Sound → Output. Reinstalling Kokoro does not address the display's CoreAudio timeout.

Remaining validation: interactive playback with the repaired output, output changes during playback, sleep/wake, and broader latency measurements. The installed app has not been replaced.
