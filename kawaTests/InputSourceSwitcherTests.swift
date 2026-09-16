import Foundation
import XCTest

final class InputSourceCatalogTests: XCTestCase {
  func testDiscoversFourthPartyKeyboardSourceWithoutFixedPresetRows() {
    let sources = [
      source(id: "com.apple.keylayout.ABC", name: "ABC"),
      source(id: "com.apple.inputmethod.SCIM.ITABC", modeID: "com.apple.inputmethod.SCIM.ITABC", name: "Pinyin"),
      source(id: "com.apple.inputmethod.Kotoeri.RomajiTyping", modeID: "com.apple.inputmethod.Japanese", name: "Japanese"),
      source(id: "org.example.inputmethod.Colemak", name: "Colemak")
    ]

    let targets = InputSourceCatalog.targets(from: sources)

    XCTAssertEqual(targets.map(\.sourceID), sources.map(\.id))
    XCTAssertEqual(targets.last?.title, "Colemak")
  }

  func testFiltersDisabledUnselectableAndNonKeyboardSources() {
    let targets = InputSourceCatalog.targets(from: [
      source(id: "enabled", name: "Enabled"),
      source(id: "disabled", name: "Disabled", isEnabled: false),
      source(id: "unselectable", name: "Unselectable", isSelectable: false),
      source(id: "palette", name: "Palette", isKeyboard: false)
    ])

    XCTAssertEqual(targets.map(\.sourceID), ["enabled"])
  }

  func testDuplicateDescriptorsKeepFirstOccurrenceDeterministically() {
    let targets = InputSourceCatalog.targets(from: [
      source(id: "org.example.source", modeID: "mode.one", name: "First"),
      source(id: "org.example.source", modeID: "mode.one", name: "Second")
    ])

    XCTAssertEqual(targets.count, 1)
    XCTAssertEqual(targets.first?.title, "First")
  }

  func testUniqueLocalizedModeNamesRemainVerbatim() {
    let targets = InputSourceCatalog.targets(from: [
      source(
        id: "com.apple.inputmethod.SCIM.ITABC",
        modeID: "com.apple.inputmethod.SCIM.ITABC",
        name: "拼音 – 簡体字"
      ),
      source(
        id: "com.apple.inputmethod.Kotoeri.RomajiTyping",
        modeID: "com.apple.inputmethod.Japanese",
        name: "日本語 – ローマ字入力"
      )
    ])

    XCTAssertEqual(targets.map(\.title), ["拼音 – 簡体字", "日本語 – ローマ字入力"])
  }

  func testDistinctModesProduceDistinctTargetsAndExplicitTitles() {
    let targets = InputSourceCatalog.targets(from: [
      source(id: "org.example.ime", modeID: "org.example.ime.Hiragana", name: "Example IME"),
      source(id: "org.example.ime", modeID: "org.example.ime.Katakana", name: "Example IME")
    ])

    XCTAssertEqual(targets.count, 2)
    XCTAssertNotEqual(targets[0], targets[1])
    XCTAssertEqual(targets.map(\.title), ["Example IME — Hiragana", "Example IME — Katakana"])
  }

  func testDuplicateJapaneseNamesIdentifyNormalConversionModeAsHiragana() {
    let targets = InputSourceCatalog.targets(from: [
      source(
        id: "com.apple.inputmethod.Kotoeri.RomajiTyping",
        modeID: "com.apple.inputmethod.Japanese",
        name: "Japanese"
      ),
      source(
        id: "com.apple.inputmethod.Kotoeri.RomajiTyping",
        modeID: "com.apple.inputmethod.Japanese.Katakana",
        name: "Japanese"
      )
    ])

    XCTAssertEqual(targets.map(\.title), ["Japanese — Hiragana", "Japanese — Katakana"])
  }

  func testDuplicateDefaultModeLabelsFallBackToSourceIdentity() {
    let targets = InputSourceCatalog.targets(from: [
      source(id: "org.example.first", name: "Example"),
      source(id: "org.example.second", name: "Example")
    ])

    XCTAssertEqual(targets.map(\.title), [
      "Example — Default — org.example.first",
      "Example — Default — org.example.second"
    ])
  }

  func testEqualReadableModeLabelsFallBackToFullSourceAndModeIdentity() {
    let sourceID = "com.apple.inputmethod.Kotoeri.RomajiTyping"
    let targets = InputSourceCatalog.targets(from: [
      source(id: sourceID, modeID: "com.apple.inputmethod.Japanese", name: "Japanese"),
      source(id: sourceID, modeID: "com.apple.inputmethod.Japanese.Hiragana", name: "Japanese")
    ])

    XCTAssertEqual(targets.map(\.title), [
      "Japanese — Hiragana — \(sourceID) / com.apple.inputmethod.Japanese",
      "Japanese — Hiragana — \(sourceID) / com.apple.inputmethod.Japanese.Hiragana"
    ])
  }

  func testGeneratedModeLabelDoesNotDisambiguateUniqueLocalizedName() {
    let targets = InputSourceCatalog.targets(from: [
      source(id: "org.example.foo", modeID: "org.example.Foo", name: "Example"),
      source(id: "org.example.bar", modeID: "org.example.Bar", name: "Example"),
      source(id: "org.example.literal", name: "Example — Foo")
    ])

    XCTAssertEqual(targets.map(\.title), [
      "Example — Foo — org.example.foo / org.example.Foo",
      "Example — Bar",
      "Example — Foo"
    ])
  }

  func testIdentityAndStorageKeySurviveRenameAndReorder() {
    let original = InputSourceCatalog.targets(from: [
      source(id: "org.example.first", name: "Old Name"),
      source(id: "org.example.ime", modeID: "org.example.mode", name: "IME")
    ])
    let refreshed = InputSourceCatalog.targets(from: [
      source(id: "org.example.ime", modeID: "org.example.mode", name: "Renamed IME"),
      source(id: "org.example.first", name: "New Name")
    ])

    XCTAssertEqual(original[0], refreshed[1])
    XCTAssertEqual(original[0].storageKey, refreshed[1].storageKey)
    XCTAssertEqual(original[1], refreshed[0])
    XCTAssertEqual(original[1].storageKey, refreshed[0].storageKey)
    XCTAssertTrue(original[0].storageKey.hasPrefix("shortcut.v2."))
    XCTAssertNotEqual(original[0].storageKey, original[1].storageKey)
  }

  private func source(
    id: String,
    modeID: String? = nil,
    name: String,
    isEnabled: Bool = true,
    isSelectable: Bool = true,
    isKeyboard: Bool = true
  ) -> InputSourceInfo {
    InputSourceInfo(
      id: id,
      modeID: modeID,
      bundleID: nil,
      isEnabled: isEnabled,
      isSelectable: isSelectable,
      isKeyboard: isKeyboard,
      localizedName: name
    )
  }
}

final class InputTargetTests: XCTestCase {
  func testTitlesAndStorageKeysAreStable() {
    XCTAssertEqual(InputTarget.pinyin.title, "Apple Pinyin")
    XCTAssertTrue(InputTarget.pinyin.storageKey.hasPrefix("shortcut.v2."))
    XCTAssertEqual(InputTarget.hiragana.title, "Japanese Hiragana")
    XCTAssertTrue(InputTarget.hiragana.storageKey.hasPrefix("shortcut.v2."))
    XCTAssertEqual(InputTarget.abc.title, "ABC")
    XCTAssertTrue(InputTarget.abc.storageKey.hasPrefix("shortcut.v2."))
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
