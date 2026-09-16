# Test Release Verification

- Package: `build/release/Kawa-AppleSilicon-test.zip`
- Edition: Kawa Test Build 1.2.0 (3), Apple Silicon only, dynamic system input-source list.
- Application source commit: `768b683`, built with the pre-existing uncommitted storyboard edits preserved in the working checkout.
- Verification completed: 2026-09-16, Asia/Tokyo.
- Size: 512169 bytes.
- SHA-256: `eeb4cd79e4cda150a23509aae1c65582f50ea86d9ebe80a62e4a6d311191c382`

## Observed results

- Native XCTest: **117 tests passed, 0 failures**.
- Native Debug and Release builds: **passed**.
- Built and staged executable: **Mach-O 64-bit arm64**.
- Built and staged app: **deep/strict codesign verification passed**.
- Signing identity: **ad-hoc**, bundle ID `net.noraesae.Kawa`; no Developer ID or notarization.
- ZIP: **144 entries**, including directories and normal Apple archive metadata; no unexpected paths. Contains only the app and the four intended documents.
- Final ZIP integrity: **passed**, `unzip -t` found no compressed-data errors.

The checksum was computed after the final documentation copy, ZIP rebuild,
and removal of Finder's top-level `.DS_Store` and corresponding archive metadata.
This record stays outside the ZIP to avoid a self-referential archive checksum.

## Interactive acceptance

On 2026-09-16 the final staged app launched and rendered six selectable entries:
ABC, Pinyin – Simplified, Hiragana, Katakana, Full-width Romaji, and Half-width
Katakana. System Settings showed the corresponding three configured input
methods; Kawa exposes their selectable modes. The user's existing Pinyin `⌘1`
binding remained visible. The settings window was left open for the user.

No system input-source configuration or shortcut recorder values were changed
during the build-3 inspection. Actual physical hotkeys, in-progress composition,
OS notifications, and live source add/remove behavior remain unverified for
this build; reconciliation and migration have automated regression coverage.
Earlier build-2 keyboard results are preserved separately in `docs/testing.md`
and are not represented as new-build acceptance. Independent spec and final
code-quality reviews passed.

The test package has not been published or installed into `/Applications`.
