import Foundation

struct ShortcutBinding: Equatable, Hashable {
  let keyCode: Int
  let modifierFlags: UInt

  static let supportedModifierFlags: UInt =
    (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20)

  var normalized: ShortcutBinding {
    ShortcutBinding(
      keyCode: keyCode,
      modifierFlags: modifierFlags & Self.supportedModifierFlags
    )
  }

  var validationError: ShortcutControllerError? {
    guard (0...127).contains(keyCode) else {
      return .invalidKeyCode(keyCode)
    }

    let unsupported = modifierFlags & ~Self.supportedModifierFlags
    guard unsupported == 0 else {
      return .unsupportedModifierFlags(unsupported)
    }

    let hasSafeModifiers = modifierFlags != 0 && modifierFlags != Self.shiftModifierFlag
    guard hasSafeModifiers || Self.functionKeyCodes.contains(keyCode) else {
      return .unsafeWithoutModifier
    }

    return nil
  }

  private static let functionKeyCodes: Set<Int> = [
    122, 120, 99, 118, 96, 97, 98, 100, 101, 109,
    103, 111, 105, 107, 113, 106, 64, 79, 80, 90
  ]
  private static let shiftModifierFlag: UInt = 1 << 17
}

protocol ShortcutRegistering {
  func register(_ binding: ShortcutBinding, action: @escaping () -> Void) -> Bool
  func unregister(_ binding: ShortcutBinding)
}

protocol ShortcutPersisting {
  func binding(for target: InputTarget) -> ShortcutBinding?
  func save(_ binding: ShortcutBinding?, for target: InputTarget)
}

enum ShortcutControllerError: Error, Equatable {
  case notStarted
  case invalidKeyCode(Int)
  case unsupportedModifierFlags(UInt)
  case unsafeWithoutModifier
  case duplicate(InputTarget)
  case registrationFailed
}

extension ShortcutControllerError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .notStarted:
      return "Shortcut services are not running."
    case .invalidKeyCode(let keyCode):
      return "The shortcut has an invalid key code (\(keyCode))."
    case .unsupportedModifierFlags:
      return "The shortcut contains unsupported modifier keys."
    case .unsafeWithoutModifier:
      return "Use a modifier key with ordinary keyboard keys."
    case .duplicate(let target):
      return "This shortcut is already assigned to \(target.title)."
    case .registrationFailed:
      return "macOS could not register this global shortcut."
    }
  }
}

final class ShortcutController {
  var onChange: ((InputTarget, ShortcutBinding?) -> Void)?
  var onError: ((InputTarget, ShortcutControllerError) -> Void)?

  private struct TargetState {
    var desired: ShortcutBinding?
    var registered: ShortcutBinding?
    var actionToken: UInt?
    var error: ShortcutControllerError?
  }

  private let store: ShortcutPersisting
  private let registrar: ShortcutRegistering
  private let onTrigger: (InputTarget) -> Void
  private var states: [String: TargetState] = [:]
  private var started = false
  private var lifecycleGeneration: UInt = 0
  private var nextActionToken: UInt = 0

  init(
    store: ShortcutPersisting,
    registrar: ShortcutRegistering,
    onTrigger: @escaping (InputTarget) -> Void
  ) {
    self.store = store
    self.registrar = registrar
    self.onTrigger = onTrigger
  }

  func start() {
    guard !started else { return }
    started = true
    lifecycleGeneration &+= 1
    let startGeneration = lifecycleGeneration
    states.removeAll()

    for target in InputTarget.allCases {
      states[target.storageKey] = TargetState(
        desired: store.binding(for: target),
        registered: nil,
        actionToken: nil,
        error: nil
      )
    }

    for target in InputTarget.allCases {
      guard isCurrentLifecycle(startGeneration) else { return }
      attemptRestoredRegistration(for: target)
    }
  }

  func stop() {
    guard started else { return }
    started = false
    lifecycleGeneration &+= 1

    for target in InputTarget.allCases {
      guard var state = states[target.storageKey] else { continue }
      state.actionToken = nil
      states[target.storageKey] = state
      if let binding = state.registered {
        registrar.unregister(binding)
        state.registered = nil
        states[target.storageKey] = state
      }
    }
  }

  func binding(for target: InputTarget) -> ShortcutBinding? {
    states[target.storageKey]?.desired
  }

  func error(for target: InputTarget) -> ShortcutControllerError? {
    states[target.storageKey]?.error
  }

  @discardableResult
  func setBinding(
    _ binding: ShortcutBinding?,
    for target: InputTarget
  ) -> Result<Void, ShortcutControllerError> {
    guard started else {
      report(.notStarted, for: target)
      return .failure(.notStarted)
    }

    let operationGeneration = lifecycleGeneration

    if let binding = binding {
      return assign(binding, to: target, generation: operationGeneration)
    }

    clear(target, generation: operationGeneration)
    return .success(())
  }

