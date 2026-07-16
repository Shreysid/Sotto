# Sotto

Sotto is a native macOS app that reads selected text aloud with a fast, expressive local voice. It uses FluidAudio to run Kokoro-82M on-device and keeps the model warm after startup for quicker playback.

## Features

- Read selected text from any macOS app with a configurable global shortcut.
- Run Kokoro locally after its one-time model download.
- Stream long selections in smaller sections for faster first audio.
- Control playback speed, pause, skip, and stop from the menu bar.
- Add custom pronunciation rules for names, acronyms, and technical terms.

## Requirements

- macOS 15 or later
- Apple silicon Mac recommended
- Xcode 26 or later for building from source
- Internet access for Swift Package Manager and the first Kokoro model download

## Build From Source

1. Clone the repository:

   ```bash
   git clone https://github.com/Shreysid/Sotto.git
   cd Sotto
   ```

2. Open the Xcode project:

   ```bash
   open Sotto.xcodeproj
   ```

3. In Xcode, choose the `Sotto` scheme and `My Mac` as the run destination.
4. Build and run with `Cmd+R`. Xcode resolves FluidAudio through Swift Package Manager on the first build.
5. When Sotto opens, allow Accessibility access. It is required to read selected text and respond to the global shortcut.
6. Download Kokoro from Sotto's first-run prompt. The model stays outside the app bundle and is loaded locally.

## Usage

Select text in any app, then use the configured global shortcut. Open **Sotto Studio** from the menu bar to change playback speed, set pronunciation rules, and view usage stats.

## Privacy

Selected text and generated audio remain on-device. Sotto connects to the model host only for the initial Kokoro download and related updates.

## Credits

- [FluidAudio](https://github.com/FluidInference/FluidAudio) provides the local Apple Silicon audio inference and model-management layer.
- [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) provides Sotto's expressive text-to-speech model.

Both FluidAudio and Kokoro-82M are licensed under Apache-2.0.

## License

Sotto is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE).
