import Foundation
import XCTest

final class InputTargetTests: XCTestCase {
  func testTitlesAndStorageKeysAreStable() {
    XCTAssertEqual(InputTarget.pinyin.title, "Apple Pinyin")
    XCTAssertEqual(InputTarget.pinyin.storageKey, "shortcut.pinyin")
    XCTAssertEqual(InputTarget.hiragana.title, "Japanese Hiragana")
    XCTAssertEqual(InputTarget.hiragana.storageKey, "shortcut.hiragana")
    XCTAssertEqual(InputTarget.abc.title, "ABC")
    XCTAssertEqual(InputTarget.abc.storageKey, "shortcut.abc")
  }

  func testABCMatchesOnlyExactAppleSourceID() {
    XCTAssertTrue(InputTarget.abc.matches(source(id: "com.apple.keylayout.ABC")))
    XCTAssertFalse(InputTarget.abc.matches(source(id: "com.example.keylayout.ABC")))
    XCTAssertFalse(InputTarget.abc.matches(source(
      id: "com.apple.keylayout.ABC",
      modeID: "com.example.mode"
    )))
  }

  func testPinyinMatchesOnlyExactAppleSourceIDAndMode() {
    XCTAssertTrue(InputTarget.pinyin.matches(source(
      id: "com.apple.inputmethod.SCIM.ITABC",
      modeID: "com.apple.inputmethod.SCIM.ITABC"
    )))
    XCTAssertFalse(InputTarget.pinyin.matches(source(id: "com.apple.inputmethod.SCIM.ITABC")))
    XCTAssertFalse(InputTarget.pinyin.matches(source(id: "com.apple.inputmethod.SCIM.ITABC.Shuangpin")))
  }

  func testHiraganaMatchesNormalJapaneseModeFromLegacyKotoeriSource() {
    let japanese = source(
      id: "com.apple.inputmethod.Kotoeri.RomajiTyping",
      modeID: "com.apple.inputmethod.Japanese",
      bundleID: "com.apple.inputmethod.Kotoeri.RomajiTyping"
    )

    XCTAssertTrue(InputTarget.hiragana.matches(japanese))
  }

  func testHiraganaMatchesNormalJapaneseModeFromCurrentAppleBundle() {
    let japanese = source(
      id: "com.apple.inputmethod.Kotoeri.RomajiTyping",
      modeID: "com.apple.inputmethod.Japanese",
      bundleID: "com.apple.JapaneseIM.RomajiTyping"
    )

    XCTAssertTrue(InputTarget.hiragana.matches(japanese))
  }

  func testHiraganaRejectsHiraganaOnlyModeWithoutKanjiConversion() {
    let hiraganaOnly = source(
      id: "com.apple.inputmethod.Kotoeri.RomajiTyping",
      modeID: "com.apple.inputmethod.Japanese.Hiragana",
      bundleID: "com.apple.JapaneseIM.RomajiTyping"
    )

    XCTAssertFalse(InputTarget.hiragana.matches(hiraganaOnly))
  }

  func testHiraganaRejectsKatakanaMode() {
    let katakana = source(
      id: "com.apple.inputmethod.Kotoeri.RomajiTyping",
      modeID: "com.apple.inputmethod.Japanese.Katakana",
      bundleID: "com.apple.inputmethod.Kotoeri.RomajiTyping"
    )

    XCTAssertFalse(InputTarget.hiragana.matches(katakana))
  }

  func testHiraganaRejectsRomanMode() {
    let roman = source(
      id: "com.apple.inputmethod.Kotoeri.RomajiTyping",
      modeID: "com.apple.inputmethod.Roman",
      bundleID: "com.apple.JapaneseIM.RomajiTyping"
    )

    XCTAssertFalse(InputTarget.hiragana.matches(roman))
  }

  func testHiraganaRejectsSameModeFromNonAppleJapaneseSource() {
    let thirdPartyJapanese = source(
      id: "com.google.inputmethod.Japanese.Roman",
      modeID: "com.apple.inputmethod.Japanese",
      bundleID: "com.google.inputmethod.Japanese"
    )

    XCTAssertFalse(InputTarget.hiragana.matches(thirdPartyJapanese))
  }

  func testHiraganaRejectsDeceptiveKotoeriBundlePrefix() {
    let deceptiveSource = source(
      id: "com.example.inputmethod.Japanese",
      modeID: "com.apple.inputmethod.Japanese",
      bundleID: "com.apple.inputmethod.KotoeriFake"
    )

    XCTAssertFalse(InputTarget.hiragana.matches(deceptiveSource))
  }

