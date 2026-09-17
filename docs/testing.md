# Apple Silicon Test Release Validation

This is the evidence log and reproducible checklist for the first limited test release. A PASS requires an observed result; an automated fake of an OS service does not establish a native input-method PASS.

## Settings UI edition: 1.2.0 (4)

The user approved UI-only improvements on 2026-09-17: compact content fitting,
clearer list alignment, lighter shortcut controls, Shortcuts / General labels,
and contextual status presentation. Input discovery, saved bindings, switching,
and notification authorization behavior remain outside this change.

Baseline native inspection showed five input-source rows, Pinyin `⌘3`, other
bindings empty, and notifications off. The working checkout was clean at
`ee72312`; the earlier uncommitted storyboard rewrite was no longer present.
Verification on 2026-09-17, application source `c4f6a8b`:

- Native Debug XCTest: **117 passed, 0 failures**; native Release build passed.
- Built and staged executables: **arm64**; both passed deep/strict signature
  verification. Signing remains ad-hoc.
- Native light-appearance inspection: Shortcuts renders five complete rows in
  a compact window; General shrinks to its content. Names, icons, column
  alignment, help text, and notification checkbox have no observed clipping.
- Empty recorders show a border; assigned Pinyin `⌘3` has a tinted background
  and clear segment. Recording shows a stronger blue border, prompt, and cancel
  segment. Escape restored Pinyin `⌘3`; clicking ABC's right cancel segment
  restored its empty state. Keyboard-focus highlighting was visible.
- After switching between both tabs, Pinyin remained `⌘3`, other bindings
  remained empty, and notifications remained off. No preferences or system
  input sources were changed, and no notification permission was requested.
- Independent spec and code-quality reviews passed for the initial UI revision
  `db3966f`.

The follow-up recorder refinement (`c4f6a8b`) uses centered 160 × 26-point
controls with at least 12 points of horizontal cell padding, quieter neutral
borders, and explicit 12-point text. AppKit's outward focus ring is disabled;
the accessible, keyboard-focusable recorder draws a single inset focus border.
Text is clipped to its own segment. Native inspection confirmed normal,
recording, and focused-after-cancel states stay within the control; Escape and
the right-side cancel control preserve bindings. Release build and all 117
existing tests passed again. Pinyin remained `⌘3`; notifications remained off.

**UNVERIFIED for this UI build:** dark appearance, catalogs longer than eight
rows, live contextual error/notification-status rendering, disabled controls,
VoiceOver use, actual physical global hotkeys, and CJK composition. These were
not exercised by changing the user's configuration. Automated tests protect
core behavior; they do not establish native UI or physical-keyboard acceptance.

Build-3 and build-2 evidence below is historical, not new-build acceptance.

## Historical dynamic-list edition: 1.2.0 (3)

The user requested restoration of the original dynamic list on 2026-09-16.
This edition reads enabled, selectable keyboard sources and modes from macOS;
the earlier fixed-three-target scope is superseded. Source/mode IDs preserve
binding identity through display-name and ordering changes. Catalog removal
releases a registration without deleting its saved value; re-addition restores
it. Existing original-version and fixed-edition bindings/tombstones migrate.

Results below the historical heading are build-2 evidence and must not be
presented as manual acceptance of build 3.

System Settings was inspected without changing configuration: its enabled list
showed ABC, `拼音 – 簡体字`, and `日本語 – ローマ字入力`. The application lists
the selectable modes within these configured sources, rather than unselectable
input-method containers.

At commit `c04c7d5`, native tests passed (105 tests, 0 failures), Release built
successfully, and arm64/signature checks passed. The staged app visibly listed
six entries: ABC, Pinyin – Simplified, Hiragana, Katakana, Full-width Romaji,
and Half-width Katakana. Thus the three configured system input methods expand
to six directly selectable entries. The existing user Pinyin binding `⌘1`
was displayed; no recorder was edited. Notifications remained off. The app
was quit before further fixes/builds.

Final implementation commit: `768b683`. Independent spec and code-quality
reviews passed. Final native Debug XCTest run passed **117 tests, 0 failures**
(`Test-kawa-2026.09.16_09-57-35-+0900.xcresult`). The parent rebuilt Release
successfully, confirmed the executable is arm64, and verified its ad-hoc
signature with deep/strict codesign checking. The final staged app was opened
again: the same six system-derived entries and existing Pinyin `⌘1` binding
were visible. The settings window was left open for the user.

Build provenance: builds used the current checkout, including the pre-existing
uncommitted `kawa/en.lproj/Main.storyboard` edits. Those edits were preserved
and excluded from the implementation commits.

No system sources were added/removed, no global test shortcuts were installed,
and no text was entered during this dynamic-edition inspection. Actual physical
hotkeys, OS notification delivery, and live add/remove behavior for build 3
remain UNVERIFIED; catalog reconciliation is covered by injected-boundary tests.

