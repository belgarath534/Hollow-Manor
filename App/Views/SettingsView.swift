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
                Text("Difficulty").font(.headline).textCase(nil)
            }

            Section {
                Picker("Speech", selection: $settings.speechOutput) {
                    Text("Game voice").tag(SpeechOutput.gameVoice)
                    Text("VoiceOver").tag(SpeechOutput.voiceOver)
                }
                Toggle(isOn: $settings.announceTurns) { Text("Say direction after turning").font(.body) }
                Toggle(isOn: $settings.captions) { Text("Captions").font(.body) }
            } header: {
                Text("Speech").font(.headline).textCase(nil)
            } footer: {
                Text("Game voice uses your VoiceOver voice and speed. VoiceOver sends everything through VoiceOver itself.")
                    .font(.footnote)
            }

            Section {
                VStack(alignment: .leading) {
                    Text("Music volume").font(.body)
                    Slider(value: $settings.musicVolume, in: 0...1, step: 0.1) {
                        Text("Music volume")
                    }
                    .accessibilityValue(settings.musicVolume == 0 ? "Off" : "\(Int(settings.musicVolume * 100)) percent")
                }
                VStack(alignment: .leading) {
                    Text("Rain and thunder").font(.body)
                    Slider(value: $settings.weatherVolume, in: 0...1, step: 0.1) {
                        Text("Rain and thunder")
                    }
                    .accessibilityValue(settings.weatherVolume == 0 ? "Off" : "\(Int(settings.weatherVolume * 100)) percent")
                }
            } header: {
                Text("Volume").font(.headline).textCase(nil)
            } footer: {
                Text("Music gets quieter while the game is speaking.").font(.footnote)
            }

            Section {
                Toggle(isOn: $settings.haptics) { Text("Vibration").font(.body) }
                Toggle(isOn: $settings.skipIntro) { Text("Skip the intro").font(.body) }
            }
        }
        .navigationTitle("Settings")
    }
}
