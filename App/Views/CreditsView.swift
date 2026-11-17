import SwiftUI

struct CreditsView: View {
    private let music: [(String, String, String)] = [
        ("Main menu", "Spooky Waltz", "Aureolus_Omicron"),
        ("Sneaking around", "Dark Rooms and Scary Things", "isaiah658"),
        ("Being chased", "Chase in the night", "Samza"),
        ("Caught", "Sad Tune", "Aureolus_Omicron"),
        ("Escaped", "Haunting piano", "Emma_MA"),
    ]
    private let sounds: [(String, String)] = [
        ("Wood and stone footsteps", "TinyWorlds"),
        ("Tile and marble footsteps", "GboxMikeFozzy"),
        ("The Hunter's boots, carpet steps", "HaelDB"),
        ("Creaks, drawers, keys, doors", "laleksic"),
        ("Door locks", "Cough-E"),
        ("Thunder, keys, doors and more", "rubberduck"),
        ("Heartbeat", "bart"),
        ("Rain on the windows", "alxl"),
    ]

    var body: some View {
        List {
            Section {
                Text("All music and sound effects are public domain (CC0), from OpenGameArt.org. Thank you to these artists.")
            }
            Section("Music") {
                ForEach(music, id: \.1) { use, title, artist in
                    row(title, "\(artist). \(use).")
                }
            }
            Section("Sound effects") {
                ForEach(sounds, id: \.0) { what, who in
                    row(what, who)
                }
            }
            Section("Voices") {
                row("Kokoro text to speech", "hexgrad. The Hunter is Lewis, the Host is Heart.")
            }
        }
        .navigationTitle("Credits")
    }

    private func row(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(detail).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
