#if os(macOS)
import AppKit
import Foundation

final class HelperAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var server: LocalHTTPServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            try TokenStore.shared.prepare()
            let server = LocalHTTPServer(token: TokenStore.shared.token)
            try server.start()
            self.server = server
            installStatusItem()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Zotero Metadata Helper failed to start"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "ZME"
        item.button?.toolTip = "Zotero Metadata Helper"

        let menu = NSMenu()
        let status = NSMenuItem(title: "Zotero Metadata Helper \(BuildInfo.version) (\(BuildInfo.build))", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(NSMenuItem.separator())

        let model = NSMenuItem(
            title: AppleIntelligenceAnalyzer.isAvailable ? "Apple Intelligence: available" : "Apple Intelligence: unavailable",
            action: nil,
            keyEquivalent: ""
        )
        model.isEnabled = false
        menu.addItem(model)

        let tokenPath = NSMenuItem(title: "Helper running on localhost:43119", action: nil, keyEquivalent: "")
        tokenPath.isEnabled = false
        menu.addItem(tokenPath)
        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit Helper", action: #selector(quitHelper), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    @objc private func quitHelper() {
        NSApp.terminate(nil)
    }
}
#endif
