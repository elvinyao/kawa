import Cocoa

class ShortcutViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
  @IBOutlet private weak var tableView: NSTableView!
  @IBOutlet private weak var statusLabel: NSTextField!

  private var targets: [InputTarget] = []
  private let sourceResolver = InputSourcePresentationResolver()
  private var applicationActivationObserver: NSObjectProtocol?

  override func viewDidLoad() {
    super.viewDidLoad()
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
      self?.refresh(target: target)
    }
    controller.onError = { [weak self] target, error in
      self?.refresh(target: target)
      self?.showStatus(error.errorDescription ?? "Shortcut registration failed.", isError: true)
    }
    AppServices.shared?.onTargetsChanged = { [weak self] targets in
      self?.applyTargets(targets)
    }
    applyTargets(AppServices.shared?.targets ?? [])
    showInitialStatus(controller: controller)
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    AppServices.shared?.refreshInputSources()
    applyTargets(AppServices.shared?.targets ?? [])
    if let controller = AppServices.shared?.shortcutController {
      showInitialStatus(controller: controller)
    }
  }

  deinit {
    if let applicationActivationObserver = applicationActivationObserver {
      NotificationCenter.default.removeObserver(applicationActivationObserver)
    }
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
    cell?.imageView?.image = presentation.icon
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
    cell?.configure(target: target, controller: controller) { [weak self] error in
      self?.showStatus(error.errorDescription ?? "Shortcut registration failed.", isError: true)
    }
    return cell
  }

  private func showInitialStatus(controller: ShortcutController) {
    if let target = targets.first(where: { controller.error(for: $0) != nil }),
       let error = controller.error(for: target) {
      showStatus("\(target.title): \(error.errorDescription ?? "Shortcut registration failed.")", isError: true)
      return
    }

    if targets.isEmpty {
      showStatus(
        "No enabled keyboard input sources are available. Add one in System Settings → Keyboard → Text Input.",
        isError: false
      )
    } else {
      statusLabel.isHidden = true
    }
  }

  private func showStatus(_ message: String, isError: Bool) {
    statusLabel.stringValue = message
    statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    statusLabel.isHidden = false
  }

  private func refresh(target: InputTarget) {
    guard let row = targets.firstIndex(of: target) else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      let shortcutColumn = self.tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("Shortcut"))
      if shortcutColumn >= 0 {
        (self.tableView.view(
          atColumn: shortcutColumn,
          row: row,
          makeIfNecessary: false
        ) as? ShortcutCellView)?.refresh()
      }
      if let controller = AppServices.shared?.shortcutController {
        self.showInitialStatus(controller: controller)
      }
    }
  }

  private func applyTargets(_ refreshedTargets: [InputTarget]) {
    let sameIdentities = targets.count == refreshedTargets.count
      && zip(targets, refreshedTargets).allSatisfy { $0.0 == $0.1 }
    targets = refreshedTargets

    guard isViewLoaded else { return }
    if !sameIdentities {
      tableView.reloadData()
    } else {
      refreshSourcePresentations()
    }
    if let controller = AppServices.shared?.shortcutController {
      showInitialStatus(controller: controller)
    }
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
}