## Historical build-2 evidence

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
| App launch and preserved settings UI | PASS | On 2026-09-16, launched the staged Release app through Computer Use after unlocking. Observed `Kawa Test Build`, all three target rows and recorders, input-source icons, both tabs, and the unchecked notification preference. |
| Recording/duplicate/edit/clear | PASS (UI/storage) | Recorded three distinct modifier combinations; duplicate Japanese assignment showed an error and preserved old values. Edited ABC from Control–Command–A to Control–Option–Shift–A, then cleared it. Physical old/new-key behavior remains unverified. |
| Hotkeys work without settings window | PARTIAL PASS | Japanese: user confirmed pressing physical Control–Option–A in TextEdit, then typing `nihon` to obtain `日本`, after settings were closed. Pinyin/ABC pending. |
| ABC text entry | PARTIAL PASS | Observed `Hello` in TextEdit after requesting the physical ABC shortcut test. Exact shortcut use awaits user confirmation. |
| Pinyin composition | PARTIAL PASS | Observed `你好` in TextEdit after requesting the physical Pinyin shortcut/candidate test. The candidate UI and exact shortcut use await user confirmation. |
| Japanese Hiragana and Kanji conversion | PASS (user-assisted) | TextEdit visibly contained `日本`; user explicitly confirmed it followed physical Control–Option–A and `nihon`. Intermediate Hiragana composition was not separately captured. |
| Return from another Japanese mode | UNVERIFIED | Requires native UI observation. |
| Rapid switching and another application | PARTIAL PASS | Japanese hotkey worked in TextEdit; rapid sequences and another text application remain unverified. |
| Relaunch restores saved/cleared state | PASS (UI/storage) | Quit using Quit Kawa and relaunched: all three saved bindings remained. Cleared all three, quit/relaunched again: all three remained empty. Hotkeys before opening settings on relaunch were not separately exercised. |
| In-progress candidate/composition handling | UNVERIFIED | Requires native UI observation. |
| Failure feedback and optional notifications | UNVERIFIED | Requires native UI observation. |
| Temporary settings restored | PARTIAL PASS | All three original empty bindings restored and verified after relaunch; notifications stayed off; Quit Kawa invoked. Final active input-source identity was not independently verified. |

### Interactive session, 2026-09-16

Read-only HIToolbox preferences reported ABC before testing. This is persisted
metadata, not an independent live TIS query of the foreground application's mode.
All three shortcuts were empty and notifications were off. The staged Release
app launched successfully. A duplicate assignment was rejected with a visible
message, preserving the existing Pinyin binding and the empty Japanese binding.

Computer Use's `pressKey` calls for modified `1`, `j`, and `e` were all displayed
by the recorder as physical key A, with the requested modifiers. Temporary
bindings are therefore Pinyin Control–Option–Command–A, Japanese Control–Option–A,
and ABC Control–Command–A. Sending the Japanese combination from TextEdit inserted
a control character; subsequent individual `nihon` calls produced Latin text.
These synthetic events do not establish actual keyboard or IME behavior. A
physical-keyboard check was requested to distinguish automation limitations
from an application defect. The user subsequently confirmed that physical
Control–Option–A followed by `nihon` produced `日本`; that output was also observed
in TextEdit. This establishes successful real-keyboard Japanese switching and
Kanji conversion despite the synthetic-event limitation. No system notification
permission was requested.

After a further physical-keyboard test request, TextEdit contained `你好` and
`Hello`. These outputs were observed, but exact Pinyin/ABC shortcut use has not
yet been confirmed by the user. Saved shortcut values survived quitting and
relaunching. Editing and clearing worked in the recorder. Finally, all three
bindings were restored to their original empty state, quit/relaunched, and
verified empty; the notification checkbox remained off. Kawa was then quit.
The test document was saved locally as `build/Kawa-input-test-2026-09-16.rtf`
and closed; it is ignored by Git and excluded from the release ZIP.

This session did not verify return from Katakana/Roman mode, rapid switching,
in-progress composition policy, or OS notification display. These require
further physical-keyboard acceptance and must not be inferred from unit tests.

## Current package

Final package: `build/release/Kawa-AppleSilicon-test.zip`, version 1.2.0 (3). Include `Kawa.app`, Chinese installation instructions, this validation record, the MIT license, and the MASShortcut BSD-2-Clause notice. Exclude build caches, test products, signing credentials, user preferences, and private documents. Verify contents before sharing. Public upload is outside this task's authorization.

| Check | Status | Evidence |
| --- | --- | --- |
| Copied app architecture and signature | PASS | Staged app remains arm64; deep/strict codesign verification succeeds after copying. |
| ZIP contents | PASS | Listing contains the app, four intended documents, and normal `__MACOSX` archive metadata. No build caches or test products included. |
| ZIP integrity | PASS | `unzip -t` reports no errors in compressed data. |

The archive checksum is recorded separately in `docs/release-checks.md` so this
document does not embed its own archive's changing hash. Native interactive
acceptance is partial, as detailed above; this package has not been publicly uploaded or
automatically installed into `/Applications`.
