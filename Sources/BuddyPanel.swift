import SwiftUI
import AppKit
import Combine

/// What the paperclip is saying and doing, shared by the floating panel and the menu.
@MainActor
final class Buddy: ObservableObject {
    static let shared = Buddy()

    /// One speech bubble: a line of advice, and what the person can answer.
    struct Bubble: Equatable {
        var text: String
        var detail: String? = nil
        var isThinking = false
        var isAsking = false
        var needsSetup = false
        var offersScreen = false
    }

    @Published var bubble: Bubble? = Bubble(text: "Hi! I'm Paperclip. I'll pop in now and then with tips for whatever you're doing.",
                                           detail: "Click me any time for a tip, or drag me somewhere else.",
                                           offersScreen: !LampPermissions.has(.screenRecording))
    @Published var isShown = true { didSet { BuddyPanel.shared.update() } }
    @Published private(set) var quietUntil: Date?
    /// Bumped to make the paperclip do a little hop when it has something to say.
    @Published var hop = 0

    var isQuiet: Bool { (quietUntil ?? .distantPast) > .now }

    func setQuiet(_ on: Bool) {
        quietUntil = on ? Date().addingTimeInterval(3600) : nil
        if on { bubble = nil }
    }

    func say(_ text: String, detail: String? = nil) {
        bubble = Bubble(text: text, detail: detail)
        hop += 1
        if !isShown { isShown = true }
    }

    func dismiss() { bubble = nil }

    func think(_ text: String) {
        bubble = Bubble(text: text, isThinking: true)
        if !isShown { isShown = true }
    }

    func dismissIfThinking() {
        if bubble?.isThinking == true { bubble = nil }
    }

    func failed(_ error: Error) {
        let setup = (error as? LampAI.Failure)?.needsSetup != nil
        bubble = Bubble(text: setup ? "I need AI set up in Lamp before I can give advice." : "Oops! I got a bit bent out of shape.",
                        detail: setup ? nil : error.localizedDescription, needsSetup: setup)
        hop += 1
    }

    func tipNow() {
        Task { await Advisor.shared.tip(asked: true) }
    }

    func ask(_ question: String) {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        Task { await Advisor.shared.answer(question) }
    }

    func openAsk() {
        bubble = Bubble(text: "What would you like to know?", isAsking: true)
        hop += 1
        if !isShown { isShown = true }
        BuddyPanel.shared.focus()
    }
}

/// The see-through window in the corner of the screen that holds the paperclip and its bubble.
/// It floats over every app and every Space, and never takes focus from what the person is doing
/// unless they click into it to type.
@MainActor
final class BuddyPanel {
    static let shared = BuddyPanel()

    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    static let size = NSSize(width: 380, height: 420)
    private var panel: Panel?
    private var watching: AnyCancellable?

    func show() {
        if panel == nil { make() }
        update()
        Advisor.shared.start()
    }

    private func make() {
        let panel = Panel(contentRect: NSRect(origin: .zero, size: Self.size),
                          styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: BuddyView(buddy: .shared))
        self.panel = panel
        if let saved = UserDefaults.standard.string(forKey: "buddyOrigin") {
            panel.setFrameOrigin(NSPointFromString(saved))
            keepOnScreen()
        } else {
            moveToCorner()
        }
        watching = Buddy.shared.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.update() }
        }
    }

    func update() {
        guard let panel else { return }
        if Buddy.shared.isShown { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }

    func focus() {
        panel?.makeKey()
    }

    /// Bottom right of the screen the mouse is on, clear of the Dock.
    func moveToCorner() {
        guard let panel else { return }
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: area.maxX - Self.size.width - 8, y: area.minY + 8))
        Buddy.shared.isShown = true
        saveOrigin()
    }

    /// Moves the window along with a drag of the paperclip.
    func drag(by delta: CGSize) {
        guard let panel else { return }
        panel.setFrameOrigin(NSPoint(x: panel.frame.origin.x + delta.width, y: panel.frame.origin.y - delta.height))
    }

    func endDrag() {
        keepOnScreen()
        saveOrigin()
    }

    private func keepOnScreen() {
        guard let panel else { return }
        let frame = panel.frame
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(frame) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        let x = min(max(frame.minX, area.minX - frame.width * 0.6), area.maxX - frame.width * 0.4)
        let y = min(max(frame.minY, area.minY), area.maxY - frame.height * 0.5)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func saveOrigin() {
        guard let panel else { return }
        UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: "buddyOrigin")
    }
}
