# Apple Silicon Test Release Validation

This is the evidence log and reproducible checklist for the first limited test release. A PASS requires an observed result; an automated fake of an OS service does not establish a native input-method PASS.

## Environment

- Host OS: macOS 27.0, build 26A428 (read from SystemVersion.plist).
- Xcode: 27.0, build 27A266a (native xcodebuild output).
- Architecture: final Release executable verified as arm64.
- Deployment floor: macOS 12.0, dictated by Xcode 27's supported build range.
- Other macOS versions: UNVERIFIED.
- Distribution: local/ad-hoc test signing; no Developer ID signing or notarization.
- Test edition: version 1.2.0, build 2; window/display label `Kawa Test Build`.

## Automated build and tests

Run from the repository root with native Xcode:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project kawa.xcodeproj -scheme kawa -configuration Debug -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' test
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project kawa.xcodeproj -scheme kawa -configuration Release -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' build
```

Record completed runs and exact totals below. Unit tests use isolated UserDefaults suites and fake only Carbon/hotkey boundaries; they must not register real global hotkeys or change the user's input source.

| Check | Status | Evidence |
| --- | --- | --- |
| Original project baseline | FAIL (pre-existing) | Xcode 27 rejects deployment target 10.15; no Carthage framework installed. |
| Native Debug build | PASS | Final integrated source `e1fbc3e`; separate app build passed, and final parent-run test command rebuilt/validated the Debug app. |
| Legacy shortcut archive compatibility | PASS | 1 XCTest, 0 failures; legacy non-secure archive decoded using the typed secure decoder. |
| Input target and switching regression tests | PASS (Task 2) | Commit `4dace77`; 22 total XCTest cases, 0 failures. Covers exact modes, unavailable sources, OSStatus failures, confirmation, timeout, and stale requests. |
| Shortcut lifecycle and storage regression tests | PASS (Task 3) | Commit `4e1ea89`; 57 total XCTest cases, 0 failures. Covers transactional edits, duplicate recovery, callback lifecycle, legacy archives, corrupt settings, and cleared-state persistence. |
| Full suite, including application integration | PASS | Parent-run native tests at `e1fbc3e`: 81 tests, 0 failures, `TEST SUCCEEDED`, 2026-09-15 23:59 JST. Result: `build/DerivedData/Logs/Test/Test-kawa-2026.09.15_23-59-22-+0900.xcresult`. |
| Native Release build | PASS | Parent-run final native Xcode Release build at `e1fbc3e`, exit 0. Version 1.2.0 (2), bundle ID `net.noraesae.Kawa`, deployment floor 12.0. |
| Release executable arm64 | PASS | `file` reports `Mach-O 64-bit executable arm64`; codesign reports `Mach-O thin (arm64)`. |
| Release signature integrity | PASS | `codesign --verify --deep --strict --verbose=2` reports `valid on disk` and `satisfies its Designated Requirement`. Signature is ad-hoc; no TeamIdentifier. |
| Dependency revision and bundled licenses | PASS | MASShortcut pinned to `6f2603c6b6cc18f64a799e5d2c9d3bbc467c413a`; Release resources contain its localization bundle, MIT `LICENSE`, and `THIRD-PARTY-NOTICES.md`. |

The first sandboxed Release attempt could not write Xcode's compiler/SwiftPM caches;
the same authorized native command passed with cache access. Non-blocking toolchain
diagnostics included XCTest's newer library deployment floor and skipped AppIntents
metadata for this app, which does not use AppIntents.

## Manual validation procedure

### Read-only native input-source catalog

A temporary XCTest enumerated Carbon metadata without calling selection. The
current source remained ABC; the diagnostic was removed after recording these
results. All three rows below were enabled and selectable. Their parent input
method containers were not selectable.

| Target | Source ID | Mode ID | Bundle ID |
| --- | --- | --- | --- |
| ABC | `com.apple.keylayout.ABC` | none | `com.apple.keyboardlayout.all` |
| Pinyin | `com.apple.inputmethod.SCIM.ITABC` | `com.apple.inputmethod.SCIM.ITABC` | `com.apple.inputmethod.SCIM` |
| Japanese Hiragana | `com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese` | `com.apple.inputmethod.Japanese` | `com.apple.inputmethod.Kotoeri.RomajiTyping` |

The normal Japanese mode supports Kanji conversion. The separate SDK identifier
`com.apple.inputmethod.Japanese.Hiragana` describes Hiragana-only output without
Kanji conversion and is deliberately not used. Catalog inspection does not prove
actual typing or switching behavior.

### Interactive checks

Before testing, record the original selected input source, all three saved Kawa shortcuts, and the notification preference. Use a disposable document without private content. Choose temporary nonconflicting combinations through the recorder and restore the original settings afterward.

1. Launch Kawa and inspect the existing window, tabs, and shortcut recorder layout.
2. Record three distinct shortcuts. Try a duplicate and ensure the previous valid assignment remains in place.
3. Close the settings window and trigger each shortcut from a separate text application.
4. For ABC, enter ordinary Latin letters. For Pinyin, enter a syllable and observe conversion candidates. For Japanese, send actual keystrokes for `nihon`, observe Hiragana composition, and check that Kanji conversion remains available. Pasting text does not test the input method.
5. Select a different Japanese mode, then use Kawa's Japanese shortcut. Verify the system mode and actual typing return to normal Hiragana input.
6. Switch rapidly among all three targets. The final shortcut must determine the final mode; stale earlier feedback must not override it.
7. Change a shortcut and check old/new combinations. Clear it, relaunch, and ensure the cleared shortcut stays cleared.
8. Relaunch with saved shortcuts and use them before opening settings.
9. Test a switch while Pinyin/Japanese composition is in progress; record whether text is committed, retained, or cancelled. Do not promise composition preservation without evidence.
10. Check failure indication and optional success notifications independently. Do not enable a new system permission just for testing without applicable user authorization.
11. Quit the app; verify only its registrations are released. Restore the original selected source and saved settings and close the disposable document without replacing user files.

| Check | Status | Evidence |
| --- | --- | --- |
| App launch and preserved settings UI | UNVERIFIED | Computer Use initially blocked by locked Mac; unlock requested. |
| Recording/duplicate/edit/clear | UNVERIFIED | Requires native UI observation. |
| Hotkeys work without settings window | UNVERIFIED | Requires native UI observation. |
| ABC text entry | UNVERIFIED | Requires actual keystrokes. |
| Pinyin composition | UNVERIFIED | Requires actual keystrokes. |
| Japanese Hiragana and Kanji conversion | UNVERIFIED | Requires actual keystrokes and mode check. |
| Return from another Japanese mode | UNVERIFIED | Requires native UI observation. |
| Rapid switching and another application | UNVERIFIED | Requires native UI observation. |
| Relaunch restores saved/cleared state | UNVERIFIED | Requires native UI observation. |
| In-progress candidate/composition handling | UNVERIFIED | Requires native UI observation. |
| Failure feedback and optional notifications | UNVERIFIED | Requires native UI observation. |
| Temporary settings restored | NOT STARTED | No test hotkeys/input-source changes have been made. |

## Packaging

Final package: `build/release/Kawa-AppleSilicon-test.zip`. Include `Kawa.app`, Chinese installation instructions, this validation record, the MIT license, and the MASShortcut BSD-2-Clause notice. Exclude build caches, test products, signing credentials, user preferences, and private documents. Verify contents before sharing. Public upload is outside this task's authorization.

| Check | Status | Evidence |
| --- | --- | --- |
| Copied app architecture and signature | PASS | Staged app remains arm64; deep/strict codesign verification succeeds after copying. |
| ZIP contents | PASS | Listing contains the app, four intended documents, and normal `__MACOSX` archive metadata. No build caches or test products included. |
| ZIP integrity | PASS | `unzip -t` reports no errors in compressed data. |

The archive checksum is recorded separately in `docs/release-checks.md` so this
document does not embed its own archive's changing hash. Native interactive
acceptance remains UNVERIFIED; this package has not been publicly uploaded or
automatically installed into `/Applications`.
