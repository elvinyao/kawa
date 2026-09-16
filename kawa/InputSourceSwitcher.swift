import Foundation

enum InputSwitchFailure: Error, Equatable {
  case unavailable(InputTarget)
  case osStatus(Int32)
  case unconfirmed(InputTarget)
}

extension InputSwitchFailure: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .unavailable(let target):
      return "\(target.title) is not enabled or selectable in System Settings."
    case .osStatus(let status):
      return "macOS could not select the input source (OSStatus \(status))."
    case .unconfirmed(let target):
      return "macOS did not confirm the switch to \(target.title)."
    }
  }
}

final class InputSourceSwitcher {
  typealias Schedule = (_ delay: TimeInterval, _ callback: @escaping () -> Void) -> Void

  private let access: InputSourceAccess
  private let schedule: Schedule
  private var generation: UInt = 0

  init(
    access: InputSourceAccess,
    schedule: @escaping Schedule = { delay, callback in
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: callback)
    }
  ) {
    self.access = access
    self.schedule = schedule
  }

  func invalidate() {
    generation &+= 1
  }

  func switchTo(
    _ target: InputTarget,
    completion: @escaping (Result<InputSourceInfo, InputSwitchFailure>) -> Void
  ) {
    generation += 1
    let requestGeneration = generation

    guard let source = access.sources().first(where: target.matches) else {
      finish(.failure(.unavailable(target)), generation: requestGeneration, completion: completion)
      return
    }

    if let current = access.current(), target.matches(current) {
      finish(.success(current), generation: requestGeneration, completion: completion)
      return
    }

    let status = access.select(source)
    guard status == 0 else {
      finish(.failure(.osStatus(status)), generation: requestGeneration, completion: completion)
      return
    }

    if let current = access.current(), target.matches(current) {
      finish(.success(current), generation: requestGeneration, completion: completion)
      return
    }

    scheduleVerification(
      target,
      generation: requestGeneration,
      delayedCheck: 1,
      completion: completion
    )
  }

  private func scheduleVerification(
    _ target: InputTarget,
    generation requestGeneration: UInt,
    delayedCheck: Int,
    completion: @escaping (Result<InputSourceInfo, InputSwitchFailure>) -> Void
  ) {
    schedule(0.05) { [weak self] in
      guard let self = self, self.generation == requestGeneration else { return }

      if let current = self.access.current(), target.matches(current) {
        self.finish(.success(current), generation: requestGeneration, completion: completion)
      } else if delayedCheck == 20 {
        self.finish(
          .failure(.unconfirmed(target)),
          generation: requestGeneration,
          completion: completion
        )
      } else {
        self.scheduleVerification(
          target,
          generation: requestGeneration,
          delayedCheck: delayedCheck + 1,
          completion: completion
        )
      }
    }
  }

  private func finish(
    _ result: Result<InputSourceInfo, InputSwitchFailure>,
    generation requestGeneration: UInt,
    completion: (Result<InputSourceInfo, InputSwitchFailure>) -> Void
  ) {
    guard generation == requestGeneration else { return }
    completion(result)
  }
}
