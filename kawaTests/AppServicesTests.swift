import AppKit
import Foundation
import XCTest

final class AppServicesTests: XCTestCase {
  private let command = UInt(NSEvent.ModifierFlags.command.rawValue)

  func testStartRestoresShortcutAndRoutesVerifiedSwitchToSuccessFeedback() {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let store = IntegrationShortcutStore([.pinyin: binding])
    let registrar = IntegrationShortcutRegistrar()
    let access = IntegrationInputSourceAccess(sources: [.pinyin])
    access.onSelect = { access.currentSource = .pinyin }
    let feedback = RecordingSwitchFeedback()
    let services = AppServices(
      store: store,
      registrar: registrar,
      access: access,
      feedback: feedback
    )

    services.start()
    registrar.trigger(binding)

    XCTAssertEqual(access.selectionRequests, [.pinyin])
    XCTAssertEqual(feedback.successes.map(\.0), [.pinyin])
    XCTAssertEqual(feedback.failures.count, 0)
  }

  func testAbsentSourceDoesNotCreateOrTriggerFixedPresetRow() {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let registrar = IntegrationShortcutRegistrar()
    let feedback = RecordingSwitchFeedback()
    let services = AppServices(
      store: IntegrationShortcutStore([.pinyin: binding]),
      registrar: registrar,
      access: IntegrationInputSourceAccess(sources: []),
      feedback: feedback
    )

    services.start()
    registrar.trigger(binding)

    XCTAssertEqual(feedback.successes.count, 0)
    XCTAssertEqual(feedback.failures.count, 0)
    XCTAssertEqual(registrar.activeBindings, [])
  }

  func testQueuedOldHotkeyDoesNothingAfterReplacementClearAndStop() {
    let original = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let replacement = ShortcutBinding(keyCode: 19, modifierFlags: command)
    let registrar = IntegrationShortcutRegistrar()
    let access = IntegrationInputSourceAccess(sources: [.pinyin])
    access.onSelect = { access.currentSource = .pinyin }
    let services = AppServices(
      store: IntegrationShortcutStore([.pinyin: original]),
      registrar: registrar,
      access: access,
      feedback: RecordingSwitchFeedback()
    )
    services.start()
    let beforeReplacement = registrar.latestAction(for: original)

    _ = services.shortcutController.setBinding(replacement, for: .pinyin)
    let beforeClear = registrar.latestAction(for: replacement)
    _ = services.shortcutController.setBinding(nil, for: .pinyin)
    beforeReplacement?()
    beforeClear?()

    _ = services.shortcutController.setBinding(replacement, for: .pinyin)
    let beforeStop = registrar.latestAction(for: replacement)
    services.stop()
    beforeStop?()

    XCTAssertEqual(access.selectionRequests, [])
  }

  func testPendingSwitchCompletionCannotReportAfterStopAndRestart() {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let registrar = IntegrationShortcutRegistrar()
    let access = IntegrationInputSourceAccess(sources: [.pinyin], current: .abc)
    let scheduler = IntegrationQueuedScheduler()
    let feedback = RecordingSwitchFeedback()
    let services = AppServices(
      store: IntegrationShortcutStore([.pinyin: binding]),
      registrar: registrar,
      access: access,
      schedule: scheduler.schedule,
      feedback: feedback
    )
    services.start()
    registrar.trigger(binding)

    services.stop()
    services.start()
    access.currentSource = .pinyin
    scheduler.runNext()

    XCTAssertEqual(feedback.successes.count, 0)
    XCTAssertEqual(feedback.failures.count, 0)
  }

  func testNewSwitchRequestInvalidatesOlderSuccessWaitingForNotificationStatus() {
    let pinyinBinding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let abcBinding = ShortcutBinding(keyCode: 19, modifierFlags: command)
    let registrar = IntegrationShortcutRegistrar()
    let access = IntegrationInputSourceAccess(sources: [.pinyin, .abc], current: .pinyin)
    let scheduler = IntegrationQueuedScheduler()
    let notifications = RecordingNotificationDelivery()
    notifications.authorization = .authorized
    notifications.delaysStatus = true
    let feedback = SwitchFeedback(
      notificationsEnabled: { true },
      notifications: notifications,
      status: RecordingSwitchStatus()
    )
    let services = AppServices(
      store: IntegrationShortcutStore([.pinyin: pinyinBinding, .abc: abcBinding]),
      registrar: registrar,
      access: access,
      schedule: scheduler.schedule,
      feedback: feedback
    )
    services.start()
    registrar.trigger(pinyinBinding)

    access.currentSource = .pinyin
    registrar.trigger(abcBinding)
    notifications.completeStatusRequest()

    XCTAssertEqual(notifications.deliveredTitles, [])
  }

