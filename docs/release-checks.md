# Test Release Verification

- Package: `build/release/Kawa-AppleSilicon-test.zip`
- Edition: Kawa Test Build 1.2.0 (4), Apple Silicon only, refined settings UI with the dynamic system input-source list.
- Application source commit: `db3966f`.
- Verification completed: 2026-09-17, Asia/Tokyo.
- Size: 534942 bytes.
- SHA-256: `45f5c4dab518bfc512f3e5e181f21215eb9170dbb1d9936a1418d74eb3b29eca`

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

The final staged app rendered five system input-source entries: ABC,
Pinyin – Simplified, Hiragana, Katakana, and Full-width Romaji. The Shortcuts
and General panes fit their content, with aligned rows, readable help, and
visible recorder borders. Assigned and recording states have distinct emphasis.

Recording Pinyin and pressing Escape preserved its existing `⌘3` binding.
Recording ABC and clicking its right-side cancel segment preserved its empty
binding. Other bindings remained empty; notifications remained off. No system
input sources or stored preferences were changed, and no permission was requested.
Independent spec and final code-quality reviews passed.

Dark appearance, more than eight rows, live error/notification-status layouts,
disabled controls, VoiceOver, physical global hotkeys, and CJK composition remain
unverified for this build. See `docs/testing.md` for the evidence and historical
results; earlier keyboard acceptance is not counted as new-build verification.

The test package has not been published or installed into `/Applications`.
