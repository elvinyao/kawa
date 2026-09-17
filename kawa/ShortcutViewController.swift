import Cocoa

class ShortcutViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
  @IBOutlet private weak var scrollView: NSScrollView!
  @IBOutlet private weak var tableView: NSTableView!
  @IBOutlet private weak var statusLabel: NSTextField!

  private var targets: [InputTarget] = []
  private var targetErrors: [InputTarget: String] = [:]
  private let sourceResolver = InputSourcePresentationResolver()
  private var applicationActivationObserver: NSObjectProtocol?
  private let helpLabel = NSTextField(wrappingLabelWithString: "Choose a shortcut for each input source. Click a shortcut again to replace or clear it.")

  private let contentMargin: CGFloat = 20
  private let rowHeight: CGFloat = 42
  private let headerHeight: CGFloat = 24
  private let maximumVisibleRows = 8

  override func viewDidLoad() {
    super.viewDidLoad()
    configureAppearance()
    applicationActivationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: NSApplication.shared,
      queue: .main
    ) { [weak self] _ in
      AppServices.shared?.refreshInputSources()
      self?.applyTargets(AppServices.shared?.targets ?? [])
    }
    guard let controller = AppServices.shared?.shortcutController else {
      showStatus("Shortcut services are not available.", isError: true)
      return
    }
    controller.onChange = { [weak self] target, _ in
      self?.targetErrors.removeValue(forKey: target)
      self?.refresh(target: target)
    }
    controller.onError = { [weak self] target, error in
      self?.targetErrors[target] = error.errorDescription ?? "Shortcut registration failed."
      self?.refresh(target: target)
    }
    AppServices.shared?.onTargetsChanged = { [weak self] targets in
      self?.applyTargets(targets)
    }
    applyTargets(AppServices.shared?.targets ?? [])
    showInitialStatus()
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    AppServices.shared?.refreshInputSources()
    applyTargets(AppServices.shared?.targets ?? [])
    showInitialStatus()
  }

  deinit {
    if let applicationActivationObserver = applicationActivationObserver {
      NotificationCenter.default.removeObserver(applicationActivationObserver)
    }
  }

  override func viewDidLayout() {
    super.viewDidLayout()
    layoutContent()
  }

  func numberOfRows(in tableView: NSTableView) -> Int {
    targets.count
  }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard targets.indices.contains(row), let identifier = tableColumn?.identifier.rawValue else {
      return nil
    }
    let target = targets[row]

    switch identifier {
    case "Keyboard":
      return createKeyboardCellView(tableView, target)
    case "Shortcut":
      return createShortcutCellView(tableView, target)
    default:
      return nil
    }
  }

  func createKeyboardCellView(_ tableView: NSTableView, _ target: InputTarget) -> NSTableCellView? {
    let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "KeyboardCellView"), owner: self) as? NSTableCellView
    let presentation = sourceResolver.presentation(for: target)
    cell?.textField?.stringValue = target.title
    cell?.textField?.font = NSFont.systemFont(ofSize: 13)
    cell?.textField?.lineBreakMode = .byTruncatingTail
    cell?.textField?.toolTip = target.title
    cell?.imageView?.image = presentation.icon ?? fallbackKeyboardIcon()
    cell?.imageView?.imageScaling = .scaleProportionallyDown
    if let cell = cell {
      let iconY = cell.isFlipped ? CGFloat(11) : max(0, cell.bounds.height - 31)
      let textY = cell.isFlipped ? CGFloat(13) : max(0, cell.bounds.height - 29)
      cell.imageView?.frame = NSRect(x: 8, y: iconY, width: 20, height: 20)
      cell.textField?.frame = NSRect(x: 38, y: textY, width: max(0, cell.bounds.width - 46), height: 16)
      cell.textField?.autoresizingMask = [.width, .minYMargin]
    }
    if let modeID = target.modeID {
      cell?.toolTip = "\(presentation.name)\nSource: \(target.sourceID)\nMode: \(modeID)"
    } else {
      cell?.toolTip = "\(presentation.name)\nSource: \(target.sourceID)"
    }
    return cell
  }

  func createShortcutCellView(_ tableView: NSTableView, _ target: InputTarget) -> ShortcutCellView? {
    let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ShortcutCellView"), owner: self) as? ShortcutCellView
    guard let controller = AppServices.shared?.shortcutController else { return cell }
    cell?.configure(target: target, controller: controller, errorMessage: targetErrors[target]) { [weak self] error in
      guard let self = self else { return }
      self.targetErrors[target] = error.errorDescription ?? "Shortcut registration failed."
      self.refresh(target: target)
    }
    return cell
  }

  func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
    guard targets.indices.contains(row) else { return rowHeight }
    return height(for: targets[row])
  }

  private func showInitialStatus() {
    guard AppServices.shared?.shortcutController != nil else {
      showStatus("Shortcut services are not available.", isError: true)
      return
    }
    if targets.isEmpty {
      showStatus(
        "No enabled keyboard input sources are available. Add one in System Settings → Keyboard → Text Input.",
        isError: false
      )
    } else {
      statusLabel.isHidden = true
      updatePreferredContentSize()
    }
  }

  private func showStatus(_ message: String, isError: Bool) {
    statusLabel.stringValue = message
    statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    statusLabel.isHidden = false
    updatePreferredContentSize()
  }

  private func refresh(target: InputTarget) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self,
            let row = self.targets.firstIndex(of: target) else { return }
      let shortcutColumn = self.tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("Shortcut"))
      if shortcutColumn >= 0 {
        let shortcutCell = self.tableView.view(
          atColumn: shortcutColumn,
          row: row,
          makeIfNecessary: false
        ) as? ShortcutCellView
        shortcutCell?.setErrorMessage(self.targetErrors[target])
        shortcutCell?.refresh()
      }
      self.tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
      self.updatePreferredContentSize()
      self.showInitialStatus()
    }
  }

  private func applyTargets(_ refreshedTargets: [InputTarget]) {
    let sameIdentities = targets.count == refreshedTargets.count
      && zip(targets, refreshedTargets).allSatisfy { $0.0 == $0.1 }
    targets = refreshedTargets
    targetErrors = targetErrors.filter { refreshedTargets.contains($0.key) }

    if let controller = AppServices.shared?.shortcutController {
      cacheControllerErrors(controller)
    }

    guard isViewLoaded else { return }
    if !sameIdentities {
      tableView.reloadData()
    } else {
      refreshSourcePresentations()
    }
    showInitialStatus()
    updatePreferredContentSize()
  }

  private func refreshSourcePresentations() {
    let keyboardColumn = tableView.column(
      withIdentifier: NSUserInterfaceItemIdentifier("Keyboard")
    )
    if keyboardColumn >= 0 {
      tableView.reloadData(
        forRowIndexes: IndexSet(integersIn: targets.indices),
        columnIndexes: IndexSet(integer: keyboardColumn)
      )
    }
  }

  private func configureAppearance() {
    helpLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    helpLabel.textColor = .secondaryLabelColor
    helpLabel.maximumNumberOfLines = 2
    helpLabel.autoresizingMask = [.width]
    view.addSubview(helpLabel)

    statusLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    statusLabel.maximumNumberOfLines = 2
    tableView.rowHeight = rowHeight
    tableView.intercellSpacing = .zero
    tableView.gridStyleMask = .solidHorizontalGridLineMask
    tableView.gridColor = .separatorColor
    tableView.usesAlternatingRowBackgroundColors = true
    tableView.backgroundColor = .controlBackgroundColor
    tableView.selectionHighlightStyle = .none
    tableView.tableColumns.first?.title = "Input Source"
    tableView.tableColumns.first?.width = 270
    if tableView.tableColumns.count > 1 {
      tableView.tableColumns[1].width = 207
    }
    scrollView.borderType = .lineBorder
    scrollView.drawsBackground = false
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    updatePreferredContentSize()
  }

  private func cacheControllerErrors(_ controller: ShortcutController) {
    for target in targets {
      if let error = controller.error(for: target) {
        targetErrors[target] = error.errorDescription ?? "Shortcut registration failed."
      } else {
        targetErrors.removeValue(forKey: target)
      }
    }
  }

  private func fallbackKeyboardIcon() -> NSImage? {
    let icon = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard input source")
    return icon?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .regular))
  }

  private func updatePreferredContentSize() {
    guard isViewLoaded else { return }
    let visibleTargets = targets.prefix(maximumVisibleRows)
    let rowAreaHeight = visibleTargets.reduce(CGFloat(0)) { height, target in
      height + self.height(for: target)
    }
    let tableHeight = headerHeight + max(rowHeight, rowAreaHeight)
    let statusHeight = statusLabel.isHidden ? CGFloat(0) : CGFloat(40)
    preferredContentSize = NSSize(
      width: 520,
      height: contentMargin + 32 + 10 + tableHeight + (statusHeight > 0 ? 10 + statusHeight : 0) + contentMargin
    )
    view.needsLayout = true
    DispatchQueue.main.async { [weak self] in
      (self?.view.window?.windowController as? MainWindowController)?.fitToSelectedContent()
    }
  }

  private func layoutContent() {
    let availableWidth = max(0, view.bounds.width - contentMargin * 2)
    let helpHeight: CGFloat = 32
    let statusHeight = statusLabel.isHidden ? CGFloat(0) : CGFloat(40)
    helpLabel.frame = NSRect(
      x: contentMargin,
      y: view.bounds.height - contentMargin - helpHeight,
      width: availableWidth,
      height: helpHeight
    )
    let tableBottom = contentMargin + (statusHeight > 0 ? statusHeight + 10 : 0)
    scrollView.frame = NSRect(
      x: contentMargin,
      y: tableBottom,
      width: availableWidth,
      height: max(0, helpLabel.frame.minY - 10 - tableBottom)
    )
    statusLabel.frame = NSRect(
      x: contentMargin,
      y: contentMargin,
      width: availableWidth,
      height: statusHeight
    )
  }

  private func height(for target: InputTarget) -> CGFloat {
    guard let message = targetErrors[target] else { return rowHeight }
    let shortcutWidth = tableView.tableColumns.count > 1
      ? max(120, tableView.tableColumns[1].width - 16)
      : 191
    let textBounds = (message as NSString).boundingRect(
      with: NSSize(width: shortcutWidth, height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]
    )
    return rowHeight + max(20, ceil(textBounds.height)) + 8
  }
}
