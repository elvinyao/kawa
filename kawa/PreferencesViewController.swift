import Cocoa

class PreferencesViewController: NSViewController {
  @IBOutlet weak var showNotificationCheckbox: NSButton!
  private weak var notificationStatusLabel: NSTextField?

  override func viewDidLoad() {
    super.viewDidLoad()

    showNotificationCheckbox.state = PermanentStorage.showsNotification.stateValue
    installNotificationStatusLabel()
    refreshNotificationStatus()
  }

  @IBAction func quitApp(_ sender: NSButton) {
    NSApplication.shared.terminate(nil)
  }

  @IBAction func showNotification(_ sender: NSButton) {
    let enabled = sender.state.boolValue
    PermanentStorage.showsNotification = enabled
    guard enabled else {
      notificationStatusLabel?.isHidden = true
      SwitchFeedback.shared?.notificationPreferenceChanged(enabled: false)
      return
    }
    SwitchFeedback.shared?.notificationPreferenceChanged(enabled: true) { [weak self] status in
      self?.displayNotificationStatus(status)
    }
  }

  private func installNotificationStatusLabel() {
    let label = NSTextField(wrappingLabelWithString: "")
    label.frame = NSRect(x: 21, y: 78, width: max(260, view.bounds.width - 42), height: 42)
    label.autoresizingMask = [.width]
    label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    label.textColor = .secondaryLabelColor
    label.isHidden = true
    view.addSubview(label)
    notificationStatusLabel = label
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