  func testTargetsRejectDisabledAndUnselectableSources() {
    XCTAssertFalse(InputTarget.abc.matches(source(id: "com.apple.keylayout.ABC", isEnabled: false)))
    XCTAssertFalse(InputTarget.pinyin.matches(source(
      id: "com.apple.inputmethod.SCIM.ITABC",
      modeID: "com.apple.inputmethod.SCIM.ITABC",
      isSelectable: false
    )))
    XCTAssertFalse(InputTarget.hiragana.matches(source(
      id: "com.apple.inputmethod.Kotoeri.RomajiTyping",
      modeID: "com.apple.inputmethod.Japanese",
      bundleID: "com.apple.JapaneseIM.RomajiTyping",
      isEnabled: false
    )))
  }

  private func source(
    id: String,
    modeID: String? = nil,
    bundleID: String? = nil,
    isEnabled: Bool = true,
    isSelectable: Bool = true
  ) -> InputSourceInfo {
    InputSourceInfo(
      id: id,
      modeID: modeID,
      bundleID: bundleID,
      isEnabled: isEnabled,
      isSelectable: isSelectable
    )
  }
}

final class InputSwitchFailureTests: XCTestCase {
  func testUnavailableDescriptionNamesTargetAndRemedy() {
    XCTAssertEqual(
      InputSwitchFailure.unavailable(.pinyin).errorDescription,
      "Apple Pinyin is not enabled or selectable in System Settings."
    )
  }

  func testOSStatusDescriptionIncludesStatus() {
    XCTAssertEqual(
      InputSwitchFailure.osStatus(-50).errorDescription,
      "macOS could not select the input source (OSStatus -50)."
    )
  }

  func testUnconfirmedDescriptionNamesTarget() {
    XCTAssertEqual(
      InputSwitchFailure.unconfirmed(.hiragana).errorDescription,
      "macOS did not confirm the switch to Japanese Hiragana."
    )
  }
}

final class InputSourceSwitcherTests: XCTestCase {
  func testMissingSourceFailsWithoutSelection() {
    let access = FakeInputSourceAccess(sources: [Self.abc])
    let scheduler = QueuedScheduler()
    let switcher = InputSourceSwitcher(access: access, schedule: scheduler.schedule)
    var result: Result<InputSourceInfo, InputSwitchFailure>?

    switcher.switchTo(.pinyin) { result = $0 }

    XCTAssertEqual(result, .failure(.unavailable(.pinyin)))
    XCTAssertEqual(access.selectionRequests, [])
    XCTAssertEqual(scheduler.count, 0)
  }

  func testAlreadySelectedTargetSucceedsWithoutSelection() {
    let access = FakeInputSourceAccess(sources: [Self.abc], current: Self.abc)
    let scheduler = QueuedScheduler()
    let switcher = InputSourceSwitcher(access: access, schedule: scheduler.schedule)
    var result: Result<InputSourceInfo, InputSwitchFailure>?

    switcher.switchTo(.abc) { result = $0 }

    XCTAssertEqual(result, .success(Self.abc))
    XCTAssertEqual(access.selectionRequests, [])
    XCTAssertEqual(scheduler.count, 0)
  }

  func testNonzeroSelectionStatusFailsImmediately() {
    let access = FakeInputSourceAccess(sources: [Self.pinyin], selectStatus: -50)
    let scheduler = QueuedScheduler()
    let switcher = InputSourceSwitcher(access: access, schedule: scheduler.schedule)
    var result: Result<InputSourceInfo, InputSwitchFailure>?

    switcher.switchTo(.pinyin) { result = $0 }

    XCTAssertEqual(result, .failure(.osStatus(-50)))
    XCTAssertEqual(access.selectionRequests, [Self.pinyin])
    XCTAssertEqual(scheduler.count, 0)
  }

  func testImmediateConfirmationSucceeds() {
    let access = FakeInputSourceAccess(sources: [Self.pinyin])
    access.onSelect = { access.currentSource = Self.pinyin }
    let scheduler = QueuedScheduler()
    let switcher = InputSourceSwitcher(access: access, schedule: scheduler.schedule)
    var result: Result<InputSourceInfo, InputSwitchFailure>?

    switcher.switchTo(.pinyin) { result = $0 }

    XCTAssertEqual(result, .success(Self.pinyin))
    XCTAssertEqual(access.selectionRequests, [Self.pinyin])
    XCTAssertEqual(scheduler.count, 0)
  }

