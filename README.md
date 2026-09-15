![logo](resource/png/logo.png)

# Kawa [![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/utatti/kawa/master/LICENSE) [![GitHub release](https://img.shields.io/github/release/utatti/kawa.svg)](https://github.com/utatti/kawa/releases)

A macOS input source switcher with user-defined shortcuts.

## Demo

[![demo](https://cloud.githubusercontent.com/assets/1013641/9109734/d73505e4-3c72-11e5-9c71-49cdf4a484da.gif)](http://vimeo.com/135542587)

## Apple Silicon test edition

This branch targets Apple Silicon Macs and preserves Kawa's settings window.
Assign one shortcut each to Apple's Pinyin, normal Japanese Hiragana (with Kanji
conversion), and ABC. Shortcuts belong to the running app and remain available
when its settings window is closed. Switching is confirmed against the system's
current input source before success is reported.

See the [Chinese installation guide](docs/install-zh.md) and
[validation record](docs/testing.md) for setup, observed results, and outstanding
manual checks. The deployment floor is macOS 12; this does not establish runtime
compatibility with every later macOS version.

This is an ad-hoc signed test edition, without Developer ID signing or
notarization. Historical upstream releases and Homebrew packages do not contain
these branch changes.

## Development

Open `kawa.xcodeproj` in native Xcode, select the `kawa` scheme and My Mac,
then Build or Run. Swift Package Manager resolves MASShortcut to the revision
recorded in `Package.resolved`; Carthage and Docker are not required.

From the repository root, with Xcode selected:

```sh
xcodebuild -project kawa.xcodeproj -scheme kawa -configuration Debug -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' build
xcodebuild -project kawa.xcodeproj -scheme kawa -configuration Debug -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' test
xcodebuild -project kawa.xcodeproj -scheme kawa -configuration Release -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' build
```

Build products are under `build/DerivedData/Build/Products/`. XCTest runs without
launching Kawa, registering global hotkeys, or changing the selected input source.
Actual CJK composition and app interaction also require the manual checks in the
validation record. See [Repository Guidelines](AGENTS.md) for contribution rules.

## License

Kawa is released under the [MIT License](LICENSE). MASShortcut's BSD-2-Clause
license is included in [third-party notices](THIRD-PARTY-NOTICES.md).
