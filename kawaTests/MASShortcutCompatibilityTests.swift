import AppKit
import MASShortcut
import XCTest

final class MASShortcutCompatibilityTests: XCTestCase {
  func testLegacyArchiveCanBeReadWithSecureDecoder() throws {
    let original = MASShortcut(keyCode: 18, modifierFlags: [.control, .option])
    let legacy = try NSKeyedArchiver.archivedData(withRootObject: original, requiringSecureCoding: false)
    let restored = try XCTUnwrap(
      NSKeyedUnarchiver.unarchivedObject(ofClass: MASShortcut.self, from: legacy)
    )

    XCTAssertEqual(restored.keyCode, original.keyCode)
    XCTAssertEqual(restored.modifierFlags, original.modifierFlags)
  }
}