  private func assign(
    _ binding: ShortcutBinding,
    to target: InputTarget,
    generation operationGeneration: UInt
  ) -> Result<Void, ShortcutControllerError> {
    if let validationError = binding.validationError {
      report(validationError, for: target)
      return .failure(validationError)
    }

    if let conflictingTarget = conflictingTarget(for: binding, excluding: target) {
      let duplicateError = ShortcutControllerError.duplicate(conflictingTarget)
      report(duplicateError, for: target)
      return .failure(duplicateError)
    }

    let oldState = state(for: target)
    if oldState.desired?.normalized == binding.normalized,
       oldState.registered?.normalized == binding.normalized {
      let wasInError = oldState.error != nil
      clearError(for: target)
      if wasInError {
        onChange?(target, binding.normalized)
      }
      return .success(())
    }

    let token = makeActionToken()
    guard registrar.register(binding, action: action(for: target, token: token)) else {
      report(.registrationFailed, for: target)
      return .failure(.registrationFailed)
    }

    var newState = oldState
    newState.desired = binding.normalized
    newState.registered = binding.normalized
    newState.actionToken = token
    newState.error = nil
    states[target.storageKey] = newState

    if let oldBinding = oldState.registered {
      registrar.unregister(oldBinding)
    }

    store.save(binding.normalized, for: target)
    onChange?(target, binding.normalized)
    if isCurrentLifecycle(operationGeneration) {
      retryUnregisteredBindings(excluding: target)
    }
    return .success(())
  }

  private func clear(_ target: InputTarget, generation operationGeneration: UInt) {
    var oldState = state(for: target)
    oldState.actionToken = nil
    states[target.storageKey] = oldState

    if let binding = oldState.registered {
      registrar.unregister(binding)
    }

    states[target.storageKey] = TargetState(
      desired: nil,
      registered: nil,
      actionToken: nil,
      error: nil
    )
    store.save(nil, for: target)
    onChange?(target, nil)
    if isCurrentLifecycle(operationGeneration) {
      retryUnregisteredBindings(excluding: target)
    }
  }

  private func attemptRestoredRegistration(for target: InputTarget) {
    var current = state(for: target)
    guard current.registered == nil else { return }
    guard let binding = current.desired else { return }

    if let validationError = binding.validationError {
      current.error = validationError
      states[target.storageKey] = current
      onError?(target, validationError)
      return
    }

    if let conflictingTarget = earlierConflictingTarget(for: binding, target: target) {
      let duplicateError = ShortcutControllerError.duplicate(conflictingTarget)
      current.error = duplicateError
      states[target.storageKey] = current
      onError?(target, duplicateError)
      return
    }

    registerRestored(binding, for: target)
  }

  private func registerRestored(_ binding: ShortcutBinding, for target: InputTarget) {
    let token = makeActionToken()
    var current = state(for: target)
    let wasInError = current.error != nil
    if registrar.register(binding, action: action(for: target, token: token)) {
      current.registered = binding.normalized
      current.actionToken = token
      current.error = nil
      states[target.storageKey] = current
      if wasInError {
        onChange?(target, binding.normalized)
      }
    } else {
      current.registered = nil
      current.actionToken = nil
      current.error = .registrationFailed
      states[target.storageKey] = current
      onError?(target, .registrationFailed)
    }
  }

  private func retryUnregisteredBindings(excluding excludedTarget: InputTarget) {
    guard started else { return }
    let retryGeneration = lifecycleGeneration

    for target in InputTarget.allCases where target != excludedTarget {
      guard isCurrentLifecycle(retryGeneration) else { return }
      let current = state(for: target)
      guard current.registered == nil, let binding = current.desired else { continue }
      guard binding.validationError == nil else { continue }

      if let conflictingTarget = earlierConflictingTarget(for: binding, target: target) {
        report(.duplicate(conflictingTarget), for: target)
      } else {
        registerRestored(binding, for: target)
      }
    }
  }

  private func conflictingTarget(
    for binding: ShortcutBinding,
    excluding excludedTarget: InputTarget
  ) -> InputTarget? {
    InputTarget.allCases.first { target in
      target != excludedTarget && state(for: target).desired?.normalized == binding.normalized
    }
  }

  private func earlierConflictingTarget(
    for binding: ShortcutBinding,
    target: InputTarget
  ) -> InputTarget? {
    for candidate in InputTarget.allCases {
      if candidate == target { return nil }
      if state(for: candidate).desired?.normalized == binding.normalized {
        return candidate
      }
    }
    return nil
  }

  private func action(for target: InputTarget, token: UInt) -> () -> Void {
    { [weak self] in
      guard let self = self,
            self.started,
            self.state(for: target).actionToken == token else { return }
      self.onTrigger(target)
    }
  }

  private func makeActionToken() -> UInt {
    nextActionToken &+= 1
    return nextActionToken
  }

  private func state(for target: InputTarget) -> TargetState {
    states[target.storageKey] ?? TargetState(
      desired: nil,
      registered: nil,
      actionToken: nil,
      error: nil
    )
  }

  private func report(_ error: ShortcutControllerError, for target: InputTarget) {
    var current = state(for: target)
    current.error = error
    states[target.storageKey] = current
    onError?(target, error)
  }

  private func clearError(for target: InputTarget) {
    var current = state(for: target)
    current.error = nil
    states[target.storageKey] = current
  }

  private func isCurrentLifecycle(_ generation: UInt) -> Bool {
    started && lifecycleGeneration == generation
  }
}
