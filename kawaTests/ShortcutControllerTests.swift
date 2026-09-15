import AppKit
import XCTest

final class ShortcutControllerTests: XCTestCase {
  private let command = UInt(NSEvent.ModifierFlags.command.rawValue)
  private let option = UInt(NSEvent.ModifierFlags.option.rawValue)

  func testStartRestoresAndTriggersBeforeAnyViewExists() {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let store = FakeShortcutStore([.pinyin: binding])
    let registrar = FakeShortcutRegistrar()
    var triggered: [InputTarget] = []
    let controller = ShortcutController(store: store, registrar: registrar) {
      triggered.append($0)
    }

    controller.start()
    registrar.trigger(binding)

    XCTAssertEqual(registrar.activeBindings, [binding])
    XCTAssertEqual(triggered, [.pinyin])
  }

  func testStartIsIdempotent() {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let registrar = FakeShortcutRegistrar()
    let controller = makeController(store: FakeShortcutStore([.pinyin: binding]), registrar: registrar)

    controller.start()
    controller.start()

    XCTAssertEqual(registrar.registeredBindings, [binding])
  }

  func testStopIsIdempotentAndRemovesOnlyOwnedRegistrations() {
    let first = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let second = ShortcutBinding(keyCode: 19, modifierFlags: option)
    let registrar = FakeShortcutRegistrar()
    let controller = makeController(
      store: FakeShortcutStore([.pinyin: first, .abc: second]),
      registrar: registrar
    )

    controller.start()
    controller.stop()
    controller.stop()

    XCTAssertEqual(Set(registrar.unregisteredBindings), Set([first, second]))
    XCTAssertEqual(registrar.unregisteredBindings.count, 2)
    XCTAssertEqual(registrar.activeBindings, [])
  }

  func testDuplicatePersistedBindingRegistersFirstTargetAndReportsOtherTarget() {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let store = FakeShortcutStore([.pinyin: binding, .hiragana: binding])
    let registrar = FakeShortcutRegistrar()
    let controller = makeController(store: store, registrar: registrar)

    controller.start()

    XCTAssertEqual(registrar.registeredBindings, [binding])
    XCTAssertEqual(controller.binding(for: .pinyin), binding)
    XCTAssertEqual(controller.binding(for: .hiragana), binding)
    XCTAssertEqual(controller.error(for: .hiragana), .duplicate(.pinyin))
  }

  func testSuccessfulEditRegistersNewBeforeUnregisteringOldAndThenSaves() {
    let old = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let new = ShortcutBinding(keyCode: 19, modifierFlags: command)
    let store = FakeShortcutStore([.pinyin: old])
    let registrar = FakeShortcutRegistrar()
    let controller = makeController(store: store, registrar: registrar)
    controller.start()
    registrar.resetOperations()

    let result = controller.setBinding(new, for: .pinyin)

    assertSuccess(result)
    XCTAssertEqual(registrar.operations, [.register(new), .unregister(old)])
    XCTAssertEqual(store.savedValues.last?.target, .pinyin)
    XCTAssertEqual(store.savedValues.last?.binding, new)
    XCTAssertEqual(controller.binding(for: .pinyin), new)
  }

  func testClearUnregistersOnlyTargetAndPersistsTombstone() {
    let first = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let second = ShortcutBinding(keyCode: 19, modifierFlags: option)
    let store = FakeShortcutStore([.pinyin: first, .abc: second])
    let registrar = FakeShortcutRegistrar()
    let controller = makeController(store: store, registrar: registrar)
    controller.start()
    registrar.resetOperations()

    let result = controller.setBinding(nil, for: .pinyin)

    assertSuccess(result)
    XCTAssertEqual(registrar.operations, [.unregister(first)])
    XCTAssertEqual(registrar.activeBindings, [second])
    XCTAssertNil(store.savedValues.last?.binding)
    XCTAssertNil(controller.binding(for: .pinyin))
  }

  func testDuplicateEditLeavesExistingRegistrationAndStoredValueAlone() {
    let first = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let second = ShortcutBinding(keyCode: 19, modifierFlags: option)
    let store = FakeShortcutStore([.pinyin: first, .abc: second])
    let registrar = FakeShortcutRegistrar()
    let controller = makeController(store: store, registrar: registrar)
    controller.start()
    registrar.resetOperations()

    let result = controller.setBinding(second, for: .pinyin)

    assertFailure(result, equals: .duplicate(.abc))
    XCTAssertEqual(registrar.operations, [])
    XCTAssertEqual(store.savedValues.count, 0)
    XCTAssertEqual(controller.binding(for: .pinyin), first)
  }

