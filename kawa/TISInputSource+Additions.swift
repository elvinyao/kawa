import Carbon
import Foundation

extension TISInputSource {
  func safeProperty<Value>(_ key: CFString) -> Value? {
    guard let pointer = TISGetInputSourceProperty(self, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? Value
  }
}
