import Carbon
import Foundation

protocol InputSourceCataloging: AnyObject {
  func targets() -> [InputTarget]
  func startObserving(_ onChange: @escaping () -> Void)
  func stopObserving()
}

final class SystemInputSourceCatalog: InputSourceCataloging {
  private let access: InputSourceAccess
  private let notificationCenter: DistributedNotificationCenter
  private var observer: NSObjectProtocol?

  init(
    access: InputSourceAccess,
    notificationCenter: DistributedNotificationCenter = .default()
  ) {
    self.access = access
    self.notificationCenter = notificationCenter
  }

  func targets() -> [InputTarget] {
    InputSourceCatalog.targets(from: access.sources())
  }

  func startObserving(_ onChange: @escaping () -> Void) {
    stopObserving()
    observer = notificationCenter.addObserver(
      forName: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
      object: nil,
      queue: .main
    ) { _ in
      onChange()
    }
  }

  func stopObserving() {
    guard let observer = observer else { return }
    notificationCenter.removeObserver(observer)
    self.observer = nil
  }

  deinit {
    stopObserving()
  }
}

final class CarbonInputSourceAccess: InputSourceAccess {
  func sources() -> [InputSourceInfo] {
    rawSources().compactMap(makeInfo)
  }

  func current() -> InputSourceInfo? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
      return nil
    }
    return makeInfo(source)
  }

  func select(_ source: InputSourceInfo) -> Int32 {
    guard let resolved = rawSources().first(where: {
      guard let info = makeInfo($0) else { return false }
      return info.id == source.id
        && info.modeID == source.modeID
        && info.isEnabled
        && info.isSelectable
    }) else {
      return Int32(paramErr)
    }

    return TISSelectInputSource(resolved)
  }

  private func rawSources() -> [TISInputSource] {
    guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as NSArray? else {
      return []
    }
    return list as? [TISInputSource] ?? []
  }

  private func makeInfo(_ source: TISInputSource) -> InputSourceInfo? {
    guard let id: String = property(source, key: kTISPropertyInputSourceID) else {
      return nil
    }

    return InputSourceInfo(
      id: id,
      modeID: property(source, key: kTISPropertyInputModeID),
      bundleID: property(source, key: kTISPropertyBundleID),
      isEnabled: property(source, key: kTISPropertyInputSourceIsEnabled) ?? false,
      isSelectable: property(source, key: kTISPropertyInputSourceIsSelectCapable) ?? false,
      isKeyboard: (property(source, key: kTISPropertyInputSourceCategory) as String?)
        == (kTISCategoryKeyboardInputSource as String),
      localizedName: property(source, key: kTISPropertyLocalizedName),
      iconURL: property(source, key: kTISPropertyIconImageURL)
    )
  }

  private func property<Value>(_ source: TISInputSource, key: CFString) -> Value? {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
    let value = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    return value as? Value
  }
}
