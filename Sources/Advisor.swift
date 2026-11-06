import AppKit

/// How often the paperclip may pop in by itself.
enum Chattiness: String, CaseIterable, Identifiable {
    case often, sometimes, rarely, never
    var id: String { rawValue }

    var title: String {
        switch self {
        case .often: "Often (every few minutes)"
        case .sometimes: "Sometimes (about every 15 minutes)"
        case .rarely: "Rarely (about once an hour)"
        case .never: "Only when I ask"
        }
    }

    var minutes: Double? {
        switch self {
        case .often: 4
        case .sometimes: 15
        case .rarely: 60
        case .never: nil
        }
    }
}

enum Prefs {
    static var chattiness: Chattiness {
        Chattiness(rawValue: UserDefaults.standard.string(forKey: "chattiness") ?? "") ?? .sometimes
    }
    static var looksAtScreen: Bool {
        UserDefaults.standard.object(forKey: "looksAtScreen") as? Bool ?? true
    }
}

/// Watches what the person is up to and decides when the paperclip has something worth saying.
@MainActor
final class Advisor {
    static let shared = Advisor()

    private var timer: Timer?
    private var current: Glance?
    private var currentSince = Date()
    private var lastTip = Date()
    private var recentTips: [String] = []
    private var working = false

    /// How long the person has to stay on one thing before the paperclip comments on it.
    static let settleSeconds: TimeInterval = 30

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            MainActor.assumeIsolated { Advisor.shared.tick() }
        }
    }

    func tick() {
        let glance = Watcher.glance()
        if let glance, glance.key != current?.key {
            current = glance
            currentSince = .now
        }
        let buddy = Buddy.shared
        guard let minutes = Prefs.chattiness.minutes, !working, buddy.isShown, !buddy.isQuiet,
              buddy.bubble == nil, current != nil,
              Date().timeIntervalSince(currentSince) >= Self.settleSeconds,
              Date().timeIntervalSince(lastTip) >= minutes * 60 else { return }
        Task { await tip(asked: false) }
    }

    /// Looks at what the person is doing and offers one piece of advice. When it wasn't asked for and
    /// there's nothing useful to say, it stays quiet.
    func tip(asked: Bool) async {
        guard !working else { return }
        let buddy = Buddy.shared
        guard let glance = Watcher.glance() ?? current else {
            if asked { buddy.say("Switch to the app you're working in, and I'll take a look!") }
            return
        }
        working = true
        defer { working = false; lastTip = .now }
        if asked { buddy.think("Hmm, let me see…") }

        let picture = Prefs.looksAtScreen ? await Watcher.screenshot() : nil
        struct Advice: Decodable { let worthSaying: Bool; let opener: String; let tip: String }
        let prompt = """
        You are Paperclip, a cheerful, slightly goofy paperclip assistant on the person's Mac, in the spirit of the \
        old Office assistant, but genuinely useful. Look at what they're doing \(picture == nil ? "(described in the data)" : "(the screenshot and the data)") \
        and give ONE short, specific, practical tip for exactly that: a keyboard shortcut, a feature of that app, a \
        faster way to do the task in view, or a helpful observation about their work. Be concrete about what you see.
        Reply as JSON: {"worthSaying": bool, "opener": string, "tip": string}.
        - opener: one playful line in the classic style, under 15 words, e.g. "It looks like you're writing a letter!"
        - tip: the advice, at most 2 short sentences.
        - worthSaying: false if you can't see enough to say anything specific and useful\(asked ? " (they asked, so try hard to say something)" : "").
        Don't repeat any of these recent tips: \(recentTips.isEmpty ? "none yet" : recentTips.joined(separator: " | ")).
        """
        do {
            let advice = try await LampAI.ask(prompt, data: glance.describedForAI,
                                              images: picture.map { [$0] } ?? [], as: Advice.self)
            guard advice.worthSaying || asked else { buddy.dismissIfThinking(); return }
            guard !buddy.isQuiet || asked else { return }
            recentTips = Array((recentTips + [advice.tip]).suffix(8))
            buddy.say(advice.opener, detail: advice.tip)
        } catch {
            if asked || (error as? LampAI.Failure)?.needsSetup != nil {
                buddy.failed(error)
            }
        }
    }

    /// Answers a question the person typed into the bubble, with what's on their screen in mind.
    func answer(_ question: String) async {
        let buddy = Buddy.shared
        buddy.think("Ooh, good question…")
        let glance = Watcher.glance() ?? current
        let picture = Prefs.looksAtScreen ? await Watcher.screenshot() : nil
        let prompt = """
        You are Paperclip, a cheerful paperclip assistant on the person's Mac. Answer their question in at most \
        4 short sentences, plain text, no markdown. Use what they're doing (in the data\(picture == nil ? "" : " and the screenshot")) \
        when it's relevant. Their question: \(question)
        """
        do {
            let reply = try await LampAI.ask(prompt, data: glance?.describedForAI ?? "Nothing in front.",
                                             images: picture.map { [$0] } ?? [])
            buddy.say(reply.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            buddy.failed(error)
        }
    }
}
