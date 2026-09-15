# Apple Silicon Input Switching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Deliver an arm64 Kawa test application whose three configurable shortcuts reliably select Apple Pinyin, Japanese Hiragana, and ABC without depending on an open settings window.

**Architecture:** Preserve the AppKit storyboard and MASShortcutView recorder. App-lifetime services own shortcut persistence/registration and verified Carbon input-source selection; unit tests isolate only the OS boundaries. Use the official MASShortcut Swift package with a recorded, pinned revision.

**Tech Stack:** Swift 5 language mode, Xcode 27, AppKit, Carbon Text Input Source Services, UserNotifications, upstream MASShortcut Objective-C package, XCTest. macOS 12.0 build floor, arm64 only; primary runtime validation macOS 27.0.

---

## Execution rules

- Approved design: `docs/superpowers/specs/2026-09-15-apple-silicon-input-switching-design.md`.
- Working directory for every command: `/Users/elvinyao/workspace/repos/kawa`.
- Branch: `codex/apple-silicon-input-switching`; keep completed work here, without pushing or merging.
- User explicitly authorized planning and immediate execution. Do not stop for another choice of execution mode or design review.
- Native Xcode is authorized. No Docker runner is used. The global hook has a narrowly scoped native command grammar; do not bypass rejected commands. Build commands below are deliberately compatible with that grammar.
- Use a fresh implementer for each task, followed by independent spec and code-quality review. Main agent handles coordination, native UI verification, and packaging. Do not run multiple implementers concurrently.
- Write behavioral regression tests first, observe their expected failures, implement, and rerun. Configuration/dependency repairs need a real build rather than tests that merely repeat configuration values.
- Preserve the user's original input source and test shortcut settings. Do not publish, accept paid developer agreements, or change macOS security protections.

## File map

