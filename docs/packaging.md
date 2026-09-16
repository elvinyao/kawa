# Local test package

Run from the repository root after the full XCTest suite passes. These commands
build and package an ad-hoc signed arm64 app. They do not publish or install it.
Update `docs/testing.md` with observed results before copying it into the package.

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project kawa.xcodeproj -scheme kawa -configuration Release -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' build
file build/DerivedData/Build/Products/Release/Kawa.app/Contents/MacOS/Kawa
/usr/bin/codesign --verify --deep --strict --verbose=2 build/DerivedData/Build/Products/Release/Kawa.app
/usr/bin/codesign -dv --verbose=4 build/DerivedData/Build/Products/Release/Kawa.app
/bin/mkdir -p build/release/Kawa-AppleSilicon-test
/usr/bin/ditto build/DerivedData/Build/Products/Release/Kawa.app build/release/Kawa-AppleSilicon-test/Kawa.app
/bin/cp LICENSE THIRD-PARTY-NOTICES.md docs/install-zh.md docs/testing.md build/release/Kawa-AppleSilicon-test/
/usr/bin/codesign --verify --deep --strict --verbose=2 build/release/Kawa-AppleSilicon-test/Kawa.app
/usr/bin/ditto -c -k --sequesterRsrc --keepParent build/release/Kawa-AppleSilicon-test build/release/Kawa-AppleSilicon-test.zip
/usr/bin/unzip -l build/release/Kawa-AppleSilicon-test.zip
/usr/bin/unzip -t build/release/Kawa-AppleSilicon-test.zip
/usr/bin/shasum -a 256 build/release/Kawa-AppleSilicon-test.zip
```

The executable must report `Mach-O 64-bit executable arm64`. Signature verification
must succeed for both the built and copied app. An ad-hoc signature establishes
integrity; it is not a Developer ID identity or Apple notarization.

If the archive listing contains Finder's top-level `.DS_Store`, remove only
those archive entries, then repeat the integrity and checksum commands above:

```sh
/usr/bin/zip -d build/release/Kawa-AppleSilicon-test.zip Kawa-AppleSilicon-test/.DS_Store __MACOSX/Kawa-AppleSilicon-test/._.DS_Store
```

Inspect the staging directory and ZIP listing before sharing. They should contain
only `Kawa.app`, `LICENSE`, `THIRD-PARTY-NOTICES.md`, `install-zh.md`, `testing.md`,
and archive metadata. Use a clean staging directory for a later release to avoid
including stale files. Never add preferences, test results, caches, signing keys,
or personal documents. Record the ZIP checksum outside the archive.