  func testRegistrationFailurePreservesWorkingAndStoredBinding() {
    let old = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let new = ShortcutBinding(keyCode: 19, modifierFlags: command)
    let store = FakeShortcutStore([.pinyin: old])
    let registrar = FakeShortcutRegistrar()
    let controller = makeController(store: store, registrar: registrar)
    controller.start()
    registrar.failures.insert(new)
    registrar.resetOperations()

    let result = controller.setBinding(new, for: .pinyin)

    assertFailure(result, equals: .registrationFailed)
    XCTAssertEqual(registrar.operations, [.register(new)])
    XCTAssertEqual(registrar.activeBindings, [old])
    XCTAssertEqual(store.savedValues.count, 0)
    XCTAssertEqual(controller.binding(for: .pinyin), old)
    XCTAssertEqual(controller.error(for: .pinyin), .registrationFailed)
  }

  func testClearingWinnerRecoversPreviouslyFailedDuplicateBinding() {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let store = FakeShortcutStore([.pinyin: binding, .hiragana: binding])
    let registrar = FakeShortcutRegistrar()
    var triggered: [InputTarget] = []
    let controller = ShortcutController(store: store, registrar: registrar) {
      triggered.append($0)
    }
    controller.start()
    registrar.resetOperations()

    _ = controller.setBinding(nil, for: .pinyin)
    registrar.trigger(binding)

    XCTAssertEqual(registrar.operations, [.unregister(binding), .register(binding)])
    XCTAssertNil(controller.error(for: .hiragana))
    XCTAssertEqual(triggered, [.hiragana])
  }

  func testReplacingBindingSilencesQueuedActionForOldRegistration() {
    let old = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let new = ShortcutBinding(keyCode: 19, modifierFlags: command)
    let registrar = FakeShortcutRegistrar()
    var triggered: [InputTarget] = []
    let controller = ShortcutController(
      store: FakeShortcutStore([.pinyin: old]),
      registrar: registrar,
      onTrigger: { triggered.append($0) }
    )
    controller.start()
    let oldAction = registrar.latestAction(for: old)

    _ = controller.setBinding(new, for: .pinyin)
    oldAction?()
    registrar.trigger(new)

    XCTAssertEqual(triggered, [.pinyin])
  }

  func testClearingBindingSilencesQueuedAction() {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let registrar = FakeShortcutRegistrar()
    var triggered: [InputTarget] = []
    let controller = ShortcutController(
      store: FakeShortcutStore([.pinyin: binding]),
      registrar: registrar,
      onTrigger: { triggered.append($0) }
    )
    controller.start()
    let action = registrar.latestAction(for: binding)

    _ = controller.setBinding(nil, for: .pinyin)
    action?()

    XCTAssertEqual(triggered, [])
  }

  func testStopThenRestartSilencesActionFromPreviousRegistration() {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let registrar = FakeShortcutRegistrar()
    var triggered: [InputTarget] = []
    let controller = ShortcutController(
      store: FakeShortcutStore([.pinyin: binding]),
      registrar: registrar,
      onTrigger: { triggered.append($0) }
    )
    controller.start()
    let oldAction = registrar.latestAction(for: binding)

    controller.stop()
    controller.start()
    oldAction?()
    registrar.trigger(binding)

    XCTAssertEqual(triggered, [.pinyin])
  }

  func testInvalidBindingsNeverReachRegistrarOrPersistence() {
    let registrar = FakeShortcutRegistrar()
    let store = FakeShortcutStore()
    let controller = makeController(store: store, registrar: registrar)
    controller.start()
    let unsupported = UInt(NSEvent.ModifierFlags.function.rawValue)
    let invalid: [(ShortcutBinding, ShortcutControllerError)] = [
      (ShortcutBinding(keyCode: -1, modifierFlags: command), .invalidKeyCode(-1)),
      (ShortcutBinding(keyCode: 128, modifierFlags: command), .invalidKeyCode(128)),
      (ShortcutBinding(keyCode: 18, modifierFlags: unsupported), .unsupportedModifierFlags(unsupported)),
      (ShortcutBinding(keyCode: 0, modifierFlags: 0), .unsafeWithoutModifier)
    ]

    for (binding, expectedError) in invalid {
      assertFailure(controller.setBinding(binding, for: .pinyin), equals: expectedError)
    }

    XCTAssertEqual(registrar.registeredBindings, [])
    XCTAssertEqual(store.savedValues.count, 0)
  }

  func testBareFunctionKeyIsAllowed() {
    let f1 = ShortcutBinding(keyCode: 122, modifierFlags: 0)
    let registrar = FakeShortcutRegistrar()
    let store = FakeShortcutStore()
    let controller = makeController(store: store, registrar: registrar)
    controller.start()

    assertSuccess(controller.setBinding(f1, for: .abc))
    XCTAssertEqual(registrar.activeBindings, [f1])
  }