  func testStartUsesDiscoveredThirdPartyTargetsAndPublishesCatalog() {
    let target = InputTarget(sourceID: "org.example.layout", title: "Example")
    let binding = ShortcutBinding(keyCode: 20, modifierFlags: command)
    let registrar = IntegrationShortcutRegistrar()
    let access = IntegrationInputSourceAccess(sources: [
      InputSourceInfo(
        id: target.sourceID,
        modeID: nil,
        bundleID: "org.example",
        isEnabled: true,
        isSelectable: true,
        localizedName: "Example"
      )
    ])
    access.onSelect = { access.currentSource = access.availableSources[0] }
    let catalog = FakeInputSourceCatalog([target])
    let services = AppServices(
      store: IntegrationShortcutStore([target: binding]),
      registrar: registrar,
      access: access,
      catalog: catalog,
      feedback: RecordingSwitchFeedback()
    )

    services.start()
    registrar.trigger(binding)

    XCTAssertEqual(services.targets, [target])
    XCTAssertEqual(access.selectionRequests.map(\.id), [target.sourceID])
    XCTAssertEqual(catalog.startCount, 1)
  }

  func testEnabledSourceNotificationReconcilesTargetsAndStopsCleanly() {
    let first = InputTarget(sourceID: "org.example.first", title: "First")
    let second = InputTarget(sourceID: "org.example.second", title: "Second")
    let catalog = FakeInputSourceCatalog([first])
    let services = AppServices(
      store: IntegrationShortcutStore(),
      registrar: IntegrationShortcutRegistrar(),
      access: IntegrationInputSourceAccess(sources: []),
      catalog: catalog,
      feedback: RecordingSwitchFeedback()
    )
    var updates: [[InputTarget]] = []
    services.onTargetsChanged = { updates.append($0) }
    services.start()

    catalog.availableTargets = [first, second]
    catalog.sendChange()
    services.stop()
    catalog.availableTargets = []
    catalog.sendChange()

    XCTAssertEqual(services.targets, [first, second])
    XCTAssertEqual(updates.last, [first, second])
    XCTAssertEqual(catalog.stopCount, 1)
  }

  func testRemovingTargetSuppressesPendingSwitchFeedback() {
    let binding = ShortcutBinding(keyCode: 20, modifierFlags: command)
    let registrar = IntegrationShortcutRegistrar()
    let access = IntegrationInputSourceAccess(sources: [.pinyin], current: .abc)
    let catalog = FakeInputSourceCatalog([.pinyin])
    let scheduler = IntegrationQueuedScheduler()
    let feedback = RecordingSwitchFeedback()
    let services = AppServices(
      store: IntegrationShortcutStore([.pinyin: binding]),
      registrar: registrar,
      access: access,
      catalog: catalog,
      schedule: scheduler.schedule,
      feedback: feedback
    )
    services.start()
    registrar.trigger(binding)

    catalog.availableTargets = []
    catalog.sendChange()
    access.currentSource = .pinyin
    scheduler.runNext()

    XCTAssertEqual(feedback.successes.count, 0)
    XCTAssertEqual(feedback.failures.count, 0)
    XCTAssertEqual(registrar.activeBindings, [])
  }
}

final class AppLaunchCoordinatorTests: XCTestCase {
  func testFirstLaunchStartsServicesBeforeShowingPreferencesAndClearsFlag() {
    var events: [String] = []
    let services = RecordingServiceLifecycle(onStart: { events.append("start") })
    let coordinator = AppLaunchCoordinator(
      services: services,
      isFirstLaunch: {
        events.append("read-first-launch")
        return true
      },
      markFirstLaunchComplete: { events.append("mark-complete") },
      showPreferences: { events.append("show-preferences") }
    )

    coordinator.applicationDidFinishLaunching()
    XCTAssertEqual(events, [
      "read-first-launch", "start", "show-preferences", "mark-complete"
    ])
  }