| File | Responsibility |
| --- | --- |
| `kawa.xcodeproj/project.pbxproj` | arm64 targets, Swift package, unhosted XCTest target |
| `kawa.xcodeproj/xcshareddata/xcschemes/kawa.xcscheme` | build/run app and run real tests |
| `kawa.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | verified dependency revision |
| `kawa/InputTarget.swift` | exact logical targets and source metadata |
| `kawa/InputSourceSwitcher.swift` | injectable verified switching state machine |
| `kawa/CarbonInputSourceAccess.swift` | actual Carbon enumeration, selection, current mode |
| `kawa/ShortcutController.swift` | application-lifetime hotkey ownership and transactional edits |
| `kawa/ShortcutStore.swift` | isolated-testable preferences and legacy archive migration |
| `kawa/MASShortcutRegistration.swift` | MASShortcutMonitor adapter and value conversion |
| `kawa/AppServices.swift` | composition and startup wiring |
| `kawa/SwitchFeedback.swift` | verified success notifications and visible failures |
| `kawa/AppDelegate.swift` | startup and first-launch window behavior |
| `kawa/ShortcutCellView.swift` | recorder presentation and edits only |
| `kawa/ShortcutViewController.swift` | three stable input target rows |
| `kawa/PreferencesViewController.swift`, `kawa/StatusBar.swift` | opt-in notifications and status feedback |
| `kawa/en.lproj/Main.storyboard` | preserve interface and repair invalid class reference |
| `kawaTests/` | service regression tests without starting the app |
| `docs/testing.md`, `docs/install-zh.md`, `THIRD-PARTY-NOTICES.md` | reproducible checks and test-release instructions |

## Native commands

Build:
```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project kawa.xcodeproj -scheme kawa -configuration Debug -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' build
```
Tests:
```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project kawa.xcodeproj -scheme kawa -configuration Debug -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' test
```
Release:
```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project kawa.xcodeproj -scheme kawa -configuration Release -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' build
```
Expected success markers: `BUILD SUCCEEDED`, `TEST SUCCEEDED`. Capture failing baseline and regression outputs before fixes. Use sandbox escalation if required for Xcode caches, package fetching, or native test services; the tool command remains the same.

## Task 1: Repair native build and establish XCTest

**Files:** project/scheme/Package.resolved, bridging header and Swift imports, `kawaTests/MASShortcutCompatibilityTests.swift`, Cartfile files, storyboard invalid class reference.

- [x] Inspect baseline with the build command. Result: existing macOS 10.15 deployment target is rejected by Xcode 27; Carthage is absent and old framework artifacts are missing.
- [ ] Replace deployment settings with `ARCHS = arm64; MACOSX_DEPLOYMENT_TARGET = 12.0;` in app/test configurations. Retain Swift 5 language mode and ad-hoc signing. Configure `SUPPORTED_PLATFORMS = macosx`.
- [ ] Replace Carthage link/embed/search-path entries with `XCRemoteSwiftPackageReference` for `https://github.com/cocoabits/MASShortcut.git` and package product `MASShortcut`. Resolve branch master once, inspect the resulting Package.resolved, then change the requirement to that exact `revision`. Commit the resolved file; remove obsolete Cartfile files.
- [ ] Use `import MASShortcut` in files that use that module and `import Carbon` where needed. Remove the stale bridging-header setting/import if no Objective-C bridge remains. Remove nonexistent `ShortcutTableView` class metadata while retaining the NSTableView layout.
- [ ] Add a real unhosted `kawaTests` XCTest bundle, no TEST_HOST/AppDelegate launch. Initially test dependency persistence compatibility. Tests later compile actual core service files into this bundle; exclude AppDelegate and UI integration files.
- [ ] Add this behavioral archive-compatibility test (module selector types must match the compiler):
```swift
import XCTest
import AppKit
import MASShortcut

final class MASShortcutCompatibilityTests: XCTestCase {
  func testLegacyArchiveCanBeReadWithSecureDecoder() throws {
    let original = MASShortcut(keyCode: 18, modifierFlags: [.control, .option])!
    let legacy = try NSKeyedArchiver.archivedData(withRootObject: original, requiringSecureCoding: false)
    let restored = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: MASShortcut.self, from: legacy))
    XCTAssertEqual(restored.keyCode, original.keyCode)
    XCTAssertEqual(restored.modifierFlags, original.modifierFlags)
  }
}
```
- [ ] Run build and tests. Investigate package resource loading/compiler diagnostics rather than replacing the recorder speculatively. Record exact revision and remaining upstream warnings.
- [ ] Spec review, quality review, then commit `Enable native Apple Silicon builds and XCTest.`

## Task 2: Resolve and verify the three input targets

**Files:** create InputTarget.swift, InputSourceSwitcher.swift, CarbonInputSourceAccess.swift, `kawaTests/InputSourceSwitcherTests.swift`; add these sources to app and tests.

- [ ] Define source metadata and OS-boundary contracts in the tests' desired API:
```swift
struct InputSourceInfo: Equatable {
  let id: String
  let modeID: String?
  let bundleID: String?
  let isEnabled: Bool
  let isSelectable: Bool
}

protocol InputSourceAccess {
  func sources() -> [InputSourceInfo]
  func current() -> InputSourceInfo?
  func select(_ source: InputSourceInfo) -> Int32
}
```
- [ ] Test target matching before implementing. ABC matches exact source ID, Pinyin matches its exact ID/mode, and Japanese matches Apple's Hiragana mode plus Apple Japanese/Kotoeri provenance. Include same-language Katakana and Roman descriptors which must be rejected. Disabled/unselectable sources must be rejected.
```swift
func testHiraganaDoesNotAcceptKatakana() {
  let source = InputSourceInfo(id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
    modeID: "com.apple.inputmethod.Japanese.Katakana",
    bundleID: "com.apple.inputmethod.Kotoeri.RomajiTyping",
    isEnabled: true, isSelectable: true)
  XCTAssertFalse(InputTarget.hiragana.matches(source))
}
```
- [ ] Run tests and record the expected failure, then implement the enum and matching using stable identifiers. Use live system metadata during integration to verify identifiers; do not substitute localized-name matching.
- [ ] Write state-machine tests using a fake `InputSourceAccess` and an injected scheduler that queues callbacks. Assert outcomes and actual selection requests: missing source, already selected target (zero requests), nonzero OSStatus, immediate success, delayed success after current mode changes, timeout after 20 checks, and newer request suppressing an old callback. The completion API is `switchTo(_:completion:)` returning `Result<InputSourceInfo, InputSwitchFailure>`.
- [ ] Implement the switcher with a monotonically increasing request generation. Resolve fresh enabled sources; early-return if the current descriptor matches; select once; check immediately and then schedule 50 ms checks, at most 20. Every callback checks generation before reporting. Define localized errors for unavailable target, selection status, and unconfirmed target.
- [ ] Implement the Carbon adapter with TISCreateInputSourceList, TISGetInputSourceProperty, TISSelectInputSource, and TISCopyCurrentKeyboardInputSource. Read ID, mode ID, bundle ID, enabled/selectable properties safely. Freshly resolve the exact ID/mode pair before selection. Never force-enable a source or modify HIToolbox preferences.
- [ ] Run tests, inspect native source metadata without changing selection, perform both reviews, and commit `Verify exact input-source and Hiragana selection.`

