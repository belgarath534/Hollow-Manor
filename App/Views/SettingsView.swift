import ManorCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Difficulty", selection: $settings.difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(settings.difficulty.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Difficulty")
            }

            Section {
                Picker("Speech", selection: $settings.speechOutput) {
                    Text("Game voice").tag(SpeechOutput.gameVoice)
                    Text("VoiceOver").tag(SpeechOutput.voiceOver)
                }
                Toggle("Say direction after turning", isOn: $settings.announceTurns)
                Toggle("Captions", isOn: $settings.captions)
            } header: {
                Text("Speech")
            } footer: {
                Text("Game voice uses your VoiceOver voice and speed. VoiceOver sends everything through VoiceOver itself.")
            }

            Section {
                Toggle("Vibration", isOn: $settings.haptics)
                Toggle("Skip the intro", isOn: $settings.skipIntro)
            }
        }
        .navigationTitle("Settings")
    }
}
