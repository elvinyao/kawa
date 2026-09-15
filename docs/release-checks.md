# Test Release Verification

- Package: `build/release/Kawa-AppleSilicon-test.zip`
- Edition: Kawa Test Build 1.2.0 (2), Apple Silicon only.
- Application source commit: `e1fbc3e`.
- Verification completed: 2026-09-16, Asia/Tokyo.
- Size: 482108 bytes.
- SHA-256: `cf718aa4c968f06acf232ac70d44f91fe607b933f54541dc513d948aa273a61b`

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

## Interactive acceptance

After unlocking on 2026-09-16, the staged app launched and rendered correctly.
Recording, duplicate rejection, editing, and saved/cleared settings after relaunch
passed. The user confirmed Control–Option–A followed by `nihon` produced `日本`
in TextEdit with Kawa's settings closed. `你好` and `Hello` were subsequently
observed after instructions to test Pinyin/ABC; exact shortcut use awaits user
confirmation. Computer Use's synthetic letter events did not reliably emulate
physical hotkeys.

The original empty bindings were restored and verified after relaunch;
notifications remained off and Kawa was quit. Test text was saved locally under
`build/` and is excluded from the archive. Return from another Japanese mode,
rapid switching, in-progress composition, OS notifications, and final live
input-source identity remain unverified. See `docs/testing.md` for evidence and
the distinction between observed results and pending checks.

The test package has not been published or installed into `/Applications`.
