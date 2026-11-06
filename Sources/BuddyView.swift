import SwiftUI

/// The paperclip and its speech bubble, drawn in the floating corner window.
struct BuddyView: View {
    @ObservedObject var buddy: Buddy
    @State private var dragStart: CGPoint?

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Spacer(minLength: 0)
            if let bubble = buddy.bubble {
                SpeechBubble(bubble: bubble, buddy: buddy)
                    .frame(maxWidth: 290, alignment: .trailing)
                    .padding(.trailing, 30)
                    .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
            }
            ClipCharacter(hop: buddy.hop, thinking: buddy.bubble?.isThinking == true)
                .frame(width: 70, height: 176)
                .padding(.trailing, 18)
                .contentShape(Rectangle())
                .onTapGesture {
                    if buddy.bubble == nil { buddy.tipNow() } else { buddy.dismiss() }
                }
                .gesture(DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        let last = dragStart ?? value.startLocation
                        BuddyPanel.shared.drag(by: CGSize(width: value.location.x - last.x, height: value.location.y - last.y))
                        dragStart = value.location
                    }
                    .onEnded { _ in
                        dragStart = nil
                        BuddyPanel.shared.endDrag()
                    })
                .help("Click for a tip, drag to move")
                .accessibilityElement()
                .accessibilityLabel("Paperclip")
                .accessibilityAddTraits(.isButton)
        }
        .padding(.bottom, 4)
        .frame(width: BuddyPanel.size.width, height: BuddyPanel.size.height, alignment: .bottomTrailing)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: buddy.bubble)
    }
}

/// The paperclip itself, bobbing gently and hopping when it has something to say.
struct ClipCharacter: View {
    var hop: Int
    var thinking: Bool
    @State private var bounce = false

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let sway = sin(t * (thinking ? 6 : 1.3)) * (thinking ? 4 : 2.5)
            Group {
                if let image = LampAssets.image("clip.png") {
                    Image(nsImage: image).resizable().scaledToFit()
                } else {
                    Image(systemName: "paperclip").resizable().scaledToFit()
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 4, x: 1, y: 3)
            .rotationEffect(.degrees(sway), anchor: .bottom)
            .offset(y: bounce ? -18 : 0)
        }
        .onChange(of: hop) {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { bounce = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { bounce = false }
            }
        }
    }
}

/// The classic pale yellow bubble, with its tail pointing down at the paperclip.
struct SpeechBubble: View {
    var bubble: Buddy.Bubble
    @ObservedObject var buddy: Buddy

    static let paper = Color(red: 1.0, green: 1.0, blue: 0.82)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if bubble.isThinking {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(bubble.text)
                }
            } else {
                Text(bubble.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let detail = bubble.detail {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.black.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if bubble.isAsking {
                AskField(buddy: buddy)
            } else if bubble.offersScreen {
                Text("Let me see your screen, and my tips will fit what you're doing.")
                    .font(.system(size: 12))
                    .foregroundStyle(.black.opacity(0.7))
                HStack {
                    Spacer()
                    Button("Not Now") { buddy.dismiss() }
                    Button("Let Me See") { LampPermissions.request(.screenRecording); buddy.dismiss() }
                }
                .buttonStyle(RetroButtonStyle())
            } else if bubble.needsSetup {
                HStack {
                    Spacer()
                    Button("Not Now") { buddy.dismiss() }
                    Button("Set Up in Lamp") { LampAI.openSetup(for: .text); buddy.dismiss() }
                }
                .buttonStyle(RetroButtonStyle())
            } else if !bubble.isThinking {
                HStack {
                    Button("Hush") { buddy.setQuiet(true) }
                        .help("Stay quiet for an hour")
                    Spacer()
                    Button("Ask…") { buddy.openAsk() }
                    Button("Thanks!") { buddy.dismiss() }
                }
                .buttonStyle(RetroButtonStyle())
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(.black)
        .padding(12)
        .background(BubbleShape().fill(Self.paper))
        .overlay(BubbleShape().stroke(.black, lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 6, x: 2, y: 3)
        .padding(.bottom, 14)
    }
}

/// A rounded box with a little tail at the bottom right.
struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let box = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
        var path = Path(roundedRect: box, cornerRadius: 10)
        let tailX = box.maxX - 36
        path.move(to: CGPoint(x: tailX - 12, y: box.maxY))
        path.addLine(to: CGPoint(x: tailX + 6, y: box.maxY + 14))
        path.addLine(to: CGPoint(x: tailX + 2, y: box.maxY))
        return path
    }
}

/// Buttons in the bubble, in the chunky style of the 90s helpers.
struct RetroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(configuration.isPressed ? Color(white: 0.8) : Color(white: 0.93)))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.6), lineWidth: 1))
    }
}
