import Foundation

protocol SwitchFeedbackReporting: AnyObject {
  func switchDidSucceed(target: InputTarget, source: InputSourceInfo)
  func switchDidFail(target: InputTarget, failure: InputSwitchFailure)
  func invalidatePendingFeedback()
}

extension SwitchFeedbackReporting {
  func invalidatePendingFeedback() {}
}

protocol AppServiceLifecycle: AnyObject {
  func start()
  func stop()
  func refreshInputSources()
}

extension AppServiceLifecycle {
  func refreshInputSources() {}
}

final class AppServices: AppServiceLifecycle {
  static var shared: AppServices?

  private let switcher: InputSourceSwitcher
  private let feedback: SwitchFeedbackReporting
  private let catalog: InputSourceCataloging
  private var started = false
  private var lifecycleGeneration: UInt = 0

  var onTargetsChanged: (([InputTarget]) -> Void)?
  private(set) var targets: [InputTarget] = []

  private let store: ShortcutPersisting
  private let registrar: ShortcutRegistering

  private(set) lazy var shortcutController: ShortcutController = {
    ShortcutController(targets: [], store: store, registrar: registrar) { [weak self] target in
      self?.switchInput(to: target)
    }
  }()

  init(
    store: ShortcutPersisting,
    registrar: ShortcutRegistering,
    access: InputSourceAccess,
    catalog: InputSourceCataloging? = nil,
    schedule: @escaping InputSourceSwitcher.Schedule = { delay, callback in
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: callback)
    },
    feedback: SwitchFeedbackReporting
  ) {
    self.store = store
    self.registrar = registrar
    self.catalog = catalog ?? SystemInputSourceCatalog(access: access)
    switcher = InputSourceSwitcher(access: access, schedule: schedule)
    self.feedback = feedback
  }

  func start() {
    guard !started else { return }
    started = true
    lifecycleGeneration &+= 1
    catalog.startObserving { [weak self] in
      guard let self = self, self.started else { return }
      self.refreshInputSources()
    }
    refreshInputSources()
    shortcutController.start()
  }

  func stop() {
    guard started else { return }
    started = false
    lifecycleGeneration &+= 1
    catalog.stopObserving()
    switcher.invalidate()
    shortcutController.stop()
    feedback.invalidatePendingFeedback()
  }

  func refreshInputSources() {
    if !Thread.isMainThread {
      DispatchQueue.main.async { [weak self] in self?.refreshInputSources() }
      return
    }

    let refreshed = catalog.targets()
    let refreshedSet = Set(refreshed)
    let removedTarget = targets.contains { !refreshedSet.contains($0) }
    let changed = targets != refreshed || zip(targets, refreshed).contains { pair in
      pair.0.title != pair.1.title
        || pair.0.iconURL != pair.1.iconURL
        || pair.0.bundleID != pair.1.bundleID
    }

    targets = refreshed
    shortcutController.updateTargets(refreshed)
    if removedTarget {
      switcher.invalidate()
      feedback.invalidatePendingFeedback()
    }
    if changed {
      onTargetsChanged?(refreshed)
    }
  }

  private func switchInput(to target: InputTarget) {
    guard started else { return }
    feedback.invalidatePendingFeedback()
    let requestGeneration = lifecycleGeneration
    switcher.switchTo(target) { [weak self] result in
      guard let self = self,
            self.started,
            self.lifecycleGeneration == requestGeneration,
            self.targets.contains(target) else { return }

      switch result {
      case .success(let source):
        self.feedback.switchDidSucceed(target: target, source: source)
      case .failure(let failure):
        self.feedback.switchDidFail(target: target, failure: failure)
      }
    }
  }
}

final class AppLaunchCoordinator {
  private let services: AppServiceLifecycle
  private let isFirstLaunch: () -> Bool
  private let markFirstLaunchComplete: () -> Void
  private let showPreferences: () -> Void
  private var finishedLaunching = false

  init(
    services: AppServiceLifecycle,
    isFirstLaunch: @escaping () -> Bool,
    markFirstLaunchComplete: @escaping () -> Void,
    showPreferences: @escaping () -> Void
  ) {
    self.services = services
    self.isFirstLaunch = isFirstLaunch
    self.markFirstLaunchComplete = markFirstLaunchComplete
    self.showPreferences = showPreferences
  }

  func applicationDidFinishLaunching() {
    guard !finishedLaunching else { return }
    finishedLaunching = true
    let firstLaunch = isFirstLaunch()
    services.start()
    if firstLaunch {
      showPreferences()
      markFirstLaunchComplete()
    }
  }

  func applicationDidBecomeActive() {
    guard finishedLaunching else { return }
    services.refreshInputSources()
  }

  func applicationShouldHandleReopen() {
    guard finishedLaunching else { return }
    showPreferences()
  }

  func applicationWillTerminate() {
    services.stop()
  }
}