  func testActivationBeforeFinishDoesNotConsumeFirstLaunchPresentation() {
    var events: [String] = []
    let coordinator = AppLaunchCoordinator(
      services: RecordingServiceLifecycle(onStart: { events.append("start") }),
      isFirstLaunch: { true },
      markFirstLaunchComplete: { events.append("mark-complete") },
      showPreferences: { events.append("show-preferences") }
    )

    coordinator.applicationDidBecomeActive()
    coordinator.applicationDidFinishLaunching()

    XCTAssertEqual(events, ["start", "show-preferences", "mark-complete"])
  }

  func testFinishLaunchIsIdempotentDuringFirstLaunchPresentation() {
    var startCount = 0
    var showCount = 0
    var markCount = 0
    var coordinator: AppLaunchCoordinator!
    coordinator = AppLaunchCoordinator(
      services: RecordingServiceLifecycle(onStart: { startCount += 1 }),
      isFirstLaunch: { true },
      markFirstLaunchComplete: { markCount += 1 },
      showPreferences: {
        showCount += 1
        coordinator.applicationDidFinishLaunching()
      }
    )

    coordinator.applicationDidFinishLaunching()

    XCTAssertEqual(startCount, 1)
    XCTAssertEqual(showCount, 1)
    XCTAssertEqual(markCount, 1)
  }

  func testLaterLaunchRestoresServicesWithoutOpeningPreferences() {
    var events: [String] = []
    let coordinator = AppLaunchCoordinator(
      services: RecordingServiceLifecycle(onStart: { events.append("start") }),
      isFirstLaunch: { false },
      markFirstLaunchComplete: { events.append("mark-complete") },
      showPreferences: { events.append("show-preferences") }
    )

    coordinator.applicationDidFinishLaunching()
    coordinator.applicationDidBecomeActive()

    XCTAssertEqual(events, ["start"])
  }

  func testActivationAfterLaunchRefreshesInputSources() {
    var refreshCount = 0
    let coordinator = AppLaunchCoordinator(
      services: RecordingServiceLifecycle(onRefresh: { refreshCount += 1 }),
      isFirstLaunch: { false },
      markFirstLaunchComplete: {},
      showPreferences: {}
    )

    coordinator.applicationDidFinishLaunching()
    coordinator.applicationDidBecomeActive()

    XCTAssertEqual(refreshCount, 1)
  }

  func testApplicationReopenShowsPreferencesAfterLaunch() {
    var showCount = 0
    let coordinator = AppLaunchCoordinator(
      services: RecordingServiceLifecycle(),
      isFirstLaunch: { false },
      markFirstLaunchComplete: {},
      showPreferences: { showCount += 1 }
    )
    coordinator.applicationDidFinishLaunching()
    coordinator.applicationShouldHandleReopen()

    XCTAssertEqual(showCount, 1)
  }

  func testTerminationStopsServices() {
    var stopCount = 0
    let coordinator = AppLaunchCoordinator(
      services: RecordingServiceLifecycle(onStop: { stopCount += 1 }),
      isFirstLaunch: { false },
      markFirstLaunchComplete: {},
      showPreferences: {}
    )

    coordinator.applicationWillTerminate()

    XCTAssertEqual(stopCount, 1)
  }
}

final class SwitchFeedbackTests: XCTestCase {
  func testStartupNeverRequestsNotificationAuthorization() {
    let notifications = RecordingNotificationDelivery()

    _ = SwitchFeedback(
      notificationsEnabled: { true },
      notifications: notifications,
      status: RecordingSwitchStatus()
    )

    XCTAssertEqual(notifications.authorizationRequests, 0)
  }

  func testExplicitOptInRequestsAuthorization() {
    let notifications = RecordingNotificationDelivery()
    let feedback = SwitchFeedback(
      notificationsEnabled: { true },
      notifications: notifications,
      status: RecordingSwitchStatus()
    )

    feedback.notificationPreferenceChanged(enabled: true)

    XCTAssertEqual(notifications.authorizationRequests, 1)
  }

  func testVerifiedSuccessClearsFailureAndNotifiesWhenAuthorized() {
    let notifications = RecordingNotificationDelivery()
    notifications.authorization = .authorized
    let status = RecordingSwitchStatus()
    let feedback = SwitchFeedback(
      notificationsEnabled: { true },
      notifications: notifications,
      status: status
    )

    feedback.switchDidSucceed(target: .hiragana, source: .hiragana)

    XCTAssertEqual(status.clearCount, 1)
    XCTAssertEqual(notifications.deliveredTitles, ["Japanese Hiragana"])
  }

