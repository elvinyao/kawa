import Foundation

struct InputSourceInfo: Equatable {
  let id: String
  let modeID: String?
  let bundleID: String?
  let isEnabled: Bool
  let isSelectable: Bool
  let isKeyboard: Bool
  let localizedName: String
  let iconURL: URL?

  init(
    id: String,
    modeID: String?,
    bundleID: String?,
    isEnabled: Bool,
    isSelectable: Bool,
    isKeyboard: Bool = true,
    localizedName: String? = nil,
    iconURL: URL? = nil
  ) {
    self.id = id
    self.modeID = modeID
    self.bundleID = bundleID
    self.isEnabled = isEnabled
    self.isSelectable = isSelectable
    self.isKeyboard = isKeyboard
    self.localizedName = localizedName ?? id
    self.iconURL = iconURL
  }
}

protocol InputSourceAccess {
  func sources() -> [InputSourceInfo]
  func current() -> InputSourceInfo?
  func select(_ source: InputSourceInfo) -> Int32
}

struct InputTarget: Hashable {
  let sourceID: String
  let modeID: String?
  let bundleID: String?
  let title: String
  let iconURL: URL?

  init(
    sourceID: String,
    modeID: String? = nil,
    bundleID: String? = nil,
    title: String,
    iconURL: URL? = nil
  ) {
    self.sourceID = sourceID
    self.modeID = modeID
    self.bundleID = bundleID
    self.title = title
    self.iconURL = iconURL
  }

  var storageKey: String {
    let identity: [String?] = [sourceID, modeID]
    let data = try! JSONEncoder().encode(identity)
    return "shortcut.v2.\(data.base64EncodedString())"
  }

  func matches(_ source: InputSourceInfo) -> Bool {
    source.isEnabled
      && source.isSelectable
      && source.isKeyboard
      && source.id == sourceID
      && source.modeID == modeID
  }

  static func == (lhs: InputTarget, rhs: InputTarget) -> Bool {
    lhs.sourceID == rhs.sourceID && lhs.modeID == rhs.modeID
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(sourceID)
    hasher.combine(modeID)
  }

  static let pinyin = InputTarget(
    sourceID: "com.apple.inputmethod.SCIM.ITABC",
    modeID: "com.apple.inputmethod.SCIM.ITABC",
    bundleID: "com.apple.inputmethod.SCIM",
    title: "Apple Pinyin"
  )

  static let hiragana = InputTarget(
    sourceID: "com.apple.inputmethod.Kotoeri.RomajiTyping",
    modeID: "com.apple.inputmethod.Japanese",
    bundleID: "com.apple.JapaneseIM.RomajiTyping",
    title: "Japanese Hiragana"
  )

  static let abc = InputTarget(
    sourceID: "com.apple.keylayout.ABC",
    title: "ABC"
  )

}

enum InputSourceCatalog {
  static func targets(from sources: [InputSourceInfo]) -> [InputTarget] {
    var seen = Set<InputTarget>()
    var targets: [InputTarget] = []

    for source in sources where source.isEnabled && source.isSelectable && source.isKeyboard {
      let title: String
      if let modeID = source.modeID {
        let modeName = modeID.split(separator: ".").last.map(String.init) ?? modeID
        title = "\(source.localizedName) — \(modeName)"
      } else {
        title = source.localizedName
      }
      let target = InputTarget(
        sourceID: source.id,
        modeID: source.modeID,
        bundleID: source.bundleID,
        title: title,
        iconURL: source.iconURL
      )
      if seen.insert(target).inserted {
        targets.append(target)
      }
    }

    return targets
  }
}
