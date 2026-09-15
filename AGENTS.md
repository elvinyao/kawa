# Repository Guidelines

## Project Structure & Module Organization

Kawa is a macOS menu bar app for switching input sources with keyboard shortcuts.

- `kawa/`: Swift sources. `InputSourceManager.swift` wraps Carbon input sources; `ShortcutCellView.swift` binds shortcuts; `PermanentStorage.swift` stores preferences.
- `kawa/en.lproj/Main.storyboard` and `kawa/Images.xcassets/`: interface and bundled icons. `resource/` contains artwork.
- `kawa.xcodeproj/`: project settings and shared scheme. `Cartfile` and `Cartfile.resolved` declare and lock MASShortcut; `kawa/BridgingHeader.h` exposes it to Swift.

## Build, Test, and Development Commands

Project settings specify Swift 5.0 language mode and macOS 10.15 deployment. MASShortcut is pinned to 2.4.0.

- `xcodebuild -version`: inspect the selected native Xcode toolchain.
- `carthage bootstrap`: prepare dependencies.
- `xcodebuild -project kawa.xcodeproj -target kawa -configuration Debug build`: build the app. Open `kawa.xcodeproj` in Xcode for interactive runs.

Use native macOS and Xcode for builds and input-method validation. The repository's former Docker-only execution policy was explicitly revoked by the user on 2026-09-15.

## Coding Style & Naming Conventions

Use two-space indentation, same-line opening braces, `UpperCamelCase` types, and `lowerCamelCase` members. Match existing filenames and extension naming, such as `TISInputSource+Additions.swift`. Preserve storyboard outlets/actions when renaming symbols. No formatter or linter is configured. Keep generated Carthage, build, and Xcode user files untracked.

## Testing Guidelines

There is no active test target, test directory, CI pipeline, or coverage threshold. The shared scheme retains stale `kawaTests` references. If introducing automated tests, add an XCTest target, use `*Tests.swift` files and `test...` methods, and repair the scheme.

macOS validation should cover shortcut assignment/removal, input switching (including CJK sources), preference persistence, notifications, and status-bar behavior. Record checks unavailable under Docker as unverified.

## Commit & Pull Request Guidelines

Follow history's short, imperative subjects, such as `Simplify table view.` Keep commits focused. PRs should explain behavior changes, link relevant issues, describe validation and limitations, and include screenshots for visible UI changes.

## Agent Execution Policy

Native host commands are authorized for dependency setup, builds, tests, packaging, and Git operations in this repository. Computer use of the local Xcode app is also authorized. Use project-local build directories, preserve the user's input-source and shortcut preferences during tests, and restore temporary settings after validation. Do not change system-wide security settings or publish releases without explicit authorization. Docker is not required.
