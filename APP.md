Kind: utility

# Paperclip

A Clippy-style helper: a paperclip character floats in a see-through panel in the corner of the screen
(over every app and Space), and pops in with a speech bubble of advice about what the person is doing.
Menu bar icon (paperclip) holds: tip now, ask a question, show/hide, quiet for an hour, back to corner, Settings.

## Structure
- `App.swift`: LampMenuBar menu + Settings scene; shows the floating panel at launch.
- `BuddyPanel.swift`: `Buddy` (what the bubble says) and `BuddyPanel` (the borderless non-activating NSPanel; drag to move, position saved).
- `BuddyView.swift`: the character (Assets/clip.png, sways, hops on new bubble), the 90s yellow speech bubble and its buttons.
- `AskField.swift`: the question box in the bubble.
- `Watcher.swift`: front app, its window title, and a 1280px-wide screenshot (ScreenCaptureKit, excludes our own window).
- `Advisor.swift`: every 10 s checks; pops in once the person has stayed on one app/window 30 s and the chattiness interval has passed.
- `SettingsView.swift`: chattiness, look at screen (Screen Recording permission), AI status, open at login.

## AI (asked for)
- Tips: `LampAI.ask(as: Advice)` with the screenshot (when allowed and switched on) and front app/window title as `data:`.
  Returns opener + tip + worthSaying; unasked tips that aren't worth saying are dropped. Last 8 tips passed to avoid repeats.
- Questions: `LampAI.ask` with the typed question, plus the same context.
- Sent to the app's text model (remote, via Lamp). Nothing is stored. Without AI, the bubble says so with Set Up in Lamp.
- Proof: open a document in Pages, click the paperclip, get a tip about that document/app.
