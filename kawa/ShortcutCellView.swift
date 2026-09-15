import Cocoa
import MASShortcut

class ShortcutCellView: NSTableCellView {
  @IBOutlet weak var shortcutView: MASShortcutView!

  private weak var controller: ShortcutController?
  private var target: InputTarget?
  private var onError: ((ShortcutControllerError) -> Void)?

  func configure(
    target: InputTarget,
    controller: ShortcutController,
    onError: @escaping (ShortcutControllerError) -> Void
  ) {
    self.target = target
    self.controller = controller
    self.onError = onError
    load(controller.binding(for: target))
  }

  func shortcutValueDidChange(_ sender: MASShortcutView?) {
    guard sender === shortcutView,
          let target = target,
          let controller = controller else { return }
    let binding = sender?.shortcutValue.map {
      ShortcutBinding(
        keyCode: $0.keyCode,
        modifierFlags: UInt($0.modifierFlags.rawValue)
      )
    }

    if case .failure(let error) = controller.setBinding(binding, for: target) {
      load(controller.binding(for: target))
      onError?(error)
    }
  }

  func refresh() {
    guard let target = target else { return }
    load(controller?.binding(for: target))
  }

  private func load(_ binding: ShortcutBinding?) {
    shortcutView.shortcutValueChange = nil
    shortcutView.shortcutValue = binding.map {
      MASShortcut(
        keyCode: $0.keyCode,
        modifierFlags: NSEvent.ModifierFlags(rawValue: $0.modifierFlags)
      )
    }
    shortcutView.shortcutValueChange = { [weak self] sender in
      self?.shortcutValueDidChange(sender)
    }
  }
}
