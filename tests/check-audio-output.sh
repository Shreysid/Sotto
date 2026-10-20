#!/bin/zsh
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
check_dir="$(mktemp -d /tmp/sotto-audio-checks.XXXXXX)"
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -g -target "$(uname -m)-apple-macos15.0" -module-cache-path "$check_dir/modules" \
  "$repo_dir/Sotto/Services/AudioOutputDevice.swift" \
  "$repo_dir/Sotto/Services/SpeechAudioOutput.swift" \
  "$repo_dir/Sotto/Services/SpeechTypes.swift" \
  "$repo_dir/tests/AudioOutputChecks.swift" -o "$check_dir/checks"
"$check_dir/checks" "$@"
