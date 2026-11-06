import SwiftUI

struct SettingsView: View {
    @AppStorage("chattiness") private var chattiness: Chattiness = .sometimes
    @AppStorage("looksAtScreen") private var looksAtScreen = true
    @StateObject private var recording = LampPermissionState(.screenRecording)
    @State private var askForRecording = false
    @State private var openAtLogin = LampLoginItem.isEnabled
    @State private var ai: LampAIStatus?

    var body: some View {
        Form {
            Section {
                Picker("Pop in with tips", selection: $chattiness) {
                    ForEach(Chattiness.allCases) { Text($0.title).tag($0) }
                }
            } footer: {
                Text("Paperclip only speaks up once you've stayed on something for a little while, and keeps quiet when it has nothing useful to say.")
            }

            Section {
                Toggle("Look at my screen", isOn: $looksAtScreen)
                if looksAtScreen && !recording.isOn {
                    HStack {
                        Label("Paperclip can only see which app is in front until you allow it to see the screen.",
                              systemImage: "eye.slash")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Allow…") { askForRecording = true }
                    }
                }
            } footer: {
                Text("A small screenshot goes with each tip and question, so the advice fits what you're actually doing. Paperclip never keeps it.")
            }

            Section("AI") {
                if let ai {
                    LabeledContent("Advice comes from", value: ai.route ?? "Nothing yet")
                    if !ai.available {
                        HStack {
                            Text(ai.reason ?? "AI isn't set up yet.").foregroundStyle(.secondary)
                            Spacer()
                            Button("Set Up in Lamp") { LampAI.openSetup(for: .text) }
                        }
                    }
                } else {
                    ProgressView().controlSize(.small)
                }
            }

            Section {
                Toggle("Open at Login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { LampLoginItem.isEnabled = openAtLogin }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .task { ai = await LampAI.status(.text) }
        .sheet(isPresented: $askForRecording) {
            LampPermissionView(.screenRecording,
                               reason: "Paperclip looks at your screen so its tips fit what you're doing.") {
                askForRecording = false
            }
        }
    }
}
