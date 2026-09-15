import Foundation
import UserNotifications

enum SwitchNotificationAuthorization {
  case notDetermined
  case denied
  case authorized
}

protocol SwitchNotificationDelivering: AnyObject {
  func authorizationStatus(_ completion: @escaping (SwitchNotificationAuthorization) -> Void)
  func requestAuthorization(_ completion: @escaping (Bool) -> Void)
  func deliverSuccess(title: String)
}

protocol SwitchStatusDisplaying: AnyObject {
  func showSwitchFailure(_ message: String)
  func clearSwitchFailure()
}

final class SwitchFeedback: SwitchFeedbackReporting {
  static var shared: SwitchFeedback?

  private let notificationsEnabled: () -> Bool
  private let notifications: SwitchNotificationDelivering
  private let status: SwitchStatusDisplaying
  private var generation: UInt = 0
  private var authorizationStatusGeneration: UInt = 0

  init(
    notificationsEnabled: @escaping () -> Bool,
    notifications: SwitchNotificationDelivering,
    status: SwitchStatusDisplaying
  ) {
    self.notificationsEnabled = notificationsEnabled
    self.notifications = notifications
    self.status = status
  }

  func notificationPreferenceChanged(
    enabled: Bool,
    completion: ((SwitchNotificationAuthorization) -> Void)? = nil
  ) {
    generation &+= 1
    authorizationStatusGeneration &+= 1
    let requestGeneration = authorizationStatusGeneration
    guard enabled else {
      completion?(.notDetermined)
      return
    }
    notifications.requestAuthorization { [weak self] granted in
      guard let self = self,
            self.authorizationStatusGeneration == requestGeneration,
            self.notificationsEnabled() else { return }
      completion?(granted ? .authorized : .denied)
    }
  }

  func notificationAuthorizationStatus(
    _ completion: @escaping (SwitchNotificationAuthorization) -> Void
  ) {
    authorizationStatusGeneration &+= 1
    let requestGeneration = authorizationStatusGeneration
    guard notificationsEnabled() else { return }
    notifications.authorizationStatus { [weak self] authorization in
      guard let self = self,
            self.authorizationStatusGeneration == requestGeneration,
            self.notificationsEnabled() else { return }
      completion(authorization)
    }
  }

  func invalidatePendingFeedback() {
    generation &+= 1
  }

  func switchDidSucceed(target: InputTarget, source: InputSourceInfo) {
    generation &+= 1
    let requestGeneration = generation
    status.clearSwitchFailure()
    guard notificationsEnabled() else { return }

    notifications.authorizationStatus { [weak self] authorization in
      guard let self = self,
            self.generation == requestGeneration,
            self.notificationsEnabled(),
            authorization == .authorized else { return }
      self.notifications.deliverSuccess(title: target.title)
    }
  }

  func switchDidFail(target: InputTarget, failure: InputSwitchFailure) {
    generation &+= 1
    status.showSwitchFailure(failure.errorDescription ?? "Input source switching failed.")
  }
}

final class UserNotificationDelivery: SwitchNotificationDelivering {
  private let center: UNUserNotificationCenter

  init(center: UNUserNotificationCenter = .current()) {
    self.center = center
  }

  func authorizationStatus(_ completion: @escaping (SwitchNotificationAuthorization) -> Void) {
    center.getNotificationSettings { settings in
      let authorization: SwitchNotificationAuthorization
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral:
        authorization = .authorized
      case .denied:
        authorization = .denied
      case .notDetermined:
        authorization = .notDetermined
      @unknown default:
        authorization = .denied
      }
      DispatchQueue.main.async {
        completion(authorization)
      }
    }
  }

  func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
    center.requestAuthorization(options: [.alert]) { granted, _ in
      DispatchQueue.main.async {
        completion(granted)
      }
    }
  }

  func deliverSuccess(title: String) {
    let content = UNMutableNotificationContent()
    content.title = "Kawa"
    content.body = title
    center.add(UNNotificationRequest(identifier: "input-source", content: content, trigger: nil))
  }
}
