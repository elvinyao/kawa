import AppKit
import Foundation
import MASShortcut

final class ShortcutStore: ShortcutPersisting {
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func binding(for target: InputTarget) -> ShortcutBinding? {
    if let canonicalValue = defaults.object(forKey: target.storageKey) {
      return decode(canonicalValue)
    }

    for legacyKey in legacyKeys(for: target) {
      guard let legacyValue = defaults.object(forKey: legacyKey),
            let binding = decode(legacyValue) else { continue }
      save(binding, for: target)
      return binding
    }

    return nil
  }

  func save(_ binding: ShortcutBinding?, for target: InputTarget) {
    guard let binding = binding else {
      defaults.set(Data(), forKey: target.storageKey)
      return
    }

    guard binding.validationError == nil else { return }
    let shortcut = MASShortcut(
      keyCode: binding.keyCode,
      modifierFlags: NSEvent.ModifierFlags(rawValue: binding.modifierFlags)
    )
    guard let data = try? NSKeyedArchiver.archivedData(
      withRootObject: shortcut,
      requiringSecureCoding: true
    ) else { return }
    defaults.set(data, forKey: target.storageKey)
  }

  private func decode(_ value: Any) -> ShortcutBinding? {
    guard let data = value as? Data, !data.isEmpty else { return nil }
    guard let shortcut = try? NSKeyedUnarchiver.unarchivedObject(
      ofClass: MASShortcut.self,
      from: data
    ) else { return nil }

    let binding = ShortcutBinding(
      keyCode: shortcut.keyCode,
      modifierFlags: UInt(shortcut.modifierFlags.rawValue)
    )
    guard binding.validationError == nil else { return nil }
    return binding.normalized
  }

  private func legacyKeys(for target: InputTarget) -> [String] {
    switch target {
    case .abc:
      return ["com-apple-keylayout-ABC"]
    case .pinyin:
      return ["com-apple-inputmethod-SCIM-ITABC"]
    case .hiragana:
      return [
        "com-apple-inputmethod-Kotoeri-RomajiTyping-Japanese",
        "com-apple-inputmethod-Kotoeri-Japanese",
        "com-apple-inputmethod-Kotoeri-RomajiTyping",
        "com-apple-JapaneseIM-RomajiTyping-Japanese",
        "com-apple-JapaneseIM-Japanese",
        "com-apple-JapaneseIM-RomajiTyping"
      ]
    }
  }
}
