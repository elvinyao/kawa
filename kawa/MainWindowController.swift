import Cocoa

class MainWindowController: NSWindowController, NSWindowDelegate {
  private static let contentWidth: CGFloat = 520
  private static let tabChromeHeight: CGFloat = 38

  static let shared: MainWindowController = {
    let storyboard = NSStoryboard(name: "Main", bundle: nil)
    return storyboard.instantiateController(withIdentifier: "MainWindow") as! MainWindowController
  }()

  func showAndActivate(_ sender: AnyObject?) {
    self.showWindow(sender)
    fitToSelectedContent()
    self.window?.makeKeyAndOrderFront(sender)
    NSApp.activate(ignoringOtherApps: true)
  }

  override func windowDidLoad() {
    super.windowDidLoad()
    window?.title = "Kawa Settings"
    fitToSelectedContent()
  }

  func fitToSelectedContent() {
    guard let window = window,
          let tabs = contentViewController as? NSTabViewController,
          tabs.tabViewItems.indices.contains(tabs.selectedTabViewItemIndex),
          let selectedController = tabs.tabViewItems[tabs.selectedTabViewItemIndex].viewController else {
      return
    }

    _ = selectedController.view
    let targetSize = NSSize(
      width: Self.contentWidth,
      height: selectedController.preferredContentSize.height + Self.tabChromeHeight
    )
    guard abs(window.contentLayoutRect.width - targetSize.width) > 0.5
      || abs(window.contentLayoutRect.height - targetSize.height) > 0.5 else { return }
    window.setContentSize(targetSize)
  }

  func windowWillClose(_ notification: Notification) {
    deactivate()
  }

  func deactivate() {
    // focus an application owning the menu bar
    let workspace = NSWorkspace.shared
    workspace.menuBarOwningApplication?.activate(options: NSApplication.ActivationOptions.activateIgnoringOtherApps)
  }
}

final class SettingsTabViewController: NSTabViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    tabStyle = .segmentedControlOnTop
  }

  override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
    super.tabView(tabView, didSelect: tabViewItem)
    DispatchQueue.main.async { [weak self] in
      (self?.view.window?.windowController as? MainWindowController)?.fitToSelectedContent()
    }
  }
}
