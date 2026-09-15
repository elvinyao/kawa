import AppKit
import MASShortcut

final class MASShortcutRegistration: ShortcutRegistering {
  private let monitor: MASShortcutMonitor?

  init() {
    monitor = MASShortcutMonitor.shared()
  }

  func register(_ binding: ShortcutBinding, action: @escaping () -> Void) -> Bool {
    guard let monitor = monitor else { return false }
    let shortcut = MASShortcut(
      keyCode: binding.keyCode,
      modifierFlags: NSEvent.ModifierFlags(rawValue: binding.modifierFlags)
    )
    return monitor.register(shortcut, withAction: action)
  }

  func unregister(_ binding: ShortcutBinding) {
    let shortcut = MASShortcut(
      keyCode: binding.keyCode,
      modifierFlags: NSEvent.ModifierFlags(rawValue: binding.modifierFlags)
    )
    monitor?.unregisterShortcut(shortcut)
  }
}
