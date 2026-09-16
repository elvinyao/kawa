# Dynamic Input Sources Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkboxes for tracking.

**Goal:** Restore the original system-derived input-source list while retaining the Apple Silicon test build's shortcut and switching improvements.

**Architecture:** Discover enabled, selectable keyboard sources through Carbon. Give each source/mode a stable identity independent of its localized name and list position. The application owns catalog refresh, shortcut registrations, and verified switching; the settings window displays that catalog. Apple Japanese normal Hiragana remains an explicit source/mode, with Kanji conversion supported.

**Tech Stack:** Swift 5, AppKit, Carbon TIS, pinned MASShortcut, XCTest; native Xcode, arm64/macOS 12 floor.

## Approved scope and existing work

The user's 2026-09-16 instruction supersedes the earlier fixed-three-target scope. Show all system-enabled/selectable keyboard sources, including third-party sources and separately selectable modes. Do not invent rows for absent Pinyin/Japanese/ABC. Use system names/icons and distinguish modes; selecting the normal Japanese Hiragana row must select/verify that mode rather than a language container or Roman/Katakana mode.

Preserve transactional edits, duplicate checks, clear tombstones, legacy migration, app-lifetime registrations, stale-action/feedback suppression, optional notifications, existing UI, and native build configuration. Refresh on app startup, enabled-source changes, and opening/activating settings. Removing a source releases its hotkey without erasing its saved binding; re-enabling it restores that binding. No new permission, auto-enabling sources, publication, or system-security changes.

Continue on `codex/apple-silicon-input-switching`. A pre-existing uncommitted `kawa/en.lproj/Main.storyboard` change must be preserved and excluded from implementation commits. No parallel implementers.

## Task 1: Implement and review dynamic catalog integration

**Files:** `kawa/InputTarget.swift`, `CarbonInputSourceAccess.swift`, `InputSourceManager.swift`, `ShortcutController.swift`, `ShortcutStore.swift`, `AppServices.swift`, `AppDelegate.swift`, `ShortcutViewController.swift`, related `kawaTests/*Tests.swift`; project references only if required. Existing feedback/cell code may be adapted to the dynamic target model. Do not modify the storyboard.

- [ ] Add failing regression tests for a fourth/third-party source, excluded disabled/unselectable/non-keyboard entries, duplicate descriptors, distinct modes, and stable identity/storage across renames/reordering. A representative assertion is `XCTAssertEqual(catalog.map(\.sourceID), ["com.example.inputmethod.Custom", "com.apple.keylayout.ABC"])` for an eligible fixture catalog in system order.
- [ ] Replace production `InputTarget.allCases` enumeration with an injected catalog. Separate identity (source ID plus optional mode ID) from presentation. Use a collision-free persisted identity encoding, e.g. a versioned base64 encoding of a JSON array containing source ID and nullable mode ID. Match exact identity for arbitrary sources; ensure Apple's normal Hiragana target remains exact and explicitly recognizable.
- [ ] Add migration regressions before changing storage: original dot-to-hyphen source keys work for arbitrary sources; the previous `shortcut.pinyin`, `shortcut.hiragana`, and `shortcut.abc` archives and empty tombstones migrate to their corresponding dynamic entries. An existing new value, including an empty/corrupt canonical value, must not fall back and resurrect old data. Leave legacy keys untouched.
- [ ] Add controller/service regressions for source addition/removal/re-addition, unchanged-source refresh without duplicate registrations, renamed labels, persisted duplicates, stale callbacks after removal, and callback-driven stop/restart/refresh. Drive `refreshTargets(_:)` with injected arrays; assert removed registrations are released, saved data retained, and additions restored independently of any window.
- [ ] Implement catalog reconciliation and app-owned enabled-source notifications on the main queue. Refresh on startup and settings appearance/activation. Release removed registrations; retain unchanged ones and metadata freshness; reject edits/triggers for removed identities. Invalidate pending feedback for removed targets. Avoid resetting a recorder for a presentation-only refresh.
- [ ] Display dynamic rows with system names/icons; show a useful empty-state message. Keep normal Hiragana explicit without hiding other system-enabled modes. Do not show unavailable fixed presets.
- [ ] Run native tests after the red phase, resolve failures, self-review, and commit only implementation/test files. Keep all prior lifecycle/verification tests meaningful, adapting fixtures rather than disabling assertions.
- [ ] Complete independent spec review, then code-quality review; fix important findings and re-review before delivery.

Test command (native execution already authorized):

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project kawa.xcodeproj -scheme kawa -configuration Debug -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' test
```

Expected red: new catalog assertions fail before implementation. Expected green: all old and new tests pass. Tests remain unhosted and must not change production input sources or register physical hotkeys.

## Task 2: Verify native UI and update delivery

**Files:** `AGENTS.md`, `README.md`, `docs/install-zh.md`, `docs/testing.md`, `docs/release-checks.md`, this plan; ignored `build/` artifacts.

- [ ] Update contributor/install documentation to describe system-derived sources, per-mode shortcuts, add/remove refresh, and migration. Keep earlier test evidence clearly associated with its original build.
- [ ] Build Release with the command below. Inspect actual list via Computer Use, compare it with configured sources where available, and record any unavailable manual checks honestly. Synthetic letter events were unreliable in previous testing; do not claim physical-keyboard acceptance from them.
- [ ] Verify the Release arm64 executable and ad-hoc signature. Copy the app and four documents using `docs/packaging.md`, rebuild ZIP, run `unzip -t`, and record the new SHA-256 outside the archive.
- [ ] Commit final documentation after review; retain the development branch and the pre-existing storyboard change. Do not publish, merge, or push.

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project kawa.xcodeproj -scheme kawa -configuration Release -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' -quiet build
```

## Self-review

Task 1 covers arbitrary sources, per-mode identity, migration, refresh, background lifecycle, Japanese precision, and preserved error/notification behavior. Task 2 covers documentation, native observation, and test-package integrity. Existing storyboard edits and user preferences remain protected; actual OS acceptance is reported separately from injected-boundary tests.