## Task 3: Own hotkeys independently of the settings window

**Files:** ShortcutController.swift, ShortcutStore.swift, MASShortcutRegistration.swift, `kawaTests/ShortcutControllerTests.swift`, `kawaTests/ShortcutStoreTests.swift`, project source references.

- [ ] Use a value identity for comparisons:
```swift
struct ShortcutBinding: Equatable, Hashable {
  let keyCode: Int
  let modifierFlags: UInt
}
protocol ShortcutRegistering {
  func register(_ binding: ShortcutBinding, action: @escaping () -> Void) -> Bool
  func unregister(_ binding: ShortcutBinding)
}
protocol ShortcutPersisting {
  func binding(for target: InputTarget) -> ShortcutBinding?
  func save(_ binding: ShortcutBinding?, for target: InputTarget)
}
```
- [ ] Write tests with real controller/store and OS-boundary fake registrar. Before any view exists, call `start()` and trigger the registered callback; assert it requests the correct target. Call start twice and verify no duplicate registrations. Cover stop twice, duplicate persisted settings, edits, clear, duplicate attempted edit, registration failure preserving the old working binding and saved data, and recovery after clearing a conflicting target.
- [ ] Implement application-owned registration tracking. New assignments validate before mutation, register before unregistering the old value, and save only after success. Clearing removes only that target's registration. Stop removes only registrations owned by this controller. Keep errors queryable by target; expose change/error callbacks for UI integration. Guard queued stale hotkey actions after a binding is replaced or cleared.
- [ ] Keep target storage keys stable. Codec uses modern secure MASShortcut archive encoding/decoding; compatibility test covers old non-secure NSData archives. Read original dot-to-hyphen source-ID keys (ABC, Pinyin, Japanese/Hiragana variants) only when a new canonical value is absent. Preserve old keys, and distinguish an explicitly cleared new binding from a never-migrated value so a cleared shortcut cannot reappear after restart.
- [ ] Use unique UserDefaults suites in storage tests and remove those suites afterward. Test roundtrip, legacy migration, clear/restart, corrupt archive, invalid key/modifier values, and unknown data types. Do not touch the user's production defaults.
- [ ] Implement MASShortcutRegistration using an app-owned MASShortcutMonitor instance, returning its register result. Convert between MASShortcut.keyCode/modifierFlags and ShortcutBinding. Continue using recorder validation for detectable symbolic/menu conflicts and enforce app-wide duplicates in the controller.
- [ ] Run tests, perform both reviews, and commit `Manage persistent shortcuts for the application lifetime.`

## Task 4: Integrate services into the preserved interface

**Files:** AppServices.swift, SwitchFeedback.swift, AppDelegate.swift, ShortcutCellView.swift, ShortcutViewController.swift, PreferencesViewController.swift, StatusBar.swift, storyboard/Info.plist, service integration tests.

