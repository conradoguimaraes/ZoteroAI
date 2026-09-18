import Foundation

struct BuildInfo {
    static let version = "0.2.5"
    static let build = 7
}

#if os(macOS)
import AppKit

let application = NSApplication.shared
let delegate = HelperAppDelegate()
application.delegate = delegate
application.run()
#else
print("ZoteroMetadataHelper \(BuildInfo.version) build \(BuildInfo.build): macOS-only helper. Linux build is a CI syntax/package smoke test.")
#endif
