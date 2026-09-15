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

  func testSwitchFailureNeverProducesSuccessFeedback() {
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
    XCTAssertEqual(feedback.failures.map(\.0), [.pinyin])
    XCTAssertEqual(feedback.failures.map(\.1), [.unavailable(.pinyin)])
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
    XCTAssertEqual(events, ["read-first-launch", "start", "mark-complete"])

    coordinator.applicationDidBecomeActive()
    XCTAssertEqual(events, [
      "read-first-launch", "start", "mark-complete", "show-preferences"
    ])
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

  func testLaterApplicationActivationReopensPreferences() {
    var showCount = 0
    let coordinator = AppLaunchCoordinator(
      services: RecordingServiceLifecycle(),
      isFirstLaunch: { false },
      markFirstLaunchComplete: {},
      showPreferences: { showCount += 1 }
    )
    coordinator.applicationDidFinishLaunching()
    coordinator.applicationDidBecomeActive()

    coordinator.applicationDidBecomeActive()

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

  init(onStart: @escaping () -> Void = {}, onStop: @escaping () -> Void = {}) {
    self.onStart = onStart
    self.onStop = onStop
  }

  func start() { onStart() }
  func stop() { onStop() }
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