  func testDeniedPermissionDoesNotTurnSuccessfulSwitchIntoFailure() {
    let notifications = RecordingNotificationDelivery()
    notifications.authorization = .denied
    let status = RecordingSwitchStatus()
    let feedback = SwitchFeedback(
      notificationsEnabled: { true },
      notifications: notifications,
      status: status
    )

    feedback.switchDidSucceed(target: .abc, source: .abc)

    XCTAssertEqual(status.clearCount, 1)
    XCTAssertEqual(status.failures, [])
    XCTAssertEqual(notifications.deliveredTitles, [])
    XCTAssertEqual(notifications.authorizationRequests, 0)
  }

  func testDisabledNotificationPreferenceSuppressesSuccessNotification() {
    let notifications = RecordingNotificationDelivery()
    notifications.authorization = .authorized
    let status = RecordingSwitchStatus()
    let feedback = SwitchFeedback(
      notificationsEnabled: { false },
      notifications: notifications,
      status: status
    )

    feedback.switchDidSucceed(target: .pinyin, source: .pinyin)

    XCTAssertEqual(status.clearCount, 1)
    XCTAssertEqual(notifications.statusRequests, 0)
    XCTAssertEqual(notifications.deliveredTitles, [])
  }

  func testFailureUpdatesStatusWithoutNotification() {
    let notifications = RecordingNotificationDelivery()
    let status = RecordingSwitchStatus()
    let feedback = SwitchFeedback(
      notificationsEnabled: { true },
      notifications: notifications,
      status: status
    )

    feedback.switchDidFail(target: .pinyin, failure: .unavailable(.pinyin))

    XCTAssertEqual(status.failures, ["Apple Pinyin is not enabled or selectable in System Settings."])
    XCTAssertEqual(notifications.deliveredTitles, [])
  }

  func testTurningPreferenceOffBeforeDelayedAuthorizationStatusSuppressesDelivery() {
    var enabled = true
    let notifications = RecordingNotificationDelivery()
    notifications.authorization = .authorized
    notifications.delaysStatus = true
    let feedback = SwitchFeedback(
      notificationsEnabled: { enabled },
      notifications: notifications,
      status: RecordingSwitchStatus()
    )

    feedback.switchDidSucceed(target: .abc, source: .abc)
    enabled = false
    feedback.notificationPreferenceChanged(enabled: false)
    notifications.completeStatusRequest()

    XCTAssertEqual(notifications.deliveredTitles, [])
  }

  func testNewerFailureInvalidatesOlderSuccessWaitingForAuthorizationStatus() {
    let notifications = RecordingNotificationDelivery()
    notifications.authorization = .authorized
    notifications.delaysStatus = true
    let status = RecordingSwitchStatus()
    let feedback = SwitchFeedback(
      notificationsEnabled: { true },
      notifications: notifications,
      status: status
    )
    feedback.switchDidSucceed(target: .abc, source: .abc)

    feedback.switchDidFail(target: .pinyin, failure: .unavailable(.pinyin))
    notifications.completeStatusRequest()

    XCTAssertEqual(notifications.deliveredTitles, [])
    XCTAssertEqual(status.failures.count, 1)
  }

  func testNewerSuccessInvalidatesOlderSuccessWaitingForAuthorizationStatus() {
    let notifications = RecordingNotificationDelivery()
    notifications.authorization = .authorized
    notifications.delaysStatus = true
    let feedback = SwitchFeedback(
      notificationsEnabled: { true },
      notifications: notifications,
      status: RecordingSwitchStatus()
    )
    feedback.switchDidSucceed(target: .pinyin, source: .pinyin)
    let oldCompletion = notifications.takePendingStatusRequest()

    notifications.delaysStatus = false
    feedback.switchDidSucceed(target: .abc, source: .abc)
    oldCompletion?(.authorized)

    XCTAssertEqual(notifications.deliveredTitles, ["ABC"])
  }