- [ ] First add regression coverage for service startup, a shortcut requesting verified switching, failure not producing success feedback, and replacement/clear silencing an already queued old callback. Tests use injected services, without launching AppDelegate or mutating system input sources.
- [ ] Compose one controller, switcher, store, and registrar for the app lifetime. Wire shortcuts to switching and switching completion to feedback. Initialize on applicationDidFinishLaunching before first-use settings presentation. Capture first-launch state before clearing it; show preferences once on first launch, and restore existing shortcuts on later launches without opening the window.
- [ ] Make ShortcutViewController render three stable rows. A row resolves an optional current icon/name but remains editable if its source is unavailable. Hiragana is explicitly identified. Remove forced unwraps when creating/reusing cells.
- [ ] Make ShortcutCellView display controller data without associatedUserDefaultsKey or bindShortcut calls. On a valid recorder edit, invoke the controller and restore the old displayed value on failure. Temporarily detach the value-change callback during programmatic assignment to avoid recursion. Show readable validation errors in the existing settings window.
- [ ] Add visible menu-bar failure indication and an explanatory tooltip/status that does not activate a different application while typing. Clear failure after confirmed success. Send optional success notifications via UserNotifications only after confirmation; request authorization only when the checkbox is explicitly enabled and handle denied permission independently from switching outcome.
- [ ] Preserve bundle identifier for saved settings, retain menu/window interaction, and mark the test build version clearly. Bundle the upstream license and application license without inventing authorship.
- [ ] Run automated tests and build. Open the project/app through native Xcode computer use and inspect recorder/table rendering. Fix runtime/resource issues with a reproducing test where practical. Perform both reviews, then commit `Connect native switching services to the existing settings UI.`

## Task 5: Validate and package the test release

**Files:** docs/testing.md, docs/install-zh.md, THIRD-PARTY-NOTICES.md, README.md, AGENTS.md, packaging recipe and ignored build output.

- [ ] Run the complete native test suite and Release build; record exact Xcode/macOS versions and test totals. Verify Mach-O output using `file` and signature integrity using Xcode's signing output or a separately approved read-only codesign verification.
- [ ] Through computer use, record temporary distinct hotkeys, test without reopening settings, verify edit/clear/relaunch, and exercise ABC/Pinyin/Hiragana in a disposable text document. Observe actual Hiragana text, not just the menu icon. Test rapid switching, another application's field, and candidate/composition behavior. Restore original input source and all temporary test settings. Do not delete or overwrite user documents.
- [ ] Write Chinese installation instructions for an arm64 testing-only build: unpack, copy app if desired, enable the three Apple sources, choose three nonconflicting shortcuts, understand failure messages, and note Developer ID/notarization limitations. Do not recommend disabling Gatekeeper or deleting quarantine metadata.
- [ ] Write the test checklist with PASS/FAIL/UNVERIFIED states and concrete evidence. State deployment floor separately from actually tested OS versions.
- [ ] Package Release Kawa.app, licenses, and installation/testing notes into `build/release/Kawa-AppleSilicon-test.zip`. Use a reviewed project-local packaging operation or Finder compression; verify the resulting archive contents and embedded arm64 app. Do not publish or install into /Applications automatically.
- [ ] Update contributor commands and test architecture in AGENTS.md, remove obsolete Docker/Carthage instructions, review the full diff against every spec requirement, perform final spec and code-quality review, and commit `Document and package the Apple Silicon test build.`

## Plan self-review

Coverage: native architecture/dependency/SDK repair (Task 1); exact target and result verification (Task 2); startup/edit/clear/migration (Task 3); existing interface and truthful feedback (Task 4); native runtime checks and limited test distribution (Task 5). OS-level changes remain behind narrow adapters, while tests exercise the production state machines. No global shortcut is activated by unit tests. Any package-revision or compiler/API spelling discovered during resolution must be recorded before committing the corresponding task.
