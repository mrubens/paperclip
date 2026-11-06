import SwiftUI

/// The box in the bubble where the person types a question for the paperclip.
struct AskField: View {
    @ObservedObject var buddy: Buddy
    @State private var question = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Type your question here", text: $question, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 3).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.5), lineWidth: 1))
                .focused($focused)
                .onSubmit(send)
            HStack {
                Spacer()
                Button("Cancel") { buddy.dismiss() }
                Button("Search", action: send)
                    .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .buttonStyle(RetroButtonStyle())
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focused = true }
        }
    }

    private func send() {
        buddy.ask(question)
        question = ""
    }
}
