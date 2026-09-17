import Cocoa
import MASShortcut

final class PolishedShortcutView: MASShortcutView {
  private static let flatHintWidth: CGFloat = 15

  override class func shortcutCellClass() -> AnyClass {
    PolishedShortcutCell.self
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: 176, height: 28)
  }

  override func awakeFromNib() {
    super.awakeFromNib()
    style = .flat
    setAcceptsFirstResponder(true)
    focusRingType = .default
    toolTip = "Click to set a shortcut. Use the right-hand control to clear or cancel."
  }

  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    super.mouseDown(with: event)
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let isFocused = window?.firstResponder === self
    let fillColor: NSColor
    let strokeColor: NSColor

    if !isEnabled {
      fillColor = NSColor.disabledControlTextColor.withAlphaComponent(0.05)
      strokeColor = NSColor.disabledControlTextColor.withAlphaComponent(0.35)
    } else if isRecording {
      fillColor = NSColor.controlAccentColor.withAlphaComponent(0.12)
      strokeColor = .controlAccentColor
    } else if isFocused {
      fillColor = NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.08)
      strokeColor = .keyboardFocusIndicatorColor
    } else if shortcutValue != nil {
      fillColor = NSColor.controlAccentColor.withAlphaComponent(0.07)
      strokeColor = NSColor.controlAccentColor.withAlphaComponent(0.55)
    } else {
      fillColor = .clear
      strokeColor = NSColor.secondaryLabelColor.withAlphaComponent(0.55)
    }

    let bounds = self.bounds.insetBy(dx: 0.5, dy: 0.5)
    let path = NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5)
    fillColor.setFill()
    path.fill()
    strokeColor.setStroke()
    path.lineWidth = isRecording || isFocused ? 1.5 : 1
    path.stroke()

    if shortcutValue != nil || isRecording {
      strokeColor.withAlphaComponent(0.55).setStroke()
      let divider = NSBezierPath()
      let dividerX = self.bounds.maxX - Self.flatHintWidth
      divider.move(to: NSPoint(x: dividerX, y: 5))
      divider.line(to: NSPoint(x: dividerX, y: self.bounds.maxY - 5))
      divider.lineWidth = 1
      divider.stroke()
    }
  }
}

final class PolishedShortcutCell: NSButtonCell {
  override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
    drawInterior(withFrame: cellFrame, in: controlView)
  }

  override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
    switch title {
    case "Record Shortcut":
      title = "Set Shortcut"
    case "Type Shortcut", "Type New Shortcut":
      title = "Press shortcut"
    default:
      break
    }
    super.drawInterior(withFrame: cellFrame, in: controlView)
  }
}

class ShortcutCellView: NSTableCellView {
  @IBOutlet weak var shortcutView: PolishedShortcutView!

  private weak var controller: ShortcutController?
  private var target: InputTarget?
  private var onError: ((ShortcutControllerError) -> Void)?
  private let errorLabel = NSTextField(wrappingLabelWithString: "")

  override func awakeFromNib() {
    super.awakeFromNib()
    errorLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    errorLabel.textColor = .systemRed
    errorLabel.maximumNumberOfLines = 0
    errorLabel.isHidden = true
    addSubview(errorLabel)
  }

  override func layout() {
    super.layout()
    let recorderY = isFlipped ? CGFloat(7) : max(0, bounds.height - 35)
    let errorY = isFlipped ? CGFloat(38) : CGFloat(4)
    shortcutView.frame = NSRect(x: 8, y: recorderY, width: max(0, bounds.width - 16), height: 28)
    errorLabel.frame = NSRect(
      x: 8,
      y: errorY,
      width: max(0, bounds.width - 16),
      height: max(0, bounds.height - 42)
    )
  }

  func configure(
    target: InputTarget,
    controller: ShortcutController,
    errorMessage: String?,
    onError: @escaping (ShortcutControllerError) -> Void
  ) {
    self.target = target
    self.controller = controller
    self.onError = onError
    setErrorMessage(errorMessage)
    load(controller.binding(for: target))
  }

  func setErrorMessage(_ message: String?) {
    errorLabel.stringValue = message ?? ""
    errorLabel.isHidden = message == nil
    needsLayout = true
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
