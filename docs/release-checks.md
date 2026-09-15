# Test Release Verification

- Package: `build/release/Kawa-AppleSilicon-test.zip`
- Edition: Kawa Test Build 1.2.0 (2), Apple Silicon only.
- Application source commit: `e1fbc3e`.
- Verification completed: 2026-09-16, Asia/Tokyo.
- Size: 480815 bytes.
- SHA-256: `96c2b8c5b0e1eee99c570a16ef42f9eb5dd2ee53e5bf0d3d780af6a66d09a99a`

## Observed results

- Native XCTest: **81 tests passed, 0 failures**.
- Native Debug and Release builds: **passed**.
- Built and staged executable: **Mach-O 64-bit arm64**.
- Built and staged app: **deep/strict codesign verification passed**.
- Signing identity: **ad-hoc**, bundle ID `net.noraesae.Kawa`; no Developer ID or notarization.
- ZIP: **144 entries**, including directories and normal Apple archive metadata; no unexpected paths. Contains only the app and the four intended documents.
- Final ZIP integrity: **passed**, `unzip -t` found no compressed-data errors.

The checksum was computed after the final documentation copy and ZIP rebuild.
This record stays outside the ZIP to avoid a self-referential archive checksum.

## Acceptance still pending

Computer Use reported the Mac locked, including a later recheck. No application
launch/UI inspection, actual hotkey registration, Pinyin/Japanese typing,
composition behavior, or OS notification display was observed. These remain
**UNVERIFIED** in `docs/testing.md`. Tests used isolated preferences and did not
change the selected input source. No temporary manual settings need restoration.

The test package has not been published or installed into `/Applications`.
