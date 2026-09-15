import AppKit
import MASShortcut
import XCTest

final class ShortcutStoreTests: XCTestCase {
  private var suiteName = ""
  private var defaults: UserDefaults!
  private let command = UInt(NSEvent.ModifierFlags.command.rawValue)
  private let shift = UInt(NSEvent.ModifierFlags.shift.rawValue)

  override func setUp() {
    super.setUp()
    suiteName = "ShortcutStoreTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    defaults = nil
    super.tearDown()
  }

  func testRoundTripUsesSecureMASShortcutArchive() throws {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let store = ShortcutStore(defaults: defaults)

    store.save(binding, for: .pinyin)

    let data = try XCTUnwrap(defaults.data(forKey: InputTarget.pinyin.storageKey))
    let archived = try XCTUnwrap(
      NSKeyedUnarchiver.unarchivedObject(ofClass: MASShortcut.self, from: data)
    )
    XCTAssertEqual(archived.keyCode, binding.keyCode)
    XCTAssertEqual(archived.modifierFlags.rawValue, binding.modifierFlags)
    XCTAssertEqual(ShortcutStore(defaults: defaults).binding(for: .pinyin), binding)
  }

  func testMigratesRealLegacyNonSecureArchiveWhenCanonicalKeyIsAbsent() throws {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let legacy = MASShortcut(
      keyCode: binding.keyCode,
      modifierFlags: NSEvent.ModifierFlags(rawValue: binding.modifierFlags)
    )
    let data = try NSKeyedArchiver.archivedData(
      withRootObject: legacy,
      requiringSecureCoding: false
    )
    defaults.set(data, forKey: "com-apple-inputmethod-SCIM-ITABC")

    let restored = ShortcutStore(defaults: defaults).binding(for: .pinyin)

    XCTAssertEqual(restored, binding)
    XCTAssertNotNil(defaults.object(forKey: "com-apple-inputmethod-SCIM-ITABC"))
    XCTAssertNotNil(defaults.object(forKey: InputTarget.pinyin.storageKey))
  }

  func testMigratesKnownLegacyKeysForEveryTarget() throws {
    let binding = ShortcutBinding(keyCode: 19, modifierFlags: command)
    let cases: [(InputTarget, String)] = [
      (.abc, "com-apple-keylayout-ABC"),
      (.pinyin, "com-apple-inputmethod-SCIM-ITABC"),
      (.hiragana, "com-apple-inputmethod-Kotoeri-RomajiTyping-Japanese"),
      (.hiragana, "com-apple-inputmethod-Kotoeri-Japanese")
    ]

    for (target, legacyKey) in cases {
      defaults.removePersistentDomain(forName: suiteName)
      defaults.set(try legacyArchive(binding), forKey: legacyKey)
      XCTAssertEqual(ShortcutStore(defaults: defaults).binding(for: target), binding, legacyKey)
    }
  }

  func testExplicitClearPersistsTombstoneAndPreventsLegacyReappearanceAfterRestart() throws {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    defaults.set(try legacyArchive(binding), forKey: "com-apple-keylayout-ABC")
    let store = ShortcutStore(defaults: defaults)
    XCTAssertEqual(store.binding(for: .abc), binding)

    store.save(nil, for: .abc)

    XCTAssertNil(ShortcutStore(defaults: defaults).binding(for: .abc))
    XCTAssertNotNil(defaults.object(forKey: InputTarget.abc.storageKey))
    XCTAssertNotNil(defaults.object(forKey: "com-apple-keylayout-ABC"))
  }

  func testCorruptCanonicalArchiveDoesNotFallBackToLegacyValue() throws {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    defaults.set(Data([0x00, 0x01]), forKey: InputTarget.abc.storageKey)
    defaults.set(try legacyArchive(binding), forKey: "com-apple-keylayout-ABC")

    XCTAssertNil(ShortcutStore(defaults: defaults).binding(for: .abc))
  }

  func testUnknownCanonicalValueTypeDoesNotFallBackToLegacyValue() throws {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    defaults.set(["keyCode": 18], forKey: InputTarget.abc.storageKey)
    defaults.set(try legacyArchive(binding), forKey: "com-apple-keylayout-ABC")

    XCTAssertNil(ShortcutStore(defaults: defaults).binding(for: .abc))
  }

  func testInvalidArchivedKeyCodesAreRejected() throws {
    let store = ShortcutStore(defaults: defaults)

    for keyCode in [-1, 128] {
      defaults.set(try rawArchive(keyCode: keyCode, modifierFlags: command), forKey: InputTarget.pinyin.storageKey)
      XCTAssertNil(store.binding(for: .pinyin), "keyCode \(keyCode)")
    }
  }

  func testUnsupportedArchivedModifierFlagsAreRejectedBeforeMASShortcutCanNormalizeThem() throws {
    let unsupported = UInt(NSEvent.ModifierFlags.function.rawValue)
    defaults.set(
      try rawArchive(keyCode: 18, modifierFlags: unsupported),
      forKey: InputTarget.pinyin.storageKey
    )

    XCTAssertNil(ShortcutStore(defaults: defaults).binding(for: .pinyin))
  }

  func testBareOrdinaryKeyArchiveIsRejected() throws {
    defaults.set(try rawArchive(keyCode: 0, modifierFlags: 0), forKey: InputTarget.abc.storageKey)

    XCTAssertNil(ShortcutStore(defaults: defaults).binding(for: .abc))
  }

  func testShiftOnlyOrdinaryKeyArchiveIsRejected() throws {
    defaults.set(
      try rawArchive(keyCode: 0, modifierFlags: shift),
      forKey: InputTarget.abc.storageKey
    )

    XCTAssertNil(ShortcutStore(defaults: defaults).binding(for: .abc))
  }

  private func legacyArchive(_ binding: ShortcutBinding) throws -> Data {
    let shortcut = MASShortcut(
      keyCode: binding.keyCode,
      modifierFlags: NSEvent.ModifierFlags(rawValue: binding.modifierFlags)
    )
    return try NSKeyedArchiver.archivedData(withRootObject: shortcut, requiringSecureCoding: false)
  }

  private func rawArchive(keyCode: Int, modifierFlags: UInt) throws -> Data {
    let value = RawArchivedShortcut(keyCode: keyCode, modifierFlags: modifierFlags)
    let archiver = NSKeyedArchiver(requiringSecureCoding: false)
    archiver.setClassName(NSStringFromClass(MASShortcut.self), for: RawArchivedShortcut.self)
    archiver.encode(value, forKey: NSKeyedArchiveRootObjectKey)
    archiver.finishEncoding()
    return archiver.encodedData
  }
}

@objc(KawaTestsRawArchivedShortcut)
private final class RawArchivedShortcut: NSObject, NSCoding {
  let keyCode: Int
  let modifierFlags: UInt

  init(keyCode: Int, modifierFlags: UInt) {
    self.keyCode = keyCode
    self.modifierFlags = modifierFlags
  }

  required init?(coder: NSCoder) {
    nil
  }

  func encode(with coder: NSCoder) {
    coder.encode(keyCode, forKey: "KeyCode")
    coder.encode(Int(modifierFlags), forKey: "ModifierFlags")
  }
}
