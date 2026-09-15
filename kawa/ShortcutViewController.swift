import Cocoa

class ShortcutViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
  @IBOutlet private weak var tableView: NSTableView!
  @IBOutlet private weak var statusLabel: NSTextField!

  private let targets = InputTarget.allCases
  private let sourceResolver = InputSourcePresentationResolver()
  private var applicationActivationObserver: NSObjectProtocol?

  override func viewDidLoad() {
    super.viewDidLoad()
    applicationActivationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: NSApplication.shared,
      queue: .main
    ) { [weak self] _ in
      self?.refreshSourceAvailability()
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
    showInitialStatus(controller: controller)
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    tableView.reloadData()
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
    cell?.imageView?.image = presentation?.icon
    if target == .hiragana {
      cell?.toolTip = presentation.map {
        "Normal Japanese Hiragana with Kanji conversion. Enabled source: \($0.name)"
      } ?? "Enable Japanese Romaji input for normal Hiragana with Kanji conversion in System Settings."
    } else {
      cell?.toolTip = presentation.map { "Enabled input source: \($0.name)" }
        ?? "Enable \(target.title) in System Settings → Keyboard → Text Input."
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

    let unavailable = targets.filter { sourceResolver.presentation(for: $0) == nil }
    if unavailable.isEmpty {
      statusLabel.isHidden = true
    } else {
      let names = unavailable.map(\.title).joined(separator: ", ")
      showStatus(
        "Enable \(names) in System Settings → Keyboard → Text Input. You can still record shortcuts here.",
        isError: false
      )
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

  private func refreshSourceAvailability() {
    let keyboardColumn = tableView.column(
      withIdentifier: NSUserInterfaceItemIdentifier("Keyboard")
    )
    if keyboardColumn >= 0 {
      tableView.reloadData(
        forRowIndexes: IndexSet(integersIn: targets.indices),
        columnIndexes: IndexSet(integer: keyboardColumn)
      )
    }
    if let controller = AppServices.shared?.shortcutController {
      showInitialStatus(controller: controller)
    }
  }
}
