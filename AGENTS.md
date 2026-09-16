# Repository Guidelines

## Project Structure & Module Organization

Kawa is a Swift/AppKit menu bar app for switching among macOS-enabled keyboard input sources, with independent shortcuts for selectable modes.

- `kawa/`: application sources. Separate input-source access, switching verification, shortcut registration, persistence, and UI presentation.
- `kawa/en.lproj/Main.storyboard` and `kawa/Images.xcassets/`: interface and bundled icons. `resource/` contains artwork.
- `kawa.xcodeproj/`: native targets, shared scheme, and the SwiftPM dependency lock.
- `kawaTests/`: unhosted XCTest tests; `docs/`: design, implementation plan, installation instructions, and validation evidence.

## Build, Test, and Development Commands

Use native Xcode on an Apple Silicon Mac. The project uses Swift 5 language mode, arm64, and a macOS 12 deployment floor. MASShortcut is pinned through Swift Package Manager.

```sh
xcodebuild -project kawa.xcodeproj -scheme kawa -configuration Debug -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' build
xcodebuild -project kawa.xcodeproj -scheme kawa -configuration Debug -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' test
```

The first command builds Kawa; the second runs XCTest. Use `-configuration Release` with `build` for distribution output. Open `kawa.xcodeproj` in Xcode for interactive runs.

## Coding Style & Naming Conventions

Use two-space indentation, same-line opening braces, `UpperCamelCase` types, and `lowerCamelCase` members. Match filenames to types; extensions use names such as `TISInputSource+Additions.swift`. Preserve storyboard outlets/actions. No formatter or linter is configured. Keep `build/` and Xcode user settings untracked.

## Testing Guidelines

Name test files `*Tests.swift` and methods `test...`. Test catalog changes, source/mode identity, migration, and shortcut lifecycle with injected OS boundaries and isolated UserDefaults suites. Unit tests must not register real hotkeys or change system input sources. No coverage percentage is mandated. Record native UI, CJK composition, persistence, and notification checks in `docs/testing.md`; label unobserved results UNVERIFIED.

## Commit & Pull Request Guidelines

Follow history's short, imperative subjects, such as `Simplify table view.` Keep commits focused. PRs should explain behavior changes, link relevant issues, describe validation and limitations, and include screenshots for visible UI changes.

## Agent Execution Policy

The user revoked Docker-only execution on 2026-09-15. Native builds, tests, packaging, Git work, and computer use of Xcode are authorized. Preserve user preferences and restore temporary test settings. Do not change system security settings or publish releases without explicit authorization.