  func testAuthorizationStatusCanBeReadForSettingsWithoutShowingSwitchFailure() {
    let notifications = RecordingNotificationDelivery()
    notifications.authorization = .denied
    let status = RecordingSwitchStatus()
    let feedback = SwitchFeedback(
      notificationsEnabled: { true },
      notifications: notifications,
      status: status
    )
    var observed: SwitchNotificationAuthorization?

    feedback.notificationAuthorizationStatus { observed = $0 }

    XCTAssertEqual(observed, .denied)
    XCTAssertEqual(status.failures, [])
  }

  func testNewerAuthorizationStatusReadSuppressesOlderResult() {
    let notifications = RecordingNotificationDelivery()
    notifications.delaysStatus = true
    let feedback = SwitchFeedback(
      notificationsEnabled: { true },
      notifications: notifications,
      status: RecordingSwitchStatus()
    )
    var observations: [SwitchNotificationAuthorization] = []

    feedback.notificationAuthorizationStatus { observations.append($0) }
    let olderCompletion = notifications.takePendingStatusRequest()
    feedback.notificationAuthorizationStatus { observations.append($0) }
    notifications.authorization = .authorized
    notifications.completeStatusRequest()
    olderCompletion?(.denied)

    XCTAssertEqual(observations.count, 1)
    XCTAssertEqual(observations.first, .authorized)
  }

  func testTurningPreferenceOffSuppressesPendingAuthorizationStatusRead() {
    var enabled = true
    let notifications = RecordingNotificationDelivery()
    notifications.authorization = .denied
    notifications.delaysStatus = true
    let feedback = SwitchFeedback(
      notificationsEnabled: { enabled },
      notifications: notifications,
      status: RecordingSwitchStatus()
    )
    var observations: [SwitchNotificationAuthorization] = []

    feedback.notificationAuthorizationStatus { observations.append($0) }
    enabled = false
    feedback.notificationPreferenceChanged(enabled: false)
    notifications.completeStatusRequest()

    XCTAssertEqual(observations, [])
  }

  func testInvalidationSuppressesSuccessWaitingForAuthorizationStatus() {
    let notifications = RecordingNotificationDelivery()
    notifications.authorization = .authorized
    notifications.delaysStatus = true
    let feedback = SwitchFeedback(
      notificationsEnabled: { true },
      notifications: notifications,
      status: RecordingSwitchStatus()
    )
    feedback.switchDidSucceed(target: .abc, source: .abc)

    feedback.invalidatePendingFeedback()
    notifications.completeStatusRequest()

    XCTAssertEqual(notifications.deliveredTitles, [])
  }
}

private final class RecordingServiceLifecycle: AppServiceLifecycle {
  private let onStart: () -> Void
  private let onStop: () -> Void
  private let onRefresh: () -> Void

  init(
    onStart: @escaping () -> Void = {},
    onStop: @escaping () -> Void = {},
    onRefresh: @escaping () -> Void = {}
  ) {
    self.onStart = onStart
    self.onStop = onStop
    self.onRefresh = onRefresh
  }

  func start() { onStart() }
  func stop() { onStop() }
  func refreshInputSources() { onRefresh() }
}

private final class FakeInputSourceCatalog: InputSourceCataloging {
  var availableTargets: [InputTarget]
  private var onChange: (() -> Void)?
  private(set) var startCount = 0
  private(set) var stopCount = 0

  init(_ targets: [InputTarget]) {
    availableTargets = targets
  }

  func targets() -> [InputTarget] { availableTargets }

  func startObserving(_ onChange: @escaping () -> Void) {
    startCount += 1
    self.onChange = onChange
  }

  func stopObserving() {
    stopCount += 1
    onChange = nil
  }

  func sendChange() {
    onChange?()
  }
}

private final class RecordingSwitchFeedback: SwitchFeedbackReporting {
  private(set) var successes: [(InputTarget, InputSourceInfo)] = []
  private(set) var failures: [(InputTarget, InputSwitchFailure)] = []

  func switchDidSucceed(target: InputTarget, source: InputSourceInfo) {
    successes.append((target, source))
  }

  func switchDidFail(target: InputTarget, failure: InputSwitchFailure) {
    failures.append((target, failure))
  }
}

private final class RecordingSwitchStatus: SwitchStatusDisplaying {
  private(set) var failures: [String] = []
  private(set) var clearCount = 0

  func showSwitchFailure(_ message: String) {
    failures.append(message)
  }