  func testDelayedConfirmationSucceedsAfterCurrentModeChanges() {
    let access = FakeInputSourceAccess(sources: [Self.japanese], current: Self.roman)
    let scheduler = QueuedScheduler()
    let switcher = InputSourceSwitcher(access: access, schedule: scheduler.schedule)
    var result: Result<InputSourceInfo, InputSwitchFailure>?

    switcher.switchTo(.hiragana) { result = $0 }

    XCTAssertNil(result)
    XCTAssertEqual(access.selectionRequests, [Self.japanese])
    XCTAssertEqual(scheduler.delays, [0.05])

    access.currentSource = Self.japanese
    scheduler.runNext()

    XCTAssertEqual(result, .success(Self.japanese))
    XCTAssertEqual(scheduler.count, 0)
  }

  func testUnconfirmedSelectionTimesOutAfterTwentyDelayedChecks() {
    let access = FakeInputSourceAccess(sources: [Self.pinyin], current: Self.abc)
    let scheduler = QueuedScheduler()
    let switcher = InputSourceSwitcher(access: access, schedule: scheduler.schedule)
    var result: Result<InputSourceInfo, InputSwitchFailure>?

    switcher.switchTo(.pinyin) { result = $0 }

    for check in 1...20 {
      XCTAssertNil(result, "reported before delayed check \(check)")
      scheduler.runNext()
    }

    XCTAssertEqual(result, .failure(.unconfirmed(.pinyin)))
    XCTAssertEqual(access.selectionRequests, [Self.pinyin])
    XCTAssertEqual(scheduler.delays, Array(repeating: 0.05, count: 20))
    XCTAssertEqual(scheduler.count, 0)
  }

  func testNewerRequestSuppressesEarlierScheduledCompletion() {
    let access = FakeInputSourceAccess(sources: [Self.pinyin, Self.abc], current: Self.roman)
    let scheduler = QueuedScheduler()
    let switcher = InputSourceSwitcher(access: access, schedule: scheduler.schedule)
    var firstResult: Result<InputSourceInfo, InputSwitchFailure>?
    var secondResult: Result<InputSourceInfo, InputSwitchFailure>?

    switcher.switchTo(.pinyin) { firstResult = $0 }
    access.currentSource = Self.abc
    switcher.switchTo(.abc) { secondResult = $0 }
    scheduler.runNext()

    XCTAssertNil(firstResult)
    XCTAssertEqual(secondResult, .success(Self.abc))
    XCTAssertEqual(access.selectionRequests, [Self.pinyin])
    XCTAssertEqual(scheduler.count, 0)
  }

  private static let abc = InputSourceInfo(
    id: "com.apple.keylayout.ABC",
    modeID: nil,
    bundleID: nil,
    isEnabled: true,
    isSelectable: true
  )
  private static let pinyin = InputSourceInfo(
    id: "com.apple.inputmethod.SCIM.ITABC",
    modeID: "com.apple.inputmethod.SCIM.ITABC",
    bundleID: "com.apple.inputmethod.SCIM",
    isEnabled: true,
    isSelectable: true
  )
  private static let japanese = InputSourceInfo(
    id: "com.apple.inputmethod.Kotoeri.RomajiTyping",
    modeID: "com.apple.inputmethod.Japanese",
    bundleID: "com.apple.JapaneseIM.RomajiTyping",
    isEnabled: true,
    isSelectable: true
  )
  private static let roman = InputSourceInfo(
    id: "com.apple.inputmethod.Kotoeri.RomajiTyping",
    modeID: "com.apple.inputmethod.Roman",
    bundleID: "com.apple.JapaneseIM.RomajiTyping",
    isEnabled: true,
    isSelectable: true
  )
}

private final class FakeInputSourceAccess: InputSourceAccess {
  var availableSources: [InputSourceInfo]
  var currentSource: InputSourceInfo?
  var selectStatus: Int32
  var selectionRequests: [InputSourceInfo] = []
  var onSelect: (() -> Void)?

  init(
    sources: [InputSourceInfo],
    current: InputSourceInfo? = nil,
    selectStatus: Int32 = 0
  ) {
    availableSources = sources
    currentSource = current
    self.selectStatus = selectStatus
  }

  func sources() -> [InputSourceInfo] {
    availableSources
  }

  func current() -> InputSourceInfo? {
    currentSource
  }

  func select(_ source: InputSourceInfo) -> Int32 {
    selectionRequests.append(source)
    onSelect?()
    return selectStatus
  }
}

private final class QueuedScheduler {
  private var callbacks: [() -> Void] = []
  private(set) var delays: [TimeInterval] = []

  var count: Int {
    callbacks.count
  }

  func schedule(after delay: TimeInterval, _ callback: @escaping () -> Void) {
    delays.append(delay)
    callbacks.append(callback)
  }

  func runNext() {
    XCTAssertFalse(callbacks.isEmpty, "no scheduled callback")
    guard !callbacks.isEmpty else { return }
    callbacks.removeFirst()()
  }
}
