import AppKit
import Cocoa

final class StatusBar: SwitchStatusDisplaying {
  static let shared: StatusBar = StatusBar()

  let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

  init() {
    guard let button = item.button else { return }
    button.target = self
    button.action = #selector(StatusBar.action(_:))
    button.image = normalImage
    button.appearsDisabled = false;
    button.toolTip = "Click to open preferences"
  }

  @objc func action(_ sender: NSButton) {
    MainWindowController.shared.showAndActivate(sender)
  }

  func showSwitchFailure(_ message: String) {
    updateButton {
      $0.image = NSImage(
        systemSymbolName: "exclamationmark.triangle.fill",
        accessibilityDescription: "Input source switch failed"
      ) ?? self.normalImage
      $0.contentTintColor = .systemRed
      $0.toolTip = "Kawa: \(message)"
    }
  }

  func clearSwitchFailure() {
    updateButton {
      $0.image = self.normalImage
      $0.contentTintColor = nil
      $0.toolTip = "Click to open preferences"
    }
  }

  private var normalImage: NSImage? {
    let image = NSImage(named: "StatusItemIcon")
    image?.isTemplate = true
    return image
  }

  private func updateButton(_ update: @escaping (NSStatusBarButton) -> Void) {
    let apply = { [weak self] in
      guard let button = self?.item.button else { return }
      update(button)
    }
    if Thread.isMainThread {
      apply()
    } else {
      DispatchQueue.main.async(execute: apply)
    }
  }
}
