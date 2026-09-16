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
    var seenIdentities = Set<InputTarget>()
    var uniqueSources: [InputSourceInfo] = []

    for source in sources where source.isEnabled && source.isSelectable && source.isKeyboard {
      let identity = InputTarget(
        sourceID: source.id,
        modeID: source.modeID,
        bundleID: source.bundleID,
        title: source.localizedName,
        iconURL: source.iconURL
      )
      if seenIdentities.insert(identity).inserted {
        uniqueSources.append(source)
      }
    }

    let nameCounts = Dictionary(grouping: uniqueSources, by: \.localizedName).mapValues {
      $0.count
    }
    let reservedTitles = Set(uniqueSources.compactMap { source -> String? in
      nameCounts[source.localizedName, default: 0] == 1 ? source.localizedName : nil
    })
    let generatedTitles = uniqueSources.compactMap { source -> String? in
      guard nameCounts[source.localizedName, default: 0] > 1 else { return nil }
      return "\(source.localizedName) — \(modeLabel(for: source))"
    }
    let generatedTitleCounts = Dictionary(grouping: generatedTitles, by: { $0 }).mapValues {
      $0.count
    }
    var occupiedTitles = reservedTitles
    let titles = uniqueSources.map { source -> String in
      guard nameCounts[source.localizedName, default: 0] > 1 else {
        return source.localizedName
      }

      let readableTitle = "\(source.localizedName) — \(modeLabel(for: source))"
      let identitySuffix = " — \(identityLabel(for: source))"
      var title = readableTitle
      if generatedTitleCounts[readableTitle, default: 0] > 1
        || occupiedTitles.contains(title) {
        title += identitySuffix
      }
      while occupiedTitles.contains(title) {
        title += identitySuffix
      }
      occupiedTitles.insert(title)
      return title
    }
    return zip(uniqueSources, titles).map { source, title in
      return InputTarget(
        sourceID: source.id,
        modeID: source.modeID,
        bundleID: source.bundleID,
        title: title,
        iconURL: source.iconURL
      )
    }
  }

  private static func modeLabel(for source: InputSourceInfo) -> String {
    guard let modeID = source.modeID else { return "Default" }
    let appleJapanese = source.id.hasPrefix("com.apple.inputmethod.Kotoeri.")
      || source.bundleID == "com.apple.inputmethod.Kotoeri"
      || source.bundleID?.hasPrefix("com.apple.inputmethod.Kotoeri.") == true
      || source.bundleID == "com.apple.JapaneseIM"
      || source.bundleID?.hasPrefix("com.apple.JapaneseIM.") == true
    if modeID == "com.apple.inputmethod.Japanese", appleJapanese {
      return "Hiragana"
    }
    if modeID == "com.apple.inputmethod.SCIM.ITABC" {
      return "Pinyin"
    }
    return modeID.split(separator: ".").last.map(String.init) ?? "Mode"
  }

  private static func identityLabel(for source: InputSourceInfo) -> String {
    guard let modeID = source.modeID else { return source.id }
    return "\(source.id) / \(modeID)"
  }
}
