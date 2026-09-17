import Cocoa
import MASShortcut

final class PolishedShortcutView: MASShortcutView {
  override class func shortcutCellClass() -> AnyClass {
    PolishedShortcutCell.self
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: 160, height: 26)
  }

  override func awakeFromNib() {
    super.awakeFromNib()
    // The default style reserves a 23-point trailing action area. Keep its
    // inherited hit testing while the custom cell supplies the appearance.
    style = .default
    setAcceptsFirstResponder(true)
    // Draw focus inside the control instead of AppKit's outward cell mask.
    focusRingType = .none
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
      strokeColor = NSColor.disabledControlTextColor.withAlphaComponent(0.18)
    } else if isRecording {
      fillColor = NSColor.controlAccentColor.withAlphaComponent(0.08)
      strokeColor = .controlAccentColor
    } else if isFocused {
      fillColor = NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.04)
      strokeColor = .keyboardFocusIndicatorColor
    } else if shortcutValue != nil {
      fillColor = NSColor.labelColor.withAlphaComponent(0.03)
      strokeColor = NSColor.labelColor.withAlphaComponent(0.20)
    } else {
      fillColor = .clear
      strokeColor = NSColor.labelColor.withAlphaComponent(0.16)
    }

    let bounds = self.bounds.insetBy(dx: 1, dy: 1)
    let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
    fillColor.setFill()
    path.fill()
    strokeColor.setStroke()
    path.lineWidth = isRecording || isFocused ? 1.5 : 1
    path.stroke()
  }
}

final class PolishedShortcutCell: NSButtonCell {
  override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
    drawInterior(withFrame: cellFrame, in: controlView)
  }

  override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
    if alignment == .right {
      drawDismissButton(in: cellFrame)
      return
    }
    switch title {
    case "Record Shortcut":
      title = "Set Shortcut"
    case "Type Shortcut", "Type New Shortcut":
      title = "Press shortcut"
    default:
      break
    }
    let textColor: NSColor
    if !isEnabled {
      textColor = .disabledControlTextColor
    } else if (controlView as? MASShortcutView)?.shortcutValue != nil {
      textColor = .labelColor
    } else {
      textColor = .secondaryLabelColor
    }
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 12),
      .foregroundColor: textColor
    ]
    let text = title as NSString
    let textSize = text.size(withAttributes: attributes)
    let x = cellFrame.midX - textSize.width / 2
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    // Keep localized prompts and long key combinations inside their own segment.
    NSBezierPath(rect: cellFrame.insetBy(dx: 4, dy: 0)).addClip()
    text.draw(at: NSPoint(x: x, y: cellFrame.midY - textSize.height / 2), withAttributes: attributes)
  }

  private func drawDismissButton(in frame: NSRect) {
    // MASShortcut's default style centers clear/cancel in the trailing 23 pt.
    let center = NSPoint(x: frame.maxX - 11.5, y: frame.midY)
    let circle = NSBezierPath(ovalIn: NSRect(
      x: center.x - 6, y: center.y - 6, width: 12, height: 12
    ))
    NSColor.labelColor.withAlphaComponent(isEnabled ? 0.08 : 0.04).setFill()
    circle.fill()

    let mark = NSBezierPath()
    mark.move(to: NSPoint(x: center.x - 2, y: center.y - 2))
    mark.line(to: NSPoint(x: center.x + 2, y: center.y + 2))
    mark.move(to: NSPoint(x: center.x + 2, y: center.y - 2))
    mark.line(to: NSPoint(x: center.x - 2, y: center.y + 2))
    mark.lineWidth = 1
    mark.lineCapStyle = .round
    (isEnabled ? NSColor.secondaryLabelColor : NSColor.disabledControlTextColor).setStroke()
    mark.stroke()
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
    let recorderY = isFlipped ? CGFloat(8) : max(0, bounds.height - 34)
    let errorY = isFlipped ? CGFloat(38) : CGFloat(4)
    let recorderWidth = min(160, max(0, bounds.width - 24))
    shortcutView.frame = NSRect(
      x: floor((bounds.width - recorderWidth) / 2),
      y: recorderY,
      width: recorderWidth,
      height: 26
    )
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
