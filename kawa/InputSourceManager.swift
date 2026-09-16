import Cocoa

struct InputSourcePresentation {
  let name: String
  let icon: NSImage?
}

final class InputSourcePresentationResolver {
  func presentation(for target: InputTarget) -> InputSourcePresentation {
    InputSourcePresentation(name: target.title, icon: loadIcon(at: target.iconURL))
  }

  private func loadIcon(at iconURL: URL?) -> NSImage? {
    guard let iconURL = iconURL else { return nil }
    let candidates = [
      iconURL.deletingPathExtension().appendingPathExtension("tiff"),
      iconURL
    ]
    return candidates.lazy.compactMap { NSImage(contentsOf: $0) }.first
  }
}