  func clearSwitchFailure() {
    clearCount += 1
  }
}

private final class RecordingNotificationDelivery: SwitchNotificationDelivering {
  var authorization: SwitchNotificationAuthorization = .notDetermined
  var delaysStatus = false
  private var pendingStatus: ((SwitchNotificationAuthorization) -> Void)?
  private(set) var statusRequests = 0
  private(set) var authorizationRequests = 0
  private(set) var deliveredTitles: [String] = []

  func authorizationStatus(_ completion: @escaping (SwitchNotificationAuthorization) -> Void) {
    statusRequests += 1
    if delaysStatus {
      pendingStatus = completion
    } else {
      completion(authorization)
    }
  }

  func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
    authorizationRequests += 1
    completion(authorization == .authorized)
  }

  func deliverSuccess(title: String) {
    deliveredTitles.append(title)
  }

  func completeStatusRequest() {
    let completion = pendingStatus
    pendingStatus = nil
    completion?(authorization)
  }

  func takePendingStatusRequest() -> ((SwitchNotificationAuthorization) -> Void)? {
    let completion = pendingStatus
    pendingStatus = nil
    return completion
  }
}

private final class IntegrationShortcutStore: ShortcutPersisting {
  private var values: [String: ShortcutBinding] = [:]

  init(_ initial: [InputTarget: ShortcutBinding] = [:]) {
    for (target, binding) in initial {
      values[target.storageKey] = binding
    }
  }

  func binding(for target: InputTarget) -> ShortcutBinding? {
    values[target.storageKey]
  }

  func save(_ binding: ShortcutBinding?, for target: InputTarget) {
    values[target.storageKey] = binding
  }
}

private final class IntegrationShortcutRegistrar: ShortcutRegistering {
  private var active: [ShortcutBinding: () -> Void] = [:]
  private var history: [ShortcutBinding: [() -> Void]] = [:]

  var activeBindings: [ShortcutBinding] {
    Array(active.keys)
  }

  func register(_ binding: ShortcutBinding, action: @escaping () -> Void) -> Bool {
    guard active[binding] == nil else { return false }
    active[binding] = action
    history[binding, default: []].append(action)
    return true
  }

  func unregister(_ binding: ShortcutBinding) {
    active.removeValue(forKey: binding)
  }

  func trigger(_ binding: ShortcutBinding) {
    active[binding]?()
  }

  func latestAction(for binding: ShortcutBinding) -> (() -> Void)? {
    history[binding]?.last
  }
}

private final class IntegrationInputSourceAccess: InputSourceAccess {
  var availableSources: [InputSourceInfo]
  var currentSource: InputSourceInfo?
  var selectionRequests: [InputSourceInfo] = []
  var onSelect: (() -> Void)?

  init(sources: [InputSourceInfo], current: InputSourceInfo? = nil) {
    availableSources = sources
    currentSource = current
  }

  func sources() -> [InputSourceInfo] { availableSources }
  func current() -> InputSourceInfo? { currentSource }
  func select(_ source: InputSourceInfo) -> Int32 {
    selectionRequests.append(source)
    onSelect?()
    return 0
  }
}

private final class IntegrationQueuedScheduler {
  private var callbacks: [() -> Void] = []

  func schedule(after delay: TimeInterval, _ callback: @escaping () -> Void) {
    callbacks.append(callback)
  }

  func runNext() {
    XCTAssertFalse(callbacks.isEmpty)
    guard !callbacks.isEmpty else { return }
    callbacks.removeFirst()()
  }
}

private extension InputSourceInfo {
  static let abc = InputSourceInfo(
    id: "com.apple.keylayout.ABC",
    modeID: nil,
    bundleID: nil,
    isEnabled: true,
    isSelectable: true
  )

  static let pinyin = InputSourceInfo(
    id: "com.apple.inputmethod.SCIM.ITABC",
    modeID: "com.apple.inputmethod.SCIM.ITABC",
    bundleID: "com.apple.inputmethod.SCIM",
    isEnabled: true,
    isSelectable: true
  )

  static let hiragana = InputSourceInfo(
    id: "com.apple.inputmethod.Kotoeri.RomajiTyping",
    modeID: "com.apple.inputmethod.Japanese",
    bundleID: "com.apple.JapaneseIM.RomajiTyping",
    isEnabled: true,
    isSelectable: true
  )
}
