import AppKit
import ScreenCaptureKit

/// What the person is doing right now: the app in front, its window's title, and when they allow it,
/// a small picture of the screen (without the paperclip in it).
struct Glance: Equatable {
    var app: String
    var bundleID: String
    var windowTitle: String?

    /// Same app and same window: the person is still on the same thing.
    var key: String { bundleID + "|" + (windowTitle ?? "") }

    var describedForAI: String {
        var lines = ["App in front: \(app)"]
        if let windowTitle, !windowTitle.isEmpty { lines.append("Window title: \(windowTitle)") }
        return lines.joined(separator: "\n")
    }
}

enum Watcher {
    /// Apps the paperclip never comments on: itself, Lamp, and the screen saver and login window.
    static let ignored: Set<String> = ["com.apple.loginwindow", "com.apple.ScreenSaver.Engine"]

    static func glance() -> Glance? {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != getpid() else { return nil }
        let bundleID = front.bundleIdentifier ?? ""
        if ignored.contains(bundleID) || bundleID.lowercased().contains("lamp") { return nil }
        return Glance(app: front.localizedName ?? "an app", bundleID: bundleID,
                      windowTitle: windowTitle(of: front.processIdentifier))
    }

    /// The front window's title. macOS only shares other apps' window titles with an app that may see the screen.
    private static func windowTitle(of pid: pid_t) -> String? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let mine = windows.first {
            ($0[kCGWindowOwnerPID as String] as? Int32) == pid && ($0[kCGWindowLayer as String] as? Int) == 0
        }
        let title = mine?[kCGWindowName as String] as? String
        return (title?.isEmpty ?? true) ? nil : title
    }

    /// A picture of the screen the mouse is on, small enough to send quickly, with the paperclip left out.
    static func screenshot() async -> NSImage? {
        guard LampPermissions.has(.screenRecording) else { return nil }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
            let screenID = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            guard let display = content.displays.first(where: { $0.displayID == screenID }) ?? content.displays.first else { return nil }
            let mine = content.applications.filter { $0.processID == getpid() }
            let filter = SCContentFilter(display: display, excludingApplications: mine, exceptingWindows: [])
            let config = SCStreamConfiguration()
            let width = 1280
            config.width = width
            config.height = Int(Double(width) * Double(display.height) / Double(max(display.width, 1)))
            config.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        } catch {
            print("Paperclip: couldn't take a screenshot: \(error.localizedDescription)")
            return nil
        }
    }
}
