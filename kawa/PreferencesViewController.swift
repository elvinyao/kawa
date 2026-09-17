import Cocoa

class PreferencesViewController: NSViewController {
  @IBOutlet weak var showNotificationCheckbox: NSButton!
  @IBOutlet weak var preferencesBox: NSBox!
  @IBOutlet weak var quitButton: NSButton!
  private weak var notificationStatusLabel: NSTextField?
  private var applicationActivationObserver: NSObjectProtocol?
  private let helpLabel = NSTextField(wrappingLabelWithString: "Choose whether Kawa confirms successful input source changes with a notification.")

  override func viewDidLoad() {
    super.viewDidLoad()

    showNotificationCheckbox.state = PermanentStorage.showsNotification.stateValue
    configureAppearance()
    installNotificationStatusLabel()
    applicationActivationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: NSApplication.shared,
      queue: .main
    ) { [weak self] _ in
      self?.refreshNotificationStatus()
    }
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    showNotificationCheckbox.state = PermanentStorage.showsNotification.stateValue
    refreshNotificationStatus()
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

  @IBAction func quitApp(_ sender: NSButton) {
    NSApplication.shared.terminate(nil)
  }

  @IBAction func showNotification(_ sender: NSButton) {
    let enabled = sender.state.boolValue
    PermanentStorage.showsNotification = enabled
    guard enabled else {
      notificationStatusLabel?.isHidden = true
      updatePreferredContentSize()
      SwitchFeedback.shared?.notificationPreferenceChanged(enabled: false)
      return
    }
    SwitchFeedback.shared?.notificationPreferenceChanged(enabled: true) { [weak self] status in
      self?.displayNotificationStatus(status)
    }
  }

  private func installNotificationStatusLabel() {
    let label = NSTextField(wrappingLabelWithString: "")
    label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    label.textColor = .secondaryLabelColor
    label.maximumNumberOfLines = 2
    label.isHidden = true
    view.addSubview(label)
    notificationStatusLabel = label
    updatePreferredContentSize()
  }

  private func refreshNotificationStatus() {
    guard PermanentStorage.showsNotification else { return }
    SwitchFeedback.shared?.notificationAuthorizationStatus { [weak self] status in
      self?.displayNotificationStatus(status)
    }
  }

  private func displayNotificationStatus(_ status: SwitchNotificationAuthorization) {
    guard PermanentStorage.showsNotification else {
      notificationStatusLabel?.isHidden = true
      updatePreferredContentSize()
      return
    }
    switch status {
    case .authorized:
      notificationStatusLabel?.stringValue = "Success notifications are enabled."
      notificationStatusLabel?.textColor = .secondaryLabelColor
      notificationStatusLabel?.isHidden = false
    case .denied:
      notificationStatusLabel?.stringValue = "Notifications are denied in System Settings. Input switching still works."
      notificationStatusLabel?.textColor = .systemRed
      notificationStatusLabel?.isHidden = false
    case .notDetermined:
      notificationStatusLabel?.isHidden = true
    }
    updatePreferredContentSize()
  }

  private func configureAppearance() {
    helpLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    helpLabel.textColor = .secondaryLabelColor
    helpLabel.maximumNumberOfLines = 2
    view.addSubview(helpLabel)
    preferencesBox.title = "Notifications"
    preferencesBox.boxType = .primary
    showNotificationCheckbox.font = NSFont.systemFont(ofSize: 13)
    quitButton.bezelStyle = .rounded
    quitButton.controlSize = .regular
  }

  private func updatePreferredContentSize() {
    guard isViewLoaded else { return }
    preferredContentSize = NSSize(
      width: 520,
      height: notificationStatusLabel?.isHidden == false ? 230 : 190
    )
    view.needsLayout = true
    DispatchQueue.main.async { [weak self] in
      (self?.view.window?.windowController as? MainWindowController)?.fitToSelectedContent()
    }
  }

  private func layoutContent() {
    let margin: CGFloat = 20
    let availableWidth = max(0, view.bounds.width - margin * 2)
    helpLabel.frame = NSRect(
      x: margin,
      y: view.bounds.height - margin - 28,
      width: availableWidth,
      height: 28
    )
    let boxY = helpLabel.frame.minY - 72
    preferencesBox.frame = NSRect(
      x: margin,
      y: boxY,
      width: availableWidth,
      height: 62
    )
    showNotificationCheckbox.frame = NSRect(
      x: 12,
      y: 18,
      width: preferencesBox.contentView?.bounds.width ?? availableWidth - 24,
      height: 20
    )
    notificationStatusLabel?.frame = NSRect(
      x: margin,
      y: boxY - 44,
      width: availableWidth,
      height: notificationStatusLabel?.isHidden == false ? 36 : 0
    )
    quitButton.sizeToFit()
    quitButton.frame.origin = NSPoint(
      x: view.bounds.width - margin - quitButton.frame.width,
      y: 16
    )
  }
}

private extension Bool {
  var stateValue: NSControl.StateValue {
    return self ? .on : .off;
  }
}

private extension NSControl.StateValue {
  var boolValue: Bool {
    return self == .on;
  }
}
