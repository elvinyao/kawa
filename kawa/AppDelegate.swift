import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  let statusBar = StatusBar.shared

  private lazy var switchFeedback = SwitchFeedback(
    notificationsEnabled: { PermanentStorage.showsNotification },
    notifications: UserNotificationDelivery(),
    status: statusBar
  )
  private lazy var services = AppServices(
    store: ShortcutStore(),
    registrar: MASShortcutRegistration(),
    access: CarbonInputSourceAccess(),
    feedback: switchFeedback
  )
  private lazy var launchCoordinator = AppLaunchCoordinator(
    services: services,
    isFirstLaunch: { PermanentStorage.launchedForTheFirstTime },
    markFirstLaunchComplete: { PermanentStorage.launchedForTheFirstTime = false },
    showPreferences: { [weak self] in self?.showPreferences() }
  )

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    AppServices.shared = services
    SwitchFeedback.shared = switchFeedback
    launchCoordinator.applicationDidFinishLaunching()
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    launchCoordinator.applicationShouldHandleReopen()
    return true
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    launchCoordinator.applicationDidBecomeActive()
  }

  func applicationWillTerminate(_ notification: Notification) {
    launchCoordinator.applicationWillTerminate()
  }

  @IBAction func showPreferences(_ sender: AnyObject? = nil) {
    MainWindowController.shared.showAndActivate(self)
  }

  @IBAction func hidePreferences(_ sender: AnyObject?) {
    MainWindowController.shared.close()
  }
}