  func testChangeAndErrorCallbacksExposeUIIntegrationEvents() {
    let first = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let store = FakeShortcutStore([.pinyin: first])
    let registrar = FakeShortcutRegistrar()
    let controller = makeController(store: store, registrar: registrar)
    var changes: [(InputTarget, ShortcutBinding?)] = []
    var errors: [(InputTarget, ShortcutControllerError)] = []
    controller.onChange = { changes.append(($0, $1)) }
    controller.onError = { errors.append(($0, $1)) }
    controller.start()

    _ = controller.setBinding(first, for: .abc)
    _ = controller.setBinding(nil, for: .pinyin)

    XCTAssertEqual(changes.count, 1)
    XCTAssertEqual(changes.first?.0, .pinyin)
    XCTAssertNil(changes.first?.1)
    XCTAssertEqual(errors.count, 1)
    XCTAssertEqual(errors.first?.0, .abc)
    XCTAssertEqual(errors.first?.1, .duplicate(.pinyin))
  }

  func testEditWhileStoppedDoesNotRegisterOrPersist() {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let store = FakeShortcutStore()
    let registrar = FakeShortcutRegistrar()
    let controller = makeController(store: store, registrar: registrar)

    assertFailure(controller.setBinding(binding, for: .pinyin), equals: .notStarted)

    XCTAssertEqual(registrar.activeBindings, [])
    XCTAssertEqual(store.savedValues.count, 0)
  }

  func testClearingFirstOfThreePersistedDuplicatesRecoversNextDeterministically() {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let store = FakeShortcutStore([.pinyin: binding, .hiragana: binding, .abc: binding])
    let registrar = FakeShortcutRegistrar()
    var triggered: [InputTarget] = []
    let controller = ShortcutController(store: store, registrar: registrar) {
      triggered.append($0)
    }
    controller.start()
    registrar.resetOperations()

    _ = controller.setBinding(nil, for: .pinyin)
    registrar.trigger(binding)

    XCTAssertEqual(registrar.operations, [.unregister(binding), .register(binding)])
    XCTAssertNil(controller.error(for: .hiragana))
    XCTAssertEqual(controller.error(for: .abc), .duplicate(.hiragana))
    XCTAssertEqual(triggered, [.hiragana])
  }

  func testErrorCallbackObservesCommittedErrorState() {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let registrar = FakeShortcutRegistrar()
    registrar.failures.insert(binding)
    var controller: ShortcutController!
    controller = ShortcutController(
      store: FakeShortcutStore([.pinyin: binding]),
      registrar: registrar,
      onTrigger: { _ in }
    )
    var observed: ShortcutControllerError?
    controller.onError = { target, _ in
      observed = controller.error(for: target)
    }

    controller.start()

    XCTAssertEqual(observed, .registrationFailed)
  }

  func testSuccessfulRecoveryEmitsChangeAfterClearingError() {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let store = FakeShortcutStore([.pinyin: binding, .hiragana: binding])
    let registrar = FakeShortcutRegistrar()
    let controller = makeController(store: store, registrar: registrar)
    var recoveredError: ShortcutControllerError?
    var recoveredBinding: ShortcutBinding?
    controller.start()
    controller.onChange = { target, value in
      guard target == .hiragana else { return }
      recoveredError = controller.error(for: target)
      recoveredBinding = value
    }

    _ = controller.setBinding(nil, for: .pinyin)

    XCTAssertNil(recoveredError)
    XCTAssertEqual(recoveredBinding, binding)
  }

  func testReapplyingWorkingBindingClearsEarlierEditErrorAndEmitsChange() {
    let binding = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let registrar = FakeShortcutRegistrar()
    let controller = makeController(
      store: FakeShortcutStore([.pinyin: binding]),
      registrar: registrar
    )
    controller.start()
    _ = controller.setBinding(ShortcutBinding(keyCode: -1, modifierFlags: command), for: .pinyin)
    var changedBinding: ShortcutBinding?
    controller.onChange = { target, value in
      guard target == .pinyin else { return }
      changedBinding = value
    }

    assertSuccess(controller.setBinding(binding, for: .pinyin))

    XCTAssertNil(controller.error(for: .pinyin))
    XCTAssertEqual(changedBinding, binding)
    XCTAssertEqual(registrar.registeredBindings, [binding])
  }

