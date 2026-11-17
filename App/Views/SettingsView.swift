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
                VStack(alignment: .leading) {
                    Text("Music volume")
                    Slider(value: $settings.musicVolume, in: 0...1, step: 0.1) {
                        Text("Music volume")
                    }
                    .accessibilityValue(settings.musicVolume == 0 ? "Off" : "\(Int(settings.musicVolume * 100)) percent")
                }
                VStack(alignment: .leading) {
                    Text("Rain and thunder")
                    Slider(value: $settings.weatherVolume, in: 0...1, step: 0.1) {
                        Text("Rain and thunder")
                    }
                    .accessibilityValue(settings.weatherVolume == 0 ? "Off" : "\(Int(settings.weatherVolume * 100)) percent")
                }
            } header: {
                Text("Volume")
            } footer: {
                Text("Music gets quieter while the game is speaking.")
            }

            Section {
                Toggle("Vibration", isOn: $settings.haptics)
                Toggle("Skip the intro", isOn: $settings.skipIntro)
            }
        }
        .navigationTitle("Settings")
    }
}
