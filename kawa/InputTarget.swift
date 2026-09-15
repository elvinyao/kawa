import Foundation

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

enum InputTarget: CaseIterable {
  case pinyin
  case hiragana
  case abc

  var title: String {
    switch self {
    case .pinyin:
      return "Apple Pinyin"
    case .hiragana:
      return "Japanese Hiragana"
    case .abc:
      return "ABC"
    }
  }

  var storageKey: String {
    switch self {
    case .pinyin:
      return "shortcut.pinyin"
    case .hiragana:
      return "shortcut.hiragana"
    case .abc:
      return "shortcut.abc"
    }
  }

  func matches(_ source: InputSourceInfo) -> Bool {
    guard source.isEnabled, source.isSelectable else { return false }

    switch self {
    case .abc:
      return source.id == "com.apple.keylayout.ABC" && source.modeID == nil
    case .pinyin:
      return source.id == "com.apple.inputmethod.SCIM.ITABC"
        && source.modeID == "com.apple.inputmethod.SCIM.ITABC"
    case .hiragana:
      guard source.modeID == "com.apple.inputmethod.Japanese" else { return false }
      let legacyBundle = source.bundleID == "com.apple.inputmethod.Kotoeri"
        || source.bundleID?.hasPrefix("com.apple.inputmethod.Kotoeri.") == true
      let currentBundle = source.bundleID == "com.apple.JapaneseIM"
        || source.bundleID?.hasPrefix("com.apple.JapaneseIM.") == true
      return source.id.hasPrefix("com.apple.inputmethod.Kotoeri.")
        || legacyBundle
        || currentBundle
    }
  }
}
