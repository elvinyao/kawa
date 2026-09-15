import Carbon
import Cocoa

struct InputSourcePresentation {
  let name: String
  let icon: NSImage?
}

final class InputSourcePresentationResolver {
  func presentation(for target: InputTarget) -> InputSourcePresentation? {
    rawSources().compactMap(makePresentation).first { target.matches($0.info) }.map {
      InputSourcePresentation(name: $0.name, icon: $0.icon)
    }
  }

  private func rawSources() -> [TISInputSource] {
    guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as NSArray? else {
      return []
    }
    return list as? [TISInputSource] ?? []
  }

  private func makePresentation(
    _ source: TISInputSource
  ) -> (info: InputSourceInfo, name: String, icon: NSImage?)? {
    guard let id: String = source.safeProperty(kTISPropertyInputSourceID) else { return nil }
    let info = InputSourceInfo(
      id: id,
      modeID: source.safeProperty(kTISPropertyInputModeID),
      bundleID: source.safeProperty(kTISPropertyBundleID),
      isEnabled: source.safeProperty(kTISPropertyInputSourceIsEnabled) ?? false,
      isSelectable: source.safeProperty(kTISPropertyInputSourceIsSelectCapable) ?? false
    )
    let name: String = source.safeProperty(kTISPropertyLocalizedName) ?? id
    return (info, name, loadIcon(for: source))
  }

  private func loadIcon(for source: TISInputSource) -> NSImage? {
    if let iconURL: URL = source.safeProperty(kTISPropertyIconImageURL) {
      let candidates = [
        iconURL.deletingPathExtension().appendingPathExtension("tiff"),
        iconURL
      ]
      if let image = candidates.lazy.compactMap({ NSImage(contentsOf: $0) }).first {
        return image
      }
    }

    return nil
  }
}