  func testStoppingFromStartupErrorCallbackPreventsLaterRegistration() {
    let failed = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let later = ShortcutBinding(keyCode: 19, modifierFlags: command)
    let registrar = FakeShortcutRegistrar()
    registrar.failures.insert(failed)
    var controller: ShortcutController!
    controller = ShortcutController(
      store: FakeShortcutStore([.pinyin: failed, .abc: later]),
      registrar: registrar,
      onTrigger: { _ in }
    )
    controller.onError = { _, _ in controller.stop() }

    controller.start()

    XCTAssertEqual(registrar.registeredBindings, [failed])
    XCTAssertEqual(registrar.activeBindings, [])
  }

  func testRestartingFromStartupErrorCallbackCannotLoseNewRegistrations() {
    let failed = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let later = ShortcutBinding(keyCode: 19, modifierFlags: command)
    let registrar = FakeShortcutRegistrar()
    registrar.failures.insert(failed)
    var restarted = false
    var controller: ShortcutController!
    controller = ShortcutController(
      store: FakeShortcutStore([.pinyin: failed, .abc: later]),
      registrar: registrar,
      onTrigger: { _ in }
    )
    controller.onError = { _, _ in
      guard !restarted else { return }
      restarted = true
      registrar.failures.remove(failed)
      controller.stop()
      controller.start()
    }

    controller.start()
    controller.stop()

    XCTAssertEqual(registrar.activeBindings, [])
  }

  func testStoppingFromRecoveryChangeCallbackPreventsLaterRetryRegistration() {
    let failed = ShortcutBinding(keyCode: 18, modifierFlags: command)
    let cleared = ShortcutBinding(keyCode: 19, modifierFlags: command)
    let later = ShortcutBinding(keyCode: 20, modifierFlags: command)
    let registrar = FakeShortcutRegistrar()
    registrar.failures.insert(failed)
    var controller: ShortcutController!
    controller = ShortcutController(
      store: FakeShortcutStore([.pinyin: failed, .hiragana: cleared, .abc: later]),
      registrar: registrar,
      onTrigger: { _ in }
    )
    controller.start()
    registrar.failures.remove(failed)
    controller.onChange = { target, _ in
      if target == .pinyin {
        controller.stop()
      }
    }

    _ = controller.setBinding(nil, for: .hiragana)

    XCTAssertEqual(registrar.activeBindings, [])
  }

  private func makeController(
    store: FakeShortcutStore,
    registrar: FakeShortcutRegistrar
  ) -> ShortcutController {
    ShortcutController(store: store, registrar: registrar, onTrigger: { _ in })
  }

  private func assertSuccess(
    _ result: Result<Void, ShortcutControllerError>,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    if case .failure(let error) = result {
      XCTFail("Expected success, got \(error)", file: file, line: line)
    }
  }

  private func assertFailure(
    _ result: Result<Void, ShortcutControllerError>,
    equals expected: ShortcutControllerError,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    switch result {
    case .success:
      XCTFail("Expected failure \(expected), got success", file: file, line: line)
    case .failure(let error):
      XCTAssertEqual(error, expected, file: file, line: line)
    }
  }
}

private final class FakeShortcutStore: ShortcutPersisting {
  struct SavedValue {
    let target: InputTarget
    let binding: ShortcutBinding?
  }

  private var values: [String: ShortcutBinding] = [:]
  private(set) var savedValues: [SavedValue] = []

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
    savedValues.append(SavedValue(target: target, binding: binding))
  }
}

private final class FakeShortcutRegistrar: ShortcutRegistering {
  enum Operation: Equatable {
    case register(ShortcutBinding)
    case unregister(ShortcutBinding)
  }

  var failures: Set<ShortcutBinding> = []
  private(set) var operations: [Operation] = []
  private(set) var registeredBindings: [ShortcutBinding] = []
  private(set) var unregisteredBindings: [ShortcutBinding] = []
  private var activeActions: [ShortcutBinding: () -> Void] = [:]
  private var allActions: [ShortcutBinding: [() -> Void]] = [:]

  var activeBindings: [ShortcutBinding] {
    Array(activeActions.keys)
  }

  func register(_ binding: ShortcutBinding, action: @escaping () -> Void) -> Bool {
    operations.append(.register(binding))
    registeredBindings.append(binding)
    guard !failures.contains(binding), activeActions[binding] == nil else { return false }
    activeActions[binding] = action
    allActions[binding, default: []].append(action)
    return true
  }

  func unregister(_ binding: ShortcutBinding) {
    operations.append(.unregister(binding))
    unregisteredBindings.append(binding)
    activeActions.removeValue(forKey: binding)
  }

  func trigger(_ binding: ShortcutBinding) {
    activeActions[binding]?()
  }

  func latestAction(for binding: ShortcutBinding) -> (() -> Void)? {
    allActions[binding]?.last
  }

  func resetOperations() {
    operations.removeAll()
  }
}
