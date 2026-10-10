# Apple Silicon (arm64) macOS build

This fork adds two things on top of [nurupo/vlc-pause-click-plugin](https://github.com/nurupo/vlc-pause-click-plugin):

1. **A native Apple Silicon (arm64) build** for VLC 3.0.x on macOS.
   The official macOS releases are x86_64 only and cannot be loaded by the arm64 VLC.
2. **Working "ignore double click" on macOS.**
   With the original plugin, double-clicking to toggle fullscreen also pauses the video on macOS.
   This fork fixes that: **single click = pause/play, double click = fullscreen only.**

Windows and Linux behavior is unchanged (all changes are inside `#ifdef __APPLE__`).

日本語の説明は [README.ja.md](README.ja.md)、設計の詳細は [double-click.ja.md](double-click.ja.md) を参照してください。

## Install (prebuilt binary)

Tested with VLC 3.0.18 and 3.0.23 (arm64) on macOS.

1. Download `libpause_click_plugin.dylib` from the [Releases](https://github.com/Ryohei-Yamazaki/vlc-pause-click-plugin/releases) page.
2. Remove the quarantine flag (the binary is ad-hoc signed, not notarized):
   ```sh
   xattr -d com.apple.quarantine ~/Downloads/libpause_click_plugin.dylib
   ```
3. Quit VLC and copy it into VLC:
   ```sh
   cp ~/Downloads/libpause_click_plugin.dylib /Applications/VLC.app/Contents/MacOS/plugins/
   ```
4. Start VLC once with a fresh plugin cache:
   ```sh
   /Applications/VLC.app/Contents/MacOS/VLC --reset-plugins-cache
   ```
5. Enable the plugin as described in [Usage](../README.md#usage) —
   **both** `Interface > Control interfaces` **and** `Video > Filters` must be checked.

## Build from source

Requirements: Xcode Command Line Tools (`xcode-select --install`) and arm64 VLC 3.0.x in `/Applications`.

```sh
macos/build-arm64.sh            # build -> build/dist/libpause_click_plugin.dylib
macos/build-arm64.sh --install  # build and install into VLC.app (quit VLC first)
```

The script detects the installed VLC version, downloads the matching plugin SDK headers
from download.videolan.org, compiles, and ad-hoc signs the plugin.
Re-run it after updating VLC.

## How the macOS double click handling works

On macOS, the Cocoa video output consumes the second click of a double click for its
native fullscreen toggle, so the plugin only ever sees **one** press for both a single and a
double click. The original double-click detection therefore never triggers on macOS.

This fork detects a double click after the fact: if the fullscreen state changes within the
double-click interval (default 300 ms) after a press, it was a double click.

| State before | Action | Result |
|---|---|---|
| Playing | single click | pauses immediately |
| Playing | double click | fullscreen toggles; the instant pause is undone (hidden by the fullscreen animation) |
| Paused | double click | fullscreen toggles; stays paused |
| Paused | single click | resumes after the double-click interval (~300 ms) |

Settings (`Video > Filters > Pause/Play video on mouse click`):

| Option | Default (macOS) | |
|---|---|---|
| Prevent pause/play from triggering on double click | **on** | off = pause/play on every click |
| Custom double click interval (milliseconds) | 300 | used on macOS even if "Enable the custom double click interval" is off; increase if your double clicks are slow |
