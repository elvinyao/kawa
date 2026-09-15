# Kawa Apple Silicon Input Switching Design

## Approval and scope

The user approved this design in conversation on 2026-09-15 and explicitly requested an implementation plan followed by implementation. The user also revoked the repository's Docker-only rule and authorized native macOS/Xcode execution and computer use of Xcode. Continue through implementation without another planning handoff.

The first release is an Apple Silicon-only test build for the user's own use and limited sharing. Preserve the existing AppKit/storyboard settings window and shortcut recorder interaction. Provide three independently configurable shortcuts: Apple Pinyin, Apple Japanese Hiragana, and ABC. Japanese must always select Hiragana, rather than restore an arbitrary last-used Japanese mode. No Developer ID distribution, notarization, public publishing, or Intel support is included.

## Compatibility and build

- Build app and dependency code for arm64 using the installed Xcode 27.0 (27A266a).
- Set the deployment target to macOS 12.0, the oldest target accepted by the installed SDK. This is a build floor, not a claim that every macOS release has been tested.
- The primary acceptance environment is the user's macOS 27.0 (26A428). Record other versions as unverified unless exercised.
- Replace unavailable Carthage integration with the upstream `cocoabits/MASShortcut` Swift package. Resolve its existing master branch once, record the exact revision in Package.resolved, and pin the project to that revision before delivery.
- Preserve upstream BSD-2-Clause licensing in the application/test distribution. The application remains MIT licensed.
- Repair stale scheme/test references and the storyboard's nonexistent ShortcutTableView class.

## Components

### Input targets and system access

`InputTarget` describes the three user-facing destinations. Resolve targets using stable Apple input-source and input-mode identifiers, never localized display names. ABC identifies `com.apple.keylayout.ABC`; Pinyin identifies `com.apple.inputmethod.SCIM.ITABC`; Hiragana requires Apple's Japanese mode `com.apple.inputmethod.Japanese` within the Apple Japanese/Kotoeri input method. A Katakana or Roman mode is never an acceptable Hiragana result.

A Carbon adapter enumerates enabled/selectable sources, selects a freshly resolved source, and reads the current source including mode ID. Do not enable, install, remove, or reorder the user's system input sources. Missing sources produce an actionable error.

### Verified switching

An app-owned switcher requests selection and checks the system-reported result. An already-selected exact target succeeds without another selection request. A nonzero OSStatus fails immediately. Otherwise check immediately and at 50 ms intervals for at most 20 delayed checks. If the target is still not selected, report failure. A newer request supersedes verification of an older request, so stale success/failure feedback cannot overwrite the latest result. There are no blind repeated selection requests.

### Shortcut lifecycle and persistence

Shortcut ownership belongs to an application-lifetime controller, initialized before the settings window is needed. It restores saved bindings at startup, registers/unregisters only its own shortcuts, and supports idempotent start/stop. Every target has a stable storage key. Read existing MASShortcut archives using a safe codec and migrate supported legacy source-ID keys without deleting them. Corrupt settings must not crash the app or cause unexpected hotkey registration.

Use MASShortcutMonitor directly because MASShortcutBinder discards registration failure. Compare normalized key-code/modifier pairs to reject duplicate assignments across Kawa targets. MASShortcutView's validator continues checking the system/menu conflicts it can detect. Do not claim to detect every shortcut in every third-party app.

Changing a shortcut is transactional: reject duplicates before mutation; attempt the new registration before removing an existing working binding; only persist a successful change. Clearing a binding unregisters it and saves the cleared state. Failed persisted registrations remain visible as failures and can be retried after a conflicting binding is cleared. Window creation/destruction never owns registrations.

### Settings and feedback

Keep the current window, tabs, table layout, and MASShortcutView recorder. Show three stable destination rows; Japanese explicitly indicates Hiragana. The cell loads its value from the controller and reports edits to it, without defaults binding or hotkey registration inside the view. Guard programmatic recorder updates against callback recursion.

Keep shortcut settings editable even when a source is missing, and explain which source needs enabling. Present recording/registration errors in the settings window. Global switching failures use visible menu-bar status and a readable explanation without stealing the active application's keyboard focus. Success feedback is emitted only after verification. Preserve the notification preference; use UserNotifications for optional success notifications, request authorization only in response to opting in, and handle denial without treating a successful switch as failure.

## Verification

Use an unhosted XCTest target compiling the actual non-UI application services. Unit tests must not launch AppDelegate or alter the user's real preferences/input source. Use a unique UserDefaults suite for storage and narrowly scoped fakes for Carbon/OS hotkey boundaries.

Required automated cases: exact target resolution; Hiragana rejects Katakana/Roman modes; missing/disabled source; selection OSStatus failure; immediate/delayed confirmation; timeout; newer request supersedes old verification; startup without a window; idempotent registration; duplicate assignments; successful edit/clear; failed replacement preserves working binding and persisted value; legacy archive migration; corrupt data; restart restoration; cleanup only removes owned registrations.

Use native Xcode and computer use to verify app launch, existing settings layout, recording and clearing shortcuts, and direct switching among the installed sources. Verify actual Hiragana text entry as well as reported mode. Exercise rapid switches, another application's text field, candidate/composition handling, and relaunch. Any case that cannot be safely automated or observed must remain explicitly unverified. Record and restore all temporary test shortcuts and the original input source; never alter unrelated preferences or system-wide security settings.

## Delivery

Produce a Release `Kawa.app` with local/ad-hoc signing suitable for testing, package it with concise Chinese installation notes, the license notices, and a test checklist. Verify Mach-O architecture, signature integrity, and archive contents. Clearly state the build is not Developer ID signed/notarized, and downloaded copies may encounter Gatekeeper restrictions. Do not publish or install into /Applications automatically. Keep source changes on `codex/apple-silicon-input-switching` for review.

## Environment note

The old global Docker hook remained active after AGENTS.md changed. Automatic review rejected an unrestricted per-directory exception. A narrower approved exception permits only explicit Kawa Xcode commands and scoped local Git operations. Preserve that boundary; request ordinary sandbox escalation for a concrete native build when Xcode needs its caches or network. Do not bypass the hook via an alternate execution mechanism.
